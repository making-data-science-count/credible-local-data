# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CREDIBLE Local Data is a Shiny web application for collecting water quality data for educational purposes. The app fetches data from the USGS Water Quality Portal and exports it in CSV format or directly to CODAP (Common Online Data Analysis Platform) for interactive analysis.

**IMPORTANT:** Air quality and weather/climate features are currently archived (wrapped in `if(FALSE)` blocks) to focus development on perfecting the water quality functionality first. These features remain in the codebase and can be restored by removing the `if(FALSE)` wrappers marked with `## ARCHIVED` comments.

## Running the Application

**Local Development:**
```r
# Install required packages first (see Dependencies section)
shiny::runApp("app.R")
```

Or in RStudio: Open `app.R` and click "Run App"

**No build or test commands** - This is a pure R/Shiny application with no compilation step.

## Dependencies

Required R packages:
```r
install.packages(c(
  "shiny",
  "shinydashboard",
  "DT",
  "tidyverse",
  "dataRetrieval",
  "janitor",
  "lubridate"
))
```

Optional packages for extended functionality:
- `RAQSAPI` - Air quality data (requires EPA credentials)
- `climateR` - Weather/climate data (install via `devtools::install_github('mikejohnson51/climateR')`)

**Note:** API credentials are hardcoded in app.R line 16 for AQS API. This should be moved to environment variables for production.

## Core Architecture

### Current Design: Water Quality Focus
The app currently features a single-tab design focused on water quality data:
1. **Water Quality** (Active) - USGS Water Quality Portal via `dataRetrieval` package
2. **Air Quality** (Archived) - EPA AQS Data Mart via `RAQSAPI` package
3. **Weather & Climate** (Archived) - Multiple datasets via `climateR` package

The archived tabs (Air Quality and Weather) remain in the codebase but are disabled with `if(FALSE)` wrappers. They can be restored by searching for `## ARCHIVED` comments and removing the wrappers.

### Water Quality Tab Pattern
The active water quality tab follows this structure:
- **Location Selection**: State → County dropdowns using comprehensive FIPS crosswalk
- **Parameter Selection**: Checkboxes for different measurements
- **Year Range**: Slider for temporal filtering
- **Data Fetching**: Action button triggers API calls
- **Site/Station Selection**: Multi-select dropdown for spatial filtering
- **Export Options**: CSV download + "Send to CODAP" button

### FIPS Crosswalk System
- `fips-xwalk.csv` contains ALL US counties (3,000+) from Kieran Healy's dataset
- `fips_clean` dataframe (lines 48-66) provides state/county lookups
- Five-digit FIPS codes: first 2 digits = state, last 3 = county

## Data Flow

**General Pattern (Water Quality Example):**
1. User selects location → `observeEvent(input$state_selection)` updates county choices
2. User clicks "Fetch Data" → `fetch_water_data()` function called
3. Function builds query parameters → calls external API
4. Raw data cleaned with `janitor::clean_names()`
5. Data processed into long format (`wq_tidy`) and wide format (`wq_wide`)
6. Reactive values updated → UI tables re-render
7. User exports via CSV or CODAP

**Key Functions:**
- `fetch_water_data()` (lines 1090-1242): Water quality data pipeline
- `fetch_air_data()` (lines 1525-1612): Air quality data pipeline
- `fetch_weather_data()` (lines 1868-2024): Weather data pipeline

## CODAP Integration

The app implements the CODAP Data Interactive Plugin API for direct data export:

**JavaScript Layer (lines 194-317):**
- `codapInterface()` - Promise-based wrapper for `window.parent.postMessage()`
- `sendToCODAP` custom message handler - Receives data from R, creates CODAP dataset

**R Server Layer (three implementations):**
- Water: lines 1288-1369
- Air: lines 1658-1711
- Weather: lines 2070-2123

**Data Conversion:**
1. Data frame columns → CODAP attributes: `{name: colName, title: colName}`
2. Data frame rows → CODAP cases (list of objects)
3. NA values converted to NULL for JSON serialization
4. Sent via `session$sendCustomMessage(type = "sendToCODAP", ...)`

**Important:** CODAP export only works when the app is embedded as a Data Interactive plugin inside CODAP. Standalone usage will show helpful error messages.

## Important Technical Details

