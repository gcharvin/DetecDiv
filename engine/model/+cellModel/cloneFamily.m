function [model, targetFamilyId, report] = cloneFamily( ...
        model, sourceFamily, targetFamily, maskProvider, varargin)
%CELLMODEL.CLONEFAMILY Clone instances and relations into an editable family.

p = inputParser;
p.addParameter('Overwrite', false, @(x) islogical(x) && isscalar(x));
p.addParameter('LineageSource', 'ground_truth', @(x) ischar(x) || isstring(x));
p.addParameter('CopyRelations', true, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

model = cellModel.normalize(model);
[sourceIndex, sourceFamilyId] = cellModel.familyIndex(model, sourceFamily);
if isempty(sourceIndex)
    error('cellModel:MissingSourceFamily', ...
        'Source family "%s" does not exist.', char(string(sourceFamily)));
end
[targetIndex, targetFamilyId] = cellModel.familyIndex(model, targetFamily);
if ~isempty(targetIndex) && targetFamilyId == sourceFamilyId
    error('cellModel:CloneFamilyCollision', ...
        'Source and target family must be different.');
end
if ~isempty(targetIndex) && ~p.Results.Overwrite
    error('cellModel:TargetFamilyExists', ...
        'Target family "%s" already exists.', char(string(targetFamily)));
end

if isempty(maskProvider)
    maskProvider = model.families.mask_provider{sourceIndex};
end
if isempty(targetIndex)
    targetFamilyId = max([model.families.family_id; uint32(0)]) + uint32(1);
    targetIndex = numel(model.families.family_id) + 1;
    model.families.family_id(targetIndex,1) = targetFamilyId;
    model.families.name{targetIndex,1} = char(string(targetFamily));
    model.families.mask_provider{targetIndex,1} = char(string(maskProvider));
    model.families.lineage_source{targetIndex,1} = char(string(p.Results.LineageSource));
    model.families.color_rgb(targetIndex,:) = model.families.color_rgb(sourceIndex,:);
else
    model.instances = subsetRows(model.instances, ...
        model.instances.family_id ~= targetFamilyId);
    model.relations = subsetRows(model.relations, ...
        model.relations.family_id ~= targetFamilyId);
    model.families.name{targetIndex} = char(string(targetFamily));
    model.families.mask_provider{targetIndex} = char(string(maskProvider));
    model.families.lineage_source{targetIndex} = char(string(p.Results.LineageSource));
end

sourceInstances = find(model.instances.family_id == sourceFamilyId);
newObjectStart = max([model.instances.object_id; uint64(0)]) + uint64(1);
newInstances = subsetRows(model.instances, sourceInstances);
newInstances.family_id(:) = targetFamilyId;
newInstances.object_id = newObjectStart + uint64((0:numel(sourceInstances)-1)');
model.instances = appendRows(model.instances, newInstances);

sourceRelations = find(model.relations.family_id == sourceFamilyId);
if ~p.Results.CopyRelations
    sourceRelations = zeros(0,1);
end
newRelationStart = max([model.relations.relation_id; uint64(0)]) + uint64(1);
newRelations = subsetRows(model.relations, sourceRelations);
newRelations.family_id(:) = targetFamilyId;
newRelations.relation_id = newRelationStart + uint64((0:numel(sourceRelations)-1)');
model.relations = appendRows(model.relations, newRelations);

model = cellModel.normalize(model);
validation = cellModel.validate(model, 'Throw', true);
report = struct( ...
    'source_family_id', sourceFamilyId, ...
    'target_family_id', targetFamilyId, ...
    'target_family', char(string(targetFamily)), ...
    'mask_provider', char(string(maskProvider)), ...
    'instances', numel(sourceInstances), ...
    'relations', numel(sourceRelations), ...
    'validation', validation);
end

function columns = subsetRows(columns, rows)
names = fieldnames(columns);
for i = 1:numel(names)
    columns.(names{i}) = columns.(names{i})(rows,:);
end
end

function target = appendRows(target, source)
names = fieldnames(target);
for i = 1:numel(names)
    target.(names{i}) = [target.(names{i}); source.(names{i})];
end
end
