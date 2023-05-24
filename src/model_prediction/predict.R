# Function to generate forecast and save
generate_forecast_and_save <- function(model, test_data_mat, test_data, power_metric) {
  fcast <- predict(model, test_data_mat)
  test_data_fcast <- test_data %>%
    select(forecast_for = utc, unit, max) %>%
    add_column(fcast) %>%
    rename(actual = max, forecast = fcast) %>%
    mutate(forecast_generated_at = forecast_for - minutes(i*5), .before = forecast_for)
  
  filename <- paste0("direct_model_", i, "_fcast", ".rds")
  path <- here("results", power_metric, filename)
  saveRDS(test_data_fcast, path)
  
  return(test_data_fcast)  
}
