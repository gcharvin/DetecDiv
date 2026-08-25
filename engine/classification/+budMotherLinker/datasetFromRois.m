function dataset = datasetFromRois(classif, roiIndices, splitName, tp, frames)
%BUDMOTHERLINKER.DATASETFROMROIS Extract candidate rows from reviewed ROIs.

if nargin < 5, frames = []; end
featureNames = budMotherLinker.utils.featureNames();
dataset = emptyDataset(featureNames);
params = trainingInferenceParams(classif, tp);
eventOffset = 0;
externalGt = loadExternalGroundTruth(tp.groundTruthSource);

roiIndices = roiIndices(:)';
for roiPosition = 1:numel(roiIndices)
    r = roiIndices(roiPosition);
    roiobj = classif.roi(r);
    wasLoaded = ~isempty(roiobj.image);
    if ~wasLoaded, roiobj.load; end
    cleanup = onCleanup(@() clearIfNeeded(roiobj,wasLoaded));
    channelName = resolveTrackChannel(classif, roiobj, tp.trackChannelName);
    stack = getTrackStack(roiobj, channelName);
    if isempty(externalGt)
        [cellState, ~] = roiobj.loadCellModel('MigrateLegacy',true);
        cellState = cellModel.normalize(cellState);
        [cellState, ~] = cellModel.canonicalizeParentageEvents(cellState);
        [familyId, familyName] = resolveGroundTruthFamily( ...
            cellState, channelName, tp.groundTruthFamily);
        gt = cellState.relations;
        gtRows = gt.family_id == familyId & gt.parent_track_id > 0 & ...
            gt.child_track_id > 0;
        gtParents = double(gt.parent_track_id(gtRows));
        gtChildren = double(gt.child_track_id(gtRows));
        gtFrames = double(gt.event_frame(gtRows));
    else
        roiRows = externalRowsForRoi(externalGt,char(string(roiobj.id)));
        gtParents = double(roiRows.parent_track_id);
        gtChildren = double(roiRows.child_track_id);
        gtFrames = double(roiRows.bud_appearance_frame);
        familyName = ['external:' char(string(tp.groundTruthSource))];
    end

    result = budMotherLinker.infer(stack, params, char(string(roiobj.id)));
    selectedFrames = trainingBounds.frames(classif,r,size(stack,3),frames, ...
        'RoiPosition',roiPosition,'SplitName',splitName);
    dataset.summary.rois = dataset.summary.rois + 1;
    for e = 1:numel(result.edges)
        edge = result.edges(e);
        if ~isempty(selectedFrames) && ...
                ~ismember(double(edge.bud_appearance_frame),selectedFrames)
            continue;
        end
        relationRows = find(gtChildren == double(edge.child_track_id));
        if numel(relationRows) > 1
            [~,closest] = min(abs(gtFrames(relationRows) - ...
                double(edge.bud_appearance_frame)));
            relationRows = relationRows(closest);
        end
        dataset.summary.events = dataset.summary.events + 1;
        if isempty(relationRows)
            dataset.summary.skipped_unreviewed_events = ...
                dataset.summary.skipped_unreviewed_events + 1;
            continue;
        end
        trueParent = gtParents(relationRows(1));
        candidates = edge.ranked_candidates;
        candidateParents = double([candidates.parent_track_id]);
        if isempty(candidates) || ~ismember(trueParent,candidateParents)
            dataset.summary.missed_gt_candidates = ...
                dataset.summary.missed_gt_candidates + 1;
            continue;
        end

        eventOffset = eventOffset + 1;
        dataset.summary.reviewed_events = dataset.summary.reviewed_events + 1;
        for c = 1:numel(candidates)
            values = zeros(1,numel(featureNames));
            for f = 1:numel(featureNames)
                values(f) = candidates(c).features.(featureNames{f});
            end
            dataset.X(end+1,:) = values;
            dataset.y(end+1,1) = candidateParents(c) == trueParent;
            dataset.event_id(end+1,1) = eventOffset;
            dataset.roi_index(end+1,1) = r;
            dataset.roi_id{end+1,1} = char(string(roiobj.id));
            dataset.child_track_id(end+1,1) = double(edge.child_track_id);
            dataset.parent_track_id(end+1,1) = candidateParents(c);
            dataset.event_frame(end+1,1) = double(edge.bud_appearance_frame);
            dataset.split{end+1,1} = splitName;
        end
    end
    dataset.gt_family_by_roi(end+1,:) = {r,char(string(roiobj.id)),familyName};
    clear cleanup;
end
end

function dataset = emptyDataset(names)
dataset = struct( ...
    'schema_version',1, ...
    'feature_names',{names}, ...
    'X',zeros(0,numel(names)), ...
    'y',false(0,1), ...
    'event_id',zeros(0,1), ...
    'roi_index',zeros(0,1), ...
    'roi_id',{{}}, ...
    'child_track_id',zeros(0,1), ...
    'parent_track_id',zeros(0,1), ...
    'event_frame',zeros(0,1), ...
    'split',{{}}, ...
    'gt_family_by_roi',{cell(0,3)}, ...
    'summary',struct('rois',0,'events',0,'reviewed_events',0, ...
        'skipped_unreviewed_events',0,'missed_gt_candidates',0));
end

function p = trainingInferenceParams(classif,tp)
p = budMotherLinker.utils.defaultExecutionParam();
names = {'minLifetime','maxBirthArea','minParentAge', ...
    'maxParentCentroidDistance','maxParentContourDistance','maxCandidates'};
