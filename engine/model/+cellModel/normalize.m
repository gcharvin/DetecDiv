function model = normalize(model, roiId)
%CELLMODEL.NORMALIZE Normalize types/shapes while preserving schema-v1 data.

if nargin < 2, roiId = ''; end
defaults = cellModel.create(roiId);
if nargin < 1 || isempty(model) || ~isstruct(model)
    model = defaults;
    return;
end

model = mergeTopLevel(defaults, model);
model.format = 'detecdiv_cell_model';
model.schema_version = uint16(1);
model.index_base = uint8(1);
if isempty(model.roi_id), model.roi_id = char(string(roiId)); end
model.roi_id = char(string(model.roi_id));

model.families = normalizeFamilies(model.families);
model.states = normalizeStates(model.states);
model.instances = normalizeInstances(model.instances);
model.relations = normalizeRelations(model.relations);
model.relation_types = normalizeRelationTypes(model.relation_types);

if ~isstruct(model.provenance), model.provenance = defaults.provenance; end
if ~isfield(model.provenance, 'created_at') || isempty(model.provenance.created_at)
    model.provenance.created_at = defaults.provenance.created_at;
end
if ~isfield(model.provenance, 'updated_at') || isempty(model.provenance.updated_at)
    model.provenance.updated_at = defaults.provenance.updated_at;
end
if ~isfield(model.provenance, 'source'), model.provenance.source = 'detecdiv'; end
if ~isfield(model.provenance, 'source_version'), model.provenance.source_version = '1'; end
model.provenance.created_at = char(string(model.provenance.created_at));
model.provenance.updated_at = char(string(model.provenance.updated_at));
model.provenance.source = char(string(model.provenance.source));
model.provenance.source_version = char(string(model.provenance.source_version));

% Deterministic row order makes HDF5 diffs and cross-language tests stable.
if ~isempty(model.instances.object_id)
    [~, order] = sortrows([double(model.instances.family_id), ...
        double(model.instances.frame), double(model.instances.mask_label)]);
    model.instances = reorderColumns(model.instances, order);
end
if ~isempty(model.relations.relation_id)
    [~, order] = sortrows([double(model.relations.family_id), ...
        double(model.relations.event_frame), double(model.relations.child_track_id)]);
    model.relations = reorderColumns(model.relations, order);
end
end

function out = mergeTopLevel(defaults, input)
out = defaults;
names = fieldnames(input);
for i = 1:numel(names), out.(names{i}) = input.(names{i}); end
end

function families = normalizeFamilies(families)
template = cellModel.create(''); template = template.families;
if ~isstruct(families), families = template; return; end
n = maxColumnLength(families, {'family_id','name','mask_provider','lineage_source','color_rgb'});
families.family_id = numericColumn(families, 'family_id', n, 'uint32', (1:n)');
families.name = textColumn(families, 'name', n, 'family');
families.mask_provider = textColumn(families, 'mask_provider', n, '');
families.lineage_source = textColumn(families, 'lineage_source', n, '');
families.color_rgb = colorRows(families, 'color_rgb', n, [255 255 255]);
end

function states = normalizeStates(states)
template = cellModel.create(''); template = template.states;
if ~isstruct(states), states = template; return; end
n = maxColumnLength(states, {'state_id','name','color_rgb'});
states.state_id = numericColumn(states, 'state_id', n, 'uint16', (1:n)');
states.name = textColumn(states, 'name', n, 'state');
states.color_rgb = colorRows(states, 'color_rgb', n, [255 255 255]);
end

function instances = normalizeInstances(instances)
template = cellModel.create(''); template = template.instances;
if ~isstruct(instances), instances = template; return; end
n = maxColumnLength(instances, fieldnames(template));
instances.object_id = numericColumn(instances, 'object_id', n, 'uint64', (1:n)');
instances.family_id = numericColumn(instances, 'family_id', n, 'uint32', 0);
instances.frame = numericColumn(instances, 'frame', n, 'uint32', 0);
instances.mask_label = numericColumn(instances, 'mask_label', n, 'uint32', 0);
instances.track_id = numericColumn(instances, 'track_id', n, 'uint64', 0);
instances.state_id = numericColumn(instances, 'state_id', n, 'uint16', 0);
end

function relations = normalizeRelations(relations)
template = cellModel.create(''); template = template.relations;
if ~isstruct(relations), relations = template; return; end
n = maxColumnLength(relations, fieldnames(template));
relations.relation_id = numericColumn(relations, 'relation_id', n, 'uint64', (1:n)');
relations.family_id = numericColumn(relations, 'family_id', n, 'uint32', 0);
relations.parent_track_id = numericColumn(relations, 'parent_track_id', n, 'uint64', 0);
relations.child_track_id = numericColumn(relations, 'child_track_id', n, 'uint64', 0);
relations.event_frame = numericColumn(relations, 'event_frame', n, 'uint32', 0);
relations.type_id = numericColumn(relations, 'type_id', n, 'uint8', 1);
relations.confidence = numericColumn(relations, 'confidence', n, 'single', NaN);
end

function types = normalizeRelationTypes(types)
if ~isstruct(types) || isempty(types)
    types = struct('type_id', uint8(1), 'name', 'parent');
    return;
end
if numel(types) == 1 && isfield(types, 'type_id') && numel(types.type_id) > 1
    ids = types.type_id(:); names = cellstr(string(types.name));
    types = repmat(struct('type_id',uint8(0),'name',''), numel(ids), 1);
    for i=1:numel(ids), types(i).type_id=uint8(ids(i)); types(i).name=names{i}; end
else
    for i=1:numel(types)
        types(i).type_id = uint8(types(i).type_id);
        types(i).name = char(string(types(i).name));
    end
end
end

function n = maxColumnLength(s, names)
n = 0;
for i=1:numel(names)
    if isfield(s,names{i}) && ~isempty(s.(names{i}))
        if strcmp(names{i},'color_rgb'), thisN=size(s.(names{i}),1); else, thisN=numel(s.(names{i})); end
        n=max(n,thisN);
    end
end
end

function value = numericColumn(s, name, n, cls, fallback)
if isfield(s,name) && ~isempty(s.(name)), value=s.(name)(:); else, value=fallback; end
if isscalar(value) && n>1, value=repmat(value,n,1); end
if numel(value)<n, value(end+1:n,1)=cast(0,cls); end
value=cast(value(1:n),cls);
end

function values = textColumn(s, name, n, prefix)
if isfield(s,name) && ~isempty(s.(name)), values=cellstr(string(s.(name)(:))); else, values=cell(n,1); end
values=values(:);
if numel(values)<n, values(end+1:n,1)={''}; end
for i=1:n
    if isempty(values{i}) && ~isempty(prefix), values{i}=sprintf('%s_%d',prefix,i); end
end
end

function colors = colorRows(s, name, n, fallback)
if isfield(s,name) && ~isempty(s.(name)), colors=double(s.(name)); else, colors=repmat(fallback,n,1); end
if size(colors,2)~=3 && size(colors,1)==3, colors=colors.'; end
if size(colors,2)~=3, colors=repmat(fallback,n,1); end
if size(colors,1)<n, colors(end+1:n,:)=repmat(fallback,n-size(colors,1),1); end
if ~isempty(colors) && max(colors(:))<=1, colors=round(255*colors); end
colors=uint8(max(0,min(255,colors(1:n,:))));
end

function s = reorderColumns(s, order)
names=fieldnames(s);
for i=1:numel(names), s.(names{i})=s.(names{i})(order,:); end
end
