# Functions to model the data

genModelForm <- function(varname) {
  #' Generate Model Formulas
  #'
  #' Generate model formulas to use in `compareModel`
  #'
  #' @param varname A character vector of a variable name
  #' @return A list of formulas

  forms <- list(
    "snaive"  = "%s ~ lag(52)",
    "drift"   = "%s ~ drift()",
    "tslm"    = "%s ~ trend() + fourier(period = 'year', K = 2)",
    "ets"     = "%s ~ season(period = 24)", # Max supported period is 24
    "sarima"  = "%s ~ PDQ(period = 52)",
    "arimax"  = "%s ~ PDQ(0, 0, 0) + fourier(period = 'year', K = 2)",
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
      "ARIMAX"  = fable::ARIMA(forms$arimax),
      "Prophet" = fable.prophet::prophet(forms$prophet)
    )

  return(model)
}

castModel <- function(mable, len = 52) {
  #' Forecast models
  #'
  #' Create a forecast from models in a mable
  #'
  #' @param mable A model table, usually the outoput of `compareModel`
  #' @param len The length of forecasted data points
  #' @return A forecast table

  mod_cast <- mable %>% fabletools::forecast(h = len)

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
    dplyr::arrange(group)

  return(mod_eval)
}

