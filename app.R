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

/* Loading — the reassurance card shown while a fetch runs.
   It sits directly under the Get Water Data button so it is impossible
   to miss, and reports what is being fetched plus elapsed time. */
.wq-loading-card {
  background: #f2f9fa;
  border: 1px solid #cfe3e8;
  border-left: 5px solid #3B7A8C;
  border-radius: 8px;
  padding: 16px 18px;
  margin: 4px 0 16px 0;
}
.wq-loading-top {
  display: flex;
  align-items: flex-start;
  gap: 14px;
}
.wq-loading-title {
  font-size: 17px;
  font-weight: 700;
  color: #2A5F70;
  margin: 0 0 3px 0;
}
.wq-loading-sub {
  font-size: 13px;
  color: #4A6B73;
  margin: 0;
}
.wq-loading-meta {
  font-size: 13px;
  font-weight: 600;
  color: #3B7A8C;
  margin-top: 10px;
  font-variant-numeric: tabular-nums;
}
.wq-loading-hint {
  font-size: 13px;
  color: #4A6B73;
  margin-top: 4px;
}
.wq-loading-actions {
  margin-top: 10px;
}
/* Deliberately quiet: waiting is the normal path, so stopping should be
   available without competing with the progress bar for attention. */
.wq-cancel-link {
  font-size: 13px;
  color: #4A6B73;
  text-decoration: underline;
  cursor: pointer;
}
.wq-cancel-link:hover, .wq-cancel-link:focus {
  color: #2A5F70;
}

/* Estimated search time, under the county picker. Counties are the only
   choice with a real cost, so the number sits where that choice is made. */
.wq-estimate {
  font-size: 12.5px;
  color: #4A6B73;
  margin-top: 6px;
  font-variant-numeric: tabular-nums;
}
.wq-estimate-warn {
  color: #8a5a00;
  font-weight: 600;
}
.wq-estimate-note {
  font-weight: 400;
}

