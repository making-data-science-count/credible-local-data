# Regression tests for the two live-API bugs fixed in R/fetch-wq.R. Both
# were invisible to synthetic tests and to the saved fixtures: one needs a
# county with no matching data, the other needs two counties whose CSV
# columns were typed differently by the WQP parser.

test_that("stamp_county stamps the queried FIPS onto every row", {
  df <- data.frame(a = 1:3)
  out <- stamp_county(df, "US:47:093")
  expect_equal(out$credible_county_fips, rep("093", 3))
})

test_that("stamp_county handles a zero-row result without erroring", {
  # A county/year/parameter combination with no data returns 0 rows but
  # many columns. `df$col <- "093"` on that throws "replacement has 1 row,
  # data has 0", which used to kill the whole fetch (both services) and
  # surface as "Oops! Something went wrong" instead of "No data found".
  empty <- data.frame(a = numeric(0), b = character(0))
  expect_no_error(out <- stamp_county(empty, "US:47:093"))
  expect_equal(nrow(out), 0)
  expect_true("credible_county_fips" %in% names(out))
  expect_type(out$credible_county_fips, "character")
})

test_that("an empty county still binds with a non-empty one", {
  # The multi-county path binds per-county frames; an empty county must not
  # disturb the combined result, so the server reaches its own
  # nrow(wq_raw) == 0 branch only when *every* county came back empty.
  empty <- stamp_county(data.frame(a = numeric(0)), "US:47:009")
  full  <- stamp_county(data.frame(a = c(1, 2)), "US:47:093")
  combined <- dplyr::bind_rows(harmonize_wq_columns(list(full, empty)))
  expect_equal(nrow(combined), 2)
  expect_equal(combined$credible_county_fips, c("093", "093"))
})

test_that("all-empty counties bind to a zero-row frame", {
  frames <- list(stamp_county(data.frame(a = numeric(0)), "US:47:093"),
                 stamp_county(data.frame(a = numeric(0)), "US:47:009"))
  expect_equal(nrow(dplyr::bind_rows(harmonize_wq_columns(frames))), 0)
})

test_that("harmonize_wq_columns leaves consistently typed frames alone", {
  frames <- list(data.frame(x = 1, y = "a"), data.frame(x = 2, y = "b"))
  out <- harmonize_wq_columns(frames)
  expect_type(out[[1]]$x, "double")
  expect_identical(out, frames)
})

test_that("harmonize_wq_columns rescues the real multi-county type clash", {
  # Exactly the shape observed live: DetectionLimit_MeasureA came back
  # numeric for Knox and Blount and character for Sevier (its slice mixed
  # blank strings with numbers). bind_rows() aborted, the WQX3 tryCatch
  # swallowed it, and the fetch silently dropped to the legacy service --
  # which serves no USGS data newer than March 2024.
  knox   <- data.frame(id = "a", DetectionLimit_MeasureA = 1,      stringsAsFactors = FALSE)
  blount <- data.frame(id = "b", DetectionLimit_MeasureA = 5,      stringsAsFactors = FALSE)
  sevier <- data.frame(id = "c", DetectionLimit_MeasureA = "1750.7", stringsAsFactors = FALSE)

  expect_error(dplyr::bind_rows(list(knox, blount, sevier)), "Can't combine")

  out <- harmonize_wq_columns(list(knox, blount, sevier))
  combined <- dplyr::bind_rows(out)
  expect_equal(nrow(combined), 3)
  expect_type(combined$DetectionLimit_MeasureA, "character")
  expect_equal(combined$DetectionLimit_MeasureA, c("1", "5", "1750.7"))
  # Untouched columns keep their type
  expect_type(combined$id, "character")
})

test_that("harmonize_wq_columns only coerces the columns that disagree", {
  a <- data.frame(keep = 1.5, clash = 1, stringsAsFactors = FALSE)
  b <- data.frame(keep = 2.5, clash = "x", stringsAsFactors = FALSE)
  out <- harmonize_wq_columns(list(a, b))
  expect_type(out[[1]]$keep, "double")
  expect_type(out[[1]]$clash, "character")
})

test_that("harmonize_wq_columns tolerates frames with different columns", {
  # A column absent from one frame is not a conflict; bind_rows fills NA.
  a <- data.frame(x = 1, only_a = "p", stringsAsFactors = FALSE)
  b <- data.frame(x = 2, only_b = "q", stringsAsFactors = FALSE)
  combined <- dplyr::bind_rows(harmonize_wq_columns(list(a, b)))
  expect_equal(nrow(combined), 2)
  expect_true(all(c("only_a", "only_b") %in% names(combined)))
})

