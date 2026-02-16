# CREDIBLE Local Data Collection Tool

A Shiny web application for collecting water quality data for educational purposes. This tool fetches data from the USGS Water Quality Portal and exports it as CSV or directly to CODAP for interactive analysis.

> **Note:** This version focuses on water quality data. Air quality and weather/climate features are temporarily archived as we refine the core functionality.

## Features

- **Water Quality Data**: Fetch data from USGS Water Quality Portal for five key parameters (Nitrate, Nitrite, pH, Turbidity, Total Phosphorus)
- **Complete US Coverage**: Choose from dropdown menus with **ALL 3,000+ US counties, parishes, and boroughs** (no need to look up FIPS codes!)
- **Comprehensive Geographic Support**: Every county in all 50 states, plus Louisiana parishes, Alaska boroughs, and US territories
- **CODAP Integration**: Send data directly to CODAP for interactive student analysis (see [CODAP Integration](#codap-integration) below)
- **Interactive Preview**: View data before downloading
- **Smart Downloads**: Files automatically named with location and date
- **User-Friendly Interface**: Real-time status updates and location confirmation

## Water Quality Parameters

The app collects data for five key water quality parameters:
- Nitrate
- Nitrite
- pH
- Turbidity
- Total Phosphorus

## CODAP Integration

This app includes seamless integration with **CODAP** (Common Online Data Analysis Platform), allowing students to analyze environmental data interactively.

### What is CODAP?
CODAP is a free, web-based data analysis tool designed for education. Students can create graphs, perform statistical analysis, and explore data patterns interactively.

### How to Use with CODAP

1. **Deploy your app** to shinyapps.io or run locally
2. **Open CODAP** at https://codap.concord.org/
3. **Add your app** as a Data Interactive plugin in CODAP
4. **Fetch data** in your app (water, air, or weather data)
5. **Click "Send to CODAP"** - data appears instantly in CODAP!

### Documentation

- **[CODAP_INTEGRATION.md](CODAP_INTEGRATION.md)** - Complete user guide with deployment, embedding, and troubleshooting
- **[CODAP_TECHNICAL.md](CODAP_TECHNICAL.md)** - Technical reference for developers
- **[UI_CHANGES_VISUAL_GUIDE.md](UI_CHANGES_VISUAL_GUIDE.md)** - Visual guide to the interface

### Alternative: CSV Download

If you prefer not to use CODAP integration, you can still download data as CSV files and import them into CODAP (or any other analysis tool) manually.

## Installation

### Required R Packages

Before running the app, install the required packages:

```r
install.packages(c(
  "shiny",
  "shinydashboard",
  "DT",
  "tidyverse",
  "dataRetrieval",
  "janitor"
))
```

### Running the App

1. Open R or RStudio
2. Set your working directory to the folder containing `app.R`
3. Run the following command:

```r
shiny::runApp("app.R")
```

Or simply open `app.R` in RStudio and click the "Run App" button.

## How to Use

### Step 1: Select Your Location
1. **Choose State**: Select your state from the dropdown menu
2. **Choose County**: Select your county from the filtered list of major counties
3. **Alternative**: If your county isn't listed, use the "Advanced: Manual FIPS Code Entry" option

### Step 2: Fetch Data
1. Click "Fetch Water Quality Data" 
2. Wait for the data to be processed (this may take a few minutes)
3. Monitor the status updates as data is retrieved and processed

### Step 3: Preview and Download
1. Use the "Data Preview" tabs to examine your data
2. Choose which format(s) you need:
   - **Wide Format**: Best for detailed analysis and visualization
   - **Quarterly Raw**: Good for seasonal trend analysis
   - **Quarterly Complete**: Best for statistical analysis (no missing data)
3. Click the appropriate download button(s)

## County Coverage

🎉 **ALL US COUNTIES NOW AVAILABLE!** 🎉

The app now includes **every single county, parish, borough, and census area** in the United States through comprehensive FIPS data sourced from Kieran Healy's authoritative crosswalk dataset.

### Complete Coverage Includes:
- **All 3,000+ US Counties**: Every county in all 50 states
- **Louisiana Parishes**: All parishes in Louisiana
- **Alaska Boroughs**: All boroughs and census areas in Alaska  
- **Special Districts**: Washington DC, independent cities, etc.
- **US Territories**: Counties in Puerto Rico, US Virgin Islands, etc.

### Easy Selection:
1. Choose your state from the dropdown
2. See **ALL** counties in that state automatically populated
3. No more hunting for FIPS codes or missing counties!

### Still Need Manual Entry?
The **"Advanced: Manual FIPS Code Entry"** option remains available for special use cases or if you prefer to work directly with FIPS codes.

## Data Sources

- **Water Quality Portal (WQP)**: https://www.waterqualitydata.us/
- **USGS dataRetrieval Package**: https://github.com/USGS-R/dataRetrieval

## Educational Use

This tool is designed for educational purposes and helps students:
- Learn about local water quality
- Understand environmental monitoring
- Practice data analysis skills
- Explore temporal and spatial patterns in water quality

## Troubleshooting

### No Data Found
- Some counties may not have water quality monitoring stations
- Try a nearby county or major metropolitan area
- Check that you've selected both state and county from the dropdowns
- For manual entry, verify your FIPS codes are correct

### App Won't Start
- Make sure all required packages are installed
- Check that you're using a recent version of R (>= 4.0.0)

### Slow Data Loading
- Large counties may take several minutes to process
- The app fetches data from 1970 onwards, which can be substantial
- Be patient during the "Fetching data..." phase

## File Structure

```
credible-local-data/
├── app.R                    # Main Shiny application
├── water-data.R            # Original R script (reference)
├── README.md               # This file
└── credible-local-data.Rproj  # RStudio project file
```

## Support

For questions about water quality data or FIPS codes:
- USGS Water Data: https://waterdata.usgs.gov/
- EPA Water Quality Portal: https://www.epa.gov/waterdata/water-quality-portal

## Development Roadmap

### Current Focus: Water Quality
This version focuses exclusively on water quality data to ensure a robust, well-tested core feature before expanding.

### Archived Features
The following features are temporarily disabled but preserved in the code:
- **Air Quality**: EPA AQS data integration
- **Weather & Climate**: NOAA/climateR data integration

These features can be restored by developers by removing `if(FALSE)` wrappers in `app.R`. Look for comments marked `## ARCHIVED`.

### Future Plans
Once water quality functionality is perfected, we plan to:
1. Restore and refine air quality data collection
2. Restore and refine weather/climate data collection
3. Add additional water quality parameters
4. Enhance CODAP integration features

## License

This tool is provided for educational use. Water quality data is provided by USGS and EPA through the Water Quality Portal. 