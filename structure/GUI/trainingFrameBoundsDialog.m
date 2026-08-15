function result = trainingFrameBoundsDialog(parent, classif, selectedIndices)
%TRAININGFRAMEBOUNDSDIALOG Configure persistent training frames in one place.

if nargin < 3, selectedIndices = []; end
result = struct('accepted', false, 'scope', 'training', ...
    'mode', 'all', 'roiIndices', [], 'bounds', []);

fig = uifigure('Name', 'Training frames', 'WindowStyle', 'modal', ...
    'Resize', 'off', 'Position', centeredPosition(parent, [500 310]), ...
    'CloseRequestFcn', @cancelDialog);
grid = uigridlayout(fig, [7 2]);
grid.RowHeight = {52, 28, 28, 28, 28, '1x', 34};
grid.ColumnWidth = {155, '1x'};
grid.Padding = [14 12 14 12];
grid.RowSpacing = 8;

intro = uilabel(grid, 'Text', [ ...
    'These persistent bounds are the only frames used by dataset formatting. ' ...
    'The default is all frames.']);
intro.Layout.Row = 1;
intro.Layout.Column = [1 2];
intro.WordWrap = 'on';

uilabel(grid, 'Text', 'Apply to:', 'HorizontalAlignment', 'right');
scope = uidropdown(grid, ...
    'Items', {'All training ROIs','Selected table rows','All imported ROIs'}, ...
    'ItemsData', {'training','selected','all'}, ...
    'Value', 'training', 'ValueChangedFcn', @refreshControls);

uilabel(grid, 'Text', 'Frame mode:', 'HorizontalAlignment', 'right');
mode = uidropdown(grid, ...
    'Items', {'All frames','Same range','Edit each ROI in the table'}, ...
    'ItemsData', {'all','range','per_roi'}, ...
    'Value', defaultMode(classif), 'ValueChangedFcn', @refreshControls);

uilabel(grid, 'Text', 'First frame:', 'HorizontalAlignment', 'right');
firstFrame = uieditfield(grid, 'numeric', 'Limits', [1 Inf], ...
    'RoundFractionalValues', 'on', 'Value', 1, ...
    'ValueChangedFcn', @refreshControls);

uilabel(grid, 'Text', 'Last frame:', 'HorizontalAlignment', 'right');
lastFrame = uieditfield(grid, 'numeric', 'Limits', [1 Inf], ...
    'RoundFractionalValues', 'on', 'Value', suggestedLastFrame(classif), ...
    'ValueChangedFcn', @refreshControls);

summary = uilabel(grid, 'Text', '', 'WordWrap', 'on', ...
    'FontColor', [0.25 0.25 0.25]);
summary.Layout.Row = 6;
summary.Layout.Column = [1 2];

buttons = uigridlayout(grid, [1 3]);
buttons.Layout.Row = 7;
buttons.Layout.Column = [1 2];
buttons.ColumnWidth = {'1x', 110, 110};
buttons.Padding = [0 0 0 0];
uilabel(buttons, 'Text', '');
uibutton(buttons, 'Text', 'Cancel', 'ButtonPushedFcn', @cancelDialog);
applyButton = uibutton(buttons, 'Text', 'Apply', ...
    'ButtonPushedFcn', @applyDialog);