for i = 1:numel(names), p.(names{i}) = tp.(names{i}); end
p.frameEnd = -1;
p.rankMarginThreshold = -1;
p.modelSource = 'builtin';
p.modelPath = '';
p.trackChannelName = tp.trackChannelName;
try
    if isempty(p.trackChannelName), p.trackChannelName = classif.channelName{1}; end
catch
end
end

function name = resolveTrackChannel(classif,roiobj,requested)
name = char(string(requested));
if isempty(name)
    try
        values = cellstr(string(classif.channelName));
        values = values(strlength(string(values)) > 0);
        if ~isempty(values), name = values{1}; end
    catch
    end
end
if isempty(name)
    channels = cellstr(string(roiobj.display.channel));
    hit = find(contains(lower(string(channels)),'track'),1,'last');
    if ~isempty(hit), name = channels{hit}; end
end
if isempty(name) || isempty(roiobj.findChannelID(name))
    error('budMotherLinker:TrainingChannelNotFound', ...
        'Tracked-label channel "%s" was not found in ROI %s.', ...
        name, char(string(roiobj.id)));
end
end

function stack = getTrackStack(roiobj,name)
pix = roiobj.findChannelID(name);
pix = pix(1);
stack = squeeze(roiobj.image(:,:,pix,:));
if ismatrix(stack), stack = reshape(stack,size(stack,1),size(stack,2),1); end
if any(~isfinite(double(stack(:)))) || any(double(stack(:)) < 0) || ...
        any(mod(double(stack(:)),1) ~= 0)
    error('budMotherLinker:InvalidTrainingLabels', ...
        'ROI %s channel %s is not an indexed track mask.', ...
        char(string(roiobj.id)),name);
end
stack = uint32(stack);
end

function [familyId,name] = resolveGroundTruthFamily(model,channel,requested)
model = cellModel.normalize(model);
requested = char(string(requested));
if ~isempty(requested) && ~strcmpi(requested,'<auto>')
    [index,familyId] = cellModel.familyIndex(model,requested);
    if isempty(index)
        error('budMotherLinker:GroundTruthFamilyNotFound', ...
            'Ground-truth family "%s" was not found.',requested);
    end
    name = model.families.name{index};
    return;
end

ids = model.families.family_id;
counts = zeros(numel(ids),1);
providerMatch = false(numel(ids),1);
for i = 1:numel(ids)
    counts(i) = nnz(model.relations.family_id == ids(i) & ...
        model.relations.parent_track_id > 0);
    providerMatch(i) = strcmp(char(string(model.families.mask_provider{i})),channel);
end
candidates = find(counts > 0 & providerMatch);
if isempty(candidates)
    error('budMotherLinker:NoReviewedLineage', ...
        ['No reviewed lineage family uses tracked-mask channel "%s". ' ...
         'Select a matching groundTruthFamily or set groundTruthSource to ' ...
         'the reviewed SQLite/CSV export.'],channel);
end

[~,order] = sortrows([-counts(candidates),double(ids(candidates))],[1 2]);
index = candidates(order(1));
familyId = ids(index);
name = model.families.name{index};
if numel(candidates) > 1 && counts(candidates(order(1))) == counts(candidates(order(2)))
    warning('budMotherLinker:AmbiguousGroundTruthFamily', ...
        ['Several lineage families contain the same number of relations; ' ...
         'using "%s". Set groundTruthFamily explicitly to remove ambiguity.'],name);
end
end

function gt = loadExternalGroundTruth(source)
source = strtrim(char(string(source)));
if isempty(source), gt = table(); return; end
if ~isfile(source)
    error('budMotherLinker:GroundTruthSourceNotFound', ...
        'Ground-truth source was not found: %s',source);
end
[~,~,ext] = fileparts(source);
switch lower(ext)
    case {'.sqlite','.db'}
        if isempty(which('sqlite'))
            error('budMotherLinker:SQLiteUnavailable', ...
                'Reading SQLite GT requires MATLAB Database Toolbox.');
        end
        connection = sqlite(source,'readonly');
        cleanup = onCleanup(@() close(connection));
        query = [ ...
            'SELECT e.roi, e.child_track_id, a.parent_track_id, ' ...
            'a.bud_appearance_frame, a.decision, a.tracking_status ' ...
            'FROM annotations a JOIN events e ON e.event_id=a.event_id ' ...
            'WHERE a.decision=''accepted'' AND a.parent_track_id IS NOT NULL'];
        gt = fetch(connection,query);
        clear cleanup;
    case {'.csv','.tsv','.txt'}
        gt = readtable(source,'TextType','string');
    otherwise
        error('budMotherLinker:UnsupportedGroundTruthSource', ...
            'Use a reviewed .sqlite database or accepted_lineage.csv.');
end
required = {'roi','child_track_id','parent_track_id','bud_appearance_frame'};
if ~all(ismember(required,gt.Properties.VariableNames))
    error('budMotherLinker:InvalidGroundTruthSource', ...
        'GT source must contain: %s.',strjoin(required,', '));
end
if ismember('decision',gt.Properties.VariableNames)
    gt = gt(strcmpi(string(gt.decision),'accepted'),:);
end
if ismember('tracking_status',gt.Properties.VariableNames)
    gt = gt(strcmpi(string(gt.tracking_status),'ok'),:);
end
end

function rows = externalRowsForRoi(gt,roiId)
aliases = roiAliases(roiId);
rows = gt(ismember(string(gt.roi),string(aliases)),:);
end

function aliases = roiAliases(roiId)
roiId = char(string(roiId));
aliases = {roiId};
trimmed = regexprep(roiId,'_1$','');
if ~strcmp(trimmed,roiId), aliases{end+1}=trimmed; end
end

function clearIfNeeded(roiobj,wasLoaded)
if ~wasLoaded
    try roiobj.clear; catch, end
end
end
