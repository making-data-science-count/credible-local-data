# CODAP Integration - Code Reference Guide

This document provides exact line references for all CODAP-related code additions in `app.R`.

## Quick Navigation

| Section | Lines | Description |
|---------|-------|-------------|
| **JavaScript CODAP API** | 191-289 | Core CODAP interface and message handler |
| **Water Quality UI** | 424-448 | Dataset name input and Send button |
| **Air Quality UI** | 580-604 | Dataset name input and Send button |
| **Weather UI** | 791-815 | Dataset name input and Send button |
| **Water Server Logic** | 1255-1334 | Export handler and status feedback |
| **Air Server Logic** | 1618-1676 | Export handler |
| **Weather Server Logic** | 2030-2088 | Export handler |

---

## Detailed Code Locations

### 1. JavaScript CODAP API Integration

**Lines 191-289** - Added in `dashboardBody()` within `tags$head()`:

```r
tags$head(
  tags$style(HTML(custom_css)),
  
  # ============================================================================
  # CODAP DATA INTERACTIVE PLUGIN API INTEGRATION - JavaScript
  # ============================================================================
  tags$script(HTML("
    // CODAP Interface Helper Function
    function codapInterface(action, resource, values) { ... }
    
    // Custom Shiny Message Handler: sendToCODAP
    Shiny.addCustomMessageHandler('sendToCODAP', function(payload) { ... });
  "))
)
```

**Key Functions:**
- `codapInterface(action, resource, values)` - Promise-based CODAP communication
- `Shiny.addCustomMessageHandler('sendToCODAP', ...)` - Receives data from R

---

### 2. UI Elements - Water Quality Tab

**Lines 424-448** - Modified the "Data Preview" box:

```r
# ============================================================================
# CODAP EXPORT UI ELEMENTS - Water Quality
# ============================================================================
div(style = "text-align: center; margin-top: 15px; ...",
    h4("Export Options", style = "margin-bottom: 15px;"),
    fluidRow(
      column(4,
             downloadButton("download_wide", "Download as CSV", ...)
      ),
      column(4,
             textInput("codap_dataset_name", "CODAP Dataset Name:", 
                       value = "WaterQualityData", ...)
      ),
      column(4,
             actionButton("send_to_codap", "Send to CODAP", ...)
      )
    ),
    p("Download data as CSV or send directly to CODAP...")
)
```

**UI Elements Added:**
- `input$codap_dataset_name` - Text input for dataset name
- `input$send_to_codap` - Action button to trigger export

---

### 3. UI Elements - Air Quality Tab

**Lines 580-604** - Modified the "Data Preview" box:

```r
# ============================================================================
# CODAP EXPORT UI ELEMENTS - Air Quality
# ============================================================================
div(style = "text-align: center; ...",
    h4("Export Options", ...),
    fluidRow(
      column(4, downloadButton("download_air_data", ...)),
      column(4, textInput("codap_air_dataset_name", ..., value = "AirQualityData")),
      column(4, actionButton("send_air_to_codap", "Send to CODAP", ...))
    ),
    ...
)
```

**UI Elements Added:**
- `input$codap_air_dataset_name` - Text input
- `input$send_air_to_codap` - Action button

---

### 4. UI Elements - Weather & Climate Tab

**Lines 791-815** - Modified the "Data Preview" box:

```r
# ============================================================================
# CODAP EXPORT UI ELEMENTS - Weather & Climate
# ============================================================================
div(style = "text-align: center; ...",
    h4("Export Options", ...),
    fluidRow(
      column(4, downloadButton("download_weather_data", ...)),
      column(4, textInput("codap_weather_dataset_name", ..., value = "WeatherData")),
      column(4, actionButton("send_weather_to_codap", "Send to CODAP", ...))
    ),
    ...
)
```

**UI Elements Added:**
- `input$codap_weather_dataset_name` - Text input
- `input$send_weather_to_codap` - Action button

---

### 5. Server Logic - Water Quality CODAP Export

**Lines 1255-1334** - Added after `output$download_wide`:

```r
# =============================================================================
# CODAP EXPORT SERVER LOGIC - Water Quality
# =============================================================================

# observeEvent for "Send to CODAP" button (Water Quality)
observeEvent(input$send_to_codap, {
  # Get the filtered data
  data <- filtered_wide_data()
  
  # Validate that data exists
  if (is.null(data) || nrow(data) == 0) { ... }
  
  # Get dataset name from input
  dataset_name <- input$codap_dataset_name
  
  # Convert data frame columns into CODAP attributes format
  attributes <- lapply(names(data), function(col_name) {
    list(name = col_name, title = col_name)
  })
  
  # Convert data frame rows into a list of cases
  cases <- lapply(seq_len(nrow(data)), function(i) {
    row_data <- as.list(data[i, ])
    row_data <- lapply(row_data, function(x) {
      if (is.na(x)) return(NULL) else return(x)
    })
    return(row_data)
  })
  
  # Send data to JavaScript via session$sendCustomMessage()
  session$sendCustomMessage(
    type = "sendToCODAP",
    message = list(
      datasetName = dataset_name,
      attributes = attributes,
      cases = cases
    )
  )
  
  # Show initial notification
  showNotification(...)
})

# Handle CODAP export status feedback from JavaScript
observeEvent(input$codap_export_status, {
  status <- input$codap_export_status
  
  if (!is.null(status) && !is.null(status$success)) {
    if (status$success) {
      showNotification(status$message, type = "message", ...)
    } else {
      showNotification(paste("CODAP Export Error:", status$message), type = "error", ...)
    }
  }
})
```

