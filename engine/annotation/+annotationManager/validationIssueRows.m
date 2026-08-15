function rows = validationIssueRows(report)
%ANNOTATIONMANAGER.VALIDATIONISSUEROWS Normalize validation output for UIs.

rows = emptyRows();
structured = struct([]);
if isstruct(report) && isfield(report, 'issues') && ~isempty(report.issues)
    structured = report.issues;
end

for i = 1:numel(structured)
    issue = structured(i);
    role = char(string(issue.role));
    summary = sprintf('Missing %s track', role);
    rows(end+1,1) = makeRow( ...
        'Parentage', char(string(issue.code)), summary, ...
        char(string(issue.message)), double(issue.focus_frame), ...
        double(issue.focus_track_id), double(issue.missing_track_id), ...
        true, i); %#ok<AGROW>
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
        firstFrame(message), NaN, NaN, false, 0); %#ok<AGROW>
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
        relatedTrack, missingTrack, repairable, issueIndex)
row = struct( ...
    'component', char(string(component)), ...
    'code', char(string(code)), ...
    'summary', char(string(summary)), ...
    'message', char(string(message)), ...
    'frame', double(frame), ...
    'related_track', double(relatedTrack), ...
    'missing_track', double(missingTrack), ...
    'repairable', logical(repairable), ...
    'issue_index', double(issueIndex));
end

function rows = emptyRows()
rows = repmat(makeRow('', '', '', '', NaN, NaN, NaN, false, 0), 0, 1);
end
