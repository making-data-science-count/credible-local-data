# Regenerate the saved WQP API fixtures used by the testthat suite.
# Run from the app root:  Rscript tests/capture-fixtures.R
#
# Mirrors the app's fetch: one request per county (the WQP API returns
# HTTP 500 when given multiple countycode values), results combined.

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

fetch_one <- function(code) {
  q <- qry
  q$countycode <- code
  list(
    wq = do.call(dataRetrieval::readWQPdata, q),
    meta = do.call(dataRetrieval::whatWQPsites, q)
  )
}
parts <- lapply(qry$countycode, fetch_one)
wq_raw <- dplyr::bind_rows(lapply(parts, function(p) p$wq))
meta_df <- dplyr::distinct(dplyr::bind_rows(lapply(parts, function(p) p$meta)))

dir.create("tests/testthat/fixtures", recursive = TRUE, showWarnings = FALSE)
saveRDS(wq_raw, "tests/testthat/fixtures/wq_raw_knox_blount_2024.rds")
saveRDS(meta_df, "tests/testthat/fixtures/wq_sites_knox_blount_2024.rds")
cat("Saved fixtures:", nrow(wq_raw), "samples,", nrow(meta_df), "sites\n")
