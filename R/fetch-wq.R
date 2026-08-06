# Helpers used inside the fetch itself (the ExtendedTask body in app.R),
# as opposed to R/process-wq.R which transforms what the fetch returned.
#
# These live here rather than inline in the future() block so they can be
# unit tested — both of them exist because of a bug that only showed up
# against the live API.

# Stamp every fetched row with the county FIPS we queried for. The queried
# county is authoritative: WQX3 result rows often carry empty county
# metadata, and tidy_wq_sites() prefers this stamp over the profile's own
# county column.
#
# The zero-row guard is load-bearing. A county/year/parameter combination
# with no matching data comes back as a 0-row (but many-column) frame, and
# `df$col <- "047"` on that throws "replacement has 1 row, data has 0".
# Without the guard that error escaped the fetch, took the legacy fallback
# down with it, and surfaced to the student as "Oops! Something went wrong"
# — the server's own "No water quality data found" branch was unreachable.
stamp_county <- function(df, code) {
  fips <- sub("^US:[0-9]+:", "", code)
  df$credible_county_fips <- if (nrow(df) == 0) character(0) else fips
  df
}

# Make a list of per-county result frames safe to bind_rows().
#
# The WQP CSV parser infers each column's type per request, so the same
# column can come back numeric for one county and character for another
# when that county's slice mixes blank strings with numbers. Observed on
# DetectionLimit_MeasureA (Sevier County TN character, Knox and Blount
# numeric), and it is data-dependent, so it appears and disappears with the
# county and parameter mix.
#
# bind_rows() aborts on that mismatch. Inside the app's fetch that error
# was caught by the WQX3 tryCatch, so every affected multi-county query
# silently fell back to the legacy service — which serves no USGS data
# newer than March 2024. Students got quietly stale data.
#
# Conflicting columns are coerced to character because that is lossless and
# predictable. It costs nothing downstream: every column the pipeline
# actually reads (identifier, name, lat/lon, date, characteristic, measure,
# unit) is consistently typed across counties, and tidy_wq_sites() coerces
# lat/lon numerically anyway in case that ever stops being true.
# Run expr with a wall-clock deadline, always clearing the limit again.
#
# setTimeLimit's limit is global to the process, so the on.exit reset is
# load-bearing: leave it armed and the *next* thing this worker does dies
# instead.
with_deadline <- function(expr, seconds) {
  setTimeLimit(elapsed = seconds, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)
  force(expr)
}

# Did this condition come from our deadline rather than from the API?
#
# The signal depends on where the limit fires, which is why both arms are
# needed. Blocked in curl (the case we actually care about) R delivers an
# *interrupt* condition with an empty message -- so tryCatch(error=) never
# sees it, which is why an obvious-looking error handler silently does
# nothing. Fired in R-level code it arrives as a plain error whose message
# is "reached elapsed time limit".
is_deadline_condition <- function(cond) {
  inherits(cond, "interrupt") ||
    grepl("reached (elapsed|CPU) time limit", conditionMessage(cond))
}

# One WQP request, bounded and retried.
#
# dataRetrieval sets no timeout on the WQP path: getWebServiceData() builds
# its httr2 request with req_throttle() and req_retry() but no
# req_timeout() (contrast its newer basic_request(), which sets 180s). A
# stalled request therefore hangs until the Portal eventually answers --
# the 210s worst case in PERFORMANCE.md. WQP stalls ~12% of requests for no
# visible reason, and a stall is a property of the request, not the query:
# the same query re-issued normally returns at its usual speed. So a
# bounded retry converts a ~12% chance of a very long wait into ~1.4%
# (0.12^2), at a cost of `deadline` seconds when it fires.
#
# Only deadlines are retried. Real API errors propagate untouched so the
# caller's WQX3 -> legacy fallback still triggers on them exactly as before.
#
# The defaults are literals rather than named constants on purpose. This
# runs inside future(), and future's globals scanner does not follow
# default arguments -- a `deadline = wqp_deadline_seconds` default looks
# fine locally and in every unit test, then fails in the worker with
# "object 'wqp_deadline_seconds' not found" only when the app actually
# fetches. 20s is ~4x a normal per-county request (~4.5s, including
# dataRetrieval's 30-req/min throttle), so it cannot fire on a healthy slow
# query, and it sits just above the smallest stall observed (17.5s).
wqp_request <- function(fn, deadline = 20, tries = 2) {
  for (attempt in seq_len(tries)) {
    out <- tryCatch(
      list(ok = TRUE, value = with_deadline(fn(), deadline)),
      interrupt = function(cond) list(ok = FALSE),
      error = function(cond) {
        if (is_deadline_condition(cond)) list(ok = FALSE) else stop(cond)
      }
    )
    if (isTRUE(out$ok)) return(out$value)
    message(sprintf("WQP request exceeded %ss (attempt %d of %d)",
                    deadline, attempt, tries))
  }
  # Classed so the server can tell "the Portal was slow" apart from "the
  # request was rejected" and say so in the student's own terms. The class
  # survives the future/ExtendedTask boundary (verified); the server still
  # falls back to matching the message, in case a future runtime wraps it.
  stop(structure(
    class = c("wqp_timeout", "error", "condition"),
    list(
      message = sprintf(
        "The Water Quality Portal did not respond within %s seconds (tried %s times).",
        deadline, tries
      ),
      call = NULL
    )
  ))
}

