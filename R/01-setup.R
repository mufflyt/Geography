#The provided code sets up a data analysis environment in R by loading various packages and setting up directories. Here's a summary of what each section of the code does:
# 
# 1. **Setting Up Packages**: The code starts by setting a seed for reproducibility and loading numerous R packages. These packages are essential for data manipulation, visualization, and geospatial analysis.
# 
# 2. **Setting Up Directories**: It sets the working directory to "~/Dropbox (Personal)/Tannous" using the `here` package. It also defines folders for data, results, figures, and R code using the `here::here()` function. These directories are used to organize and manage data and results.
# 
# 3. **Bespoke Functions**: The code defines several custom functions for specific tasks, including:
#   - `search_by_taxonomy`: A function to search the National Provider Identifier (NPI) Database by taxonomy.
# - `search_and_process_npi`: A memoized function to search and process NPI numbers from a specified input file.
# - `create_geocode`: A memoized function to geocode addresses using the HERE API and update a CSV file with geocoded information.
# - `create_and_save_physician_dot_map`: A function to create and save a dot map of physicians with specified options.
# - `test_and_process_isochrones`: A function to test and process isochrones (areas reachable within a specified time) for given locations.
# - `process_and_save_isochrones`: A function to process and save isochrones for a large dataset in chunks.
# 
# 4. **Example Usage**: The code provides comments and example usage for some of the defined functions, such as `search_and_process_npi`, to demonstrate how to use them.

set.seed(1978)
invisible(gc())

library(hereR)
library(tidyverse)
library(sf)
library(progress)
library(memoise)
library(easyr)
library(data.table)
library(npi)
library(tidyr)
library(leaflet)
library(tigris)
library(ggplot2)
library(censusapi)
library(htmlwidgets)
library(webshot)
library(viridis)
library(wesanderson) # color palettes
library(mapview)
library(shiny) # creation of GUI, needed to change leaflet layers with dropdowns
library(htmltools) # added for saving html widget
devtools::install_github('ramnathv/htmlwidgets')
library(readxl)
library(leaflet.extras)
library(leaflet.minicharts)
library(formattable)
library(tidycensus)
library(rnaturalearth)
library(purrr)
library(stringr)
library(exploratory)
library(humaniformat)
library(ggplot2)
library(ggthemes)
library(maps)

# Store tidycensus data on cache
options(tigris_use_cache = TRUE)

Sys.setenv(HERE_API_KEY = "VnDX-Rafqchcmb4LUDgEpYlvk8S1-LCYkkrtb1ujOrM")
readRenviron("~/.Renviron")
hereR::set_key("VnDX-Rafqchcmb4LUDgEpYlvk8S1-LCYkkrtb1ujOrM")

#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####
#####  Directory
#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####
#here::set_here(path = ".", verbose = TRUE)
setwd("~/Dropbox (Personal)/Tannous")
here::i_am(path = "Tannous.Rproj")
data_folder <- here::here("data")
results_folder <- here::here("results")
images_folder <- here::here("figures")
code_folder <- here::here("R")

########### Bespoke Functions ----
#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####
#####  Functions for nomogram
#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####
`%nin%`<-Negate(`%in%`)