test_that("harmonize_wq_columns passes through a single frame", {
  one <- list(data.frame(x = 1))
  expect_identical(harmonize_wq_columns(one), one)
})

# ---- request deadline + retry ------------------------------------------
# WQP sets no timeout on this path, so a stalled request hangs until the
# Portal answers (210s observed). These cover the retry, and specifically
# that both signal shapes count as a deadline: an R-level limit arrives as
# an error, but a limit that fires inside curl arrives as an *interrupt*
# with an empty message, which tryCatch(error=) never sees.

test_that("wqp_request returns the value when the call is fast", {
  expect_equal(wqp_request(function() 42, deadline = 5), 42)
})

test_that("wqp_request retries after a deadline and returns the retry", {
  attempts <- 0
  out <- wqp_request(function() {
    attempts <<- attempts + 1
    if (attempts == 1) repeat {}  # never returns; the deadline stops it
    "second attempt"
  }, deadline = 1, tries = 2)
  expect_equal(attempts, 2)
  expect_equal(out, "second attempt")
})

test_that("wqp_request gives up after the last try", {
  attempts <- 0
  expect_error(
    wqp_request(function() { attempts <<- attempts + 1; repeat {} },
                deadline = 1, tries = 2),
    "did not respond within"
  )
  expect_equal(attempts, 2)
})

test_that("wqp_request does not retry real API errors", {
  # Non-deadline errors must propagate untouched and on the first attempt,
  # or the WQX3 -> legacy fallback would be delayed and retried needlessly.
  attempts <- 0
  expect_error(
    wqp_request(function() { attempts <<- attempts + 1; stop("HTTP 400") },
                deadline = 5),
    "HTTP 400"
  )
  expect_equal(attempts, 1)
})

test_that("an interrupt counts as a deadline, an ordinary error does not", {
  # The curl case: empty message, condition class "interrupt".
  interrupt_cond <- structure(
    class = c("interrupt", "condition"),
    list(message = "", call = NULL)
  )
  expect_true(is_deadline_condition(interrupt_cond))
  expect_true(is_deadline_condition(simpleError("reached elapsed time limit")))
  expect_false(is_deadline_condition(simpleError("HTTP 500")))
})

test_that("wqp_request retries an interrupt, not just an error", {
  attempts <- 0
  out <- wqp_request(function() {
    attempts <<- attempts + 1
    if (attempts == 1) {
      stop(structure(class = c("interrupt", "condition"),
                     list(message = "", call = NULL)))
    }
    "recovered"
  }, deadline = 5, tries = 2)
  expect_equal(out, "recovered")
  expect_equal(attempts, 2)
})

test_that("with_deadline clears the limit again afterwards", {
  # The limit is process-global. If it survives the call, the next thing
  # this worker does dies instead -- including the retry itself.
  expect_error(with_deadline(repeat {}, seconds = 1))
  start <- Sys.time()
  Sys.sleep(1.5)
  expect_no_error(with_deadline(sum(1:10), seconds = 30))
  expect_gt(as.numeric(difftime(Sys.time(), start, units = "secs")), 1)
})

# ---- result cache -------------------------------------------------------

test_that("wq_cache_key ignores county and parameter order", {
  a <- list(countycode = c("US:47:093", "US:47:009"),
            characteristicName = c("pH", "Temperature, water"),
            startDateLo = "2025-01-01", startDateHi = "2025-12-31",
            service = "ResultWQX3")
  b <- a
  b$countycode <- rev(a$countycode)
  b$characteristicName <- rev(a$characteristicName)
  expect_identical(wq_cache_key(a), wq_cache_key(b))
})

test_that("wq_cache_key separates anything that changes the response", {
  base <- list(countycode = "US:47:093", characteristicName = "pH",
               startDateLo = "2025-01-01", startDateHi = "2025-12-31",
               service = "ResultWQX3", dataProfile = "basicPhysChem")
  differs <- function(field, value) {
    other <- base
    other[[field]] <- value
    expect_false(identical(wq_cache_key(base), wq_cache_key(other)),
                 label = paste("key changes with", field))
  }
  differs("countycode", "US:47:009")
  differs("characteristicName", "Temperature, water")
  differs("startDateLo", "2024-01-01")
  differs("startDateHi", "2026-12-31")
  # WQX3 and legacy return different schemas, so one must never be served
  # in place of the other.
  differs("service", "Result")
  differs("dataProfile", "resultPhysChem")
})

