'''
Created on 30 May 2023

@author: fdenijs
'''

import os
from pathlib import Path
import time

import pandas as pd
import pyreadr

__root__: Path = Path(__file__).parent.parent
in_root: Path = __root__ / 'data/'
out_root: Path = __root__ / 'data/'


def initialize(signal_rds_path: dict) -> None:

    for signal, rds_path in signal_rds_path.items():
        initialize_signal(signal, rds_path)


def initialize_signal(signal: str,
                      rds_path: Path,
                      aggregator: dict = {'sum': sum, 'count': sum, 'min': min, 'max': max}) -> None:

    # Read the RDS.
    df: pd.DataFrame = read_rds_signal(rds_path)

    # Create the root folder for the signal.
    out_signal: Path = out_root / signal
    if not out_signal.exists():
        out_signal.mkdir(parents = True)

    print(f"Writing to '{out_signal}'...", end = ' ')
    st = time.time()

    # Identify all unique units.
    all_units = df.index.unique()

    # Create the datasets (one per unit).
    for unit_id in all_units:

        # Select the unit and remove the 'unit' index in favor of 'utc'.
        unit_df = df.loc[unit_id]
        unit_df = unit_df.reset_index(drop = True).set_index('utc')

        # Aggregate duplicates.
        unit_df = unit_df.groupby(unit_df.index).agg(aggregator)

        # Write signal to disk.
        out_path = out_root / signal / f'unit_{unit_id:03d}.parquet'#.gzip'
        unit_df.to_parquet(out_path)#, compression = "gzip")

    ed = time.time()
    print(f"({ed-st:.1f}s)")


def read_rds_signal(rds_path: Path) -> pd.DataFrame:

    print(f"Reading '{rds_path.name}'...", end = ' ')
    st = time.time()

    df = pyreadr.read_r(rds_path)[None]
    df = df.drop(columns = ['metric'])
    df = df.set_index('unit')

    ed = time.time()
    print(f"({ed-st:.1f}s)")

    return df



def get_forecast(fc_path, at_time):

    ## Get forecast for _all_ time steps.
    forecast = forecast_to_pandas(fc_path, at_time)

    ## Select forecasts made 'at' a given time.
    return forecast.reset_index().set_index(['forecast_for', 'unit']).unstack(1)['forecast']


def forecast_to_pandas(path_root: Path,
                       at_time: str):

    return pd.concat((step_forecast_to_pandas(path_rds, at_time) for path_rds in path_root.iterdir()))


def step_forecast_to_pandas(path_rds: Path,
                            at_time: str,
                            columns: list = ['forecast_generated_at', 'forecast_for', 'unit', 'forecast']):

    df = pyreadr.read_r(path_rds)[None][columns]
    df = df.set_index(['forecast_generated_at', 'forecast_for'])
    return df.loc[at_time]

def get_ground_truth(units: list, signal: str, start_date: str, end_date: str, metric: str = 'max') -> pd.DataFrame:
    return pd.concat((get_unit_truth(unit_id, signal, start_date, end_date, metric) for unit_id in units), axis = 1)


def get_unit_truth(unit_id: int,
                   signal: str,
                   start_date: str,
                   end_date: str,
                   metric: str,
                   aggregator: dict = {'sum': sum, 'count': sum, 'min': min, 'max': max}) -> pd.DataFrame:

    # Where to find the data?
    in_path = out_root / f'{signal}_unit_{unit_id:d}.rds'

    # Read the signal.
    df = pyreadr.read_r(in_path)[None]

    # Keep only the metrics, set the index to 'utc'; remove duplicates.
    df = df[['utc', 'sum', 'count', 'min', 'max']].set_index('utc')
    df = df.groupby(df.index).agg(aggregator)

    # Calculate the 'mean', if requested.
    if 'metric' == 'mean':
        df['mean'] = df['sum'] / df['count']

    # Subset the signal.
    df = df.loc[start_date:end_date, metric]

    # Set the name of the signal to the unit ID.
    df.name = unit_id

    return df


def get_unit_truth_parquet(unit_id: int,
                   signal: str,
                   start_date: str,
                   end_date: str,
                   metric: str) -> pd.DataFrame:

    # Where to find the data?
    in_path = out_root / signal / f'unit_{unit_id:03d}.parquet'

    # Read the signal.
    df = pd.read_parquet(in_path)

    # Subset the signal.
    df = df.loc[start_date:end_date, metric]

    # Set the name of the signal to the unit ID.
    df.name = unit_id

    return df


def do_init():
    __root__: Path = Path(os.path.abspath('..'))
    in_root: Path = __root__ / 'forecast/data/'
    out_root: Path = __root__ / 'data/'

    signals = [ 'pv_power', 'load_power' ]
    in_paths = { signal: (in_root / f'anonymous_public_{signal}_data.rds') for signal in signals }

    initialize(in_paths)


def do_read():
    # Units being forecast.
    units = [17, 23, 44, 79, 96, 110, 138, 178, 180, 181, 183, 229, 252, 261, 268, 272]

    # When the forecast is for.
    start_date = "2022-07-20"
    end_date = "2022-07-23"

    '''
    st = time.time()
    df = get_ground_truth(units, 'pv_power', start_date, end_date)
    ed = time.time()
    print(f"Reading in {ed-st}")
    '''

    st = time.time()
    df = get_ground_truth(units, 'pv_power', start_date, end_date)
    ed = time.time()
    print(f"Reading in {ed-st}")
    print(df)


if __name__ == '__main__':
    #do_init()
    do_read()
