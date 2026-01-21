# Water Quality Data Collection Tool

A Shiny web application that allows teachers to collect local water quality data for educational purposes. This tool fetches data from the USGS Water Quality Portal and processes it into three different formats for classroom use.

## Features

- **Complete US Coverage**: Choose from dropdown menus with **ALL 3,000+ US counties, parishes, and boroughs** (no need to look up FIPS codes!)
- **Comprehensive Geographic Support**: Every county in all 50 states, plus Louisiana parishes, Alaska boroughs, and US territories
- **Multiple Data Formats**: Get data in three different formats:
  - Wide format (raw data with site information)
  - Quarterly raw (aggregated by quarter with means)
  - Quarterly complete (only complete quarters with no missing data)
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

## License

This tool is provided for educational use. Water quality data is provided by USGS and EPA through the Water Quality Portal. 