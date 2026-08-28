function report = reviewHints(classif, roiObj, varargin)
%ANNOTATIONMANAGER.REVIEWHINTS Load external, navigable review findings.
% Classifier-local review_hints*.json files are advisory evidence. They never
% edit GT or change validation validity; Score may display them next
% to ordinary validation errors and navigate to its ROI/frame/track.

p = inputParser;
p.addParameter('ReviewFrames', [], @isnumeric);
p.addParameter('ResolveFamily', true, @(x)islogical(x) && isscalar(x));
p.parse(varargin{:});

report = struct( ...
    'valid', true, ...
    'errors', strings(0,1), ...
    'warnings', strings(0,1), ...
    'issues', annotationManager.emptyValidationIssues(), ...
    'sourcePath', '', ...
    'sourceId', '', ...
    'resolved', 0, ...
    'total', 0);

root = char(string(classif.path));
paths = hintPaths(root);
if isempty(paths)
    report.sourcePath = fullfile(root, 'review_hints.json');
    return;
end
report.sourcePath = strjoin(paths, pathsep);
roiId = char(string(roiObj.id));
reviewFrames = unique(round(double(p.Results.ReviewFrames(:).')));
familyId = uint32(0);
model = [];
if p.Results.ResolveFamily
    [familyId, model] = reviewedFamily(roiObj, classif);
end
sourceIds = strings(0,1);
for fileIndex = 1:numel(paths)
    payload = jsondecode(fileread(paths{fileIndex}));
    validateClassifier(payload, classif);
    if isfield(payload, 'source_id')
        sourceIds(end+1,1) = string(payload.source_id); %#ok<AGROW>
    end
    if ~isfield(payload, 'items') || isempty(payload.items), continue; end
    items = payload.items;
    for i = 1:numel(items)
        item = items(i);
        if ~strcmpi(fieldText(item, 'roi_id', ''), roiId), continue; end
        frame = fieldDouble(item, 'frame', NaN);
        if ~isempty(reviewFrames) && ~ismember(frame, reviewFrames), continue; end
        if ~isfinite(frame) || frame < 1, continue; end

        decision = lower(fieldText(item, 'decision', 'review'));
        child = positiveUint64(fieldDouble(item, 'child_track_id', NaN));
        parent = positiveUint64(fieldDouble(item, 'parent_track_id', NaN));
        eventId = fieldText(item, 'hint_id', fieldText(item, 'event_id', ''));
        note = fieldText(item, 'note', '');
        scope = decisionScope(decision);
        if latentDecisionResolved(model, familyId, child, decision) || ...
                (~isempty(model) && familyId > 0 && child > 0 && scope > 0 && ...
                cellModel.isCensored(model, familyId, child, frame, scope))
            report.resolved = report.resolved + 1;
            continue;
        end
        summary = decisionSummary(decision, child, parent);
        component = 'Prior review';
        if startsWith(decision, 'latent_')
            component = 'Latent v4 suggestion';
            message = sprintf([ ...
                'Target-free latent v4 review proposal %s at frame %d ' ...
                '(child Track %s, proposed parent Track %s).'], ...
                eventId, round(frame), trackText(child), trackText(parent));
        else
            message = sprintf([ ...
                'Imported review hint %s at frame %d (child Track %s, ' ...
                'parent Track %s). Decision: %s.'], ...
                eventId, round(frame), trackText(child), trackText(parent), decision);
        end
        if ~isempty(note), message = sprintf('%s %s', message, note); end

        issue = annotationManager.newValidationIssue( ...
            'code', ['external_review_' decision], ...
            'severity', 'warning', ...
            'component', component, ...
            'summary', summary, ...
            'message', message, ...
            'role', decision, ...
            'family_id', familyId, ...
            'event_frame', uint32(round(frame)), ...
            'focus_frame', uint32(round(frame)), ...
            'parent_track_id', parent, ...
            'child_track_id', child, ...
            'focus_track_id', child, ...
            'suggested_censor', scope > 0 && familyId > 0 && child > 0, ...
            'suggested_scope_flags', uint16(scope), ...
            'suggested_reason', decisionReason(decision), ...
            'suggested_frame_start', uint32(round(frame)), ...
            'suggested_frame_end', uint32(round(frame)), ...
            'suggestion_confidence', itemConfidence(item, decision), ...
            'repairable', false);
        report.issues(end+1,1) = issue;
    end
end
report.sourceId = char(strjoin(unique(sourceIds, 'stable'), ' + '));
report.total = numel(report.issues);
end

function paths = hintPaths(root)
listing = dir(fullfile(root, 'review_hints*.json'));
listing = listing(~[listing.isdir]);
[~, order] = sort(lower(string({listing.name})));
listing = listing(order);
paths = arrayfun(@(x) fullfile(x.folder, x.name), listing, ...
    'UniformOutput', false);
end

function validateClassifier(payload, classif)
if isfield(payload, 'classifier_id') && ...
        ~strcmp(char(string(payload.classifier_id)), char(string(classif.strid)))
    error('annotationManager:ReviewHintsClassifierMismatch', ...
        'Review hints target classifier "%s", not "%s".', ...
        char(string(payload.classifier_id)), char(string(classif.strid)));
end
end

function tf = latentDecisionResolved(model, familyId, child, decision)
tf = false;
if ~startsWith(decision, 'latent_') || isempty(model) || ...
        familyId < 1 || child < 1
    return;
end
childExists = any(model.instances.family_id == familyId & ...
    model.instances.track_id == child);
if ~childExists
    % The prediction was made on an older track tensor and is no longer
    % actionable after human identity correction.
    tf = true;
    return;
end
% Any explicit human parent for this child takes precedence over a model
% proposal, even when it differs from latent top-1.
tf = any(model.relations.family_id == familyId & ...
    model.relations.type_id == uint8(1) & ...
    model.relations.child_track_id == child);
end

function value = decisionReason(decision)
switch decision
    case 'ambiguous'
        value = 'ambiguous_parentage';
    case 'tracking_error'
        value = 'ambiguous_identity';
    case 'skip'
        value = 'other';
    otherwise
        value = '';
end
end

function value = hintConfidence(decision)
if any(strcmp(decision, {'ambiguous','tracking_error','skip'}))
    value = 1.0; % An imported human review decision, not model confidence.
else
    value = NaN;
end
end

function [familyId, model] = reviewedFamily(roiObj, classif)
familyId = uint32(0);
model = [];
try
    spec = annotationManager.specForClassifier(classif);
    rows = find(strcmp({spec.components.storage}, 'cell_model_family'));
    if isempty(rows), return; end
    [model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
    for i = rows(:).'
        [index, candidate] = cellModel.familyIndex( ...
            model, spec.components(i).groundTruth.family);
        if ~isempty(index)
            familyId = uint32(candidate);
            return;
        end
    end
catch
    model = [];
end
end

function scope = decisionScope(decision)
switch decision
    case 'ambiguous'
        scope = cellModel.censorScope('parentage');
    case 'tracking_error'
        scope = cellModel.censorScope('tracking');
    case 'skip'
        scope = cellModel.censorScope('all');
    otherwise
        % "not_bud" is a useful reviewed NULL decision, not a censor.
        scope = uint16(0);
end
end

function text = decisionSummary(decision, child, parent)
if nargin < 3, parent = uint64(0); end
switch decision
    case 'tracking_error'
        label = 'Tracking error reported';
    case 'ambiguous'
        label = 'Ambiguous parentage reported';
    case 'not_bud'
        label = 'Candidate reported as not a bud';
    case 'skip'
        label = 'Event skipped during prior review';
    case 'latent_parent'
        label = sprintf('Proposed mother Track %s', trackText(parent));
    case 'latent_null'
        label = 'Predicted NULL/unlinked — confirm visually';
    case 'latent_unscored'
        label = 'Unscored birth — manual parentage review required';
    otherwise
        label = 'Prior review finding';
end
if child > 0
    text = sprintf('%s — child Track %u', label, child);
else
    text = label;
end
end

function value = itemConfidence(item, decision)
value = fieldDouble(item, 'suggestion_confidence', NaN);
if isfinite(value), return; end
value = hintConfidence(decision);
end

function value = fieldText(item, name, fallback)
value = fallback;
if isfield(item, name) && ~isempty(item.(name))
    value = char(string(item.(name)));
end
end

function value = fieldDouble(item, name, fallback)
value = fallback;
if isfield(item, name) && ~isempty(item.(name))
    candidate = double(item.(name));
    if isscalar(candidate), value = candidate; end
end
end

function value = positiveUint64(value)
if ~isfinite(value) || value < 1
    value = uint64(0);
else
    value = uint64(round(value));
end
end

function value = trackText(value)
if value < 1, value = '?'; else, value = sprintf('%u', value); end
end