#' Search NPI Database by Taxonomy
search_by_taxonomy <- function(taxonomy_to_search) {
  # Create an empty data frame to store search results
  data <- data.frame()

  # Loop over each taxonomy description
  for (taxonomy in taxonomy_to_search) {
    tryCatch({
      # Perform the search for the current taxonomy
      result <- npi::npi_search(
        taxonomy_description = taxonomy,
        country_code = "US",
        enumeration_type = "ind",
        limit = 1200
      )

      if (!is.null(result)) {
        # Process and filter the data for the current taxonomy
        data_taxonomy <- npi::npi_flatten(result) %>%
          dplyr::distinct(npi, .keep_all = TRUE) %>%
          dplyr::mutate(search_term = taxonomy) %>%
          dplyr::filter(addresses_country_name == "United States") %>%
          dplyr::mutate(basic_credential = stringr::str_remove_all(basic_credential, "[[\\p{P}][\\p{S}]]")) %>%
          dplyr::filter(stringr::str_to_lower(basic_credential) %in% stringr::str_to_lower(c("MD", "DO"))) %>%
          dplyr::arrange(basic_last_name) %>%
          dplyr::filter(stringr::str_detect(taxonomies_desc, taxonomy)) %>%
          dplyr::select(-basic_credential, -basic_last_updated, -basic_status, -basic_name_prefix, -basic_name_suffix, -basic_certification_date, -other_names_type, -other_names_code, -other_names_credential, -other_names_first_name, -other_names_last_name, -other_names_prefix, -other_names_suffix, -other_names_middle_name, -identifiers_code, -identifiers_desc, -identifiers_identifier, -identifiers_state, -identifiers_issuer, -taxonomies_code, -taxonomies_taxonomy_group, -taxonomies_state, -taxonomies_license, -addresses_country_code, -addresses_country_name, -addresses_address_purpose, -addresses_address_type, -addresses_address_2, -addresses_fax_number, -endpoints_endpointType, -endpoints_endpointTypeDescription, -endpoints_endpoint, -endpoints_affiliation, -endpoints_useDescription, -endpoints_contentTypeDescription, -endpoints_country_code, -endpoints_country_name, -endpoints_address_type, -endpoints_address_1, -endpoints_city, -endpoints_state, -endpoints_postal_code, -endpoints_use, -endpoints_endpointDescription, -endpoints_affiliationName, -endpoints_contentType, -endpoints_contentOtherDescription, -endpoints_address_2, -endpoints_useOtherDescription) %>%
          dplyr::distinct(npi, .keep_all = TRUE) %>%
          dplyr::distinct(basic_first_name, basic_last_name, basic_middle_name, basic_sole_proprietor, basic_gender, basic_enumeration_date, addresses_state, .keep_all = TRUE) %>%
          dplyr::mutate(full_name = paste(
            stringr::str_to_lower(basic_first_name),
            stringr::str_to_lower(basic_last_name)
          ))

        # Append the data for the current taxonomy to the main data frame
        data <- dplyr::bind_rows(data, data_taxonomy)
      }
    }, error = function(e) {
      message(sprintf("Error in search for %s:\n%s", taxonomy, e$message))
    })
  }

  # Write the combined data frame to an RDS file
  filename <- paste("data/search_taxonomy", format(Sys.time(), format = "%Y-%m-%d_%H-%M-%S"), ".rds", sep = "_")
  readr::write_rds(data, filename)

  return(data)
}


print("Setup is complete!")




##############################
###############################
#' Search and Process NPI Numbers
# Define a memoization function for search_and_process_npi

