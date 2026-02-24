library(shiny)
library(shinydashboard)
library(DT)
library(tidyverse)
library(dataRetrieval)
library(janitor)
library(lubridate)

# Check if RAQSAPI is installed, if not provide instructions
if (!requireNamespace("RAQSAPI", quietly = TRUE)) {
  warning("RAQSAPI package not found. Install with: install.packages('RAQSAPI')")
} else {
  library(RAQSAPI)
}

# AQS API credentials — set AQS_USERNAME and AQS_KEY in .Renviron (see .Renviron.example)
# Falls back to the EPA public test account if env vars are not set.
# Register for real credentials at: https://aqs.epa.gov/data/api/signup
aqs_creds <- RAQSAPI::aqs_credentials(
  username = ifelse(Sys.getenv("AQS_USERNAME") != "", Sys.getenv("AQS_USERNAME"), "test@aqs.api"),
  key      = ifelse(Sys.getenv("AQS_KEY")      != "", Sys.getenv("AQS_KEY"),      "test")
)

# Check if climateR is installed, if not provide instructions
if (!requireNamespace("climateR", quietly = TRUE)) {
  warning("climateR package not found. Install with: devtools::install_github('mikejohnson51/climateR')")
} else {
  library(climateR)
}

# Load comprehensive FIPS crosswalk data from local file
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

# CREDIBLE Brand Colors
# Primary (Coral Red): #E63946
# Secondary (Teal): #60C5BA
# Accent (Sage Green): #7A9B76
# Warning (Orange): #F4A261
# Dark: #2D3142

custom_css <- "
/* Still Water palette — one color family throughout
   Primary:   #3B7A8C  (lake teal)
   Dark:      #2A5F70  (deep water, hovers)
   Muted:     #6A9AA6  (secondary buttons)
   Accent:    #4A9BAA  (status bar, spinner, links)
*/

/* App header */
.skin-blue .main-header .navbar {
  background-color: #3B7A8C !important;
}
.skin-blue .main-header .logo {
  background-color: #2A5F70 !important;
}
.skin-blue .main-header .logo:hover {
  background-color: #1F4A58 !important;
}

/* All box headers — same color, every box type */
.box.box-solid > .box-header {
  background-color: #3B7A8C !important;
  color: #ffffff !important;
}
.box.box-primary, .box.box-warning,
.box.box-info,    .box.box-success {
  border-color: #dee2e6 !important;
  border-top-color: #3B7A8C !important;
}

