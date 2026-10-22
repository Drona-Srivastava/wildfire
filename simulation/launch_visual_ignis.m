function launch_visual_ignis()
%LAUNCH_VISUAL_IGNIS Rebuild and launch the paced visual wildfire/UAV demo.
root = fileparts(fileparts(mfilename('fullpath')));
simulationDir = fullfile(root, 'simulation');
addpath(simulationDir);
modelFile = build_ignis_sim();
modelName = 'ignis_wildfire_uav';
open_system(modelFile);
set_param(modelName, 'StopTime', '120', 'EnablePacing', 'on', 'PacingRate', '1');
save_system(modelName, modelFile);
set_param(modelName, 'SimulationCommand', 'start');
fprintf('IGNIS visual simulation started (120 s at approximately 1x wall-clock pace).\n');
end
