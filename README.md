# RACE2030 Predict and Optimise

This repository includes code for processing and cleaning residential power data, training power models with machine learning, forecasting power, and optimising battery schedules. The forecasting code is in R, while the optimisation code is in Python. Details about the raw data can be found [here](https://github.com/quangvanbui/RACE2030-predict-optimise/tree/main/processed_data/public_data.md).

## Table of Contents

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Data Processing and Cleaning](#data-processing-and-cleaning)
- [Training Models](#training-models)
- [Forecasting](#forecasting)
- [Optimisation](#optimisation)
- [Usage](#usage)

## Getting Started

These instructions will help you set up the project on your local machine for development and testing purposes.

1. Clone the repository

```
git clone https://github.com/quangvanbui/switchdin-predict-optimise.git
```

2. Install dependencies

- Forecasting: Download and install [R](https://cran.rstudio.com/) and [RStudio](https://posit.co/download/rstudio-desktop/). Then, use RStudio to install the necessary packages by running the following commands:

```
install.packages(c("tidyverse", "arrow", "here", "data.table", "lightgbm", "caTools"))
```

- Optimisation: [TODO]

## Data Processing and Cleaning

This project involves processing and cleaning raw power and weather data to prepare it for model training. The process consists of the following steps:

1. **Data loading**:  Raw power data is sourced from SwitchDin and stored in a shared [Zenodo](https://zenodo.org/) as a single .rds file. The dataset includes 14 months of data, ranging from 2021-07 to 2022-08. The power data are loaded into the project using functions from the `preprocess_power_data.R` script, which is called when executing the `main.R` script.

2. **Data format**: The raw power data are provided in 1-minute intervals and includes load power and PV power measurements from 273 units.

3. **Data cleaning**: Data cleaning functions are incorporated in the `clean_data.R` script and are called when executing the `main.R` script. The cleaning process removes any inconsistencies, errors, or missing values to ensure the quality of the data.

4. **Data preprocessing**: The project computes basic features for the models using functions in the `compute_features.R` script. These functions are called when executing the `main.R` script.

5. **Splitting the data**: Functions in the `prepare_modelling_data.R` script divide the data into training and testing sets for model training and evaluation.

## Training Models

The project uses the [LightGBM](https://github.com/microsoft/LightGBM) algorithm to train separate models for load power and PV power forecasting. The process is as follows:

1. **Model types**: Both load and PV power models are trained using the LightGBM algorithm, a gradient boosting framework that uses tree-based learning algorithms.

2. **Features**: The load and PV power models use different lags of the output variable as features in the model. Load power models use lags of the last hour, day, and 7-day, while PV power models use lags of the last hour and day.

3. **Training process**: The models are trained using the Huber loss function and an early stopping criterion of 20 iterations, implemented with LightGBM. A unique model is developed for each forecast step required. For instance, to generate a 2-day forecast using 5-minute interval data, 576 models need to be trained. This approach is known as the direct global modeling architecture. It is referred to as "global" since the model is trained using data from all cross-sectional units.

## Forecasting

The trained models are used to create multi-step ahead forecasts for both load power and PV power. Each model generates a forecast for a single 5-minute interval, and with a total of 576 models, they collectively produce forecasts covering a 48-hour horizon.

The output of our forecasting models are stored in data files that contain five columns, each representing different aspects of our forecast. Here is a brief description of each column:

* `forecast_generated_at`: This column represents the date and time at which the forecast was generated. It is a timestamp that indicates when our model made this specific forecast.
* `forecast_for`: This column represents the date and time for which the forecast is applicable. This is the target timestamp that the forecast corresponds to.
* `unit`: This column corresponds to the unit of observation that the forecast relates to. This could represent different entities depending on the context, for example, it could be a geographical area, an operational unit, or a time series id.
* `actual`: This column holds the actual observed values for the corresponding `forecast_for` timestamp. This data may not be available at the time of forecast generation and is typically used for model validation and performance measurement after the fact.
* `forecast`: This column contains the forecast values generated by the model for each unit at each `forecast_for` timestamp.

This output data provides a comprehensive and chronological record of the model's forecast values, the actual values, and when each forecast was generated. It can be used for further analysis, model evaluation, visualisation, or reporting.

## Optimisation

The code to optimise a battery schedule for the calculated forecasts is in [RACE2030-Optimise GitHub repository](https://github.com/fdenijs/RACE2030-optimise/). 

## Usage

Follow these steps to set up and use the project:

### Setup and Installation

1. Install R and RStudio. Download and install the latest versions of each.
2. Install the required R packages: tidyverse, arrow, here, tsibble, data.table, lightgbm, and caTools.
3. (For optimisation) Install Python and MiniZinc and follow the steps in the RACE2030-optimise repo to create a virtual environment.

### Running the project

1. To run the forecasting component, execute the `main.R` script located in the `src/` folder. This script sources the necessary functions from the other R scripts and performs the entire workflow, from data preprocessing and cleaning to model training and prediction.
2. To run the optimisation component, run `python src/demo.py` in RACE2030-optimise repo to compute a VPP battery schedule with the forecast signals

### Input Data

1. The input data are located in [Zenodo](https://zenodo.org/). A sample of the raw power data is included in this folder.
2. To run the project with the full power data, copy the data from [Zenodo](https://zenodo.org/) into the `data/` folder.

### Output Data

1. When running the project, the models and forecasts will be generated.
2. The trained models are stored in the `models/` folder, while the forecasts are stored in the `results/` folder.
