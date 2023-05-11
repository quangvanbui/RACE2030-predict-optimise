# Downsample power data
downsample_raw_power_data <- function(input_dir, output_dir) {
  power_data <- readRDS(file.path(input_dir, "anonymous_public_power_data.rds"))
  power_data <- power_data %>% 
    mutate(utc_minute = minute(utc)) %>%
    filter(utc_minute %in% seq(0, 55, by = 5)) %>%
    select(-utc_minute)
  power_data <- power_data %>% 
    distinct() %>%
    arrange(unit, utc)
  saveRDS(power_data, file.path(output_dir, "power_data.rds"))
}

# Select units from single location
process_each_power_data <- function(power_data, power_metric, input_dir) {
  power_data <- power_data %>%
    filter(metric == power_metric)
  
  # Keep first observation of duplicates
  power_data_duplicates <- power_data %>%
    duplicates(key = unit, index = utc)
  power_data_first_row <- power_data_duplicates %>%
    group_by(unit, utc) %>%
    dplyr::slice(1) %>%
    ungroup()
  utc_unit_first_row <- power_data_first_row %>%
    select(utc, unit)
  power_data <- power_data %>%
    anti_join(utc_unit_first_row, by = c("utc", "unit"))
  power_data <- power_data %>%
    bind_rows(power_data_first_row) %>%
    arrange(utc, unit)
  
  # Fill gaps
  power_data <- power_data %>%
    as_tsibble(index = utc, key = c(unit, metric))
  power_data <- power_data %>%
    fill_gaps(.full = FALSE)
  power_data <- power_data %>% 
    as_tibble()
  
  saveRDS(power_data, file.path(output_dir, paste0(power_metric, "_data.rds")))
}
