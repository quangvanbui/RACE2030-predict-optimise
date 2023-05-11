# Function to generate forecast and save
generate_forecast_and_save <- function(model, test_data_mat, test_data) {
  fcast <- predict(model, test_data_mat)
  test_data_fcast <- test_data %>%
    select(utc, unit, max) %>%
    add_column(fcast) %>%
    rename_with(~paste0("fcast_direct_", i), fcast)
  saveRDS(test_data_fcast, here("results", paste0("direct_model_", i, "_fcast", ".rds")))
  
  return(test_data_fcast)  
}