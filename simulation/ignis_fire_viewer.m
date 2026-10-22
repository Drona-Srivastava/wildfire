function ignis_fire_viewer(block)
% Level-2 MATLAB S-function that draws the fire grid and UAV during simulation.
setup(block);
end

function setup(block)
block.NumDialogPrms = 1; % 1 = show map, 0 = disable for headless/batch runs
block.NumInputPorts = 14;
block.NumOutputPorts = 0;

block.InputPort(1).Dimensions = [40 40];
block.InputPort(1).DatatypeID = 3; % uint8 fire-state map
block.InputPort(1).DirectFeedthrough = true;
for k = 2:13
    block.InputPort(k).Dimensions = 1;
    block.InputPort(k).DatatypeID = 0;
    block.InputPort(k).DirectFeedthrough = true;
end
block.InputPort(14).Dimensions = [40 40];
block.InputPort(14).DatatypeID = 0;
block.InputPort(14).DirectFeedthrough = true;
block.SampleTimes = [1 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('Outputs', @draw_map);
end

function draw_map(block)
if block.DialogPrm(1).Data == 0
    return;
end
persistent fig ax infoAx mapHandle fireOverlay riskOverlay uavHandle footprintHandle ...
    titleHandle riskHandle focusHandle infoHandle
fire = double(block.InputPort(1).Data);
x = block.InputPort(2).Data;
y = block.InputPort(3).Data;
burning = block.InputPort(4).Data;
report = block.InputPort(5).Data;
battery = block.InputPort(6).Data;
nextRow = block.InputPort(7).Data;
nextCol = block.InputPort(8).Data;
nextProbability = block.InputPort(9).Data;
windDir = block.InputPort(10).Data;
windSpeed = block.InputPort(11).Data;
rh = block.InputPort(12).Data;
temperatureC = block.InputPort(13).Data;
riskMap = double(block.InputPort(14).Data);
nextY = 41.0-nextRow;

if isempty(fig) || ~isgraphics(fig)
    fig = figure('Name', 'IGNIS wildfire operations dashboard', ...
        'NumberTitle', 'off', 'Color', [0.08 0.10 0.12], ...
        'Position', [80 100 1280 760]);
    layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax = nexttile(layout, 1, [1 1]);
    set(ax, 'Color', [0.12 0.13 0.15]);
    mapHandle = image(ax, 'XData', [0.5 40.5], 'YData', [0.5 40.5], ...
        'CData', terrain_texture());
    fireOverlay = image(ax, 'XData', [0.5 40.5], 'YData', [0.5 40.5], ...
        'CData', fire_texture(fire), 'AlphaData', flipud(fire) > 0);
    set(ax, 'YDir', 'normal', 'XLim', [0.5 40.5], 'YLim', [0.5 40.5], ...
        'Color', [0.12 0.13 0.15], 'XColor', 'w', 'YColor', 'w');
    axis(ax, 'image');
    xlabel(ax, 'East (grid cells)'); ylabel(ax, 'North (grid cells)');
    hold(ax, 'on');
    rgbRisk = ind2rgb(uint8(round(min(1,max(0,flipud(riskMap)))*255)), hot(256));
    riskOverlay = image(ax, 'XData', [0.5 40.5], 'YData', [0.5 40.5], ...
        'CData', rgbRisk, 'AlphaData', min(0.78, 2.0*flipud(riskMap)));
    footprintHandle = rectangle(ax, 'Position', [x-3 y-3 6 6], ...
        'EdgeColor', 'c', 'LineStyle', '--', 'LineWidth', 1.5);
    uavHandle = plot(ax, x, y, 'co', 'MarkerFaceColor', 'c', 'MarkerSize', 8);
    riskHandle = plot(ax, nextCol, nextY, 'p', 'Color', [1 0.9 0.1], ...
        'MarkerFaceColor', [1 0.55 0.05], 'MarkerSize', 13, 'LineWidth', 1.5);
    focusHandle = rectangle(ax, 'Position', [0.5 0.5 5 5], ...
        'EdgeColor', [0.2 0.95 1.0], 'LineWidth', 2.2, 'LineStyle', '-');
    legendHandles = [plot(ax,nan,nan,'s','MarkerFaceColor',[0.26 0.43 0.20], ...
        'MarkerEdgeColor','none'), ...
        plot(ax,nan,nan,'s','MarkerFaceColor',[1.00 0.20 0.02],'MarkerEdgeColor','none'), ...
        plot(ax,nan,nan,'s','MarkerFaceColor',[0.20 0.17 0.15],'MarkerEdgeColor','none'), ...
        plot(ax,nan,nan,'co','MarkerFaceColor','c'), ...
        plot(ax,nan,nan,'p','MarkerFaceColor',[1 0.55 0.05], ...
        'MarkerEdgeColor',[1 0.9 0.1]), ...
        plot(ax,nan,nan,'-','Color',[0.2 0.95 1.0],'LineWidth',2)];
    legend(ax, legendHandles, {'Forest terrain','Burning','Burned','UAV','Risk cell','Priority sector'}, ...
        'Location','southoutside','Orientation','horizontal','TextColor','w', ...
        'Color',[0.08 0.10 0.12],'EdgeColor',[0.3 0.34 0.37]);
    titleHandle = title(ax, 'LIVE FIRE MAP  |  orange overlay = next-step ignition risk', ...
        'Color', 'w', 'FontWeight', 'bold');
    hold(ax, 'off');
    infoAx = nexttile(layout, 2, [1 1]);
    axis(infoAx, 'off');
    infoHandle = text(infoAx, 0.02, 0.98, '', 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'Color', [0.92 0.95 0.97], ...
        'FontName', 'Consolas', 'FontSize', 12, 'Interpreter', 'none');
else
    set(fireOverlay, 'CData', fire_texture(fire), 'AlphaData', flipud(fire) > 0);
    rgbRisk = ind2rgb(uint8(round(min(1,max(0,flipud(riskMap)))*255)), hot(256));
    set(riskOverlay, 'CData', rgbRisk, ...
        'AlphaData', min(0.78, 2.0*flipud(riskMap)));
    set(uavHandle, 'XData', x, 'YData', y);
    set(footprintHandle, 'Position', [x-3 y-3 6 6]);
    set(riskHandle, 'XData', nextCol, 'YData', nextY, ...
        'Visible', onoff(nextRow >= 1 && nextRow <= 40));
end
% Rank 8x8 operational sectors, each 5x5 cells (50 m square). The displayed
% chance is an independent-cell approximation for this model's next update.
sectorChance = zeros(8,8);
sectorCells = zeros(8,8);
for sr = 1:8
    for sc = 1:8
        rr = (sr-1)*5 + (1:5);
        cc = (sc-1)*5 + (1:5);
        regionRisk = riskMap(rr,cc);
        sectorChance(sr,sc) = 1.0 - prod(1.0 - min(0.999,max(0,regionRisk(:))));
        sectorCells(sr,sc) = nnz(regionRisk > 0);
    end
end
[rankedChance, rankedIdx] = sort(sectorChance(:), 'descend');
bestSector = rankedIdx(1);
[bestRow, bestCol] = ind2sub([8 8], bestSector);
set(focusHandle, 'Position', [(bestCol-1)*5+0.5, 40-bestRow*5+0.5, 5, 5], ...
    'Visible', onoff(rankedChance(1) > 0));
if rankedChance(1) > 0
    lead = sprintf('PRIORITY SECTOR  R%d-C%d  (%d x %d cells / 50 m square)', ...
        bestRow, bestCol, 5, 5);
    hazardLine = sprintf('Next-step chance of >=1 ignition: %5.1f%%', ...
        100*rankedChance(1));
    focusLine = sprintf('Cells with nonzero forecast risk: %d / 25', ...
        sectorCells(bestRow,bestCol));
else
    lead = 'PRIORITY SECTOR  No active spread edge';
    hazardLine = 'Next-step ignition forecast: 0.0%';
    focusLine = 'No unburned cell adjacent to active fire';
end
burningCount = nnz(fire == 1);
burnedCount = nnz(fire == 2);
if nextRow >= 1 && nextRow <= 40
    cellLine = sprintf('Highest-risk cell: row %02d, col %02d  (%5.1f%%)', ...
        round(nextRow), round(nextCol), 100*nextProbability);
else
    cellLine = 'Highest-risk cell: none';
end
topLines = strings(3,1);
for rank = 1:3
    if rankedChance(rank) <= 0, continue; end
    [sr, sc] = ind2sub([8 8], rankedIdx(rank));
    topLines(rank) = sprintf('  %d) R%d-C%d  %5.1f%%  (%d risk cells)', ...
        rank, sr, sc, 100*rankedChance(rank), sectorCells(sr,sc));
end
set(infoHandle, 'String', sprintf([ ...
    'IGNIS  |  WILDFIRE OPERATIONS\n' ...
    'Simulation time: %d s\n\n' ...
    'FIRE STATUS\n  Burning cells: %d\n  Burned cells:  %d\n  UAV report event: %d\n  Burning cells in camera footprint: %d\n\n' ...
    'UAV STATUS\n  Position: east %.1f, north %.1f (cell)\n  Altitude: 50 m  |  Battery: %.1f%%\n\n' ...
    'WEATHER INPUTS\n  Wind: %.0f deg at %.1f m/s\n  Relative humidity: %.0f%%\n  Air temperature: %.1f C\n\n' ...
    'NEXT IGNITION FORECAST\n  %s\n  %s\n  %s\n\n' ...
    'TOP SECTORS TO MONITOR\n%s\n%s\n%s\n\n' ...
    'CONTROL FOCUS\n  Prioritize patrol / containment resources\n  around the cyan-outlined sector.\n\n' ...
    '* Heuristic one-step model estimate; not a\n  calibrated operational fire prediction.'], ...
    round(block.CurrentTime), burningCount, burnedCount, round(report), ...
    round(burning), x, y, battery, windDir, windSpeed, rh, temperatureC, ...
    lead, hazardLine, cellLine, char(topLines(1)), char(topLines(2)), char(topLines(3))));
drawnow limitrate;
end

function value = onoff(condition)
if condition, value = 'on'; else, value = 'off'; end
end

function rgb = terrain_texture()
% Deterministic stylized terrain texture for the 400 m survey area.
[east,north] = meshgrid(1:40,1:40);
shade = 0.5 + 0.20*sin(east/5.2).*cos(north/6.7) + ...
    0.12*cos((east+north)/4.1) + 0.08*sin((east-2*north)/3.8);
shade = min(1,max(0,shade));
rgb = zeros(40,40,3);
rgb(:,:,1) = 0.13 + 0.12*shade;
rgb(:,:,2) = 0.24 + 0.24*shade;
rgb(:,:,3) = 0.10 + 0.08*shade;
rgb = flipud(rgb);
end

function rgb = fire_texture(fire)
rgb = zeros(40,40,3);
burning = flipud(fire) == 1;
burned = flipud(fire) == 2;
rgb(:,:,1) = 1.00*burning + 0.20*burned;
rgb(:,:,2) = 0.18*burning + 0.17*burned;
rgb(:,:,3) = 0.015*burning + 0.15*burned;
end
