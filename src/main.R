# main.R
library(tidyverse)
library(arrow)
library(here)
library(tsibble)
library(data.table)
library(lightgbm)
library(caTools)

source(here("src/data_preprocessing", "preprocess_power_data.R"))
source(here("src/data_preprocessing", "clean_data.R"))
source(here("src/data_preprocessing", "compute_features.R"))
source(here("src/model_training", "prepare_modelling_data.R"))
source(here("src/model_training", "train.R"))
source(here("src/model_prediction", "predict.R"))

sample_data <- TRUE
input_dir <- here("data/power")
output_dir <- here("processed_data/power")
power_file_path <- file.path(output_dir, paste0(if (sample_data) "sample_", "power_data.rds"))

#````````````````````````````````````````````````````````````````````````````#
#`````````````Run this once to save processing of raw power data`````````````#
#````````````````````````````````````````````````````````````````````````````#
# Power data
if (!file.exists(power_file_path)) {
  downsample_raw_power_data(input_dir, output_dir)
  power_data <- readRDS(power_file_path)
  metric_names <- power_data %>%
    distinct(metric) %>%
    pull()
  
  for (power_metric in metric_names) {
    process_each_power_data(power_data, power_metric, input_dir)
  }
}
#````````````````````````````````````````````````````````````````````````````#
#````````````````````````````````````````````````````````````````````````````#
#````````````````````````````````````````````````````````````````````````````#

periods_per_day <- 288
power_metric <- "pv_power"
start <- "2021-07-01 00:00:00"
end <- "2022-08-17 22:00:00"

# Load and clean power data
power_data_path <- here("processed_data/power", paste0(if (sample_data) "sample_", paste0(power_metric, "_data.rds")))
power_data <- load_data(power_data_path, end)
power_data <- remove_units_with_more_than_1perc_negative(power_data)
power_data <- replace_negative_values_with_NA(power_data)

min_available_data <- periods_per_day*30
min_perc_missing_overall <- 20
test_days <- 30
missing_data_threshold <- 0.2
power_data <- filter_units_based_on_missing_data(power_data, min_available_data, min_perc_missing_overall)
power_data <- remove_units_with_high_missing_data_in_test_set(power_data, end, test_days, missing_data_threshold)
power_data <- replace_zero_day_with_NA(power_data, power_metric)

threshold_load_power <- 0.1
threshold_pv_power <- 0.6
if (power_metric == "load_power") {
  power_data <- remove_units_exceeding_zero_threshold(power_data, power_metric, threshold_load_power)
} else if (power_metric == "pv_power") {
  power_data <- remove_units_exceeding_zero_threshold(power_data, power_metric, threshold_pv_power)
  power_data <- replace_zeros_with_NA(power_data)
}

# Compute features
if (power_metric == "load_power") {
  power_data <- compute_datetime_features(power_data, "ACST") %>%
    rename(clockdatetime_month = tz_month,
           clockdatetime_dow = tz_dow,
           clockdatetime_hour = tz_hour,
           clockdatetime_period = tz_period)
} else if (power_metric == "pv_power") {
  power_data <- compute_datetime_features(power_data, "UTC") %>%
    select(-tz_dow) %>%
    rename(utc_month = tz_month,
           utc_hour = tz_hour,
           utc_period = tz_period)
}
train_end_date <- "2022-07-18"
power_features <- suppressWarnings(compute_statistics_features(power_metric, power_data, train_end_date))
power_data <- remove_units_with_excessive_NAs(power_data, power_metric, power_features$units_many_consecutive_NAs1, power_features$units_many_consecutive_NAs2)

# Model training and prediction
direct_model_steps <- seq(1, 300, 25) #~~~~~This is the selection of steps to model and forecast~~~~#
#~~~~~To model all steps for a 2-day span, set direct_model_steps <- 1:576~~~~#
metric_lags <- get_metric_lags(power_metric, direct_model_steps, periods_per_day)
power_data <- create_lags_of_output_variable(power_data, metric_lags)
power_data <- join_features(power_data, power_metric, feat_unit_dat = power_features$feat_unit_dat, feat_unit_month_period_dat = power_features$feat_unit_month_period_dat, feat_unit_month_dow_dat = power_features$feat_unit_month_dow_dat)

nrounds <- 1000
early_stopping_rounds <- 20
params <- list(
  objective = "huber"
  , metric = "l1"
  , learning_rate = 0.03
)

for (i in direct_model_steps) {
  # Prepare data
  modelling_data <- rearrange_columns(power_data, i, power_metric, periods_per_day)
  modelling_data <- create_differences_means(modelling_data, i)
  modelling_data <- rolling_stats(modelling_data, power_metric, i)
  split_data_result <- prepare_and_split_data(modelling_data, power_metric)
  training_data <- split_data_result$training_data
  test_data <- split_data_result$test_data
  training_data_output <- training_data$max
  test_data_output <- test_data$max
  
  gc()
  
  # Train
  training_data_mat <- convert_to_matrix(training_data)
  test_data_mat <- convert_to_matrix(test_data)
  model <- train_lightgbm(training_data_mat, training_data_output, test_data_mat, test_data_output, params, nrounds, early_stopping_rounds)
  
  # Predict
  test_data_fcast <- generate_forecast_and_save(model, test_data_mat, test_data)
}
