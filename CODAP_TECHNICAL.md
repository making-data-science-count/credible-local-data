# CODAP Integration - Technical Reference

This document provides technical details about the CODAP Data Interactive Plugin API integration in the CREDIBLE Local Data Shiny application. For user-facing instructions, see `CODAP_INTEGRATION.md`.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Code Locations](#code-locations)
- [JavaScript Implementation](#javascript-implementation)
- [R/Shiny Implementation](#rshiny-implementation)
- [Data Flow](#data-flow)
- [CODAP API Specification](#codap-api-specification)
- [Error Handling](#error-handling)
- [Testing](#testing)

---

## Architecture Overview

The integration follows the CODAP Data Interactive Plugin API specification and consists of three layers:

### Layer 1: JavaScript Interface (Client-side)
- **Location:** Lines 191-289 in `app.R`
- **Purpose:** Communicates with CODAP via `window.parent.postMessage()`
- **Components:**
  - `codapInterface()` - Promise-based API wrapper
  - `sendToCODAP` message handler - Receives data from R

### Layer 2: R/Shiny Server Logic
- **Location:** Three separate implementations for water, air, and weather data
- **Purpose:** Converts R data frames to CODAP format and sends to JavaScript
- **Components:**
  - Button event handlers (`observeEvent`)
  - Data conversion functions
  - Status feedback handlers

### Layer 3: UI Elements
- **Location:** All three data tabs (water quality, air quality, weather)
- **Purpose:** User controls for dataset naming and export triggering
- **Components:**
  - Text inputs for dataset names
  - Action buttons for triggering export

### Communication Flow
```
User (Browser) ←→ Shiny Server ←→ JavaScript ←→ CODAP
```

---

## Code Locations

### Quick Reference Table

| Component | Lines | Description |
|-----------|-------|-------------|
| **JavaScript API** | 191-289 | CODAP interface and message handler |
| **Water Quality UI** | 424-448 | Dataset name input and send button |
| **Air Quality UI** | 580-604 | Dataset name input and send button |
| **Weather UI** | 791-815 | Dataset name input and send button |
| **Water Server Logic** | 1255-1334 | Export handler and status feedback |
| **Air Server Logic** | 1618-1676 | Export handler and status feedback |
| **Weather Server Logic** | 2030-2088 | Export handler and status feedback |

### Detailed Locations

#### JavaScript CODAP API (Lines 191-289)
Added in `dashboardBody()` within `tags$head()`:

```r
tags$head(
  tags$style(HTML(custom_css)),

  # CODAP Data Interactive Plugin API Integration
  tags$script(HTML("
    // CODAP Interface Helper Function
    function codapInterface(action, resource, values) {
      return new Promise((resolve, reject) => {
        // Implementation details...
      });
    }

    // Custom Shiny Message Handler
    Shiny.addCustomMessageHandler('sendToCODAP', function(payload) {
      // Implementation details...
    });
  "))
)
```

#### Water Quality UI (Lines 424-448)
Modified the "Data Preview" box:

```r
div(style = "text-align: center; margin-top: 15px; ...",
    h4("Export Options", style = "margin-bottom: 15px;"),
    fluidRow(
      column(4, downloadButton("download_wide", "Download as CSV", ...)),
      column(4, textInput("codap_dataset_name", "CODAP Dataset Name:",
                          value = "WaterQualityData", ...)),
      column(4, actionButton("send_to_codap", "Send to CODAP", ...))
    ),
    p("Download data as CSV or send directly to CODAP...")
)
```

**UI Input IDs:**
- `input$codap_dataset_name` - Dataset name
- `input$send_to_codap` - Export trigger

#### Air Quality UI (Lines 580-604)
Same structure with different IDs:
- `input$codap_air_dataset_name`
- `input$send_air_to_codap`

#### Weather & Climate UI (Lines 791-815)
Same structure with different IDs:
- `input$codap_weather_dataset_name`
- `input$send_weather_to_codap`

---

## JavaScript Implementation

### codapInterface() Function

**Purpose:** Wraps CODAP API calls in a Promise-based interface

**Parameters:**
- `action` - CODAP action (e.g., "create", "update", "get")
- `resource` - CODAP resource type (e.g., "dataContext", "collection")
- `values` - Payload specific to the action/resource

**Returns:** Promise that resolves with CODAP's response or rejects on error

**Implementation Details:**
1. Generates unique `requestId` for tracking
2. Sends message via `window.parent.postMessage()` to CODAP
3. Listens for matching response with same `requestId`
4. 10-second timeout for responses
5. Comprehensive console logging for debugging

**Detection Logic:**
```javascript
if (window === window.parent) {
  // Not embedded in CODAP - reject immediately
  reject({
    error: 'Not running in CODAP',
    message: 'This app must be embedded in CODAP...'
  });
}
```

### sendToCODAP Message Handler

**Purpose:** Receives data from R/Shiny and sends it to CODAP

**Process:**
1. Receives payload from R via `session$sendCustomMessage()`
2. Extracts `datasetName`, `attributes`, and `cases`
3. Creates CODAP `dataContext` with dataset metadata
4. Sends data rows as cases
5. Reports success/failure back to R via `Shiny.setInputValue()`

**Console Logging:**
- `"CODAP interface initialized"` - Script loaded
- `"Received sendToCODAP message from Shiny:"` - Data received from R
- `"Sending to CODAP:"` - Outgoing CODAP request
- `"DataContext created successfully:"` - Dataset created
- `"Cases sent successfully:"` - Data transmitted
- `"Total cases sent:"` - Row count
- `"Error sending data to CODAP:"` - Error details

---

## R/Shiny Implementation

### Water Quality Export Handler (Lines 1255-1334)

#### Button Click Handler
```r
observeEvent(input$send_to_codap, {
  # 1. Get filtered data
  data <- filtered_wide_data()

  # 2. Validate data exists
  if (is.null(data) || nrow(data) == 0) {
    showNotification("No data available to send to CODAP",
                     type = "error", duration = 5)
    return()
  }

  # 3. Get dataset name
  dataset_name <- input$codap_dataset_name
  if (is.null(dataset_name) || dataset_name == "") {
    dataset_name <- "WaterQualityData"  # Fallback
  }

  # 4. Convert columns to CODAP attributes
  attributes <- lapply(names(data), function(col_name) {
    list(name = col_name, title = col_name)
  })

  # 5. Convert rows to CODAP cases
  cases <- lapply(seq_len(nrow(data)), function(i) {
    row_data <- as.list(data[i, ])
    # Convert NA to NULL for JSON serialization
    row_data <- lapply(row_data, function(x) {
      if (is.na(x)) return(NULL) else return(x)
    })
    return(row_data)
  })

  # 6. Send to JavaScript
  session$sendCustomMessage(
    type = "sendToCODAP",
    message = list(
      datasetName = dataset_name,
      attributes = attributes,
      cases = cases
    )
  )

  # 7. Show notification
  showNotification(
    paste("Sending", nrow(data), "rows to CODAP..."),
    type = "message",
    duration = 3
  )
})
```

#### Status Feedback Handler
```r
observeEvent(input$codap_export_status, {
  status <- input$codap_export_status

  if (!is.null(status) && !is.null(status$success)) {
    if (status$success) {
      showNotification(
        status$message,
        type = "message",
        duration = 5
      )
    } else {
      showNotification(
        paste("CODAP Export Error:", status$message),
        type = "error",
        duration = 8
      )
    }
  }
})
```

### Air Quality Export Handler (Lines 1618-1676)
- Uses `filtered_air_data()`
- Uses `input$codap_air_dataset_name`
- Default: "AirQualityData"
- Otherwise identical structure

### Weather Export Handler (Lines 2030-2088)
- Uses `filtered_weather_data()`
- Uses `input$codap_weather_dataset_name`
- Default: "WeatherData"
- Otherwise identical structure

### Key Implementation Notes

**Data Safety:**
- Uses `seq_len(nrow(data))` instead of `1:nrow(data)` to handle empty edge cases

**NA Handling:**
- R's `NA` values are converted to JavaScript `null` for proper JSON serialization
- Critical for CODAP to correctly interpret missing data

**Error Validation:**
- Validates data exists before attempting export
- Provides helpful error messages to user

**Consistent Naming:**
- All three implementations use parallel naming conventions
- Easy to maintain and extend

---

## Data Flow

### Complete Request-Response Cycle

```
┌─────────────────────────────────────────────────────────────┐
│ User Action                                                 │
│ Clicks "Send to CODAP" button                              │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ R/Shiny Server                                              │
│ observeEvent(input$send_to_codap) triggered                │
│ - Get filtered data from reactive                          │
│ - Validate data exists                                     │
│ - Convert columns → CODAP attributes                       │
│ - Convert rows → CODAP cases (NA → NULL)                   │
│ - session$sendCustomMessage(type="sendToCODAP", ...)       │
│ - Show "Sending..." notification                           │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ JavaScript (Browser)                                        │
│ Shiny.addCustomMessageHandler('sendToCODAP') receives      │
│ - Extract datasetName, attributes, cases                   │
│ - Call codapInterface('create', 'dataContext', values)     │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ codapInterface()                                            │
│ - Generate unique requestId                                │
│ - window.parent.postMessage() to CODAP                     │
│ - Wait for response (10-second timeout)                    │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ CODAP                                                       │
│ - Receives message via postMessage                         │
│ - Creates dataContext with attributes                      │
│ - Imports cases (rows)                                     │
│ - Responds with success/failure                            │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ JavaScript (Browser)                                        │
│ - Receives CODAP response                                  │
│ - Shiny.setInputValue('codap_export_status', {...})        │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ R/Shiny Server                                              │
│ observeEvent(input$codap_export_status) triggered          │
│ - Check success/failure                                    │
│ - Show success or error notification to user               │
└─────────────────────────────────────────────────────────────┘
```

---

## CODAP API Specification

### Message Format: Create DataContext

**Action:** `create`
**Resource:** `dataContext`

**Values Structure:**
```javascript
{
  name: "WaterQualityData",              // Dataset identifier
  title: "WaterQualityData",             // Display name
  description: "Data exported from CREDIBLE Local Data Shiny App",
  collections: [{
    name: "WaterQualityData_collection", // Collection identifier
    title: "WaterQualityData",           // Collection display name
    attrs: [                              // Column definitions
      {name: "site_no", title: "site_no"},
      {name: "date", title: "date"},
      {name: "ph", title: "ph"},
      // ... more attributes
    ]
  }]
}
```

### Message Format: Create Cases

**Action:** `create`
**Resource:** `dataContext[{datasetName}].item`

**Values Structure:**
```javascript
[
  {site_no: "12345", date: "2024-01-01", ph: 7.2},
  {site_no: "12345", date: "2024-01-02", ph: 7.3},
  // ... more cases (rows)
]
```

### CODAP Response Format

**Success:**
```javascript
{
  success: true,
  values: {
    id: 123,
    name: "WaterQualityData",
    title: "WaterQualityData"
  }
}
```

**Error:**
```javascript
{
  success: false,
  values: {
    error: "Error message from CODAP"
  }
}
```

### Attribute Schema

Each attribute (column) is defined as:
```javascript
{
  name: "column_name",  // Required: Identifier for column
  title: "column_name"  // Required: Display name (can differ from name)
  // Optional fields we don't currently use:
  // type: "numeric" | "categorical" | "date" | "boundary"
  // description: "Column description"
  // unit: "mg/L"
}
```

---

## Error Handling

### Client-Side Detection

**Not Embedded in CODAP:**
```javascript
if (window === window.parent) {
  // Immediately reject - don't wait for timeout
  reject({
    error: 'Not running in CODAP',
    message: 'This app must be embedded in CODAP as a Data Interactive...'
  });
}
```

**Timeout:**
```javascript
setTimeout(() => {
  reject({
    error: 'Timeout',
    message: 'CODAP did not respond within 10 seconds'
  });
}, 10000);
```

### Server-Side Validation

**No Data Available:**
```r
if (is.null(data) || nrow(data) == 0) {
  showNotification(
    "No data available to send to CODAP. Please fetch data first.",
    type = "error",
    duration = 5
  )
  return()
}
```

**Empty Dataset Name:**
```r
if (is.null(dataset_name) || dataset_name == "") {
  dataset_name <- "WaterQualityData"  # Fallback to default
}
```

### User Notifications

**Error Messages Include:**
- Clear description of the problem
- Helpful guidance for resolution
- Link to CODAP website when applicable
- Alternative solution (CSV download)
- Extended duration for errors (8 seconds vs 3-5 for success)

**Example Error Notification:**
```
CODAP Export Error: This app must be embedded in CODAP to use
the Send to CODAP feature. Please open CODAP at codap.concord.org
and add this app URL as a plugin.

Tip: Alternatively, use the 'Download as CSV' button and import
the file into CODAP manually.
```

---

## Testing

### Console Verification

**Step 1: Verify JavaScript Loaded**
Open browser console (F12). Should see:
```
CODAP interface initialized
```

**Step 2: Test Export**
Click "Send to CODAP". Console should show:
```
Received sendToCODAP message from Shiny: {datasetName: "...", ...}
Sending to CODAP: {action: "create", resource: "dataContext", ...}
DataContext created successfully: {success: true, ...}
Cases sent successfully: {success: true, ...}
Total cases sent: 123
```

### Integration Test Checklist

- [ ] All three "Send to CODAP" buttons appear correctly
- [ ] Dataset name inputs are editable
- [ ] Dataset name inputs have correct defaults
- [ ] Clicking button shows "Sending..." notification
- [ ] Console shows JavaScript messages
- [ ] Data appears in CODAP with correct structure
- [ ] Column names match data frame
- [ ] All rows are present
- [ ] NA values handled correctly (appear as blank/missing in CODAP)
- [ ] Success notification shows row count
- [ ] CSV download buttons still work (not affected by CODAP integration)

### Error Condition Testing

- [ ] Clicking button without fetching data shows error
- [ ] Running app standalone shows "not embedded" error
- [ ] Timeout error appears if CODAP doesn't respond
- [ ] Error messages are clear and actionable

### Data Type Testing

Test with different data types:
- [ ] Numeric values (e.g., pH, temperature)
- [ ] Character/string values (e.g., site names)
- [ ] Dates (various formats)
- [ ] Missing values (NA)
- [ ] Large datasets (>1000 rows)
- [ ] Small datasets (<10 rows)

---

## Preserved Functionality

All existing app functionality remains intact:

✅ **Data Fetching:**
- Water quality via USGS Water Quality Portal
- Air quality via EPA AQS API
- Weather/climate via climateR

✅ **Data Filtering:**
- State/county selection
- Site/station selection
- Parameter selection
- Date range selection

✅ **Data Display:**
- Data preview tables (DT)
- Loading indicators
- Status messages

✅ **CSV Export:**
- All download buttons work as before
- File naming conventions preserved

---

## Future Enhancement Possibilities

Potential improvements (not currently implemented):

1. **Update Existing Datasets**
   - Instead of always creating new datasets, check if dataset exists
   - Provide option to update or append

2. **Custom Attribute Types**
   - Specify numeric vs categorical vs date
   - Improves CODAP's automatic analysis

3. **Batch Processing**
   - Split very large datasets into chunks
   - Avoid timeout issues with huge datasets

4. **Dataset Preferences**
   - Save/load preferred dataset names
   - Remember user choices across sessions

5. **Advanced CODAP Features**
   - Create CODAP formulas
   - Set up default graphs
   - Configure initial table layout

---

## External Resources

### CODAP Documentation
- **CODAP Website:** https://codap.concord.org/
- **Data Interactive Plugin API:** https://github.com/concord-consortium/codap/wiki/CODAP-Data-Interactive-Plugin-API
- **CODAP Wiki:** https://github.com/concord-consortium/codap/wiki

### Shiny Documentation
- **Custom Message Handlers:** https://shiny.rstudio.com/articles/communicating-with-js.html
- **JavaScript Integration:** https://shiny.rstudio.com/articles/js-send-message.html

### Related Project Documentation
- **User Guide:** See `CODAP_INTEGRATION.md`
- **UI Reference:** See `UI_CHANGES_VISUAL_GUIDE.md`
- **Project Overview:** See `CLAUDE.md`

---

**This integration follows best practices for Shiny-JavaScript communication and adheres to the official CODAP Data Interactive Plugin API specification.**
