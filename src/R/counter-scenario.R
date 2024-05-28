# Functions to simulate a counterfactual scenario

projectDiff <- function(ts_aug, res_diff, region = "Indonesia", ref_year = 2018) {
  #' Project Difference
  #'
  #' Project the relative difference between SKI 2023 and Riskesdas 2018 into
  #' GBD data.
  #'
  #' @param ts_aug A table outlining the best-fitting model augmentation
  #' @param res_diff A tidy ime-series containing the test result
  #' @param region The region of interest, can be either Global or Indonesia
  #' @param ref_year Reference year to start the counterfactual scenario. In
  #' interventional analysis term, `ref_year` is the time point where an
  #' intervention/event occurred.
  #' @return A tidy time-series containing the projected relative difference

  # Subset both data frame inputs
  tbl_diff <- res_diff |> subset(select = c(Diagnosis, perc))

  sub_tbl <- ts_aug |>
    tibble::tibble() %>%
    subset(
      grepl(x = .$Region, region) & Year == ref_year,
      select = c(Diagnosis, Prevalence)
    )

  # Project the relative difference of Riskesdas to the GBD data  
  tbl_project <- dplyr::inner_join(tbl_diff, sub_tbl, by = "Diagnosis") |>
    dplyr::mutate("2023" = Prevalence * {perc + 1}) |>
    subset(select = -perc) |>
    set_names(c("Diagnosis", as.character(ref_year), "2023"))

  # Create a time-series object
  ts_project <- tbl_project |>
    tidyr::pivot_longer(
      c("2018", "2023"), names_to = "Year", values_to = "Prevalence"
    ) |>
    dplyr::mutate(Year = as.numeric(Year)) |>
    tsibble::tsibble(key = Diagnosis, index = Year) |>
    dplyr::full_join( # Generate NA for years between 2018 and 2023 for Asthma
      tibble::tibble("Diagnosis" = "Asthma", "Year" = seq(2018, 2023, 1))
    ) |>
    tsibble::fill_gaps(.full = TRUE) |> # Generate NA for other diagnoses
    dplyr::mutate("Prevalence" = imputeTS::na_interpolation(Prevalence))

  return(ts_project)
}

mkScenario <- function(ts_aug, res_diff, region = "Indonesia", ref_year = 2018) {
  #' Make Scenario
  #'
  #' Create a counterfactual scenario based on the relative difference between
  #' SKI 2023 and Riskesdas 2018.
  #'
  #' @param ts_aug A table outlining the best-fitting model augmentation
  #' @param res_diff A tidy ime-series containing the test result
  #' @param region The region of interest, can be either Global or Indonesia
  #' @param ref_year Reference year to start the counterfactual scenario. In
  #' interventional analysis term, `ref_year` is the time point where an
  #' intervention/event occurred.
  #' @return A tidy data frame containing counterfactual scenario

  sub_ts <- ts_aug %>% subset(grepl(x = .$Region, region) & .$Year < ref_year)

  ts_project <- ts_aug |>
    projectDiff(res_diff, region = region, ref_year = ref_year) |>
    dplyr::mutate(.model = "Projected Difference")

  tbl_scenario <- ts_project |>
    dplyr::full_join(sub_ts, by = c("Diagnosis", "Year", "Prevalence", ".model")) |>
    dplyr::group_by(Diagnosis) |>
    dplyr::mutate(
      "Group"  = na.omit(Group)  |> unique(),
      "Region" = na.omit(Region) |> unique()
    ) |>
    dplyr::ungroup()

  return(tbl_scenario)
}

