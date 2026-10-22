function modelFile = build_ignis_uav_scene()
%BUILD_IGNIS_UAV_SCENE Add a native UAV Toolbox scenario to the fire model.
root = fileparts(fileparts(mfilename('fullpath')));
modelName = 'ignis_wildfire_uav';
modelFile = fullfile(root, 'simulation', [modelName '.slx']);
scene = setup_ignis_uav_scenario();

if ~bdIsLoaded(modelName)
    load_system(modelFile);
else
    close_system(modelName, 0);
    load_system(modelFile);
end
if ~bdIsLoaded('uavsimlib')
    load_system('uavsimlib');
end
modelWorkspace = get_param(modelName, 'ModelWorkspace');
assignin(modelWorkspace, 'ignisUAVScenario', scene);

% Rebuild these optional scene blocks cleanly when this function is called
% repeatedly from the top-level model builder.
for oldPath = {[modelName '/Scenario NED motion'], ...
        [modelName '/UAV Scenario Motion Write']}
    if getSimulinkBlockHandle(oldPath{1}) ~= -1
        oldPorts = get_param(oldPath{1}, 'PortHandles');
        for p = 1:numel(oldPorts.Inport)
            oldLine = get_param(oldPorts.Inport(p), 'Line');
            if oldLine ~= -1
                delete_line(oldLine);
            end
        end
    end
end
nativeBlocks = {'UAV Scenario Configuration', 'Scenario NED motion', ...
    'Scenario clock', 'UAV Scenario Motion Write', ...
    'Scenario zero acceleration', 'Scenario zero angular rate', ...
    'UAV Scenario Scope'};
for k = 1:numel(nativeBlocks)
    blockPath = [modelName '/' nativeBlocks{k}];
    if getSimulinkBlockHandle(blockPath) ~= -1
        delete_block(blockPath);
    end
end

cfg = [modelName '/UAV Scenario Configuration'];
if getSimulinkBlockHandle(cfg) == -1
    add_block('uavsimlib/UAV Scenario Configuration', cfg, ...
        'Position', [1640 180 1790 245], ...
        'UAVScenarioObject', 'ignisUAVScenario', 'SampleTime', '1');
else
    set_param(cfg, 'UAVScenarioObject', 'ignisUAVScenario', 'SampleTime', '1');
end

pose = [modelName '/Scenario NED motion'];
if getSimulinkBlockHandle(pose) == -1
    add_block('simulink/User-Defined Functions/MATLAB Function', pose, ...
        'Position', [1320 350 1480 465]);
end
rt = sfroot;
chart = rt.find('-isa', 'Stateflow.EMChart', 'Path', pose);
chart.Script = scenario_pose_code();
set_param(modelName, 'SimulationCommand', 'update'); % refresh 5-input chart ports
add_line(modelName, 'UAV waypoint controller/1', 'Scenario NED motion/1', ...
    'autorouting', 'on');
add_line(modelName, 'UAV waypoint controller/2', 'Scenario NED motion/2', ...
    'autorouting', 'on');
add_line(modelName, 'UAV waypoint controller/3', 'Scenario NED motion/3', ...
    'autorouting', 'on');
add_line(modelName, 'UAV waypoint controller/5', 'Scenario NED motion/4', ...
    'autorouting', 'on');
add_line(modelName, 'UAV waypoint controller/4', 'Scenario NED motion/5', ...
    'autorouting', 'on');

motion = [modelName '/UAV Scenario Motion Write'];
if getSimulinkBlockHandle(motion) == -1
    add_block('uavsimlib/UAV Scenario Motion Write', motion, ...
        'Position', [1515 340 1655 465], ...
        'PlatName', '''UAV''', 'ReferenceFrame', 'NED');
end
add_block('simulink/Sources/Constant', [modelName '/Scenario zero acceleration'], ...
    'Value', '[0 0 0]', 'Position', [1430 510 1515 540]);
add_block('simulink/Sources/Constant', [modelName '/Scenario zero angular rate'], ...
    'Value', '[0 0 0]', 'Position', [1430 555 1515 585]);

% The script is idempotent: clear any old lines from the pose and motion
% blocks before making the five native Motion Write connections.
try
    delete_line(modelName, 'Scenario NED motion/1', 'UAV Scenario Motion Write/1');
catch
end
try
    delete_line(modelName, 'Scenario NED motion/2', 'UAV Scenario Motion Write/2');
catch
end
try
    delete_line(modelName, 'Scenario NED motion/3', 'UAV Scenario Motion Write/3');
catch
end
try
    delete_line(modelName, 'Scenario NED motion/4', 'UAV Scenario Motion Write/4');
catch
end
try
    delete_line(modelName, 'Scenario NED motion/5', 'UAV Scenario Motion Write/5');
catch
end
add_line(modelName, 'Scenario NED motion/1', 'UAV Scenario Motion Write/1', ...
    'autorouting', 'on');