.loading-spinner {
  flex: 0 0 auto;
  display: inline-block;
  width: 34px;
  height: 34px;
  border: 3px solid #d7e8ec;
  border-radius: 50%;
  border-top-color: #3B7A8C;
  animation: spin 1s linear infinite;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Results already on screen are dimmed while a new fetch runs, so students
   don't read stale numbers as the answer to the question they just asked.
   The body class is toggled from JS off the loading_visible output. */
.wq-fetching .wq-results {
  opacity: 0.4;
  pointer-events: none;
  transition: opacity 0.2s ease-in-out;
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
/* Indeterminate progress bar: a stripe that slides across, because we
   cannot know how far along the API call is — a bar that fills to 100%
   would promise a completion we can't predict. */
.progress-bar-custom {
  position: relative;
  width: 100%;
  height: 6px;
  background-color: #e0ecef;
  border-radius: 3px;
  overflow: hidden;
  margin-top: 12px;
}
.progress-bar-fill {
  position: absolute;
  top: 0;
  left: -40%;
  width: 40%;
  height: 100%;
  background-color: #3B7A8C;
  border-radius: 3px;
  animation: progress 1.4s ease-in-out infinite;
}
@keyframes progress {
  0%   { left: -40%; }
  100% { left: 100%; }
}

/* Students using reduced-motion settings still get the card and the
   elapsed timer; the moving parts just hold still. */
@media (prefers-reduced-motion: reduce) {
  .loading-spinner,
  .progress-bar-fill,
  .codap-status-busy::before {
    animation: none !important;
  }
  .progress-bar-fill {
    left: 0;
    width: 100%;
    opacity: 0.5;
  }
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
      # Marks the page as "fetching" so already-visible results dim while a
      # new query runs. Driven by a custom message rather than the
      # loading_visible output, which has no DOM binding to listen to.
      tags$script(HTML("
        Shiny.addCustomMessageHandler('setFetching', function(msg) {
          document.body.classList.toggle('wq-fetching', !!(msg && msg.fetching));
        });
      ")),
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
              options = list(placeholder = "Select one or more counties")),
            # Counties are the one choice with a real, predictable cost
            # (~4.7s each, looked up one at a time), so show it at the
            # moment the student is making that choice rather than
            # surprising them with the wait afterwards.
            uiOutput("county_estimate")
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
          # input_task_button (not actionButton) so the button itself turns
          # into a spinner + "Fetching data…" and disables while the
          # ExtendedTask runs — see bind_task_button below.
          bslib::input_task_button("fetch_data", "Get Water Data",
            icon = icon("download"),
            label_busy = "Fetching data…",
            type = "primary", class = "btn-lg"),
          div(style = "flex: 1 1 220px; min-width: 200px;",
            textOutput("status_text")
          )
        ),

        # Loading indicator, immediately below the button so it is visible
        # without scrolling even in a short CODAP plugin iframe
        conditionalPanel(
          condition = "output.loading_visible == true",
          div(class = "wq-loading-card", role = "status", `aria-live` = "polite",
            div(class = "wq-loading-top",
              div(class = "loading-spinner"),
              div(
                p(class = "wq-loading-title", "Getting your water data…"),
                p(class = "wq-loading-sub", textOutput("loading_query_summary", inline = TRUE))
              )
            ),
            div(class = "progress-bar-custom", div(class = "progress-bar-fill")),
            div(class = "wq-loading-meta", textOutput("loading_elapsed", inline = TRUE)),
            div(class = "wq-loading-hint",
              "We're asking the USGS Water Quality Portal for every measurement that matches your choices. ",
              "You can keep this window open — it will fill in on its own."),
            # There is no way to abort a request already in flight, so this
            # stops waiting rather than claiming to stop the search. See the
            # cancel_fetch observer.
            div(class = "wq-loading-actions",
              actionLink("cancel_fetch", "Stop waiting", class = "wq-cancel-link"))
          )
        )
      )
    ),

    # Results - appears after data is fetched
    conditionalPanel(
      condition = "output.data_fetched == true",
      class = "wq-results",

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
    )

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
      current_state_name = "",
      current_county_fips = "",
      current_location = "",
      loading_visible = FALSE,
      available_sites = NULL,
      fetch_start_time = NULL,  # Track when fetch started for elapsed time display
      fetch_elapsed = 0,        # Seconds since the fetch started (ticks while loading)
      current_query_summary = "",  # "Knox County, Tennessee · 2025 · 5 parameters"
      query_is_big = FALSE,     # Picks which wait copy to show (see below)
      # Cancellation. Only one fetch can be in flight (the task button is
      # disabled while it runs), so a single flag is enough to decide
      # whether a result that lands later is still wanted — no generation
      # counter needed. cancel_file is the sentinel the worker polls
      # between counties (see stop_if_cancelled in R/fetch-wq.R).
      fetch_cancelled = FALSE,
      cancel_file = NULL
    )
    
    # Make loading_visible available as an input for the conditional panel
    output$loading_visible <- reactive({
      values$loading_visible
    })
    outputOptions(output, "loading_visible", suspendWhenHidden = FALSE)

    # ...and tell the browser, so the results section below can dim while a
    # new fetch replaces it (see the setFetching handler in tags$head)
    observeEvent(values$loading_visible, {
      session$sendCustomMessage("setFetching",
                                list(fetching = isTRUE(values$loading_visible)))
    })
    
    # Make data_fetched available for the conditional panel
    output$data_fetched <- reactive({
      values$data_fetched
    })
    outputOptions(output, "data_fetched", suspendWhenHidden = FALSE)

    # ============================================================
    # ExtendedTask for Water Quality API calls (async)
    # ============================================================
    water_fetch_task <- ExtendedTask$new(function(qry, location, cache_dir, cancel_file) {
      future({
        # These API calls run in a separate R process, allowing UI to update.
        # The Water Quality Portal rejects requests with multiple countycode
        # values (HTTP 500), so query one county at a time and combine.
        #
        # Primary service: WQX 3.0 — the only WQP route to USGS data newer
        # than March 2024 (legacy services stopped receiving USGS updates
        # then). Its result profile carries site metadata (name, lat/lon,
        # county) on every row, so it needs no separate station request.
        # WQX 3.0 is still labeled beta, so if any request fails the whole
        # fetch falls back to the legacy services. All-or-nothing: the two
        # services use different column names, so counties must never be
        # mixed across services in one result.
        # harmonize_wq_columns() before every bind_rows: the WQP CSV parser
        # types each column per request, so one county can return a column
        # as character that another returned as numeric, and bind_rows()
        # aborts. See R/fetch-wq.R — unguarded, that mismatch silently
        # demoted multi-county fetches to the legacy service.
        # Rebuilt here rather than passed in: a cachem cache is a set of
        # closures, and handing one across the process boundary is a
        # serialization risk for no gain — the disk directory is the shared
        # state, and opening it is just a directory handle.
        cache <- wq_cache(cache_dir)
        fetch_counties <- function(fetch_county) {
          # Between counties is the only place the worker can notice a
          # cancellation; a request already in flight is bounded by the
          # deadline instead. Checked before the first county too, so a
          # cancel that lands during the future's startup costs nothing.
          parts <- lapply(qry$countycode, function(code) {
            stop_if_cancelled(cancel_file)
            fetch_county(code)
          })
          list(
            wq_raw = dplyr::bind_rows(
              harmonize_wq_columns(lapply(parts, function(p) p$wq))
            ),
            meta_df = dplyr::distinct(dplyr::bind_rows(
              harmonize_wq_columns(lapply(parts, function(p) p$meta))
            ))
          )
        }
        # Every result fetch in this app goes through here, and none of them
        # want readWQPdata()'s attributes. Its create_WQP_attributes() step
        # fires a whatWQPsites() request (plus wqp_check_status() on WQX3)
        # purely to attach siteInfo/variableInfo/headerInfo — attributes
        # nothing in this app reads. That was two extra cold round trips per
        # county, and a failure point: a 500 from the hidden request would
        # drop the whole fetch into the slower legacy fallback.
        #
        # This belongs on readWQPdata only. whatWQPsites() forwards unknown
        # argument names into the URL as query parameters, so the flag must
        # not be added to a query list that is also passed to it.
        #
        # wqp_request() (R/fetch-wq.R) bounds each request and retries it
        # once on timeout. WQP has no timeout of its own on this path, so
        # without it a stalled request hangs indefinitely -- see
        # PERFORMANCE.md. Non-timeout errors still propagate, so the
        # WQX3 -> legacy fallback below is unaffected.
        read_wqp_results <- function(q) {
          wqp_request(function() {
            do.call(dataRetrieval::readWQPdata, c(q, list(ignore_attributes = TRUE)))
          })
        }
        # Each county goes through the shared read-through cache, keyed on
        # the per-county query including the service — so a class searching
        # the same county pays the network cost once, and a cache hit also
        # cannot stall. See cached_wqp_fetch() in R/fetch-wq.R.
        wqx3_county <- function(code) {
          q <- qry
          q$countycode <- code
          q$service <- "ResultWQX3"
          q$dataProfile <- "basicPhysChem"
          cached_wqp_fetch(q, function() {
            wq <- stamp_county(read_wqp_results(q), code)
            list(wq = wq, meta = wq)
          }, cache)
        }
        legacy_county <- function(code) {
          q <- qry
          q$countycode <- code
          cached_wqp_fetch(q, function() {
            list(
              wq = read_wqp_results(q),
              meta = stamp_county(
                wqp_request(function() do.call(dataRetrieval::whatWQPsites, q)), code
              )
            )
          }, cache)
        }
        # Which service answered travels with the result. The legacy
        # services carry no USGS data newer than March 2024, so a fallback
        # result for a recent year range is missing every USGS station —
        # silently plausible in counties with other providers, and a flat
        # "no data" in counties where USGS is the only one. The server
        # branches its copy on this so the student is told either way.
        service <- "wqx3"
        fetched <- tryCatch(
          fetch_counties(wqx3_county),
          error = function(e) {
            # A cancellation is not a WQX3 failure. Falling back would
            # restart the entire fetch on the legacy service — slower, and
            # against what the student just asked for.
            if (inherits(e, "wqp_cancelled")) stop(e)
            service <<- "legacy"
            fetch_counties(legacy_county)
          }
        )
        list(wq_raw = fetched$wq_raw, meta_df = fetched$meta_df,
             location = location, service = service)
      }, seed = TRUE)
    }) |> bslib::bind_task_button("fetch_data")


    # Observer for elapsed time display during water quality fetch.
    # req() suspends the observer while idle, so the once-per-second tick
    # only runs during an active fetch.
    observe({
      req(values$loading_visible, values$fetch_start_time)
      invalidateLater(1000)  # Update every second
      values$fetch_elapsed <- as.numeric(
        round(difftime(Sys.time(), values$fetch_start_time, units = "secs"))
      )
    })

    # What the loading card says: what we asked for, and how long it's taken.
    output$loading_query_summary <- renderText({
      values$current_query_summary
    })

    output$loading_elapsed <- renderText({
      secs <- values$fetch_elapsed
      elapsed_text <- if (secs < 60) {
        paste0(secs, if (secs == 1) " second" else " seconds")
      } else {
        mins <- secs %/% 60
        paste0(mins, if (mins == 1) " minute " else " minutes ", secs %% 60, "s")
      }
      # What we tell the student while they wait, staged by how long it has
      # actually taken. Grounded in tests/benchmark-results.csv rather than
      # guesswork, because the old copy ("most searches finish in 10–60
      # seconds", "big counties and long year ranges take longer") was
      # wrong twice over:
      #   - A normal search returns in about 4-5 seconds, not 10–60. The
      #     old range made the common case sound like a long wait.
      #   - County *size* is not what makes a search slow: results of 77
      #     and 1093 rows both came back in ~5s. What costs time is the
      #     *number of counties* (one serial request each), and to a lesser
      #     degree the year range. Blaming big counties sent students to a
      #     control that wouldn't help.
      # The Portal also stalls on individual requests for no visible reason
      # (3 of 24 cold reps, from 17s to 210s where the same query normally
      # took ~5s), so past the expected window the copy stops predicting
      # and starts reassuring — and never quotes a finish time it can't
      # keep.
      # The stages differ by query size, because the same 15-second mark
      # means "something is stalling" for a normal search and "going to
      # plan" for a big one.
      tail_text <- if (values$query_is_big) {
        if (secs < 90) {
          "searches like this take a little longer — each extra county is looked up separately, and longer year ranges add time too"
        } else {
          "still working. It's safe to leave this running, or reload the page to try fewer counties or a shorter year range"
        }
      } else {
        if (secs < 10) {
          "searches like this usually take just a few seconds"
        } else if (secs < 30) {
          "the Portal is being slow to answer — that happens even for small counties, and it usually sorts itself out"
        } else if (secs < 90) {
          "still working — this one is taking longer than usual"
        } else {
          "still working. It's safe to leave this running, or reload the page to try fewer counties or a shorter year range"
        }
      }
      paste0(elapsed_text, " so far · ", tail_text)
    })

    # Observer for water quality task completion (success or error).
    # Keyed on status() rather than result(): result() rethrows the task's
    # error, so using it as the event expression would crash the session
    # whenever the API call fails. (ExtendedTask has no error() method;
    # the error is retrieved by calling result() inside tryCatch.)
    observeEvent(water_fetch_task$status(), {
      task_status <- water_fetch_task$status()

      if (!task_status %in% c("error", "success")) return()

      # A stopped search's result is unwanted however it settled. Clear the
      # sentinel and leave the "Search stopped" status in place; the
      # student's earlier results stay on screen.
      if (isTRUE(values$fetch_cancelled)) {
        values$fetch_cancelled <- FALSE
        if (!is.null(values$cancel_file)) unlink(values$cancel_file)
        values$loading_visible <- FALSE
        values$fetch_start_time <- NULL
        return()
      }

      if (task_status == "error") {
        # Keep the condition, not just its message: a timeout is classed
        # (wqp_timeout, from wqp_request in R/fetch-wq.R) so it can be told
        # apart from a rejected request. The message match is a backstop in
        # case a future runtime wraps the condition and drops the class.
        err <- tryCatch({
          water_fetch_task$result()
          simpleError("Unknown error")
        }, error = function(e) e)
        err_msg <- conditionMessage(err)

        if (inherits(err, "wqp_timeout") ||
            grepl("did not respond within", err_msg, fixed = TRUE)) {
          # Not an "oops" — nothing went wrong with the search. The Portal
          # stalls ~12% of requests for no reason we can see, and the same
          # search usually works on the next try. Say that plainly instead
          # of showing a student a technical error they can't act on.
          values$status <- paste0(
            "The Water Quality Portal didn't answer in time.\n\n",
            "There's nothing wrong with your search — the Portal is just ",
            "being slow right now. We waited, tried again, and it still ",
            "didn't answer.\n\n",
            "What you can try:\n",
            "- Click 'Get Water Data' again — this usually clears up on its own\n",
            "- If it keeps happening, try fewer counties or a shorter year range"
          )
          showNotification(
            "The Water Quality Portal didn't answer. Please try again.",
            type = "warning", duration = 8
          )
        } else {
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
        }
        values$loading_visible <- FALSE
        values$fetch_start_time <- NULL
        return()
      }

      result <- water_fetch_task$result()
      wq_raw <- result$wq_raw
      meta_df <- result$meta_df
      location <- result$location

      # Get year range text from input (still available in main process)
      start_year <- input$year_selection[1]
      end_year <- input$year_selection[2]

      # The legacy fallback only loses data the student asked for when the
      # year range reaches into the post-March-2024 USGS gap; for older
      # ranges legacy is complete and a warning would be a false alarm.
      legacy_gap <- identical(result$service, "legacy") && end_year >= 2024
      year_range_text <- if (start_year == end_year) {
        paste("Year", start_year)
      } else {
        paste("Years", start_year, "-", end_year)
      }

      values$status <- paste("Processing", nrow(wq_raw), "samples from", location, "...")

      if (nrow(wq_raw) == 0) {
        # An empty legacy-fallback result for a recent range must not be
        # reported as "no data": USGS measurements after March 2024 exist
        # only on the WQX3 service we just failed to reach, so in a county
        # where USGS is the main provider this empty result says nothing
        # about whether data exists. Saying "no data" here would tell a
        # teacher their creek has no monitoring when the Portal was merely
        # having a bad minute.
        if (legacy_gap) {
          values$status <- paste0(
            "We couldn't check the newest data for ", location, ".\n\n",
            "The newest water data service isn't answering right now, and the ",
            "older backup service found nothing for this search. That does not ",
            "mean there's no data — USGS measurements after March 2024 are only ",
            "on the service we couldn't reach.\n\n",
            "Try: Click 'Get Water Data' again in a few minutes."
          )
          showNotification(
            "The newest data service isn't answering - please try this search again in a few minutes.",
            type = "warning", duration = 8
          )
        } else {
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
        }
        values$loading_visible <- FALSE
        values$fetch_start_time <- NULL
        return()
      }

      # Full processing pipeline (cleaning, county resolution, unit
      # standardisation, pivot to wide) lives in R/process-wq.R so it can
      # be unit tested.
      processed <- process_wq_result(
        wq_raw     = wq_raw,
        meta_df    = meta_df,
        location   = location,
        state_fips = values$current_state_fips,
        state_name = values$current_state_name,
        fips_clean = fips_clean
      )

      values$long_data <- processed$long_data
      values$wide_data <- processed$wide_data
      values$available_sites <- processed$available_sites
      values$data_fetched <- TRUE

      # Update site selector choices with informative labels. The dropdown
      # lists only the five most active sites; "All sites" covers every site.
      site_choices <- c(
        setNames("all", paste0("All sites (", processed$n_sites_total, " total)")),
        setNames(processed$available_sites$site_id,
                 processed$available_sites$display_label)
      )
      updateSelectInput(session, "site_selection",
                        choices = site_choices,
                        selected = "all")

      unit_note <- if (processed$n_dropped_units > 0) {
        paste0(" (", processed$n_dropped_units,
               " readings in nonstandard units were excluded.)")
      } else {
        ""
      }
      # A fallback result for a recent range looks complete — graphs draw
      # fine — but is missing every USGS measurement after March 2024, so
      # the student must be told the results are partial.
      legacy_note <- if (legacy_gap) {
        paste0(
          "\n\nHeads up: the newest data service wasn't answering, so these ",
          "results came from an older backup. Measurements from USGS after ",
          "March 2024 may be missing. Run this search again later for the ",
          "most complete data."
        )
      } else {
        ""
      }
      values$status <- paste0(
        "Data processing complete for ", location, "! Found ",
        nrow(processed$long_data), " measurements from ",
        processed$n_sites_total, " monitoring sites. Year range: ", year_range_text,
        " - Parameters found: ", paste(processed$found_parameters, collapse = ", "),
        unit_note, legacy_note
      )

      if (legacy_gap) {
        showNotification(
          "Results came from a backup data service - some recent USGS measurements may be missing.",
          type = "warning", duration = 8
        )
      } else {
        showNotification("Data fetched successfully!", type = "message", duration = 5)
      }

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
    
    # Estimated search time under the county picker. The model and the soft
    # cap live in R/wq-estimate.R so they can be tested against the measured
    # benchmark numbers.
    output$county_estimate <- renderUI({
      n <- length(input$county_selection)
      if (n == 0) return(NULL)
      secs <- wq_time_estimate(n, selected_year_span(input$year_selection))
      over_cap <- n > wq_county_soft_cap
      div(
        class = paste("wq-estimate", if (over_cap) "wq-estimate-warn" else ""),
        paste0(n, if (n == 1) " county · " else " counties · ", format_estimate(secs)),
        if (over_cap) {
          span(class = "wq-estimate-note",
               " — each county is looked up separately, so this will be slow. Fewer counties will be much faster.")
        }
      )
    })

    # Show warning for large year ranges. The estimate keeps this honest:
    # the old copy here claimed 30-90 seconds for a long range, but a
    # 5-year single-county search measures 9.5s.
    observeEvent(input$year_selection, {
      year_range <- selected_year_span(input$year_selection)
      if (year_range > 3) {
        n <- max(1, length(input$county_selection))
        showNotification(
          paste0("Searching ", year_range, " years takes ",
                 format_estimate(wq_time_estimate(n, year_range)), "."),
          type = "warning", duration = 6
        )
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

      # Store state FIPS (same for all counties in a state) and the state
      # name as fetched, so results stay labeled correctly even if the
      # user changes the dropdowns while the fetch is running
      values$current_state_fips <- county_info$state_fips[1]
      values$current_state_name <- input$state_selection

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
        # Expand friendly labels to the WQP characteristic names the data
        # is actually recorded under (see R/wq-parameters.R)
        characteristicName = expand_wq_characteristics(selected_parameters),
        sampleMedia = "Water",
        startDateLo = start_date,
        startDateHi = end_date,
        siteType = "Stream"
      )

      # Show loading indicator and start timer. The summary echoes the
      # student's own choices back to them so it's clear what is being
      # looked up (and that the click registered).
      year_summary <- if (start_year == end_year) {
        as.character(start_year)
      } else {
        paste0(start_year, "–", end_year)
      }
      values$current_query_summary <- paste0(
        values$current_location, " · ", year_summary, " · ",
        length(selected_parameters),
        if (length(selected_parameters) == 1) " parameter" else " parameters"
      )
      # Which wait message to show. Measured medians over 4 cold reps each
      # (tests/benchmark-results.csv):
      #   1 county,  1 year,  5 params ->  4.6s
      #   1 county,  1 year, 16 params ->  5.1s   parameters: negligible
      #   1 county,  5 years, 5 params ->  9.5s   year range: modest
      #   3 counties, 1 year, 5 params -> 14.1s   counties: ~4.7s each
      # So the number of counties dominates — the API rejects multi-county
      # requests, so we issue one request per county in series. Parameter
      # count is deliberately NOT a term here: it barely moves the clock.
      values$query_is_big <- length(county_codes) >= 2 ||
        (end_year - start_year + 1) >= 4

      values$loading_visible <- TRUE
      values$fetch_start_time <- Sys.time()
      values$fetch_elapsed <- 0
      values$status <- "Searching the USGS Water Quality Portal…"

      # Fresh sentinel path per fetch, and clear any file left behind by a
      # previous cancelled search — a stale sentinel would abort this fetch
      # before it issued a single request.
      values$fetch_cancelled <- FALSE
      values$cancel_file <- file.path(
        tempdir(), paste0("wq-cancel-", session$token, ".flag")
      )
      unlink(values$cancel_file)

      # Invoke the async task - UI will remain responsive
      water_fetch_task$invoke(qry, values$current_location,
                              wq_cache_dir(), values$cancel_file)
    })

    # "Stop waiting" in the loading card.
    #
    # ExtendedTask has no cancel(), and a request already inside curl cannot
    # be interrupted from here, so this does two separate things: it drops
    # the sentinel file the worker polls between counties (which genuinely
    # ends a multi-county fetch early), and it marks the result unwanted so
    # whatever eventually lands is discarded. The student's previous results
    # stay on screen untouched.
    #
    # The Get Water Data button stays busy until the task actually settles —
    # bind_task_button follows the task, not this flag — so the copy says so
    # rather than pretending the search is already gone. That wait is now
    # bounded by the per-request deadline instead of being open-ended.
    observeEvent(input$cancel_fetch, {
      req(values$loading_visible)
      values$fetch_cancelled <- TRUE
      if (!is.null(values$cancel_file)) file.create(values$cancel_file)
      values$loading_visible <- FALSE
      values$fetch_start_time <- NULL
      values$status <- paste0(
        "Search stopped. Your earlier results are still below.\n",
        "The Get Water Data button will be ready again in a moment."
      )
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
