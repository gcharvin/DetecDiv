function report = quickValidate(roiObj, spec, varargin)
%ANNOTATIONMANAGER.QUICKVALIDATE Cheap, non-blocking checks after an edit.
% This intentionally avoids full-H5 scans. Final approval still calls the
% exhaustive annotationManager.validate implementation.

p = inputParser;
p.addParameter('Components', {}, @(x) ischar(x) || isstring(x) || iscell(x));
p.addParameter('Frames', [], @isnumeric);
p.parse(varargin{:});

componentIds = normalizeIds(p.Results.Components, spec);
frames = normalizeFrames(p.Results.Frames, annotationManager.frameCount(roiObj));
errors = strings(0,1);
warnings = strings(0,1);
checked = strings(0,1);
for i = 1:numel(spec.components)
    component = spec.components(i);
    if ~any(strcmp(componentIds, component.id)), continue; end
    checked(end+1,1) = string(component.id); %#ok<AGROW>
    try
        switch char(string(component.storage))
            case 'channel'
                quickCheckChannel(roiObj, component, frames);
            case 'dataseries'
                quickCheckDataseries(roiObj, component, frames);
            case 'cell_model_family'
                quickCheckFamily(roiObj, component, frames);
        end
    catch ME
        errors(end+1,1) = sprintf('%s: %s', component.id, ME.message); %#ok<AGROW>
    end
end

report = struct('valid', isempty(errors), 'errors', errors, ...
    'warnings', warnings, 'components', checked, 'frames', frames);
end

function quickCheckChannel(roiObj, component, frames)
[channel, exists] = annotationManager.resolveChannel(roiObj, component.groundTruth);
if ~exists, error('Ground-truth channel is missing.'); end
if isempty(roiObj.image), return; end
pix = roiObj.findChannelID(channel);
if isempty(pix), error('Ground-truth channel is not loaded.'); end
if isempty(frames), frames = double(roiObj.display.frame); end
frames = frames(frames <= size(roiObj.image,4));
values = roiObj.image(:,:,pix,frames);
if ~isnumeric(values) && ~islogical(values)
    error('Mask data must be numeric.');
end
numericValues = double(values(:));
if any(~isfinite(numericValues)) || any(numericValues < 0)
    error('Mask labels must be finite and non-negative.');
end
if any(strcmp(component.kind, {'instance_mask','tracked_instances'})) && ...
        any(numericValues ~= round(numericValues))
    error('Instance labels must be integers.');
end
end

function quickCheckDataseries(roiObj, component, frames)
asset = component.groundTruth;
idx = find(arrayfun(@(x) strcmp(char(string(x.groupid)), ...
    char(string(asset.groupId))), roiObj.data), 1);
if isempty(idx) || ~ismember(asset.valueField, ...
        roiObj.data(idx).data.Properties.VariableNames)
    error('Ground-truth label field is missing.');
end
if isempty(frames), frames = double(roiObj.display.frame); end
values = roiObj.data(idx).data.(asset.valueField);
frames = frames(frames <= numel(values));
if any(undefinedValues(values(frames)))
    error('Edited frame still contains an undefined label.');
end
end

function quickCheckFamily(roiObj, component, frames)
model = [];
try
    if isstruct(roiObj.cellModel) && isfield(roiObj.cellModel, 'schema_version')
        model = roiObj.cellModel;
    end
catch
end
if isempty(model), [model, ~] = roiObj.loadCellModel('MigrateLegacy', true); end
[familyIndex, familyId] = cellModel.familyIndex(model, component.groundTruth.family);
if isempty(familyIndex), error('Ground-truth object family is missing.'); end

if strcmp(component.kind, 'tracking')
    if isempty(frames), frames = double(roiObj.display.frame); end
    rows = model.instances.family_id == familyId & ...
        ismember(double(model.instances.frame), frames);
    tracks = model.instances.track_id(rows);
    objectFrames = model.instances.frame(rows);
    if any(tracks == 0), error('An edited object has no track identity.'); end
    pairs = [double(objectFrames(:)) double(tracks(:))];
    if size(unique(pairs, 'rows'),1) ~= size(pairs,1)
        error('A frame contains multiple objects assigned to the same track.');
    end
    quickCheckProviderFrames(roiObj, model, familyIndex, familyId, frames);
elseif strcmp(component.kind, 'lineage')
    annotationManager.validateParentage(model, familyId, 'Throw', true);
end
end

function quickCheckProviderFrames(roiObj, model, familyIndex, familyId, frames)
provider = char(string(model.families.mask_provider{familyIndex}));
if isempty(provider) || isempty(roiObj.image), return; end
pix = roiObj.findChannelID(provider);
if isempty(pix), return; end
frames = frames(frames >= 1 & frames <= size(roiObj.image,4));
for frame = frames
    actual = unique(double(roiObj.image(:,:,pix,frame)));
    actual = actual(actual > 0);
    rows = model.instances.family_id == familyId & ...
        model.instances.frame == uint32(frame);
    expected = unique(double(model.instances.mask_label(rows)));
    expected = expected(expected > 0);
    if ~isequal(actual(:), expected(:))
        error('Mask provider and object family disagree on frame %d.', frame);
    end
end
end

function ids = normalizeIds(value, spec)
if isempty(value)
    ids = {spec.components.id};
elseif ischar(value) || isstring(value)
    ids = cellstr(string(value));
else
    ids = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
end
end

function frames = normalizeFrames(value, total)
frames = unique(round(double(value(:)')), 'stable');
frames = frames(isfinite(frames) & frames >= 1 & frames <= total);
end

function tf = undefinedValues(values)
if iscategorical(values)
    tf = isundefined(values) | lower(string(values)) == "undefined";
elseif isstring(values) || iscellstr(values) || ischar(values)
    text = lower(strtrim(string(values)));
    tf = ismissing(text) | text == "" | text == "undefined";
elseif isnumeric(values)
    tf = ~isfinite(double(values)) | double(values) <= 0;
else
    tf = false(size(values));
end
tf = tf(:);
end
