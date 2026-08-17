# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CREDIBLE Local Data is a Shiny web application that helps middle and high school learners collect local water quality data and send it to CODAP (Common Online Data Analysis Platform) to make graphs and explore patterns. The app fetches data from the USGS Water Quality Portal and exports it as CSV or directly into CODAP.

**IMPORTANT:** Only the Water Quality tab is active. Earlier features — Air Quality (EPA AQS), Weather/Climate (climateR), and Biodiversity (iNaturalist via rinat) — are archived in `archived-tabs.R`, which is excluded from deployment and renv scanning. They are kept for reference and can be restored by porting code back into `app.R`.

## Running the Application

Package installation is managed by renv (`renv.lock`); `app.R` only calls `library()`, never `install.packages()`.

**Tests** (run after any change to the data pipeline):
```sh
Rscript -e 'testthat::test_dir("tests/testthat")'
```
The suite covers the functions in `R/` with synthetic cases plus saved real API responses in `tests/testthat/fixtures/` (one fixture per schema: WQX 3.0 and legacy). Regenerate fixtures with `Rscript tests/capture-fixtures.R` (hits the live API).

A quick smoke test after app.R changes:
```sh
Rscript -e 'invisible(parse("app.R"))'                        # syntax
Rscript -e 'shiny::shinyAppFile("app.R")'                     # app object builds
```

**Performance** (`PERFORMANCE.md`, raw data in `tests/benchmark-results.csv`): a normal search is ~4.5s and our own processing is 0.5% of it — the wait is entirely WQP. The only selection with a real cost is the **number of counties** (~4.7s each, serial requests); parameter count is negligible and county *size* has no effect. WQP also stalls ~12% of requests (17s–210s). Re-measure with `Rscript tests/benchmark-queries.R` (live API, ~10–20 min); **never conclude anything from a single rep** — single samples previously produced two badly wrong numbers that were really stalls.

## Dependencies

Restore with `renv::restore()`.

No API credentials are required for the water quality features. (The archived air quality code reads `AQS_USERNAME`/`AQS_KEY` from `.Renviron`; see `.Renviron.example`.)

## Core Architecture

`app.R` (~1,450 lines) contains the CSS, the CODAP JavaScript bridge, UI, and server. The data-processing pipeline lives in `R/` (auto-sourced by Shiny):
- `R/wq-parameters.R` — mapping between student-facing parameter labels and the WQP characteristic names data is actually recorded under
- `R/process-wq.R` — pure data-frame transforms: tidy, county resolution, unit standardization, pivot, site summary; entry point is `process_wq_result()`

