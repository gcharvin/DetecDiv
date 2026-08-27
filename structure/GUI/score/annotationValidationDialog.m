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
p.addParameter('OnAcceptCensor', [], @(x)isempty(x) || isa(x,'function_handle'));
p.addParameter('OnKeepUsable', [], @(x)isempty(x) || isa(x,'function_handle'));
p.addParameter('Title', 'Annotation validation findings', ...
    @(x)ischar(x) || (isstring(x) && isscalar(x)));
p.parse(varargin{:});
persistentMode = p.Results.Persistent;

rows = annotationManager.validationIssueRows(report);
result = struct('action', 'close', 'row', 0, 'issueIndex', 0, ...
    'frame', NaN, 'relatedTrack', NaN);
if isempty(rows), return; end

figureHandle = uifigure('Name', char(string(p.Results.Title)), ...
    'Position', [100 100 1280 540], 'Resize', 'on', ...
    'WindowStyle', windowStyle(persistentMode), 'Visible', 'off');
figureHandle.Tag = 'ScoreAnnotationFindings';
figureHandle.CloseRequestFcn = @closeDialog;
layout = uigridlayout(figureHandle, [4 1]);
layout.RowHeight = {30, '1x', 100, 38};
layout.Padding = [12 12 12 12];
layout.RowSpacing = 8;

[summaryText, ~, ~] = reportSummary(rows);
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

buttonLayout = uigridlayout(layout, [1 7]);
buttonLayout.Layout.Row = 4;
buttonLayout.ColumnWidth = {140, 170, 185, 180, 145, '1x', 80};
buttonLayout.Padding = [0 0 0 0];
goButton = uibutton(buttonLayout, 'Text', 'Go to selected', ...
    'ButtonPushedFcn', @(~,~) finish('go'));
repairButton = uibutton(buttonLayout, 'Text', 'Repair selected link', ...
    'ButtonPushedFcn', @(~,~) finish('repair'));
repairAllButton = uibutton(buttonLayout, 'Text', 'Repair all broken links', ...
    'ButtonPushedFcn', @(~,~) finish('repair_all'));
acceptCensorButton = uibutton(buttonLayout, ...
    'Text', 'Censor as suggested [C]', ...
    'ButtonPushedFcn', @(~,~) finish('accept_censor'));
keepUsableButton = uibutton(buttonLayout, ...
    'Text', 'Keep usable [K]', ...
    'ButtonPushedFcn', @(~,~) finish('keep_usable'));
refreshButton = uibutton(buttonLayout, 'Text', 'Refresh', ...
    'ButtonPushedFcn', @(~,~) refreshDialog());
refreshButton.Enable = onOff(persistentMode && ~isempty(p.Results.OnRefresh));
uibutton(buttonLayout, 'Text', 'Close', ...
    'ButtonPushedFcn', @(~,~) finish('close'));

selectedRow = 1;
refreshing = false;
figureHandle.KeyPressFcn = @keyPressed;
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
        detailLines = splitlines(string(row.message));
        if row.suggested_censor && row.issue_index >= 1 && ...
                row.issue_index <= numel(report.issues)
            issue = report.issues(row.issue_index);
            detailLines(end+1,1) = "";
            detailLines(end+1,1) = string(sprintf( ...
                'Suggested action: censor %s, frames %u-%u; reason: %s.', ...
                scopeText(issue.suggested_scope_flags), ...
                uint32(issue.suggested_frame_start), ...
                uint32(issue.suggested_frame_end), ...
                humanText(issue.suggested_reason)));
            if isfinite(double(issue.suggestion_confidence))
                detailLines(end+1,1) = string(sprintf( ...
                    'Suggestion confidence: %.0f%%. No GT changes until you accept.', ...
                    100 * double(issue.suggestion_confidence)));
            end
        end
        detail.Value = cellstr(detailLines);
        goButton.Enable = onOff(isfinite(row.frame) && row.frame > 0);
        repairButton.Enable = onOff(row.repairable);
        repairAllButton.Enable = onOff(any([rows.repairable]));
        actionable = row.suggested_censor && persistentMode;
        acceptCensorButton.Enable = onOff(actionable && ...
            ~isempty(p.Results.OnAcceptCensor));
        keepUsableButton.Enable = onOff(actionable && ...
            ~isempty(p.Results.OnKeepUsable));
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
            case 'accept_censor'
                if isempty(p.Results.OnAcceptCensor) || isempty(issue) || ...
                        ~rows(selectedRow).suggested_censor, return; end
                updated = p.Results.OnAcceptCensor(issue);
                applyUpdatedReport(updated);
            case 'keep_usable'
                if isempty(p.Results.OnKeepUsable) || isempty(issue) || ...
                        ~rows(selectedRow).suggested_censor, return; end
                updated = p.Results.OnKeepUsable(issue);
                applyUpdatedReport(updated);
            otherwise
                delete(figureHandle);
        end
    end

    function keyPressed(~, event)
        if isempty(rows), return; end
        switch lower(char(string(event.Key)))
            case 'c'
                if strcmp(char(acceptCensorButton.Enable), 'on')
                    finish('accept_censor');
                end
            case 'k'
                if strcmp(char(keepUsableButton.Enable), 'on')
                    finish('keep_usable');
                end
            case 'r'
                if strcmp(char(refreshButton.Enable), 'on'), refreshDialog(); end
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
suggestionCount = nnz([rows.suggested_censor]);
if errorCount == 0
    text = sprintf([ ...
        'Validation passed. %d advisory warning(s); warnings do not ' ...
        'block Ready status or training.'], warningCount);
else
    text = sprintf( ...
        '%d error(s), %d warning(s). Select a row to inspect it.', ...
        errorCount, warningCount);
end
if suggestionCount > 0
    text = sprintf('%s %d censor suggestion(s) await a decision.', ...
        text, suggestionCount);
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

function text = scopeText(flags)
names = {'segmentation','tracking','appearance','end','parentage','state'};
selected = strings(0,1);
for i = 1:numel(names)
    if bitand(uint16(flags),cellModel.censorScope(names{i})) ~= 0
        selected(end+1,1) = string(names{i}); %#ok<AGROW>
    end
end
if isempty(selected), text = 'unspecified task';
else, text = char(strjoin(selected, ' + '));
end
end

function value = humanText(value)
value = strrep(char(string(value)),'_',' ');
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
