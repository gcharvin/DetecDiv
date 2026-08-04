function report = bootstrap(classif, roiObj, spec, varargin)
%ANNOTATIONMANAGER.BOOTSTRAP Promote prediction assets to an editable GT draft.

p = inputParser;
p.addParameter('Overwrite', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
p.addParameter('SourceRunId', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});

componentReports = repmat(struct('id', '', 'operation', '', ...
    'source', '', 'target', '', 'changed', false, 'details', struct()), ...
    numel(spec.components), 1);
channelsToSave = {};
dataChanged = false;
modelChanged = false;

for i = 1:numel(spec.components)
    component = spec.components(i);
    componentReports(i).id = component.id;
    componentReports(i).operation = component.bootstrap;
    switch char(string(component.bootstrap))
        case 'copy_channel'
            [details, target] = copyChannel(roiObj, component, p.Results.Overwrite);
            componentReports(i).source = details.source;
            componentReports(i).target = target;
            componentReports(i).changed = true;
            componentReports(i).details = details;
            channelsToSave{end+1} = target; %#ok<AGROW>
        case 'copy_fields'
            details = copyFields(roiObj, component, p.Results.Overwrite);
            componentReports(i).source = details.source;
            componentReports(i).target = details.target;
            componentReports(i).changed = true;
            componentReports(i).details = details;
            dataChanged = true;
        case 'clone_family'
            details = cloneFamily(roiObj, component, p.Results.Overwrite);
            componentReports(i).source = details.source;
            componentReports(i).target = details.target;
            componentReports(i).changed = true;
            componentReports(i).details = details.report;
            modelChanged = true;
        otherwise
            componentReports(i).changed = false;
    end
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
entry.source_type = 'prediction';
entry.source_id = sourceDescription(componentReports);
entry.source_run_id = char(string(p.Results.SourceRunId));
entry = resetReview(entry);
entry = annotationManager.setEntry(roiObj, spec, entry, 'Save', p.Results.Save);

updateTrainingBindings(classif, spec);
report = struct('status', entry.status, 'revision', double(entry.revision), ...
    'components', componentReports, 'channelsSaved', {channelsToSave}, ...
    'dataChanged', dataChanged, 'modelChanged', modelChanged, 'entry', entry);
end

function [details, targetName] = copyChannel(roiObj, component, overwrite)
[sourceName, sourceExists] = annotationManager.resolveChannel(roiObj, component.prediction);
if ~sourceExists
    error('annotationManager:MissingPrediction', ...
        'Prediction channel for component "%s" does not exist.', component.id);
end
targetName = char(string(component.groundTruth.channel));
if isempty(targetName)
    error('annotationManager:MissingGroundTruthBinding', ...
        'Component "%s" has no GT channel binding.', component.id);
end

roiObj.load('Silent');
sourceIdx = roiObj.findChannelID(sourceName);
if isempty(sourceIdx)
    error('annotationManager:MissingPrediction', ...
        'Prediction channel "%s" could not be loaded.', sourceName);
end
sourceData = roiObj.image(:,:,sourceIdx,:);
targetIdx = roiObj.findChannelID(targetName);
replacedBlank = false;
if isempty(targetIdx)
    roiObj.addChannel(sourceData, targetName, [1 1 1], [0 0 0]);
else
    targetData = roiObj.image(:,:,targetIdx,:);
    replacedBlank = ~any(targetData(:));
    if ~overwrite && ~replacedBlank
        error('annotationManager:GroundTruthExists', ...
            'GT channel "%s" already contains annotations.', targetName);
    end
    if numel(targetIdx) ~= numel(sourceIdx)
        error('annotationManager:ChannelPlaneMismatch', ...
            'Prediction "%s" and GT "%s" have different plane counts.', ...
            sourceName, targetName);
    end
    roiObj.image(:,:,targetIdx,:) = cast(sourceData, class(roiObj.image));
end
details = struct('source', sourceName, 'target', targetName, ...
    'replacedBlankTarget', replacedBlank, 'size', size(sourceData));
end

function details = copyFields(roiObj, component, overwrite)
ensureData(roiObj);
source = component.prediction;
target = component.groundTruth;
sourceIdx = dataseriesIndex(roiObj, source.groupId);
if isempty(sourceIdx) || ~ismember(source.valueField, ...
        roiObj.data(sourceIdx).data.Properties.VariableNames)
    error('annotationManager:MissingPrediction', ...
        'Prediction field "%s.%s" does not exist.', ...
        source.groupId, source.valueField);
