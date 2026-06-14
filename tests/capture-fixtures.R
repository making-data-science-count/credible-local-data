# Regenerate the saved WQP API fixtures used by the testthat suite.
# Run from the app root:  Rscript tests/capture-fixtures.R
#
# Mirrors the app's fetch: one request per county (the WQP API returns
# HTTP 500 when given multiple countycode values), results combined.
# Captures both schemas the app can encounter: the primary WQX 3.0
# profile and the legacy profile used as fallback.

suppressPackageStartupMessages({
  library(dplyr)
  library(dataRetrieval)
})

qry <- list(
  countycode = c("US:47:093", "US:47:009"),  # Knox + Blount County, TN
  characteristicName = c("pH", "Temperature, water"),
  sampleMedia = "Water",
  startDateLo = "2024-06-01",
  startDateHi = "2024-12-31",
  siteType = "Stream"
)

dir.create("tests/testthat/fixtures", recursive = TRUE, showWarnings = FALSE)

# As in the app's fetch: stamp every row with the county FIPS it was
# queried for (the query is the authoritative county; WQX3 rows often
# have empty county metadata)
stamp_county <- function(df, code) {
  df$credible_county_fips <- sub("^US:[0-9]+:", "", code)
  df
}

# --- WQX 3.0 (primary): one request per county, metadata rides along ---
wqx3_one <- function(code) {
  q <- qry
  q$countycode <- code
  q$service <- "ResultWQX3"
  q$dataProfile <- "basicPhysChem"
  stamp_county(do.call(dataRetrieval::readWQPdata, q), code)
}
wqx3_raw <- dplyr::bind_rows(lapply(qry$countycode, wqx3_one))
saveRDS(wqx3_raw, "tests/testthat/fixtures/wq_raw_wqx3_knox_blount_2024.rds")
cat("Saved WQX3 fixture:", nrow(wqx3_raw), "samples\n")

# --- Legacy (fallback): separate result + station requests per county ---
legacy_one <- function(code) {
  q <- qry
  q$countycode <- code
  list(
    wq = do.call(dataRetrieval::readWQPdata, q),
    meta = stamp_county(do.call(dataRetrieval::whatWQPsites, q), code)
  )
}
parts <- lapply(qry$countycode, legacy_one)
wq_raw <- dplyr::bind_rows(lapply(parts, function(p) p$wq))
meta_df <- dplyr::distinct(dplyr::bind_rows(lapply(parts, function(p) p$meta)))
saveRDS(wq_raw, "tests/testthat/fixtures/wq_raw_knox_blount_2024.rds")
saveRDS(meta_df, "tests/testthat/fixtures/wq_sites_knox_blount_2024.rds")
cat("Saved legacy fixtures:", nrow(wq_raw), "samples,", nrow(meta_df), "sites\n")
