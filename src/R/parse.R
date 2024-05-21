# Functions to parse the dataset

lsData <- function(path = "data/raw", ...) {
  #' List Data
  #'
  #' List all data file within `path` directory
  #'
  #' @param path A path of raw data directory, set to "data/raw" by default
  #' @return A list of complete relative path of each dataset

  filepath <- list.files(path, full.name = TRUE, recursive = TRUE, ...) %>%
    set_names(gsub(x = ., ".*_|\\w+/|\\.\\w*", "")) %>%
    as.list()

  return(filepath)
}

readData <- function(fpath, ..., is_gbd = FALSE) {
  #' Read Data Frame
  #'
  #' Read external tabular data as a tidy data frame
  #'
  #' @param fpath Path name of the file to parse
  #' @inheritDotParams readr::read_csv
  #' @param is_gbd A boolean to indicate whether to treat the input as a GBD
  #' time series
  #' @return A tidy data frame

  tbl <- readr::read_csv(fpath, ...)

  if (is_gbd) {
    tbl %<>%
      dplyr::filter(!grepl(x = Diagnosis, "<5 y.o.")) %>%
      tsibble::tsibble(key = c(Region, Diagnosis), index = Year)
  }

  return(tbl)
}

subsetData <- function(tbl, ts) {
  #' Subset Riskesdas Data
  #'
  #' Subset Riskesdas based on variables available in the GBD time-series.
  #'
  #' @param tbl Riskesdas data
  #' @param ts A GBD time-series
  #' @return A subset tidy data frame

  diagnosis <- unique(ts$Diagnosis)
  sub_tbl   <- tbl %>% subset(.$Diagnosis %in% diagnosis)

  return(sub_tbl)
}
