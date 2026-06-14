suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(janitor)
})

# Source the app's R/ helpers (the same files Shiny auto-sources)
for (f in list.files(testthat::test_path("..", "..", "R"),
                     pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Minimal FIPS crosswalk covering the fixture counties
make_fips_clean <- function() {
  tibble(
    state_fips     = c("47", "47", "47"),
    county_fips    = c("093", "009", "001"),
    county_display = c("Knox County", "Blount County", "Anderson County")
  )
}

# One long-format measurement row, with overridable fields
make_long <- function(parameter, value, unit, site_id = "S1",
                      site_name = "First Creek", date = as.Date("2024-06-01")) {
  tibble(
    site_id = site_id, site_name = site_name, county = "Knox County",
    lat = 35.9, lon = -83.9, date = date,
    parameter = parameter, value = value, unit = unit
  )
}

# Synthetic cleaned site metadata (column names as after janitor::clean_names)
make_meta <- function(county_code = c("093", "009")) {
  tibble(
    monitoring_location_identifier = c("S1", "S2"),
    monitoring_location_name = c("First Creek", "Second Creek"),
    latitude_measure = c(35.9, 35.7),
    longitude_measure = c(-83.9, -83.95),
    county_code = county_code
  )
}

read_fixture <- function(name) readRDS(testthat::test_path("fixtures", name))
