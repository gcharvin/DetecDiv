function [stableTracks,family] = materializeStableTracks( ...
        maskLabels,model,frames,maskProvider)
%MATERIALIZESTABLETRACKS Replace frame-local mask labels by reviewed track IDs.
%
% Pixel values in an annotation mask identify objects only within one frame.
% DetecDiv's persistent identity is stored separately in
% model.instances.track_id.  A mask label may therefore be reused by a new
% bud after the previous bud ends.  Tracker supervision must use track_id,
% never the raw mask-label value.

model = cellModel.normalize(model);
maskProvider = strtrim(char(string(maskProvider)));
frames = double(frames(:)');
if size(maskLabels,3) ~= numel(frames)
    error('cellLatentTracker:FrameCountMismatch', ...
        'The GT mask stack and selected source frames have different lengths.');
end
if isempty(maskProvider)
    error('cellLatentTracker:MissingGroundTruthProvider', ...
        'A reviewed GT mask provider is required.');
end

family = resolveFamily(model,maskProvider);
instances = model.instances;
stableTracks = zeros(size(maskLabels),'uint32');
for localFrame = 1:numel(frames)
    sourceFrame = uint32(frames(localFrame));
    labels = unique(uint32(maskLabels(:,:,localFrame)));
    labels(labels == 0) = [];
    familyRows = instances.family_id == family.family_id & ...
        instances.frame == sourceFrame;
    referencedLabels = unique(instances.mask_label(familyRows));
    if ~isequal(labels(:),referencedLabels(:))
        missingReferences = setdiff(labels,referencedLabels);
        staleReferences = setdiff(referencedLabels,labels);
        error('cellLatentTracker:GroundTruthInstanceMapping', ...
            ['ROI GT family "%s" and mask provider "%s" disagree at ' ...
             'frame %u (mask labels without an instance: %s; instance ' ...
             'labels without mask pixels: %s).'],family.name,maskProvider, ...
            sourceFrame,labelList(missingReferences), ...
            labelList(staleReferences));
    end
    frameTrackIds = zeros(numel(labels),1,'uint32');
    for labelIndex = 1:numel(labels)
        label = labels(labelIndex);
        rows = find(familyRows & instances.mask_label == label);
        if numel(rows) ~= 1
            error('cellLatentTracker:GroundTruthInstanceMapping', ...
                ['ROI GT family "%s" must contain exactly one cell-model ' ...
                 'instance for mask label %u at frame %u; found %d.'], ...
                family.name,label,sourceFrame,numel(rows));
        end
        trackId = instances.track_id(rows);
        if trackId == 0 || trackId > intmax('uint32')
            error('cellLatentTracker:InvalidStableTrackId', ...
                ['GT family "%s" has invalid stable track ID %s for mask ' ...
                 'label %u at frame %u.'],family.name, ...
                char(string(trackId)),label,sourceFrame);
        end
        frameTrackIds(labelIndex) = uint32(trackId);
        frameTracks = stableTracks(:,:,localFrame);
        frameTracks(maskLabels(:,:,localFrame) == label) = uint32(trackId);
        stableTracks(:,:,localFrame) = frameTracks;
    end
    if numel(unique(frameTrackIds)) ~= numel(frameTrackIds)
        error('cellLatentTracker:GroundTruthInstanceMapping', ...
            ['ROI GT family "%s" assigns several mask labels to the same ' ...
             'stable track at frame %u.'],family.name,sourceFrame);
    end
end
end

function value = labelList(labels)
if isempty(labels)
    value = '<none>';
    return;
end
value = char(strjoin(string(double(labels(:).')),','));
end

function family = resolveFamily(model,maskProvider)
families = model.families;
matches = find(strcmpi(string(families.mask_provider),maskProvider));
if isempty(matches)
    error('cellLatentTracker:GroundTruthFamilyNotFound', ...
        ['No cell-model family uses GT mask provider "%s". Refresh or ' ...
         'revalidate the ROI annotation before training.'],maskProvider);
end
if numel(matches) > 1
    reviewed = matches(strcmpi( ...
        string(families.lineage_source(matches)),'ground_truth'));
    if numel(reviewed) == 1
        matches = reviewed;
    else
        names = strjoin(string(families.name(matches)),', ');
        error('cellLatentTracker:AmbiguousGroundTruthFamily', ...
            ['Several cell-model families use GT mask provider "%s" (%s). ' ...
             'Exactly one reviewed ground-truth family is required.'], ...
            maskProvider,char(names));
    end
end
index = matches(1);
family = struct( ...
    'family_id',families.family_id(index), ...
    'name',families.name{index}, ...
    'mask_provider',families.mask_provider{index}, ...
    'lineage_source',families.lineage_source{index});
end