# Cooperative cancellation ------------------------------------------------
#
# A request already in flight cannot be interrupted from outside the worker
# (that is what the deadline is for), but between counties the worker can
# notice it is no longer wanted and stop. The parent signals by creating a
# sentinel file; parent and worker are always on the same machine, so a
# file is the simplest channel that crosses the process boundary.
#
# This is what makes "Stop waiting" more than cosmetic on the multi-county
# queries -- the slow ones, and the ones students actually want to abandon.
wqp_cancelled <- function(cancel_file) {
  !is.null(cancel_file) && nzchar(cancel_file) && file.exists(cancel_file)
}

stop_if_cancelled <- function(cancel_file) {
  if (wqp_cancelled(cancel_file)) {
    stop(structure(
      class = c("wqp_cancelled", "error", "condition"),
      list(message = "Search stopped.", call = NULL)
    ))
  }
  invisible(NULL)
}

# Shared result cache -----------------------------------------------------
#
# The single biggest win for classroom use. A class of 30 converges on the
# same handful of queries (the teacher's county, one year), so without a
# cache that is 30 independent trips to WQP -- and 30 independent rolls of
# its ~12% stall dice -- where it could be one. It also lowers the load the
# app puts on WQP through its single shinyapps.io IP.
#
# Keyed per *county*, not per fetch, so overlapping county selections share
# entries and a 3-county query re-run with one county added pays for one.

# Where the cache lives. dirname(tempdir()) is the machine's temp root
# (/tmp on Linux), shared by every R process in the container -- unlike
# tempdir() itself, which is private per process and would hand each Shiny
# worker and each future worker its own useless private cache.
wq_cache_dir <- function() {
  configured <- Sys.getenv("CREDIBLE_WQ_CACHE_DIR", unset = "")
  if (nzchar(configured)) configured else file.path(dirname(tempdir()), "credible-wq-cache")
}

# max_age is 24h: WQP results for a past year are immutable, and even
# current-year monitoring data reaches the Portal with a lag of days to
# weeks (USGS QA), so a day of staleness is not observable to a student.
#
# Returns NULL rather than erroring if the directory cannot be used, so a
# read-only or full filesystem degrades to "no cache" instead of taking
# every fetch down with it.
wq_cache <- function(dir = wq_cache_dir(), max_age = 24 * 60 * 60,
                     max_size = 100 * 1024^2) {
  tryCatch({
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(dir)) stop("cache directory could not be created: ", dir)
    cache <- suppressWarnings(
      cachem::cache_disk(dir = dir, max_age = max_age, max_size = max_size)
    )
    # Prove it round-trips before handing it to the fetch. cache_disk()
    # creates lazily and constructs happily against a directory it cannot
    # write to, so a read-only or full filesystem would otherwise surface
    # as a mid-fetch failure rather than as "no cache".
    probe <- "credible-cache-probe"
    cache$set(probe, TRUE)
    if (!isTRUE(cache$get(probe))) stop("cache did not round-trip")
    cache$remove(probe)
    cache
  }, error = function(e) {
    message("Result cache unavailable (", conditionMessage(e),
            ") - fetching uncached")
    NULL
  })
}

# Order-independent so the same selections in a different order hit the same
# entry. Everything that changes the response is in the key -- including
# service and dataProfile, because WQX3 and legacy return different schemas
# and must never be served for one another.
wq_cache_key <- function(q) {
  parts <- list(
    countycode         = sort(as.character(q$countycode)),
    characteristicName = sort(as.character(q$characteristicName)),
    startDateLo        = as.character(q$startDateLo),
    startDateHi        = as.character(q$startDateHi),
    sampleMedia        = as.character(q$sampleMedia),
    siteType           = as.character(q$siteType),
    service            = if (is.null(q$service)) "legacy" else as.character(q$service),
    dataProfile        = if (is.null(q$dataProfile)) "" else as.character(q$dataProfile)
  )
  paste0("wq-", rlang::hash(parts))
}

# Read-through cache around one county's fetch. Cache faults never break a
# fetch: a failed read falls through to the API, a failed write is dropped.
cached_wqp_fetch <- function(q, fn, cache = NULL) {
  if (is.null(cache)) return(fn())
  key <- wq_cache_key(q)
  hit <- tryCatch(cache$get(key), error = function(e) NULL)
  if (!is.null(hit) && !cachem::is.key_missing(hit)) return(hit)
  value <- fn()
  tryCatch(cache$set(key, value), error = function(e) NULL)
  value
}

harmonize_wq_columns <- function(frames) {
  if (length(frames) < 2) return(frames)

  col_class <- function(df, cn) {
    if (cn %in% names(df)) class(df[[cn]])[1] else NA_character_
  }
  all_cols <- unique(unlist(lapply(frames, names), use.names = FALSE))
  conflicted <- all_cols[vapply(all_cols, function(cn) {
    seen <- unique(stats::na.omit(vapply(frames, col_class, character(1), cn = cn)))
    length(seen) > 1
  }, logical(1))]

  if (length(conflicted) == 0) return(frames)

  lapply(frames, function(df) {
    for (cn in intersect(conflicted, names(df))) {
      df[[cn]] <- as.character(df[[cn]])
    }
    df
  })
}
