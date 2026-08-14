function report = validateParentage(model, family, varargin)
%ANNOTATIONMANAGER.VALIDATEPARENTAGE Validate parent relations for one family.

p = inputParser;
p.addParameter('Throw', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Frames', [], @isnumeric);
p.parse(varargin{:});

errors = strings(0,1);
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
    missingTracks = unique([parents(~ismember(parents, familyTracks)); ...
        children(~ismember(children, familyTracks))]);
    if ~isempty(missingTracks)
        preview = strjoin(string(missingTracks( ...
            1:min(8, numel(missingTracks)))), ', ');
        if numel(missingTracks) > 8, preview = preview + ", ..."; end
        errors(end+1,1) = sprintf( ...
            'Parentage references track(s) that do not exist: %s.', preview);
    end

    if ~isempty(parents)
        graphValue = digraph(double(parents), double(children));
        if ~isdag(graphValue)
            errors(end+1,1) = "Parentage contains a cycle.";
        end
    end
end

report = struct('valid', isempty(errors), 'errors', errors, ...
    'familyId', familyId);
if p.Results.Throw && ~report.valid
    error('annotationManager:InvalidParentage', '%s', ...
        strjoin(report.errors, ' '));
end
end