test_that("cached_wqp_fetch calls the API once, then serves from cache", {
  cache <- cachem::cache_mem()
  q <- list(countycode = "US:47:093", characteristicName = "pH",
            service = "ResultWQX3")
  calls <- 0
  fetch <- function() { calls <<- calls + 1; list(wq = data.frame(x = 1)) }

  first <- cached_wqp_fetch(q, fetch, cache)
  second <- cached_wqp_fetch(q, fetch, cache)
  expect_equal(calls, 1)
  expect_identical(first, second)

  # A different county is a different entry
  q2 <- q; q2$countycode <- "US:47:009"
  cached_wqp_fetch(q2, fetch, cache)
  expect_equal(calls, 2)
})

test_that("cached_wqp_fetch caches empty results too", {
  # A county with no matching data is a valid answer; re-asking WQP for it
  # every time would spend a whole request to learn nothing.
  cache <- cachem::cache_mem()
  q <- list(countycode = "US:06:037", service = "ResultWQX3")
  calls <- 0
  empty <- function() { calls <<- calls + 1; list(wq = data.frame(), meta = data.frame()) }
  cached_wqp_fetch(q, empty, cache)
  cached_wqp_fetch(q, empty, cache)
  expect_equal(calls, 1)
})

test_that("cached_wqp_fetch works with no cache at all", {
  # wq_cache() returns NULL on a read-only or full filesystem; the fetch
  # must degrade to uncached rather than failing.
  calls <- 0
  fetch <- function() { calls <<- calls + 1; "value" }
  expect_equal(cached_wqp_fetch(list(a = 1), fetch, NULL), "value")
  expect_equal(cached_wqp_fetch(list(a = 1), fetch, NULL), "value")
  expect_equal(calls, 2)
})

test_that("a broken cache falls through to the API instead of erroring", {
  broken <- list(
    get = function(...) stop("disk gone"),
    set = function(...) stop("disk gone")
  )
  expect_equal(cached_wqp_fetch(list(a = 1), function() "fresh", broken), "fresh")
})

test_that("wq_cache returns NULL rather than erroring on an unusable dir", {
  # A path under a regular file can never be a directory.
  blocker <- tempfile(); file.create(blocker)
  on.exit(unlink(blocker))
  expect_null(suppressMessages(wq_cache(dir = file.path(blocker, "cache"))))
})

test_that("the cache directory is shared between processes, not per-process", {
  # tempdir() is private to each R process, so a cache under it would give
  # every Shiny and future worker its own useless copy. The default must
  # sit in the shared temp root instead.
  expect_false(startsWith(wq_cache_dir(), tempdir()))
  expect_equal(dirname(wq_cache_dir()), dirname(tempdir()))
  withr::with_envvar(c(CREDIBLE_WQ_CACHE_DIR = "/somewhere/else"), {
    expect_equal(wq_cache_dir(), "/somewhere/else")
  })
})

# ---- cancellation -------------------------------------------------------

test_that("stop_if_cancelled only fires once the sentinel exists", {
  flag <- tempfile()
  expect_silent(stop_if_cancelled(flag))
  file.create(flag)
  on.exit(unlink(flag))
  expect_error(stop_if_cancelled(flag), class = "wqp_cancelled")
})

test_that("no sentinel path means never cancelled", {
  expect_silent(stop_if_cancelled(NULL))
  expect_silent(stop_if_cancelled(""))
  expect_false(wqp_cancelled(NULL))
})

test_that("a timeout is classed so the server can give it its own message", {
  err <- tryCatch(
    wqp_request(function() repeat {}, deadline = 1, tries = 1),
    error = function(e) e
  )
  expect_s3_class(err, "wqp_timeout")
  # The server also matches on the message as a backstop
  expect_match(conditionMessage(err), "did not respond within")
})

test_that("character lat/lon survive the pipeline as numbers", {
  # If a lat/lon column ever gets character-coerced by harmonization,
  # CODAP still needs numbers to place map points.
  meta <- make_meta()
  meta$latitude_measure <- as.character(meta$latitude_measure)
  meta$longitude_measure <- as.character(meta$longitude_measure)
  sites <- tidy_wq_sites(meta, "Knox County, Tennessee", "47", make_fips_clean())
  expect_type(sites$lat, "double")
  expect_type(sites$lon, "double")
  expect_equal(sites$lat, c(35.9, 35.7))
})