### Async Fetch Pattern (ExtendedTask)
The fetch runs in a separate R process via `ExtendedTask` + `future::plan(multisession)` so the UI stays responsive. `bslib::bind_task_button("fetch_data")` drives the button's busy state — this only works because the button is a `bslib::input_task_button`; with a plain `actionButton` the binding is silently inert and students can fire overlapping fetches.
- **One request per county**, results combined with `bind_rows()`, because the WQP API returns HTTP 500 when given multiple `countycode` values (verified June 2026; repeated params and semicolon-delimited both fail)
- **Primary service: WQX 3.0** (`readWQPdata(service = "ResultWQX3", dataProfile = "basicPhysChem")`) — the only WQP route to USGS data newer than March 2024 (legacy services stopped receiving USGS updates then; verified empirically June 2026). The WQX3 result profile carries site metadata (name, lat/lon) on every row, so it needs no separate station request — the result frame is passed as `meta_df` too.
- **Fallback: legacy services** (`readWQPdata()` + `whatWQPsites()`) if any WQX3 request fails (WQX3 is still labeled beta). The fallback is **all-or-nothing across counties** — never mix services in one fetch, because the two schemas have different column names.
- **The fallback is surfaced, not silent**: the task result carries `service` ("wqx3"/"legacy"). Legacy has no USGS data after March 2024 (other providers — state agencies, NPS — keep flowing), so when legacy served a query whose year range reaches ≥2024 the UI warns that USGS measurements may be missing, and an *empty* legacy result gets "the newest service isn't answering — try again" instead of "No water quality data found" (an empty fallback result says nothing about whether data exists in USGS-only counties). Ranges ending before 2024 warn about nothing: legacy is complete there.
- **County stamping**: every fetched row is stamped with `credible_county_fips` from the query it came from (`stamp_county()`, `R/fetch-wq.R`). The queried county is authoritative — WQX3 rows often have *empty* county metadata — and `tidy_wq_sites()` prefers the stamp over the profile's own county column. `stamp_county()` **must keep its zero-row guard**: a no-data county returns a 0-row/many-column frame, and `df$col <- value` on that throws `"replacement has 1 row, data has 0"`, which used to kill both services and hide the server's "No water quality data found" branch behind a technical error.
- **Column-type harmonization**: `harmonize_wq_columns()` (`R/fetch-wq.R`) runs before every `bind_rows()` of per-county frames. The WQP CSV parser types each column *per request*, so one county can return e.g. `DetectionLimit_MeasureA` as character while another returns it numeric (observed: Sevier vs. Knox/Blount, TN); `bind_rows()` aborts on that. Because the abort was caught by the WQX3 `tryCatch`, it silently demoted **every affected multi-county query to the legacy service** — i.e. to data with no USGS updates after March 2024. Conflicting columns are coerced to character (lossless; no column the pipeline reads is affected).
- **Request deadline**: every WQP call goes through `wqp_request()` (`R/fetch-wq.R`), which bounds it to 20s and retries once. `dataRetrieval` sets **no timeout** on the WQP path (`getWebServiceData()` has `req_throttle` + `req_retry` but no `req_timeout`), so without this a stalled request hangs indefinitely — WQP stalls ~12% of requests, up to 210s observed. Two traps, both verified live: a deadline that fires inside curl arrives as an **`interrupt`** with an empty message, so `tryCatch(error = ...)` silently misses it; and `future`'s globals scanner **does not follow default arguments**, so the deadline/tries defaults must stay literals — a named constant passes every local test and then fails only in the worker. Only deadlines are retried, so the WQX3→legacy fallback still triggers on real errors as before.
- **Shared result cache**: each county's result goes through `cached_wqp_fetch()` (`R/fetch-wq.R`), a read-through `cachem::cache_disk` keyed on county + dates + parameters + **service** (WQX3 and legacy schemas must never be served for one another). Keyed per *county*, not per fetch, so overlapping selections share entries. It lives in `dirname(tempdir())` — the container's shared temp root — **not** `tempdir()`, which is private per process and would give every Shiny and future worker its own useless copy. 24h TTL is safe because WQP data reaches the Portal days-to-weeks after collection. `wq_cache()` probes a real write before returning, because `cache_disk()` constructs happily against a directory it cannot write to; on failure it returns `NULL` and the fetch runs uncached rather than failing.
- **Cancellation** is cooperative: `input$cancel_fetch` drops a sentinel file that the worker checks *between counties* via `stop_if_cancelled()`, and sets `values$fetch_cancelled` so a result that lands anyway is discarded. A request already inside curl cannot be interrupted — that is what the deadline is for — so the Get Water Data button stays busy briefly after "Stop waiting", and the copy says so. A `wqp_cancelled` error must **not** trigger the legacy fallback, or cancelling would silently restart the whole fetch on the slower service.
- **One observer keyed on `water_fetch_task$status()`** handles both success and error. Critical: `ExtendedTask` has no `error()` method, and `result()` *rethrows* the task's error — so never use `result()` as an event expression (it would crash the session on API failure). Errors are retrieved by calling `result()` inside `tryCatch`.
- An elapsed-time observer (gated by `req(values$loading_visible, ...)` so it only ticks during a fetch) updates `values$fetch_elapsed` every second

