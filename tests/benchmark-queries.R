# Benchmark the water quality fetch pipeline against the live WQP API.
#
# Answers "how long does a student wait?" for a set of representative
# queries, and appends every run to tests/benchmark-results.csv so the
# numbers can be compared over time (after a dataRetrieval upgrade, a WQP
# service change, or a pipeline refactor).
#
# Usage, from the project root:
#   Rscript tests/benchmark-queries.R                  # default scenarios, 4 reps
#   Rscript tests/benchmark-queries.R --reps=6
#   Rscript tests/benchmark-queries.R --scenario=default,five-year
#   Rscript tests/benchmark-queries.R --service=legacy  # force the fallback path
#   Rscript tests/benchmark-queries.R --list            # show scenarios, don't run
#
# This hits the live API. A full default run is ~30 network requests and
# takes 10-20 minutes; it is deliberately NOT part of the test suite.
#
# EVERY REP IS COLD. The Water Quality Portal caches an identical query
# server-side: repeat the same query and it returns in ~0.1s, which tells
# us nothing about what a student waits for. So each rep shifts startDateLo
# forward by (rep - 1) days, which changes the cache key while changing the
# workload only marginally (a few days out of a year or more). Without this
# the 2nd..Nth rep of a scenario just measure the cache.
#
# WHY SEVERAL REPS: WQP stalls individual requests for no visible reason —
# measured across four counties, seven of eight requests landed in a tight
# 4.1-6.3s band and one took 27.4s. A single sample can't tell a stall from
# a genuinely expensive query, so the summary reports min (clean run),
# median (typical), and max (worst seen), and counts likely stalls. Trust
# the median; read a single high max as noise until it repeats.
#
# WHAT ACTUALLY COSTS TIME (medians, 4 cold reps each, 2026-07-30):
#   1 county,  1 year,  5 params ->  4.6s   <- the app default
#   1 county,  1 year, 16 params ->  5.1s   parameter count: negligible
#   1 county,  5 years, 5 params ->  9.5s   year range: modest
#   3 counties, 1 year, 5 params -> 14.1s   county count: ~4.7s each, linear
# County *size* does not matter (77-row and 1093-row counties both ~5s);
# county *count* does, because the API rejects multi-county requests so we
# issue one serial request per county. Anything above these numbers in a
# single sample is far more likely a stall than a real cost.
#
# NOTE: the fetch block below mirrors the ExtendedTask body in app.R
# (search "ExtendedTask for Water Quality API calls"). If that fetch logic
# changes — services, dataProfile, ignore_attributes, per-county loop —
# update fetch_wq() here to match or the timings stop describing the app.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(janitor)
  library(dataRetrieval)
})

# Run from anywhere: locate the project root by walking up for app.R.
proj_root <- normalizePath(getwd())
while (!file.exists(file.path(proj_root, "app.R")) && dirname(proj_root) != proj_root) {
  proj_root <- dirname(proj_root)
}
if (!file.exists(file.path(proj_root, "app.R"))) {
  stop("Could not locate the project root (no app.R found above ", getwd(), ")")
}

