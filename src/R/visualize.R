# Functions to visualize the dataset

genColor <- function() {
  #' Generate Color Palette
  #'
  #' Generate the color palette to use when plotting
  #'
  #' @return A named list of color palette
  col_palette <- list(
    "black"  = "#2E3440",
    "white"  = "#ECEFF4",
    "red"    = "#BF616A",
    "blue"   = "#5E81AC",
    "green"  = "#8FBCBB",
    "yellow" = "#EBCB8B",
    "orange" = "#D08770"
  )

  return(col_palette)
}

setRefTable <- function(ts) {
  #' Set Reference Table
  #'
  #' Set a reference table for colouring or grouping.
  #'
  #' @param ts A GBD time-series
  #' @return A tidy data frame

  colors <- genColor()

  tbl <- ftable(Group ~ Diagnosis, data = ts) %>%
    data.frame() %>%
    subset(.$Freq != 0) %>%
    dplyr::mutate(
      "Diagnosis" = factor(Diagnosis, levels = Diagnosis),
      "color" = dplyr::case_when(
        Group == "Mental Health"             ~ colors$green,
        Group == "Non-Communicable Diseases" ~ "grey90",
        Group == "Communicable Diseases"     ~ colors$orange
      )
    )

  return(tbl)
}

setStripColor <- function(ts, group) {
  #' Set Strip Color
  #'
  #' Set strip color in a faceted GGPlot2 object
  #'
  #' @param ts A GBD time-series
  #' @param group A grouping variable, support either `Diagnosis` or `Group`
  #' @return Themed strip as a `ggh4x` object
  require("ggh4x")

  colors <- genColor()

  # Set reference table
  tbl <- setRefTable(ts)
  
  # Subset by faceting variable
  sub_tbl <- tbl %>%
    dplyr::select({{ group }}, color) %>%
    unique() %>%
    dplyr::arrange({{ group }})

  # Set the strip colors
  strip_col <- ggh4x::strip_themed(
    background_x = ggh4x::elem_list_rect(fill = sub_tbl$color)
  )

  return(strip_col)
}

setDot <- function(ts, y) {
  #' Set the Dot Plot
  #'
  #' Set the dot position for visualization.
  #'
  #' @param ts A GBD time-series
  #' @param y A metric name from the time-series data
  #' @return A GGPlot object
  require("ggplot2")
  require("tsibble")

  plt <- ggplot(ts, aes(x = as.numeric(Year), y = get(y), color = Region)) +
    geom_point(alpha = 0.4, size = 0.8) +
    geom_line(alpha = 0.2, linewidth = 0.8) +
    labs(x = "Year", y = y) +
    ggpubr::theme_pubclean() +
    scale_y_continuous(labels = scales::percent) +
    theme(
      strip.text = element_text(size = 10),
      axis.text  = element_text(size = 8),
      legend.title = element_blank()
    )

  return(plt)
}

setFacet <- function(..., strip_col = NULL) {
  #' Set the Facet
  #'
  #' Set the facet for visualization.
  #'
  #' @param strip_col Configured strip colours
  #' @inheritDotParams ggh4x::facet_wrap2
  #' @return A facet configuration
  require("ggh4x")

  if (is.null(strip_col)) {
    strip_col <- ggh4x::strip_vanilla()
  }

  plt_facet <- ggh4x::facet_wrap2(..., strip = strip_col)

  return(plt_facet)
}

vizDot <- function(ts, y, ...) {
  #' Visualize the Dot Plot
  #'
  #' Visualizing the data frame content as a dot plot.
  #'
  #' @param ts A GBD time-series
  #' @param y A metric name from the time-series data
  #' @inheritDotParams ggh4x::facet_wrap2
  #' @return A GGPlot object
  require("ggplot2")
  require("ggh4x")
  require("tsibble")

  colors    <- genColor()
  strip_col <- setStripColor(ts, group = Diagnosis)

  dot <- setDot(ts, y)
  plt <- dot + setFacet(~Group + Diagnosis, strip_col = strip_col, ...)

  return(plt)
}

