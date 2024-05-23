# Load packages
pkgs <- c("magrittr", "targets", "tarchetypes", "crew")
pkgs_load <- sapply(pkgs, library, character.only = TRUE)

# Source user-defined functions
funs <- list.files("src/R", pattern = "*.R", full.name = TRUE) %>%
  lapply(source)

# Set option for targets
tar_option_set(
  packages   = pkgs,
  error      = "continue",
  memory     = "transient",
  controller = crew_controller_local(worker = 4),
  storage    = "worker",
  retrieval  = "worker",
  garbage_collection = TRUE
)

seed <- 1810

# Set paths for the raw data
raws <- lsData(pattern = "*csv")

# Set the analysis pipeline
list(

  # List data files
  tar_target(file_tbl, raws$data, format = "file"),
  tar_target(file_ts, raws$gbd, format = "file"),

  # Read the data frame
  tar_target(tbl, readData(file_tbl)),
  tar_target(ts,  readData(file_ts, is_gbd = TRUE)),
  tar_target(sub_tbl, subsetData(tbl, ts)),

  # Plot the GBD time series
  tar_target(plt_dot,  vizDot(ts, "Prevalence", scales = "free_y", nrow = 3)),
  tar_target(plt_acf,  vizAutocor(ts, "Prevalence", type = "ACF")),
  tar_target(plt_pacf, vizAutocor(ts, "Prevalence", type = "PACF")),

  # Assess trend in the GBD time series
  tar_target(res_trend, checkTrend(ts, "Prevalence")),

  # Evaluate the difference between SKI 2023 and Riskesdas 2018
  tar_target(res_diff, getDiff(sub_tbl)),

  # Apply rolling cross validation to select the best-fitting model
  tar_target(mod, compareModel(ts, Prevalence, split = list("recent" = "2015"), .init = 4, step = 1)),
  tar_target(mod_cast, castModel(mod, Prevalence, len = 4)),
  tar_target(mod_eval, evalModel(mod_cast, ts)),

  # Refit models for an interrupted time-series analysis, now use all dataset and without cross validation
  tar_target(mod_its, compareModel(ts, Prevalence)),
  tar_target(mod_cast_its, castModel(mod_its, Prevalence, len = 4)),

  # Select the best-fitting model and forecast
  tar_target(best_fit, selectModel(mod_eval)),
  tar_target(best_cast, selectForecast(mod_cast_its, best_fit)),

  # Augment the GBD dataset with its forecast
  tar_target(ts_aug, augmentModel(mod_its, ts, best_cast)),
  tar_target(plt_dot_aug, vizDotAug(ts_aug, "Prevalence", scales = "free_y", nrow = 3)),

  # Generate documentation
  tar_quarto(readme, "README.qmd", priority = 0)

)
