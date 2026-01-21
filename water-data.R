library(tidyverse)
library(dataRetrieval)
library(janitor)

# 1 ────────────────────────────────────────────────────────────────────────────
#   Build the query once (now includes Turbidity & Phosphorus)
qry <- list(
  countycode         = "US:47:093",                       # Knox County, TN
  characteristicName = c("Nitrate", "Nitrite", "pH",
                         "Turbidity",                    # NTU
                         "Phosphorus"), # mg/L as P
  sampleMedia        = "Water",
  startDateLo        = "2000-01-01"
)

# 2 ───────────────────────────────Vie─────────────────────────────────────────────
#   Sample results and site metadata
wq_raw  <- do.call(readWQPdata,  qry)
meta_df <- do.call(whatWQPsites, qry)

# 3 ────────────────────────────────────────────────────────────────────────────
#   Clean names ➜ snake_case
wq_clean <- wq_raw  %>% janitor::clean_names()
meta     <- meta_df %>% janitor::clean_names()

# 4 ────────────────────────────────────────────────────────────────────────────
#   Select / rename essentials
lat_col  <- grep("latitude",  names(meta), value = TRUE)[1]
lon_col  <- grep("longitude", names(meta), value = TRUE)[1]

wq_tidy <- wq_clean %>%
  transmute(
    site_id  = monitoring_location_identifier,
    date     = activity_start_date,
    parameter= characteristic_name,
    value    = as.numeric(result_measure_value),
    unit     = result_measure_measure_unit_code
  )

meta_trim <- meta %>%
  transmute(
    site_id  = monitoring_location_identifier,
    site_name = monitoring_location_name,
    lat       = .data[[lat_col]],
    lon       = .data[[lon_col]]
  )

# 5 ────────────────────────────────────────────────────────────────────────────
#   Join samples ↔ metadata
wq_join <- wq_tidy %>%
  left_join(meta_trim, by = "site_id") %>%
  relocate(site_name, lat, lon, .after = site_id)

# 6 ────────────────────────────────────────────────────────────────────────────
#   Standardise units: convert µg/L → mg/L
wq_join <- wq_join %>%
  mutate(
    value = if_else(unit %in% c("ug/l", "µg/l", "ug/L", "µg/L"),
                    value / 1000, value),
    unit  = if_else(unit %in% c("ug/l", "µg/l", "ug/L", "µg/L"),
                    "mg/L", unit)
  )

wq_wide <- wq_join %>%
  mutate(row_id = row_number()) %>% 
  pivot_wider(names_from = parameter, values_from = value)

wq_wide

# 8 ────────────────────────────────────────────────────────────────────────────
#   Write both CSVs for students
write_csv(wq_join, "knox_water_quality_long.csv")   # one row = one measurement
write_csv(wq_wide, "knox_water_quality_wide.csv")   # one row = site‑date


# clean
#   Add a MONTH field (the first day of each month keeps it date‑like)
wq_monthly <- wq_wide %>% 
  mutate(month = floor_date(as.Date(date), unit = "month")) %>%   # 2023‑04‑01 etc.
  
  # 2 ────────────────────────────────────────────────────────────────────────────
  #   Group by site + month, then summarise
  group_by(site_name, lat, lon, month) %>% 
  summarise(
    across(c(Turbidity, pH, Phosphorus, Nitrate, Nitrite),
           list(mean = ~mean(., na.rm = TRUE),        # average per month
                n    = ~sum(!is.na(.))),              # how many samples
           .names = "{.col}_{.fn}"),
    .groups = "drop"
  )

wq_monthly <- wq_monthly %>%                     # overwrite in place
  mutate(
    across(                                     # apply to…
      where(is.numeric),                        # …all numeric columns
      ~ replace(., is.nan(.), NA_real_)         # turn NaN → NA
    )
  )

wq_monthly %>% 
  arrange(desc(month)) %>% 
  select(site_name, lat, lon, month, Turbidity_mean, pH_mean, Phosphorus_mean) %>% 
  drop_na() %>% write_csv("wq_knox_monthly_cleaned_all.csv")

wq_monthly %>% 
  arrange(desc(month)) %>% 
  select(site_name, lat, lon, month, Turbidity_mean, pH_mean, Phosphorus_mean) %>% 
  drop_na() %>% View()

write_csv("wq_knox_monthly_cleaned_all.csv")

wq_monthly %>% 
  arrange(desc(month)) %>% 
  drop_na() %>% View()
select(site_name, lat, lon, month, contains("mean")) %>% write_csv("wq_knox_monthly_cleaned.csv")

# 3 ────────────────────────────────────────────────────────────────────────────
#   Save for students
write_csv(wq_monthly, "knox_water_quality_monthly.csv")