**Key Components:**
1. `observeEvent(input$send_to_codap, ...)` - Handles button click
2. Data validation and retrieval
3. Attribute conversion: `list(name = colName, title = colName)`
4. Case conversion with NA handling
5. `session$sendCustomMessage()` to JavaScript
6. Status feedback handler for `input$codap_export_status`

---

### 6. Server Logic - Air Quality CODAP Export

**Lines 1618-1676** - Added after `output$download_air_data`:

```r
# =============================================================================
# CODAP EXPORT SERVER LOGIC - Air Quality
# =============================================================================

# observeEvent for "Send to CODAP" button (Air Quality)
observeEvent(input$send_air_to_codap, {
  data <- filtered_air_data()
  
  # [Same structure as Water Quality]
  # - Validation
  # - Dataset name from input$codap_air_dataset_name
  # - Attribute conversion
  # - Case conversion
  # - sendCustomMessage
  # - Notification
})
```

**Uses filtered_air_data()** and **input$codap_air_dataset_name**

---

### 7. Server Logic - Weather & Climate CODAP Export

**Lines 2030-2088** - Added after `output$download_weather_data`:

```r
# =============================================================================
# CODAP EXPORT SERVER LOGIC - Weather & Climate
# =============================================================================

# observeEvent for "Send to CODAP" button (Weather & Climate)
observeEvent(input$send_weather_to_codap, {
  data <- filtered_weather_data()
  
  # [Same structure as Water Quality]
  # - Validation
  # - Dataset name from input$codap_weather_dataset_name
  # - Attribute conversion
  # - Case conversion
  # - sendCustomMessage
  # - Notification
})
```

**Uses filtered_weather_data()** and **input$codap_weather_dataset_name**

---

## Data Flow Diagram

```
User clicks "Send to CODAP" button
         ↓
observeEvent(input$send_to_codap) triggered
         ↓
Get filtered data from reactive
         ↓
Validate data exists
         ↓
Convert columns → CODAP attributes
         ↓
Convert rows → CODAP cases
         ↓
session$sendCustomMessage(type = "sendToCODAP", ...)
         ↓
JavaScript: Shiny.addCustomMessageHandler('sendToCODAP')
         ↓
codapInterface('create', 'dataContext', values)
         ↓
window.parent.postMessage() to CODAP
         ↓
CODAP creates dataset and receives data
         ↓
CODAP responds with success/failure
         ↓
JavaScript: Shiny.setInputValue('codap_export_status')
         ↓
observeEvent(input$codap_export_status)
         ↓
Show success/error notification to user
```

---

## Key Variables and Inputs

### Reactive Values (Unchanged)
- `values$wide_data` - Water quality data
- `values$air_wide_data` - Air quality data
- `values$weather_wide_data` - Weather data

### Reactive Expressions (Unchanged)
- `filtered_wide_data()` - Filtered water quality data
- `filtered_air_data()` - Filtered air quality data
- `filtered_weather_data()` - Filtered weather data

### New Inputs Added
- `input$codap_dataset_name` - Water quality dataset name
- `input$send_to_codap` - Water quality send button
- `input$codap_air_dataset_name` - Air quality dataset name
- `input$send_air_to_codap` - Air quality send button
- `input$codap_weather_dataset_name` - Weather dataset name
- `input$send_weather_to_codap` - Weather send button
- `input$codap_export_status` - Status feedback from JavaScript (created by JS)

---

## Testing the Integration

### 1. Check JavaScript Loaded
Open browser console and verify:
```
CODAP interface initialized
```

### 2. Test Water Quality Export
1. Fetch water quality data
2. Enter dataset name (e.g., "MyWaterData")
3. Click "Send to CODAP"
4. Watch console for:
   - `"Received sendToCODAP message from Shiny:"`
   - `"Sending to CODAP:"`
   - `"DataContext created successfully:"`
   - `"Cases sent successfully:"`

### 3. Test Other Tabs
Repeat for Air Quality and Weather tabs

### 4. Verify in CODAP
- Dataset should appear in CODAP
- Column names should match your data
- All rows should be present
- Values should be correct (no NA issues)

---

## Debugging Tips

### No data sent to CODAP?
- Check: Did you fetch data first?
- Check browser console for errors
- Verify CODAP is running and accessible

### JavaScript errors?
- Open browser console (F12)
- Look for red error messages
- Check if CODAP responded with an error

### Wrong data sent?
- Check the filtered data reactive expressions
- Verify site/station selection is correct
- Check console log for the actual payload

### NA values causing issues?
- The code converts NA to NULL automatically
- Check if dates/numbers are formatted correctly

---

**End of Code Reference Guide**