# Source every file in R/, exactly as Shiny does, so the benchmark uses the
# app's real helpers (stamp_county, harmonize_wq_columns, the pipeline)
# rather than copies that can drift.
for (f in list.files(file.path(proj_root, "R"), pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

RESULTS_CSV <- file.path(proj_root, "tests", "benchmark-results.csv")

# ---------------------------------------------------------------------------
# FIPS crosswalk — same derivation as app.R (fips, name, state columns),
# trimmed to the columns process_wq_result() and the scenarios need.
# ---------------------------------------------------------------------------
state_lookup <- data.frame(
  state_abbr = c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
                 "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
                 "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
                 "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
                 "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC"),
  state_name = c("Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado",
                 "Connecticut", "Delaware", "Florida", "Georgia", "Hawaii", "Idaho",
                 "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana",
                 "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota",
                 "Mississippi", "Missouri", "Montana", "Nebraska", "Nevada",
                 "New Hampshire", "New Jersey", "New Mexico", "New York",
                 "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon",
                 "Pennsylvania", "Rhode Island", "South Carolina", "South Dakota",
                 "Tennessee", "Texas", "Utah", "Vermont", "Virginia", "Washington",
                 "West Virginia", "Wisconsin", "Wyoming", "District of Columbia"),
  stringsAsFactors = FALSE
)

fips_clean <- read_csv(file.path(proj_root, "fips-xwalk.csv"), show_col_types = FALSE) %>%
  mutate(
    full_fips = sprintf("%05d", as.numeric(fips)),
    state_fips = substr(full_fips, 1, 2),
    county_fips = substr(full_fips, 3, 5),
    county_display = name
  ) %>%
  left_join(state_lookup, by = c("state" = "state_abbr")) %>%
  select(state_fips, county_fips, state_name, county_display) %>%
  filter(!is.na(state_fips), !is.na(county_fips), !is.na(state_name))

lookup_fips <- function(state, counties) {
  hit <- fips_clean %>% filter(state_name == state, county_display %in% counties)
  if (nrow(hit) != length(counties)) {
    stop("FIPS lookup failed for ", state, ": ", paste(counties, collapse = ", "),
         " (matched ", nrow(hit), " of ", length(counties), ")")
  }
  hit
}

# ---------------------------------------------------------------------------
# Scenarios: what students actually ask for.
#
# The app's defaults are Knox County, Tennessee · last year · the 5 headline
# parameters (pH, Turbidity, Temperature, Dissolved oxygen, E. coli), so
# `default` is the single most important number here. The rest bracket it:
# a small rural county (floor), a large urban county and a 5-year range
# (ceiling), and a multi-county query (the per-county serial loop).
# ---------------------------------------------------------------------------
CORE_PARAMS <- c("pH", "Turbidity", "Temperature", "Dissolved oxygen", "Escherichia coli")
ALL_PARAMS  <- names(wq_characteristic_map)
this_year   <- as.integer(format(Sys.Date(), "%Y"))
last_year   <- this_year - 1L

SCENARIOS <- list(
  list(id = "default", label = "App default: Knox Co. TN, 1 year, 5 params",
       state = "Tennessee", counties = "Knox County",
       years = c(last_year, last_year), params = CORE_PARAMS),

  list(id = "small-county", label = "Small rural county: Pickett Co. TN, 1 year, 5 params",
       state = "Tennessee", counties = "Pickett County",
       years = c(last_year, last_year), params = CORE_PARAMS),

  list(id = "large-county", label = "Large urban county: Los Angeles Co. CA, 1 year, 5 params",
       state = "California", counties = "Los Angeles County",
       years = c(last_year, last_year), params = CORE_PARAMS),

  list(id = "five-year", label = "5-year range: Knox Co. TN, 5 years, 5 params",
       state = "Tennessee", counties = "Knox County",
       years = c(last_year - 4L, last_year), params = CORE_PARAMS),

  list(id = "multi-county", label = "3 counties: Knox/Blount/Sevier TN, 1 year, 5 params",
       state = "Tennessee",
       counties = c("Knox County", "Blount County", "Sevier County"),
       years = c(last_year, last_year), params = CORE_PARAMS),

  list(id = "all-params", label = "All 16 parameters: Knox Co. TN, 1 year",
       state = "Tennessee", counties = "Knox County",
       years = c(last_year, last_year), params = ALL_PARAMS)
)
names(SCENARIOS) <- vapply(SCENARIOS, `[[`, "", "id")

# ---------------------------------------------------------------------------
# Fetch — mirrors the ExtendedTask body in app.R
# ---------------------------------------------------------------------------
read_wqp_results <- function(q) {
  do.call(dataRetrieval::readWQPdata, c(q, list(ignore_attributes = TRUE)))
}

wqx3_county <- function(qry, code) {
  q <- qry
  q$countycode <- code
  q$service <- "ResultWQX3"
  q$dataProfile <- "basicPhysChem"
  wq <- stamp_county(read_wqp_results(q), code)
  list(wq = wq, meta = wq)
}

legacy_county <- function(qry, code) {
  q <- qry
  q$countycode <- code
  list(
    wq = read_wqp_results(q),
    meta = stamp_county(do.call(dataRetrieval::whatWQPsites, q), code)
  )
}

# Returns list(wq_raw, meta_df, service_used, per_county_secs).
# `service` is "auto" (WQX3 with legacy fallback, exactly what the app does),
# "wqx3" (no fallback — a WQX3 failure is an error), or "legacy" (fallback only).
fetch_wq <- function(qry, service = "auto") {
  run_all <- function(fetch_county) {
    per_county <- numeric(0)
    parts <- lapply(qry$countycode, function(code) {
      t <- system.time(p <- fetch_county(qry, code))[["elapsed"]]
      per_county <<- c(per_county, t)
      p
    })
    list(
      wq_raw = dplyr::bind_rows(
        harmonize_wq_columns(lapply(parts, function(p) p$wq))
      ),
      meta_df = dplyr::distinct(dplyr::bind_rows(
        harmonize_wq_columns(lapply(parts, function(p) p$meta))
      )),
      per_county_secs = per_county
    )
  }

  if (service == "legacy") {
    out <- run_all(legacy_county); out$service_used <- "legacy"; return(out)
  }
  if (service == "wqx3") {
    out <- run_all(wqx3_county); out$service_used <- "wqx3"; return(out)
  }
  tryCatch({
    out <- run_all(wqx3_county); out$service_used <- "wqx3"; out
  }, error = function(e) {
    message("    WQX3 failed (", conditionMessage(e), ") — falling back to legacy")
    out <- run_all(legacy_county); out$service_used <- "legacy-fallback"; out
  })
}

# ---------------------------------------------------------------------------
# One timed run of one scenario
# ---------------------------------------------------------------------------
run_scenario <- function(sc, rep, service) {
  info <- lookup_fips(sc$state, sc$counties)
  state_fips <- info$state_fips[1]
  location <- paste0(paste(sc$counties, collapse = ", "), ", ", sc$state)

  # Shift the window start by (rep - 1) days so each rep is a fresh cache
  # key at WQP and therefore a genuine cold measurement. A few days out of
  # a year-plus window barely moves the workload.
  jitter_days <- rep - 1L
  start_date <- as.Date(paste0(sc$years[1], "-01-01")) + jitter_days

  qry <- list(
    countycode = paste0("US:", state_fips, ":", info$county_fips),
    characteristicName = expand_wq_characteristics(sc$params),
    sampleMedia = "Water",
    startDateLo = format(start_date, "%Y-%m-%d"),
    startDateHi = paste0(sc$years[2], "-12-31"),
    siteType = "Stream"
  )

  fetch_secs <- NA_real_; process_secs <- NA_real_
  n_raw <- NA_integer_; n_rows <- NA_integer_; n_sites <- NA_integer_
  service_used <- NA_character_; slowest_county <- NA_real_
  status <- "ok"; err <- ""

  tryCatch({
    t0 <- proc.time()[["elapsed"]]
    f <- fetch_wq(qry, service)
    fetch_secs <- proc.time()[["elapsed"]] - t0
    service_used <- f$service_used
    slowest_county <- max(f$per_county_secs)
    n_raw <- nrow(f$wq_raw)

    if (n_raw == 0) {
      status <- "empty"
      process_secs <- 0; n_rows <- 0L; n_sites <- 0L
    } else {
      t1 <- proc.time()[["elapsed"]]
      res <- process_wq_result(
        wq_raw = f$wq_raw, meta_df = f$meta_df, location = location,
        state_fips = state_fips, state_name = sc$state, fips_clean = fips_clean
      )
      process_secs <- proc.time()[["elapsed"]] - t1
      n_rows <- nrow(res$wide_data)
      n_sites <- res$n_sites_total
    }
  }, error = function(e) {
    status <<- "error"; err <<- conditionMessage(e)
  })

  tibble(
    run_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    scenario = sc$id, label = sc$label, rep = rep,
    # Every rep is cold by construction (see jitter_days above).
    jitter_days = jitter_days,
    n_counties = length(sc$counties), n_params = length(sc$params),
    n_years = sc$years[2] - sc$years[1] + 1L,
    service_requested = service, service_used = service_used,
    fetch_secs = round(fetch_secs, 2),
    slowest_county_secs = round(slowest_county, 2),
    process_secs = round(process_secs, 3),
    total_secs = round(fetch_secs + process_secs, 2),
    n_raw_rows = n_raw, n_wide_rows = n_rows, n_sites = n_sites,
    status = status, error = err,
    dataRetrieval_version = as.character(packageVersion("dataRetrieval")),
    r_version = paste0(R.version$major, ".", R.version$minor)
  )
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
arg_val <- function(name, default) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit) == 0) default else sub(paste0("^--", name, "="), "", hit[1])
}

