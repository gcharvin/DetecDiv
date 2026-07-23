function result = infer(tracks, param, roiId)
%BUDMOTHERLINKER.INFER Native MATLAB HGB-16 bud/mother inference.

if nargin < 3 || isempty(roiId), roiId = 'roi'; end
tracks = uint32(tracks);
if param.frameEnd > 0
    tracks = tracks(:,:,1:min(size(tracks,3), param.frameEnd));
end
[stats, newTracks] = trackStatistics(tracks);
geometry = budMotherLinker.Lyn16Geometry(tracks, 8);
[modelInfo, manifestFile] = loadModelInfo(param);
threshold = double(modelInfo.rank_margin_threshold);
if isfield(param, 'rankMarginThreshold') && param.rankMarginThreshold >= 0
    threshold = double(param.rankMarginThreshold);
end
guardEnabled = logical(param.trackingLoadGuard);
maxNewTracks = double(param.maxNewTracksPerFrame);

eligible = find(stats.start > 1 & stats.frames >= param.minLifetime & ...
    stats.birthArea <= param.maxBirthArea);
if ~isempty(eligible)
    order = sortrows([stats.start(eligible), eligible(:)], [1 2]);
    eligible = order(:,2);
end
edges = repmat(edgeTemplate(), 0, 1);

