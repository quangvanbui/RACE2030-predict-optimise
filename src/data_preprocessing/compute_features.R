# Compute date-time features
compute_datetime_features <- function(data, timezone = "UTC") {
  time_zone <- case_when(
    timezone == "UTC" ~ "UTC",
    timezone == "ACST" ~ "Australia/Adelaide"
  )
  
  data <- data %>%
    mutate(
      utc_date = date(utc),
      tz_month = as.numeric(month(with_tz(utc, tzone = time_zone))),
      tz_dow = lubridate::wday(with_tz(utc, tzone = time_zone), week_start = 1),  
      tz_hour = hour(with_tz(utc, tzone = time_zone)),
      tz_minute = minute(with_tz(utc, tzone = time_zone)),
      tz_minute_char = if_else(tz_minute < 10, paste0(0, tz_minute), as.character(tz_minute)),
      tz_hour_minute = paste0(tz_hour, tz_minute_char),
      tz_period = as.numeric(tz_hour_minute)/5,
      .before = 4
    ) %>%
    select(-c(# tz_hour, 
      tz_minute, tz_minute_char, tz_hour_minute))
  
  return(data)
}

# Compute summary statistics features
compute_statistics_features <- function(power_metric, data, train_end_date) {
  if (power_metric == "load_power") {
    month_var <- "clockdatetime_month"
    period_var <- "clockdatetime_period"
    dow_var <- "clockdatetime_dow"
  } else if (power_metric == "pv_power") {
    month_var <- "utc_month"
    period_var <- "utc_period"
    dow_var <- NULL
  }
  
  feat_unit_month_period_dat <- data %>%
    filter(utc_date <= date(train_end_date)) %>%
    group_by(unit, !!sym(month_var), !!sym(period_var)) %>%
    summarise(unit_month_period_max = max(max, na.rm = TRUE),
              unit_month_period_min = min(max, na.rm = TRUE),
              unit_month_period_sd = sd(max, na.rm = TRUE),
              unit_month_period_mean = mean(max, na.rm = TRUE),
              unit_month_period_median = median(max, na.rm = TRUE)) %>%
    ungroup()
  
  units_many_consecutive_NAs1 <- feat_unit_month_period_dat %>%
    filter(is.infinite(unit_month_period_max)) %>%
    distinct(unit) %>%
    pull()
  
  if (!is.null(dow_var)) {
    feat_unit_month_dow_dat <- data %>%
      filter(utc_date <= date(train_end_date), !unit %in% units_many_consecutive_NAs1) %>%
      group_by(unit, !!sym(month_var), !!sym(dow_var)) %>%
      summarise(unit_month_dow_max = max(max, na.rm = TRUE),
                unit_month_dow_min = min(max, na.rm = TRUE),
                unit_month_dow_sd = sd(max, na.rm = TRUE),
                unit_month_dow_mean = mean(max, na.rm = TRUE),
                unit_month_dow_median = median(max, na.rm = TRUE)) %>%
      ungroup()
    
    units_many_consecutive_NAs2 <- feat_unit_month_dow_dat %>%
      filter(is.infinite(unit_month_dow_max)) %>%
      distinct(unit) %>%
      pull()
    
    feat_unit_month_dow_dat <- feat_unit_month_dow_dat %>%
      filter(!unit %in% units_many_consecutive_NAs2)
    
  } else {
    units_many_consecutive_NAs2 <- NULL
    feat_unit_month_dow_dat <- NULL
  }
  
  feat_unit_dat <- data %>%
    filter(utc_date <= date(train_end_date), !unit %in% c(units_many_consecutive_NAs1, units_many_consecutive_NAs2)) %>%
    group_by(unit) %>%
    summarise(unit_max = max(max, na.rm = TRUE),
              unit_sd = sd(max, na.rm = TRUE),
              unit_mean = mean(max, na.rm = TRUE),
              unit_median = median(max, na.rm = TRUE)) %>%
    ungroup()
  
  feat_unit_month_period_dat <- feat_unit_month_period_dat %>%
    filter(!unit %in% c(units_many_consecutive_NAs1, units_many_consecutive_NAs2))
  
  return(list(feat_unit_dat = feat_unit_dat,
              feat_unit_month_dow_dat = feat_unit_month_dow_dat,
              feat_unit_month_period_dat = feat_unit_month_period_dat,
              units_many_consecutive_NAs1 = units_many_consecutive_NAs1,
              units_many_consecutive_NAs2 = units_many_consecutive_NAs2))
}

# Remove units with excessive NAs found from summary statistics
remove_units_with_excessive_NAs <- function(data, power_metric, units_NAs1, units_NAs2 = NULL) {
  if (power_metric == "load_power") {
    data <- data %>%
      filter(!unit %in% c(units_NAs1, units_NAs2))
  }
  
  if (power_metric == "pv_power") {
    data <- data %>%
      filter(!unit %in% c(units_NAs1))
  }
  
  return(data)
}