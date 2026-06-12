# Package installation is managed by renv (see renv.lock); only load here.
library(shiny)
library(shinydashboard)
library(tidyverse)
library(dataRetrieval)
library(janitor)
library(promises)
library(future)
library(bslib)
plan(multisession)  # Enable async execution for ExtendedTask

# Weather/climateR feature is archived; its packages are intentionally not loaded.

# Load comprehensive FIPS crosswalk data from local file
if (!file.exists("fips-xwalk.csv")) {
  stop("FIPS crosswalk file 'fips-xwalk.csv' not found. Please ensure it is in the app directory.")
}
fips_xwalk <- read_csv("fips-xwalk.csv", show_col_types = FALSE)

# Create state abbreviation to full name lookup
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

# Clean and prepare FIPS data using your exact column structure
fips_clean <- fips_xwalk %>%
  # Your CSV has: fips, name, state (abbreviation)
  mutate(
    # Ensure 5-digit FIPS format
    full_fips = sprintf("%05d", as.numeric(fips)),
    # Extract state and county codes from the 5-digit FIPS
    state_fips = substr(full_fips, 1, 2),
    county_fips = substr(full_fips, 3, 5),
    # Use full county name (remove redundancy)
    county_name = str_remove(name, " County| Parish| Borough| Census Area"),
    county_display = name  # Use full name instead of redundant format
  ) %>%
  # Add full state names using lookup
  left_join(state_lookup, by = c("state" = "state_abbr")) %>%
  # Select final columns
  select(state_fips, county_fips, full_fips, state_name, county_name, county_display) %>%
  # Remove any rows with missing essential data
  filter(!is.na(state_fips), !is.na(county_fips), !is.na(state_name), !is.na(county_name))

# Get unique states for dropdown
states_df <- fips_clean %>%
  distinct(state_name, state_fips) %>%
  arrange(state_name)

# Used for the year-range slider; defaults to last year so the default
# query returns a full year of data.
current_year <- as.integer(format(Sys.Date(), "%Y"))

# CREDIBLE Brand Colors
# Primary (Coral Red): #E63946
# Secondary (Teal): #60C5BA
# Accent (Sage Green): #7A9B76
# Warning (Orange): #F4A261
# Dark: #2D3142

custom_css <- "
@import url('https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700&display=swap');

body, .content-wrapper, .main-sidebar, .main-header {
  font-family: 'Nunito', sans-serif !important;
}

/* Still Water palette — one color family throughout
   Primary:   #3B7A8C  (lake teal)
   Dark:      #2A5F70  (deep water, hovers)
   Muted:     #6A9AA6  (secondary buttons)
   Accent:    #4A9BAA  (status bar, spinner, links)
*/

/* App header — hide the empty navbar bar; keep only the title bar */
.skin-blue .main-header .navbar {
  display: none !important;
}
.skin-blue .main-header,
.skin-blue .main-header .logo {
  background-color: #2A5F70 !important;
}
.skin-blue .main-header .logo {
  width: 100% !important;
  float: none !important;
  text-align: center !important;
}

/* Flat section look (Concord-style structure, our Still Water palette):
   no card chrome - a bold teal label + a thin teal divider per section. */
.box, .box.box-solid, .box.box-primary, .box.box-warning,
.box.box-info, .box.box-success {
  background: transparent !important;
  border: none !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  margin-bottom: 16px !important;
}
.box > .box-header,
.box.box-solid > .box-header {
  background: transparent !important;
  color: #2A5F70 !important;
  padding: 2px 0 8px 0 !important;
  border-bottom: 2px solid #3B7A8C !important;
}
.box > .box-header .box-title {
  font-size: 18px !important;
  font-weight: 700 !important;
  color: #2A5F70 !important;
}
.box > .box-body {
  padding: 12px 2px 2px 2px !important;
}
/* keep the collapse (+/-) control visible on the flat header */
.box > .box-header .box-tools .btn {
  color: #2A5F70 !important;
  background: transparent !important;
  box-shadow: none !important;
}
/* tighter, plugin-scale content padding */
.content-wrapper .content {
  padding: 10px 14px !important;
}

/* Segmented pill toggle for the aggregation choice (our palette) */
#time_aggregation.shiny-options-group {
  display: inline-flex;
  border: 1px solid #3B7A8C;
  border-radius: 999px;
  overflow: hidden;
  margin-top: 4px;
}
#time_aggregation .radio-inline {
  margin: 0 !important;
  padding: 6px 18px !important;
  cursor: pointer;
  color: #2A5F70;
  font-weight: 600;
}
#time_aggregation .radio-inline + .radio-inline {
  border-left: 1px solid #3B7A8C;
}
#time_aggregation .radio-inline input[type=radio] {
  display: none;
}
#time_aggregation .radio-inline:has(input:checked) {
  background: #3B7A8C;
  color: #ffffff;
}

/* Header nav text */
.main-header .navbar-brand {
  color: white !important;
  font-weight: bold !important;
  padding: 15px !important;
}

/* All action buttons — same primary teal */
.btn-primary, .btn-success, .btn-info {
  background-color: #3B7A8C !important;
  border-color: #2A5F70 !important;
  color: white !important;
}
.btn-primary:hover, .btn-success:hover, .btn-info:hover {
  background-color: #2A5F70 !important;
  border-color: #1F4A58 !important;
  color: white !important;
}

/* Clear/Refresh — muted so it reads as secondary, not destructive */
.btn-warning {
  background-color: #6A9AA6 !important;
  border-color: #5A8A96 !important;
  color: white !important;
}
.btn-warning:hover {
  background-color: #5A8A96 !important;
  border-color: #4A7A86 !important;
  color: white !important;
}

/* Status text — compact, sits beside the Get Water Data button */
#status_text {
  color: #2A5F70;
  font-size: 14px;
  font-weight: 600;
  line-height: 1.4;
  white-space: pre-line;  /* render \\n in status messages as line breaks */
}

