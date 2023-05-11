# Load data
load_data <- function(power_data_path, end) {
  readRDS(power_data_path) %>%
    filter(utc <= ymd_hms(end)) %>%
    arrange(unit, utc)
}

# Remove units with more than 1% negative values
remove_units_with_more_than_1perc_negative <- function(data) {
  units_less_1perc_neg <- data %>%
    mutate(neg_max = if_else(max < 0, 1, 0)) %>%
    group_by(unit) %>%
    summarise(prop_neg_max = mean(neg_max, na.rm = TRUE)) %>%
    ungroup() %>%
    filter(prop_neg_max < 0.01) %>%
    distinct(unit) %>%
    pull()
  
  data %>%
    filter(unit %in% units_less_1perc_neg)
}

# Replace remaining negative values with NAs
replace_negative_values_with_NA <- function(data) {
  data %>%
    mutate(max = if_else(max < 0, as.numeric(NA), max))
}

# Remove units with less than 100 days of data
remove_units_with_less_than_100_days <- function(data, power_metric) {
  if (power_metric == "load_power") {
    unit_length_dat <- data %>%
      filter(!is.na(max)) %>%
      group_by(unit) %>%
      summarise(first_utc = first(utc), last_utc = last(utc), n = n()) %>%
      ungroup() %>%
      mutate(n_days = round(n*(5/60)/24, 5),
             unit_length = as.numeric(last_utc - first_utc),
             unit_length_dur = duration(unit_length),
             unit_length_hours = unit_length/(60*60),
             length_days = unit_length_hours/24) %>%
      select(-unit_length, -unit_length_dur, -unit_length_hours)
  } else {
    unit_length_dat <- data %>%
      filter(!is.na(max)) %>%
      group_by(unit) %>%
      summarise(first_utc = first(utc), last_utc = last(utc), n = n()) %>%
      ungroup() %>%
      mutate(n_days = round(n*(5/60)/24, 5),
             unit_length = as.numeric(last_utc - first_utc),
             length_days = unit_length/24) %>%
      select(-unit_length)
  }
  
  short_length_units <- unit_length_dat %>%
    mutate(n_days_100_ind = if_else(n_days < 100, 1, 0),
           length_days_100_ind = if_else(length_days < 100, 1, 0)) %>%
    filter(n_days_100_ind == 1 | length_days_100_ind == 1) %>%
    pull(unit)
  
  data %>%
    filter(!unit %in% short_length_units)
}

# Filter units based on missing data threshold
filter_units_based_on_missing_data <- function(data, min_available_data, min_perc_missing_overall) {
  modelling_units <- data %>%
    mutate(PV_miss_avai = if_else(is.na(max), "Missing", "Available"), .before = 1) %>%
    group_by(unit, PV_miss_avai) %>%
    summarise(n = n()) %>%
    ungroup() %>%
    group_by(unit) %>%
    mutate(perc = 100 *n/sum(n)) %>%
    ungroup() %>%
    pivot_wider(names_from = PV_miss_avai, values_from = c(n, perc)) %>%
    filter(perc_Missing < min_perc_missing_overall, n_Available > min_available_data) %>%
    pull(unit)
  
  data %>%
    filter(unit %in% modelling_units)
}

# Remove units missing more than a certain percentage of data in the test set
remove_units_with_high_missing_data_in_test_set <- function(data, end, test_days, missing_data_threshold) {
  unit_prop_miss_test_train <- data %>%
    mutate(test_period = if_else(date(utc) > as_date(end) - days(test_days), "Test", "Train")) %>%
    mutate(miss_ind = if_else(is.na(max), 1, 0)) %>%
    group_by(unit, test_period) %>%
    summarise(prop_miss = mean(miss_ind, na.rm = TRUE)) %>%
    ungroup() %>%
    pivot_wider(names_from = test_period, values_from = prop_miss) %>%
    arrange(desc(Test))
  
  unit_miss_over_threshold <- unit_prop_miss_test_train %>%
    filter(Test > missing_data_threshold) %>%
    pull(unit)
  
  data %>%
    filter(!unit %in% unit_miss_over_threshold)
}

# Replace max with NA if the entire day has a value of 0 (for pv_power metric only)
replace_zero_day_with_NA <- function(data, power_metric) {
  if (power_metric == "pv_power") {
    data %>%
      mutate(utc_0930 = utc + hours(9) + minutes(30), 
             utc_0930_date = date(utc_0930),
             max_0_ind = if_else(max == 0, 1, 0)) %>%
      group_by(unit, utc_0930_date) %>%
      mutate(mean_0_prop_date = mean(max_0_ind, na.rm = TRUE)) %>%
      ungroup() %>%
      mutate(max = if_else(mean_0_prop_date == 1, as.numeric(NA), max)) %>%
      select(-c(utc_0930, utc_0930_date, max_0_ind, mean_0_prop_date))
  } else {
    data
  }
}

calculate_zero_proportion <- function(data) {
  data %>%
    mutate(max_0_ind = if_else(max == 0, 1, 0)) %>%
    group_by(unit) %>%
    summarise(mean_0_prop = mean(max_0_ind, na.rm = TRUE)) %>%
    ungroup() %>%
    arrange(desc(mean_0_prop))
}

remove_units_exceeding_zero_threshold <- function(data, power_metric, threshold) {
  prop_0_dat <- calculate_zero_proportion(data)
  unit_over_threshold <- prop_0_dat %>%
    filter(mean_0_prop > threshold) %>%
    pull(unit)
  
  data <- data %>%
    filter(!unit %in% unit_over_threshold)
  
  return(data)
}

replace_zeros_with_NA <- function(data) {
  data %>%
    group_by(utc) %>%
    mutate(median_PV = median(max, na.rm = TRUE),
           sd_PV = sd(max, na.rm = TRUE)) %>%
    ungroup() %>%
    mutate(max_0_flag = if_else((max == 0) & (max < (median_PV - 2*sd_PV)), 1, 0),
           max = if_else(max_0_flag == 1, as.numeric(NA), max)) %>%
    select(-median_PV, -sd_PV, -max_0_flag)
}