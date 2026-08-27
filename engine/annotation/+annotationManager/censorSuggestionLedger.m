function [ledger, record] = censorSuggestionLedger(classif, roiObj, varargin)
%ANNOTATIONMANAGER.CENSORSUGGESTIONLEDGER Read or record UI triage decisions.
% This classifier-local ledger is deliberately separate from GT. A "keep"
% decision only hides a repeated suggestion; it never changes training data.

p = inputParser;
p.addParameter('Issue', struct([]), @isstruct);
p.addParameter('Decision', '', @(x)ischar(x) || (isstring(x) && isscalar(x)));
p.parse(varargin{:});

path = fullfile(char(string(classif.path)), ...
    'censor_suggestion_decisions.json');
ledger = emptyLedger(classif);
if exist(path, 'file') == 2
    try
        loaded = jsondecode(fileread(path));
        if isstruct(loaded), ledger = normalizeLedger(loaded, classif); end
    catch ME
        error('annotationManager:CensorSuggestionLedgerInvalid', ...
            'Cannot read censor suggestion decisions: %s', ME.message);
    end
end
record = struct([]);
decision = lower(strtrim(char(string(p.Results.Decision))));
if isempty(decision), return; end
if ~any(strcmp(decision, {'keep','censored'}))
    error('annotationManager:CensorSuggestionDecision', ...
        'Decision must be "keep" or "censored".');
end
issue = p.Results.Issue;
if isempty(issue) || ~isfield(issue, 'suggested_censor') || ...
        ~logical(issue.suggested_censor)
    error('annotationManager:NotCensorSuggestion', ...
        'The selected finding is not a censor suggestion.');
end
suggestionId = char(string(issue.suggestion_id));
if isempty(suggestionId)
    suggestionId = annotationManager.censorSuggestionId(roiObj, issue);
end
roiId = char(string(roiObj.id));
record = struct( ...
    'suggestion_id', suggestionId, ...
    'roi_id', roiId, ...
    'decision', decision, ...
    'decided_at', char(datetime('now','TimeZone','UTC', ...
        'Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX')), ...
    'code', char(string(issue.code)), ...
    'track_id', double(issue.focus_track_id), ...
    'frame_start', double(issue.suggested_frame_start), ...
    'frame_end', double(issue.suggested_frame_end), ...
    'scope_flags', double(issue.suggested_scope_flags), ...
    'reason', char(string(issue.suggested_reason)));
items = ledger.items;
if isempty(items)
    items = record;
else
    match = strcmp(string({items.suggestion_id}), string(suggestionId));
    items(match) = [];
    items(end+1,1) = record;
end
ledger.items = items;
ledger.updated_at = record.decided_at;
writeAtomic(path, ledger);
end

function ledger = emptyLedger(classif)
ledger = struct( ...
    'schema_version', 'detecdiv_censor_suggestion_decisions_v001', ...
    'classifier_id', char(string(classif.strid)), ...
    'updated_at', '', ...
    'items', repmat(emptyRecord(), 0, 1));
end

function ledger = normalizeLedger(value, classif)
ledger = emptyLedger(classif);
if isfield(value, 'classifier_id') && ...
        ~strcmp(char(string(value.classifier_id)), char(string(classif.strid)))
    error('annotationManager:CensorSuggestionLedgerClassifierMismatch', ...
        'Censor suggestion decisions target another classifier.');
end
if isfield(value, 'updated_at'), ledger.updated_at = char(string(value.updated_at)); end
if ~isfield(value, 'items') || isempty(value.items), return; end
raw = value.items;
items = repmat(emptyRecord(), numel(raw), 1);
names = fieldnames(items);
for i = 1:numel(raw)
    for k = 1:numel(names)
        if isfield(raw(i), names{k}), items(i).(names{k}) = raw(i).(names{k}); end
    end
end
ledger.items = items;
end

function value = emptyRecord()
value = struct('suggestion_id','','roi_id','','decision','', ...
    'decided_at','','code','','track_id',0,'frame_start',0, ...
    'frame_end',0,'scope_flags',0,'reason','');
end

function writeAtomic(path, value)
folder = fileparts(path);
if exist(folder, 'dir') ~= 7, mkdir(folder); end
temporary = [tempname(folder) '.json'];
cleanup = onCleanup(@() deleteIfPresent(temporary)); %#ok<NASGU>
fid = fopen(temporary, 'w');
if fid < 0
    error('annotationManager:CensorSuggestionLedgerWrite', ...
        'Cannot create temporary decision ledger.');
end
closeFile = onCleanup(@() fclose(fid));
fwrite(fid, unicode2native(jsonencode(value), 'UTF-8'), 'uint8');
clear closeFile;
[ok,message] = movefile(temporary, path, 'f');
if ~ok
    error('annotationManager:CensorSuggestionLedgerWrite', '%s', message);
end
end

function deleteIfPresent(path)
if exist(path, 'file') == 2, delete(path); end
end
