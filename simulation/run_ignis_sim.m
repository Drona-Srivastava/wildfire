function run_ignis_sim()
%RUN_IGNIS_SIM Build and run a deterministic 300-second starter scenario.
root = fileparts(fileparts(mfilename('fullpath')));
modelFile = build_ignis_sim();
modelName = 'ignis_wildfire_uav';
load_system(modelFile);
viewerBlock = [modelName '/Live fire map viewer'];
scenarioScope = [modelName '/UAV Scenario Scope'];
uav3d = [modelName '/Simulation 3D UAV Vehicle'];
scene3d = [modelName '/Simulation 3D Scene Configuration'];
set_param(viewerBlock, 'Parameters', '0'); % keep this verification run headless
set_param(scenarioScope, 'Commented', 'on');
set_param(uav3d, 'Commented', 'on');
set_param(scene3d, 'Commented', 'on');
displayCleanup = onCleanup(@() restore_display_blocks(viewerBlock, scenarioScope, uav3d, scene3d));
simOut = sim(modelName, 'StopTime', '300', 'ReturnWorkspaceOutputs', 'on');

fireLog = simOut.get('fire_state_log');
affectedLog = simOut.get('burned_cell_count_log');
riskMapLog = simOut.get('next_ignition_risk_map_log');
nextRowLog = simOut.get('next_ignition_row_log');
nextColLog = simOut.get('next_ignition_col_log');
nextProbabilityLog = simOut.get('next_ignition_probability_log');
xLog = simOut.get('uav_x_log');
yLog = simOut.get('uav_y_log');
altitudeLog = simOut.get('uav_altitude_log');
speedLog = simOut.get('uav_speed_log');
batteryLog = simOut.get('uav_battery_log');
observedMapLog = simOut.get('observed_fire_map_log');
visibleBurningLog = simOut.get('uav_visible_burning_log');
visibleBurnedLog = simOut.get('uav_visible_burned_log');
reportLog = simOut.get('uav_report_event_log');
reportXLog = simOut.get('uav_report_x_log');
reportYLog = simOut.get('uav_report_y_log');
coverageLog = simOut.get('uav_camera_coverage_log');
fireData = squeeze(fireLog.Data);
lastFire = fireData(:,:,end);
assert(isequal(size(lastFire), [40 40]), 'Fire grid must be 40 by 40.');
assert(any(lastFire(:) > 0), 'Ignition did not propagate into the logged state.');
assert(any(nextProbabilityLog.Data > 0), 'Weather-based next-cell forecast stayed empty.');
assert(all(nextProbabilityLog.Data >= 0 & nextProbabilityLog.Data <= 0.95), ...
    'Forecast probability is outside the model limits.');
assert(all(nextRowLog.Data(nextProbabilityLog.Data > 0) >= 1 & ...
    nextRowLog.Data(nextProbabilityLog.Data > 0) <= 40), ...
    'Forecast row is outside the grid.');
assert(all(nextColLog.Data(nextProbabilityLog.Data > 0) >= 1 & ...
    nextColLog.Data(nextProbabilityLog.Data > 0) <= 40), ...
    'Forecast column is outside the grid.');
assert(all(lastFire(:) <= 2), 'Unexpected fire-state value.');
assert(numel(xLog.Data) == numel(fireLog.Time), 'UAV and fire logs must share the simulation clock.');
assert(all(xLog.Data >= 1 & xLog.Data <= 40), 'UAV x left the grid bounds.');
assert(all(yLog.Data >= 1 & yLog.Data <= 40), 'UAV y left the grid bounds.');
assert(all(altitudeLog.Data == 50), 'UAV altitude must remain at 50 m in this first model.');
assert(all(speedLog.Data >= 0 & speedLog.Data <= 10), 'Unexpected UAV ground speed.');
assert(all(diff(batteryLog.Data) <= 1e-9), 'Battery must not increase during a mission.');
assert(any(visibleBurningLog.Data > 0), ...
    'UAV camera did not observe an active fire.');
