from pathlib import Path
import json
import subprocess

import pandas as pd
import numpy as np
import datetime

def solve(args):

    # Temporary folder for scratch files.
    path_temp = Path.cwd() / 'temp'

    # Identify locations of files.
    path_dzn = path_temp / 'instance.dzn'
    path_json = path_temp / 'solution.json'
    path_log = path_temp / 'logfile.txt'

    # Create the temporary output directory, if missing.
    if not path_temp.exists():
        path_temp.mkdir()
        assert path_temp.exists(), f"Failed to create temporary dir '{str(path_temp)}'."

    # Solve model.
    if not args.verbose:
        with open(path_log, 'w') as fp:
            _read_and_solve(args, path_dzn, path_json, fp)
    else:
        _read_and_solve(args, path_dzn, path_json, None)

    # Clean up the created instance & log files if requested.
    if args.cleanup:

        # Remove files. They might be missing if a solver error happened.
        path_dzn.unlink(missing_ok=True)
        path_json.unlink(missing_ok=True)
        path_log.unlink(missing_ok=True)

        # Only remove temp dir if it is empty.
        if _is_empty(path_temp.iterdir()):
            path_temp.rmdir()

def _is_empty(generator):
    for _ in generator:
        return False
    return True

def _read_and_solve(args, path_dzn, path_json, fp):
    
    # Read the indicated configuration file, and append the program arguments to it.
    config = json.loads(Path(args.config).read_text())
    config.update(vars(args))
    config['path_dzn'] = path_dzn
    config['path_json'] = path_json

    # Read the optimisation data.
    df_base = pd.read_csv(config['load'], index_col=0, parse_dates=[0])
    df_solar = pd.read_csv(config['solar'], index_col=0, parse_dates=[0])
    df_batt = pd.read_csv(config['battery'], index_col=0)
    
    # Extract solution.
    df_sol = _do_solve(df_base, df_solar, df_batt, config, fp)

    # Write solution.
    df_sol.to_csv(config['out'])

def _do_solve(df_base, df_solar, df_batt, config, fp=None, calc_soc=False, verbose=True):

    # Ensure model exists.
    path_mzn_opt = Path(__file__).parent / 'model' / 'peak_model.mzn'
    assert path_mzn_opt.exists(), "Optimisation model missing."

    # Check and reshape the inputs.
    processed = _preprocess_inputs(df_base, df_solar, df_batt)

    # Create DZN string from data, and write to file.
    dzn_str = _convert_to_dzn(config['alpha'], *processed)
    config['path_dzn'].write_text(dzn_str)

    # Run Minizinc on the problem.
    run_minizinc(path_mzn_opt, config['path_dzn'], config['path_json'],
                 mz_bin=config['mzn_bin'], solver=config['solver'], threads=config['threads'],
                 verbose=verbose, fp=fp)

    # Extract solution.
    json_opt = json.loads(config['path_json'].read_text())

    # Extract baseload.
    df_sol = pd.DataFrame(np.array(json_opt['battery_load']))
    df_sol.index = df_base.index
    df_sol.columns = df_batt.index

    # Should we (also) return state-of-charge?
    if calc_soc:

        # Extend the datetime index by one.
        n = 1
        dates = df_base.index
        dates.freq = pd.infer_freq(dates)
        dates = dates.union(pd.date_range(dates[-1] + dates.freq, periods=n, freq=dates.freq))

        # Extract state of charge.
        df_soc = pd.DataFrame(np.array(json_opt['state_of_charge_kWh']))
        df_soc.index = dates
        df_soc.columns = df_batt.index

        return df_sol, df_soc

    return df_sol

