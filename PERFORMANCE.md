# Water Quality Fetch — Performance

How long a student waits for a water quality search, what makes that number
move, and what was fixed along the way.

Baseline measured **2026-07-30**, `dataRetrieval` 2.7.25, R 4.5.0, from a
single machine and network. Raw data in `tests/benchmark-results.csv`.

---

## TL;DR

- **A normal search takes about 4.5 seconds.** That is the app default
  (one county, one year, five parameters).
- **Almost nothing a student selects makes it meaningfully slower** —
  except adding counties, which costs ~4.7s each and is linear.
- **Our own R code is 0.5% of the wait.** There is no optimisation to win
  on our side; the time is the USGS Water Quality Portal (WQP).
- **WQP randomly stalls individual requests** (3 of 24 reps, 17s–210s
  where the same query normally took ~5s). This is the main source of a
  bad experience and is not predictable, but it is now **bounded**: each
  request gets a 20s deadline and one retry (see [Stalls](#stalls)).
- Two correctness bugs were found by benchmarking against the live API and
  have been fixed (see [Bugs found](#bugs-found-and-fixed)).

---

## Reproducing

```sh
Rscript tests/benchmark-queries.R              # 6 scenarios x 4 cold reps, ~10-20 min
Rscript tests/benchmark-queries.R --list
Rscript tests/benchmark-queries.R --scenario=default,multi-county --reps=6
Rscript tests/benchmark-queries.R --service=legacy   # force the fallback path
```

Every run appends to `tests/benchmark-results.csv` and prints drift against
prior runs. The script hits the live API and is deliberately **not** part of
the test suite (`testthat::test_dir("tests/testthat")`).

Two things the script does that a naive benchmark would get wrong:

- **Every rep is genuinely cold.** WQP caches an identical query
  server-side and returns a repeat in ~0.1s. Each rep shifts `startDateLo`
  forward by `rep - 1` days, which changes the cache key while barely
  changing the workload. Without this, reps 2..N just measure the cache.
- **Stalls are counted, not averaged in.** The summary reports min /
  median / max plus a count of reps exceeding 3x that scenario's own best.
  A single sample cannot distinguish a stall from an expensive query.

The script mirrors the `ExtendedTask` body in `app.R` and sources the real
helpers from `R/`, so it stays honest about what the app actually does. If
the fetch logic changes (services, `dataProfile`, `ignore_attributes`, the
per-county loop), update `fetch_wq()` in the script to match.

---

## Baseline

Four cold reps per scenario. Times in seconds, total = fetch + processing.

| Scenario | n | min | **median** | max | stalls | rows |
|---|---|---|---|---|---|---|
| 3 counties (Knox/Blount/Sevier TN), 1yr, 5 params | 4 | 13.8 | **14.1** | 15.0 | 0 | 1680 |
| 5-year range (Knox TN), 5 params | 4 | 8.4 | **9.5** | 210.5 | 1 | 2222 |
| All 16 parameters (Knox TN), 1yr | 4 | 5.0 | **5.1** | 42.6 | 1 | 705 |
| **App default** (Knox TN, 1yr, 5 params) | 4 | 4.4 | **4.6** | 17.5 | 1 | 402 |
| Small rural county (Pickett TN), 1yr, 5 params | 4 | 4.2 | **4.4** | 4.4 | 0 | 77 |
| Large urban county (LA CA), 1yr, 5 params | 4 | 3.8 | **3.9** | 7.0 | 0 | 0 |

Supporting measurements:

| | |
|---|---|
| App startup | ~4.2s (2.0s libraries + 1.4s app build + 0.8s `plan(multisession)`) |
| Repeat of an identical query | 0.2–1.1s (WQP server cache) |
| CODAP export payload build | ~0.4ms/row — negligible at typical sizes, 3.8s at 10k rows, and **synchronous** unlike the fetch |
| `process_wq_result()` | ~0.1s, flat from 199 to 20,000 raw rows |

---

## What drives the wait

| Factor | Effect | Verdict |
|---|---|---|
| **Number of counties** | 1 → 3 counties: 4.6s → 14.1s | **Dominant.** ~4.7s each, linear |
| Year range | 1 → 5 years: 4.6s → 9.5s | Modest |
| Parameter count | 5 → 16 params: 4.6s → 5.1s | Negligible |
| County *size* | 77-row vs 1093-row county | **No effect** — both ~5s |
| Rows returned | 0 to 2222 rows | **No effect** |

County count is the only lever with a real, predictable cost, and it is
structural: **the WQP API returns HTTP 500 for multi-county requests**, so
`app.R` issues one request per county in series, each paying
`dataRetrieval`'s built-in 30-requests-per-minute throttle (~2s). Nothing
about this is fixable on our side short of the API supporting batching.

Latency does not track data volume at all. The clearest demonstration is a
round-robin probe across four counties with cache-busting date jitter:

```
round 1  Knox     6.3s  rows=402      round 2  Knox    27.4s  rows=402
round 1  Pickett  4.5s  rows=77       round 2  Pickett  4.1s  rows=77
round 1  Blount   4.5s  rows=185      round 2  Blount   4.2s  rows=185
round 1  Sevier   5.5s  rows=1093     round 2  Sevier   4.8s  rows=1093
```

Sevier returned 14x Pickett's data in the same time. Knox ran 6.3s then
27.4s for the same query shape. The cost is not in the payload.

### Stalls

WQP stalls individual requests for no visible reason: **3 of 24 cold reps**
(~12%), consistent with the 1-in-8 seen in the probe above. Magnitudes were
17.5s, 42.6s, and 210.5s against ~5s baselines.

The 210.5s case is a distinct and worse failure mode. A transient HTTP/2
framing error killed the WQX3 request, the `tryCatch` fell back to the
legacy service, and legacy took 3.5 minutes:

```
WQX3 failed (Failed to perform HTTP request. Caused by error in
`curl::curl_fetch_memory()`: Stream error in the HTTP/2 framing layer
[www.waterqualitydata.us]: HTTP/2 stream 31 was not closed cleanly:
INTERNAL_ERROR (err 2)) — falling back to legacy
```

So the legacy fallback is not only for "WQX3 is down" — a momentary network
blip can turn a 9s query into a 210s one. This is the realistic worst case
and the reason the wait copy has a >90s stage.

**Stalls compound per county.** The 12% is per *request*, and the app
issues one request per county, so the chance a fetch contains a stall is
`1 - 0.88^n`: 12% at one county, 32% at three, 64% at eight. Because the
requests are serial, the stall adds to an already-long wait.

#### The deadline (fix)

A stalled request previously hung until the Portal answered, because
**`dataRetrieval` sets no timeout on the WQP path**. `getWebServiceData()`
builds its httr2 request with `req_throttle()` and `req_retry()` but no
`req_timeout()` — contrast its newer `basic_request()`, which sets 180s.
There was no ceiling at all; 210s was just where that sample landed.

`wqp_request()` (`R/fetch-wq.R`) now wraps every WQP call in a 20s deadline
with one retry. A stall is a property of the request, not the query — the
same query re-issued returns at its usual speed — so the retry converts a
~12% chance of a long wait into ~1.4% (0.12²) at a cost of 20s when it
fires. 20s is ~4x a normal per-county request and just above the smallest
stall observed (17.5s), so it cannot fire on a healthy slow query.

Two things this depends on, both verified against the live API and easy to
get wrong:

- **A blocked curl request delivers the deadline as an `interrupt`**, not
  an error, with an empty message. `tryCatch(error = ...)` never sees it and
  silently does nothing. (An R-level limit *does* arrive as an error, so
  `is_deadline_condition()` accepts both shapes.)
- **`future`'s globals scanner does not follow default arguments.** A
  `deadline = wqp_deadline_seconds` default passes every local test, then
  fails in the worker with `object 'wqp_deadline_seconds' not found` the
  first time the app really fetches. The defaults are literals for this
  reason.

Only deadlines are retried; real API errors propagate untouched, so the
WQX3 → legacy fallback still triggers on them exactly as before.

---

## Bugs found and fixed

Both were invisible to the unit tests and the saved fixtures, and only
appeared against the live API. Both now live in `R/fetch-wq.R` with
regression tests in `tests/testthat/test-fetch-wq.R`.

### 1. Empty results crashed the fetch

A county/year/parameter combination with no data returns a 0-row (but
104-column) frame. `df$credible_county_fips <- "037"` on that throws
`"replacement has 1 row, data has 0"`. The error escaped the fetch, took
the legacy fallback down with it, and surfaced to the student as
*"Oops! Something went wrong … Technical details: replacement has 1 row,
data has 0"* after a ~17s wait — the server's own "No water quality data
found" branch was unreachable.

Los Angeles County, 2025, streams genuinely has no matching data, so this
was reachable from the UI. Fixed with a zero-row guard in `stamp_county()`.

### 2. Multi-county queries silently served stale data

WQP's CSV parser types each column *per request*, so the same column can
come back numeric for one county and character for another when that
county's slice mixes blank strings with numbers:

```
US:47:093 (Knox)   rows= 402  DetectionLimit_MeasureA=numeric
US:47:009 (Blount) rows= 185  DetectionLimit_MeasureA=numeric
US:47:155 (Sevier) rows=1093  DetectionLimit_MeasureA=character
bind_rows ERROR: Can't combine `..1$DetectionLimit_MeasureA` <double>
                 and `..3$DetectionLimit_MeasureA` <character>.
```

`bind_rows()` aborted, the WQX3 `tryCatch` swallowed it, and **every
affected multi-county query fell back to the legacy service — which serves
no USGS data newer than March 2024.** Students got quietly stale data with
no indication anything had gone wrong. Being data-dependent, it appeared
and disappeared with the county and parameter mix.

Fixed with `harmonize_wq_columns()`, which coerces only the columns whose
class disagrees across frames to character (lossless; every column the
pipeline reads is consistently typed). After the fix the same query
completes on WQX3 and returns 1680 rows vs. legacy's 1651 — that delta is
the post-March-2024 USGS data students were missing.

---

## Wait copy

The old loading-card copy was wrong twice over and has been replaced:

| Old | Why it was wrong |
|---|---|
| "most searches finish in 10–60 seconds" | The common case is ~4.5s. The range made a normal search sound slow, and still didn't cover the tail. |
| "big counties and long year ranges take longer" | County *size* has no measurable effect. It pointed students at a control that wouldn't help. |

The replacement never quotes a finish time, and stages by elapsed time —
with different stages for big and normal queries, because 15 seconds means
"stalling" for a default search and "on track" for a three-county one.
A query counts as big at **≥2 counties or ≥4 years**; parameter count is
deliberately not a term.

| Elapsed | Normal search |
|---|---|
| <10s | searches like this usually take just a few seconds |
| 10–30s | the Portal is being slow to answer — that happens even for small counties, and it usually sorts itself out |
| 30–90s | still working — this one is taking longer than usual |
| >90s | still working. It's safe to leave this running, or reload the page to try fewer counties or a shorter year range |

Big searches get an up-front expectation (*"each extra county is looked up
separately, and longer year ranges add time too"*) and only escalate past
90s.

The >90s line says *reload the page* rather than *start a new search*
because the fetch button is disabled mid-fetch and there is no cancel —
reloading is genuinely the only way out.

---

## Production assessment

**Acceptable.** The default path is ~4.5s with async fetch, so one
student's slow search never blocks another's. Processing is flat and
irrelevant to the wait. The two correctness bugs above were more serious
than any latency concern and are fixed.

Remaining risks, in order:

1. **WQP stalls (~12% of requests).** Still not preventable, but now
   bounded to 20s + one retry per request instead of open-ended. Reaching
   the legacy fallback now requires two consecutive stalls (~1.4%).
2. **The cache is per-instance, not global.** `cache_disk` lives in the
   container's temp root, so it is shared by every process on one
   shinyapps.io instance but not across instances. A class split across
   two instances warms two caches. Fine for a classroom; worth knowing
   before assuming a single global hit rate.
3. **The estimate is a model, not a measurement.** `wq_time_estimate()` is
   fitted to three benchmark points. It cannot know about a stall or a
   cache hit, so it will read low during a stall and high on a warm cache.
   That is why the loading card still stages by *elapsed* time rather than
   counting down to it.
4. **Cancel stops the waiting, not always the request.** A request already
   inside curl runs to its deadline; the sentinel is only checked between
   counties. The Get Water Data button therefore stays busy for a moment
   after "Stop waiting", which the copy says outright.

### Added since the baseline

| | |
|---|---|
| **Shared result cache** | `cachem::cache_disk` keyed per county+year+params+service, 24h TTL, 100 MB cap. A class of 30 searching the same county now makes one trip to WQP instead of 30 — and 29 of them can no longer stall. Verified shared across separate R processes. |
| **Search time estimate** | Under the county picker, from `wq_time_estimate()` (`R/wq-estimate.R`). Turns into a warning above 5 counties — advisory only, since comparing eight counties is a legitimate lesson. |
| **"Stop waiting"** | Drops a sentinel file the worker checks between counties, and marks the result unwanted. Previous results stay on screen. |
| **Timeout copy** | A `wqp_timeout` condition now gets its own message ("the Portal is just being slow") instead of the generic "Oops! Something went wrong", which blamed the student's search for the Portal's behaviour. |
| **Legacy fallback surfaced** | The fetch result carries which service answered. Legacy serves no USGS data after March 2024 — but other providers keep flowing, so a fallback result looks plausible while silently missing every USGS station (fixture check: WQX3 199 rows incl. 24 USGS for Knox/Blount Jun–Dec 2024; legacy 175 rows, 0 USGS). For year ranges reaching ≥2024, a non-empty fallback result now warns that recent USGS measurements may be missing, and an empty one says "the newest service isn't answering — try again" instead of "No data found", which in a USGS-only county was a confident wrong answer. |

The old year-range notification claimed a long range "may take 30-90
seconds"; a 5-year single-county search measures 9.5s. It now uses the same
fitted estimate as everything else.

### Caveats on these numbers

- One sitting, one machine, one network. The medians are solid; the **~12%
  stall rate is the shakiest figure** and would firm up with runs at other
  times of day.
- Earlier single-sample measurements produced two badly wrong conclusions
  (that 16 parameters cost 55s and a 5-year range cost 108s — both were
  stalls, actually 5.1s and 9.5s). **Do not draw conclusions from one rep
  of this benchmark.** Use the median across at least four.
