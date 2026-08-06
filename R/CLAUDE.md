# R/ — data pipeline

## Data Processing (R/process-wq.R, called from the success branch)
`process_wq_result()` orchestrates; every step is schema-aware via `wq_col()` (column-name candidates for both WQX3 and legacy profiles):
1. Raw data cleaned with `janitor::clean_names()`
2. Site metadata joined: site_name, **per-site county** (from the fetch-time county stamp through the FIPS crosswalk, so multi-county queries label each row with its actual county), lat, lon
3. Unit standardization in two steps (`standardize_wq_units()`):
   - Convert known variants to a canonical unit: µg/L→mg/L, °F→°C, mS/cm→µS/cm, umho/cm→µS/cm
   - Within each parameter, keep only the most common unit (case-insensitive key, so "mg/L" and "mg/l" count as one); dropped rows are counted and reported in the status message
4. `pivot_wider` (unit column dropped first; `values_fn = mean` averages same-day replicates) into `values$wide_data`
5. Top-5 most active sites populate the site selector
