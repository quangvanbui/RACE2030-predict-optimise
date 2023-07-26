# Residential Power and Battery Data

## Overview

The Residential Power and Battery data is an open-source dataset designed to facilitate the advancement of predictive and optimisation algorithms. It features anonymised, minute-by-minute real-world customer data on energy consumption, solar generation, and battery measurements. This dataset was compiled by SwitchDin and made available through Monash University on the Zenodo platform.

Open-sourcing the Residential Power and Battery data offers numerous benefits to researchers, developers, and industry stakeholders. By providing access to comprehensive, real-world data on energy consumption, solar generation, and battery usage, the dataset enables the development of more accurate and efficient algorithms for energy management systems. For example, the dataset could facilitate the development of machine learning models that forecast energy consumption patterns, enabling better demand-side management strategies. These improved algorithms contribute to more effective demand response, grid stability, and renewable energy integration, helping to build a more resilient and sustainable energy future.

Furthermore, open-sourcing this dataset fosters collaboration and knowledge sharing among researchers and professionals in the energy sector. By making the data freely available, researchers from various backgrounds and organisations can work together to identify patterns, trends, and innovative solutions to pressing challenges in energy management. This collaborative approach accelerates the pace of innovation, as diverse perspectives can generate novel ideas and methods that might not emerge in isolation. As a result, the open-sourcing of the Residential Power and Battery data has the potential to significantly advance the pursuit of a more efficient, reliable, and environmentally friendly energy landscape.

## Dataset Structure

The dataset is structured as follows:

`anonymous_public_power_data.rds`

**utc**: The date-time in UTC, formatted as `yyyy-mm-dd hh:mm:ss`.

**unit**: A categorical label denoting the unique identifier for the unit.

**metric**: A categorical label indicating whether the data point corresponds to load or solar power generation.

**max**: A numerical variable denoting the peak value of load or solar power generation in kilowatts (kW) within a one-minute interval.

`anonymous_public_battery_data.rds`

**unit**: A categorical label denoting the unique identifier for the unit.

**batt_kwh**: A numerical variable representing battery kilowatt-hour rating.

**batt_p_ch**: A numerical variable representing battery charge power rating.

**batt_p_dch**: A numerical variable representing battery discharge power rating.

## Usage and Licensing

Residential Power and Battery Data is released under the Creative Commons Attribution-NonCommercial 3.0 Unported (CC BY-NC 3.0) license, which allows for free use, distribution, and modification of the dataset, provided appropriate credit is given to the original authors.

For more information about the license, please refer to https://creativecommons.org/licenses/by-nc/3.0/.

## Citation

If you use this dataset in your research or projects, please cite it as follows:

Christoph Bergmeir, Quang Bui, Frits de Nijs, Peter Stuckey. (2023) Residential Power and Battery Data. Retrieved from [TODO URL of Zenodo platform].

## Contact Information

For any questions or concerns regarding the Residential Power and Battery Data, please contact [TODO Names] at [TODO email address].