### Fetch Feedback (what the student sees while waiting)
A network fetch of 10–90 seconds is the app's longest silence, so the wait is signalled in four places at once:
- **The button itself** swaps to a spinner + "Fetching data…" and disables (`input_task_button` + `bind_task_button`)
- **`#status_text`** beside the button reads "Searching the USGS Water Quality Portal…", and afterwards carries the result/error summary
- **The loading card** (`.wq-loading-card`, in a `conditionalPanel` on `output.loading_visible`, placed *inside* the Step 3 box so it is visible without scrolling in a short CODAP iframe) echoes the query back — `values$current_query_summary` is "Knox County, Tennessee · 2025 · 5 parameters" — over an indeterminate sliding progress bar, plus a live elapsed counter (`output$loading_elapsed`) whose reassurance text switches from "most searches finish in 10–60 seconds" to "still working…" past the one-minute mark. The bar is deliberately indeterminate: the API gives no progress signal, so a bar that fills to 100% would promise a completion time we can't know.
- **Stale results dim** during a re-fetch: an `observeEvent(values$loading_visible, ...)` sends a `setFetching` custom message and the JS handler toggles `body.wq-fetching`, which fades the `.wq-results` conditional panel to 40% and blocks pointer events. This goes through a custom message rather than a `shiny:value` listener because `loading_visible` has no DOM output binding to listen on.
- `@media (prefers-reduced-motion: reduce)` freezes the spinner, the progress stripe, and the CODAP busy spinner; the card and the elapsed counter still convey the state.

### Parameter Name Mapping (R/wq-parameters.R)
WQP characteristic names are exact-match, and most data is recorded under names that differ from the obvious ones (e.g., "Temperature, water" not "Temperature"; "Dissolved oxygen (DO)" not "Dissolved oxygen"). A name absent from the WQX domain list fails the whole request with HTTP 400 (the old "Total nitrogen" did this). So:
- `wq_characteristic_map` maps each student-facing checkbox label to all synonymous characteristic names (verified against the WQP domain service, June 2026)
- `expand_wq_characteristics()` expands labels → query names at fetch time
- `normalize_wq_parameter()` collapses fetched names → labels, so synonyms share one column after pivoting
- Only same-quantity/same-basis synonyms are merged; "Nitrate as N" vs "Nitrate" (as NO3) are intentionally NOT merged

## Dual Mode (CODAP plugin vs standalone website)

One codebase serves two deployments: the CODAP plugin (app embedded in a CODAP iframe) and a standalone website. The mode is decided at runtime in the browser — `window !== window.parent` — and reported in three places:

- a **body class** (`embedded` or `standalone`) that all mode-specific CSS is scoped to
- **`input$is_embedded`** (`Shiny.setInputValue(..., {priority: "event"})` on `shiny:connected`), read via the server's `is_embedded` reactive
- the JS flag `isEmbeddedInCodap`, which gates iframe-phone bridge initialization (the bridge is never initialized standalone)

**Deploy-time override**: setting the `STANDALONE` env var (any non-empty value; checked once at app startup via `Sys.getenv`) forces standalone mode even inside an iframe — for a second deployment under its own URL, and for local testing (`STANDALONE=1 Rscript -e 'shiny::runApp()'`). The override value is injected from R into the detection script with `sprintf`.

**Standalone is the safe default**: the CODAP send block (`.codap-send-block` — the Send button, `#codap_send_status`, and the CODAP blurb) is hidden by *default* CSS and shown only under `body.embedded`, so the brief gap before detection can never flash a CODAP button that wouldn't work. Server-side, the CODAP-only observers (`input$send_to_codap`, `input$codap_export_status`) `req(is_embedded())`, which is FALSE until the browser confirms embedding. In standalone, "Download as CSV" (`#download_wide`) takes over the CODAP button's primary styling, and the layout gets a centered 1100px max-width — all CSS-only, scoped to `body.standalone`, so the embedded (CODAP) presentation and behavior are untouched.

## CODAP Integration

The app implements the CODAP Data Interactive Plugin API using **iframe-phone**, vendored locally at `www/iframe-phone.js` (do not load it from a CDN — school networks block CDNs).

**JavaScript layer** (in `tags$head`):
- `codapInterface()` — Promise wrapper around an `iframePhone.IframePhoneRpcEndpoint` to `window.parent`
- `sendToCODAP` custom message handler — receives a payload from R and performs a **hierarchical export**: one shared data context (`WaterQualityQueries`) with a parent "Queries" collection (one case per Send, keyed by `fetched_at`) and a child "Measurements" collection. The case table is auto-opened on first Send only.

**R server layer**:
- `observeEvent(input$send_to_codap)` builds parent attrs (query, location, year_range, aggregation, parameters, n_rows, fetched_at) and child attrs (county, date, measurements…), then `session$sendCustomMessage(type = "sendToCODAP", ...)`
- `observeEvent(input$codap_export_status)` shows success/error notifications from JS