### Reactive Values Structure (lines 869-900)
All three tabs store state in a `reactiveValues()` object with parallel naming:
- Water: `data_fetched`, `wide_data`, `status`, `loading_visible`, etc.
- Air: `air_data_fetched`, `air_wide_data`, `air_status`, `air_loading_visible`, etc.
- Weather: `weather_data_fetched`, `weather_wide_data`, `weather_status`, `weather_loading_visible`, etc.

### Water Quality Parameter Codes
The app uses common names ("pH", "Nitrate") not parameter codes. The `dataRetrieval::readWQPdata()` function accepts these directly.

### Air Quality Parameter Codes
Uses EPA AQS parameter codes (e.g., "88101" = PM2.5, "44201" = Ozone). See lines 513-533 for full mapping.

### Weather Dataset Options
- TerraClimate: Global monthly data
- GridMET: Western US daily data
- Daymet: North America daily data

Each has different parameter names (e.g., "tmax" vs "tmmx" for max temperature).

## Code Patterns to Follow

**When adding a new data source:**
1. Add a new `tabItem` in the UI (follow existing three-tab pattern)
2. Create reactive values in `server()` function with consistent naming
3. Implement location selection with FIPS crosswalk
4. Write a `fetch_*_data()` function following the error handling pattern
5. Add filtered data reactive and DT preview output
6. Add CSV download handler
7. Add CODAP export `observeEvent` handlers (two: send button + status feedback)

**Data validation pattern:**
```r
if (input$state_selection == "" || input$county_selection == "") {
  showNotification("Please select both state and county", type = "error", duration = 5)
  return()
}
```

**Loading indicator pattern:**
```r
values$loading_visible <- TRUE
# ... data fetching code ...
values$loading_visible <- FALSE
```

**Error handling pattern:**
```r
tryCatch({
  # ... main logic ...
}, error = function(e) {
  values$status <- paste("Error:", e$message)
  showNotification(paste("Error:", e$message), type = "error", duration = 8)
  values$loading_visible <- FALSE
})
```

## Common Gotchas

1. **County selection initialization**: Tennessee/Knox County is hardcoded as default (lines 954, 965-983). Change this or make it truly optional if expanding beyond Tennessee.

2. **Site filtering**: The `filtered_*_data()` reactive functions check for "all" in selection. When adding sites, ensure unique site IDs (lines 1206-1220 use `distinct()` for this).

3. **Year range warnings**: Large year ranges trigger notifications (lines 986-994). Consider API rate limits.

4. **CODAP error messages**: The JavaScript checks for `window === window.parent` to detect if embedded (line 200). This is critical for helpful error messages.

5. **NA handling in CODAP export**: Must convert NA to NULL explicitly (lines 1319-1321) or CODAP receives invalid JSON.

6. **Unit standardization**: Water quality data converts µg/L → mg/L (lines 1187-1193). Check units for any new parameters.

## File Structure

```
credible-local-data/
├── app.R                   # Main Shiny app (2,127 lines)
├── fips-xwalk.csv         # FIPS code lookup (3,000+ counties)
├── water-data.R           # Original script (reference only - not used by app)
├── fips.R                 # Script to download FIPS data (reference only)
├── credible-logo.png      # Logo for About tab
├── README.md              # User-facing documentation
├── CODAP_*.md            # CODAP integration documentation
└── credible-local-data.Rproj  # RStudio project file
```

**Note:** Only `app.R` is required for the application to run. `water-data.R` and `fips.R` are historical reference files showing the original data processing logic.

## Key External Resources

- **USGS Water Quality Portal**: https://www.waterqualitydata.us/
- **EPA AQS API**: Requires registration at https://aqs.epa.gov/aqsweb/documents/data_api.html
- **CODAP**: https://codap.concord.org/
- **CODAP Plugin API**: https://github.com/concord-consortium/codap/wiki/CODAP-Data-Interactive-Plugin-API
- **climateR**: https://github.com/mikejohnson51/climateR

## Deployment Notes

The app can be deployed to shinyapps.io or other Shiny hosting platforms. Key considerations:

- Ensure all optional packages are installed if using those features
- EPA AQS credentials must be configured on the server
- Large data queries (10+ years) may timeout on free tiers
- The app uses `addResourcePath("images", ".")` for the logo (line 169)