if ("--list" %in% args) {
  cat("Scenarios:\n")
  for (sc in SCENARIOS) cat(sprintf("  %-14s %s\n", sc$id, sc$label))
  quit(status = 0)
}

reps <- as.integer(arg_val("reps", "4"))
service <- arg_val("service", "auto")
want <- arg_val("scenario", "")
selected <- if (nzchar(want)) {
  ids <- trimws(strsplit(want, ",")[[1]])
  unknown <- setdiff(ids, names(SCENARIOS))
  if (length(unknown)) stop("Unknown scenario(s): ", paste(unknown, collapse = ", "))
  SCENARIOS[ids]
} else SCENARIOS

cat(sprintf("Benchmarking %d scenario(s) x %d rep(s), service=%s\n",
            length(selected), reps, service))
cat(sprintf("dataRetrieval %s, R %s.%s\n\n",
            packageVersion("dataRetrieval"), R.version$major, R.version$minor))

results <- list()
for (sc in selected) {
  cat(sprintf("%-14s %s\n", sc$id, sc$label))
  for (r in seq_len(reps)) {
    row <- run_scenario(sc, r, service)
    results[[length(results) + 1]] <- row
    cat(sprintf("    rep %d: fetch %6.2fs + process %5.3fs = %6.2fs  [%s, %s rows, %s sites, %s]\n",
                r, row$fetch_secs, row$process_secs, row$total_secs,
                row$service_used, row$n_raw_rows, row$n_sites, row$status))
  }
}

