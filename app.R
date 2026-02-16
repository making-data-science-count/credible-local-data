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

aqs_creds <- RAQSAPI::aqs_credentials(username = "jmrosen48@gmail.com", key = "ochregazelle27")

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

# Simplified CSS theme
custom_css <- "
/* Simple loading spinner */
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
  border: 3px solid #f3f3f3;
  border-radius: 50%;
  border-top-color: #007bff;
  animation: spin 1s ease-in-out infinite;
  margin-bottom: 15px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Simple progress bar */
.progress-bar-custom {
  width: 100%;
  height: 6px;
  background-color: #e9ecef;
  border-radius: 3px;
  overflow: hidden;
  margin-top: 10px;
}

.progress-bar-fill {
  height: 100%;
  background-color: #007bff;
  border-radius: 3px;
  animation: progress 3s ease-in-out infinite;
}

@keyframes progress {
  0% { width: 0%; }
  50% { width: 70%; }
  100% { width: 100%; }
}

/* Clean header styling */
.main-header .navbar-brand {
  color: white !important;
  font-weight: bold !important;
  padding: 15px !important;
}

/* Simple status text */
#status_text {
  background-color: #f8f9fa;
  border-left: 4px solid #007bff;
  padding: 15px;
  border-radius: 4px;
  font-family: monospace;
}

/* Clean box styling */
.box {
  border-radius: 6px !important;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1) !important;
  margin-bottom: 20px !important;
}

/* Advanced options styling */
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
}

details[open] summary {
  margin-bottom: 15px;
  padding-bottom: 10px;
  border-bottom: 1px solid #dee2e6;
}
"

# Add resource path for logo
addResourcePath("images", ".")

