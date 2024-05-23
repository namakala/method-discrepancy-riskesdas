# Functions to analyze the data

checkTrend <- function(ts, varname) {
  #' Check Trend
  #'
  #' Check the presence of a trend in a time-series data using Mann-Kendall
  #' test.
  #'
  #' @param ts A GBD time-series data
  #' @param varname A time-series variable name
  #' @return A tidy time-series containing the test result

  tbl      <- tibble::tibble(ts)
  tbl_nest <- tbl |> tidyr::nest(.by = c(Region, Diagnosis, Group))

  tbl_trend <- tbl_nest |>
    dplyr::mutate(
      "trend" = purrr::map(
        data, ~ trend::mk.test(.x[[varname]]) |> broom::tidy()
      )
    ) |>
    tidyr::unnest(trend)

  res <- tbl_trend |> subset(select = -c(data, parameter, alternative))

  return(res)
}

getDiff <- function(tbl) {
  #' Get Prevalence Difference
  #'
  #' @param tbl A data frame containing data from Riskesdas/SKI
  #' @return A tidy ime-series containing the test result

  tbl_wide <- tbl |>
    subset(select = -c(Definition, Source, Lower, Upper, Page, Instrument)) |>
    tidyr::pivot_wider(names_from = Year, values_from = c(Prevalence, N, SD))

  res <- tbl_wide |>
    dplyr::mutate(
      diff = {Prevalence_2023 - Prevalence_2018},
      perc = diff / Prevalence_2018,
      t    = diff / sqrt({SD_2018^2 / N_2018} + {SD_2023^2 / N_2023}), # Welch's
      p    = dt(t, df = N_2018 + N_2023 - 2)
    )

  return(res)
}