add_line(modelName, 'Scenario NED motion/2', 'UAV Scenario Motion Write/2', ...
    'autorouting', 'on');
add_line(modelName, 'Scenario NED motion/3', 'UAV Scenario Motion Write/3', ...
    'autorouting', 'on');
add_line(modelName, 'Scenario zero acceleration/1', ...
    'UAV Scenario Motion Write/4', 'autorouting', 'on');
add_line(modelName, 'Scenario zero angular rate/1', ...
    'UAV Scenario Motion Write/5', 'autorouting', 'on');

scope = [modelName '/UAV Scenario Scope'];
if getSimulinkBlockHandle(scope) == -1
    add_block('uavsimlib/UAV Scenario Scope', scope, ...
        'Position', [1815 335 1950 420], 'SampleTime', '1');
end

% Use the two Simulink 3D Animation/UAV Toolbox blocks the user added.
% The 3D UAV follows the same route as the grid-based survey controller.
scene3d = [modelName '/Simulation 3D Scene Configuration'];
uav3d = [modelName '/Simulation 3D UAV Vehicle'];
if ~bdIsLoaded('uavsim3dlib')
    load_system('uavsim3dlib');
end
if getSimulinkBlockHandle(scene3d) == -1
    add_block('uavsim3dlib/Simulation 3D Scene Configuration', scene3d, ...
        'Position', [2000 720 2190 820]);
end
if getSimulinkBlockHandle(uav3d) == -1
    add_block('uavsim3dlib/Simulation 3D UAV Vehicle', uav3d, ...
        'Position', [1770 720 1975 820]);
end
set_param(scene3d, 'ProjectFormat', 'Default Scenes', ...
    'SceneDesc', 'Empty scene', 'ScenePath', '/Game/Maps/EmptyScene', ...
    'EnableWindow', 'on', 'ViewerType', 'Default Viewer', ...
    'ViewpointName', 'SimulinkVehicle1');
set_param(uav3d, 'Priority', '-1', 'ActorName', 'SimulinkVehicle1', ...
    'SampleTime', '-1');

pose3d = [modelName '/Simulation 3D UAV pose'];
if getSimulinkBlockHandle(pose3d) == -1
    add_block('simulink/User-Defined Functions/MATLAB Function', pose3d, ...
        'Position', [1590 690 1745 790]);
end
% sfroot is a MATLAB function; call it before using the Stateflow API.
poseChart = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', pose3d);
poseChart.Script = sim3d_pose_code();
set_param(modelName, 'SimulationCommand', 'update');
portPairs = {'UAV waypoint controller/1','Simulation 3D UAV pose/1'; ...
        'UAV waypoint controller/2','Simulation 3D UAV pose/2'; ...
        'UAV waypoint controller/3','Simulation 3D UAV pose/3'; ...
        'UAV waypoint controller/5','Simulation 3D UAV pose/4'; ...
        'Simulation 3D UAV pose/1','Simulation 3D UAV Vehicle/1'; ...
        'Simulation 3D UAV pose/2','Simulation 3D UAV Vehicle/2'};
for k = 1:size(portPairs, 1)
    try, delete_line(modelName, portPairs{k,1}, portPairs{k,2}); catch, end
end
for k = 1:size(portPairs, 1)
    add_line(modelName, portPairs{k,1}, portPairs{k,2}, 'autorouting', 'on');
end

set_param(modelName, 'SimulationCommand', 'update');
save_system(modelName, modelFile);
fprintf('Added native UAV Toolbox scene to: %s\n', modelFile);
end

function code = sim3d_pose_code()
code = sprintf([ ...
    'function [translation,rotation] = sim3d_pose(xCell,yCell,altitudeM,headingDeg)\n' ...
    '%%#codegen\n' ...
    'translation = [(yCell-20.0)*10.0 (xCell-20.0)*10.0 -altitudeM];\n' ...
    'rotation = [pi/2.0-headingDeg*pi/180.0 0.0 0.0];\n' ...
    'end\n']);
end

function code = scenario_pose_code()
code = sprintf([ ...
    'function [position,orientation,velocity,acceleration,angularVelocity] = pose(xCell,yCell,altitudeM,headingDeg,speedMps)\n' ...
    '%%#codegen\n' ...
    'heading = headingDeg*pi/180.0;\n' ...
    'yaw = pi/2.0 - heading;\n' ...
    'position = [(yCell-20.0)*10.0 (xCell-20.0)*10.0 -altitudeM];\n' ...
    'orientation = [cos(yaw/2.0) 0.0 0.0 sin(yaw/2.0)];\n' ...
    'velocity = [speedMps*sin(heading) speedMps*cos(heading) 0.0];\n' ...
    'acceleration = [0.0 0.0 0.0];\n' ...
    'angularVelocity = [0.0 0.0 0.0];\n' ...
    'end\n']);
end
