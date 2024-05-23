# Functions to model the data

splitTs <- function(ts, ratio = 0.2, recent = NULL) {
  #' Split Time-Series
  #'
  #' Split the time-series into training and testing dataset based on the ratio
  #'
  #' @param ts A time series dta frame, will accept a `tsibble` object
  #' @param recent A date for specifying the split
  #' @param ratio The testing:training ratio, set to 0.2 by default
  #' @return A list containing training and testing dataset

  # Date of the most recent dataset
  if (is.null(recent)) {
    dates  <- ts$Year %>% unique()
    loc    <- floor(ratio * length(dates))
    recent <- dates %>% extract2(length(.) - loc)
  }

  # Subset the dataset
  sub_ts <- list(
    "past"   = ts %>% subset(.$Year <= recent),
    "recent" = ts %>% subset(.$Year >  recent)
  )

  return(sub_ts)

}

genModelForm <- function(varname) {
  #' Generate Model Formulas
  #'
  #' Generate model formulas to use in `compareModel`
  #'
  #' @param varname A character vector of a variable name
  #' @return A list of formulas

  forms <- list(
    "snaive"  = "%s ~ lag(4)",
    "drift"   = "%s ~ drift()",
    "tslm"    = "%s ~ trend()",
    "ets"     = "%s ~ season(period = 4)",
    "sarima"  = "%s ~ PDQ(period = 4)",
    "prophet" = "%s ~ season(period = 'year', order = 2)"
  ) %>%
    lapply(\(form) sprintf(form, varname) %>% formula())

  return(forms)
}

compareModel <- function(ts, y, split = NULL, ...) {
  #' Compare Models
  #'
  #' Fit Multiple Models for Comparison
  #'
  #' @param ts A time series data frame, will accept a `tsibble` object
  #' @param y The variable to fit
  #' @param split A list containing parameters to pass on to `splitTs`, support
  #' either `recent` (date object) or `ratio` (0 $\leq$ ratio $\leq$ 1)
  #' @return A mable object (model table)
  require("tsibble")

  # Get variable name with englue then generate model formulas
  varname <- rlang::englue("{{ y }}")
  forms   <- genModelForm(varname)

  # Switcher to perform a rolling-window cross validation or data splitting
  if (!is.null(split)) {
    ratio   <-  split$ratio
    recent  <-  split$recent
    id      <-  split$id %>% {ifelse(is.null(.), "past", .)}
    ts     %<>% splitTs(recent = recent, ratio = ratio) %>% extract2(id)
  }

  if (hasArg(.init) & hasArg(.step)) {
    ts %<>% tsibble::stretch_tsibble(...)
  }

  # Fit multiple models as a mable
  model <- ts %>%
    fabletools::model(
      "Mean"    = fable::MEAN({{ y }}),
      "Naive"   = fable::NAIVE({{ y }}),
      "SNaive"  = fable::SNAIVE(forms$snaive),
      "Drift"   = fable::RW(forms$drift),
      "OLS"     = fable::TSLM(forms$tslm),
      "ETS"     = fable::ETS(forms$ets),
      "ARIMA"   = fable::ARIMA({{ y }}),
      "SARIMA"  = fable::ARIMA(forms$sarima),
      "Prophet" = fable.prophet::prophet(forms$prophet)
    )

  return(model)
}

castModel <- function(mable, y, len = 52) {
  #' Forecast models
  #'
  #' Create a forecast from models in a mable
  #'
  #' @param mable A model table, usually the outoput of `compareModel`
  #' @param y The fitted variable to calculate confidence intervals
  #' @param len The length of forecasted data points
  #' @return A forecast table

  mod_cast <- mable %>%
    fabletools::forecast(h = len) %>%
    dplyr::mutate("ci" = fabletools::hilo({{ y }}, 95))

  return(mod_cast)
}

