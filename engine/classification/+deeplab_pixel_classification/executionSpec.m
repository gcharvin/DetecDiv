function spec = executionSpec(classif)
% deeplab_pixel_classification.executionSpec
% Execution-time parameter contract for pipeline2.

if nargin < 1
    classif = [];
end

spec = struct();
spec.summary = 'DeepLab v3+ pixel classifier: writes segmentation masks, probability channels, or both.';
spec.staticKeys = {'outputType','executionEnvironment'};
spec.outputKeys = {'outputName','probabilityOutputName'};
spec.defaultImportKeys = {'outputType','executionEnvironment'};
spec.pathKeys = {};

spec.defaults = struct( ...
    'outputType', 'segmentation', ...
    'outputName', 'deeplab_pixels', ...
    'probabilityOutputName', 'deeplab_pixels_prob', ...
    'executionEnvironment', 'module_default');

spec.labels = struct( ...
    'outputType', 'Output resource', ...
    'outputName', 'Segmentation output name', ...
    'probabilityOutputName', 'Probability output name', ...
    'executionEnvironment', 'Execution environment');

spec.tips = struct( ...
    'outputType', 'Controls whether this node writes a segmentation mask, a grayscale probability map, or both.', ...
    'outputName', 'Name used for the segmentation mask resource and ROI result channel.', ...
    'probabilityOutputName', 'Name used for the grayscale DeepLab probability ROI image channel.', ...
    'executionEnvironment', 'Optional node-local CPU/GPU choice; module_default keeps the run-level policy.');

spec.choices = struct();
spec.choices.outputType = {'segmentation','probability','both'};
spec.choices.executionEnvironment = {'module_default','cpu','gpu'};

spec.defaults = mergeDefaultsFromClassi(spec.defaults, classif);
spec.defaults.outputType = normalizeOutputType(spec.defaults.outputType);
spec.defaults.executionEnvironment = normalizeExecutionEnvironment(spec.defaults.executionEnvironment);
end

function defaults = mergeDefaultsFromClassi(defaults, classif)
if isempty(classif)
    return;
end

sources = {};
try
    if isobject(classif) && isprop(classif, 'executionParam') && isstruct(classif.executionParam)
        sources{end+1} = classif.executionParam;
    elseif isstruct(classif) && isfield(classif, 'executionParam') && isstruct(classif.executionParam)
        sources{end+1} = classif.executionParam;
    end
catch
end
try
    if isobject(classif) && isprop(classif, 'runProfiles') && isstruct(classif.runProfiles) && ...
            isfield(classif.runProfiles, 'classify') && isstruct(classif.runProfiles.classify)
        sources{end+1} = classif.runProfiles.classify;
    elseif isstruct(classif) && isfield(classif, 'runProfiles') && isstruct(classif.runProfiles) && ...
            isfield(classif.runProfiles, 'classify') && isstruct(classif.runProfiles.classify)
        sources{end+1} = classif.runProfiles.classify;
    end
catch
end

keys = fieldnames(defaults);
for s = 1:numel(sources)
    src = sources{s};
    for i = 1:numel(keys)
        key = keys{i};
        if isfield(src, key) && ~isempty(src.(key))
            defaults.(key) = src.(key);
        end
    end
end

try
    if isobject(classif) && isprop(classif, 'outputType') && ~isempty(classif.outputType)
        defaults.outputType = classif.outputType;
    elseif isstruct(classif) && isfield(classif, 'outputType') && ~isempty(classif.outputType)
        defaults.outputType = classif.outputType;
    end
catch
end
try
    if isobject(classif) && isprop(classif, 'strid') && ~isempty(classif.strid)
        defaults.outputName = classif.strid;
        defaults.probabilityOutputName = [char(string(classif.strid)) '_prob'];
    elseif isstruct(classif) && isfield(classif, 'strid') && ~isempty(classif.strid)
        defaults.outputName = classif.strid;
        defaults.probabilityOutputName = [char(string(classif.strid)) '_prob'];
    end
catch
end
end

function outputType = normalizeOutputType(value)
outputType = lower(strtrim(choiceToChar(value)));
outputType = strrep(outputType, '-', '_');
outputType = strrep(outputType, ' ', '_');
switch outputType
    case {'probability','probabilities','probability_map','proba'}
        outputType = 'probability';
    case {'seg','mask','masks','semantic','semantic_segmentation'}
        outputType = 'segmentation';
    case {'both','segmentation_and_probability','all'}
        outputType = 'both';
    otherwise
        if isempty(outputType)
            outputType = 'segmentation';
        end
end
end

function env = normalizeExecutionEnvironment(value)
env = lower(strtrim(choiceToChar(value)));
env = strrep(env, '-', '_');
env = strrep(env, ' ', '_');
switch env
    case {'gpu','force_gpu'}
        env = 'gpu';
    case {'cpu','force_cpu'}
        env = 'cpu';
    otherwise
        env = 'module_default';
end
end

function txt = choiceToChar(value)
txt = '';
if isempty(value)
    return;
end
if iscell(value)
    flat = value(~cellfun(@isempty, value));
    if isempty(flat)
        return;
    end
    txt = char(string(flat{end}));
elseif ischar(value)
    txt = value;
elseif isstring(value) || isnumeric(value) || islogical(value) || iscategorical(value)
    vals = string(value(:));
    if ~isempty(vals)
        txt = char(vals(end));
    end
else
    try
        txt = char(string(value));
    catch
        txt = '';
    end
end
end
