# Simulink wildfire and UAV simulation

The executable model is `ignis_wildfire_uav.slx`. `build_ignis_sim.m` creates the fire and survey logic, then `build_ignis_uav_scene.m` adds the UAV Toolbox and Simulink 3D Animation blocks. To rebuild and launch the paced visual demonstration from MATLAB, run `launch_visual_ignis` from the `simulation` folder or call it with that folder on the MATLAB path. It runs for 120 simulation seconds at about 1x wall-clock speed.

```powershell
matlab -batch "cd('C:\path\to\wildfire-uav'); addpath('simulation'); run_ignis_sim"
```

Use `launch_visual_ignis` in the MATLAB desktop to open the live fire map and 3D viewers.

## Model contract

- **Clock:** fixed-step discrete at 1/60 second for the 3D Animation engine. Fire spread is gated to one update per simulation second; UAV kinematics and battery use elapsed simulation time.
- **Grid:** 40 rows by 40 columns, 10 m per cell (400 m square); array row 1 is north, columns increase east. In cell coordinates, x is east and y is north.
- **Fire states:** 0 unburned, 1 burning, 2 burned. Initial ignition is at row 20, column 20.
- **Environment inputs:** constant wind direction 0 degrees (east), wind speed 4 m/s, relative humidity 40%, air temperature 32 C, a patterned fuel map with a low-fuel strip, and synthetic terrain elevation. Edit the corresponding Constant blocks to change the run.
- **Fire:** a deterministic 8-neighbor cellular automaton with wind, humidity, temperature, fuel, and slope modifiers. Fire states are 0 unburned, 1 burning, and 2 burned; cells remain active for 15 seconds. This is an illustrative spread model, not calibrated wildfire physics or a safety prediction.
- **Next-cell forecast:** a one-step probability map scores unburned cells adjacent to active fire with the same wind alignment, humidity, temperature, fuel, and slope factors as the spread rule. The live map marks the highest-risk cell and shows its row, column, probability, and weather inputs. This is a model-based estimate, not a safety prediction.
- **UAV mission:** a waypoint-following kinematic UAV on the same 40-by-40 map at 50 m altitude. It includes wind disturbance, ground speed, heading, battery, low-battery return logic, and a footprint-based survey sensor.
- **Native UAV Toolbox scene:** `setup_ignis_uav_scenario.m` creates a 400 m square, patchy forest scene with a central burn scar/flame marker and quadrotor. `UAV Scenario Configuration`, `UAV Scenario Motion Write`, and `UAV Scenario Scope` provide the native scenario visualization. The scenario UAV motion is driven from the same position, altitude, heading, and speed as the fire-survey UAV.
- **Unreal 3D UAV:** the `Simulation 3D Scene Configuration` and `Simulation 3D UAV Vehicle` blocks are wired to the same route and currently use MATLAB's built-in Empty scene. That viewer shows sky and the UAV only; the live operations dashboard is where the evolving fire, forecast, and priority sector are visible. The UAV Scenario Scope scenario contains a separate stylized forest and static flame landmark; that landmark is not the cellular automaton's changing fire.
- **Fire reporting:** the camera footprint reads active/burned states from the simulated grid, leaves cells outside its footprint unknown (`255`), and emits report events with estimated grid centroids. This is an idealized grid sensor: it does not yet run the trained smoke-segmentation network on camera pixels.
- **Display:** a live operations dashboard shows the changing fire grid, UAV position and camera footprint, weather inputs, detected burning cells, battery, highest-risk next-ignition cell, and the top three 50 m x 50 m sectors to monitor. The cyan outline marks the sector with the largest estimated chance of at least one next-step ignition. The sector score combines cell probabilities under an independence approximation; it is a heuristic for this illustrative model, not an operational fire prediction. Direct desktop simulation opens this dashboard alongside the 3D UAV viewer. `run_ignis_sim.m` disables visual displays during its deterministic batch run and verifies the outputs.

The scenario scope uses a static stylized fire mesh as a scene landmark; it does not yet render the cellular automaton's changing cells as 3D flame actors. The included UAV is kinematic and is not yet a six-degree-of-freedom aerodynamic/rotorcraft model. Aerospace Blockset and Simulink 3D Animation are installed for those next fidelity steps.

The simulation writes `results/starter_run.mat` with fire state, affected-cell count, next-cell risk map and candidate, UAV telemetry, observed-map snapshots, active/burned cells in view, report events/centroids, and coverage. The headless run script checks grid dimensions and state transitions, forecast bounds and deterministic replay, active-fire visibility, report coordinates, UAV bounds, altitude/speed/battery ranges, and replay. The previous fire-only baseline had 301 samples, 416 final affected cells, 26 fire reports, and a peak of 6 burning cells visible at once.

## Next integration stages

1. Add a ground/vegetation environment to the Unreal viewer and drive flame actors from the live fire state; the current Unreal scene remains sky-only while the MATLAB dashboard and UAV Scenario scene carry the fire/terrain visualization.
2. Upgrade UAV kinematics to a closed-loop six-degree-of-freedom vehicle model using the installed Aerospace Blockset.
3. Generate synthetic camera imagery and connect the smoke model through a separate image/mask path; keep its output distinct from fire-grid truth.
4. Exchange telemetry and observations with Python and connect the regional priority output to suppression-resource planning.