evalModel <- function(mod_cast, ts) {
  #' Evaluate Comparative Models
  #'
  #' Evaluate comparative models provided by the `compareModel` function
  #'
  #' @param mod_cast A model forecast
  #' @param ts A time-series data used to evaluate the model. To calculate MASE
  #' and RMSSE, it is required to use the whole dataset (training + testing).
  #' @return A table containing model goodness of fit
  require("fabletools")

  mod_eval <- mod_cast %>%
    fabletools::accuracy(
      ts,
      list(
        "MAE"  = fabletools::MAE,
        "RMSE" = fabletools::RMSE,
        "MAPE" = fabletools::MAPE,
        "MASE" = fabletools::MASE,
        "RMSSE" = fabletools::RMSSE,
        "Winkler" = fabletools::winkler_score, 
        "QS"      = fabletools::quantile_score,
        "CRPS"    = fabletools::CRPS,
        "Skill"   = fabletools::skill_score(CRPS)
      )
    ) %>%
    dplyr::arrange(Region, Diagnosis)

  return(mod_eval)
}

selectModel <- function(mod_eval) {
  #' Select Model
  #'
  #' Select model based on evaluation metrics
  #'
  #' @param mod_eval A table containing model goodness of fit
  #' @return A table outlining the best-fitting model

  tbl <- mod_eval %>%
    tidyr::nest(.by = c(Region, Diagnosis))

  tbl_gof <- tbl %>%
    dplyr::mutate(
      "Model" = purrr::map(data, ~ .x$.model),
      "Skill" = purrr::map(data, ~ .x$Skill),
      "gof"   = purrr::map(data, ~ subset(.x, select = c(MAE:CRPS))),
      "rank"  = purrr::map(gof,  ~ sapply(.x, rank) %>% rowSums())
    )

  best_fit <- tbl_gof %>%
    tidyr::unnest(c(Model, Skill, gof, rank)) %>%
    dplyr::group_by(Region, Diagnosis) %>%
    dplyr::slice_min(rank) %>%
    dplyr::slice_head(n = 1) %>%
    subset(select = -data)

  return(best_fit)
}

selectForecast <- function(mod_cast, best_fit) {
  #' Select Forecast
  #'
  #' Select forecast from the best-fitting model.
  #'
  #' @param mod_cast A forecast table
  #' @param best_fit A table outlining the best-fitting model
  #' @return A table outlining the best-fitting forecast

  best_cast <- mod_cast %>%
    dplyr::right_join(
      best_fit,
      by = c(
        "Region"    = "Region",
        "Diagnosis" = "Diagnosis",
        ".model"    = "Model"
      )
    )

  return(best_cast)
}

augmentModel <- function(mod, ts, best_cast) {
  #' Augment Model
  #'
  #' Augment the model with previous observation and its forecast. Return only
  #' the best-fitting model.
  #'
  #' @param mod A mable object
  #' @param ts A GBD time-series
  #' @param best_cast A table outlining the best-fitting forecast
  #' @return A table outlining the best-fitting model augmentation

  # Augment the model to its training data
  tbl <- mod %>% fabletools::augment() %>% tibble::tibble()

  # Subset to best-fitting model only
  best_mod <- best_cast %>%
    subset(select = c("Region", "Diagnosis", ".model")) %>%
    unique()

  groups <- subset(ts, select = c(Diagnosis, Group)) %>% unique()

  sub_tbl <- tbl %>%
    dplyr::right_join(best_mod)

  # Construct the forecast table
  tbl_cast <- best_cast %>%
    tibble::tibble() %>%
    dplyr::mutate("hi" = ci$upper, "lo" = ci$lower) %>%
    subset(select = c(Region:Year, .mean, hi, lo)) %>%
    dplyr::rename("Prevalence" = ".mean")

  # Bind all relevant fields
  best_aug <- sub_tbl %>%
    dplyr::full_join(
      tbl_cast,
      by = c(
        "Region"     = "Region",
        "Diagnosis"  = "Diagnosis",
        ".model"     = ".model",
        "Prevalence" = "Prevalence",
        "Year"       = "Year"
      )
    ) %>%
    dplyr::arrange(Region, Diagnosis, Year) %>%
    dplyr::left_join(groups) %>%
    tsibble::tsibble(key = c(Region, Diagnosis), index = Year)

  return(best_aug)
}

