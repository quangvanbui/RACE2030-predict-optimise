# Function to prepare and split data into training and test sets
prepare_and_split_data <- function(data, power_metric) {
  data <- data %>% filter(!is.na(max))
  
  test_days <- 30
  last_test_date <- data %>%
    distinct(utc_date) %>%
    arrange(utc_date) %>%
    tail(1) %>%
    pull() %>%
    lubridate::ymd()
  last_training_date <- last_test_date - days(test_days)
  first_training_date <- data %>%
    distinct(utc_date) %>%
    arrange(utc_date) %>%
    head(1) %>%
    pull() %>%
    lubridate::ymd()
  training_window <- str_remove_all(paste0(first_training_date, "_", last_training_date), "-")
  training_days <- as.numeric(last_training_date - first_training_date)
  training_data <- data %>% filter(utc_date <= last_training_date)
  test_data <- data %>% filter(utc_date >= last_training_date + days(1))
  
  return(list(training_data = training_data, test_data = test_data))
}

# Function to convert data to matrix form
convert_to_matrix <- function(data) {
  data <- data %>%
    select(-max, -utc, -utc_date, -unit) %>%
    as.matrix()
  return(data)
}

# Function to train LightGBM model
train_lightgbm <- function(training_data_mat, training_data_output, test_data_mat, test_data_output, params, nrounds, early_stopping_rounds, power_metric) {
  dtrain <- lgb.Dataset(
    data = training_data_mat
    , label = training_data_output
  )
  dtest <- lgb.Dataset.create.valid(
    dtrain
    , data = test_data_mat
    , label = test_data_output
  )
  
  model <- lgb.train(
    params = params
    , data = dtrain
    , nrounds = nrounds
    , valids = list(train = dtrain, valid = dtest)
    , early_stopping_rounds = early_stopping_rounds
  )
  
  
  filename <- paste0("direct_model_", i, ".txt")
  path <- here("models", power_metric, filename)
  lgb.save(model, filename = path)
  
  return(model)
}