vizAutocor <- function(ts, y, type = "ACF", ...) {
  #' Visualize the Autocorrelation Plot
  #'
  #' Generate an autocorrelation plot from the output of `feasts::ACF`,
  #' `feasts::PACF`, or `feasts::CCF`
  #'
  #' @param ts A GBD time-series
  #' @param y A metric name from the time-series data
  #' @param type Type of autocorrelation, supports both `ACF` and `PACF`
  #' @inheritDotParams feasts::ACF
  #' @return A GGPlot object
  require("ggplot2")
  require("ggh4x")

  # Set plot parameters
  size      <- 0.8 # Dot size
  colors    <- genColor()
  strip_col <- setStripColor(ts, group = Diagnosis)

  # Update key to include groups
  ts %<>% tsibble::update_tsibble(key = c(Region, Diagnosis, Group))

  # Calculate the autocorrelation
  if (type == "ACF") {
    ts_ac <- ts %>% feasts::ACF(y = get(y), lag_max = 10)
  } else if (type == "PACF") {
    ts_ac <- ts %>% feasts::PACF(y = get(y), lag_max = 10)
  }

  # Get the confidence interval, see `feasts:::autoplot.tbl_cf`
  conf_int <- attr(ts_ac, "num_obs") %>%
    dplyr::mutate(
      "upper" = qnorm(1.95 / 2) / sqrt(.len),
      "lower" = -upper
    ) %>%
    tidyr::pivot_longer(c(upper, lower), names_to = "type", values_to = "ci")

  # Prepare the data frame for plotting
  ts_ac %<>%
    set_names(c("Region", "Diagnosis", "Group", "lag", "ac")) %>%
    dplyr::group_by(Region, Diagnosis) %>%
    dplyr::mutate(
      "maxcor" = ac == max(ac),
      "color"  = ifelse(maxcor, colors$red, colors$black),
      "size"   = ifelse(maxcor, size * 2, size)
    )

  # Generate the plot
  plt <- ggplot(ts_ac, aes(x = lag, y = ac)) +
    ylim(c(-1, 1)) +
    geom_hline(aes(yintercept = ci, group = type), data = conf_int, color = colors$black, linetype = "dashed", alpha = 0.4) +
    geom_hline(yintercept = 0, alpha = 0.8) +
    geom_segment(aes(x = lag, xend = lag, y = 0, yend = ac), alpha = 0.6, lwd = ts_ac$size, color = ts_ac$color) +
    geom_point(aes(shape = Region), alpha = 1, size = ts_ac$size * 2, color = ts_ac$color) +
    ggh4x::facet_wrap2(~Group + Diagnosis, nrow = 3, strip = strip_col) +
    scale_x_continuous(n.breaks = 9) +
    labs(
      x = sprintf("Lag (%s)", tsibble:::format.interval(feasts:::interval_pull.cf_lag(ts_ac))),
      y = y
    ) +
    ggpubr::theme_pubclean() +
    theme(
      strip.text = element_text(size = 10),
      axis.text  = element_text(size = 8)
    )

  return(plt)
}

vizDotAug <- function(ts, y, ...) {
  #' Visualize the Augmented Data
  #'
  #' Visualizing the agumented data frame content as a dot plot.
  #'
  #' @param ts A GBD time-series
  #' @param y A metric name from the time-series data
  #' @inheritDotParams ggh4x::facet_wrap2
  #' @return A GGPlot object
  require("ggplot2")
  require("ggh4x")
  require("tsibble")

  colors    <- genColor()
  strip_col <- setStripColor(ts, group = Diagnosis)

  tbl_model <- ts %>%
    tibble::tibble() %>%
    dplyr::arrange(Region, Diagnosis, Group, Year) %>%
    dplyr::group_by(Region, Diagnosis, Group, .model) %>%
    dplyr::slice_head(n = 1) %>%
    dplyr::ungroup()

  dot <- setDot(ts, y)

  plt <- dot +
    geom_point(aes(y = .fitted, shape = "Fitted Value"), alpha = 0.4, size = 0.8) +
    geom_line(aes(y = .fitted), alpha = 0.2, linewidth = 0.6, linetype = 3) +
    geom_ribbon(aes(ymin = lo, ymax = hi, fill = Region), alpha = 0.2, linewidth = 0, show.legend = FALSE) +
    ggrepel::geom_label_repel(
      aes(label = .model, x = as.numeric(Year), y = get(y), color = Region),
      data = tbl_model,
      alpha = 0.8,
      inherit.aes = FALSE,
      show.legend = FALSE
    ) +
    scale_shape_manual(values = c("Fitted Value" = 3), name = NULL) +
    setFacet(~Group + Diagnosis, strip_col = strip_col, ...)

  return(plt)
}

vizDotDiff <- function(ts_aug, scenario, ...) {
  #' Visualize the Dot Plot
  #'
  #' Visualizing the data frame content as a dot plot.
  #'
  #' @param ts_aug A table outlining the best-fitting model augmentation
  #' @param scenario A tidy data frame containing counterfactual scenario
  #' @inheritDotParams ggh4x::facet_wrap2
  #' @return A GGPlot object
  require("ggplot2")
  require("ggh4x")
  require("tsibble")

  colors    <- genColor()
  strip_col <- setStripColor(ts_aug, group = Diagnosis)
  region    <- unique(scenario$Region)
  plt_title <- sprintf("Relative prevalence difference between SKI 2023 and %s GBD forecast", region)

  # Configure tables for plotting
  sub_ts <- ts_aug |> dplyr::filter(Region == region)
  sub_scenario <- scenario |> dplyr::filter(Year > 2018)

  # Set the plot
  dot <- vizDotAug(sub_ts, "Prevalence", grouped = FALSE, ...)

  plt <- dot +
    geom_point(
      aes(x = as.numeric(Year), y = Prevalence, color = .model),
      size  = 1,
      alpha = 0.8,
      shape = 15,
      data  = sub_scenario,
      inherit.aes = FALSE
    ) +
    labs(x = "") +
    theme(legend.position = "top")

  return(plt)
}

