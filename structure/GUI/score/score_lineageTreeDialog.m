function fig = score_lineageTreeDialog(model, familyId, varargin)
%SCORE_LINEAGETREEDIALOG Persistent, clickable asymmetric genealogy view.
% Dense lineages use a fixed-size axes and a lane navigator.  This avoids
% browser-renderer canvas limits caused by an ever-wider scrollable axes,
% while centering the initially selected TrackID whenever possible.

p = inputParser;
addParameter(p, 'OnTrackSelected', [], @(x) isempty(x) || isa(x, 'function_handle'));
addParameter(p, 'OnRefresh', [], @(x) isempty(x) || isa(x, 'function_handle'));
addParameter(p, 'SelectedTrackId', NaN, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Title', 'Lineage tree', @(x) ischar(x) || isstring(x));
addParameter(p, 'ViewKey', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Owner', [], @(x) true);
addParameter(p, 'ReviewBounds', [], @(x) isempty(x) || ...
    (isnumeric(x) && numel(x) == 2 && all(isfinite(x))));
parse(p, varargin{:});

reviewBounds = localNormalizeReviewBounds(p.Results.ReviewBounds);

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
previousView = struct('laneStart', [], 'yLim', []);
if isempty(existing) || ~isvalid(existing(1))
    fig = uifigure('Name', char(string(p.Results.Title)), ...
        'Tag', tag, 'Position', [80 80 1250 780], ...
        'Color', [0.97 0.97 0.97]);
else
    fig = existing(1);
    if localHasSameView(fig, p.Results.ViewKey)
        previousView = localCaptureView(fig);
    end
    fig.Name = char(string(p.Results.Title));
    fig.Visible = 'on';
    delete(fig.Children);
end
fig.UserData = struct( ...
    'owner', p.Results.Owner, ...
    'viewKey', char(string(p.Results.ViewKey)));
grid = uigridlayout(fig, [3 1]);
grid.RowHeight = {42, '1x', 38};
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

% Display a bounded number of lanes at once.  Making the UIAxes itself as
% wide as the complete lineage eventually exceeds the browser renderer's
% maximum off-screen canvas size on dense ROIs.  A fixed canvas plus an
% explicit lane navigator keeps labels readable without that size limit.
maxLane = max([nodes.x]);
visibleLaneCount = min(52, maxLane);
maxWindowStart = max(1, maxLane - visibleLaneCount + 1);
initialWindowStart = localInitialWindowStart( ...
    nodes, p.Results.SelectedTrackId, visibleLaneCount, maxWindowStart);
if ~isempty(previousView.laneStart) && isfinite(previousView.laneStart)
    initialWindowStart = min(max(round(previousView.laneStart), 1), ...
        maxWindowStart);
end

ax = uiaxes(grid);
ax.Tag = 'ScoreLineageTreeAxes';
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
if ~isempty(reviewBounds)
    reviewStart = yline(ax, reviewBounds(1), '--', ...
        sprintf(' Review start: %d', reviewBounds(1)), ...
        'Color', [1 1 1], 'LineWidth', 1.25);
    reviewStart.Tag = 'ScoreLineageReviewStart';
    reviewStart.LabelHorizontalAlignment = 'left';
    reviewStart.HitTest = 'off';
    reviewStart.PickableParts = 'none';

    reviewEnd = yline(ax, reviewBounds(2), '--', ...
        sprintf(' Review end: %d', reviewBounds(2)), ...
        'Color', [1 1 1], 'LineWidth', 1.25);
    reviewEnd.Tag = 'ScoreLineageReviewEnd';
    reviewEnd.LabelHorizontalAlignment = 'left';
    reviewEnd.HitTest = 'off';
    reviewEnd.PickableParts = 'none';
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

navigator = uigridlayout(grid, [1 4]);
navigator.Padding = [4 0 4 0];
navigator.ColumnWidth = {80, '1x', 175, 80};
uibutton(navigator, 'Text', '< Previous', ...
    'Enable', localOnOff(maxWindowStart > 1), ...
    'ButtonPushedFcn', @(~,~) shiftWindow(-1));
sliderLimits = [1 max(2, maxWindowStart)];
laneSlider = uislider(navigator, 'Limits', sliderLimits, ...
    'Value', initialWindowStart, 'MajorTicks', [], 'MinorTicks', [], ...
    'Enable', localOnOff(maxWindowStart > 1), ...
    'ValueChangingFcn', @(~,event) showWindow(event.Value), ...
    'ValueChangedFcn', @(~,event) showWindow(event.Value));
laneSlider.Tag = 'ScoreLineageTreeLaneSlider';
windowLabel = uilabel(navigator, 'HorizontalAlignment', 'center');
uibutton(navigator, 'Text', 'Next >', ...
    'Enable', localOnOff(maxWindowStart > 1), ...
    'ButtonPushedFcn', @(~,~) shiftWindow(1));

fitView();
if numel(previousView.yLim) == 2 && all(isfinite(previousView.yLim)) && ...
        previousView.yLim(1) < previousView.yLim(2)
    ylim(ax, previousView.yLim);
end

    function fitView()
        minY = min([nodes.first_frame]);
        maxY = max([nodes.last_frame]);
        if ~isempty(reviewBounds)
            minY = min(minY, reviewBounds(1));
            maxY = max(maxY, reviewBounds(2));
        end
        yPad = max(1, 0.025 * max(maxY - minY, 1));
        ylim(ax, [max(0.5, minY - yPad) maxY + yPad]);
        showWindow(initialWindowStart);
    end

    function showWindow(value)
        windowStart = min(max(round(double(value)), 1), maxWindowStart);
        if maxWindowStart <= 1
            xlim(ax, [0.25 maxLane + 0.75]);
            windowLabel.Text = sprintf('All %d lineage lanes', maxLane);
        else
            windowEnd = min(maxLane, windowStart + visibleLaneCount - 1);
            xlim(ax, [windowStart - 0.5 windowEnd + 0.5]);
            laneSlider.Value = windowStart;
            windowLabel.Text = sprintf('Lineage lanes %d-%d of %d', ...
                windowStart, windowEnd, maxLane);
        end
    end

    function shiftWindow(direction)
        pageStep = max(1, floor(visibleLaneCount * 0.8));
        showWindow(laneSlider.Value + direction * pageStep);
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

function bounds = localNormalizeReviewBounds(value)
bounds = [];
if isempty(value), return; end
bounds = round(double(value(:).'));
if bounds(1) < 1 || bounds(2) < bounds(1)
    error('score:InvalidReviewBounds', ...
        'ReviewBounds must be an inclusive increasing frame interval.');
end
end

function tf = localHasSameView(fig, viewKey)
tf = false;
viewKey = char(string(viewKey));
if isempty(viewKey), return; end
try
    metadata = fig.UserData;
    tf = isstruct(metadata) && isfield(metadata, 'viewKey') && ...
        strcmp(char(string(metadata.viewKey)), viewKey);
catch
end
end

function state = localCaptureView(fig)
state = struct('laneStart', [], 'yLim', []);
try
    slider = findall(fig, 'Tag', 'ScoreLineageTreeLaneSlider');
    if ~isempty(slider) && isvalid(slider(1))
        state.laneStart = double(slider(1).Value);
    end
catch
end
try
    ax = findall(fig, 'Tag', 'ScoreLineageTreeAxes');
    if ~isempty(ax) && isvalid(ax(1))
        state.yLim = double(ax(1).YLim);
    end
catch
end
end

function value = localInitialWindowStart( ...
    nodes, selectedTrackId, visibleLaneCount, maxWindowStart)
value = 1;
if ~isfinite(selectedTrackId) || maxWindowStart <= 1
    return;
end
trackIds = [nodes.track_id];
index = find(trackIds == uint64(selectedTrackId), 1, 'first');
if isempty(index), return; end
selectedX = nodes(index).x;
value = min(max(round(selectedX - visibleLaneCount / 2), 1), ...
    maxWindowStart);
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
