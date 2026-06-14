# Water quality data processing pipeline.
#
# Pure data-frame transforms extracted from the Shiny server so they can be
# unit tested (see tests/testthat/). Shiny auto-sources every file in R/
# when the app starts; the server calls process_wq_result() from the
# fetch-completion observer.

# Tidy raw WQP sample results into one row per measurement. Characteristic
# names are collapsed to the student-facing labels (see R/wq-parameters.R)
# so synonymous characteristics share one column after pivoting.
tidy_wq_samples <- function(wq_clean) {
  wq_clean %>%
    transmute(
      site_id = monitoring_location_identifier,
      date = activity_start_date,
      parameter = normalize_wq_parameter(characteristic_name),
      value = as.numeric(result_measure_value),
      unit = result_measure_measure_unit_code
    )
}

# Tidy WQP site metadata and resolve each site to its own county name so
# multi-county queries label every row correctly (not with the combined
# location string, which is the fallback when the county can't be resolved).
tidy_wq_sites <- function(meta, location, state_fips, fips_clean) {
  lat_col <- grep("latitude", names(meta), value = TRUE)[1]
  lon_col <- grep("longitude", names(meta), value = TRUE)[1]
  cnty_col <- grep("county_code", names(meta), value = TRUE)[1]

  meta %>%
    transmute(
      site_id = monitoring_location_identifier,
      site_name = monitoring_location_name,
      lat = .data[[lat_col]],
      lon = .data[[lon_col]],
      county_fips = if (is.na(cnty_col)) NA_character_
                    else sprintf("%03d", suppressWarnings(as.integer(.data[[cnty_col]])))
    ) %>%
    left_join(
      fips_clean %>%
        filter(state_fips == .env$state_fips) %>%
        select(county_fips, county_display),
      by = "county_fips"
    ) %>%
    mutate(county = coalesce(county_display, location)) %>%
    select(site_id, site_name, county, lat, lon)
}

# Standardise units in two steps so pivot_wider never averages values
# measured on different scales. Returns list(data = <standardised rows>,
# n_dropped = <rows removed because their unit couldn't be reconciled>).
standardize_wq_units <- function(wq_data) {
  # Step 1: convert known unit variants to a canonical unit.
  ug_units <- c("ug/l", "µg/l", "ug/L", "µg/L")
  f_units  <- c("deg F", "deg f")
  ms_units <- c("mS/cm", "ms/cm")
  converted <- wq_data %>%
    mutate(
      value = case_when(
        unit %in% ug_units ~ value / 1000,         # µg/L -> mg/L
        unit %in% f_units  ~ (value - 32) * 5 / 9, # °F -> °C
        unit %in% ms_units ~ value * 1000,         # mS/cm -> µS/cm
        TRUE ~ value
      ),
      unit = case_when(
        unit %in% ug_units ~ "mg/L",
        unit %in% f_units  ~ "deg C",
        unit %in% c(ms_units, "umho/cm") ~ "uS/cm", # umho/cm == uS/cm
        TRUE ~ unit
      )
    )

  # Step 2: within each parameter, keep only the most common unit. The key
  # is lowercased so case variants ("mg/L" vs "mg/l") count as one unit.
  filtered <- converted %>%
    mutate(.unit_key = tolower(coalesce(unit, "(none)"))) %>%
    group_by(parameter) %>%
    filter(.unit_key == names(which.max(table(.unit_key)))) %>%
    ungroup() %>%
    select(-.unit_key)

  list(data = filtered, n_dropped = nrow(wq_data) - nrow(filtered))
}

# Pivot the long measurement data to one row per site/date, one column per
# parameter. Drop `unit` BEFORE pivoting so it is not treated as an id
# column (different parameters have different units, which would otherwise
# split each parameter onto its own row). values_fn averages multiple
# same-day samples so parameter columns stay atomic numeric, never
# list-columns.
widen_wq_data <- function(wq_join, state_name) {
  wq_join %>%
    select(-unit) %>%
    pivot_wider(
      names_from = parameter,
      values_from = value,
      values_fn = function(x) mean(x, na.rm = TRUE)
    ) %>%
    mutate(state = state_name) %>%
    select(state, county, site_id, site_name, lat, lon, date, everything())
}

# Top sites by measurement count, with display labels for the site selector.
summarize_wq_sites <- function(wq_join, n_top = 5) {
  wq_join %>%
    group_by(site_id, site_name) %>%
    summarise(n_measurements = n(), .groups = "drop") %>%
    arrange(desc(n_measurements)) %>%
    slice_head(n = n_top) %>%
    mutate(display_label = paste0(site_name, " (", n_measurements, " measurements)"))
}

# Full pipeline: raw WQP results + site metadata in, everything the server
# needs out. Assumes nrow(wq_raw) > 0 (the server short-circuits empty
# results before calling this).
process_wq_result <- function(wq_raw, meta_df, location, state_fips, state_name, fips_clean) {
  wq_clean <- janitor::clean_names(wq_raw)
  meta <- janitor::clean_names(meta_df)

  wq_join <- tidy_wq_samples(wq_clean) %>%
    left_join(tidy_wq_sites(meta, location, state_fips, fips_clean), by = "site_id") %>%
    relocate(site_name, county, lat, lon, .after = site_id)

  standardized <- standardize_wq_units(wq_join)
  wq_join <- standardized$data

  available_sites <- summarize_wq_sites(wq_join)

  list(
    long_data = wq_join,
    wide_data = widen_wq_data(wq_join, state_name),
    available_sites = available_sites,
    n_dropped_units = standardized$n_dropped,
    n_sites_total = length(unique(wq_join$site_id)),
    found_parameters = unique(wq_join$parameter)
  )
}
