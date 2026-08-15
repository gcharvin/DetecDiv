function report = startBlank(classif, roiObj, spec, varargin)
%ANNOTATIONMANAGER.STARTBLANK Materialize an empty editable GT draft.

p = inputParser;
p.addParameter('Overwrite', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

componentReports = repmat(struct('id', '', 'target', '', 'changed', false), ...
    numel(spec.components), 1);
channelsToSave = {};
modelChanged = false;
for i = 1:numel(spec.components)
    component = spec.components(i);
    componentReports(i).id = component.id;
    switch char(string(component.storage))
        case 'channel'
            target = createBlankChannel(roiObj, component, p.Results.Overwrite);
            channelsToSave{end+1} = target; %#ok<AGROW>
        case 'dataseries'
            target = createBlankFields(roiObj, component, p.Results.Overwrite);
        case 'cell_model_family'
            target = createBlankFamily(roiObj, component, p.Results.Overwrite);
            modelChanged = true;
        otherwise
            target = '';
    end
    componentReports(i).target = target;
    componentReports(i).changed = ~isempty(target);
end

if p.Results.Save && ~isempty(channelsToSave)
    roiObj.save(unique(channelsToSave, 'stable'), false);
end
if p.Results.Save && modelChanged
    roiObj.saveCellModel(roiObj.cellModel);
end

[entry, ~] = annotationManager.entryForSpec(roiObj, spec);
entry.status = 'draft';
entry.revision = uint32(double(entry.revision) + 1);
entry.approved_at = '';
entry.approved_hash = '';
entry = annotationManager.resetValidationState(entry);
entry.source_type = 'blank';
entry.source_id = '';
entry.source_run_id = '';
for i = 1:numel(entry.review)
    entry.review(i).frames(:) = false;
    entry.review(i).complete = false;
end
entry = annotationManager.setEntry(roiObj, spec, entry, 'Save', p.Results.Save);
updateTrainingBindings(classif, spec);

report = struct('status', entry.status, 'revision', double(entry.revision), ...
    'components', componentReports, 'channelsSaved', {channelsToSave}, ...
    'modelChanged', modelChanged, 'entry', entry);
end

function target = createBlankChannel(roiObj, component, overwrite)
target = char(string(component.groundTruth.channel));
if isempty(target), return; end
roiObj.load('Silent');
idx = roiObj.findChannelID(target);
if ~isempty(idx)
    current = roiObj.image(:,:,idx,:);
    if any(current(:)) && ~overwrite
        error('annotationManager:GroundTruthExists', ...
            'GT channel "%s" already contains annotations.', target);
    end
    roiObj.image(:,:,idx,:) = zeros(size(current), class(roiObj.image));
    return;
end
if isempty(roiObj.image)
    error('annotationManager:MissingRoiImage', ...
        'Cannot create GT channel "%s" without a ROI image.', target);
end
blank = zeros(size(roiObj.image,1), size(roiObj.image,2), 1, ...
    size(roiObj.image,4), 'uint16');
roiObj.addChannel(blank, target, [1 1 1], [0 0 0]);
end

function targetName = createBlankFields(roiObj, component, overwrite)
ensureData(roiObj);
asset = component.groundTruth;
targetName = [char(string(asset.groupId)) '.' char(string(asset.valueField))];
idx = dataseriesIndex(roiObj, asset.groupId);
if isempty(idx)
    ds = dataseries;
    ds.groupid = char(string(asset.groupId));
    ds.parentid = char(string(roiObj.id));
    ds.class = "classification";
    ds.type = "temporal";
    ds.data = table;
    if isempty(roiObj.data) || (numel(roiObj.data) == 1 && ...
            isempty(char(string(roiObj.data(1).groupid))))
        roiObj.data = ds;
        idx = 1;
    else
        roiObj.data(end+1) = ds;
        idx = numel(roiObj.data);
    end
end
tbl = roiObj.data(idx).data;
if ismember(asset.valueField, tbl.Properties.VariableNames) && ...
        hasDefinedValues(tbl.(asset.valueField)) && ~overwrite
    error('annotationManager:GroundTruthExists', ...
        'GT field "%s" already contains annotations.', targetName);
end
n = annotationManager.frameCount(roiObj);
categories = unique([{'undefined'}, component.classes], 'stable');
tbl.(asset.valueField) = categorical(repmat({'undefined'}, n, 1), categories);
if ~isempty(asset.idField), tbl.(asset.idField) = zeros(n, 1); end
roiObj.data(idx).data = tbl;
roiObj.data(idx) = configureLabelDisplay(roiObj.data(idx), asset);
end

function ds = configureLabelDisplay(ds, asset)
rows = cell(0,6);
if ~isempty(asset.idField)
    rows(end+1,:) = {false, char(string(asset.idField)), 'double', 'k', 2, 'id'};
end
rows(end+1,:) = {true, char(string(asset.valueField)), 'categorical', 'k', 2, 'label'};
ds.plotProperties = rows;
ds.plotGroup = {[] [] [] [] [] {'id','label'}};
ds.groupProperties = {'id','Plot','auto','auto'; 'label','Plot','auto','auto'};
ds.show = true;
end

function target = createBlankFamily(roiObj, component, overwrite)
target = char(string(component.groundTruth.family));
provider = char(string(component.groundTruth.maskProvider));
[model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
[idx, familyId] = cellModel.familyIndex(model, target);
if ~isempty(idx)
    hasRows = any(model.instances.family_id == familyId) || ...
        any(model.relations.family_id == familyId);
    if hasRows && ~overwrite
        error('annotationManager:GroundTruthExists', ...
            'GT object family "%s" already contains annotations.', target);
    end
    model.instances = subsetRows(model.instances, model.instances.family_id ~= familyId);
    model.relations = subsetRows(model.relations, model.relations.family_id ~= familyId);
    model.families.mask_provider{idx} = provider;
    model.families.lineage_source{idx} = 'ground_truth';
else
    familyId = max([model.families.family_id; uint32(0)]) + uint32(1);
    idx = numel(model.families.family_id) + 1;
    model.families.family_id(idx,1) = familyId;
    model.families.name{idx,1} = target;
    model.families.mask_provider{idx,1} = provider;
    model.families.lineage_source{idx,1} = 'ground_truth';
    model.families.color_rgb(idx,:) = uint8([99 214 255]);
end
roiObj.cellModel = cellModel.normalize(model);
end

function columns = subsetRows(columns, keep)
names = fieldnames(columns);
for i = 1:numel(names)
    columns.(names{i}) = columns.(names{i})(keep,:);
end
end

function ensureData(roiObj)
try
    if isempty(roiObj.data) || (numel(roiObj.data) == 1 && ...
            isempty(char(string(roiObj.data(1).groupid))))
        roiObj.load('Data', 'Silent');
    end
catch
end
end

function idx = dataseriesIndex(roiObj, groupId)
idx = [];
try
    idx = find(arrayfun(@(x) strcmp(char(string(x.groupid)), ...
        char(string(groupId))), roiObj.data), 1);
catch
end
end

function tf = hasDefinedValues(values)
if isempty(values), tf = false; return; end
if iscategorical(values)
    text = string(values);
    tf = any(~isundefined(values) & lower(text) ~= "undefined");
elseif isstring(values) || iscellstr(values)
    text = string(values);
    tf = any(strlength(strtrim(text)) > 0 & lower(text) ~= "undefined");
elseif isnumeric(values) || islogical(values)
    tf = any(isfinite(double(values(:))) & double(values(:)) > 0);
else
    tf = true;
end
end

function updateTrainingBindings(classif, spec)
try
    if isempty(classif) || ~isprop(classif, 'trainingParam') || ...
            ~isstruct(classif.trainingParam)
        return;
    end
    familyIdx = find(strcmp({spec.components.storage}, 'cell_model_family'), 1);
    if ~isempty(familyIdx)
        classif.trainingParam.groundTruthFamily = ...
            spec.components(familyIdx).groundTruth.family;
    end
    trackIdx = find(strcmp({spec.components.kind}, 'tracked_instances'), 1);
    if ~isempty(trackIdx)
        targetChannel = spec.components(trackIdx).groundTruth.channel;
        if isfield(classif.trainingParam, 'groundTruthChannelName')
            classif.trainingParam.groundTruthChannelName = targetChannel;
        end
        if isfield(classif.trainingParam, 'trackChannelName')
            classif.trainingParam.trackChannelName = targetChannel;
        end
    end
catch
end
end