for eventIndex = 1:numel(eligible)
    child = eligible(eventIndex) - 1;
    frame = stats.start(child + 1);
    current = tracks(:,:,frame);
    previous = tracks(:,:,frame - 1);
    childMask = current == uint32(child);
    [yy, xx] = find(childMask);
    childCentre = [mean(xx), mean(yy)];
    currentLabels = unique(current(:));
    currentLabels = double(currentLabels(currentLabels > 0));
    previousLabels = unique(previous(:));
    previousLabels = double(previousLabels(previousLabels > 0));
    parentIds = intersect(currentLabels, previousLabels);

    rough = zeros(0,2);
    for i = 1:numel(parentIds)
        parent = parentIds(i);
        if parent == child || stats.start(parent + 1) > frame - param.minParentAge
            continue;
        end
        [py, px] = find(current == uint32(parent));
        distance = norm(childCentre - [mean(px), mean(py)]);
        if distance <= param.maxParentCentroidDistance
            rough(end+1,:) = [distance, parent]; %#ok<AGROW>
        end
    end
    rough = sortrows(rough, [1 2]);
    rough = rough(1:min(size(rough,1), param.maxCandidates * 3),:);

    candidates = repmat(candidateTemplate(), 0, 1);
    for i = 1:size(rough,1)
        parent = rough(i,2);
        parentMask = current == uint32(parent);
        contourDistance = min(pdist2(geometry.contour(child, frame), ...
            geometry.contour(parent, frame)), [], 'all');
        if contourDistance > param.maxParentContourDistance, continue; end
        contact = nnz(childMask & imdilate(parentMask, ...
            [0 1 0; 1 1 1; 0 1 0]));
        candidate = candidateTemplate();
        candidate.parent_track_id = parent;
        candidate.candidate_score = contourDistance + ...
            0.03 * rough(i,1) - 0.05 * min(contact,20);
        candidate.centroid_distance = rough(i,1);
        candidate.contour_distance = contourDistance;
        candidate.contact_pixels = contact;
        candidate.parent_age_frames = frame - stats.start(parent + 1);
        candidate.parent_area = nnz(parentMask);
        candidates(end+1,1) = candidate; %#ok<AGROW>
    end
    if ~isempty(candidates)
        sorting = [[candidates.candidate_score]', ...
            [candidates.contour_distance]', [candidates.parent_track_id]'];
        [~, order] = sortrows(sorting, [1 2 3]);
        candidates = candidates(order(1:min(numel(order),param.maxCandidates)));
    end

    edge = edgeTemplate();
    edge.event_id = sprintf('%s_c%u_f%u', roiId, child, frame);
    edge.roi = char(string(roiId));
    edge.child_track_id = child;
    edge.bud_appearance_frame = frame;
    edge.lifetime = stats.frames(child + 1);
    edge.birth_area = stats.birthArea(child + 1);
    edge.candidate_count = numel(candidates);
    edge.new_tracks_at_birth = newTracks(frame);

    if isempty(candidates)
        edge.reason = 'no_candidate';
        edge.reason_code = edge.reason;
        edges(end+1,1) = edge; %#ok<AGROW>
        continue;
    end

    selectedFrames = frame:min(frame + 7, size(tracks,3));
    if numel(selectedFrames) < 2
        edge.reason = 'feature_error:not_enough_frames';
        edge.reason_code = 'feature_error';
        edges(end+1,1) = edge; %#ok<AGROW>
        continue;
    end
    if any(arrayfun(@(f) ~geometry.hasCell(child,f), selectedFrames))
        missing = selectedFrames(find(arrayfun( ...
            @(f) ~geometry.hasCell(child,f), selectedFrames), 1));
        edge.reason = sprintf('feature_error:bud_missing_at_%u', missing);
        edge.reason_code = 'feature_error';
        edges(end+1,1) = edge; %#ok<AGROW>
        continue;
    end

    featureMatrix = zeros(numel(candidates),16);
    featureError = '';
    for i = 1:numel(candidates)
        try
            [values, names] = geometry.featureVector( ...
                child, candidates(i).parent_track_id, selectedFrames);
            if ~isreal(values) || any(~isfinite(values))
                error('budMotherLinker:NonFiniteFeatures', ...
                    'Non-finite descriptor values.');
            end
            featureMatrix(i,:) = values;
            candidates(i).features = cell2struct(num2cell(values), names, 2);
        catch ME
            featureError = sprintf('%s_parent_%u:%s', ...
                class(ME), candidates(i).parent_track_id, ME.message);
            break;
        end
    end
    if ~isempty(featureError)
        edge.reason = ['feature_error:' featureError];
        edge.reason_code = 'feature_error';
        edges(end+1,1) = edge; %#ok<AGROW>
        continue;
    end

    scores = budMotherLinker.predictHGB(featureMatrix, param);
    for i = 1:numel(candidates), candidates(i).hgb_score = scores(i); end
    sorting = [-scores(:), [candidates.parent_track_id]'];
    [~, order] = sortrows(sorting, [1 2]);
    candidates = candidates(order);
    topScore = candidates(1).hgb_score;
    if numel(candidates) > 1, secondScore = candidates(2).hgb_score;
    else, secondScore = 0; end
    margin = topScore - secondScore;
    edge.pred_parent_id = candidates(1).parent_track_id;
    edge.top_score = topScore;
    edge.margin = margin;
    edge.ranked_candidates = candidates;
    if margin < threshold
        edge.reason = 'low_model_margin';
    elseif guardEnabled && edge.new_tracks_at_birth > maxNewTracks
        edge.reason = 'high_tracking_load';
    else
        edge.status = 'linked';
        edge.reason = 'auto_confident';
    end
    edge.reason_code = edge.reason;
    edges(end+1,1) = edge; %#ok<AGROW>
end

reasons = struct();
linked = 0;
for i = 1:numel(edges)
    if strcmp(edges(i).status, 'linked'), linked = linked + 1; end
    key = matlab.lang.makeValidName(edges(i).reason_code);
    if ~isfield(reasons,key), reasons.(key) = 0; end
    reasons.(key) = reasons.(key) + 1;
end
result = struct( ...
    'schema_version', 1, ...
    'tool', 'detecdiv_builtin_bud_mother_linker', ...
    'tool_version', '2.0.0', ...
    'created_at', char(datetime('now','TimeZone','local','Format','yyyy-MM-dd''T''HH:mm:ssXXX')), ...
    'roi_id', char(string(roiId)), ...
    'input', 'tracked label masks only', ...
    'gfp_used', false, ...
    'runtime', 'MATLAB', ...
    'model_manifest_sha256', sha256File(manifestFile), ...
    'model_tool_version', char(string(modelInfo.tool_version)), ...
    'feature_implementation', 'detecdiv_builtin_lyn16_geometry_matlab', ...
    'parameters', struct( ...
        'frame_end', param.frameEnd, ...
        'min_lifetime', param.minLifetime, ...
        'max_birth_area', param.maxBirthArea, ...
        'min_parent_age', param.minParentAge, ...
        'max_parent_centroid_distance', param.maxParentCentroidDistance, ...
        'max_parent_contour_distance', param.maxParentContourDistance, ...
        'max_candidates', param.maxCandidates, ...
        'rank_margin_threshold', threshold, ...
        'tracking_load_guard_enabled', guardEnabled, ...
        'tracking_load_guard_max_new_tracks', maxNewTracks), ...
    'summary', struct('events',numel(edges),'linked',linked, ...
        'review',numel(edges)-linked,'reasons',reasons), ...
    'edges', edges);
end

function [stats, newTracks] = trackStatistics(tracks)
maxLabel = double(max(tracks,[],'all'));
stats = struct( ...
    'start', zeros(maxLabel+1,1), ...
    'frames', zeros(maxLabel+1,1), ...
    'birthArea', zeros(maxLabel+1,1));
newTracks = zeros(size(tracks,3),1);
previous = [];
for frame = 1:size(tracks,3)
    plane = tracks(:,:,frame);
    [labels,~,groups] = unique(plane(:));
    counts = accumarray(groups,1);
    keep = labels > 0;
    labels = double(labels(keep));
    counts = double(counts(keep));
    newTracks(frame) = numel(setdiff(labels, previous));
    previous = labels;
    for i = 1:numel(labels)
        row = labels(i) + 1;
        if stats.start(row) == 0
            stats.start(row) = frame;
            stats.birthArea(row) = counts(i);
        end
        stats.frames(row) = stats.frames(row) + 1;
    end
end
end

function candidate = candidateTemplate()
candidate = struct( ...
    'parent_track_id', 0, ...
    'candidate_score', NaN, ...
    'centroid_distance', NaN, ...
    'contour_distance', NaN, ...
    'contact_pixels', 0, ...
    'parent_age_frames', 0, ...
    'parent_area', 0, ...
    'hgb_score', NaN, ...
    'features', struct());
end

function edge = edgeTemplate()
edge = struct( ...
    'event_id', '', ...
    'roi', '', ...
    'child_track_id', 0, ...
    'bud_appearance_frame', 0, ...
    'lifetime', 0, ...
    'birth_area', 0, ...
    'candidate_count', 0, ...
    'status', 'review', ...
    'reason_code', '', ...
    'reason', '', ...
    'pred_parent_id', [], ...
    'top_score', [], ...
    'margin', [], ...
    'new_tracks_at_birth', 0, ...
    'ranked_candidates', repmat(candidateTemplate(),0,1));
end

function [info, filename] = loadModelInfo(param)
if strcmp(param.modelSource, 'trained')
    filename = param.modelPath;
    payload = load(filename, 'artifact');
    if ~isfield(payload, 'artifact') || ~isstruct(payload.artifact)
        error('budMotherLinker:InvalidTrainedModel', ...
            'Model artifact %s has no artifact structure.', filename);
    end
    artifact = payload.artifact;
    info = struct('tool_version','trained-1', ...
        'rank_margin_threshold',0, ...
        'tracking_load_guard_enabled',true, ...
        'max_new_tracks_per_frame',7);
    if isfield(artifact,'tool_version'), info.tool_version = artifact.tool_version; end
    if isfield(artifact,'rank_margin_threshold')
        info.rank_margin_threshold = artifact.rank_margin_threshold;
    end
    if isfield(artifact,'tracking_load_guard_enabled')
        info.tracking_load_guard_enabled = artifact.tracking_load_guard_enabled;
    end
    if isfield(artifact,'max_new_tracks_per_frame')
        info.max_new_tracks_per_frame = artifact.max_new_tracks_per_frame;
    end
    return;
end

root = fileparts(mfilename('fullpath'));
filename = fullfile(root, 'model', 'project47_v002', 'manifest.json');
if ~isfile(filename)
    error('budMotherLinker:MissingBuiltinModel', ...
        'Builtin model manifest is missing: %s', filename);
end
manifest = jsondecode(fileread(filename));
info = struct( ...
    'tool_version', manifest.tool_version, ...
    'rank_margin_threshold', ...
        manifest.deployment_calibration.rank_margin_threshold, ...
    'tracking_load_guard_enabled', manifest.tracking_load_guard.enabled, ...
    'max_new_tracks_per_frame', ...
        manifest.tracking_load_guard.max_new_tracks_per_frame);
end

function value = sha256File(filename)
fid = fopen(filename, 'r');
if fid < 0, value = ''; return; end
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
hash = typecast(digest.digest(bytes), 'uint8');
value = lower(reshape(dec2hex(hash,2).',1,[]));
end
