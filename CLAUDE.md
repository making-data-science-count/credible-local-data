# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CREDIBLE Local Data is a Shiny web application that helps middle and high school learners collect local water quality data and send it to CODAP (Common Online Data Analysis Platform) to make graphs and explore patterns. The app fetches data from the USGS Water Quality Portal and exports it as CSV or directly into CODAP.

**IMPORTANT:** Only the Water Quality tab is active. Earlier features — Air Quality (EPA AQS), Weather/Climate (climateR), and Biodiversity (iNaturalist via rinat) — are archived in `archived-tabs.R`, which is excluded from deployment and renv scanning. They are kept for reference and can be restored by porting code back into `app.R`.

## Running the Application

**Local Development:**
```r
shiny::runApp("app.R")
```

Or in RStudio: Open `app.R` and click "Run App".

**No build or test commands** — this is a pure R/Shiny application with no compilation step. Package installation is managed by renv (`renv.lock`); `app.R` only calls `library()`, never `install.packages()`.

A quick smoke test after changes:
```sh
Rscript -e 'invisible(parse("app.R"))'                        # syntax
Rscript -e 'shiny::shinyAppFile("app.R")'                     # app object builds
```

## Dependencies

Loaded by `app.R`: shiny, shinydashboard, tidyverse, dataRetrieval, janitor, promises, future, bslib. Restore with `renv::restore()`.

No API credentials are required for the water quality features. (The archived air quality code reads `AQS_USERNAME`/`AQS_KEY` from `.Renviron`; see `.Renviron.example`.)

## Core Architecture

`app.R` (~1,400 lines) contains everything: CSS, the CODAP JavaScript bridge, UI, and server.

### Water Quality Tab Flow
1. **Step 1 · Location**: State dropdown → multi-select county selectizeInput (Tennessee/Knox County is the default)
2. **Step 2 · Parameters**: Primary checkboxes (pH, Turbidity, Temperature, Dissolved oxygen, E. coli) with EPA fact-sheet tooltips/links, plus a collapsible "More options" section with a year-range slider and additional parameters
3. **Step 3 · Fetch**: "Get Water Data" button triggers an async `ExtendedTask`
4. **Refine (optional)**: site filter (top-5 most active sites listed; "All sites" covers everything) and Raw/Monthly aggregation toggle
5. **Send**: "Send to CODAP" button + CSV download

### Async Fetch Pattern (ExtendedTask)
The fetch runs in a separate R process via `ExtendedTask` + `future::plan(multisession)` so the UI stays responsive, with `bslib::bind_task_button()` disabling the button while running:
- `water_fetch_task` calls `dataRetrieval::readWQPdata()` and `whatWQPsites()` inside `future()` — **one request per county**, results combined with `bind_rows()`, because the WQP API returns HTTP 500 when given multiple `countycode` values (verified June 2026; repeated params and semicolon-delimited both fail)
- **One observer keyed on `water_fetch_task$status()`** handles both success and error. Critical: `ExtendedTask` has no `error()` method, and `result()` *rethrows* the task's error — so never use `result()` as an event expression (it would crash the session on API failure). Errors are retrieved by calling `result()` inside `tryCatch`.
- An elapsed-time observer (gated by `req(values$loading_visible, ...)` so it only ticks during a fetch) updates the status text every second

### Data Processing (inside the success branch)
1. Raw data cleaned with `janitor::clean_names()`
2. Site metadata joined: site_name, **per-site county** (resolved from the WQP `county_code` through the FIPS crosswalk, so multi-county queries label each row with its actual county), lat, lon
3. Unit standardization in two steps:
   - Convert known variants to a canonical unit: µg/L→mg/L, °F→°C, mS/cm→µS/cm, umho/cm→µS/cm
   - Within each parameter, keep only the most common unit; dropped rows are counted and reported in the status message
4. `pivot_wider` (unit column dropped first; `values_fn = mean` averages same-day replicates) into `values$wide_data`
5. Top-5 most active sites populate the site selector

### FIPS Crosswalk System
- `fips-xwalk.csv` contains ALL US counties (3,000+) from Kieran Healy's dataset
- `fips_clean` dataframe provides state/county lookups
- Five-digit FIPS codes: first 2 digits = state, last 3 = county

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
- **Reactive values**: a single `reactiveValues()` object (`values$long_data`, `wide_data`, `data_fetched`, `status`, `loading_visible`, `available_sites`, `fetch_start_time`, `current_*`).
- **Parameter names**: the app passes common names ("pH", "Nitrate") as `characteristicName` to `readWQPdata()`; query is restricted to `sampleMedia = "Water"`, `siteType = "Stream"`.
- **Aggregation**: the UI offers only "Raw data" and "Monthly" (`input$time_aggregation` ∈ "none"/"month"); server code intentionally handles only those two.

## Code Patterns to Follow

**Data validation pattern:**
```r
if (input$state_selection == "" || is.null(input$county_selection) || length(input$county_selection) == 0) {
  showNotification("Please select state and at least one county", type = "error", duration = 5)
  return()
}
```

**Loading indicator pattern:**
```r
values$loading_visible <- TRUE
values$fetch_start_time <- Sys.time()
# ... invoke ExtendedTask; observers set loading_visible <- FALSE on completion/error
```

**ExtendedTask error handling pattern:**
```r
observeEvent(task$status(), {
  st <- task$status()
  if (st == "error") {
    msg <- tryCatch({ task$result(); "Unknown error" }, error = function(e) conditionMessage(e))
    # ... show friendly error ...
    return()
  }
  if (st != "success") return()
  result <- task$result()
  # ... process ...
})
```

## Common Gotchas

1. **County selection initialization**: Tennessee/Knox County is the hardcoded default (UI `selected=` values and the `observeEvent(input$state_selection)` county updater).
2. **Multi-county queries**: `input$county_selection` is a vector; FIPS codes are built as `paste0("US:", state_fips, ":", county_fips)` vectors, but the WQP API must be queried one county at a time (see Async Fetch Pattern). Each row's `county` column comes from site metadata, not the combined location string.
3. **Mixed units**: WQP returns the same parameter in different units (e.g., temperature in both °C and °F). Convert known variants first, then the modal-unit filter drops the rest — check this when adding new parameters.
4. **Year range warnings**: ranges > 3 years trigger a notification about slow fetches.
5. **NA handling in CODAP export**: NA must become NULL (`if (length(x) == 1 && is.na(x)) NULL else x`) or CODAP receives invalid JSON.
6. **`"all" %in% input$site_selection`**: the site filter treats "all" anywhere in the selection as "no filtering".

## File Structure

```
credible-local-data/
├── app.R                   # Main Shiny app (~1,400 lines) — the only file the app needs
├── www/
│   ├── credible-logo.png   # Logo (served automatically by Shiny)
│   └── iframe-phone.js     # Vendored CODAP communication library (v1.4.0)
├── fips-xwalk.csv          # FIPS code lookup (3,000+ counties)
├── archived-tabs.R         # Archived air quality / weather / biodiversity code (reference only)
├── water-data.R            # Original script (reference only)
├── fips.R                  # Script to download FIPS data (reference only)
├── renv.lock, renv/        # Package management
├── .rscignore              # Files excluded from shinyapps.io deployment
├── .renvignore             # Files excluded from renv dependency scanning
├── README.md               # User-facing documentation
├── CODAP_*.md              # CODAP integration documentation
└── credible-local-data.Rproj
```

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
