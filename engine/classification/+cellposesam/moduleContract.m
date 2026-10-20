function contract = moduleContract(params)
% cellposesam.moduleContract  Pure, parameter-driven pipeline IO metadata.
%
% Returns a detecdiv.module_contract.v1 patch over the generic classifier
% contract. No classifier, Python environment, model, or ROI data is loaded.
% Keep legacy contract defaults here: executionSpec.defaults describes new
% configurations and must not silently supply values to historical nodes.

if nargin < 1 || ~isstruct(params)
    params = struct();
end

spec = cellposesam.executionSpec();
outputType = normalizeOutputMode(paramValue(params, ...
    {'outputType','outputMode'}, 'segmentation'));
hasMasks = any(strcmp(outputType, {'segmentation','both'}));
hasProbability = any(strcmp(outputType, {'proba','both'}));

contract = struct();
contract.format = 'detecdiv.module_contract.v1';
contract.in = portDef('roiList', 'roiList', true);
contract.out = portDef('roiList', 'roiList', true);
contract.parameters = struct('static', {spec.staticKeys});
contract.requirements = struct('roi', struct('required', true, ...
    'channelsMin', 1, 'masks', false, 'dataSeries', false));
contract.capabilities = struct('preservesRoiList', true, ...
    'outputsMasks', hasMasks, 'roiMasks', hasMasks, ...
    'outputsChannels', hasProbability, 'roiChannels', hasProbability, ...
    'outputsDataSeries', false, 'roiDataSeries', false);
contract.binding = struct('scope', 'roi', 'outputScope', 'roi', ...
    'mode', 'singleChannel', 'selectorKeys', {{'channels','channel'}}, ...
    'exactCount', 1, 'resolveAt', 'design');
contract.resources = struct();
contract.resources.in = resourceDef('channel', 'roi_image', 'channels', ...
    'channels', 'channels', 'channels', true, '');
contract.resources.out = resourceDef();

if hasMasks
    contract.out(end+1) = portDef('masks', 'maskSet', true);
    contract.resources.out(end+1) = resourceDef('mask', 'segmentation', ...
        'segmentation', 'outputName', 'masks', 'outputName', false, 'roiMasks');
end
if hasProbability
    contract.out(end+1) = portDef('channels', 'channelSet', false);
    contract.resources.out(end+1) = resourceDef('channel', 'probability', ...
        'cellprob', 'probabilityOutputName', 'channels', ...
        'probabilityOutputName', false, 'roiChannel');
end

% Additive metadata only: existing maskSet ports/resources retain their
% historical meaning and execution still owns ID propagation.
outputIdentity = 'probability';
if hasMasks
    if logicalParam(paramValue(params, {'trackInstances'}, true), true)
        outputIdentity = 'propagated_instance_ids';
    else
        outputIdentity = 'frame_local_instances';
    end
end
contract.semantics = struct('inputIdentity', 'roi_images', ...
    'outputIdentity', outputIdentity);
contract.summary = spec.summary;
end

function value = paramValue(params, names, fallback)
value = fallback;
for i = 1:numel(names)
    name = names{i};
    if isfield(params, name) && ~isempty(params.(name))
        value = params.(name);
        return;
    end
end
end

function mode = normalizeOutputMode(value)
% Preserve pipelineNodeContract's historical aliases and invalid fallback.
mode = lower(strtrim(choiceToChar(value)));
mode = strrep(strrep(mode, '-', '_'), ' ', '_');
if ~any(strcmp(mode, {'segmentation','proba','probability','both'}))
    mode = 'segmentation';
elseif strcmp(mode, 'probability')
    mode = 'proba';
end
end

function txt = choiceToChar(value)
txt = '';
if isempty(value)
    return;
end
if iscell(value)
    flat = value(~cellfun(@isempty, value));
    if ~isempty(flat)
        txt = char(string(flat{end}));
    end
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

function value = logicalParam(raw, fallback)
% Match classify's current trackInstances interpretation without executing it.
value = logical(fallback);
try
    if islogical(raw) || isnumeric(raw)
        value = logical(raw(1));
    else
        value = any(strcmpi(strtrim(char(string(raw))), {'1','true','yes','on'}));
    end
catch
    value = logical(fallback);
end
end

function port = portDef(name, type, required)
port = struct('name', name, 'type', type, 'required', logical(required), ...
    'source', 'edge');
end

function resource = resourceDef(type, role, symbol, param, port, nameParam, required, transfer)
if nargin == 0
    resource = struct('type', {}, 'role', {}, 'symbol', {}, 'param', {}, ...
        'port', {}, 'nameParam', {}, 'required', {}, 'transfer', {});
    return;
end
resource = struct('type', type, 'role', role, 'symbol', symbol, ...
    'param', param, 'port', port, 'nameParam', nameParam, ...
    'required', logical(required), 'transfer', transfer);
end
