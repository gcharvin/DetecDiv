function [model, familyId, report] = applyLineageResult( ...
        model, stack, channelName, inputFamily, outputFamily, result, ...
        overwrite, lineageSource)
%CELLMODEL.APPLYLINEAGERESULT Materialize a predicted lineage without masks.
%
% The output family references the existing tracked-mask provider. It owns
% only object instances and parent/child relations, so classifiers never
% duplicate image channels.

if nargin < 8 || isempty(lineageSource), lineageSource = 'classifier'; end
model = cellModel.normalize(model);
[sourceIndex, ~] = cellModel.familyIndex(model, inputFamily);
if isempty(sourceIndex)
    [sourceIndex, ~] = cellModel.familyIndex(model, channelName);
end

[outputIndex, familyId] = cellModel.familyIndex(model, outputFamily);
if ~isempty(outputIndex) && outputIndex == sourceIndex
    error('cellModel:SourceOutputCollision', ...
        ['The output family must be distinct from the tracking/source ' ...
         'family so source states and genealogy remain immutable.']);
end
if ~isempty(outputIndex) && ~overwrite
    error('cellModel:OutputFamilyExists', ...
        'Cell-model family "%s" already exists.', outputFamily);
end
if isempty(outputIndex)
    familyId = max([model.families.family_id; uint32(0)]) + uint32(1);
    outputIndex = numel(model.families.family_id) + 1;
    model.families.family_id(outputIndex,1) = familyId;
    model.families.name{outputIndex,1} = outputFamily;
    model.families.mask_provider{outputIndex,1} = channelName;
    model.families.lineage_source{outputIndex,1} = lineageSource;
    if isempty(sourceIndex)
        model.families.color_rgb(outputIndex,:) = uint8([99 214 255]);
    else
        model.families.color_rgb(outputIndex,:) = ...
            model.families.color_rgb(sourceIndex,:);
    end
else
    model.instances = subsetRows(model.instances, ...
        model.instances.family_id ~= familyId);
    model.relations = subsetRows(model.relations, ...
        model.relations.family_id ~= familyId);
    model.families.mask_provider{outputIndex} = channelName;
    model.families.lineage_source{outputIndex} = lineageSource;
end

nextObject = max([model.instances.object_id; uint64(0)]) + uint64(1);
for frame = 1:size(stack,3)
    labels = unique(stack(:,:,frame));
    labels = labels(labels > 0);
    count = numel(labels);
    if count == 0, continue; end
    rows = (numel(model.instances.object_id)+1): ...
        (numel(model.instances.object_id)+count);
    model.instances.object_id(rows,1) = ...
        nextObject + uint64((0:count-1)');
    nextObject = nextObject + uint64(count);
    model.instances.family_id(rows,1) = familyId;
    model.instances.frame(rows,1) = uint32(frame);
    model.instances.mask_label(rows,1) = uint32(labels);
    model.instances.track_id(rows,1) = uint64(labels);
    model.instances.state_id(rows,1) = sourceStates( ...
        model, sourceIndex, frame, labels);
end

edges = result.edges;
if isempty(edges), edges = struct([]); end
nextRelation = max([model.relations.relation_id; uint64(0)]) + uint64(1);
linked = 0;
skipped = 0;
knownTracks = unique(model.instances.track_id( ...
    model.instances.family_id == familyId));
for i = 1:numel(edges)
    if iscell(edges)
        edge = edges{i};
    else
        edge = edges(i);
    end
    if ~isfield(edge,'status') || ...
            ~strcmp(char(string(edge.status)),'linked')
        continue;
    end
    if ~isfield(edge,'pred_parent_id') || ...
            ~isfield(edge,'child_track_id') || ...
            ~isfield(edge,'bud_appearance_frame')
        skipped = skipped + 1;
        continue;
    end
    parent = uint64(edge.pred_parent_id);
    child = uint64(edge.child_track_id);
    if parent == 0 || child == 0 || parent == child || ...
            ~ismember(parent,knownTracks) || ~ismember(child,knownTracks)
        skipped = skipped + 1;
        continue;
    end
    row = numel(model.relations.relation_id) + 1;
    model.relations.relation_id(row,1) = nextRelation;
    nextRelation = nextRelation + 1;
    model.relations.family_id(row,1) = familyId;
    model.relations.parent_track_id(row,1) = parent;
    model.relations.child_track_id(row,1) = child;
    model.relations.event_frame(row,1) = uint32(edge.bud_appearance_frame);
    model.relations.type_id(row,1) = uint8(1);
    confidence = NaN;
    if isfield(edge,'top_score') && ~isempty(edge.top_score)
        confidence = edge.top_score;
    elseif isfield(edge,'top_probability') && ~isempty(edge.top_probability)
        confidence = edge.top_probability;
    end
    model.relations.confidence(row,1) = single(confidence);
    linked = linked + 1;
end
model = cellModel.normalize(model);
validation = cellModel.validate(model,'Throw',true);
report = struct( ...
    'family_id',familyId, ...
    'family_name',outputFamily, ...
    'lineage_source',lineageSource, ...
    'linked_relations',linked, ...
    'skipped_invalid_relations',skipped, ...
    'validation',validation);
end

function states = sourceStates(model,sourceIndex,frame,labels)
states = zeros(numel(labels),1,'uint16');
if isempty(sourceIndex), return; end
sourceFamilyId = model.families.family_id(sourceIndex);
rows = find(model.instances.family_id == sourceFamilyId & ...
    model.instances.frame == uint32(frame));
for i = 1:numel(labels)
    hit = rows(find(model.instances.mask_label(rows) == ...
        uint32(labels(i)),1,'first'));
    if ~isempty(hit), states(i) = model.instances.state_id(hit); end
end
end

function columns = subsetRows(columns,keep)
names = fieldnames(columns);
for i = 1:numel(names)
    columns.(names{i}) = columns.(names{i})(keep,:);
end
end
