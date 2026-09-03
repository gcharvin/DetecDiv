function fig = score_lineageTreeDialog(model, familyId, varargin)
%SCORE_LINEAGETREEDIALOG Persistent, clickable asymmetric genealogy view.

p = inputParser;
addParameter(p, 'OnTrackSelected', [], @(x) isempty(x) || isa(x, 'function_handle'));
addParameter(p, 'OnRefresh', [], @(x) isempty(x) || isa(x, 'function_handle'));
addParameter(p, 'SelectedTrackId', NaN, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Title', 'Lineage tree', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

familyId = uint32(familyId);
instanceRows = model.instances.family_id == familyId & model.instances.track_id > 0;
ids = unique(model.instances.track_id(instanceRows));
if isempty(ids)
    error('score:EmptyLineageTree', 'The selected object family contains no tracks.');
end
first = zeros(numel(ids), 1);
last = zeros(numel(ids), 1);
for i = 1:numel(ids)
    rows = instanceRows & model.instances.track_id == ids(i);
    first(i) = double(min(model.instances.frame(rows)));
    last(i) = double(max(model.instances.frame(rows)));
end
relationRows = model.relations.family_id == familyId;
parent = model.relations.parent_track_id(relationRows);
child = model.relations.child_track_id(relationRows);
[nodes, edges, diagnostics] = score_lineageTreeLayout( ...
    ids, first, last, parent, child);

tag = 'ScoreAsymmetricLineageTree';
existing = findall(groot, 'Type', 'figure', 'Tag', tag);
if isempty(existing) || ~isvalid(existing(1))
    fig = uifigure('Name', char(string(p.Results.Title)), ...
        'Tag', tag, 'Position', [80 80 1250 780], ...
        'Color', [0.97 0.97 0.97]);
else
    fig = existing(1);
    fig.Name = char(string(p.Results.Title));
    fig.Visible = 'on';
    delete(fig.Children);
end
grid = uigridlayout(fig, [2 1]);
grid.RowHeight = {42, '1x'};
toolbar = uigridlayout(grid, [1 4]);
toolbar.ColumnWidth = {'1x', 130, 130, 100};
summary = uilabel(toolbar, 'Text', localSummary(diagnostics), ...
    'FontWeight', 'bold');
summary.Tooltip = localDiagnosticTooltip(diagnostics);
uibutton(toolbar, 'Text', 'Fit view', ...
    'ButtonPushedFcn', @(~,~) fitView());
refresh = uibutton(toolbar, 'Text', 'Refresh from GT', ...
    'Enable', localOnOff(~isempty(p.Results.OnRefresh)), ...
    'ButtonPushedFcn', @(~,~) runRefresh());
refresh.Tooltip = 'Reload the current cell model and rebuild this tree.';
uibutton(toolbar, 'Text', 'Close', ...
    'ButtonPushedFcn', @(~,~) delete(fig));

% Keep enough physical room for each track label.  A conventional axes
% would squeeze a large lineage (Project47 can exceed 170 tracks) into the
% window width, making the numeric IDs overlap even though their data-space
% lanes are distinct.  The oversized grid provides a horizontal scrollbar
% while preserving a stable minimum number of pixels per lineage lane.
laneWidthPixels = 22;
maxLane = max([nodes.x]);
canvasWidth = max(1180, ceil((maxLane + 1) * laneWidthPixels));
canvas = uigridlayout(grid, [1 1]);
canvas.Padding = [0 0 0 0];
canvas.RowSpacing = 0;
canvas.ColumnSpacing = 0;
canvas.Scrollable = 'on';
canvas.RowHeight = {'1x'};
canvas.ColumnWidth = {canvasWidth};

ax = uiaxes(canvas);
hold(ax, 'on');
ax.Color = [0.08 0.08 0.09];
ax.XColor = [0.75 0.75 0.75];
ax.YColor = [0.75 0.75 0.75];
ax.YDir = 'reverse';
ax.XTick = [];
ax.Box = 'on';
ax.Toolbar.Visible = 'on';
ylabel(ax, 'Frame');
title(ax, 'Click a TrackID or a vertical line to show its birth in Score', ...
    'Color', [0.85 0.85 0.85]);

for i = 1:numel(edges)
    color = score_trackColor(edges(i).child_track_id);
    line(ax, [edges(i).parent_x edges(i).child_x], ...
        [edges(i).event_frame edges(i).event_frame], ...
        'Color', color, 'LineWidth', 1.5, ...
        'HitTest', 'off', 'PickableParts', 'none');
end
for i = 1:numel(nodes)
    id = nodes(i).track_id;
    color = score_trackColor(id);
    width = 4;
    weight = 'normal';
    if isfinite(p.Results.SelectedTrackId) && ...
            uint64(p.Results.SelectedTrackId) == id
        width = 7;
        weight = 'bold';
    end
    line(ax, [nodes(i).x nodes(i).x], ...
        [nodes(i).first_frame nodes(i).last_frame], ...
        'Color', color, 'LineWidth', width, ...
        'ButtonDownFcn', @(~,~) selectTrack(id), ...
        'PickableParts', 'visible', 'HitTest', 'on');
    text(ax, nodes(i).x, nodes(i).first_frame, sprintf('%u', id), ...
        'Color', color, 'FontWeight', weight, ...
        'FontSize', 10, ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0.08 0.08 0.09], 'Margin', 1, ...
        'ButtonDownFcn', @(~,~) selectTrack(id), ...
        'PickableParts', 'all', 'HitTest', 'on');
end
fitView();

    function fitView()
        maxX = max([nodes.x]);
        minY = min([nodes.first_frame]);
        maxY = max([nodes.last_frame]);
        yPad = max(1, 0.025 * max(maxY - minY, 1));
        xlim(ax, [0.25 maxX + 0.75]);
        ylim(ax, [max(0.5, minY - yPad) maxY + yPad]);
    end

    function selectTrack(id)
        if isempty(p.Results.OnTrackSelected), return; end
        p.Results.OnTrackSelected(double(id));
    end

    function runRefresh()
        if isempty(p.Results.OnRefresh), return; end
        p.Results.OnRefresh();
    end
end

function value = localOnOff(tf)
if tf, value = 'on'; else, value = 'off'; end
end

function text = localSummary(diagnostics)
warningCount = size(diagnostics.ignored_missing_or_self_relations, 1) + ...
    size(diagnostics.ignored_duplicate_parent_relations, 1) + ...
    size(diagnostics.ignored_cycle_relations, 1);
text = sprintf('%d tracks | %d links | %d roots | %d ignored relation(s)', ...
    diagnostics.track_count, diagnostics.edge_count, ...
    diagnostics.root_count, warningCount);
end

function text = localDiagnosticTooltip(diagnostics)
text = sprintf(['Missing/self: %d; duplicate parent: %d; cycle: %d. ' ...
    'Ignored relations remain unchanged in the GT.'], ...
    size(diagnostics.ignored_missing_or_self_relations, 1), ...
    size(diagnostics.ignored_duplicate_parent_relations, 1), ...
    size(diagnostics.ignored_cycle_relations, 1));
end
