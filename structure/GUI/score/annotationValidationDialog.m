function result = annotationValidationDialog(parentFigure, report, varargin)
%ANNOTATIONVALIDATIONDIALOG Inspect and act on navigable validation findings.
% By default this preserves the historical modal/result contract.  The
% persistent mode is non-modal: Go invokes OnGo without closing the window,
% so Score can navigate and select the implicated cell while the table stays
% available.

p = inputParser;
p.addParameter('Persistent', false, @(x)islogical(x) && isscalar(x));
p.addParameter('OnGo', [], @(x)isempty(x) || isa(x,'function_handle'));
p.addParameter('OnRepair', [], @(x)isempty(x) || isa(x,'function_handle'));
p.addParameter('OnRepairAll', [], @(x)isempty(x) || isa(x,'function_handle'));
p.addParameter('OnRefresh', [], @(x)isempty(x) || isa(x,'function_handle'));
p.addParameter('OnIsStale', [], @(x)isempty(x) || isa(x,'function_handle'));
p.addParameter('Title', 'Annotation validation findings', ...
    @(x)ischar(x) || (isstring(x) && isscalar(x)));
p.parse(varargin{:});
persistentMode = p.Results.Persistent;

rows = annotationManager.validationIssueRows(report);
result = struct('action', 'close', 'row', 0, 'issueIndex', 0, ...
    'frame', NaN, 'relatedTrack', NaN);
if isempty(rows), return; end

figureHandle = uifigure('Name', char(string(p.Results.Title)), ...
    'Position', [100 100 1010 520], 'Resize', 'on', ...
    'WindowStyle', windowStyle(persistentMode), 'Visible', 'off');
figureHandle.Tag = 'ScoreAnnotationFindings';
figureHandle.CloseRequestFcn = @closeDialog;
layout = uigridlayout(figureHandle, [4 1]);
layout.RowHeight = {30, '1x', 100, 38};
layout.Padding = [12 12 12 12];
layout.RowSpacing = 8;

warningCount = nnz(strcmpi({rows.severity}, 'warning'));
errorCount = numel(rows) - warningCount;
if errorCount == 0
    summaryText = sprintf([ ...
        'Validation passed. %d advisory warning(s); warnings do not ' ...
        'block Ready status or training.'], warningCount);
else
    summaryText = sprintf( ...
        '%d error(s), %d warning(s). Select a row to inspect it.', ...
        errorCount, warningCount);
end
summaryLabel = uilabel(layout, 'Text', summaryText, ...
    'FontWeight', 'bold');
summaryLabel.Layout.Row = 1;

tableHandle = uitable(layout);
tableHandle.Layout.Row = 2;
tableHandle.ColumnName = {'Severity','Component','Problem','Frame', ...
    'Related track','Missing track'};
tableHandle.ColumnEditable = false(1,6);
tableHandle.ColumnWidth = {75, 105, 470, 70, 100, 100};
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
refreshButton = uibutton(buttonLayout, 'Text', 'Refresh', ...
    'ButtonPushedFcn', @(~,~) refreshDialog());
refreshButton.Enable = onOff(persistentMode && ~isempty(p.Results.OnRefresh));
uibutton(buttonLayout, 'Text', 'Close', ...
    'ButtonPushedFcn', @(~,~) finish('close'));

selectedRow = 1;
refreshing = false;
tableHandle.Selection = [1 1];
refreshSelection();
positionNearParent(figureHandle, parentFigure);
figureHandle.Visible = 'on';
if persistentMode
    figureHandle.WindowButtonDownFcn = @refreshIfStale;
    % Let App Designer finish painting the table before returning control to
    % Score.  Without this yield, a large findings list can remain visually
    % blank while subsequent Score refreshes compete for the graphics queue.
    drawnow;
    result = figureHandle;
    return;
