function rows = validationIssueRows(report)
%ANNOTATIONMANAGER.VALIDATIONISSUEROWS Normalize validation output for UIs.

rows = emptyRows();
structured = struct([]);
if isstruct(report) && isfield(report, 'issues') && ~isempty(report.issues)
    structured = report.issues;
end

for i = 1:numel(structured)
    issue = structured(i);
    role = fieldText(issue, 'role', '');
    summary = fieldText(issue, 'summary', '');
    if isempty(summary)
        summary = sprintf('Missing %s track', role);
    end
    component = fieldText(issue, 'component', 'Parentage');
    severity = fieldText(issue, 'severity', 'error');
    repairable = fieldLogical(issue, 'repairable', ...
        strcmp(fieldText(issue, 'code', ''), 'missing_track_reference'));
    row = makeRow( ...
        component, fieldText(issue, 'code', ''), summary, ...
        fieldText(issue, 'message', ''), ...
        fieldDouble(issue, 'focus_frame', fieldDouble(issue, 'event_frame', NaN)), ...
        fieldDouble(issue, 'focus_track_id', NaN), ...
        positiveOrNaN(fieldDouble(issue, 'missing_track_id', NaN)), ...
        repairable, i, severity);
    row.suggested_censor = fieldLogical(issue, 'suggested_censor', false);
    rows(end+1,1) = row; %#ok<AGROW>
end

errors = strings(0,1);
if isstruct(report) && isfield(report, 'errors') && ~isempty(report.errors)
    errors = string(report.errors(:));
end
for i = 1:numel(errors)
    message = strtrim(errors(i));
    if message == "", continue; end
    if isStructuredDuplicate(message, structured), continue; end
    [component, summary] = genericSummary(message);
    rows(end+1,1) = makeRow( ...
        component, 'validation_error', summary, char(message), ...
        firstFrame(message), NaN, NaN, false, 0, 'error'); %#ok<AGROW>
end

warnings = strings(0,1);
if isstruct(report) && isfield(report, 'warnings') && ~isempty(report.warnings)
    warnings = string(report.warnings(:));
end
for i = 1:numel(warnings)
    message = strtrim(warnings(i));
    if message == "", continue; end
    if isStructuredDuplicate(message, structured), continue; end
    [component, summary] = genericSummary(message);
    rows(end+1,1) = makeRow( ...
        component, 'validation_warning', summary, char(message), ...
        firstFrame(message), NaN, NaN, false, 0, 'warning'); %#ok<AGROW>
end

% Blocking findings must never be buried below a long advisory queue.
% Keep the ordering stable inside each severity group so issue_index still
% points to the exact structured issue used by Go/Repair callbacks.
if ~isempty(rows)
    blocking = strcmpi(string({rows.severity}), 'error');
    rows = [rows(blocking); rows(~blocking)];
end
end

function tf = isStructuredDuplicate(message, issues)
tf = false;
for i = 1:numel(issues)
    if contains(message, string(issues(i).message))
        tf = true;
        return;
    end
end
end

function [component, summary] = genericSummary(message)
component = 'Validation';
summary = char(message);
token = regexp(char(message), '^([^:]+):\s*(.*)$', 'tokens', 'once');
if ~isempty(token)
    component = humanLabel(token{1});
    summary = token{2};
elseif startsWith(message, 'Component "')
    component = 'Coverage';
end
summary = compactText(summary, 100);
end

function value = humanLabel(value)
value = strrep(char(string(value)), '_', ' ');
value = strtrim(value);
if isempty(value), value = 'Validation'; return; end
value(1) = upper(value(1));
end

function frame = firstFrame(message)
frame = NaN;
token = regexp(char(message), 'frame\s*[:#]?\s*(\d+)', ...
    'tokens', 'once', 'ignorecase');
if ~isempty(token), frame = str2double(token{1}); end
end

function value = compactText(value, limit)
value = strtrim(char(string(value)));
if strlength(string(value)) <= limit, return; end
value = [value(1:max(1, limit-3)) '...'];
end

function row = makeRow(component, code, summary, message, frame, ...
        relatedTrack, missingTrack, repairable, issueIndex, severity)
row = struct( ...
    'severity', char(string(severity)), ...
    'component', char(string(component)), ...
    'code', char(string(code)), ...
    'summary', char(string(summary)), ...
    'message', char(string(message)), ...
    'frame', double(frame), ...
    'related_track', double(relatedTrack), ...
    'missing_track', double(missingTrack), ...
    'repairable', logical(repairable), ...
    'suggested_censor', false, ...
    'issue_index', double(issueIndex));
end

function rows = emptyRows()
rows = repmat(makeRow('', '', '', '', NaN, NaN, NaN, false, 0, ''), 0, 1);
end

function value = fieldText(issue, name, fallback)
value = fallback;
if isfield(issue, name) && ~isempty(issue.(name))
    value = char(string(issue.(name)));
end
end

function value = fieldDouble(issue, name, fallback)
value = fallback;
if isfield(issue, name) && ~isempty(issue.(name))
    candidate = double(issue.(name));
    if isscalar(candidate), value = candidate; end
end
end

function value = fieldLogical(issue, name, fallback)
value = fallback;
if isfield(issue, name) && ~isempty(issue.(name))
    value = logical(issue.(name));
end
end

function value = positiveOrNaN(value)
if ~isfinite(value) || value <= 0, value = NaN; end
end