# UI
ui <- dashboardPage(
  dashboardHeader(
    title = "CREDIBLE Local Data"
  ),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Water Quality", tabName = "water", icon = icon("water")),
      ## ARCHIVED: Focusing on Water Quality first - restore these later
      # menuItem("Air Quality", tabName = "air", icon = icon("wind")),
      # menuItem("Weather & Climate", tabName = "weather", icon = icon("cloud-sun")),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    )
  ),
  
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
    
    tabItems(
      # Water Quality Tab
      tabItem(tabName = "water",
              fluidRow(
                box(
                  title = "Access Data", status = "primary", solidHeader = TRUE, width = 12,
                  fluidRow(
                    column(3,
                           selectInput("state_selection", "Select State:", 
                                       choices = c("Choose a state..." = "", 
                                                   setNames(states_df$state_name, states_df$state_name)),
                                       selected = "Tennessee")
                    ),
                    column(3,
                           selectInput("county_selection", "Select County:", 
                                       choices = c("Choose a county..." = ""))
                    ),
                    column(3,
                           sliderInput("year_selection", "Select Year Range:",
                                       min = 1960, max = 2024, 
                                       value = c(2023, 2024),
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
                                              selected = c("pH", "Phosphorus", "Turbidity"),
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
                                              selected = c(),
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

                  hr(),
                  fluidRow(
                    column(6,
                           p(strong("Selected Location:"), textOutput("location_display", inline = TRUE))
                    ),
                    column(6,
                           p(strong("FIPS Codes:"), textOutput("fips_display", inline = TRUE))
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
                    )
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
              

              fluidRow(
                box(
                  title = "Data Preview", status = "warning", solidHeader = TRUE, width = 12,
                  DT::dataTableOutput("preview_wide"),
                  br(),
                  # ============================================================================
                  # CODAP EXPORT UI ELEMENTS - Water Quality
                  # ============================================================================
                  div(style = "text-align: center; margin-top: 15px; padding: 15px; background-color: #f8f9fa; border-radius: 8px;",
                      h4("Export Options", style = "margin-bottom: 15px;"),
                      fluidRow(
                        column(4,
                               downloadButton("download_wide", "Download as CSV", 
                                              class = "btn-success", icon = icon("download"),
                                              style = "width: 100%; margin-bottom: 10px;")
                        ),
                        column(4,
                               textInput("codap_dataset_name", "CODAP Dataset Name:", 
                                         value = "WaterQualityData",
                                         placeholder = "Enter dataset name")
                        ),
                        column(4,
                               actionButton("send_to_codap", "Send to CODAP", 
                                            class = "btn-info", icon = icon("share-square"),
                                            style = "width: 100%; margin-top: 25px;")
                        )
                      ),
                      p("Download data as CSV or send directly to CODAP for interactive analysis", 
                        style = "margin-top: 10px; font-size: 12px; color: #6c757d;")
                  )
                )
              )
      ),

      ## ARCHIVED: Air Quality and Weather tabs removed - see git history or ARCHIVED_FEATURES.md to restore

      # About Tab
      tabItem(tabName = "about",
        fluidRow(
          box(
            title = "About CREDIBLE Local Data", status = "primary", solidHeader = TRUE, width = 12,
            div(style = "padding: 20px; text-align: center;",
              tags$img(src = "images/credible-logo.png", height = "250px", style = "margin-bottom: 30px;"),
              h3("CREDIBLE Local Data Collection Tool"),
              p("See more related information at https://projectcredible.com")
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
      current_county_fips = "",
      current_location = "",
      loading_visible = FALSE,
      available_sites = NULL

      ## ARCHIVED: Air quality and Weather reactive values
      ## To restore: Uncomment the sections below
      # # Air quality data
      # air_wide_data = NULL,
      # air_data_fetched = FALSE,
      # air_status = "Ready to fetch air quality data...",
      # air_current_state_fips = "",
      # air_current_county_fips = "",
      # air_current_location = "",
      # air_loading_visible = FALSE,
      # air_available_sites = NULL,
      #
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
          
          county_choices <- c("Choose a county..." = "", 
                              setNames(counties_for_state$county_display, counties_for_state$county_display))
          
          # Set default to Knox County if Tennessee is selected
          default_county <- if(input$state_selection == "Tennessee") "Knox County" else ""
          
        } else {
          county_choices <- c("State not found" = "")
          default_county <- ""
        }
        
        updateSelectInput(session, "county_selection", choices = county_choices, selected = default_county)
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
            
            county_choices <- c("Choose a county..." = "", 
                                setNames(counties_for_state$county_display, counties_for_state$county_display))
            
            updateSelectInput(session, "county_selection", choices = county_choices, selected = "Knox County")
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
      if (input$state_selection != "" && input$county_selection != "") {
        # Since county_display now shows the full name, use it directly
        paste(input$county_selection, ",", input$state_selection)
      } else {
        "None selected"
      }
    })
    
    # Display FIPS codes  
    output$fips_display <- renderText({
      if (input$state_selection != "" && input$county_selection != "") {
        # Find the county info
        county_info <- fips_clean %>%
          filter(state_name == input$state_selection,
                 county_display == input$county_selection)
        
        if (nrow(county_info) > 0) {
          paste("State:", county_info$state_fips, "County:", county_info$county_fips, "Full:", county_info$full_fips)
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
      if (input$state_selection == "" || input$county_selection == "") {
        showNotification("Please select both state and county", type = "error", duration = 5)
        return()
      }
      
      # Show loading indicator
      values$loading_visible <- TRUE
      
      # Get FIPS codes
      county_info <- fips_clean %>%
        filter(state_name == input$state_selection,
               county_display == input$county_selection)
      
      if (nrow(county_info) == 0) {
        showNotification("County not found in database. Please try again.", type = "error", duration = 5)
        values$loading_visible <- FALSE
        return()
      }
      
      values$current_state_fips <- county_info$state_fips
      values$current_county_fips <- county_info$county_fips
      # Since county_display now shows the full name, use it directly
      values$current_location <- paste(input$county_selection, input$state_selection, sep = ", ")
      
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
      updateSelectInput(session, "county_selection", 
                        choices = c("Choose a county..." = ""),
                        selected = "")
      updateSliderInput(session, "year_selection", value = c(2023, 2024))
      updateCheckboxGroupInput(session, "parameters_primary", 
                               selected = c("pH", "Phosphorus", "Turbidity"))
      updateCheckboxGroupInput(session, "parameters_additional", 
                               selected = c())
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
        # Build county code
        county_code <- paste0("US:", values$current_state_fips, ":", values$current_county_fips)
        
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
          countycode         = county_code,
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
        
        values$status <- paste("Fetching data for", values$current_location, "(", county_code, ") -", year_range_text, "- Parameters:", paste(selected_parameters, collapse = ", "))
        
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
          mutate(row_id = row_number()) %>% 
          pivot_wider(names_from = parameter, values_from = value)
        
        values$wide_data <- wq_wide
        
        # Get available sites for selector (ensure uniqueness)
        available_sites <- wq_join %>% 
          distinct(site_id, site_name) %>%
          arrange(site_name) %>%
          # Remove any duplicate site names (keep first occurrence)
          distinct(site_name, .keep_all = TRUE)
        
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
        if ("all" %in% input$site_selection || is.null(input$site_selection)) {
          values$wide_data
        } else {
          values$wide_data %>% filter(site_id %in% input$site_selection)
        }
      }
    })
    
    # Data preview
    output$preview_wide <- DT::renderDataTable({
      data <- filtered_wide_data()
      if (!is.null(data)) {
        DT::datatable(data, options = list(scrollX = TRUE, pageLength = 10))
      }
    })
    
    # Download handler
    output$download_wide <- downloadHandler(
      filename = function() {
        location_safe <- gsub("[^A-Za-z0-9]", "_", values$current_location)
        site_suffix <- if("all" %in% input$site_selection) "all_sites" else "selected_sites"
        paste0("water_quality_", location_safe, "_", site_suffix, "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        data <- filtered_wide_data()
        if (!is.null(data)) {
          write_csv(data, file)
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
      
      # Get dataset name from input
      dataset_name <- input$codap_dataset_name
      if (is.null(dataset_name) || dataset_name == "") {
        dataset_name <- "WaterQualityData"
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
    ## ARCHIVED: AIR QUALITY SERVER LOGIC - Focusing on Water Quality first
    ## To restore: Remove the if(FALSE) wrapper
    # =============================================================================
    if(FALSE) {
    # Update air quality county choices when state changes
    observeEvent(input$air_state_selection, {
      if (input$air_state_selection != "") {
        # Get state FIPS code
        state_info <- states_df[states_df$state_name == input$air_state_selection, ]
        
        if (nrow(state_info) > 0) {
          # Filter counties for this state
          counties_for_state <- fips_clean %>%
            filter(state_fips == state_info$state_fips) %>%
            arrange(county_name)
          
          county_choices <- c("Choose a county..." = "", 
                              setNames(counties_for_state$county_display, counties_for_state$county_display))
          
          # Set default to Knox County if Tennessee is selected
          default_county <- if(input$air_state_selection == "Tennessee") "Knox County" else ""
          
        } else {
          county_choices <- c("State not found" = "")
          default_county <- ""
        }
        
        updateSelectInput(session, "air_county_selection", choices = county_choices, selected = default_county)
      }
    })
    
    # Initialize Knox County for air quality when app loads
    observe({
      if (input$air_state_selection == "Tennessee") {
        isolate({
          state_info <- states_df[states_df$state_name == "Tennessee", ]
          if (nrow(state_info) > 0) {
            counties_for_state <- fips_clean %>%
              filter(state_fips == state_info$state_fips) %>%
              arrange(county_name)
            
            county_choices <- c("Choose a county..." = "", 
                                setNames(counties_for_state$county_display, counties_for_state$county_display))
            
            updateSelectInput(session, "air_county_selection", choices = county_choices, selected = "Knox County")
          }
        })
      }
    })
    
    # Show warning for large year ranges (air quality)
    observeEvent(input$air_year_selection, {
      if (!is.null(input$air_year_selection) && length(input$air_year_selection) == 2) {
        year_range <- input$air_year_selection[2] - input$air_year_selection[1] + 1
        if (year_range > 3) {
          warning_text <- paste("Loading", year_range, "years of air quality data may take 30-90 seconds depending on data availability.")
          showNotification(warning_text, type = "warning", duration = 6)
        }
      }
    })
    
    # Display current air quality selection
    output$air_location_display <- renderText({
      if (input$air_state_selection != "" && input$air_county_selection != "") {
        paste(input$air_county_selection, ",", input$air_state_selection)
      } else {
        "None selected"
      }
    })
    
    # Display air quality FIPS codes  
    output$air_fips_display <- renderText({
      if (input$air_state_selection != "" && input$air_county_selection != "") {
        county_info <- fips_clean %>%
          filter(state_name == input$air_state_selection,
                 county_display == input$air_county_selection)
        
        if (nrow(county_info) > 0) {
          paste("State:", county_info$state_fips, "County:", county_info$county_fips, "Full:", county_info$full_fips)
        } else {
          "Codes not found"
        }
      } else {
        "None selected"
      }
    })
    
    # Air quality data fetching logic
    observeEvent(input$fetch_air_data, {
      
      # Check if RAQSAPI is available
      if (!requireNamespace("RAQSAPI", quietly = TRUE)) {
        showNotification("RAQSAPI package is required. Install with: install.packages('RAQSAPI')", 
                         type = "error", duration = 10)
        return()
      }
      
      # Validate inputs
      if (input$air_state_selection == "" || input$air_county_selection == "") {
        showNotification("Please select both state and county", type = "error", duration = 5)
        return()
      }
      
      # Show loading indicator
      values$air_loading_visible <- TRUE
      
      # Get FIPS codes
      county_info <- fips_clean %>%
        filter(state_name == input$air_state_selection,
               county_display == input$air_county_selection)
      
      if (nrow(county_info) == 0) {
        showNotification("County not found in database. Please try again.", type = "error", duration = 5)
        values$air_loading_visible <- FALSE
        return()
      }
      
      values$air_current_state_fips <- county_info$state_fips
      values$air_current_county_fips <- county_info$county_fips
      values$air_current_location <- paste(input$air_county_selection, input$air_state_selection, sep = ", ")
      
      fetch_air_data()
    })
    
    # Air quality refresh/clear functionality
    observeEvent(input$refresh_air_data, {
      # Reset all air quality reactive values
      values$air_wide_data <- NULL
      values$air_data_fetched <- FALSE
      values$air_status <- "Ready to fetch air quality data..."
      values$air_current_state_fips <- ""
      values$air_current_county_fips <- ""
      values$air_current_location <- ""
      values$air_loading_visible <- FALSE
      values$air_available_sites <- NULL
      
      # Reset air quality input selections
      updateSelectInput(session, "air_state_selection", selected = "")
      updateSelectInput(session, "air_county_selection", 
                        choices = c("Choose a county..." = ""),
                        selected = "")
      updateSliderInput(session, "air_year_selection", value = c(2023, 2024))
      updateCheckboxGroupInput(session, "air_parameters_criteria", 
                               selected = c("88101", "81102", "44201"))
      updateCheckboxGroupInput(session, "air_parameters_additional", 
                               selected = c())
      updateSelectInput(session, "air_site_selection", 
                        choices = c("All sites" = "all"),
                        selected = "all")
      
      showNotification("Air quality interface refreshed and data cleared!", type = "message", duration = 3)
    })
    
    # Air quality data fetching function
    fetch_air_data <- function() {
      
      # Update status
      values$air_status <- "Fetching air quality data from EPA AQS Data Mart..."
      
      tryCatch({
        # Combine parameter selections
        selected_parameters <- c(input$air_parameters_criteria, input$air_parameters_additional)
        
        # Validate parameter selection
        if (is.null(selected_parameters) || length(selected_parameters) == 0) {
          showNotification("Please select at least one air quality parameter", type = "error", duration = 5)
          values$air_loading_visible <- FALSE
          return()
        }
        
        # Validate year selection
        if (is.null(input$air_year_selection) || length(input$air_year_selection) != 2) {
          showNotification("Please select a year range", type = "error", duration = 5)
          values$air_loading_visible <- FALSE
          return()
        }
        
        # Determine start and end date from selected year range
        start_year <- input$air_year_selection[1]
        end_year <- input$air_year_selection[2]
        start_date <- paste0(start_year, "0101")
        end_date <- paste0(end_year, "1231")
        
        # Create year range text
        if (start_year == end_year) {
          year_range_text <- paste("Year", start_year)
        } else {
          year_range_text <- paste("Years", start_year, "-", end_year)
        }
        
        values$air_status <- paste("Fetching data for", values$air_current_location, "-", year_range_text, "- Parameters:", paste(selected_parameters, collapse = ", "))
        
        # Update status to show requests are running
        values$air_status <- paste("Making requests to EPA AQS Data Mart for", values$air_current_location, "for", length(selected_parameters), "parameters...")
        
        # Note: This is a simplified example - in practice you would need AQS API credentials
        # For demonstration, we'll create a placeholder message
        values$air_status <- "Note: AQS API requires user credentials (email/key). Please set up credentials using RAQSAPI::aqs_sign_up() and RAQSAPI::aqs_credentials(). This is a demo interface showing the structure for air quality data access."
        
        # Create placeholder data structure for demo
        demo_data <- data.frame(
          Date = seq.Date(from = as.Date("2023-01-01"), to = as.Date("2023-12-31"), by = "month"),
          Site_ID = "Demo_Site_001",
          Site_Name = paste("Demo Air Quality Monitor -", values$air_current_location),
          Parameter = rep(c("PM2.5", "PM10", "Ozone"), each = 4),
          Value = round(runif(12, 5, 50), 2),
          Units = rep(c("µg/m³", "µg/m³", "ppb"), each = 4),
          stringsAsFactors = FALSE
        )
        
        values$air_wide_data <- demo_data
        values$air_data_fetched <- TRUE
        
        # Get available sites for selector
        available_sites <- data.frame(
          site_id = "Demo_Site_001",
          site_name = paste("Demo Air Quality Monitor -", values$air_current_location),
          stringsAsFactors = FALSE
        )
        
        values$air_available_sites <- available_sites
        
        # Update site selector choices
        site_choices <- c("All sites" = "all", 
                          setNames(available_sites$site_id, available_sites$site_name))
        updateSelectInput(session, "air_site_selection", 
                          choices = site_choices,
                          selected = "all")
        
        values$air_status <- paste("Demo data loaded for", values$air_current_location, "! To access real EPA AQS data, please set up API credentials.")
        
        showNotification("Demo data loaded! For real data, set up AQS API credentials.", type = "message", duration = 5)
        
        # Hide loading indicator
        values$air_loading_visible <- FALSE
        
      }, error = function(e) {
        values$air_status <- paste("Error:", e$message)
        showNotification(paste("Error fetching air quality data:", e$message), type = "error", duration = 8)
        values$air_loading_visible <- FALSE
      })
    }
    
    # Air quality status output
    output$air_status_text <- renderText({
      values$air_status
    })
    
    # Air quality data filtering based on site selection
    filtered_air_data <- reactive({
      if (!is.null(values$air_wide_data)) {
        if ("all" %in% input$air_site_selection || is.null(input$air_site_selection)) {
          values$air_wide_data
        } else {
          values$air_wide_data %>% filter(Site_ID %in% input$air_site_selection)
        }
      }
    })
    
    # Air quality data preview
    output$air_preview_wide <- DT::renderDataTable({
      data <- filtered_air_data()
      if (!is.null(data)) {
        DT::datatable(data, options = list(scrollX = TRUE, pageLength = 10))
      }
    })
    
    # Air quality download handler
    output$download_air_data <- downloadHandler(
      filename = function() {
        location_safe <- gsub("[^A-Za-z0-9]", "_", values$air_current_location)
        site_suffix <- if("all" %in% input$air_site_selection) "all_sites" else "selected_sites"
        paste0("air_quality_", location_safe, "_", site_suffix, "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        data <- filtered_air_data()
        if (!is.null(data)) {
          write_csv(data, file)
        }
      }
    )
    
    # =============================================================================
    # CODAP EXPORT SERVER LOGIC - Air Quality
    # =============================================================================
    
    # observeEvent for "Send to CODAP" button (Air Quality)
    observeEvent(input$send_air_to_codap, {
      # Get the filtered data
      data <- filtered_air_data()
      
      # Validate that data exists
      if (is.null(data) || nrow(data) == 0) {
        showNotification("No data available to send to CODAP. Please fetch air quality data first.", 
                         type = "error", duration = 5)
        return()
      }
      
      # Get dataset name from input
      dataset_name <- input$codap_air_dataset_name
      if (is.null(dataset_name) || dataset_name == "") {
        dataset_name <- "AirQualityData"
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
    } # End if(FALSE) - Air Quality server logic archived

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