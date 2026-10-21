function segments = cellModelLineageSegments(model, familyId, frame, masks, includeAncestors, plane)
%CELLMODELLINEAGESEGMENTS Resolve current and historical lineage endpoints.
% Historical endpoints use the last observed mask, never a current mask with
% the same label. Only ancestors of tracks visible now are retained.
% Binary fission instead joins the two currently visible sisters once,
% without projecting an extinct parent's old position onto the image.
% Accept the full ROI image with a plane index to avoid copying an entire
% time-series channel on every display refresh.
if nargin < 6, plane = 1; end
segments = struct('relationRow',{},'parentTrack',{},'childTrack',{}, ...
    'parentLabel',{},'childLabel',{},'parentFrame',{},'childFrame',{}, ...
    'parentXY',{},'childXY',{},'historical',{},'siblingTracks',{});
rows = find(model.instances.family_id == uint32(familyId));
relations = find(model.relations.family_id == uint32(familyId));
now = rows(model.instances.frame(rows) == uint32(frame));
if frame < 1 || frame > size(masks,4), return; end
labels = unique(masks(:,:,plane,frame));
now = now(ismember(double(model.instances.mask_label(now)), double(labels(labels > 0))));
visibleTracks = unique(model.instances.track_id(now));
visibleTracks(visibleTracks == 0) = [];
cache = containers.Map('KeyType','uint64','ValueType','any');
if strcmp(cellModel.divisionMode(model,familyId),'binary_fission')
    pending = relations(double(model.relations.event_frame(relations)) <= frame);
    while ~isempty(pending)
        k = pending(1);
        parentTrack = model.relations.parent_track_id(k);
        event = model.relations.event_frame(k);
        paired = pending(model.relations.parent_track_id(pending) == parentTrack & ...
            model.relations.event_frame(pending) == event);
        pending = setdiff(pending,paired,'stable');
        children = model.relations.child_track_id(paired);
        if numel(children) ~= 2 || numel(unique(children)) ~= 2 || ...
                ~all(ismember(children,visibleTracks))
            continue;
        end
        parentRows = rows(model.instances.track_id(rows) == parentTrack);
        if isempty(parentRows) || any(model.instances.frame(parentRows) >= event)
            continue;
        end
        births = zeros(1,2);
        for c = 1:2
            births(c) = min(double(model.instances.frame(rows( ...
                model.instances.track_id(rows) == children(c)))));
        end
        if any(births ~= double(event)), continue; end
        first = endpoint(children(1)); second = endpoint(children(2));
        if isempty(first) || isempty(second), continue; end
        % Endpoint field names are shared with ordinary parent/child links;
        % siblingTracks identifies the two symmetric image endpoints.
        segments(end+1) = struct('relationRow',k, ... %#ok<AGROW>
            'parentTrack',parentTrack,'childTrack',children(2), ...
            'parentLabel',first.label,'childLabel',second.label, ...
            'parentFrame',frame,'childFrame',frame, ...
            'parentXY',first.xy,'childXY',second.xy,'historical',false, ...
            'siblingTracks',reshape(children,1,[]));
    end
    return;
end
relevantTracks = visibleTracks;
if includeAncestors
    % Restrict traversal to events that have already occurred. The visited
    % set also bounds traversal if an optional model contains a cycle.
    past = relations(double(model.relations.event_frame(relations)) <= frame);
    while true
        parents = model.relations.parent_track_id(past( ...
            ismember(model.relations.child_track_id(past), relevantTracks)));
        expanded = union(relevantTracks, parents);
        if numel(expanded) == numel(relevantTracks), break; end
        relevantTracks = expanded;
    end
end
for k = relations(:).'
    if includeAncestors && double(model.relations.event_frame(k)) > frame
        continue;
    end
    childTrack = model.relations.child_track_id(k);
    parentTrack = model.relations.parent_track_id(k);
    if ~ismember(childTrack, relevantTracks), continue; end
    child = endpoint(childTrack);
    parent = endpoint(parentTrack);
    if isempty(child) || isempty(parent), continue; end
    historical = child.frame < frame || parent.frame < frame;
    if historical && double(model.relations.event_frame(k)) > frame
        continue;
    end
    segments(end+1) = struct('relationRow',k, ... %#ok<AGROW>
        'parentTrack',parentTrack,'childTrack',childTrack, ...
        'parentLabel',parent.label,'childLabel',child.label, ...
        'parentFrame',parent.frame,'childFrame',child.frame, ...
        'parentXY',parent.xy,'childXY',child.xy,'historical',historical, ...
        'siblingTracks',uint64([]));
end

    function point = endpoint(track)
        if isKey(cache,track), point = cache(track); return; end
        point = [];
        candidates = rows(model.instances.track_id(rows) == track & ...
            double(model.instances.frame(rows)) <= frame);
        if ~isempty(candidates)
            [observedFrame,index] = max(double(model.instances.frame(candidates)));
            row = candidates(index);
            label = model.instances.mask_label(row);
            if label > 0 && observedFrame >= 1 && observedFrame <= size(masks,4)
                [y,x] = find(masks(:,:,plane,observedFrame) == double(label));
                if ~isempty(x)
                    point = struct('frame',observedFrame,'label',label, ...
                        'xy',[mean(x) mean(y)]);
                end
            end
        end
        cache(track) = point;
    end
end
