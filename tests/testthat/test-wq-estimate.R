# The search-time estimate shown under the county picker. The model is only
# worth anything if it still reproduces the measured benchmark medians, so
# those are the test.

test_that("the estimate reproduces the measured benchmark medians", {
  # tests/benchmark-results.csv, 4 cold reps each. Tolerance is 0.5s: the
  # model is a two-term fit, not an interpolation.
  expect_equal(wq_time_estimate(1, 1), 4.6, tolerance = 0.5)   # measured  4.6
  expect_equal(wq_time_estimate(3, 1), 14.1, tolerance = 0.5)  # measured 14.1
  expect_equal(wq_time_estimate(1, 5), 9.5, tolerance = 0.5)   # measured  9.5
})

test_that("counties dominate the estimate, as measured", {
  # ~4.7s per county, linear: the API rejects multi-county requests, so the
  # app issues one per county in series.
  per_county <- wq_time_estimate(2, 1) - wq_time_estimate(1, 1)
  expect_equal(per_county, 4.7, tolerance = 0.1)
  # An extra year costs far less than an extra county
  expect_lt(wq_time_estimate(1, 2) - wq_time_estimate(1, 1), per_county)
})

test_that("the estimate grows with both counties and years", {
  expect_gt(wq_time_estimate(4, 1), wq_time_estimate(2, 1))
  expect_gt(wq_time_estimate(1, 6), wq_time_estimate(1, 2))
})

test_that("format_estimate reads like a person wrote it", {
  expect_equal(format_estimate(4.7), "about 5 seconds")
  expect_equal(format_estimate(14.1), "about 14 seconds")
  expect_equal(format_estimate(33), "about 30 seconds")
  expect_equal(format_estimate(62), "about a minute")
  expect_equal(format_estimate(140), "about 2 minutes")
  expect_equal(format_estimate(160), "about 3 minutes")
  # Exact half-minutes land wherever round() puts them (2.5 -> 2, banker's
  # rounding). Immaterial for an estimate, so it is not pinned here.
})

test_that("format_estimate never invents precision it does not have", {
  # Past a minute the gap between a clean run and a stalled one is wider
  # than the estimate, so no output should imply second-level accuracy.
  expect_false(grepl("[0-9]+\\.[0-9]", format_estimate(97.3)))
  expect_false(grepl("[0-9]+\\.[0-9]", format_estimate(4.72)))
})

test_that("the default county selection stays under the soft cap", {
  # Knox County alone is the app default; it must not open with a warning.
  expect_lte(1, wq_county_soft_cap)
  expect_gt(8, wq_county_soft_cap)  # but eight counties should warn
})

test_that("selected_year_span survives a half-initialized slider", {
  # renderUI runs before inputs settle; the estimate must not error.
  expect_equal(selected_year_span(NULL), 1L)
  expect_equal(selected_year_span(2025), 1L)
  expect_equal(selected_year_span(c(2020, 2025)), 6L)
  expect_equal(selected_year_span(c(2025, 2025)), 1L)
})