/* Parameter info tooltip (the i icons) — instant, works inside the CODAP iframe */
.wq-tip {
  position: relative;
  color: #3B7A8C;
  cursor: help;
}
.wq-tip:hover::after {
  content: attr(data-tip);
  position: absolute;
  left: 0;
  bottom: 135%;
  width: 300px;
  max-width: 80vw;
  background: #2A5F70;
  color: #fff;
  padding: 9px 11px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 400;
  line-height: 1.4;
  white-space: normal;
  text-align: left;
  z-index: 10000;
  box-shadow: 0 3px 10px rgba(0,0,0,0.3);
  pointer-events: none;
}
.wq-tip:hover::before {
  content: '';
  position: absolute;
  left: 12px;
  bottom: 123%;
  border: 6px solid transparent;
  border-top-color: #2A5F70;
  z-index: 10000;
  pointer-events: none;
}

/* Loading */
.loading-container {
  text-align: center;
  padding: 30px;
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  margin: 20px 0;
}
.loading-spinner {
  display: inline-block;
  width: 40px;
  height: 40px;
  border: 3px solid #e0ecef;
  border-radius: 50%;
  border-top-color: #3B7A8C;
  animation: spin 1s ease-in-out infinite;
  margin-bottom: 15px;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}

/* CODAP send status (inline, next to the Send to CODAP button) */
.codap-status { display: inline-block; vertical-align: middle; }
.codap-status-busy { color: #4A9BAA; }
.codap-status-busy::before {
  content: '';
  display: inline-block;
  width: 14px;
  height: 14px;
  margin-right: 8px;
  vertical-align: -2px;
  border: 2px solid #cfe3e8;
  border-top-color: #3B7A8C;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
.codap-status-ok  { color: #2e7d32; }
.codap-status-err { color: #c62828; }
button#send_to_codap.disabled,
button#send_to_codap:disabled {
  opacity: 0.65;
  cursor: not-allowed;
}
.progress-bar-custom {
  width: 100%;
  height: 6px;
  background-color: #e0ecef;
  border-radius: 3px;
  overflow: hidden;
  margin-top: 10px;
}
.progress-bar-fill {
  height: 100%;
  background-color: #3B7A8C;
  border-radius: 3px;
  animation: progress 3s ease-in-out infinite;
}
@keyframes progress {
  0%   { width: 0%; }
  50%  { width: 70%; }
  100% { width: 100%; }
}

/* Details / summary */
details {
  background-color: #f8f9fa;
  border-radius: 6px;
  padding: 15px;
  border: 1px solid #dee2e6;
  margin: 10px 0;
}
summary {
  font-weight: bold;
  cursor: pointer;
  margin-bottom: 10px;
  color: #2A5F70;
}
details[open] summary {
  margin-bottom: 15px;
  padding-bottom: 10px;
  border-bottom: 1px solid #dee2e6;
}

/* Links */
a {
  color: #3B7A8C !important;
}
a:hover {
  color: #2A5F70 !important;
}

/* Tab navigation pills - improved readability */
.nav-pills > li > a {
  background-color: #e9ecef !important;
  color: #495057 !important;
  font-weight: 500 !important;
  border-radius: 5px !important;
  margin-right: 5px !important;
}
.nav-pills > li > a:hover {
  background-color: #6A9AA6 !important;
  color: white !important;
}
.nav-pills > li.active > a,
.nav-pills > li.active > a:hover,
.nav-pills > li.active > a:focus {
  background-color: #3B7A8C !important;
  color: white !important;
  font-weight: 600 !important;
}
"

# Static assets (logo, vendored JS) are served from the www/ directory,
# which Shiny exposes automatically.

# UI
ui <- dashboardPage(
  dashboardHeader(
    title = "CREDIBLE Local Data"
  ),
  
  dashboardSidebar(disable = TRUE),
  
  dashboardBody(
    # Include custom CSS
    tags$head(
      tags$style(HTML(custom_css)),
      # iframe-phone is vendored locally (www/iframe-phone.js) so the CODAP
      # connection works on school networks that block CDNs.
      tags$script(src = "iframe-phone.js"),
      tags$script(HTML("
        // Initialize CODAP connection using IFramePhone
        var codapPhone = null;
        var codapConnectionInitialized = false;

        function initCodapConnection() {
          if (codapConnectionInitialized) return;

          try {
            console.log('Initializing CODAP connection with IFramePhone...');

            // Check if IFramePhone is available
            if (typeof iframePhone === 'undefined') {
              console.error('IFramePhone library not loaded');
              return;
            }

            // Create phone connection to CODAP
            codapPhone = new iframePhone.IframePhoneRpcEndpoint(
              function(command, callback) {
                // Handler for messages FROM CODAP (we don't expect any in this simple case)
                console.log('Received message from CODAP:', command);
                if (callback) callback({success: true});
              },
              'data-interactive',
              window.parent
            );

            codapConnectionInitialized = true;
            console.log('CODAP connection established successfully');
          } catch (e) {
            console.error('Error initializing CODAP connection:', e);
          }
        }

        // Call init when page loads
        window.addEventListener('load', function() {
          initCodapConnection();
        });

        // CODAP Interface Helper Function
        // This function sends messages to CODAP using the Data Interactive Plugin API via IFramePhone
        function codapInterface(action, resource, values) {
          return new Promise(function(resolve, reject) {
            // Check if running inside CODAP (has a parent frame different from self)
            if (window === window.parent) {
              console.warn('Not running inside CODAP - no parent frame detected');
              reject({
                error: 'Not running in CODAP',
                message: 'This app must be embedded in CODAP to use the Send to CODAP feature. Please open CODAP at codap.concord.org and add this app as a Data Interactive plugin.',
                helpUrl: 'https://codap.concord.org/'
              });
              return;
            }

            // Initialize connection if not already done
            if (!codapConnectionInitialized) {
              initCodapConnection();
            }

            // Check if phone is available
            if (!codapPhone) {
              reject({
                error: 'CODAP connection not established',
                message: 'Unable to establish connection with CODAP. Make sure you are using the latest CODAP version.',
                helpUrl: 'https://codap.concord.org/'
              });
              return;
            }

            var message = {
              action: action,
              resource: resource,
              values: values
            };

            console.log('Sending to CODAP via IFramePhone:', message);

            // Send via IFramePhone
            codapPhone.call(message, function(response) {
              console.log('CODAP Response:', response);
              if (response && response.success) {
                resolve(response);
              } else {
                reject(response || {error: 'Unknown error', message: 'CODAP returned an error'});
              }
            });
          });
        }
        
        // Custom Shiny Message Handler: sendToCODAP
        // This receives data from R/Shiny and sends it to CODAP
        Shiny.addCustomMessageHandler('sendToCODAP', function(payload) {
          console.log('Received sendToCODAP message from Shiny:', payload);

          var ctxName    = payload.contextName  || 'WaterQualityQueries';
          var ctxTitle   = payload.contextTitle || 'CREDIBLE Water Quality Data';
          var parentAttrs = payload.parentAttrs || [];
          var childAttrs  = payload.childAttrs  || [];
          var items      = payload.items || [];
          var queryLabel = payload.queryLabel || 'query';
          var nRows      = payload.nRows || items.length;

          var btn = document.getElementById('send_to_codap');
          var statusEl = document.getElementById('codap_send_status');
          function setStatus(text, cls) {
            if (statusEl) { statusEl.className = cls || ''; statusEl.textContent = text || ''; }
          }
          function setBusy(busy) {
            if (!btn) return;
            btn.disabled = busy;
            if (busy) { btn.classList.add('disabled'); } else { btn.classList.remove('disabled'); }
          }

          setBusy(true);
          setStatus('Sending data to CODAP…', 'codap-status codap-status-busy');

          // Is the shared data context already present?
          codapInterface('get', 'dataContext[' + ctxName + ']')
          .then(function() { return true; })
          .catch(function() { return false; })
          .then(function(exists) {
            if (exists) { return false; }  // reuse it; this query becomes a new parent case
            // First query: create the hierarchical context (Queries -> Measurements)
            return codapInterface('create', 'dataContext', {
              name: ctxName,
              title: ctxTitle,
              description: 'Water quality queries from CREDIBLE Local Data',
              collections: [
                { name: 'queries', title: 'Queries', attrs: parentAttrs },
                { name: 'measurements', title: 'Measurements', parent: 'queries', attrs: childAttrs }
              ]
            }).then(function() { return true; });  // created
          })
          .then(function(created) {
            // Add this query's rows. CODAP groups them under one parent
            // (Queries) case by the parent attribute values; fetched_at makes
            // every Send its own parent case.
            return codapInterface('create', 'dataContext[' + ctxName + '].item', items)
              .then(function() { return created; });
          })
          .then(function(created) {
            // Open one case table the first time only; later sends update it live.
            if (!created) { return null; }
            return codapInterface('create', 'component', {
              type: 'caseTable',
              dataContext: ctxName,
              name: ctxName + '_table',
              title: ctxTitle
            }).catch(function(e) { console.warn('Could not auto-open case table:', e); return null; });
          })
          .then(function() {
            setBusy(false);
            setStatus('✓ Added ' + nRows + ' rows under “' + queryLabel + '”', 'codap-status codap-status-ok');
            Shiny.setInputValue('codap_export_status', {
              success: true,
              message: 'Added ' + nRows + ' rows to CODAP under the query “' + queryLabel + '”. Open the Queries table to compare your queries.',
              timestamp: new Date().getTime()
            }, {priority: 'event'});
          })
          .catch(function(error) {
            console.error('Error sending data to CODAP:', error);
            var errorMsg = error.message || error.error || 'Unknown error';
            if (error.helpUrl) { errorMsg += ' Visit: ' + error.helpUrl; }
            setBusy(false);
            setStatus('Couldn’t send to CODAP — see the message below.', 'codap-status codap-status-err');
            Shiny.setInputValue('codap_export_status', {
              success: false,
              message: errorMsg,
              timestamp: new Date().getTime()
            }, {priority: 'event'});
          });
        });
        
        console.log('CODAP interface initialized');
      "))
    ),

    # Tab layout for Water Quality and Air Quality
    tabsetPanel(
      id = "main_tabs", type = "pills",

      # ======================================================================
      # WATER QUALITY TAB
      # ======================================================================
      tabPanel("Water Quality",
        br(),

        # ============================================================
        # STEP 1 - Choose a location
        # ============================================================
        fluidRow(
          box(
            title = "Step 1 · Choose a location",
            status = "primary", solidHeader = TRUE, width = 12,
            div(style = "display: flex; gap: 16px; flex-wrap: wrap;",
              div(style = "flex: 1 1 40%; min-width: 150px;",
                selectInput("state_selection", "State",
                  choices = c("Choose a state..." = "",
                              setNames(states_df$state_name, states_df$state_name)),
                  selected = "Tennessee", width = "100%")
              ),
              div(style = "flex: 1 1 55%; min-width: 200px;",
                selectizeInput("county_selection", "County (pick one or more)",
                  choices = {
                    tn <- fips_clean[fips_clean$state_name == "Tennessee", "county_display", drop = TRUE]
                    setNames(tn, tn)
                  },
                  selected = "Knox County",
                  multiple = TRUE,
                  width = "100%",
                  options = list(placeholder = "Select one or more counties"))
              )
            )
          )
        ),

        # ============================================================
        # STEP 2 - Choose what to measure
        # ============================================================
        fluidRow(
          box(
            title = "Step 2 · Choose what to measure",
            status = "primary", solidHeader = TRUE, width = 12,
            p("Pick the measurements you want. Hover the ",
              tags$span(icon("info-circle"), style = "color:#3B7A8C;"),
              " for a quick explanation, or click the ",
              tags$span(icon("external-link"), style = "color:#3B7A8C;"),
              " for the EPA fact sheet."),
            checkboxGroupInput(
              "parameters_primary",
              NULL,
              choiceNames = list(
                tags$span(
                  "pH ",
                  tags$span(
                    icon("info-circle"),
                    class = "wq-tip",
                    `data-tip` = "EPA pH fact sheet: pH measures the hydrogen ion balance of water and affects aquatic life. Most waters that support aquatic life fall between pH 6.5 and 9.0.",
                    style = "margin-left: 4px;"
                  ),
                  tags$a(
                    icon("external-link"),
                    href = "https://www.epa.gov/system/files/documents/2021-07/parameter-factsheet_ph.pdf",
                    target = "_blank",
                    title = "Open EPA pH fact sheet",
                    style = "margin-left: 6px;"
                  )
                ),
                tags$span(
                  "Turbidity ",
                  tags$span(
                    icon("info-circle"),
                    class = "wq-tip",
                    `data-tip` = "EPA turbidity fact sheet: Settleable and suspended solids should not reduce the depth of the compensation point for photosynthetic activity by more than 10 percent from the seasonally established norm for aquatic life.",
                    style = "margin-left: 4px;"
                  ),
                  tags$a(
                    icon("external-link"),
                    href = "https://www.epa.gov/system/files/documents/2021-07/parameter-factsheet_turbidity.pdf",
                    target = "_blank",
                    title = "Open EPA turbidity fact sheet",
                    style = "margin-left: 6px;"
                  )
                ),
                tags$span(
                  "Temperature ",
                  tags$span(
                    icon("info-circle"),
                    class = "wq-tip",
                    `data-tip` = "EPA temperature fact sheet: Water temperature shapes habitat quality, organism metabolism, and how much dissolved oxygen water can hold.",
                    style = "margin-left: 4px;"
                  ),
                  tags$a(
                    icon("external-link"),
                    href = "https://www.epa.gov/system/files/documents/2021-07/parameter-factsheet_temperature.pdf",
                    target = "_blank",
                    title = "Open EPA temperature fact sheet",
                    style = "margin-left: 6px;"
                  )
                ),
                tags$span(
                  "Dissolved oxygen ",
                  tags$span(
                    icon("info-circle"),
                    class = "wq-tip",
                    `data-tip` = "EPA dissolved oxygen fact sheet: Dissolved oxygen is essential for fish and aquatic organisms, and low concentrations can stress or kill aquatic life.",
                    style = "margin-left: 4px;"
                  ),
                  tags$a(
                    icon("external-link"),
                    href = "https://www.epa.gov/system/files/documents/2021-07/parameter-factsheet_do.pdf",
                    target = "_blank",
                    title = "Open EPA dissolved oxygen fact sheet",
                    style = "margin-left: 6px;"
                  )
                ),
                tags$span(
                  "E. coli ",
                  tags$span(
                    icon("info-circle"),
                    class = "wq-tip",
                    `data-tip` = "EPA E. coli fact sheet: Geometric mean of 126 cfu/100 mL and statistical threshold value (STV) of 410 cfu/100 mL for recreational waters. E. coli indicates fecal contamination.",
                    style = "margin-left: 4px;"
                  ),
                  tags$a(
                    icon("external-link"),
                    href = "https://www.epa.gov/system/files/documents/2021-07/parameter-factsheet_e.-coli.pdf",
                    target = "_blank",
                    title = "Open EPA E. coli fact sheet",
                    style = "margin-left: 6px;"
                  )
                )
              ),
              choiceValues = c("pH", "Turbidity", "Temperature", "Dissolved oxygen", "Escherichia coli"),
              selected = c("pH", "Turbidity", "Temperature", "Dissolved oxygen", "Escherichia coli"),
              inline = FALSE
            ),

            tags$details(
              tags$summary("More options (year range and extra parameters)"),
              tags$div(style = "padding-top: 12px;",
                sliderInput("year_selection", "Year range",
                  min = 1960, max = current_year,
                  value = c(current_year - 1, current_year - 1),
                  step = 1, sep = ""),
                tags$label("Additional parameters",
                  style = "font-weight: 600; display: block; margin-bottom: 6px;"),
                checkboxGroupInput("parameters_additional", NULL,
                  choices = c("Phosphorus" = "Phosphorus",
                              "Nitrate" = "Nitrate",
                              "Nitrite" = "Nitrite",
                              "Conductivity" = "Conductivity",
                              "Total dissolved solids" = "Total dissolved solids",
                              "Alkalinity" = "Alkalinity",
                              "Hardness" = "Hardness",
                              "Chloride" = "Chloride",
                              "Sulfate" = "Sulfate",
                              "Ammonia" = "Ammonia",
                              "Total nitrogen" = "Total nitrogen"),
                  selected = character(0),
                  inline = TRUE)
              )
            )
          )
        ),

        # ============================================================
        # STEP 3 - Get your data
        # ============================================================
        fluidRow(
          box(
            title = "Step 3 · Get your data",
            status = "primary", solidHeader = TRUE, width = 12,
            div(style = "display: flex; align-items: center; gap: 16px; flex-wrap: wrap;",
              actionButton("fetch_data", "Get Water Data",
                class = "btn-primary btn-lg", icon = icon("download")),
              div(style = "flex: 1 1 220px; min-width: 200px;",
                textOutput("status_text")
              )
            )
          )
        ),

        # Loading indicator
        conditionalPanel(
          condition = "output.loading_visible == true",
          fluidRow(
            box(
              title = "Working…", status = "primary", solidHeader = TRUE, width = 12,
              div(class = "loading-container",
                div(class = "loading-spinner"),
                h4("Fetching water quality data…"),
                p("Connecting to the USGS Water Quality Portal. This usually takes 10–60 seconds, depending on the location and year range.")
              )
            )
          )
        ),

        # Results - appears after data is fetched
        conditionalPanel(
          condition = "output.data_fetched == true",

          fluidRow(
            box(
              title = "Refine your data (optional)",
              status = "primary", solidHeader = TRUE, width = 12,
              collapsible = TRUE, collapsed = TRUE,
              fluidRow(
                column(6,
                  selectInput("site_selection", "Monitoring site(s)",
                    choices = c("All sites" = "all"),
                    selected = "all", multiple = TRUE),
                  p(style = "font-size: 12px; color: #6c757d;",
                    "Focus on specific monitoring sites within your location. ",
                    "The five most active sites are listed; “All sites” includes every site in your data.")
                ),
                column(6,
                  radioButtons("time_aggregation", "Combine measurements by",
                    choices = c("Raw data" = "none", "Monthly" = "month"),
                    selected = "month", inline = TRUE),
                  p(style = "font-size: 12px; color: #6c757d;",
                    "Averages the measurements within each period to reduce gaps and data size.")
                )
              )
            )
          ),

          fluidRow(
            box(
              title = "Send your data", status = "primary", solidHeader = TRUE, width = 12,
              div(style = "margin-top: 4px;",
                div(style = "margin-bottom: 12px;",
                  actionButton("send_to_codap", "Send to CODAP",
                    class = "btn-primary btn-lg", icon = icon("chart-bar"),
                    style = "font-size: 16px; padding: 12px 24px;"),
                  span(id = "codap_send_status",
                    style = "margin-left: 12px; font-size: 14px; font-weight: 600; vertical-align: middle;"),
                  p(style = "font-size: 12px; color: #6c757d; margin-top: 8px; margin-bottom: 0;",
                    tags$strong("CODAP"),
                    " is a free online tool for making graphs and exploring data. ",
                    "Your selected data opens there instantly — no download needed. ",
                    tags$a(href = "https://codap.concord.org/", target = "_blank",
                      "What’s CODAP?"))
                ),
                div(
                  downloadButton("download_wide", "Download as CSV",
                    class = "btn-warning", icon = icon("download")),
                  span(style = "font-size: 12px; color: #6c757d; margin-left: 10px;",
                    "For use in spreadsheet software")
                )
              )
            )
          )
        ),

      ), # end Water Quality tabPanel

      # ======================================================================
      # ABOUT TAB
      # ======================================================================
      tabPanel("About",
        br(),
        fluidRow(
          box(
            title = "About CREDIBLE Local Data", status = "primary",
            solidHeader = TRUE, width = 12,
            p("CREDIBLE Local Data helps middle and high school learners collect local water quality data and send it to CODAP to make graphs and explore patterns."),
            div(style = "text-align: center; padding: 8px 0 4px 0;",
              tags$img(src = "credible-logo.png", height = "100px",
                       style = "display: block; margin: 0 auto 8px auto; mix-blend-mode: multiply;"),
              tags$a(href = "https://projectcredible.com", target = "_blank",
                     style = "font-size: 12px; color: #3B7A8C;", "projectcredible.com")
            )
          )
        )
      ) # end About tabPanel
    ) # end tabsetPanel
  )
)

# Server function
server <- function(input, output, session) {
    
    # Reactive values to store data
    values <- reactiveValues(
      # Water quality data
      long_data = NULL,
      wide_data = NULL,
      data_fetched = FALSE,
      status = "Ready to fetch water quality data...",
      current_state_fips = "",
      current_county_fips = "",
      current_location = "",
      loading_visible = FALSE,
      available_sites = NULL,
      fetch_start_time = NULL  # Track when fetch started for elapsed time display
    )
    
    # Make loading_visible available as an input for the conditional panel
    output$loading_visible <- reactive({
      values$loading_visible
    })
    outputOptions(output, "loading_visible", suspendWhenHidden = FALSE)
    
    # Make data_fetched available for the conditional panel
    output$data_fetched <- reactive({
      values$data_fetched
    })
    outputOptions(output, "data_fetched", suspendWhenHidden = FALSE)

    # ============================================================
    # ExtendedTask for Water Quality API calls (async)
    # ============================================================
    water_fetch_task <- ExtendedTask$new(function(qry, location) {
      future({
        # These API calls run in a separate R process, allowing UI to update.
        # The Water Quality Portal rejects requests with multiple countycode
        # values (HTTP 500), so query one county at a time and combine.
        fetch_one <- function(code) {
          q <- qry
          q$countycode <- code
          list(
            wq = do.call(dataRetrieval::readWQPdata, q),
            meta = do.call(dataRetrieval::whatWQPsites, q)
          )
        }
        parts <- lapply(qry$countycode, fetch_one)
        wq_raw <- dplyr::bind_rows(lapply(parts, function(p) p$wq))
        meta_df <- dplyr::distinct(dplyr::bind_rows(lapply(parts, function(p) p$meta)))
        list(wq_raw = wq_raw, meta_df = meta_df, location = location)
      }, seed = TRUE)
    }) |> bslib::bind_task_button("fetch_data")


    # Observer for elapsed time display during water quality fetch.
    # req() suspends the observer while idle, so the once-per-second tick
    # only runs during an active fetch.
    observe({
      req(values$loading_visible, values$fetch_start_time)
      invalidateLater(1000)  # Update every second
      elapsed <- round(difftime(Sys.time(), values$fetch_start_time, units = "secs"))
      values$status <- paste0("Requesting data from USGS Water Quality Portal... (", elapsed, " seconds)")
    })

    # Observer for water quality task completion (success or error).
    # Keyed on status() rather than result(): result() rethrows the task's
    # error, so using it as the event expression would crash the session
    # whenever the API call fails. (ExtendedTask has no error() method;
    # the error is retrieved by calling result() inside tryCatch.)
    observeEvent(water_fetch_task$status(), {
      task_status <- water_fetch_task$status()

      if (task_status == "error") {
        err_msg <- tryCatch({
          water_fetch_task$result()
          "Unknown error"
        }, error = function(e) conditionMessage(e))
        values$status <- paste0(
          "Oops! Something went wrong while fetching data.\n\n",
          "Technical details: ", err_msg, "\n\n",
          "What you can try:\n",
          "- Wait a moment and click 'Get Water Data' again\n",
          "- Check your internet connection\n",
          "- Try selecting a different county or smaller year range\n",
          "- Ask your teacher for help if this keeps happening"
        )
        showNotification(
          "There was a problem fetching data. Try again or select different options.",
          type = "error", duration = 8
        )
        values$loading_visible <- FALSE
        values$fetch_start_time <- NULL
        return()
      }

      if (task_status != "success") return()

      result <- water_fetch_task$result()
      wq_raw <- result$wq_raw
      meta_df <- result$meta_df
      location <- result$location

      # Get year range text from input (still available in main process)
      start_year <- input$year_selection[1]
      end_year <- input$year_selection[2]
      year_range_text <- if (start_year == end_year) {
        paste("Year", start_year)
      } else {
        paste("Years", start_year, "-", end_year)
      }

      values$status <- paste("Processing", nrow(wq_raw), "samples from", location, "...")

      if (nrow(wq_raw) == 0) {
        values$status <- paste0(
          "No water quality data found for ", location, ".\n\n",
          "This might mean:\n",
          "- This county doesn't have water quality monitoring stations\n",
          "- No data was collected during your selected years\n",
          "- The selected parameters aren't monitored here\n\n",
          "Try: Select a different county, expand your year range, or choose different parameters."
        )
        showNotification(
          paste("No data found for", location, "- try a different county or expand your year range"),
          type = "warning", duration = 8
        )
        values$loading_visible <- FALSE
        values$fetch_start_time <- NULL
        return()
      }

      # Clean names
      wq_clean <- wq_raw %>% janitor::clean_names()
      meta <- meta_df %>% janitor::clean_names()

      # Process data following updated script logic
      lat_col <- grep("latitude", names(meta), value = TRUE)[1]
      lon_col <- grep("longitude", names(meta), value = TRUE)[1]
      cnty_col <- grep("county_code", names(meta), value = TRUE)[1]

      wq_tidy <- wq_clean %>%
        transmute(
          site_id = monitoring_location_identifier,
          date = activity_start_date,
          parameter = characteristic_name,
          value = as.numeric(result_measure_value),
          unit = result_measure_measure_unit_code
        )

      meta_trim <- meta %>%
        transmute(
          site_id = monitoring_location_identifier,
          site_name = monitoring_location_name,
          lat = .data[[lat_col]],
          lon = .data[[lon_col]],
          county_fips = if (is.na(cnty_col)) NA_character_
                        else sprintf("%03d", suppressWarnings(as.integer(.data[[cnty_col]])))
        ) %>%
        # Resolve each site to its own county name so multi-county queries
        # label every row correctly (not with the combined location string).
        left_join(
          fips_clean %>%
            filter(state_fips == values$current_state_fips) %>%
            select(county_fips, county_display),
          by = "county_fips"
        ) %>%
        mutate(county = coalesce(county_display, location)) %>%
        select(site_id, site_name, county, lat, lon)

      # Join samples with metadata
      wq_join <- wq_tidy %>%
        left_join(meta_trim, by = "site_id") %>%
        relocate(site_name, county, lat, lon, .after = site_id)

      # Standardise units in two steps so pivot_wider never averages values
      # measured on different scales.
      # Step 1: convert known unit variants to a canonical unit.
      ug_units <- c("ug/l", "µg/l", "ug/L", "µg/L")
      f_units  <- c("deg F", "deg f")
      ms_units <- c("mS/cm", "ms/cm")
      wq_join <- wq_join %>%
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

      # Step 2: within each parameter, keep only the most common unit.
      # Anything still in another unit can't be combined safely, so it is
      # dropped (and counted for the status message).
      n_before_units <- nrow(wq_join)
      wq_join <- wq_join %>%
        mutate(.unit_key = coalesce(unit, "(none)")) %>%
        group_by(parameter) %>%
        filter(.unit_key == names(which.max(table(.unit_key)))) %>%
        ungroup() %>%
        select(-.unit_key)
      n_dropped_units <- n_before_units - nrow(wq_join)

      # Create long format
      values$long_data <- wq_join

      # Create wide format. Drop `unit` BEFORE pivoting so it is not treated as
      # an id column (different parameters have different units, which would
      # otherwise split each parameter onto its own row). Use values_fn to
      # average multiple same-day samples so the parameter columns stay atomic
      # numeric instead of becoming list-columns.
      wq_wide <- wq_join %>%
        select(-unit) %>%
        pivot_wider(
          names_from = parameter,
          values_from = value,
          values_fn = function(x) mean(x, na.rm = TRUE)
        ) %>%
        mutate(state = input$state_selection) %>%
        select(state, county, site_id, site_name, lat, lon, date, everything())

      values$wide_data <- wq_wide

      # Get top 5 most active sites (by measurement count)
      available_sites <- wq_join %>%
        group_by(site_id, site_name) %>%
        summarise(n_measurements = n(), .groups = "drop") %>%
        arrange(desc(n_measurements)) %>%
        slice_head(n = 5) %>%
        mutate(
          # Create informative label with measurement count
          display_label = paste0(site_name, " (", n_measurements, " measurements)")
        )

      values$available_sites <- available_sites
      values$data_fetched <- TRUE

      # Update site selector choices with informative labels. The dropdown
      # lists only the five most active sites; "All sites" covers every site.
      n_sites_total <- length(unique(wq_join$site_id))
      site_choices <- c(
        setNames("all", paste0("All sites (", n_sites_total, " total)")),
        setNames(available_sites$site_id, available_sites$display_label)
      )
      updateSelectInput(session, "site_selection",
                        choices = site_choices,
                        selected = "all")

      # Get unique parameters found in the data
      found_parameters <- unique(wq_join$parameter)

      unit_note <- if (n_dropped_units > 0) {
        paste0(" (", n_dropped_units, " readings in nonstandard units were excluded.)")
      } else {
        ""
      }
      values$status <- paste0(
        "Data processing complete for ", location, "! Found ",
        nrow(wq_join), " measurements from ",
        n_sites_total, " monitoring sites. Year range: ", year_range_text,
        " - Parameters found: ", paste(found_parameters, collapse = ", "),
        unit_note
      )

      showNotification("Data fetched successfully!", type = "message", duration = 5)

      # Hide loading indicator
      values$loading_visible <- FALSE
      values$fetch_start_time <- NULL
    })

    # Update county choices when state changes
    observeEvent(input$state_selection, {
      if (input$state_selection != "") {
        # Get state FIPS code
        state_info <- states_df[states_df$state_name == input$state_selection, ]

        if (nrow(state_info) > 0) {
          # Filter counties for this state
          counties_for_state <- fips_clean %>%
            filter(state_fips == state_info$state_fips) %>%
            arrange(county_name)

          county_choices <- setNames(counties_for_state$county_display, counties_for_state$county_display)

          # Set default to Knox County if Tennessee is selected
          default_county <- if(input$state_selection == "Tennessee") "Knox County" else character(0)

        } else {
          county_choices <- c()
          default_county <- character(0)
        }

        updateSelectizeInput(session, "county_selection", choices = county_choices, selected = default_county)
      }
    })
    
    # Show warning for large year ranges
    observeEvent(input$year_selection, {
      if (!is.null(input$year_selection) && length(input$year_selection) == 2) {
        year_range <- input$year_selection[2] - input$year_selection[1] + 1
        if (year_range > 3) {
          warning_text <- paste("Loading", year_range, "years of data may take 30-90 seconds depending on data availability.")
          showNotification(warning_text, type = "warning", duration = 6)
        }
      }
    })
    
    # Data fetching logic (dropdown selection) - now uses ExtendedTask for async API calls
    observeEvent(input$fetch_data, {

      # Validate inputs
      if (input$state_selection == "" || is.null(input$county_selection) || length(input$county_selection) == 0) {
        showNotification("Please select state and at least one county", type = "error", duration = 5)
        return()
      }

      # Validate year selection
      if (is.null(input$year_selection) || length(input$year_selection) != 2) {
        showNotification("Please select a year range", type = "error", duration = 5)
        return()
      }

      # Combine parameter selections
      selected_parameters <- c(input$parameters_primary, input$parameters_additional)

      # Validate parameter selection
      if (is.null(selected_parameters) || length(selected_parameters) == 0) {
        showNotification("Please select at least one water quality parameter", type = "error", duration = 5)
        return()
      }

      # Get FIPS codes for all selected counties
      county_info <- fips_clean %>%
        filter(state_name == input$state_selection,
               county_display %in% input$county_selection)

      if (nrow(county_info) == 0) {
        showNotification("County not found in database. Please try again.", type = "error", duration = 5)
        return()
      }

      # Store state FIPS (same for all counties in a state)
      values$current_state_fips <- county_info$state_fips[1]

      # Store county FIPS as a vector for multiple counties
      values$current_county_fips <- county_info$county_fips

      # Build location display
      values$current_location <- if (length(input$county_selection) == 1) {
        paste(input$county_selection, input$state_selection, sep = ", ")
      } else {
        paste0(paste(input$county_selection, collapse = ", "), ", ", input$state_selection)
      }

      # Build county codes for query
      county_codes <- paste0("US:", values$current_state_fips, ":", values$current_county_fips)

      # Build query
      start_year <- input$year_selection[1]
      end_year <- input$year_selection[2]
      
      start_date <- paste0(start_year, "-01-01")
      end_date <- paste0(end_year, "-12-31")

      qry <- list(
        countycode = county_codes,
        characteristicName = selected_parameters,
        sampleMedia = "Water",
        startDateLo = start_date,
        startDateHi = end_date,
        siteType = "Stream"
      )

      # Show loading indicator and start timer
      values$loading_visible <- TRUE
      values$fetch_start_time <- Sys.time()
      values$status <- "Requesting data from USGS Water Quality Portal... (0 seconds)"

      # Invoke the async task - UI will remain responsive
      water_fetch_task$invoke(qry, values$current_location)
    })
    

    
    # Clear/refresh removed: re-fetching with new selections replaces results.

    # Status output
    output$status_text <- renderText({
      values$status
    })
    
    # Data filtering based on site selection
    filtered_wide_data <- reactive({
      if (!is.null(values$wide_data)) {
        # First filter by site
        data <- if ("all" %in% input$site_selection || is.null(input$site_selection)) {
          values$wide_data
        } else {
          values$wide_data %>% filter(site_id %in% input$site_selection)
        }

        # Then apply monthly aggregation if selected ("Raw data" and
        # "Monthly" are the only choices the UI offers)
        if (!is.null(input$time_aggregation) && input$time_aggregation == "month") {
          data <- data %>%
            mutate(
              date = as.Date(date),
              time_period = format(date, "%Y-%m")
            ) %>%
            group_by(state, county, site_id, site_name, time_period) %>%
            summarise(
              across(where(is.numeric), ~mean(.x, na.rm = TRUE)),
              n_measurements = n(),
              date_range = paste(min(date, na.rm = TRUE), "to", max(date, na.rm = TRUE)),
              .groups = "drop"
            ) %>%
            rename(date = time_period) %>%
            select(state, county, site_id, site_name, date, everything())
        }

        return(data)
      }
    })
    
    # Download handler
    output$download_wide <- downloadHandler(
      filename = function() {
        location_safe <- gsub("[^A-Za-z0-9]", "_", values$current_location)
        site_suffix <- if("all" %in% input$site_selection) "all_sites" else "selected_sites"
        agg_suffix <- if(!is.null(input$time_aggregation) && input$time_aggregation == "month") {
          "_monthly"
        } else {
          ""
        }
        paste0("water_quality_", location_safe, "_", site_suffix, agg_suffix, "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        data <- filtered_wide_data()
        if (!is.null(data)) {
          write_csv(data %>% select(-any_of(c("site_id", "row_id"))), file)
        }
      }
    )
    
    # =============================================================================
    # CODAP EXPORT SERVER LOGIC - Water Quality
    # =============================================================================
    
    # observeEvent for "Send to CODAP" button (Water Quality)
    observeEvent(input$send_to_codap, {
      # Get the filtered data
      data <- filtered_wide_data()
      
      # Validate that data exists
      if (is.null(data) || nrow(data) == 0) {
        showNotification("No data available to send to CODAP. Please fetch water quality data first.", 
                         type = "error", duration = 5)
        return()
      }
      
      # Build a friendly dataset title from the location + year range, plus a
      # machine-safe name CODAP can use as an identifier. This replaces the old
      # (non-existent) input$codap_dataset_name so students can tell datasets
      # apart in CODAP when they compare locations or time periods.
      loc <- if (!is.null(values$current_location) && nzchar(values$current_location)) {
        values$current_location
      } else {
        "Local"
      }
      yr <- if (!is.null(input$year_selection) && length(input$year_selection) == 2) {
        paste0(" ", input$year_selection[1], "-", input$year_selection[2])
      } else {
        ""
      }
      agg_label <- if (!is.null(input$time_aggregation) && input$time_aggregation == "month") {
        " (Monthly)"
      } else {
        ""
      }
      dataset_title <- paste0(loc, " Water Quality", yr, agg_label)
      # Machine-safe identifier: alphanumerics collapsed to single underscores
      dataset_name <- gsub("(^_+|_+$)", "", gsub("[^A-Za-z0-9]+", "_", dataset_title))
      if (!nzchar(dataset_name)) dataset_name <- "WaterQualityData"
      
      # ---- Hierarchical CODAP export ----
      # One shared data context with a parent "Queries" collection (one case
      # per query) and a child "Measurements" collection (the rows). Each Send
      # adds a new parent case + its rows, so students can compare multiple
      # queries side by side in a single CODAP table.
      context_name  <- "WaterQualityQueries"
      context_title <- "CREDIBLE Water Quality Data"

      year_range <- if (!is.null(input$year_selection) && length(input$year_selection) == 2) {
        if (input$year_selection[1] == input$year_selection[2]) {
          as.character(input$year_selection[1])
        } else {
          paste0(input$year_selection[1], "-", input$year_selection[2])
        }
      } else {
        ""
      }
      aggregation <- if (!is.null(input$time_aggregation) && input$time_aggregation == "month") {
        "Monthly"
      } else {
        "None"
      }

      # Non-measurement columns (everything else is a parameter)
      non_param_cols <- c("state", "county", "site_id", "site_name", "lat", "lon",
                          "date", "n_measurements", "date_range")
      param_cols <- setdiff(names(data), non_param_cols)

      # Parent ("Queries") fields - identical for every row of this Send.
      # fetched_at makes each Send its own parent case (no accidental merging).
      query_fields <- list(
        query       = dataset_title,
        location    = loc,
        year_range  = year_range,
        aggregation = aggregation,
        parameters  = paste(param_cols, collapse = ", "),
        n_rows      = nrow(data),
        fetched_at  = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      )
      parent_attrs <- lapply(names(query_fields), function(n) list(name = n, title = n))

      # Child ("Measurements") columns: drop state (carried by the parent)
      # but keep county, which can differ per site in multi-county queries.
      # Also drop site_id: it is only needed server-side for filtering, and
      # its cryptic code (e.g. "TDECWR…", "11NPS…") is what CODAP would
      # otherwise show on map points. site_name (the creek name) stays the
      # first Measurements attribute, so CODAP labels map points by creek.
      child_data  <- data[, setdiff(names(data), c("state", "site_id")), drop = FALSE] %>%
        relocate(site_name)
      child_attrs <- lapply(names(child_data), function(n) list(name = n, title = n))

      # Flat items: each row carries the parent fields + its measurements.
      # CODAP nests them under the matching parent case automatically.
      items <- lapply(seq_len(nrow(child_data)), function(i) {
        row_data <- as.list(child_data[i, ])
        row_data <- lapply(row_data, function(x) if (length(x) == 1 && is.na(x)) NULL else x)
        c(query_fields, row_data)
      })

      # Send to JavaScript via session$sendCustomMessage()
      session$sendCustomMessage(
        type = "sendToCODAP",
        message = list(
          contextName  = context_name,
          contextTitle = context_title,
          parentAttrs  = parent_attrs,
          childAttrs   = child_attrs,
          items        = items,
          queryLabel   = dataset_title,
          nRows        = nrow(data)
        )
      )
      # In-progress / success feedback is shown inline next to the button
      # (see the sendToCODAP JS handler), so no transient toast here.
    })

    # Handle CODAP export status feedback from JavaScript
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
          # Show error with helpful guidance
          error_msg <- paste("CODAP Export Error:", status$message)
          showNotification(
            HTML(paste0(
              error_msg,
              "<br><br><strong>Tip:</strong> The 'Send to CODAP' feature only works when this app is embedded inside CODAP as a Data Interactive. ",
              "To use this feature, open CODAP at <a href='https://codap.concord.org/' target='_blank'>codap.concord.org</a> and add this app URL as a plugin.",
              "<br><br>Alternatively, use the 'Download as CSV' button and import the file into CODAP manually."
            )),
            type = "error",
            duration = 15
          )
        }
      }
    })

    # Archived features (air quality, weather/climate) live in
    # archived-tabs.R, not in this file.
}

# Run the application
shinyApp(ui = ui, server = server)
