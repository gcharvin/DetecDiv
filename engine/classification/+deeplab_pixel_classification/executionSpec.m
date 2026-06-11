function spec = executionSpec(classif)
% deeplab_pixel_classification.executionSpec
% Execution-time parameter contract for pipeline2.

if nargin < 1
    classif = [];
end

spec = struct();
spec.summary = 'DeepLab v3+ pixel classifier: writes semantic segmentation masks, probability channels, or postprocessed masks.';
spec.staticKeys = {'outputType','executionEnvironment','postprocessThreshold','outputFun','outputArg'};
spec.outputKeys = {'outputName'};
spec.defaultImportKeys = {'outputType','executionEnvironment'};
spec.pathKeys = {};

spec.defaults = struct( ...
    'outputType', 'segmentation', ...
    'outputName', 'deeplab_pixels', ...
    'executionEnvironment', 'module_default', ...
    'postprocessThreshold', 0.9, ...
    'outputFun', 'post', ...
    'outputArg', {{'threshold','0.9'}});

spec.labels = struct( ...
    'outputType', 'Output resource', ...
    'outputName', 'Output name', ...
    'executionEnvironment', 'Execution environment', ...
    'postprocessThreshold', 'Postprocess threshold', ...
    'outputFun', 'Postprocess function', ...
    'outputArg', 'Postprocess arguments');

spec.tips = struct( ...
    'outputType', 'segmentation writes one indexed results channel; probability writes one channel per class; postprocessing calls outputFun on probability maps.', ...
    'outputName', 'Name used as the prefix for ROI result channels.', ...
    'executionEnvironment', 'Optional node-local CPU/GPU choice; module_default keeps the run-level policy.', ...
    'postprocessThreshold', 'Threshold forwarded to the default postprocessing function.', ...
    'outputFun', 'MATLAB function used when outputType is postprocessing.', ...
    'outputArg', 'Cell array of extra arguments passed to outputFun.');

spec.choices = struct();
spec.choices.outputType = {'segmentation','proba','postprocessing'};
spec.choices.executionEnvironment = {'module_default','cpu','gpu'};

spec.contract = defaultContractOverride();
spec.defaults = mergeDefaultsFromClassi(spec.defaults, classif);
spec.defaults.outputType = normalizeOutputType(spec.defaults.outputType);
spec.defaults.executionEnvironment = normalizeExecutionEnvironment(spec.defaults.executionEnvironment);
end

function contract = defaultContractOverride()
contract = struct();
contract.binding = struct( ...
    'scope', 'roi', ...
    'outputScope', 'roi', ...
    'mode', 'channelSet', ...
    'selectorKeys', {{'channels','channel'}}, ...
    'resolveAt', 'design');
contract.parameters = struct( ...
    'static', {{'outputType','executionEnvironment','postprocessThreshold','outputFun','outputArg'}}, ...
    'run', {{}}, ...
    'paths', {{}});
contract.capabilities = struct( ...
    'preservesRoiList', true, ...
    'roiMasks', true, ...
    'roiChannels', true, ...
    'outputsMasks', true, ...
    'outputsChannels', true, ...
    'roiDataSeries', false, ...
    'outputsDataSeries', false);
contract.resources = struct();
contract.resources.in = resource('channel', 'roi_image', 'channels', 'channels', 'channels', 'channels', true, '');
contract.resources.out = [ ...
    resource('mask', 'segmentation', 'masks', 'outputName', 'masks', 'outputName', false, 'roiMasks'), ...
    resource('channel', 'probability', 'probability', 'outputName', 'channels', 'outputName', false, 'roiChannel') ...
    ];
end

function r = resource(type, role, symbol, param, port, nameParam, required, transfer)
r = struct( ...
    'type', type, ...
    'role', role, ...
    'symbol', symbol, ...
    'param', param, ...
    'port', port, ...
    'nameParam', nameParam, ...
    'required', required, ...
    'transfer', transfer);
end

function defaults = mergeDefaultsFromClassi(defaults, classif)
if isempty(classif)
    return;
end

sources = {};
try
    if isobject(classif) && isprop(classif, 'executionParam') && isstruct(classif.executionParam)
        sources{end+1} = classif.executionParam; %#ok<AGROW>
    elseif isstruct(classif) && isfield(classif, 'executionParam') && isstruct(classif.executionParam)
        sources{end+1} = classif.executionParam; %#ok<AGROW>
    end
catch
end
try
    if isobject(classif) && isprop(classif, 'runProfiles') && isstruct(classif.runProfiles) && ...
            isfield(classif.runProfiles, 'classify') && isstruct(classif.runProfiles.classify)
        sources{end+1} = classif.runProfiles.classify; %#ok<AGROW>
    elseif isstruct(classif) && isfield(classif, 'runProfiles') && isstruct(classif.runProfiles) && ...
            isfield(classif.runProfiles, 'classify') && isstruct(classif.runProfiles.classify)
        sources{end+1} = classif.runProfiles.classify; %#ok<AGROW>
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
    elseif isstruct(classif) && isfield(classif, 'strid') && ~isempty(classif.strid)
        defaults.outputName = classif.strid;
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
        outputType = 'proba';
    case {'seg','mask','masks','semantic','semantic_segmentation'}
        outputType = 'segmentation';
    case {'post','postprocess','postprocessing'}
        outputType = 'postprocessing';
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