**Important details:**
- CODAP export only works when the app is embedded in CODAP as a Data Interactive plugin. The JS checks `window === window.parent` to produce a helpful error otherwise.
- NA values must be converted to NULL before JSON serialization
- `site_id` and `state` are dropped from child data; `site_name` is kept as the **first** child attribute so CODAP labels map points by creek name
- Inline busy/success/error status appears next to the Send button (`#codap_send_status`), driven from JS

## Important Technical Details

- **Static assets** live in `www/` (logo, iframe-phone.js), which Shiny serves automatically. Never use `addResourcePath` pointing at `"."` — that exposes the app source over HTTP.
- **Status text** (`#status_text`) uses `white-space: pre-line` CSS so `\n` in status strings renders as line breaks.
- **Year slider** bounds derive from `current_year <- as.integer(format(Sys.Date(), "%Y"))`; default is last year.
- **Reactive values**: a single `reactiveValues()` object (`values$long_data`, `wide_data`, `data_fetched`, `status`, `loading_visible`, `available_sites`, `fetch_start_time`, `fetch_elapsed`, `current_*`).
- **Parameter names**: checkbox values are student-facing labels, expanded to real WQP characteristic names via `R/wq-parameters.R` (never pass labels straight to the API — see Parameter Name Mapping above); query is restricted to `sampleMedia = "Water"`, `siteType = "Stream"`.
- **Aggregation**: the UI offers only "Raw data" and "Monthly" (`input$time_aggregation` ∈ "none"/"month"); server code intentionally handles only those two.

## Common Gotchas

1. **County selection initialization**: Tennessee/Knox County is the hardcoded default (UI `selected=` values and the `observeEvent(input$state_selection)` county updater).
2. **Multi-county queries**: `input$county_selection` is a vector; FIPS codes are built as `paste0("US:", state_fips, ":", county_fips)` vectors, but the WQP API must be queried one county at a time (see Async Fetch Pattern). Each row's `county` column comes from the fetch-time county stamp, not the combined location string.
3. **Mixed units**: WQP returns the same parameter in different units (e.g., temperature in both °C and °F). Convert known variants first, then the modal-unit filter drops the rest — check this when adding new parameters.
4. **WQX3 metadata is patchy**: county code/name fields are often empty strings in WQX3 result rows, and the WQX3 services print a "use with caution" beta warning. Don't rely on WQX3 county metadata (use the stamp) and keep the legacy fallback intact.
5. **Search time estimates**: `R/wq-estimate.R` holds the fitted model (4.7s per county + 1.2s per extra year, reproducing all three measured benchmark medians) used by both the inline estimate under the county picker and the >3-year notification. Parameter count is deliberately not a term. Keep the two in sync — the notification previously claimed "30-90 seconds" for a long range that actually measures 9.5s. Above `wq_county_soft_cap` (5) the inline estimate turns into a warning, but nothing is blocked: comparing eight counties is a legitimate lesson.
6. **NA handling in CODAP export**: NA must become NULL (`if (length(x) == 1 && is.na(x)) NULL else x`) or CODAP receives invalid JSON.
7. **`"all" %in% input$site_selection`**: the site filter treats "all" anywhere in the selection as "no filtering".

## Key External Resources

- **USGS Water Quality Portal**: https://www.waterqualitydata.us/
- **CODAP**: https://codap.concord.org/
- **CODAP Plugin API**: https://github.com/concord-consortium/codap/wiki/CODAP-Data-Interactive-Plugin-API
- **iframe-phone**: https://github.com/concord-consortium/iframe-phone

## Deployment Notes

Deployed to shinyapps.io (see `rsconnect/`). Key considerations:

- `.rscignore` controls what is uploaded; documentation, archived code, and reference scripts are excluded
- Large data queries (10+ years) may time out on free tiers
- Keep all static assets in `www/` — nothing outside it should be web-accessible
- **Standalone deployment**: deploy the same code a second time under its own URL with the `STANDALONE` env var set (on shinyapps.io: `rsconnect::appDependencies` doesn't carry env vars — set it in the deployment's environment settings). The plugin deployment needs no env var: iframe detection handles it (see Dual Mode above).