assert(any(reportLog.Data > 0), 'UAV did not emit any fire report.');
assert(all(reportXLog.Data(reportLog.Data > 0) >= 1 & reportXLog.Data(reportLog.Data > 0) <= 40), ...
    'Reported fire x-coordinate is outside the grid.');
assert(all(reportYLog.Data(reportLog.Data > 0) >= 1 & reportYLog.Data(reportLog.Data > 0) <= 40), ...
    'Reported fire y-coordinate is outside the grid.');
assert(all(coverageLog.Data >= 0 & coverageLog.Data <= 49), 'Camera footprint coverage is invalid.');
for k = 2:size(fireData,3)
    previous = fireData(:,:,k-1);
    current = fireData(:,:,k);
    assert(all(current(previous == 2) == 2), 'Burned cells must remain burned.');
    assert(all(current(previous == 1) == 1 | current(previous == 1) == 2), ...
        'Burning cells must remain burning or transition to burned.');
end

% Re-run the same model to confirm the persistent states reset at simulation start.
repeatOut = sim(modelName, 'StopTime', '300', 'ReturnWorkspaceOutputs', 'on');
repeatFireLog = repeatOut.get('fire_state_log');
repeatXLog = repeatOut.get('uav_x_log');
repeatReportLog = repeatOut.get('uav_report_event_log');
repeatRiskLog = repeatOut.get('next_ignition_probability_log');
assert(isequal(fireLog.Data, repeatFireLog.Data), 'Wildfire run is not deterministic.');
assert(isequal(xLog.Data, repeatXLog.Data), 'UAV run is not deterministic.');
assert(isequal(reportLog.Data, repeatReportLog.Data), 'UAV reports are not deterministic.');
assert(isequal(nextProbabilityLog.Data, repeatRiskLog.Data), ...
    'Weather-based next-cell forecast is not deterministic.');

resultsDir = fullfile(root, 'simulation', 'results');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end
resultsFile = fullfile(resultsDir, 'starter_run.mat');
save(resultsFile, 'fireLog', 'affectedLog', 'xLog', 'yLog', 'altitudeLog', ...
    'speedLog', 'batteryLog', 'observedMapLog', 'visibleBurningLog', ...
    'visibleBurnedLog', 'reportLog', 'reportXLog', 'reportYLog', 'coverageLog', ...
    'riskMapLog', 'nextRowLog', 'nextColLog', 'nextProbabilityLog');
clear displayCleanup;
fprintf('Simulation passed: %d samples at 1 s, final affected cells=%d, final UAV=(%.2f, %.2f, %.0f m), speed=%.1f m/s, battery=%.1f%%, fire reports=%d, peak visible burning=%d\n', ...
    numel(fireLog.Time), affectedLog.Data(end), xLog.Data(end), yLog.Data(end), ...
    altitudeLog.Data(end), speedLog.Data(end), ...
    batteryLog.Data(end), sum(reportLog.Data > 0), max(visibleBurningLog.Data));
validForecast = find(nextProbabilityLog.Data > 0, 1, 'last');
fprintf('Final forecast: cell row %d, column %d; next-step spread probability %.1f%%.\n', ...
    round(nextRowLog.Data(validForecast)), round(nextColLog.Data(validForecast)), ...
    100*nextProbabilityLog.Data(validForecast));
fprintf('Saved simulation logs: %s\n', resultsFile);
close_system(modelName, 0);
end

function restore_display_blocks(viewerBlock, scenarioScope, uav3d, scene3d)
if bdIsLoaded(bdroot(viewerBlock))
    set_param(viewerBlock, 'Parameters', '1');
    set_param(scenarioScope, 'Commented', 'off');
    set_param(uav3d, 'Commented', 'off');
    set_param(scene3d, 'Commented', 'off');
end
end
