test_that("sites resolve to their own counties via the FIPS crosswalk", {
  out <- tidy_wq_sites(make_meta(), "Knox County, Blount County, Tennessee",
                       "47", make_fips_clean())
  expect_identical(out$county, c("Knox County", "Blount County"))
  expect_identical(names(out), c("site_id", "site_name", "county", "lat", "lon"))
})

test_that("unknown county codes fall back to the location string", {
  out <- tidy_wq_sites(make_meta(c("999", "093")), "Somewhere, Tennessee",
                       "47", make_fips_clean())
  expect_identical(out$county, c("Somewhere, Tennessee", "Knox County"))
})

test_that("a missing county_code column falls back for all sites", {
  meta <- make_meta() %>% select(-county_code)
  out <- tidy_wq_sites(meta, "Somewhere, Tennessee", "47", make_fips_clean())
  expect_identical(out$county, rep("Somewhere, Tennessee", 2))
})

test_that("county codes are matched within the queried state only", {
  # County 093 exists in the crosswalk for state 47 but we query state 01
  fips <- make_fips_clean()
  out <- tidy_wq_sites(make_meta(), "loc", "01", fips)
  expect_identical(out$county, rep("loc", 2))
})

test_that("unpadded county codes are normalized before matching", {
  out <- tidy_wq_sites(make_meta(c("93", "9")), "loc", "47", make_fips_clean())
  expect_identical(out$county, c("Knox County", "Blount County"))
})
