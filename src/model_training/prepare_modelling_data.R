# Function to get metric lags based on metric
get_metric_lags <- function(power_metric, direct_model_steps, periods_per_day) {
  two_hour_lags <- direct_model_steps[1]:(23 + direct_model_steps[length(direct_model_steps)])
  one_day_lags <- (periods_per_day + direct_model_steps[1] - 1 - 3):(periods_per_day + direct_model_steps[length(direct_model_steps)] - 1 + 3)
  
  if (power_metric == "load_power") {
    one_week_lags <- (periods_per_day * 7 + direct_model_steps[1] - 1):(periods_per_day * 7 + direct_model_steps[length(direct_model_steps)] - 1)
    return(unique(c(two_hour_lags, one_day_lags, one_week_lags)))
  } else {
    return(unique(c(two_hour_lags, one_day_lags)))
  }
}

# Function to create lags of output variable
create_lags_of_output_variable <- function(data, metric_lags) {
  data <- data.table(data)
  data[, sprintf("max_lag_%01d", metric_lags) := shift(max, metric_lags, type = "lag"), by = unit]
  return(data %>% tibble())
}

# Function to create date time columns
add_columns_based_on_metric <- function(data, power_metric) {
  if (power_metric == "pv_power") {
    data <- data %>%
      mutate(utc_hour = hour(utc), .before = 4)
  }
  
  if (power_metric == "load_power") {
    acdt_acst_2020 <- ymd_hms("2020-04-05 03:00:00")
    acst_acdt_2020 <- ymd_hms("2020-10-04 02:00:00")
    acdt_acst_2021 <- ymd_hms("2021-04-04 03:00:00")
    acst_acdt_2021 <- ymd_hms("2021-10-03 02:00:00")
    acdt_acst_2022 <- ymd_hms("2022-04-02 03:00:00")
    acst_acdt_2022 <- ymd_hms("2022-10-01 02:00:00")
    
    data <- data %>%
      mutate(utc_date = date(utc),
             acst = utc + hours(9) + minutes(30),
             acdt = utc + hours(10) + minutes(30),
             acst_flag = if_else((acdt >= acdt_acst_2020 & acdt <= acst_acdt_2020) | (acdt >= acdt_acst_2021 & acdt <= acst_acdt_2021) | (acdt >= acdt_acst_2022 & acdt <= acst_acdt_2022), 1, 0),
             acdt_flag = if_else(acst_flag != 1, 1, 0),
             clockdatetime = if_else(acst_flag == 1, acst, acdt),
             clockdatetime_dow = lubridate::wday(clockdatetime, week_start = 1),
             clockdatetime_month = lubridate::month(clockdatetime),
             clockdatetime_hour = lubridate::hour(clockdatetime),
             clockdatetime_minute = lubridate::minute(clockdatetime),
             clockdatetime_minute_char = if_else(clockdatetime_minute < 10, paste0(0, clockdatetime_minute), as.character(clockdatetime_minute)),
             clockdatetime_hour_minute = paste0(clockdatetime_hour, clockdatetime_minute_char),
             clockdatetime_period = as.numeric(clockdatetime_hour_minute)/5) %>% 
      select(-c(acst, acdt, acdt_flag, clockdatetime, clockdatetime_hour, clockdatetime_minute, clockdatetime_minute_char, clockdatetime_hour_minute))
  }
  
  return(data)
}

# Function to join pre-engineered training set features
join_features <- function(data, power_metric, feat_unit_dat, feat_unit_month_period_dat, feat_unit_month_dow_dat) {
  # Join features to data
  data <- data %>%
    inner_join(feat_unit_dat, by = "unit") %>%
    inner_join(feat_unit_month_period_dat, by = c("unit", ifelse(power_metric == "load_power", "clockdatetime_month", "utc_month"), ifelse(power_metric == "load_power", "clockdatetime_period", "utc_period")))
  
  if (power_metric == "load_power") {
    data <- data %>%
      inner_join(feat_unit_month_dow_dat, by = c("unit", "clockdatetime_month", "clockdatetime_dow"))
  }
  
  return(data)
}

