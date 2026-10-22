function scene = setup_ignis_uav_scenario()
%SETUP_IGNIS_UAV_SCENARIO Create the 2.5-D forest scene used by UAV Toolbox.
% Coordinates follow the UAV Scenario convention: meshes use ENU; the UAV
% motion interface uses NED. The fire visuals are stylized scene markers;
% spread and observed reports come from the separate live cellular map.

scene = uavScenario(UpdateRate=1, ReferenceLocation=[0 0 0]);

% 400 m square terrain plane.
addMesh(scene, 'polygon', ...
    {[-200 -200; 200 -200; 200 200; -200 200], [-1 0]}, ...
    [0.20 0.25 0.16]);

% Patchy low vegetation. A repeatable irregular spacing leaves a clear flight
% corridor and a central fire observation area.
for row = 1:7
    for col = 1:8
        east = -175 + (col-1)*48 + 7*sin(row*2 + col);
        north = -165 + (row-1)*48 + 6*cos(row + col*3);
        if hypot(east, north) < 38
            continue;
        end
        trunkHeight = 4 + mod(row*3 + col*5, 5);
        addMesh(scene, 'cylinder', ...
            {[east north 1.0], [0 trunkHeight]}, [0.27 0.20 0.10]);
        addMesh(scene, 'cylinder', ...
            {[east north 3.5], [trunkHeight-1 trunkHeight+4]}, ...
            [0.12+0.025*mod(row,3) 0.31+0.03*mod(col,3) 0.10]);
    end
end

% Burn scar and three stacked, high-contrast orange/red meshes at the
% ignition point. These are visible scene cues, while the live spread stays
% in the cellular automaton and live map viewer.
addMesh(scene, 'cylinder', {[0 0 22], [0 0.25]}, [0.10 0.09 0.07]);
addMesh(scene, 'cylinder', {[0 0 8], [0.25 5]}, [0.78 0.08 0.015]);
addMesh(scene, 'cylinder', {[0 0 5.5], [1 9]}, [1.00 0.25 0.015]);
addMesh(scene, 'cylinder', {[0 0 3], [2 13]}, [1.00 0.72 0.06]);

uav = uavPlatform('UAV', scene, 'ReferenceFrame', 'NED', ...
    'InitialPosition', [-150 -150 -50], ...
    'InitialOrientation', [1 0 0 0]);
updateMesh(uav, 'quadrotor', {4}, [0 0 0], eul2tform([0 0 pi]));

% UAV Scenario Configuration resolves this named base-workspace variable.
assignin('base', 'ignisUAVScenario', scene);
end
