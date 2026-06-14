# Integration tests against saved real WQP API responses, one per schema
# the app can encounter: WQX 3.0 (primary) and legacy (fallback).
# (Regenerate with: Rscript tests/capture-fixtures.R)

expect_valid_pipeline_result <- function(res) {
  expect_gt(nrow(res$wide_data), 0)

  # Multi-county: each row carries its own county, not the combined string
  expect_in(c("Knox County", "Blount County"), unique(res$wide_data$county))

  # Synonym collapsing: the fixture contains "Temperature, water" but the
  # column is the student-facing "Temperature"
  expect_true("Temperature" %in% names(res$wide_data))
  expect_false("Temperature, water" %in% names(res$wide_data))

  expect_true(is.numeric(res$wide_data$pH))
  expect_true(is.numeric(res$wide_data$Temperature))
  expect_false(any(vapply(res$wide_data, is.list, logical(1))))

  expect_identical(res$n_sites_total, length(unique(res$long_data$site_id)))
  expect_lte(nrow(res$available_sites), 5)
  expect_in(res$found_parameters, names(wq_characteristic_map))
  expect_gte(res$n_dropped_units, 0)
}

test_that("full pipeline processes a real WQX 3.0 response", {
  # In the WQX3 path, site metadata rides along on the result rows, so the
  # same frame serves as both samples and metadata (as in the app's fetch)
  wqx3_raw <- read_fixture("wq_raw_wqx3_knox_blount_2024.rds")

  res <- process_wq_result(
    wq_raw     = wqx3_raw,
    meta_df    = wqx3_raw,
    location   = "Knox County, Blount County, Tennessee",
    state_fips = "47",
    state_name = "Tennessee",
    fips_clean = make_fips_clean()
  )
  expect_valid_pipeline_result(res)
})

test_that("full pipeline processes a real legacy WQP response", {
  wq_raw  <- read_fixture("wq_raw_knox_blount_2024.rds")
  meta_df <- read_fixture("wq_sites_knox_blount_2024.rds")

  res <- process_wq_result(
    wq_raw     = wq_raw,
    meta_df    = meta_df,
    location   = "Knox County, Blount County, Tennessee",
    state_fips = "47",
    state_name = "Tennessee",
    fips_clean = make_fips_clean()
  )
  expect_valid_pipeline_result(res)
})

test_that("both schemas produce equivalent measurement counts", {
  wqx3 <- janitor::clean_names(read_fixture("wq_raw_wqx3_knox_blount_2024.rds"))
  legacy <- janitor::clean_names(read_fixture("wq_raw_knox_blount_2024.rds"))
  s3 <- tidy_wq_samples(wqx3)
  sl <- tidy_wq_samples(legacy)
  # Same query window; WQX3 must return at least everything legacy has
  expect_gte(nrow(s3), nrow(sl))
  expect_setequal(unique(s3$parameter), unique(sl$parameter))
})