# Function to rearrange columns
rearrange_columns <- function(data, i, power_metric, periods_per_day) {
  
  # Define lag column names
  two_hour_lags_name <- paste0("max_lag_", i:(23 + i))
  one_day_lags_name <- paste0("max_lag_", (periods_per_day + i - 4):(periods_per_day + i + 2))
  
  # Add week lags if power_metric is "load_power"
  if (power_metric == "load_power") {
    one_week_lags_name <- paste0("max_lag_", (periods_per_day*7 + i - 1))
    metric_lags_name <- c(two_hour_lags_name, one_day_lags_name, one_week_lags_name)
  } else {
    metric_lags_name <- c(two_hour_lags_name, one_day_lags_name)
  }
  
  # Define datetime and feature engineering column names
  if (power_metric == "load_power") {
    date_time_name <- c("utc", "utc_date", "acst_flag", "clockdatetime_dow", "clockdatetime_month", "clockdatetime_period")
    feat_eng_name <- c('unit_max', 'unit_sd', 'unit_mean', 'unit_median', 'unit_month_dow_max', 'unit_month_dow_min', 'unit_month_dow_sd', 'unit_month_dow_mean', 'unit_month_dow_median', 'unit_month_period_max', 'unit_month_period_min', 'unit_month_period_sd', 'unit_month_period_mean', 'unit_month_period_median')
  } else {
    date_time_name <- c("utc", "utc_date", "utc_month", "utc_hour", "utc_period")
    feat_eng_name <- c('unit_max', 'unit_sd', 'unit_mean', 'unit_median', 'unit_month_period_max', 'unit_month_period_min', 'unit_month_period_sd', 'unit_month_period_mean', 'unit_month_period_median')
  }
  
  # Select the relevant columns from data
  data <- data %>%
    select(max, unit, all_of(date_time_name), all_of(feat_eng_name), all_of(metric_lags_name))
  
  return(data)
}

# Function create differences and means 
create_differences_means <- function(data, i) {
  
  two_hour_lags_name <- paste0("max_lag_", i:(23 + i))
  
  # Feature engineering: differences & rolling stats
  max_lag_x_index <- which(colnames(data) == two_hour_lags_name[1])
  max_lag_x_1_index <- which(colnames(data) == two_hour_lags_name[2])
  max_lag_x_2_index <- which(colnames(data) == two_hour_lags_name[3])
  max_lag_x_3_index <- which(colnames(data) == two_hour_lags_name[4])
  max_lag_x_4_index <- which(colnames(data) == two_hour_lags_name[5])
  max_lag_x_5_index <- which(colnames(data) == two_hour_lags_name[6])
  max_lag_x_6_index <- which(colnames(data) == two_hour_lags_name[7])
  max_lag_x_7_index <- which(colnames(data) == two_hour_lags_name[8])
  max_lag_x_8_index <- which(colnames(data) == two_hour_lags_name[9])
  max_lag_x_9_index <- which(colnames(data) == two_hour_lags_name[10])
  max_lag_x_10_index <- which(colnames(data) == two_hour_lags_name[11])
  max_lag_x_11_index <- which(colnames(data) == two_hour_lags_name[12])
  
  data <- data %>%
    mutate(max_lag_x_diff_2 = .[[max_lag_x_index]] - .[[max_lag_x_2_index]],
           max_lag_x_diff_2_perc = max_lag_x_diff_2/.[[max_lag_x_2_index]],
           max_lag_x_mean_3 = (.[[max_lag_x_index]] + .[[max_lag_x_1_index]] + .[[max_lag_x_2_index]])/3,
           max_lag_x_mean_6 = (max_lag_x_mean_3 + .[[max_lag_x_3_index]] + .[[max_lag_x_4_index]] + .[[max_lag_x_5_index]])/6,
           max_lag_x_mean_12 = (max_lag_x_mean_6 + .[[max_lag_x_6_index]] + .[[max_lag_x_7_index]] + .[[max_lag_x_8_index]] + + .[[max_lag_x_9_index]] + .[[max_lag_x_10_index]] + .[[max_lag_x_11_index]])) %>%
    select(-max_lag_x_diff_2)
  
  return(data)
}

# Function for feature engineering
rolling_stats <- function(data, power_metric, i) {
  data <- as.data.table(data)
  
  if (power_metric == "load_power") {
    data[, clockdatetime_weekday := clockdatetime_dow - 5]
    data[, `:=` (clockdatetime_weekday_ind = ifelse(clockdatetime_weekday <= 0, 0, clockdatetime_weekday))]
    period_var <- "clockdatetime_period"
    by_vars <- c("unit", "clockdatetime_weekday_ind", period_var)
  } else {
    period_var <- "utc_period"
    by_vars <- c("unit", period_var)
  }
  
  return(data)
}