search_and_process_npi <- memoise(function(input_file,
                                           enumeration_type = "ind",
                                           limit = 5L,
                                           country_code = "US",
                                           filter_credentials = c("MD", "DO")) {

  cat("Starting search_and_process_npi...\n")

  # Check if the input file exists
  if (!file.exists(input_file)) {
    stop(
      "The specified file with the NAMES to search'", input_file, "' does not exist.\n",
      "Please provide the full path to the file."
    )
  }
  cat("Input file found.\n")

  # Read data from the input file
  file_extension <- tools::file_ext(input_file)

  if (file_extension == "rds") {
    data <- readRDS(input_file)
  } else if (file_extension %in% c("csv", "xls", "xlsx")) {
    if (file_extension %in% c("xls", "xlsx")) {
      data <- readxl::read_xlsx(input_file)
    } else {
      data <- readr::read_csv(input_file)
    }
  } else {
    stop("Unsupported file format. Please provide an RDS, CSV, or XLS/XLSX file of NAMES to search.")
  }
  cat("Data loaded from the input file.\n")

  first_names <- data$first
  last_names <- data$last

  # Define the list of taxonomies to filter
  vc <- c("Allergy & Immunology", "Allergy & Immunology, Allergy", "Anesthesiology", "Anesthesiology, Critical Care Medicine", "Anesthesiology, Hospice and Palliative Medicine", "Anesthesiology, Pain Medicine", "Advanced Practice Midwife", "Colon & Rectal Surgery", "Dermatology", "Dermatology, Clinical & Laboratory Dermatological Immunology", "Dermatology, Dermatopathology", "Dermatology, MOHS-Micrographic Surgery", "Dermatology, Pediatric Dermatology", "Dermatology, Procedural Dermatology", "Doula", "Emergency Medicine", "Emergency Medicine, Emergency Medical Services", "Emergency Medicine, Hospice and Palliative Medicine", "Emergency Medicine, Medical Toxicology", "Emergency Medicine, Pediatric Emergency Medicine", "Emergency Medicine, Undersea and Hyperbaric Medicine", "Family Medicine", "Family Medicine, Addiction Medicine", "Family Medicine, Adolescent Medicine", "Family Medicine, Adult Medicine", "Family Medicine, Geriatric Medicine", "Family Medicine, Hospice and Palliative Medicine", "Family Medicine, Sports Medicine", "Internal Medicine", "Internal Medicine, Addiction Medicine", "Internal Medicine, Adolescent Medicine", "Internal Medicine, Advanced Heart Failure and Transplant Cardiology", "Internal Medicine, Allergy & Immunology", "Internal Medicine, Bariatric Medicine", "Internal Medicine, Cardiovascular Disease", "Internal Medicine, Clinical Cardiac Electrophysiology", "Internal Medicine, Critical Care Medicine", "Internal Medicine, Endocrinology, Diabetes & Metabolism", "Internal Medicine, Gastroenterology", "Internal Medicine, Geriatric Medicine", "Internal Medicine, Hematology", "Internal Medicine, Hematology & Oncology", "Internal Medicine, Hospice and Palliative Medicine", "Internal Medicine, Hypertension Specialist", "Internal Medicine, Infectious Disease", "Internal Medicine, Interventional Cardiology", "Internal Medicine, Medical Oncology", "Internal Medicine, Nephrology", "Internal Medicine, Pulmonary Disease", "Internal Medicine, Rheumatology", "Internal Medicine, Sleep Medicine", "Internal Medicine, Sports Medicine", "Lactation Consultant, Non-RN", "Medical Genetics, Clinical Biochemical Genetics", "Medical Genetics, Clinical Genetics (M.D.)", "Medical Genetics, Ph.D. Medical Genetics", "Midwife", "Nuclear Medicine", "Neuromusculoskeletal Medicine, Sports Medicine", "Neuromusculoskeletal Medicine & OMM", "Nuclear Medicine, Nuclear Cardiology", "Obstetrics & Gynecology", "Obstetrics & Gynecology, Complex Family Planning", "Obstetrics & Gynecology, Critical Care Medicine", "Obstetrics & Gynecology, Gynecologic Oncology", "Obstetrics & Gynecology, Gynecology", "Obstetrics & Gynecology, Hospice and Palliative Medicine", "Obstetrics & Gynecology, Maternal & Fetal Medicine", "Obstetrics & Gynecology, Obstetrics", "Obstetrics & Gynecology, Reproductive Endocrinology", "Ophthalmology", "Ophthalmology, Cornea and External Diseases Specialist", "Ophthalmology, Glaucoma Specialist", "Ophthalmology, Ophthalmic Plastic and Reconstructive Surgery", "Ophthalmology, Pediatric Ophthalmology and Strabismus Specialist", "Ophthalmology, Retina Specialist", "Oral & Maxillofacial Surgery", "Orthopaedic Surgery", "Orthopaedic Surgery, Adult Reconstructive Orthopaedic Surgery", "Orthopaedic Surgery, Foot and Ankle Surgery", "Orthopaedic Surgery, Hand Surgery", "Orthopaedic Surgery, Orthopaedic Surgery of the Spine", "Orthopaedic Surgery, Orthopaedic Trauma", "Orthopaedic Surgery, Pediatric Orthopaedic Surgery", "Orthopaedic Surgery, Sports Medicine", "Otolaryngology, Facial Plastic Surgery", "Otolaryngology, Otolaryngic Allergy", "Otolaryngology, Otolaryngology/Facial Plastic Surgery", "Otolaryngology, Otology & Neurotology", "Otolaryngology, Pediatric Otolaryngology", "Otolaryngology, Plastic Surgery within the Head & Neck", "Pain Medicine, Interventional Pain Medicine", "Pain Medicine, Pain Medicine", "Pathology, Anatomic Pathology", "Pathology, Anatomic Pathology & Clinical Pathology", "Pathology, Anatomic Pathology & Clinical Pathology", "Pathology, Blood Banking & Transfusion Medicine")

  bc <- c("Pathology, Chemical Pathology", "Pathology, Clinical Laboratory Director, Non-physician", "Pathology, Clinical Pathology", "Pathology, Clinical Pathology/Laboratory Medicine", "Pathology, Cytopathology", "Pathology, Dermatopathology", "Pathology, Forensic Pathology", "Pathology, Hematology", "Pathology, Medical Microbiology", "Pathology, Molecular Genetic Pathology", "Pathology, Neuropathology", "Pediatrics", "Pediatrics, Adolescent Medicine", "Pediatrics, Clinical & Laboratory Immunology", "Pediatrics, Child Abuse Pediatrics", "Pediatrics, Developmental - Behavioral Pediatrics", "Pediatrics, Hospice and Palliative Medicine", "Pediatrics, Neonatal-Perinatal Medicine", "Pediatrics, Neurodevelopmental Disabilities", "Pediatrics, Pediatric Allergy/Immunology", "Pediatrics, Pediatric Cardiology", "Pediatrics, Pediatric Critical Care Medicine", "Pediatrics, Pediatric Emergency Medicine", "Pediatrics, Pediatric Endocrinology", "Pediatrics, Pediatric Gastroenterology", "Pediatrics, Pediatric Hematology-Oncology", "Pediatrics, Pediatric Infectious Diseases", "Pediatrics, Pediatric Nephrology", "Pediatrics, Pediatric Pulmonology", "Pediatrics, Pediatric Rheumatology", "Pediatrics, Sleep Medicine", "Physical Medicine & Rehabilitation, Neuromuscular Medicine", "Physical Medicine & Rehabilitation, Pain Medicine", "Physical Medicine & Rehabilitation", "Physical Medicine & Rehabilitation, Pediatric Rehabilitation Medicine", "Physical Medicine & Rehabilitation, Spinal Cord Injury Medicine", "Physical Medicine & Rehabilitation, Sports Medicine", "Plastic Surgery", "Plastic Surgery, Plastic Surgery Within the Head and Neck", "Plastic Surgery, Surgery of the Hand", "Preventive Medicine, Aerospace Medicine", "Preventive Medicine, Obesity Medicine", "Preventive Medicine, Occupational Medicine", "Preventive Medicine, Preventive Medicine/Occupational Environmental Medicine", "Preventive Medicine, Undersea and Hyperbaric Medicine", "Preventive Medicine, Public Health & General Preventive Medicine", "Psychiatry & Neurology, Addiction Medicine", "Psychiatry & Neurology, Addiction Psychiatry", "Psychiatry & Neurology, Behavioral Neurology & Neuropsychiatry", "Psychiatry & Neurology, Brain Injury Medicine", "Psychiatry & Neurology, Child & Adolescent Psychiatry", "Psychiatry & Neurology, Clinical Neurophysiology", "Psychiatry & Neurology, Forensic Psychiatry", "Psychiatry & Neurology, Geriatric Psychiatry", "Psychiatry & Neurology, Neurocritical Care", "Psychiatry & Neurology, Neurology", "Psychiatry & Neurology, Neurology with Special Qualifications in Child Neurology", "Psychiatry & Neurology, Psychiatry", "Psychiatry & Neurology, Psychosomatic Medicine", "Psychiatry & Neurology, Sleep Medicine", "Psychiatry & Neurology, Vascular Neurology", "Radiology, Body Imaging", "Radiology, Diagnostic Neuroimaging", "Radiology, Diagnostic Radiology", "Radiology, Diagnostic Ultrasound", "Radiology, Neuroradiology", "Radiology, Nuclear Radiology", "Radiology, Pediatric Radiology", "Radiology, Radiation Oncology", "Radiology, Vascular & Interventional Radiology", "Specialist", "Surgery", "Surgery, Pediatric Surgery", "Surgery, Plastic and Reconstructive Surgery", "Surgery, Surgery of the Hand", "Surgery, Surgical Critical Care", "Surgery, Surgical Oncology", "Surgery, Trauma Surgery", "Surgery, Vascular Surgery", "Urology", "Urology, Female Pelvic Medicine and Reconstructive Surgery", "Urology, Pediatric Urology","Pathology", "Thoracic Surgery (Cardiothoracic Vascular Surgery)" , "Transplant Surgery")

  # Create a function to search NPI based on first and last names
  search_npi <- function(first_name, last_name) {
    cat("Searching NPI for:", first_name, last_name, "\n")
    tryCatch(
      {
        # NPI search object
        npi_obj <- npi::npi_search(first_name = first_name, last_name = last_name)

        # Retrieve basic and taxonomy data from npi objects
        t <- npi::npi_flatten(npi_obj, cols = c("basic", "taxonomies"))

        # Subset results with taxonomy that matches taxonomies in the lists
        t <- t %>% dplyr::filter(taxonomies_desc %in% vc | taxonomies_desc %in% bc)
      },
      error = function(e) {
        cat("ERROR:", conditionMessage(e), "\n")
        return(NULL)  # Return NULL for error cases
      }
    )
    return(t)
  }

  # Create an empty list to receive the data
  out <- list()

  # Initialize progress bar
  total_names <- length(first_names)
  pb <- progress::progress_bar$new(total = total_names)

  # Search NPI for each name in the input data
  out <- purrr::map2(first_names, last_names, function(first_name, last_name) {
    pb$tick()
    search_npi(first_name, last_name)
  })

  # Filter npi_data to keep only elements that are data frames
  npi_data <- Filter(is.data.frame, out)

  # Combine multiple data frames into a single data frame using data.table::rbindlist()
  result <- data.table::rbindlist(npi_data, fill = TRUE)

  return(result)
})