/* Box base */
.box {
  border-radius: 6px !important;
  box-shadow: 0 2px 4px rgba(0,0,0,0.08) !important;
  margin-bottom: 20px !important;
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

/* Status text */
#status_text {
  background-color: #f8f9fa;
  border-left: 4px solid #4A9BAA;
  padding: 15px;
  border-radius: 4px;
  font-family: monospace;
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
"

# Add resource path for logo
addResourcePath("images", ".")

# =============================================================================
# AIR QUALITY: AQI helper data and functions
# (Ported from aqs.ipynb notebook)
# =============================================================================

# Parameter codes mapped to display names
air_params <- c(
  "44201" = "Ozone (O3, ppm)",
  "88101" = "PM2.5 (ug/m3)",
  "81102" = "PM10 (ug/m3)",
  "42101" = "Carbon Monoxide (ppm)",
  "42401" = "Sulfur Dioxide (ppb)",
  "42602" = "Nitrogen Dioxide (ppb)"
)

# EPA AQI breakpoints: each entry is (AQI_Low, AQI_High, Conc_Low, Conc_High)
aqi_breakpoints <- list(
  "88101" = list(   # PM2.5, 24-hr, ug/m3
    c(0, 50, 0.0, 12.0),
    c(51, 100, 12.1, 35.4),
    c(101, 150, 35.5, 55.4),
    c(151, 200, 55.5, 150.4),
    c(201, 300, 150.5, 250.4),
    c(301, 400, 250.5, 350.4),
    c(401, 500, 350.5, 500.4)
  ),
  "81102" = list(   # PM10, 24-hr, ug/m3
    c(0, 50, 0, 54),
    c(51, 100, 55, 154),
    c(101, 150, 155, 254),
    c(151, 200, 255, 354),
    c(201, 300, 355, 424),
    c(301, 400, 425, 504),
    c(401, 500, 505, 604)
  ),
  "44201" = list(   # Ozone, 8-hr, ppm
    c(0, 50, 0.000, 0.054),
    c(51, 100, 0.055, 0.070),
    c(101, 150, 0.071, 0.085),
    c(151, 200, 0.086, 0.105),
    c(201, 300, 0.106, 0.200)
  ),
  "42101" = list(   # CO, 8-hr, ppm
    c(0, 50, 0.0, 4.4),
    c(51, 100, 4.5, 9.4),
    c(101, 150, 9.5, 12.4),
    c(151, 200, 12.5, 15.4),
    c(201, 300, 15.5, 30.4),
    c(301, 400, 30.5, 40.4),
    c(401, 500, 40.5, 50.4)
  ),
  "42401" = list(   # SO2, 1-hr, ppb
    c(0, 50, 0, 35),
    c(51, 100, 36, 75),
    c(101, 150, 76, 185),
    c(151, 200, 186, 304),
    c(201, 300, 305, 604),
    c(301, 400, 605, 804),
    c(401, 500, 805, 1004)
  ),
  "42602" = list(   # NO2, 1-hr, ppb
    c(0, 50, 0, 53),
    c(51, 100, 54, 100),
    c(101, 150, 101, 360),
    c(151, 200, 361, 649),
    c(201, 300, 650, 1249),
    c(301, 400, 1250, 1649),
    c(401, 500, 1650, 2049)
  )
)

# Decimal truncation spec per EPA guidelines
pollutant_decimals <- c(
  "88101" = 1, "81102" = 0, "44201" = 3,
  "42101" = 1, "42401" = 0, "42602" = 0
)

# Truncate to specified decimal places (floor, not round)
aqi_truncate <- function(n, decimals = 0) {
  if (is.null(n) || is.na(n) || !is.finite(n)) return(NULL)
  floor(n * 10^decimals) / 10^decimals
}

# Calculate individual AQI for a single pollutant measurement
calculate_individual_aqi <- function(pollutant_code, concentration) {
  if (!(pollutant_code %in% names(aqi_breakpoints))) return(NA_real_)
  if (is.null(concentration) || is.na(concentration) || !is.finite(concentration)) return(NA_real_)

  decimals <- pollutant_decimals[[pollutant_code]]
  C_p <- aqi_truncate(concentration, decimals)
  if (is.null(C_p)) return(NA_real_)

  table <- aqi_breakpoints[[pollutant_code]]
  for (bp in table) {
    I_lo <- bp[1]; I_hi <- bp[2]; C_lo <- bp[3]; C_hi <- bp[4]
    if (C_p >= C_lo && C_p <= C_hi) {
      if ((C_hi - C_lo) == 0) return(I_lo)
      aqi <- ((I_hi - I_lo) / (C_hi - C_lo)) * (C_p - C_lo) + I_lo
      return(round(aqi))
    }
  }

  # Beyond highest breakpoint: extrapolate using last bracket
  last_bp <- table[[length(table)]]
  I_lo <- last_bp[1]; I_hi <- last_bp[2]; C_lo <- last_bp[3]; C_hi <- last_bp[4]
  if (C_p > C_hi && (C_hi - C_lo) > 0) {
    aqi <- ((I_hi - I_lo) / (C_hi - C_lo)) * (C_p - C_lo) + I_lo
    return(round(aqi))
  }

  NA_real_
}

# Calculate composite AQI = max of all individual AQIs
# conc_named_vec: named numeric vector, names are parameter codes
calculate_composite_aqi <- function(conc_named_vec) {
  individual <- sapply(names(conc_named_vec), function(code) {
    calculate_individual_aqi(code, conc_named_vec[[code]])
  })
  valid <- individual[!is.na(individual)]
  if (length(valid) == 0) return(NA_real_)
  max(valid)
}

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
      tags$script(src="https://unpkg.com/iframe-phone@1.4.0/dist/iframe-phone.js"),
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
          console.log('Current window location:', window.location.href);
          console.log('Parent window exists:', window.parent !== window);
          console.log('CODAP API available:', typeof window.parent.postMessage === 'function');
          
          var datasetName = payload.datasetName || 'MyData';
          var attributes = payload.attributes || [];
          var cases = payload.cases || [];
          
          console.log('Dataset name:', datasetName);
          console.log('Number of attributes:', attributes.length);
          console.log('Number of cases:', cases.length);
          
          // Step 1: Create CODAP dataContext with attributes
          codapInterface('create', 'dataContext', {
            name: datasetName,
            title: datasetName,
            description: 'Data exported from CREDIBLE Local Data Shiny App',
            collections: [{
              name: datasetName + '_collection',
              title: datasetName,
              attrs: attributes
            }]
          })
          .then(function(response) {
            console.log('DataContext created successfully:', response);
            
            // Step 2: Send data rows as cases to CODAP
            return codapInterface('create', 'dataContext[' + datasetName + '].item', cases);
          })
          .then(function(response) {
            console.log('Cases sent successfully:', response);
            console.log('Total cases sent:', cases.length);
            
            // Notify Shiny of success
            Shiny.setInputValue('codap_export_status', {
              success: true,
              message: 'Successfully sent ' + cases.length + ' rows to CODAP dataset: ' + datasetName,
              timestamp: new Date().getTime()
            }, {priority: 'event'});
          })
          .catch(function(error) {
            console.error('Error sending data to CODAP:', error);
            
            // Create helpful error message
            var errorMsg = error.message || error.error || 'Unknown error';
            if (error.helpUrl) {
              errorMsg += ' Visit: ' + error.helpUrl;
            }
            
            // Notify Shiny of error
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
        fluidRow(
          box(
            title = "Access Water Quality Data", status = "primary", solidHeader = TRUE, width = 12,
                  fluidRow(
                    column(3,
                           selectInput("state_selection", "Select State:", 
                                       choices = c("Choose a state..." = "", 
                                                   setNames(states_df$state_name, states_df$state_name)),
                                       selected = "Tennessee")
                    ),
                    column(3,
                           selectizeInput("county_selection", "Select County/Counties:",
                                       choices = {
                                         tn <- fips_clean[fips_clean$state_name == "Tennessee", "county_display", drop = TRUE]
                                         setNames(tn, tn)
                                       },
                                       selected = "Knox County",
                                       multiple = TRUE,
                                       options = list(placeholder = "Select one or more counties"))
                    ),
                    column(3,
                           sliderInput("year_selection", "Select Year Range:",
                                       min = 1960, max = 2026,
                                       value = c(2023, 2025),
                                       step = 1, sep = "")
                    )
                  ),
                  
                  # Water Quality Parameters Selection
                  hr(),
                  h4("Select Water Quality Parameters"),
                  p("Choose which water quality parameters to fetch. Default selection focuses on commonly monitored indicators."),
                  fluidRow(
                    column(6,
                           h5("Primary Indicators"),
                           checkboxGroupInput("parameters_primary", NULL,
                                              choices = c("pH" = "pH",
                                                          "Phosphorus" = "Phosphorus",
                                                          "Turbidity" = "Turbidity",
                                                          "Temperature" = "Temperature",
                                                          "Dissolved oxygen" = "Dissolved oxygen"),
                                              selected = c("pH", "Turbidity"),
                                              inline = FALSE)
                    ),
                    column(6,
                           h5("Additional Parameters"),
                           checkboxGroupInput("parameters_additional", NULL,
                                              choices = c("Nitrate" = "Nitrate",
                                                          "Nitrite" = "Nitrite",
                                                          "Conductivity" = "Conductivity",
                                                          "Total dissolved solids" = "Total dissolved solids",
                                                          "Alkalinity" = "Alkalinity",
                                                          "Hardness" = "Hardness",
                                                          "Chloride" = "Chloride",
                                                          "Sulfate" = "Sulfate",
                                                          "Ammonia" = "Ammonia",
                                                          "Total nitrogen" = "Total nitrogen"),
                                              selected = c("Nitrate"),
                                              inline = FALSE)
                    )
                  ),
                  
                  fluidRow(
                    column(3,
                           br(),
                           actionButton("fetch_data", "Fetch Water Quality Data", 
                                        class = "btn-primary", icon = icon("download")),
                           br(), br(),
                           actionButton("refresh_data", "Refresh/Clear", 
                                        class = "btn-warning", icon = icon("refresh"))
                    )
                  ),

                  # Data Processing Status
                  hr(),
                  h4("Data Processing Status"),
                  verbatimTextOutput("status_text"),
                  
                  # Site selector - only show after data is fetched
                  conditionalPanel(
                    condition = "output.data_fetched == true",
                    hr(),
                    h4("Site Selection"),
                    fluidRow(
                      column(8,
                             selectInput("site_selection", "Select Site(s) for Selected Location:",
                                         choices = c("All sites" = "all"),
                                         selected = "all",
                                         multiple = TRUE)
                      ),
                      column(4,
                             br(),
                             p("Select specific monitoring sites within your chosen location for focused analysis.")
                      )
                    ),

                    hr(),
                    h4("Time Aggregation"),
                    fluidRow(
                      column(8,
                             selectInput("time_aggregation", "Aggregate measurements by:",
                                         choices = c("None (raw data)" = "none",
                                                     "Month" = "month"),
                                         selected = "month")
                      ),
                      column(4,
                             br(),
                             p("Aggregate multiple measurements within each time period to reduce missingness and data volume.")
                      )
                    ),
                    p(style = "font-size: 12px; color: #6c757d;",
                      "Note: Aggregation calculates the mean of available measurements for each parameter within each time period. This helps handle irregular sampling and missing values.")
                  )
                )
              ),
              
              # Loading indicator
              conditionalPanel(
                condition = "output.loading_visible == true",
                fluidRow(
                  box(
                    title = "Data Processing", status = "primary", solidHeader = TRUE, width = 12,
                    div(class = "loading-container",
                        div(class = "loading-spinner"),
                        h4("Fetching Water Quality Data..."),
                        p("Connecting to USGS Water Quality Portal and processing data"),
                        div(class = "progress-bar-custom",
                            div(class = "progress-bar-fill")
                        ),
                        p("This may take 10-60 seconds depending on data availability and timeframe", 
                          style = "font-size: 12px; margin-top: 10px; opacity: 0.8;")
                    )
                  )
                )
              ),
              

              conditionalPanel(
                condition = "output.data_fetched == true",
                fluidRow(
                  box(
                    title = "Data Preview", status = "warning", solidHeader = TRUE, width = 12,
                    DT::dataTableOutput("preview_wide"),
                    # ============================================================================
                    # CODAP EXPORT UI ELEMENTS - Water Quality
                    # ============================================================================
                    div(style = "margin-top: 12px; display: flex; gap: 10px;",
                      downloadButton("download_wide", "Download as CSV",
                                     class = "btn-success", icon = icon("download")),
                      actionButton("send_to_codap", "Send to CODAP",
                                   class = "btn-info", icon = icon("share-square"))
                    )
                  )
                )
              ),

      ), # end Water Quality tabPanel

      # ======================================================================
      # AIR QUALITY TAB
      # ======================================================================
      tabPanel("Air Quality",
        br(),
        p(style = "color: #6c757d; font-size: 13px; margin-bottom: 4px;",
          "Access EPA Air Quality System (AQS) data. Data availability has up to a 6-month delay from the present date."),
        p(style = "color: #6c757d; font-size: 11px; font-style: italic; margin-bottom: 0;",
          "Rivulet utils were originally developed as part of work on a grant by the National Science Foundation (Award #2445609). Notebook contributions by Michelle Wilkerson, Adelmo Eloy, Danny Zheng, Lucas Coletti, and Kolby Caban."),

    fluidRow(
      box(
        title = "Access Air Quality Data", status = "primary", solidHeader = TRUE, width = 12,
        fluidRow(
          column(3,
                 selectInput("air_state_selection", "Select State:",
                             choices = c("Choose a state..." = "",
                                         setNames(states_df$state_name, states_df$state_name)),
                             selected = "Tennessee")
          ),
          column(3,
                 selectizeInput("air_county_selection", "Select County/Counties:",
                             choices = {
                               tn <- fips_clean[fips_clean$state_name == "Tennessee", "county_display", drop = TRUE]
                               setNames(tn, tn)
                             },
                             selected = "Knox County",
                             multiple = TRUE,
                             options = list(placeholder = "Select one or more counties"))
          ),
          column(3,
                 sliderInput("air_year_selection", "Select Year Range:",
                             min = 2000, max = 2025,
                             value = c(2022, 2024),
                             step = 1, sep = "")
          )
        ),

        hr(),
        h4("Select Air Quality Parameters"),
        p("Choose which AQI pollutants to include. Not all monitors measure all parameters."),
        fluidRow(
          column(12,
                 checkboxGroupInput("air_parameters", NULL,
                                    choices = c(
                                      "Ozone (O3)" = "44201",
                                      "PM2.5" = "88101",
                                      "PM10" = "81102",
                                      "Carbon Monoxide (CO)" = "42101",
                                      "Sulfur Dioxide (SO2)" = "42401",
                                      "Nitrogen Dioxide (NO2)" = "42602"
                                    ),
                                    selected = c("44201", "88101"),
                                    inline = TRUE)
          )
        ),

        fluidRow(
          column(4,
                 br(),
                 actionButton("find_air_monitors", "Step 1: Find Monitors",
                              class = "btn-primary", icon = icon("search")),
                 br(), br(),
                 actionButton("refresh_air_data", "Refresh/Clear",
                              class = "btn-warning", icon = icon("refresh"))
          )
        ),

        hr(),
        h4("Data Processing Status"),
        verbatimTextOutput("air_status_text"),

        # Monitor selection — appears after Step 1 succeeds
        conditionalPanel(
          condition = "output.air_monitors_found == true",
          hr(),
          h4("Monitor Selection"),
          p("Select one or more monitoring stations, then click Step 2 to fetch measurements."),
          fluidRow(
            column(7,
                   selectInput("air_site_selection", "Select Monitoring Site(s):",
                               choices = c("All monitors" = "all"),
                               selected = "all",
                               multiple = TRUE)
            ),
            column(4,
                   br(),
                   actionButton("fetch_air_data", "Step 2: Fetch Air Quality Data",
                                class = "btn-success", icon = icon("download"))
            )
          )
        )
      )
    ),

    # Air quality loading indicator
    conditionalPanel(
      condition = "output.air_loading_visible == true",
      fluidRow(
        box(
          title = "Data Processing", status = "primary", solidHeader = TRUE, width = 12,
          div(class = "loading-container",
              div(class = "loading-spinner"),
              h4("Fetching Air Quality Data..."),
              p("Connecting to EPA Air Quality System and processing data"),
              div(class = "progress-bar-custom",
                  div(class = "progress-bar-fill")
              ),
              p("This may take 10-60 seconds depending on data availability",
                style = "font-size: 12px; margin-top: 10px; opacity: 0.8;")
          )
        )
      )
    ),

    # Air quality data preview and export
    conditionalPanel(
      condition = "output.air_data_fetched == true",
      fluidRow(
        box(
          title = "Air Quality Data Preview", status = "warning", solidHeader = TRUE, width = 12,
          DT::dataTableOutput("air_preview_wide"),
          div(style = "margin-top: 12px; display: flex; gap: 10px;",
              downloadButton("download_air_data", "Download as CSV",
                             class = "btn-success", icon = icon("download")),
              actionButton("send_air_to_codap", "Send to CODAP",
                           class = "btn-info", icon = icon("share-square"))
          )
        )
      )
    )

      ) # end Air Quality tabPanel
    ), # end tabsetPanel

    # Footer
    div(style = "text-align: center; padding: 16px 0 12px 0;",
      tags$img(src = "images/credible-logo.png", height = "100px",
               style = "display: block; margin: 0 auto 8px auto; mix-blend-mode: multiply;"),
      tags$a(href = "https://projectcredible.com", target = "_blank",
             style = "font-size: 12px; color: #3B7A8C;", "projectcredible.com")
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
      current_county_fips = "",
      current_location = "",
      loading_visible = FALSE,
      available_sites = NULL,

      # Air quality data
      air_wide_data = NULL,
      air_long_data = NULL,
      air_data_fetched = FALSE,
      air_monitors_found = FALSE,
      air_status = "Ready to fetch air quality data...",
      air_current_state_fips = "",
      air_current_county_fips = "",
      air_current_location = "",
      air_loading_visible = FALSE,
      air_available_sites = NULL,
      air_available_monitors = NULL

      ## ARCHIVED: Weather reactive values
      ## To restore: Uncomment the sections below
      # # Weather data
      # weather_wide_data = NULL,
      # weather_data_fetched = FALSE,
      # weather_status = "Ready to fetch weather data...",
      # weather_current_state_fips = "",
      # weather_current_county_fips = "",
      # weather_current_location = "",
      # weather_loading_visible = FALSE,
      # weather_available_stations = NULL
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
    
    # Make air quality loading_visible available for the conditional panel
    output$air_loading_visible <- reactive({
      values$air_loading_visible
    })
    outputOptions(output, "air_loading_visible", suspendWhenHidden = FALSE)
    
    # Make air quality data_fetched available for the conditional panel
    output$air_data_fetched <- reactive({
      values$air_data_fetched
    })
    outputOptions(output, "air_data_fetched", suspendWhenHidden = FALSE)

    # Make air quality monitors_found available for the conditional panel
    output$air_monitors_found <- reactive({
      values$air_monitors_found
    })
    outputOptions(output, "air_monitors_found", suspendWhenHidden = FALSE)

    # Make weather loading_visible available for the conditional panel
    output$weather_loading_visible <- reactive({
      values$weather_loading_visible
    })
    outputOptions(output, "weather_loading_visible", suspendWhenHidden = FALSE)
    
    # Make weather data_fetched available for the conditional panel
    output$weather_data_fetched <- reactive({
      values$weather_data_fetched
    })
    outputOptions(output, "weather_data_fetched", suspendWhenHidden = FALSE)
    
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
    
    # Initialize Knox County selection when app loads (since Tennessee is default)
    observe({
      if (input$state_selection == "Tennessee") {
        # Trigger the county update for Tennessee on app load
        isolate({
          state_info <- states_df[states_df$state_name == "Tennessee", ]
          if (nrow(state_info) > 0) {
            counties_for_state <- fips_clean %>%
              filter(state_fips == state_info$state_fips) %>%
              arrange(county_name)

            county_choices <- setNames(counties_for_state$county_display, counties_for_state$county_display)

            updateSelectizeInput(session, "county_selection", choices = county_choices, selected = "Knox County")
          }
        })
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
    
    # Display current selection
    output$location_display <- renderText({
      if (input$state_selection != "" && !is.null(input$county_selection) && length(input$county_selection) > 0) {
        if (length(input$county_selection) == 1) {
          paste(input$county_selection, ",", input$state_selection)
        } else {
          paste0(paste(input$county_selection, collapse = ", "), ", ", input$state_selection)
        }
      } else {
        "None selected"
      }
    })
    
    # Display FIPS codes
    output$fips_display <- renderText({
      if (input$state_selection != "" && !is.null(input$county_selection) && length(input$county_selection) > 0) {
        # Find the county info for all selected counties
        county_info <- fips_clean %>%
          filter(state_name == input$state_selection,
                 county_display %in% input$county_selection)

        if (nrow(county_info) > 0) {
          if (nrow(county_info) == 1) {
            paste("State:", county_info$state_fips, "County:", county_info$county_fips, "Full:", county_info$full_fips)
          } else {
            paste0("State: ", county_info$state_fips[1], " | Counties: ", paste(county_info$county_fips, collapse = ", "))
          }
        } else {
          "Codes not found"
        }
      } else {
        "None selected"
      }
    })
    
    # Data fetching logic (dropdown selection)
    observeEvent(input$fetch_data, {
      
      # Validate inputs
      if (input$state_selection == "" || is.null(input$county_selection) || length(input$county_selection) == 0) {
        showNotification("Please select state and at least one county", type = "error", duration = 5)
        return()
      }
      
      # Show loading indicator
      values$loading_visible <- TRUE

      # Get FIPS codes for all selected counties
      county_info <- fips_clean %>%
        filter(state_name == input$state_selection,
               county_display %in% input$county_selection)

      if (nrow(county_info) == 0) {
        showNotification("County not found in database. Please try again.", type = "error", duration = 5)
        values$loading_visible <- FALSE
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
      
      fetch_water_data()
    })
    

    
    # Refresh/Clear data functionality
    observeEvent(input$refresh_data, {
      # Reset all reactive values to initial state
      values$long_data <- NULL
      values$wide_data <- NULL
      values$data_fetched <- FALSE
      values$status <- "Ready to fetch water quality data..."
      values$current_state_fips <- ""
      values$current_county_fips <- ""
      values$current_location <- ""
      values$loading_visible <- FALSE
      values$available_sites <- NULL
      
      # Reset input selections
      updateSelectInput(session, "state_selection", selected = "")
      updateSelectizeInput(session, "county_selection",
                        choices = c("Choose county/counties..." = ""),
                        selected = character(0))
      updateSliderInput(session, "year_selection", value = c(2023, 2025))
      updateCheckboxGroupInput(session, "parameters_primary",
                               selected = c("pH", "Turbidity"))
      updateCheckboxGroupInput(session, "parameters_additional",
                               selected = c("Nitrate"))
      updateSelectInput(session, "site_selection", 
                        choices = c("All sites" = "all"),
                        selected = "all")
      

      
      showNotification("Interface refreshed and data cleared!", type = "message", duration = 3)
    })
    
    # Shared data fetching function
    fetch_water_data <- function() {
      
      # Update status
      values$status <- "Fetching data from Water Quality Portal..."
      
      tryCatch({
        # Build county codes for all selected counties
        county_codes <- paste0("US:", values$current_state_fips, ":", values$current_county_fips)
        
        # Validate year selection
        if (is.null(input$year_selection) || length(input$year_selection) != 2) {
          showNotification("Please select a year range", type = "error", duration = 5)
          values$loading_visible <- FALSE
          return()
        }
        
        # Determine start date from selected year range
        start_year <- input$year_selection[1]
        end_year <- input$year_selection[2]
        start_date <- paste0(start_year, "-01-01")
        
        # Combine parameter selections
        selected_parameters <- c(input$parameters_primary, input$parameters_additional)
        
        # Validate parameter selection
        if (is.null(selected_parameters) || length(selected_parameters) == 0) {
          showNotification("Please select at least one water quality parameter", type = "error", duration = 5)
          values$loading_visible <- FALSE
          return()
        }
        
        # Build query (updated to match script changes)
        qry <- list(
          countycode         = county_codes,
          characteristicName = selected_parameters,
          sampleMedia        = "Water",
          startDateLo        = start_date
        )
        
        # Create year range text
        if (start_year == end_year) {
          year_range_text <- paste("Year", start_year)
        } else {
          year_range_text <- paste("Years", start_year, "-", end_year)
        }
        
        values$status <- paste("Fetching data for", values$current_location, "(", county_codes, ") -", year_range_text, "- Parameters:", paste(selected_parameters, collapse = ", "))
        
        # Update status to show GET requests are running
        values$status <- paste("Making requests to USGS Water Quality Portal for", values$current_location, "for", length(selected_parameters), "parameters...")
        
        # Pull the data
        wq_raw <- do.call(readWQPdata,  qry)
        meta_df   <- do.call(whatWQPsites, qry)
        
        # Update status after requests complete
        values$status <- paste("Processing", nrow(wq_raw), "samples from", values$current_location, "...")
        
        if (nrow(wq_raw) == 0) {
          values$status <- paste("No data found for", values$current_location, ". Please check your selection or try a different county.")
          values$loading_visible <- FALSE
          return()
        }
        
        values$status <- paste("Processing", nrow(wq_raw), "samples from", values$current_location, "...")
        
        # Clean names
        wq_clean <- wq_raw %>% janitor::clean_names()
        meta <- meta_df %>% janitor::clean_names()
        
        # Process data following updated script logic
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
        
        # Join samples with metadata
        wq_join <- wq_tidy %>%
          left_join(meta_trim, by = "site_id") %>%
          relocate(site_name, lat, lon, .after = site_id)
        
        # Standardise units: convert µg/L → mg/L
        wq_join <- wq_join %>%
          mutate(
            value = if_else(unit %in% c("ug/l", "µg/l", "ug/L", "µg/L"),
                            value / 1000, value),
            unit  = if_else(unit %in% c("ug/l", "µg/l", "ug/L", "µg/L"),
                            "mg/L", unit)
          )
        
        # Create long format (wq_join)
        values$long_data <- wq_join
        
        # Create wide format
        wq_wide <- wq_join %>%
          pivot_wider(names_from = parameter, values_from = value) %>%
          mutate(
            state  = input$state_selection,
            county = values$current_location
          ) %>%
          select(state, county, site_id, site_name, lat, lon, date, everything(), -unit)

        values$wide_data <- wq_wide
        
        # Get top 5 most active sites (by measurement count)
        available_sites <- wq_join %>%
          group_by(site_id, site_name) %>%
          summarise(n_measurements = n(), .groups = "drop") %>%
          arrange(desc(n_measurements)) %>%
          slice_head(n = 5) %>%
          select(site_id, site_name)
        
        values$available_sites <- available_sites
        values$data_fetched <- TRUE
        
        # Update site selector choices
        site_choices <- c("All sites" = "all", 
                          setNames(available_sites$site_id, available_sites$site_name))
        updateSelectInput(session, "site_selection", 
                          choices = site_choices,
                          selected = "all")
        
        # Get unique parameters found in the data
        found_parameters <- unique(wq_join$parameter)
        
        values$status <- paste("Data processing complete for", values$current_location, "! Found", 
                               nrow(wq_join), "measurements from", 
                               length(unique(wq_join$site_id)), "monitoring sites. Year range:", year_range_text,
                               "- Parameters found:", paste(found_parameters, collapse = ", "))
        
        showNotification("Data fetched successfully!", type = "message", duration = 5)
        
        # Hide loading indicator
        values$loading_visible <- FALSE
        
      }, error = function(e) {
        values$status <- paste("Error:", e$message)
        showNotification(paste("Error fetching data:", e$message), type = "error", duration = 8)
        
        # Hide loading indicator
        values$loading_visible <- FALSE
      })
    }
    
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

        # Then apply time aggregation if selected
        if (!is.null(input$time_aggregation) && input$time_aggregation != "none") {
          data <- data %>%
            mutate(
              date = as.Date(date),
              time_period = case_when(
                input$time_aggregation == "day" ~ as.character(date),
                input$time_aggregation == "week" ~ as.character(floor_date(date, "week")),
                input$time_aggregation == "month" ~ format(date, "%Y-%m"),
                input$time_aggregation == "year" ~ format(date, "%Y")
              )
            ) %>%
            group_by(site_id, site_name, time_period) %>%
            summarise(
              across(where(is.numeric), ~mean(.x, na.rm = TRUE)),
              n_measurements = n(),
              date_range = paste(min(date, na.rm = TRUE), "to", max(date, na.rm = TRUE)),
              .groups = "drop"
            ) %>%
            rename(date = time_period) %>%
            select(site_id, site_name, date, everything())
        }

        return(data)
      }
    })
    
    # Data preview
    output$preview_wide <- DT::renderDataTable({
      data <- filtered_wide_data()
      if (!is.null(data)) {
        display_data <- data %>% select(-any_of(c("site_id", "row_id")))
        DT::datatable(display_data, options = list(scrollX = TRUE, pageLength = 10))
      }
    })
    
    # Download handler
    output$download_wide <- downloadHandler(
      filename = function() {
        location_safe <- gsub("[^A-Za-z0-9]", "_", values$current_location)
        site_suffix <- if("all" %in% input$site_selection) "all_sites" else "selected_sites"
        agg_suffix <- if(!is.null(input$time_aggregation) && input$time_aggregation != "none") {
          paste0("_", input$time_aggregation, "ly")
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
      
      # Get dataset name from input and add aggregation suffix
      dataset_name <- input$codap_dataset_name
      if (is.null(dataset_name) || dataset_name == "") {
        dataset_name <- "WaterQualityData"
      }

      # Add aggregation level to dataset name
      if (!is.null(input$time_aggregation) && input$time_aggregation != "none") {
        agg_label <- switch(input$time_aggregation,
          "day" = "Daily",
          "week" = "Weekly",
          "month" = "Monthly",
          "year" = "Yearly"
        )
        dataset_name <- paste0(dataset_name, "_", agg_label)
      }
      
      # Convert data frame columns into CODAP attributes format
      # Format: list(name = colName, title = colName)
      attributes <- lapply(names(data), function(col_name) {
        list(
          name = col_name,
          title = col_name
        )
      })
      
      # Convert data frame rows into a list of cases
      # Each case is a list of values corresponding to the attributes
      cases <- lapply(seq_len(nrow(data)), function(i) {
        row_data <- as.list(data[i, ])
        # Convert any NA values to null for JSON serialization
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
      showNotification(
        paste("Sending", nrow(data), "rows to CODAP as dataset:", dataset_name),
        type = "message",
        duration = 3
      )
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

    # =============================================================================
    # AIR QUALITY SERVER LOGIC
    # =============================================================================

    # Update county choices when air quality state changes
    observeEvent(input$air_state_selection, {
      if (input$air_state_selection != "") {
        # Get state FIPS code
        state_info <- states_df[states_df$state_name == input$air_state_selection, ]
        
        if (nrow(state_info) > 0) {
          # Filter counties for this state
          counties_for_state <- fips_clean %>%
            filter(state_fips == state_info$state_fips) %>%
            arrange(county_name)
          
          county_choices <- setNames(counties_for_state$county_display, counties_for_state$county_display)

          # Set default to Knox County if Tennessee is selected
          default_county <- if(input$air_state_selection == "Tennessee") "Knox County" else character(0)

        } else {
          county_choices <- character(0)
          default_county <- character(0)
        }

        updateSelectizeInput(session, "air_county_selection", choices = county_choices, selected = default_county)
      }
    })
    
    # Show warning for large year ranges (air quality)
    observeEvent(input$air_year_selection, {
      if (!is.null(input$air_year_selection) && length(input$air_year_selection) == 2) {
        year_range <- input$air_year_selection[2] - input$air_year_selection[1] + 1
        if (year_range > 2) {
          showNotification(
            paste("Loading", year_range, "years of hourly air quality data may take a while."),
            type = "warning", duration = 6
          )
        }
      }
    })

    # Step 1: Find Monitors button
    observeEvent(input$find_air_monitors, {
      if (input$air_state_selection == "" ||
          is.null(input$air_county_selection) || length(input$air_county_selection) == 0) {
        showNotification("Please select both state and at least one county", type = "error", duration = 5)
        return()
      }
      if (is.null(input$air_parameters) || length(input$air_parameters) == 0) {
        showNotification("Please select at least one air quality parameter", type = "error", duration = 5)
        return()
      }

      # Reset state before search
      values$air_monitors_found <- FALSE
      values$air_data_fetched <- FALSE
      values$air_wide_data <- NULL
      values$air_long_data <- NULL
      values$air_available_monitors <- NULL

      county_info <- fips_clean %>%
        filter(state_name == input$air_state_selection,
               county_display %in% input$air_county_selection)

      if (nrow(county_info) == 0) {
        showNotification("County not found in database.", type = "error", duration = 5)
        return()
      }

      values$air_current_state_fips  <- county_info$state_fips[1]
      values$air_current_county_fips <- county_info$county_fips   # vector of county FIPS
      values$air_current_location <- if (length(input$air_county_selection) == 1) {
        paste(input$air_county_selection, input$air_state_selection, sep = ", ")
      } else {
        paste0(paste(input$air_county_selection, collapse = ", "), ", ", input$air_state_selection)
      }
      values$air_status <- paste("Searching for monitors in", values$air_current_location, "...")
      values$air_loading_visible <- TRUE

      tryCatch({
        bdate <- as.Date(paste0(input$air_year_selection[1], "-01-01"))
        edate <- as.Date(paste0(input$air_year_selection[2], "-12-31"))
        params <- input$air_parameters

        # Query monitors for each selected parameter × county combination
        monitor_list <- list()
        for (county_fips in county_info$county_fips) {
          for (param in params) {
            result <- tryCatch({
              RAQSAPI::aqs_monitors_by_county(
                parameter  = param,
                bdate      = bdate,
                edate      = edate,
                stateFIPS  = county_info$state_fips[1],
                countycode = county_fips
              )
            }, error = function(e) NULL)
            if (!is.null(result)) monitor_list <- c(monitor_list, list(result))
          }
        }

        all_raw <- bind_rows(monitor_list)

        if (is.null(all_raw) || nrow(all_raw) == 0) {
          values$air_status <- paste(
            "No monitors found for the selected parameters in",
            values$air_current_location,
            "for the selected year range. Try different parameters or a wider year range."
          )
          values$air_loading_visible <- FALSE
          showNotification("No monitors found. Try adjusting parameters or year range.",
                           type = "warning", duration = 8)
          return()
        }

        monitors_clean <- all_raw %>% janitor::clean_names()

        # Find sites that report ALL requested parameters (mirrors notebook filter logic)
        sites_summary <- monitors_clean %>%
          group_by(state_code, county_code, site_number) %>%
          summarise(params_available = list(unique(parameter_code)), .groups = "drop")

        sites_all <- sites_summary %>%
          filter(sapply(params_available, function(p) all(params %in% p)))

        if (nrow(sites_all) == 0) {
          # Fall back: sites with at least one of the requested params
          sites_any <- sites_summary %>%
            mutate(n_params = sapply(params_available, function(p) sum(params %in% p))) %>%
            filter(n_params > 0) %>%
            arrange(desc(n_params))

          if (nrow(sites_any) == 0) {
            values$air_status <- paste("No monitors found for the selected parameters in", values$air_current_location)
            values$air_loading_visible <- FALSE
            return()
          }

          showNotification(
            "No single monitor has all selected parameters. Showing monitors with at least one.",
            type = "warning", duration = 8
          )
          sites_with_data <- sites_any
        } else {
          sites_with_data <- sites_all
        }

        # Build display info per site
        site_details <- monitors_clean %>%
          select(state_code, county_code, site_number, address, city_name, county_name) %>%
          distinct() %>%
          inner_join(
            sites_with_data %>% select(state_code, county_code, site_number),
            by = c("state_code", "county_code", "site_number")
          ) %>%
          mutate(
            display_city = ifelse(
              tolower(trimws(city_name)) %in% c("not in a city", ""),
              county_name, city_name
            ),
            site_label = paste0(site_number, " - ", address, ", ", display_city),
            site_id    = paste0(county_code, "-", site_number)
          ) %>%
          distinct(site_id, .keep_all = TRUE)

        values$air_available_monitors <- site_details

        site_choices <- c("All monitors" = "all", setNames(site_details$site_id, site_details$site_label))
        updateSelectInput(session, "air_site_selection",
                          choices  = site_choices,
                          selected = "all")

        n_sites <- nrow(site_details)
        values$air_status <- paste(
          "Found", n_sites, "monitoring station(s) in", values$air_current_location,
          "with data for the selected parameters.",
          "Select station(s) below and click 'Step 2: Fetch Air Quality Data'."
        )
        values$air_monitors_found  <- TRUE
        values$air_loading_visible <- FALSE

        showNotification(paste("Found", n_sites, "monitor(s). Select one and fetch data."),
                         type = "message", duration = 5)

      }, error = function(e) {
        values$air_status <- paste("Error finding monitors:", e$message)
        showNotification(paste("Error:", e$message), type = "error", duration = 8)
        values$air_loading_visible <- FALSE
      })
    })

    # Step 2: Fetch Air Quality Data function
    fetch_air_data <- function() {
      values$air_status <- "Fetching air quality sample data from EPA AQS..."

      tryCatch({
        site_selection <- input$air_site_selection
        params   <- input$air_parameters
        bdate    <- as.Date(paste0(input$air_year_selection[1], "-01-01"))
        edate    <- as.Date(paste0(input$air_year_selection[2], "-12-31"))

        # Handle "all" selection or multiple sites
        if ("all" %in% site_selection) {
          site_ids <- values$air_available_monitors$site_id
        } else {
          site_ids <- site_selection
        }

        n_sites <- length(site_ids)
        values$air_status <- paste(
          "Fetching data for", n_sites, "site(s) —",
          length(params), "parameter(s),",
          input$air_year_selection[1], "–", input$air_year_selection[2]
        )

        # Fetch data for each site
        all_site_data <- list()

        for (i in seq_along(site_ids)) {
          site_id <- site_ids[i]

          # Parse site_id: format is "county_code-site_number"
          site_parts <- strsplit(site_id, "-")[[1]]
          county_code <- site_parts[1]
          site_number <- site_parts[2]

          # Get site details for this site
          site_info <- values$air_available_monitors %>%
            filter(site_id == !!site_id)

          site_label <- if (nrow(site_info) > 0) site_info$site_label[1] else site_id

          values$air_status <- paste(
            "Fetching site", i, "of", n_sites, "—", site_label
          )

          # Fetch sample data for each parameter separately (RAQSAPI takes one at a time)
          raw_list <- lapply(params, function(param) {
            tryCatch({
              RAQSAPI::aqs_sampledata_by_site(
                parameter  = param,
                bdate      = bdate,
                edate      = edate,
                stateFIPS  = values$air_current_state_fips,
                countycode = county_code,
                sitenum    = site_number
              )
            }, error = function(e) {
              message("Failed to fetch param ", param, " for site ", site_id, ": ", e$message)
              NULL
            })
          })

          raw_data <- bind_rows(Filter(Negate(is.null), raw_list))

          if (!is.null(raw_data) && nrow(raw_data) > 0) {
            # Add site identifier to the raw data
            raw_data$site_id <- site_id
            raw_data$site_label <- site_label
            all_site_data[[i]] <- raw_data
          }
        }

        # Combine data from all sites
        combined_raw <- bind_rows(all_site_data)

        if (is.null(combined_raw) || nrow(combined_raw) == 0) {
          values$air_status <- paste(
            "No data found for the selected site(s)",
            "with the selected parameters and year range."
          )
          values$air_loading_visible <- FALSE
          showNotification("No data found. Try a different site, parameters, or year range.",
                           type = "warning", duration = 8)
          return()
        }

        values$air_status <- paste("Processing", nrow(combined_raw), "records from", n_sites, "site(s)...")

        aq_clean <- combined_raw %>% janitor::clean_names()

        # Build combined datetime field and keep site identifiers
        aq_tidy <- aq_clean %>%
          mutate(
            date_str       = format(as.Date(date_local), "%Y-%m-%d"),
            datetime_local = as.POSIXct(paste(date_str, time_local), format = "%Y-%m-%d %H:%M")
          ) %>%
          select(site_id, site_label, site_number, county_name, latitude, longitude,
                 datetime_local, parameter_code, sample_measurement) %>%
          filter(!is.na(sample_measurement))

        values$air_long_data <- aq_tidy

        # Pivot to wide: one row per site+datetime, one column per parameter code
        aq_wide <- aq_tidy %>%
          pivot_wider(
            id_cols = c(site_id, site_label, site_number, county_name, latitude, longitude, datetime_local),
            names_from  = parameter_code,
            values_from = sample_measurement,
            values_fn   = mean
          )

        # Calculate composite AQI per row using parameter-code columns
        param_code_cols <- intersect(names(aq_wide), names(aqi_breakpoints))
        if (length(param_code_cols) > 0) {
          aq_wide$composite_aqi <- apply(
            aq_wide[, param_code_cols, drop = FALSE], 1,
            function(row) {
              conc_vec <- as.numeric(row)
              names(conc_vec) <- param_code_cols
              conc_vec <- conc_vec[!is.na(conc_vec)]
              if (length(conc_vec) == 0) return(NA_real_)
              calculate_composite_aqi(conc_vec)
            }
          )
        }

        # Rename parameter-code columns to human-readable display names
        for (code in names(air_params)) {
          if (code %in% names(aq_wide)) {
            names(aq_wide)[names(aq_wide) == code] <- air_params[[code]]
          }
        }

        # Format datetime and reorder columns with site info first
        aq_wide <- aq_wide %>%
          mutate(
            datetime_local = format(datetime_local, "%Y-%m-%d %H:%M"),
            location       = values$air_current_location
          ) %>%
          select(site_number, site_label, county_name, latitude, longitude, location,
                 datetime_local, everything(), -site_id)

        values$air_wide_data  <- aq_wide
        values$air_data_fetched <- TRUE

        values$air_status <- paste(
          "Data ready —", n_sites, "site(s) in", values$air_current_location, "—",
          nrow(aq_wide), "time points,", length(params), "pollutant(s) + composite AQI.",
          "Year range:", input$air_year_selection[1], "-", input$air_year_selection[2]
        )

        showNotification(
          paste("Air quality data fetched successfully!", n_sites, "site(s),", nrow(aq_wide), "records"),
          type = "message", duration = 5
        )
        values$air_loading_visible <- FALSE

      }, error = function(e) {
        values$air_status <- paste("Error:", e$message)
        showNotification(paste("Error fetching air quality data:", e$message), type = "error", duration = 8)
        values$air_loading_visible <- FALSE
      })
    }

    # Trigger Step 2 on button click
    observeEvent(input$fetch_air_data, {
      if (is.null(input$air_site_selection) || length(input$air_site_selection) == 0) {
        showNotification("Please find and select at least one monitoring site first (Step 1)", type = "error", duration = 5)
        return()
      }
      values$air_loading_visible <- TRUE
      fetch_air_data()
    })

    # Air quality refresh/clear
    observeEvent(input$refresh_air_data, {
      values$air_wide_data        <- NULL
      values$air_long_data        <- NULL
      values$air_data_fetched     <- FALSE
      values$air_monitors_found   <- FALSE
      values$air_status           <- "Ready to fetch air quality data..."
      values$air_current_state_fips <- ""
      values$air_current_county_fips <- ""
      values$air_current_location <- ""
      values$air_loading_visible  <- FALSE
      values$air_available_sites  <- NULL
      values$air_available_monitors <- NULL

      updateSelectInput(session, "air_state_selection", selected = "")
      updateSelectInput(session, "air_county_selection",
                        choices = c("Choose a county..." = ""), selected = "")
      updateSliderInput(session, "air_year_selection", value = c(2022, 2024))
      updateCheckboxGroupInput(session, "air_parameters", selected = c("44201", "88101"))
      updateSelectInput(session, "air_site_selection",
                        choices = c("Select a monitor..." = ""), selected = "")

      showNotification("Air quality interface refreshed!", type = "message", duration = 3)
    })

    # Air quality status output
    output$air_status_text <- renderText({
      values$air_status
    })

    # Air quality data preview
    output$air_preview_wide <- DT::renderDataTable({
      data <- values$air_wide_data
      if (!is.null(data)) {
        DT::datatable(data, options = list(scrollX = TRUE, pageLength = 10))
      }
    })

    # Air quality CSV download
    output$download_air_data <- downloadHandler(
      filename = function() {
        location_safe <- gsub("[^A-Za-z0-9]", "_", values$air_current_location)
        site_safe     <- gsub("[^A-Za-z0-9]", "_", input$air_site_selection)
        paste0("air_quality_", location_safe, "_site_", site_safe, "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        data <- values$air_wide_data
        if (!is.null(data)) {
          write_csv(data, file)
        }
      }
    )

    # =============================================================================
    # CODAP EXPORT SERVER LOGIC - Air Quality
    # =============================================================================

    observeEvent(input$send_air_to_codap, {
      data <- values$air_wide_data

      if (is.null(data) || nrow(data) == 0) {
        showNotification("No data available to send to CODAP. Please fetch air quality data first.",
                         type = "error", duration = 5)
        return()
      }

      dataset_name <- "AirQualityData"

      # Convert datetime column to character for JSON serialization
      data_export <- data %>%
        mutate(datetime_local = as.character(datetime_local))

      attributes <- lapply(names(data_export), function(col_name) {
        list(name = col_name, title = col_name)
      })

      cases <- lapply(seq_len(nrow(data_export)), function(i) {
        row_data <- as.list(data_export[i, ])
        row_data <- lapply(row_data, function(x) {
          if (is.null(x) || (length(x) == 1 && is.na(x))) return(NULL) else return(x)
        })
        return(row_data)
      })

      session$sendCustomMessage(
        type = "sendToCODAP",
        message = list(
          datasetName = dataset_name,
          attributes  = attributes,
          cases       = cases
        )
      )

      showNotification(
        paste("Sending", nrow(data_export), "rows to CODAP as dataset:", dataset_name),
        type = "message",
        duration = 3
      )
    })

    # =============================================================================
    ## ARCHIVED: WEATHER & CLIMATE SERVER LOGIC - Focusing on Water Quality first
    ## To restore: Remove the if(FALSE) wrapper
    # =============================================================================
    if(FALSE) {
    # Update weather county choices when state changes
    observeEvent(input$weather_state_selection, {
      if (input$weather_state_selection != "") {
        # Get state FIPS code
        state_info <- states_df[states_df$state_name == input$weather_state_selection, ]
        
        if (nrow(state_info) > 0) {
          # Filter counties for this state
          counties_for_state <- fips_clean %>%
            filter(state_fips == state_info$state_fips) %>%
            arrange(county_name)
          
          county_choices <- c("Choose a county..." = "", 
                              setNames(counties_for_state$county_display, counties_for_state$county_display))
          
          # Set default to Knox County if Tennessee is selected
          default_county <- if(input$weather_state_selection == "Tennessee") "Knox County" else ""
          
        } else {
          county_choices <- c("State not found" = "")
          default_county <- ""
        }
        
        updateSelectInput(session, "weather_county_selection", choices = county_choices, selected = default_county)
      }
    })
    
    # Initialize Knox County for weather when app loads
    observe({
      if (input$weather_state_selection == "Tennessee") {
        isolate({
          state_info <- states_df[states_df$state_name == "Tennessee", ]
          if (nrow(state_info) > 0) {
            counties_for_state <- fips_clean %>%
              filter(state_fips == state_info$state_fips) %>%
              arrange(county_name)
            
            county_choices <- c("Choose a county..." = "", 
                                setNames(counties_for_state$county_display, counties_for_state$county_display))
            
            updateSelectInput(session, "weather_county_selection", choices = county_choices, selected = "Knox County")
          }
        })
      }
    })
    
    # Show warning for large year ranges (weather)
    observeEvent(input$weather_year_selection, {
      if (!is.null(input$weather_year_selection) && length(input$weather_year_selection) == 2) {
        year_range <- input$weather_year_selection[2] - input$weather_year_selection[1] + 1
        if (year_range > 3) {
          warning_text <- paste("Loading", year_range, "years of weather data may take 30-90 seconds depending on data availability.")
          showNotification(warning_text, type = "warning", duration = 6)
        }
      }
    })
    
    # Display current weather selection
    output$weather_location_display <- renderText({
      if (input$weather_state_selection != "" && input$weather_county_selection != "") {
        paste(input$weather_county_selection, ",", input$weather_state_selection)
      } else {
        "None selected"
      }
    })
    
    # Display weather FIPS codes  
    output$weather_fips_display <- renderText({
      if (input$weather_state_selection != "" && input$weather_county_selection != "") {
        county_info <- fips_clean %>%
          filter(state_name == input$weather_state_selection,
                 county_display == input$weather_county_selection)
        
        if (nrow(county_info) > 0) {
          paste("State:", county_info$state_fips, "County:", county_info$county_fips, "Full:", county_info$full_fips)
        } else {
          "Codes not found"
        }
      } else {
        "None selected"
      }
    })
    
    # Weather data fetching logic
    observeEvent(input$fetch_weather_data, {
      
      # Check if climateR is available
      if (!requireNamespace("climateR", quietly = TRUE)) {
        showNotification("climateR package is required. Install with: devtools::install_github('mikejohnson51/climateR')", 
                         type = "error", duration = 10)
        return()
      }
      
      # Validate inputs
      if (input$weather_state_selection == "" || input$weather_county_selection == "") {
        showNotification("Please select both state and county", type = "error", duration = 5)
        return()
      }
      
      # Show loading indicator
      values$weather_loading_visible <- TRUE
      
      # Get FIPS codes
      county_info <- fips_clean %>%
        filter(state_name == input$weather_state_selection,
               county_display == input$weather_county_selection)
      
      if (nrow(county_info) == 0) {
        showNotification("County not found in database. Please try again.", type = "error", duration = 5)
        values$weather_loading_visible <- FALSE
        return()
      }
      
      values$weather_current_state_fips <- county_info$state_fips
      values$weather_current_county_fips <- county_info$county_fips
      values$weather_current_location <- paste(input$weather_county_selection, input$weather_state_selection, sep = ", ")
      
      fetch_weather_data()
    })
    
    # Weather refresh/clear functionality
    observeEvent(input$refresh_weather_data, {
      # Reset all weather reactive values
      values$weather_wide_data <- NULL
      values$weather_data_fetched <- FALSE
      values$weather_status <- "Ready to fetch weather data..."
      values$weather_current_state_fips <- ""
      values$weather_current_county_fips <- ""
      values$weather_current_location <- ""
      values$weather_loading_visible <- FALSE
      values$weather_available_stations <- NULL
      
      # Reset weather input selections
      updateSelectInput(session, "weather_state_selection", selected = "")
      updateSelectInput(session, "weather_county_selection", 
                        choices = c("Choose a county..." = ""),
                        selected = "")
      updateSliderInput(session, "weather_year_selection", value = c(2023, 2024))
      updateSelectInput(session, "weather_dataset", selected = "terraclimate")
      updateCheckboxGroupInput(session, "weather_parameters_primary", 
                               selected = c("tmax", "tmin", "ppt"))
      updateCheckboxGroupInput(session, "weather_parameters_additional", 
                               selected = c())
      updateSelectInput(session, "weather_station_selection", 
                        choices = c("All parameters" = "all"),
                        selected = "all")
      
      showNotification("Weather interface refreshed and data cleared!", type = "message", duration = 3)
    })
    
    # Weather data fetching function
    fetch_weather_data <- function() {
      
      # Update status
      values$weather_status <- "Fetching weather data using climateR..."
      
      tryCatch({
        # Combine parameter selections
        selected_parameters <- c(input$weather_parameters_primary, input$weather_parameters_additional)
        
        # Validate parameter selection
        if (is.null(selected_parameters) || length(selected_parameters) == 0) {
          showNotification("Please select at least one weather parameter", type = "error", duration = 5)
          values$weather_loading_visible <- FALSE
          return()
        }
        
        # Validate year selection
        if (is.null(input$weather_year_selection) || length(input$weather_year_selection) != 2) {
          showNotification("Please select a year range", type = "error", duration = 5)
          values$weather_loading_visible <- FALSE
          return()
        }
        
        # Get the county FIPS code for climateR
        county_fips <- values$weather_current_county_fips
        if (is.null(county_fips) || county_fips == "") {
          showNotification("County FIPS code not found", type = "error", duration = 5)
          values$weather_loading_visible <- FALSE
          return()
        }
        
        # Determine start and end date from selected year range
        start_year <- input$weather_year_selection[1]
        end_year <- input$weather_year_selection[2]
        start_date <- paste0(start_year, "-01-01")
        end_date <- paste0(end_year, "-12-31")
        
        # Create year range text
        if (start_year == end_year) {
          year_range_text <- paste("Year", start_year)
        } else {
          year_range_text <- paste("Years", start_year, "-", end_year)
        }
        
        values$weather_status <- paste("Fetching", input$weather_dataset, "data for", values$weather_current_location, "-", year_range_text, "- Parameters:", paste(selected_parameters, collapse = ", "))
        
        # Get county boundary as AOI for climateR
        county_aoi <- AOI::aoi_get(county = values$weather_current_location)
        
        # Update status to show requests are running
        values$weather_status <- paste("Making requests to", input$weather_dataset, "for", values$weather_current_location, "for", length(selected_parameters), "parameters...")
        
        # Fetch data based on selected dataset
        weather_data <- switch(input$weather_dataset,
          "terraclimate" = {
            getTerraClim(AOI = county_aoi, 
                        param = selected_parameters,
                        startDate = start_date,
                        endDate = end_date)
          },
          "gridmet" = {
            getGridMET(AOI = county_aoi,
                      param = selected_parameters,
                      startDate = start_date,
                      endDate = end_date)
          },
          "daymet" = {
            getDaymet(AOI = county_aoi,
                     param = selected_parameters,
                     start = start_year,
                     end = end_year)
          }
        )
        
        # Convert SpatRaster to data frame for display
        if (!is.null(weather_data) && class(weather_data)[1] == "SpatRaster") {
          # Extract data and convert to long format
          weather_df <- as.data.frame(weather_data, xy = TRUE)
          weather_long <- weather_df %>%
            pivot_longer(cols = -c(x, y), names_to = "variable_date", values_to = "value") %>%
            mutate(
              date = str_extract(variable_date, "\\d{4}_\\d{2}_\\d{2}|\\d{4}\\d{2}\\d{2}"),
              parameter = str_remove(variable_date, "_\\d{4}_\\d{2}_\\d{2}|_\\d{4}\\d{2}\\d{2}"),
              date = case_when(
                str_detect(date, "_") ~ as.Date(date, format = "%Y_%m_%d"),
                TRUE ~ as.Date(date, format = "%Y%m%d")
              )
            ) %>%
            select(x, y, date, parameter, value) %>%
            arrange(date, parameter)
          
          # Summarize by county (take mean across pixels)
          weather_summary <- weather_long %>%
            group_by(date, parameter) %>%
            summarise(
              mean_value = round(mean(value, na.rm = TRUE), 3),
              min_value = round(min(value, na.rm = TRUE), 3),
              max_value = round(max(value, na.rm = TRUE), 3),
              .groups = "drop"
            ) %>%
            mutate(
              location = values$weather_current_location,
              dataset = input$weather_dataset
            )
          
          values$weather_wide_data <- weather_summary
        } else {
          # If no data returned, create empty data frame
          values$weather_wide_data <- data.frame(
            date = as.Date(character()),
            parameter = character(),
            mean_value = numeric(),
            min_value = numeric(),
            max_value = numeric(),
            location = character(),
            dataset = character()
          )
        }
        
        values$weather_data_fetched <- TRUE
        
        # Get available parameters for selector (simplified - using parameters as "stations")
        available_parameters <- data.frame(
          parameter_id = selected_parameters,
          parameter_name = selected_parameters,
          stringsAsFactors = FALSE
        )
        
        values$weather_available_stations <- available_parameters
        
        # Update parameter selector choices
        parameter_choices <- c("All parameters" = "all", 
                              setNames(available_parameters$parameter_id, available_parameters$parameter_name))
        updateSelectInput(session, "weather_station_selection", 
                          label = "Select Parameter(s):",
                          choices = parameter_choices,
                          selected = "all")
        
        # Calculate summary statistics
        data_rows <- nrow(values$weather_wide_data)
        unique_dates <- length(unique(values$weather_wide_data$date))
        unique_params <- length(unique(values$weather_wide_data$parameter))
        
        values$weather_status <- paste("Data loaded for", values$weather_current_location, "!", 
                                      data_rows, "records with", unique_params, "parameters across", unique_dates, "time periods from", input$weather_dataset)
        
        showNotification(paste("Weather data successfully loaded!", data_rows, "records retrieved"), type = "message", duration = 5)
        
        # Hide loading indicator
        values$weather_loading_visible <- FALSE
        
      }, error = function(e) {
        values$weather_status <- paste("Error:", e$message)
        showNotification(paste("Error fetching weather data:", e$message), type = "error", duration = 8)
        values$weather_loading_visible <- FALSE
      })
    }
    
    # Weather status output
    output$weather_status_text <- renderText({
      values$weather_status
    })
    
    # Weather data filtering based on parameter selection
    filtered_weather_data <- reactive({
      if (!is.null(values$weather_wide_data)) {
        if ("all" %in% input$weather_station_selection || is.null(input$weather_station_selection)) {
          values$weather_wide_data
        } else {
          values$weather_wide_data %>% filter(parameter %in% input$weather_station_selection)
        }
      }
    })
    
    # Weather data preview
    output$weather_preview_wide <- DT::renderDataTable({
      data <- filtered_weather_data()
      if (!is.null(data)) {
        DT::datatable(data, options = list(scrollX = TRUE, pageLength = 10))
      }
    })
    
    # Weather download handler
    output$download_weather_data <- downloadHandler(
      filename = function() {
        location_safe <- gsub("[^A-Za-z0-9]", "_", values$weather_current_location)
        station_suffix <- if("all" %in% input$weather_station_selection) "all_stations" else "selected_stations"
        paste0("weather_data_", location_safe, "_", station_suffix, "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        data <- filtered_weather_data()
        if (!is.null(data)) {
          write_csv(data, file)
        }
      }
    )
    
    # =============================================================================
    # CODAP EXPORT SERVER LOGIC - Weather & Climate
    # =============================================================================
    
    # observeEvent for "Send to CODAP" button (Weather & Climate)
    observeEvent(input$send_weather_to_codap, {
      # Get the filtered data
      data <- filtered_weather_data()
      
      # Validate that data exists
      if (is.null(data) || nrow(data) == 0) {
        showNotification("No data available to send to CODAP. Please fetch weather data first.", 
                         type = "error", duration = 5)
        return()
      }
      
      # Get dataset name from input
      dataset_name <- input$codap_weather_dataset_name
      if (is.null(dataset_name) || dataset_name == "") {
        dataset_name <- "WeatherData"
      }
      
      # Convert data frame columns into CODAP attributes format
      # Format: list(name = colName, title = colName)
      attributes <- lapply(names(data), function(col_name) {
        list(
          name = col_name,
          title = col_name
        )
      })
      
      # Convert data frame rows into a list of cases
      # Each case is a list of values corresponding to the attributes
      cases <- lapply(seq_len(nrow(data)), function(i) {
        row_data <- as.list(data[i, ])
        # Convert any NA values to null for JSON serialization
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
      showNotification(
        paste("Sending", nrow(data), "rows to CODAP as dataset:", dataset_name),
        type = "message",
        duration = 3
      )
    })
    } # End if(FALSE) - Weather & Climate server logic archived
}

# Run the application
shinyApp(ui = ui, server = server) 