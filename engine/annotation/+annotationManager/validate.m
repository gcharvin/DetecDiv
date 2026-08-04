function report = validate(roiObj, spec, varargin)
%ANNOTATIONMANAGER.VALIDATE Validate GT assets and review coverage.

p = inputParser;
p.addParameter('RequireReviewed', true, @(x) islogical(x) && isscalar(x));
p.addParameter('AllowPartial', spec.allowPartialApproval, ...
    @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

summary = annotationManager.inspect(roiObj, spec);
errors = strings(0,1);
warnings = strings(0,1);
for i = 1:numel(summary.components)
    component = summary.components(i);
    if component.required && ~component.groundTruthExists
        errors(end+1) = sprintf('Missing GT component "%s" (%s).', ...
            component.id, component.kind); %#ok<AGROW>
    end
end

if p.Results.RequireReviewed
    for i = 1:numel(summary.coverage.components)
        coverage = summary.coverage.components(i);
        component = spec.components(i);
        if ~component.required, continue; end
        if p.Results.AllowPartial
            if coverage.reviewed == 0
                errors(end+1) = sprintf('Component "%s" has no reviewed unit.', ...
                    component.id); %#ok<AGROW>
            elseif coverage.reviewed < coverage.total
                warnings(end+1) = sprintf('Component "%s" is partially reviewed (%d/%d).', ...
                    component.id, coverage.reviewed, coverage.total); %#ok<AGROW>
            end
        elseif coverage.reviewed < coverage.total
            errors(end+1) = sprintf('Component "%s" is not fully reviewed (%d/%d).', ...
                component.id, coverage.reviewed, coverage.total); %#ok<AGROW>
        end
    end
end

for i = 1:numel(spec.components)
    component = spec.components(i);
    if ~summary.components(i).groundTruthExists, continue; end
    try
        validateComponent(roiObj, component, summary.entry);
    catch ME
        errors(end+1) = sprintf('%s: %s', component.id, ME.message); %#ok<AGROW>
    end
end

report = struct('valid', isempty(errors), 'errors', errors, ...
    'warnings', warnings, 'summary', summary);
end

function validateComponent(roiObj, component, entry)
switch char(string(component.storage))
    case 'channel'
        [channel, exists] = annotationManager.resolveChannel(roiObj, component.groundTruth);
        if ~exists, return; end
        if any(strcmp(component.kind, {'semantic_mask','instance_mask', ...
                'tracked_instances'}))
            values = readChannel(roiObj, channel);
            if ~isnumeric(values) && ~islogical(values)
                error('Mask data must be numeric.');
            end
            if any(~isfinite(double(values(:)))) || any(double(values(:)) < 0)
                error('Mask labels must be finite and non-negative.');
            end
            if any(strcmp(component.kind, {'instance_mask','tracked_instances'})) && ...
                    any(double(values(:)) ~= round(double(values(:))))
                error('Instance labels must be integers.');
            end
        end
    case 'dataseries'
        ensureData(roiObj);
        asset = component.groundTruth;
        idx = find(arrayfun(@(x) strcmp(char(string(x.groupid)), ...
            char(string(asset.groupId))), roiObj.data), 1);
        values = roiObj.data(idx).data.(asset.valueField);
        if isempty(values), error('GT label field is empty.'); end
        reviewIdx = find(strcmp(string({entry.review.component_id}), ...
            string(component.id)), 1, 'first');
        if ~isempty(reviewIdx) && strcmp(entry.review(reviewIdx).unit, 'frame')
            reviewed = find(entry.review(reviewIdx).frames);
            reviewed = reviewed(reviewed <= numel(values));
            if any(undefinedValues(values(reviewed)))
                error('Reviewed frames still contain undefined labels.');
            end
        elseif ~isempty(reviewIdx) && entry.review(reviewIdx).complete && ...
                all(undefinedValues(values))
            error('Reviewed annotation still contains no defined label.');
        end
    case 'cell_model_family'
        [model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
        validation = cellModel.validate(model);
        if ~validation.ok
            error('Cell model is invalid: %s', strjoin(validation.errors, '; '));
        end
        [idx, ~] = cellModel.familyIndex(model, component.groundTruth.family);
        expected = char(string(component.groundTruth.maskProvider));
        if ~isempty(expected) && ~strcmp(char(string(model.families.mask_provider{idx})), expected)
            error('Object family uses mask provider "%s" instead of "%s".', ...
                model.families.mask_provider{idx}, expected);
        end
end
end

function tf = undefinedValues(values)
if isempty(values), tf = false(size(values)); return; end
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

function values = readChannel(roiObj, channel)
h5File = fullfile(char(string(roiObj.path)), ...
    ['im_' char(string(roiObj.id)) '.h5']);
if isfile(h5File)
    info = h5info(h5File);
    for i = 1:numel(info.Datasets)
        path = ['/' info.Datasets(i).Name];
        logicalName = info.Datasets(i).Name;
        try, logicalName = h5readatt(h5File, path, 'channel_name'); catch, end
        if strcmpi(char(string(logicalName)), channel)
            values = h5read(h5File, path);
            return;
        end
    end
end
if isempty(roiObj.image), roiObj.load('Silent'); end
idx = roiObj.findChannelID(channel);
values = roiObj.image(:,:,idx,:);
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