# Example usage:
# input_file <- "data-raw/acog_presidents.csv"
# output_result <- search_and_process_npi(input_file)
# readr::write_csv(output_result, "results_of_search_and_process_npi.csv")


##############################
###############################
##########################################################################
## Geocode
# Memoized version of create_geocode
create_geocode <- memoise::memoise(function(csv_file) {
  # Set your HERE API key
  api_key <- "VnDX-Rafqchcmb4LUDgEpYlvk8S1-LCYkkrtb1ujOrM"
  hereR::set_key(api_key)

  # Check if the CSV file exists
  if (!file.exists(csv_file)) {
    stop("CSV file not found.")
  }

  # Read the CSV file into a data frame
  data <- read.csv(csv_file)

  # Check if the data frame contains a column named "address"
  if (!"address" %in% colnames(data)) {
    stop("The CSV file must have a column named 'address' for geocoding.")
  }

  # Initialize a list to store geocoded results
  geocoded_results <- list()

  # Initialize progress bar
  pb <- progress_bar$new(total = nrow(data), format = "[:bar] :percent :elapsed :eta :rate")

  # Loop through each address and geocode it
  for (i in 1:nrow(data)) {
    address <- data[i, "address"]
    result <- hereR::geocode(address)
    geocoded_results[[i]] <- result
    cat("Geocoded address ", i, " of ", nrow(data), "\n")
    pb$tick()  # Increment the progress bar
  }

  # Combine all geocoded results into one sf object
  geocoded <- do.call(rbind, geocoded_results)

  # Add the geocoded information to the original data frame
  data$latitude <- geocoded$latitude
  data$longitude <- geocoded$longitude

  # Write the updated data frame with geocoded information back to a CSV file
  write.csv(data, csv_file, row.names = FALSE)
  cat("Updated CSV file with geocoded information.\n")

  cat("Geocoding complete.\n")

  return(geocoded)
})