all_rows <- bind_rows(results)

# Append to the history file so runs are comparable over time.
if (file.exists(RESULTS_CSV)) {
  write_csv(all_rows, RESULTS_CSV, append = TRUE)
} else {
  write_csv(all_rows, RESULTS_CSV)
}
cat(sprintf("\nAppended %d rows to %s\n", nrow(all_rows), RESULTS_CSV))

# ---------------------------------------------------------------------------
# Summary: this run, then drift against previous runs
# ---------------------------------------------------------------------------
cold <- all_rows %>% filter(status %in% c("ok", "empty"))

cat("\n=== This run (every rep a cold fetch) ===\n")
this_run <- cold %>%
  group_by(scenario) %>%
  summarise(
    n = n(),
    min = round(min(total_secs, na.rm = TRUE), 1),
    median = round(median(total_secs, na.rm = TRUE), 1),
    max = round(max(total_secs, na.rm = TRUE), 1),
    # A rep more than 3x the scenario's own best is a WQP stall, not the
    # cost of the query. Counting them keeps the median honest.
    stalls = sum(total_secs > 3 * min(total_secs, na.rm = TRUE), na.rm = TRUE),
    process = round(median(process_secs, na.rm = TRUE), 3),
    rows = max(n_raw_rows, na.rm = TRUE),
    status = paste(unique(status), collapse = "/"),
    .groups = "drop"
  ) %>%
  arrange(desc(median))
print(as.data.frame(this_run), row.names = FALSE)

failed <- all_rows %>% filter(status == "error")
if (nrow(failed) > 0) {
  cat("\nERRORS:\n")
  for (i in seq_len(nrow(failed))) {
    cat(sprintf("  %s rep %d: %s\n", failed$scenario[i], failed$rep[i], failed$error[i]))
  }
}

# The split that matters for where to optimise: our own R code vs. the API.
if (nrow(cold) > 0 && sum(cold$total_secs, na.rm = TRUE) > 0) {
  cat("\nOur processing as a share of wait time: ",
      sprintf("%.1f%%", 100 * sum(cold$process_secs, na.rm = TRUE) /
                          sum(cold$total_secs, na.rm = TRUE)),
      "  (the rest is the WQP API)\n", sep = "")
}

# run_at must stay character: read_csv would otherwise parse it to POSIXct,
# and the %in% below (against the character timestamps we just wrote) would
# never match — leaking this run's own rows into the "prior" comparison.
history <- read_csv(RESULTS_CSV, show_col_types = FALSE,
                    col_types = cols(run_at = col_character()))
prior <- history %>%
  filter(!run_at %in% all_rows$run_at, status %in% c("ok", "empty"))
if (nrow(prior) > 0) {
  cat("\n=== Drift vs. previous runs ===\n")
  drift <- prior %>%
    group_by(scenario) %>%
    summarise(prior_median = round(median(total_secs, na.rm = TRUE), 1),
              prior_n = n(), .groups = "drop") %>%
    inner_join(this_run %>% select(scenario, median), by = "scenario") %>%
    mutate(change_pct = round(100 * (median - prior_median) / prior_median, 1))
  print(as.data.frame(drift), row.names = FALSE)
  # WQP latency is noisy, so only a large move on a slow scenario is signal.
  regressed <- drift %>% filter(change_pct > 100, median > 20)
  if (nrow(regressed) > 0) {
    cat("\nWARNING: >2x slower than history and over 20s: ",
        paste(regressed$scenario, collapse = ", "), "\n", sep = "")
  }
} else {
  cat("\n(No prior runs to compare against — this is the baseline.)\n")
}