def _preprocess_inputs(df_load, df_solar, df_batt):

    # Infer decision-making step size.
    diffs = np.diff(df_load.index)
    delta = diffs[0]

    # Sanity checks.
    assert np.all(df_load.index == df_solar.index), "Load and solar time series do not align."
    assert df_load.index.tz == datetime.timezone.utc, "Time series not in UTC."
    assert np.all(diffs == delta), "Step size not constant."
    assert ((delta.seconds // 60) - (delta.seconds / 60)) < 1e-6, "Step size not in whole minutes" 
    assert not np.any(df_load.isna()), "Load forecast contains NAs."
    assert not np.any(df_solar.isna()), "Solar forecast contains NAs."
    assert not np.any(df_batt.isna()), "Battery data contains NAs."

    # Collect used unit IDs.
    unit_load = set(df_load.columns.values)
    unit_solar = set(df_solar.columns.values)
    unit_batt = set(df_batt.index.values)

    # Identify uncontrolled base load units.
    unc_load = list(unit_load - unit_batt)
    unc_solar = list(unit_solar - unit_batt)

    # Calculate the base load from the uncontrolled time series.
    base_load = pd.Series(0, index=df_load.index)
    base_load += df_load.loc[:,unc_load].sum(axis=1)
    base_load -= df_solar.loc[:,unc_solar].sum(axis=1)

    # Construct a fixed ordering for the controllable units.
    unit_batt = list(unit_batt)
    unit_batt.sort()

    # Keep only time series for controllable units.
    df_load = df_load.reindex(columns=unit_batt, fill_value=0)
    df_solar = df_solar.reindex(columns=unit_batt, fill_value=0)
    df_batt = df_batt.reindex(unit_batt)

    # Calculate SA tariffs from the index.
    tariff_import, tariff_export = get_SA_tariff(df_load.index)

    # Return the preprocessed data.
    return delta, base_load, tariff_import, tariff_export, df_load, df_solar, df_batt

def get_SA_tariff(ts):

    # Convert UTC to SA time.
    ts = ts.tz_convert('Australia/Adelaide')

    # Construct tariff Series.
    tariff_import = pd.Series(0.45, index=ts)
    tariff_export = pd.Series(0.15, index=ts) 

    # Shoulder between 1 am and 6 am, Off-peak between 10 am and 3 pm.
    tariff_import[ts.indexer_between_time("01:00", "06:00")] = 0.17
    tariff_import[ts.indexer_between_time("10:00", "15:00")] = 0.20

    # For consistency, we restore the timezone to UTC.
    tariff_import.index = tariff_import.index.tz_convert('UTC')
    tariff_export.index = tariff_export.index.tz_convert('UTC')

    return tariff_import, tariff_export

def _convert_to_dzn(alpha, delta, base_load, tariff_import, tariff_export, df_load, df_solar, df_batt):

    # Convert quantities from W to kW.
    batt_capacity = df_batt["batt_wh"].values / 1000
    batt_charge = df_batt["batt_p_ch"].values / 1000
    batt_discharge = df_batt["batt_p_dch"].values / 1000
    batt_state = df_batt["batt_soc"].values / 1000
    batt_eff = np.sqrt(df_batt["batt_eff"].values)

    # Return data compiled to dzn format.
    return (
        f'num_timesteps = {len(df_load)};\n'
        f'num_units = {len(df_batt)};\n'
        f'step_minutes = {delta.seconds // 60};\n'
        f'uncontrollable_forecast = array1d(TIMESTEPS, {repr(base_load.values.tolist())});\n'
        f'base_load_forecast = array2d(TIMESTEPS, UNITS, {repr(df_load.values.ravel().tolist())});\n'
        f'solar_load_forecast = array2d(TIMESTEPS, UNITS, {repr((-df_solar.values.ravel()).tolist())});\n'
        f'capacity_kWh = array1d(UNITS, {repr(batt_capacity.tolist())});\n'
        f'charge_kWh = array1d(UNITS, {repr(batt_state.tolist())});\n'
        f'max_charge_kW = array1d(UNITS, {repr(batt_charge.tolist())});\n'
        f'max_discharge_kW = array1d(UNITS, {repr(batt_discharge.tolist())});\n'
        f'tariff = array1d(TIMESTEPS, {repr(tariff_import.values.tolist())});\n'
        f'feed_in = array1d(TIMESTEPS, {repr(tariff_export.values.tolist())});\n'
        f'efficiency = array1d(UNITS, {repr(batt_eff.tolist())});\n'
        f'alpha = {alpha};\n'
    )

def run_minizinc(mzn_file, dzn_file, out_file, mz_bin='minizinc', solver='gurobi', threads=8, verbose=True, fp=None):

    # Construct command-line command for running minizinc.
    run_cmd = [mz_bin,
               '--solver', solver,
               '--model', mzn_file,
               '--data', dzn_file,
               '--parallel', str(threads),
               '--output-to-file', out_file,
               '--output-mode', 'json', 
               '--solution-separator', '',
               '--search-complete-msg', '',
               ]

    if verbose:
        run_cmd.append('--verbose')
    elif fp is None:
        fp = subprocess.DEVNULL

    return subprocess.run(run_cmd, stdout=fp, stderr=subprocess.STDOUT)