##############################
###############################
create_and_save_physician_dot_map <- function(physician_data, jitter_range = 0.05, color_palette = "magma", popup_var = "name") {
  # Add jitter to latitude and longitude coordinates
  jittered_physician_data <- physician_data %>%
    dplyr::mutate(
      lat = lat + runif(n()) * jitter_range,
      long = long + runif(n()) * jitter_range
    )

  # Create a base map using tyler::create_base_map()
  cat("Setting up the base map...\n")
  base_map <- tyler::create_base_map("Physician Dot Map")
  cat("Map setup complete.\n")

  # Generate ACOG districts using tyler::generate_acog_districts_sf()
  cat("Generating the ACOG district boundaries from tyler::generate_acog_districts_sf...\n")
  acog_districts <- tyler::generate_acog_districts_sf()

  # Define the number of ACOG districts
  num_acog_districts <- 11

  # Create a custom color palette using viridis
  district_colors <- viridis::viridis(num_acog_districts, option = color_palette)

  # Reorder factor levels
  jittered_physician_data$ACOG_District <- factor(
    jittered_physician_data$ACOG_District,
    levels = c("District I", "District II", "District III", "District IV", "District V",
               "District VI", "District VII", "District VIII", "District IX",
               "District XI", "District XII"))

  # Create a Leaflet map
  dot_map <- base_map %>%
    # Add physician markers
    leaflet::addCircleMarkers(
      data = jittered_physician_data,
      lng = ~long,
      lat = ~lat,
      radius = 3,         # Adjust the radius as needed
      stroke = TRUE,      # Add a stroke (outline)
      weight = 1,         # Adjust the outline weight as needed
      color = district_colors[as.numeric(physician_data$ACOG_District)],   # Set the outline color to black
      fillOpacity = 0.8,  # Fill opacity
      popup = as.formula(paste0("~", popup_var))  # Popup text based on popup_var argument
    ) %>%
    # Add ACOG district boundaries
    leaflet::addPolygons(
      data = acog_districts,
      color = "red",      # Boundary color
      weight = 2,         # Boundary weight
      fill = FALSE,       # No fill
      opacity = 0.8,      # Boundary opacity
      popup = ~ACOG_District   # Popup text
    ) %>%
    # Add a legend
    leaflet::addLegend(
      position = "bottomright",   # Position of the legend on the map
      colors = district_colors,   # Colors for the legend
      labels = levels(physician_data$ACOG_District),   # Labels for legend items
      title = "ACOG Districts"   # Title for the legend
    )

  # Generate a timestamp
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

  # Define file names with timestamps
  html_file <- paste0("figures/dot_map_", timestamp, ".html")
  png_file <- paste0("figures/dot_map_", timestamp, ".png")

  # Save the Leaflet map as an HTML file
  htmlwidgets::saveWidget(widget = dot_map, file = html_file, selfcontained = TRUE)
  cat("Leaflet map saved as HTML:", html_file, "\n")

  # Capture and save a screenshot as PNG
  webshot::webshot(html_file, file = png_file)
  cat("Screenshot saved as PNG:", png_file, "\n")

  # Return the Leaflet map
  return(dot_map)
}