end
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
        if persistentMode
            actPersistent(action);
            return;
        end
        result.action = action;
        result.row = selectedRow;
        result.issueIndex = rows(selectedRow).issue_index;
        result.frame = rows(selectedRow).frame;
        result.relatedTrack = rows(selectedRow).related_track;
        uiresume(figureHandle);
    end

    function closeDialog(~, ~)
        if persistentMode
            delete(figureHandle);
            return;
        end
        result.action = 'close';
        result.row = selectedRow;
        result.issueIndex = rows(selectedRow).issue_index;
        result.frame = rows(selectedRow).frame;
        result.relatedTrack = rows(selectedRow).related_track;
        uiresume(figureHandle);
    end

    function actPersistent(action)
        if isempty(rows), return; end
        issueIndex = rows(selectedRow).issue_index;
        issue = struct([]);
        if issueIndex >= 1 && isfield(report, 'issues') && ...
                issueIndex <= numel(report.issues)
            issue = report.issues(issueIndex);
        end
        switch action
            case 'go'
                if ~isempty(p.Results.OnGo)
                    p.Results.OnGo(issue, rows(selectedRow));
                end
            case 'repair'
                if isempty(p.Results.OnRepair) || isempty(issue), return; end
                updated = p.Results.OnRepair(issue);
                applyUpdatedReport(updated);
            case 'repair_all'
                if isempty(p.Results.OnRepairAll), return; end
                repairable = false(size(report.issues));
                for k = 1:numel(report.issues)
                    try
                        repairable(k) = logical(report.issues(k).repairable);
                    catch
                    end
                end
                updated = p.Results.OnRepairAll(report.issues(repairable));
                applyUpdatedReport(updated);
            otherwise
                delete(figureHandle);
        end
    end

    function applyUpdatedReport(updated)
        if ~isstruct(updated) || ~isfield(updated, 'issues'), return; end
        report = updated;
        rows = annotationManager.validationIssueRows(report);
        if isempty(rows)
            delete(figureHandle);
            return;
        end
        selectedRow = min(selectedRow, numel(rows));
        tableHandle.Data = tableData(rows);
        tableHandle.Selection = [selectedRow 1];
        [summaryText, ~, ~] = reportSummary(rows);
        summaryLabel.Text = summaryText;
        refreshSelection();
    end

    function refreshIfStale(~, ~)
        if refreshing || isempty(p.Results.OnRefresh), return; end
        stale = true;
        if ~isempty(p.Results.OnIsStale)
            try
                stale = logical(p.Results.OnIsStale());
            catch
                stale = true;
            end
        end
        if stale, refreshDialog(); end
    end

    function refreshDialog()
        if refreshing || isempty(p.Results.OnRefresh), return; end
        refreshing = true;
        oldSummary = summaryLabel.Text;
        summaryLabel.Text = 'Refreshing findings after GT changes...';
        try, figureHandle.Pointer = 'watch'; catch, end
        drawnow limitrate;
        try
            updated = p.Results.OnRefresh();
            applyUpdatedReport(updated);
        catch ME
            if isvalid(figureHandle)
                summaryLabel.Text = oldSummary;
                detail.Value = cellstr(splitlines(string(ME.message)));
            end
        end
        if isvalid(figureHandle)
            try, figureHandle.Pointer = 'arrow'; catch, end
        end
        refreshing = false;
    end
end

function style = windowStyle(persistentMode)
if persistentMode, style = 'normal'; else, style = 'modal'; end
end

function [text, warningCount, errorCount] = reportSummary(rows)
warningCount = nnz(strcmpi({rows.severity}, 'warning'));
errorCount = numel(rows) - warningCount;
if errorCount == 0
    text = sprintf([ ...
        'Validation passed. %d advisory warning(s); warnings do not ' ...
        'block Ready status or training.'], warningCount);
else
    text = sprintf( ...
        '%d error(s), %d warning(s). Select a row to inspect it.', ...
        errorCount, warningCount);
end
end

function data = tableData(rows)
data = cell(numel(rows), 6);
for i = 1:numel(rows)
    data{i,1} = severityText(rows(i).severity);
    data{i,2} = rows(i).component;
    data{i,3} = rows(i).summary;
    data{i,4} = numberText(rows(i).frame);
    data{i,5} = trackText(rows(i).related_track);
    data{i,6} = trackText(rows(i).missing_track);
end
end

function value = severityText(value)
value = lower(char(string(value)));
if isempty(value), value = 'issue'; end
value(1) = upper(value(1));
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