end
targetIdx = dataseriesIndex(roiObj, target.groupId);
if isempty(targetIdx)
    ds = dataseries;
    ds.groupid = char(string(target.groupId));
    ds.parentid = char(string(roiObj.id));
    ds.class = "classification";
    ds.type = "temporal";
    ds.data = table;
    if isempty(roiObj.data) || (numel(roiObj.data) == 1 && ...
            isempty(char(string(roiObj.data(1).groupid))))
        roiObj.data = ds;
        targetIdx = 1;
    else
        roiObj.data(end+1) = ds;
        targetIdx = numel(roiObj.data);
    end
end

targetTable = roiObj.data(targetIdx).data;
if ismember(target.valueField, targetTable.Properties.VariableNames) && ...
        ~overwrite && hasDefinedValues(targetTable.(target.valueField))
    error('annotationManager:GroundTruthExists', ...
        'GT field "%s.%s" already contains annotations.', ...
        target.groupId, target.valueField);
end
sourceTable = roiObj.data(sourceIdx).data;
targetTable.(target.valueField) = sourceTable.(source.valueField);
if ~isempty(target.idField)
    if ~isempty(source.idField) && ismember(source.idField, sourceTable.Properties.VariableNames)
        targetTable.(target.idField) = sourceTable.(source.idField);
    else
        targetTable.(target.idField) = labelsToIds( ...
            sourceTable.(source.valueField), component.classes);
    end
end
try, targetTable.Properties.UserData = sourceTable.Properties.UserData; catch, end
roiObj.data(targetIdx).data = targetTable;
roiObj.data(targetIdx) = configureLabelDisplay(roiObj.data(targetIdx), target);
details = struct('source', [char(string(source.groupId)) '.' char(string(source.valueField))], ...
    'target', [char(string(target.groupId)) '.' char(string(target.valueField))], ...
    'rows', height(targetTable));
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

function details = cloneFamily(roiObj, component, overwrite)
[model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
source = char(string(component.prediction.family));
target = char(string(component.groundTruth.family));
provider = char(string(component.groundTruth.maskProvider));
[model, ~, cloneReport] = cellModel.cloneFamily(model, source, target, provider, ...
    'Overwrite', overwrite, 'LineageSource', 'ground_truth');
roiObj.cellModel = model;
details = struct('source', source, 'target', target, 'report', cloneReport);
end

function idx = dataseriesIndex(roiObj, groupId)
idx = [];
try
    idx = find(arrayfun(@(x) strcmp(char(string(x.groupid)), ...
        char(string(groupId))), roiObj.data), 1);
catch
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

function tf = hasDefinedValues(values)
if isempty(values), tf = false; return; end
if iscategorical(values)
    tf = any(~isundefined(values));
elseif isstring(values)
    tf = any(strlength(strtrim(values)) > 0 & lower(values) ~= "undefined");
elseif iscellstr(values)
    s = string(values);
    tf = any(strlength(strtrim(s)) > 0 & lower(s) ~= "undefined");
elseif isnumeric(values) || islogical(values)
    tf = any(isfinite(double(values(:))) & double(values(:)) > 0);
else
    tf = true;
end
end

function ids = labelsToIds(labels, classes)
ids = zeros(numel(labels), 1);
values = string(labels(:));
for i = 1:numel(classes)
    ids(values == string(classes{i})) = i;
end
end

function entry = resetReview(entry)
for i = 1:numel(entry.review)
    entry.review(i).frames(:) = false;
    entry.review(i).complete = false;
end
end

function value = sourceDescription(reports)
parts = strings(0,1);
for i = 1:numel(reports)
    if reports(i).changed && ~isempty(reports(i).source)
        parts(end+1) = string(reports(i).source); %#ok<AGROW>
    end
end
value = char(strjoin(unique(parts, 'stable'), ';'));
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
    if ~isempty(trackIdx) && isfield(classif.trainingParam, 'groundTruthChannelName')
        classif.trainingParam.groundTruthChannelName = ...
            spec.components(trackIdx).groundTruth.channel;
    end
catch
end
end
