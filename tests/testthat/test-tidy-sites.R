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

test_that("the fetch-time county stamp takes precedence over county_code", {
  # county_code says Anderson (001) but the stamp says Knox/Blount; the
  # stamp wins because the queried county is authoritative
  meta <- make_meta(c("001", "001")) %>%
    mutate(credible_county_fips = c("093", "009"))
  out <- tidy_wq_sites(meta, "loc", "47", make_fips_clean())
  expect_identical(out$county, c("Knox County", "Blount County"))
})

test_that("duplicate site rows collapse to one site (WQX3-style metadata)", {
  # In the WQX3 path the result frame doubles as metadata, so each site
  # appears once per measurement
  meta <- bind_rows(make_meta(), make_meta(), make_meta())
  out <- tidy_wq_sites(meta, "loc", "47", make_fips_clean())
  expect_identical(nrow(out), 2L)
})
