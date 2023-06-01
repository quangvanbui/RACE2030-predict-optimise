%% Decision problem scale.
int: num_timesteps;
int: num_units;
float: step_minutes;
float: step_delta = step_minutes / 60.0;
float: alpha;

%% Sets derived over problem scale values.
set of int: TIMESTEPS = 1..num_timesteps;
set of int: UNITS = 1..num_units;

%% Forecasts over future load and generation (per unit).
array [TIMESTEPS] of float: uncontrollable_forecast;
array [TIMESTEPS, UNITS] of float: base_load_forecast;
array [TIMESTEPS, UNITS] of float: solar_load_forecast;

%% Specs of the battery.
array [UNITS] of float: capacity_kWh;
array [UNITS] of float: charge_kWh;
array [UNITS] of float: max_charge_kW;
array [UNITS] of float: max_discharge_kW;
array [UNITS] of float: efficiency;

%% State of charge of the battery and the power.
array [0..num_timesteps, UNITS] of var 0..max(capacity_kWh): state_of_charge_kWh;
array [TIMESTEPS, UNITS] of var -max(max_discharge_kW)..max(max_charge_kW): charge_rate_kW;
array [TIMESTEPS, UNITS] of var -max(max_discharge_kW)*max(efficiency)..max(max_charge_kW)/min(efficiency): battery_load;
array [TIMESTEPS, UNITS] of var 0.0..(2*max(base_load_forecast)): unit_load_kW;
var float: max_load;

%% Apply capacity constraints across all units and time steps.
constraint
  forall (t in TIMESTEPS, u in UNITS) (
    (0 <= state_of_charge_kWh[t,u] /\ 
          state_of_charge_kWh[t,u] <= capacity_kWh[u]) 
       /\
    (-max_discharge_kW[u] <= charge_rate_kW[t,u] /\ 
                             charge_rate_kW[t,u] <= max_charge_kW[u])
  );

%% Initial battery charge is given.
constraint forall (u in UNITS) (state_of_charge_kWh[0,u] = charge_kWh[u]);

%% Transition state of charge according to the control decision.
constraint
  forall (t in TIMESTEPS, u in UNITS)
    (state_of_charge_kWh[t,u] = state_of_charge_kWh[t-1,u] + step_delta * charge_rate_kW[t,u]);

%% Battery load is modulated by efficiency.
constraint
  forall (t in TIMESTEPS, u in UNITS) (
    (battery_load[t,u] >= charge_rate_kW[t,u] * efficiency[u]) /\
    (battery_load[t,u] >= charge_rate_kW[t,u] / efficiency[u])
  );

%% $ / kWh
array [TIMESTEPS] of float: tariff;
array [TIMESTEPS] of float: feed_in;
array [TIMESTEPS, UNITS] of var float: cost;

%% Unit load is tracked every time step.
constraint
  forall (t in TIMESTEPS, u in UNITS) (
    unit_load_kW[t,u] >= 
		base_load_forecast[t,u] + 
		solar_load_forecast[t,u] +
		battery_load[t,u]);

%% Max load is measured across the entire day.
constraint
  forall (t in TIMESTEPS)
    (max_load >= sum(u in UNITS) (unit_load_kW[t,u]) + uncontrollable_forecast[t]);

%% Tariff cost depends on the direction of control.
constraint
  forall (t in TIMESTEPS, u in UNITS)
    (cost[t,u] >= (tariff[t] * unit_load_kW[t,u] * step_delta) /\
     cost[t,u] >= (feed_in[t] * unit_load_kW[t,u] * step_delta));

%% Minimize maximum load and cost-of-electricity.
solve minimize
  (1-alpha) * max_load + 
     alpha  * sum(cost);
