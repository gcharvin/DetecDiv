function report = validateParentage(model, family, varargin)
%ANNOTATIONMANAGER.VALIDATEPARENTAGE Validate parent relations for one family.

p = inputParser;
p.addParameter('Throw', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Frames', [], @isnumeric);
p.parse(varargin{:});

errors = strings(0,1);
issues = emptyIssues();
[familyIndex, familyId] = cellModel.familyIndex(model, family);
if isempty(familyIndex)
    errors(end+1,1) = "Ground-truth object family is missing.";
else
    relationRows = model.relations.family_id == familyId & ...
        model.relations.type_id == uint8(1);
    if ~isempty(p.Results.Frames)
        relationRows = relationRows & ismember( ...
            double(model.relations.event_frame),double(p.Results.Frames));
    end
    parents = model.relations.parent_track_id(relationRows);
    children = model.relations.child_track_id(relationRows);

    if any(parents == 0 | children == 0 | parents == children)
        errors(end+1,1) = ...
            "Parentage contains an invalid parent/child identity.";
    end
    if numel(unique(children)) ~= numel(children)
        errors(end+1,1) = "A child track has more than one parent.";
    end

    familyTracks = unique(model.instances.track_id( ...
        model.instances.family_id == familyId));
    familyTracks = familyTracks(familyTracks > 0);
    relationIndices = find(relationRows);
    missingParent = ~ismember(parents, familyTracks);
    missingChild = ~ismember(children, familyTracks);
    for i = find(missingParent(:)).'
        issues(end+1,1) = missingTrackIssue(model, familyId, ... %#ok<AGROW>
            relationIndices(i), 'parent', parents(i), children(i));
    end
    for i = find(missingChild(:)).'
        issues(end+1,1) = missingTrackIssue(model, familyId, ... %#ok<AGROW>
            relationIndices(i), 'child', children(i), parents(i));
    end
    if ~isempty(issues)
        previewCount = min(8, numel(issues));
        errors = [errors; string({issues(1:previewCount).message}).']; %#ok<AGROW>
        if numel(issues) > previewCount
            errors(end+1,1) = sprintf( ...
                '%d additional invalid parentage reference(s) were omitted.', ...
                numel(issues) - previewCount);
        end
    end

    if ~isempty(parents)
        graphValue = digraph(double(parents), double(children));
        if ~isdag(graphValue)
            errors(end+1,1) = "Parentage contains a cycle.";
        end
    end
end

report = struct('valid', isempty(errors), 'errors', errors, ...
    'familyId', familyId, 'issues', issues);
if p.Results.Throw && ~report.valid
    error('annotationManager:InvalidParentage', '%s', ...
        strjoin(report.errors, ' '));
end

function issue = missingTrackIssue(model, familyId, relationIndex, role, ...
        missingTrackId, counterpartTrackId)
eventFrame = double(model.relations.event_frame(relationIndex));
focusFrame = nearestTrackFrame(model, familyId, counterpartTrackId, eventFrame);
counterpartRole = 'child';
repairHint = 'remove or reassign its parent';
if strcmp(role, 'child')
    counterpartRole = 'parent';
    repairHint = 'remove the stale relation or restore its child';
end

if focusFrame > 0
    location = sprintf('Open frame %u and inspect %s Track %u', ...
        uint32(focusFrame), counterpartRole, uint64(counterpartTrackId));
else
    location = sprintf('Inspect %s Track %u', ...
        counterpartRole, uint64(counterpartTrackId));
end
message = sprintf([ ...
    'Missing %s Track %u: %s Track %u references it at parentage event ' ...
    'frame %u, but Track %u has no object in this GT family. %s, then %s.'], ...
    role, uint64(missingTrackId), counterpartRole, ...
    uint64(counterpartTrackId), uint32(eventFrame), ...
    uint64(missingTrackId), location, repairHint);

issue = struct( ...
    'code', 'missing_track_reference', ...
    'message', message, ...
    'role', role, ...
    'relation_id', model.relations.relation_id(relationIndex), ...
    'family_id', familyId, ...
    'event_frame', uint32(eventFrame), ...
    'missing_track_id', uint64(missingTrackId), ...
    'parent_track_id', model.relations.parent_track_id(relationIndex), ...
    'child_track_id', model.relations.child_track_id(relationIndex), ...
    'focus_track_id', uint64(counterpartTrackId), ...
    'focus_frame', uint32(max(0, focusFrame)));
end

function frame = nearestTrackFrame(model, familyId, trackId, eventFrame)
rows = model.instances.family_id == familyId & ...
    model.instances.track_id == uint64(trackId);
frames = double(model.instances.frame(rows));
if isempty(frames)
    frame = 0;
    return;
end
[~, index] = min(abs(frames - eventFrame));
frame = frames(index);
end

function issues = emptyIssues()
issues = repmat(struct( ...
    'code', '', ...
    'message', '', ...
    'role', '', ...
    'relation_id', uint64(0), ...
    'family_id', uint32(0), ...
    'event_frame', uint32(0), ...
    'missing_track_id', uint64(0), ...
    'parent_track_id', uint64(0), ...
    'child_track_id', uint64(0), ...
    'focus_track_id', uint64(0), ...
    'focus_frame', uint32(0)), 0, 1);
end
end
