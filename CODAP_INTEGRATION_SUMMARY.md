# CODAP Data Interactive Plugin API Integration - Summary

## Overview
This document summarizes the CODAP (Common Online Data Analysis Platform) integration added to the CREDIBLE Local Data Shiny application. The integration allows users to send data directly from the Shiny app to CODAP for interactive analysis.

## Changes Made

### 1. JavaScript CODAP API Integration (Lines 191-289)

Added comprehensive JavaScript code in the `<head>` section with:

#### `codapInterface()` Helper Function
- **Purpose**: Communicates with CODAP using the Data Interactive Plugin API
- **Implementation**: Uses `window.parent.postMessage()` for parent frame communication
- **Features**:
  - Promise-based async communication
  - Unique `requestId` for tracking responses
  - Response listener with 10-second timeout
  - Console logging for debugging
  - Error handling

#### `sendToCODAP` Custom Message Handler
- **Purpose**: Receives data from R/Shiny and sends it to CODAP
- **Process**:
  1. Receives payload with `datasetName`, `attributes`, and `cases`
  2. Creates CODAP `dataContext` with attributes
  3. Sends data rows as cases to CODAP
  4. Reports success/failure back to Shiny via `codap_export_status` input
- **Data Structure**: `{action: 'create', resource: 'dataContext', values: {...}}`

### 2. UI Elements Added

Added export controls to all three data tabs (Water Quality, Air Quality, Weather & Climate):

#### Water Quality Tab (Lines 424-448)
- **Location**: In the "Data Preview" box
- **Elements**:
  - Text input: `codap_dataset_name` (default: "WaterQualityData")
  - Action button: `send_to_codap` ("Send to CODAP")
  - Download CSV button (existing, repositioned)
- **Layout**: Three-column layout with helpful description

#### Air Quality Tab (Lines 580-604)
- **Location**: In the "Data Preview" box
- **Elements**:
  - Text input: `codap_air_dataset_name` (default: "AirQualityData")
  - Action button: `send_air_to_codap` ("Send to CODAP")
  - Download CSV button (existing, repositioned)
- **Layout**: Consistent with Water Quality tab

#### Weather & Climate Tab (Lines 791-815)
- **Location**: In the "Data Preview" box
- **Elements**:
  - Text input: `codap_weather_dataset_name` (default: "WeatherData")
  - Action button: `send_weather_to_codap` ("Send to CODAP")
  - Download CSV button (existing, repositioned)
- **Layout**: Consistent with other tabs

### 3. Server Logic Added

#### Water Quality CODAP Export (Lines 1255-1334)

**observeEvent: `input$send_to_codap`**
- Gets filtered water quality data via `filtered_wide_data()`
- Validates data exists
- Retrieves dataset name from input (defaults to "WaterQualityData")
- **Data Conversion Process**:
  1. Converts column names to CODAP attributes: `list(name = colName, title = colName)`
  2. Converts data frame rows to list of cases using `seq_len(nrow(data))`
  3. Handles NA values by converting to NULL for JSON serialization
- Sends via `session$sendCustomMessage(type = "sendToCODAP", message = list(...))`
- Shows notification with row count

**observeEvent: `input$codap_export_status`**
- Handles JavaScript feedback
- Shows success/error notifications based on CODAP response
- Duration: 5 seconds for success, 8 seconds for errors

#### Air Quality CODAP Export (Lines 1618-1676)

**observeEvent: `input$send_air_to_codap`**
- Gets filtered air quality data via `filtered_air_data()`
- Same conversion and validation logic as Water Quality
- Default dataset name: "AirQualityData"

#### Weather & Climate CODAP Export (Lines 2030-2088)

**observeEvent: `input$send_weather_to_codap`**
- Gets filtered weather data via `filtered_weather_data()`
- Same conversion and validation logic
- Default dataset name: "WeatherData"

## Technical Specifications

### CODAP API Message Format
```javascript
{
  action: 'create',
  resource: 'dataContext',
  values: {
    name: datasetName,
    title: datasetName,
    description: 'Data exported from CREDIBLE Local Data Shiny App',
    collections: [{
      name: datasetName + '_collection',
      title: datasetName,
      attrs: [
        {name: 'column1', title: 'column1'},
        {name: 'column2', title: 'column2'},
        ...
      ]
    }]
  }
}
```

### Data Case Format
```javascript
[
  {column1: value1, column2: value2, ...},
  {column1: value1, column2: value2, ...},
  ...
]
```

## Preserved Functionality

All existing functionality remains intact:
- ✅ Water Quality data fetching and filtering
- ✅ Air Quality data fetching and filtering
- ✅ Weather & Climate data fetching and filtering
- ✅ CSV download functionality (all tabs)
- ✅ Site/station selection
- ✅ Parameter selection
- ✅ Date range selection
- ✅ Data preview tables
- ✅ Loading indicators
- ✅ Status displays

## Usage Instructions

1. **Fetch Data**: Use existing controls to fetch water quality, air quality, or weather data
2. **Filter Data**: (Optional) Use site/station selectors to filter data
3. **Specify Dataset Name**: Enter a custom name in the "CODAP Dataset Name" input field
4. **Send to CODAP**: Click the "Send to CODAP" button
5. **Monitor Status**: Watch for success/error notifications
6. **View in CODAP**: Data appears in CODAP as a new dataset ready for interactive analysis

## Browser Console Logging

The integration includes comprehensive console logging for debugging:
- `"CODAP interface initialized"` - Confirms script loaded
- `"Sending to CODAP:"` - Shows outgoing messages
- `"CODAP Response Success:"` - Shows successful responses
- `"CODAP Response Error:"` - Shows error responses
- `"Received sendToCODAP message from Shiny:"` - Shows data from R
- `"DataContext created successfully:"` - Confirms dataset creation
- `"Cases sent successfully:"` - Confirms data transmission
- `"Total cases sent:"` - Shows row count

## Error Handling

1. **No Data Available**: Shows error notification if user tries to send before fetching data
2. **Empty Dataset Name**: Falls back to default names (WaterQualityData, AirQualityData, WeatherData)
3. **CODAP Connection Timeout**: 10-second timeout with error message
4. **CODAP API Errors**: Captured and displayed to user with descriptive messages
5. **NA Values**: Automatically converted to NULL for proper JSON serialization

## Code Quality Improvements

- Used `seq_len(nrow(data))` instead of `1:nrow(data)` to handle empty edge cases
- Comprehensive comments explaining each section
- Consistent naming conventions across all three tabs
- Proper error validation before sending data
- User-friendly notifications at each step

## Future Enhancements (Optional)

Potential improvements for future versions:
- Update existing datasets instead of always creating new ones
- Add option to append data to existing CODAP datasets
- Support for custom attribute types (numeric, categorical, etc.)
- Batch processing for very large datasets
- Save/load CODAP dataset name preferences
- Integration with CODAP formulas and calculations

## References

- [CODAP Data Interactive Plugin API](https://github.com/concord-consortium/codap/wiki/CODAP-Data-Interactive-Plugin-API)
- Shiny Custom Message Handler documentation
- JavaScript postMessage API documentation

## Testing Recommendations

When testing the integration:
1. Test with small datasets first (< 100 rows)
2. Verify data appears correctly in CODAP
3. Check console for any error messages
4. Test with different column types (numeric, character, date)
5. Test the default dataset names and custom names
6. Verify CSV download still works alongside CODAP export
7. Test all three data types (water, air, weather)

---

**Integration Complete**: Your Shiny app now supports direct CODAP export while maintaining all existing CSV functionality!


