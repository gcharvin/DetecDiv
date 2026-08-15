function result = annotationValidationDialog(parentFigure, report)
%ANNOTATIONVALIDATIONDIALOG Select and act on one validation issue.

rows = annotationManager.validationIssueRows(report);
result = struct('action', 'close', 'row', 0, 'issueIndex', 0, ...
    'frame', NaN, 'relatedTrack', NaN);
if isempty(rows), return; end

figureHandle = uifigure('Name', 'Annotation validation issues', ...
    'Position', [100 100 940 520], 'Resize', 'on', ...
    'WindowStyle', 'modal', 'Visible', 'off');
figureHandle.CloseRequestFcn = @closeDialog;
layout = uigridlayout(figureHandle, [4 1]);
layout.RowHeight = {30, '1x', 100, 38};
layout.Padding = [12 12 12 12];
layout.RowSpacing = 8;

summaryLabel = uilabel(layout, 'Text', sprintf( ...
    '%d issue(s). Select a row to inspect or repair it.', numel(rows)), ...
    'FontWeight', 'bold');
summaryLabel.Layout.Row = 1;

tableHandle = uitable(layout);
tableHandle.Layout.Row = 2;
tableHandle.ColumnName = {'Component','Problem','Frame', ...
    'Related track','Missing track'};
tableHandle.ColumnEditable = false(1,5);
tableHandle.ColumnWidth = {105, 470, 70, 100, 100};
tableHandle.RowName = {};
tableHandle.Data = tableData(rows);
tableHandle.CellSelectionCallback = @selectRow;

detail = uitextarea(layout, 'Editable', 'off');
detail.Layout.Row = 3;

buttonLayout = uigridlayout(layout, [1 5]);
buttonLayout.Layout.Row = 4;
buttonLayout.ColumnWidth = {150, 175, 190, '1x', 90};
buttonLayout.Padding = [0 0 0 0];
goButton = uibutton(buttonLayout, 'Text', 'Go to selected', ...
    'ButtonPushedFcn', @(~,~) finish('go'));
repairButton = uibutton(buttonLayout, 'Text', 'Repair selected link', ...
    'ButtonPushedFcn', @(~,~) finish('repair'));
repairAllButton = uibutton(buttonLayout, 'Text', 'Repair all broken links', ...
    'ButtonPushedFcn', @(~,~) finish('repair_all'));
uilabel(buttonLayout, 'Text', '');
uibutton(buttonLayout, 'Text', 'Close', ...
    'ButtonPushedFcn', @(~,~) finish('close'));

selectedRow = 1;
tableHandle.Selection = [1 1];
refreshSelection();
positionNearParent(figureHandle, parentFigure);
figureHandle.Visible = 'on';
uiwait(figureHandle);
if isvalid(figureHandle), delete(figureHandle); end

    function selectRow(~, event)
        if isempty(event.Indices), return; end
        selectedRow = event.Indices(1,1);
        refreshSelection();
    end

    function refreshSelection()
        row = rows(selectedRow);
        detail.Value = cellstr(splitlines(string(row.message)));
        goButton.Enable = onOff(isfinite(row.frame) && row.frame > 0);
        repairButton.Enable = onOff(row.repairable);
        repairAllButton.Enable = onOff(any([rows.repairable]));
    end

    function finish(action)
        result.action = action;
        result.row = selectedRow;
        result.issueIndex = rows(selectedRow).issue_index;
        result.frame = rows(selectedRow).frame;
        result.relatedTrack = rows(selectedRow).related_track;
        uiresume(figureHandle);
    end

    function closeDialog(~, ~)
        result.action = 'close';
        result.row = selectedRow;
        result.issueIndex = rows(selectedRow).issue_index;
        result.frame = rows(selectedRow).frame;
        result.relatedTrack = rows(selectedRow).related_track;
        uiresume(figureHandle);
    end
end

function data = tableData(rows)
data = cell(numel(rows), 5);
for i = 1:numel(rows)
    data{i,1} = rows(i).component;
    data{i,2} = rows(i).summary;
    data{i,3} = numberText(rows(i).frame);
    data{i,4} = trackText(rows(i).related_track);
    data{i,5} = trackText(rows(i).missing_track);
end
end

function value = numberText(value)
if ~isfinite(value) || value < 1
    value = '';
else
    value = sprintf('%d', round(value));
end
end

function value = trackText(value)
if ~isfinite(value) || value < 1
    value = '';
else
    value = sprintf('Track %d', round(value));
end
end

function value = onOff(tf)
if tf, value = 'on'; else, value = 'off'; end
end

function positionNearParent(figureHandle, parentFigure)
try
    parentPosition = parentFigure.Position;
    figurePosition = figureHandle.Position;
    figurePosition(1) = parentPosition(1) + ...
        max(0, (parentPosition(3) - figurePosition(3)) / 2);
    figurePosition(2) = parentPosition(2) + ...
        max(0, (parentPosition(4) - figurePosition(4)) / 2);
    figureHandle.Position = figurePosition;
catch
    movegui(figureHandle, 'center');
end
end