##############################
###############################
#***************
test_and_process_isochrones <- function(input_file) {
  input_file <- input_file %>%
    mutate(id = row_number()) %>%
    filter(postmastr.name.x != "Hye In Park, MD")

  input_file$lat <- as.numeric(input_file$lat)
  input_file$long <- as.numeric(input_file$long)

  input_file_sf <- input_file %>%
    st_as_sf(coords = c("long", "lat"), crs = 4326)

  posix_time <- as.POSIXct("2023-10-20 09:00:00", format = "%Y-%m-%d %H:%M:%S")
  # Here are the dates for the third Friday in October from 2013 to 2022:
  # October 18, 2013
  # October 17, 2014
  # October 16, 2015
  # October 21, 2016
  # October 20, 2017
  # October 19, 2018
  # October 18, 2019
  # October 16, 2020
  # October 15, 2021
  # October 21, 2022

  error_rows <- vector("list", length = nrow(input_file_sf))

  for (i in 1:nrow(input_file_sf)) {
    row_data <- input_file_sf[i, ]

    isochrones <- tryCatch(
      {
        hereR::isoline(
          poi = row_data,
          range = c(1),
          datetime = posix_time,
          routing_mode = "fast",
          range_type = "time",
          transport_mode = "car",
          url_only = FALSE,
          optimize = "balanced",
          traffic = TRUE,
          aggregate = FALSE
        )
      },
      error = function(e) {
        message("Error processing row ", i, ": ", e$message)
        return(NULL)
      }
    )

    if (is.null(isochrones)) {
      error_rows[[i]] <- i
    }
  }

  # Collect the rows that caused errors
  error_rows <- unlist(error_rows, use.names = FALSE)

  if (length(error_rows) > 0) {
    message("Rows with errors: ", paste(error_rows, collapse = ", "))
  } else {
    message("No errors found.")
  }
}