initializeRangeFromExisting();
refreshControls();
uiwait(fig);
if isvalid(fig), delete(fig); end

    function initializeRangeFromExisting()
        cfg = [];
        try cfg = classif.bounds; catch, end
        try
            if isstruct(cfg) && strcmpi(char(string(cfg.Type)), 'Auto') && ...
                    isfield(cfg, 'Values') && ~isempty(cfg.Values)
                bounds = trainingBounds.parse(cfg.Values);
                firstFrame.Value = bounds(1);
                lastFrame.Value = bounds(2);
            end
        catch
        end
    end

    function refreshControls(varargin)
        isRange = strcmp(mode.Value, 'range');
        isPerRoi = strcmp(mode.Value, 'per_roi');
        firstFrame.Enable = onOff(isRange);
        lastFrame.Enable = onOff(isRange);
        scope.Enable = onOff(~isPerRoi);
        if isPerRoi
            applyButton.Text = 'Use table';
            summary.Text = [ ...
                'Per-ROI mode keeps existing values. After closing, edit the ' ...
                'Frame bounds cells directly; enter "all" to clear one ROI.'];
            return;
        end
        indices = scopedIndices(scope.Value);
        if isempty(indices)
            summary.Text = 'The selected scope currently contains no ROI.';
            return;
        end
        ids = string({classif.roi(indices).id});
        if numel(ids) > 3
            idText = sprintf('%s, %s, %s, ...', ids(1), ids(2), ids(3));
        else
            idText = char(strjoin(ids, ', '));
        end
        if isRange
            actionText = sprintf('frames %d:%d', ...
                round(firstFrame.Value), round(lastFrame.Value));
        else
            actionText = 'all frames';
        end
        summary.Text = sprintf('Will apply %s to %d ROI(s): %s', ...
            actionText, numel(indices), idText);
        applyButton.Text = 'Apply';
    end

    function applyDialog(~, ~)
        selectedMode = char(string(mode.Value));
        indices = scopedIndices(scope.Value);
        bounds = [];
        if strcmp(selectedMode, 'range')
            bounds = round([firstFrame.Value lastFrame.Value]);
            if bounds(2) < bounds(1)
                uialert(fig, 'Last frame must be greater than or equal to first frame.', ...
                    'Invalid frame range');
                return;
            end
        elseif ~strcmp(selectedMode, 'per_roi') && isempty(indices)
            uialert(fig, 'The selected scope contains no ROI.', ...
                'No ROI selected');
            return;
        end
        result = struct('accepted', true, ...
            'scope', char(string(scope.Value)), ...
            'mode', selectedMode, 'roiIndices', indices, 'bounds', bounds);
        uiresume(fig);
        delete(fig);
    end

    function cancelDialog(~, ~)
        if isvalid(fig), uiresume(fig); delete(fig); end
    end

    function indices = scopedIndices(value)
        switch char(string(value))
            case 'training'
                indices = [];
                try indices = double(classif.trainingset(:).'); catch, end
                if isempty(indices)
                    try indices = double(classif.getTrainingROIIndices()); catch, end
                end
            case 'selected'
                indices = selectedIndices;
            otherwise
                indices = 1:numel(classif.roi);
        end
        indices = unique(round(double(indices(:).')), 'stable');
        indices = indices(isfinite(indices) & indices >= 1 & ...
            indices <= numel(classif.roi));
    end
end

function mode = defaultMode(classif)
mode = 'all';
try
    cfg = classif.bounds;
    if strcmpi(char(string(cfg.Type)), 'Manual') && ...
            isfield(cfg, 'RoiValues') && ~isempty(cfg.RoiValues)
        mode = 'per_roi';
    elseif strcmpi(char(string(cfg.Type)), 'Auto') && ...
            isfield(cfg, 'Values') && ~isempty(cfg.Values)
        mode = 'range';
    end
catch
end
end

function value = suggestedLastFrame(classif)
value = 1;
for i = 1:numel(classif.roi)
    count = 0;
    try count = annotationManager.frameCount(classif.roi(i)); catch, end
    if count < 1
        try count = size(classif.roi(i).image, 4); catch, end
    end
    value = max(value, round(double(count)));
end
end

function value = onOff(condition)
if condition, value = 'on'; else, value = 'off'; end
end

function position = centeredPosition(parent, sizeValue)
position = [100 100 sizeValue(1) sizeValue(2)];
try
    parentPosition = parent.Position;
    position(1) = parentPosition(1) + (parentPosition(3) - sizeValue(1)) / 2;
    position(2) = parentPosition(2) + (parentPosition(4) - sizeValue(2)) / 2;
catch
end
end
