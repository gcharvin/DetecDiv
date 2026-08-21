function [overrides, accepted] = annotationInputMappingDialog(parent, plan)
%ANNOTATIONINPUTMAPPINGDIALOG Ask only for ambiguous/missing model inputs.

requests = annotationInputMappingRequests(plan);
itemCount = 1;
try, itemCount = max(1, numel(plan.items)); catch, end
template = struct('instanceChannelName', '', 'brightfieldChannelName', '', ...
    'nucleusChannelName', '', 'budneckChannelName', '');
overrides = repmat(template, 1, itemCount);
accepted = false;
if isempty(requests), return; end

height = min(680, 205 + 58 * numel(requests));
fig = uifigure('Name', 'Resolve model inputs', ...
    'Position', [100 100 720 height], 'Resize', 'off', ...
    'WindowStyle', 'modal', 'CloseRequestFcn', @cancelDialog);
positionNearParent(fig, parent);
grid = uigridlayout(fig, [numel(requests) + 3, 2]);
grid.ColumnWidth = {230, '1x'};
grid.RowHeight = [{55}, repmat({42}, 1, numel(requests)), {50, 38}];
grid.Padding = [18 15 18 15];
grid.RowSpacing = 8;

intro = uilabel(grid, 'Text', [ ...
    'Only unresolved inputs are shown. Ground-truth channels are forbidden ' ...
    'and are never offered as inference inputs.'], 'WordWrap', 'on', ...
    'FontWeight', 'bold');
intro.Layout.Row = 1;
intro.Layout.Column = [1 2];

dropDowns = gobjects(numel(requests), 1);
for i = 1:numel(requests)
    label = uilabel(grid, 'Text', sprintf('%s — %s', ...
        requests(i).roiId, requests(i).label), 'WordWrap', 'on');
    label.Layout.Row = i + 1;
    label.Layout.Column = 1;
    dropDowns(i) = uidropdown(grid, 'Items', requests(i).candidates, ...
        'ItemsData', requests(i).candidates);
    dropDowns(i).Layout.Row = i + 1;
    dropDowns(i).Layout.Column = 2;
end

note = uilabel(grid, 'Text', [ ...
    'The selected mapping applies only to this prediction run. ' ...
    'The resulting GT remains Draft until you review and validate it.'], ...
    'WordWrap', 'on', 'FontColor', [0.35 0.35 0.35]);
note.Layout.Row = numel(requests) + 2;
note.Layout.Column = [1 2];

buttons = uigridlayout(grid, [1 3]);
buttons.Layout.Row = numel(requests) + 3;
buttons.Layout.Column = [1 2];
buttons.ColumnWidth = {'1x', 100, 150};
buttons.Padding = [0 0 0 0];
cancel = uibutton(buttons, 'Text', 'Cancel', ...
    'ButtonPushedFcn', @cancelDialog); %#ok<NASGU>
cancel.Layout.Column = 2;
run = uibutton(buttons, 'Text', 'Use these inputs', ...
    'FontWeight', 'bold', 'ButtonPushedFcn', @acceptDialog); %#ok<NASGU>
run.Layout.Column = 3;

uiwait(fig);
if isvalid(fig), delete(fig); end

    function acceptDialog(~, ~)
        for requestIndex = 1:numel(requests)
            position = requests(requestIndex).roiPosition;
            selector = requests(requestIndex).selector;
            if ~isfield(overrides(position), selector)
                uialert(fig, sprintf('Unsupported input selector: %s', selector), ...
                    'Resolve model inputs', 'Icon', 'error');
                return;
            end
            overrides(position).(selector) = char(string( ...
                dropDowns(requestIndex).Value));
        end
        accepted = true;
        uiresume(fig);
    end

    function cancelDialog(~, ~)
        accepted = false;
        if isvalid(fig), uiresume(fig); end
    end
end

function positionNearParent(fig, parent)
try
    parentFigure = ancestor(parent, 'figure');
    p = parentFigure.Position;
    f = fig.Position;
    f(1) = p(1) + max(0, (p(3) - f(3)) / 2);
    f(2) = p(2) + max(0, (p(4) - f(4)) / 2);
    fig.Position = f;
catch
    movegui(fig, 'center');
end
end