##############################
###############################
process_and_save_isochrones <- function(input_file, chunk_size = 25) {
  input_file <- input_file %>%
    dplyr::mutate(id = dplyr::row_number()) %>%
    dplyr::filter(postmastr.name.x != "Hye In Park, MD")

  input_file$lat <- as.numeric(input_file$lat)
  input_file$long <- as.numeric(input_file$long)

  input_file_sf <- input_file %>%
    sf::st_as_sf(coords = c("long", "lat"), crs = 4326)

  posix_time <- as.POSIXct("2023-10-20 09:00:00", format = "%Y-%m-%d %H:%M:%S")

  num_chunks <- ceiling(nrow(input_file_sf) / chunk_size)
  isochrones_list <- list()

  for (i in 1:num_chunks) {
    start_idx <- (i - 1) * chunk_size + 1
    end_idx <- min(i * chunk_size, nrow(input_file_sf))
    chunk_data <- input_file_sf[start_idx:end_idx, ]

    isochrones <- tryCatch(
      {
        hereR::isoline(
          poi = chunk_data,
          range = c(1800, 3600, 7200, 10800),
          datetime = posix_time,
          routing_mode = "fast",
          range_type = "time",
          transport_mode = "car",
          url_only = FALSE,
          optimize = "balanced",
          traffic = TRUE,
          aggregate = FALSE
        )
      },
      error = function(e) {
        message("Error processing chunk ", i, ": ", e$message)
        return(NULL)
      }
    )

    if (!is.null(isochrones)) {
      # Create the file name with the current date and time
      current_datetime <- format(Sys.time(), "%Y%m%d%H%M%S")

      file_name <- paste("data/isochrones/isochrones_", current_datetime, "_chunk_", min(chunk_data$id), "_to_", max(chunk_data$id))

      # Assuming "arrival" field is originally in character format with both date and time
      # Convert it to a DateTime object
      isochrones$arrival <- as.POSIXct(isochrones$arrival, format = "%Y-%m-%d %H:%M:%S")

      # Save the data as a shapefile with the layer name "isochrones"
      sf::st_write(
        isochrones,
        dsn = file_name,
        layer = "isochrones",
        driver = "ESRI Shapefile",
        quiet = FALSE
      )

      # Store the isochrones in the list
      isochrones_list[[i]] <- isochrones
    }
  }

  # Combine all isochrones from the list into one data frame
  isochrones_data <- do.call(rbind, isochrones_list)

  return(isochrones_data)
}


##############################
###############################


