function cfg = configuration(p)
% Parse data declarations only; never evaluate MATLAB expressions.
cfg = customModule.setparam();
keys = fieldnames(cfg);
for i = 1:numel(keys)
    if isfield(p, keys{i}), cfg.(keys{i}) = p.(keys{i}); end
end
for i = 1:numel(keys)
    value = cfg.(keys{i});
    if ~(ischar(value) && (isrow(value) || isempty(value))) && ...
            ~(isstring(value) && isscalar(value) && ~ismissing(value))
        error('customModule:Configuration', '%s must be text.', keys{i});
    end
    cfg.(keys{i}) = strtrim(char(value));
end
cfg.entryPoint = regexprep(cfg.entryPoint, '\.m$', '');
if ~isempty(cfg.entryPoint) && isempty(regexp(cfg.entryPoint, ...
        '^[A-Za-z]\w*(\.[A-Za-z]\w*)*$', 'once'))
    error('customModule:EntryPoint', 'Use a function name (optionally package.function), without an expression or path.');
end
cfg.callMode = lower(cfg.callMode);
if ~any(strcmp(cfg.callMode, {'context','arguments'}))
    error('customModule:CallMode', 'callMode must be context or arguments.');
end
cfg.in = parsePorts(cfg.inputPorts);
cfg.out = parsePorts(cfg.outputPorts);
reserved = {'params','run','io','store','pipeline','executionPolicy','runId', ...
    'progress','progressCallback','cancel','customModuleRuns','pipelineRef','targetRef'};
if any(ismember({cfg.out.name}, reserved))
    error('customModule:OutputPorts', 'Output ports cannot replace runner metadata.');
end
try
    cfg.userParams = jsondecode(cfg.parametersJson);
catch ME
    error('customModule:ParametersJson', 'Invalid parametersJson: %s', ME.message);
end
if ~startsWith(cfg.parametersJson, '{') || ~isstruct(cfg.userParams) || ~isscalar(cfg.userParams)
    error('customModule:ParametersJson', 'parametersJson must be a JSON object, for example {"threshold":0.5}.');
end
try
    args = customModule.parseArguments(cfg.argumentsJson);
catch ME
    error('customModule:ArgumentsJson', 'Invalid argumentsJson: %s', ME.message);
end
if ~startsWith(cfg.argumentsJson, '[')
    error('customModule:ArgumentsJson', 'argumentsJson must be a JSON array.');
end
cfg.args = args;
if strcmp(cfg.callMode, 'context') && ~isempty(cfg.args)
    error('customModule:ArgumentsJson', 'Context mode takes ctx only. Put user settings in parametersJson or select arguments mode.');
end
for i = 1:numel(cfg.args)
    arg = cfg.args{i};
    if ~isstruct(arg), continue; end
    fields = fieldnames(arg);
    if ~isscalar(arg) || numel(fields) ~= 1 || ~any(strcmp(fields{1}, {'context','param','value'}))
        error('customModule:Argument', 'Argument %d: use {"context":"roiList"}, {"param":"threshold"}, or {"value":...}.', i);
    end
    if strcmp(fields{1}, 'value'), continue; end
    ref = arg.(fields{1});
    if ~(ischar(ref) || (isstring(ref) && isscalar(ref))) || ...
            isempty(regexp(char(ref), '^[A-Za-z]\w*(\.[A-Za-z]\w*)*$', 'once'))
        error('customModule:Argument', 'Argument %d has an invalid field reference.', i);
    end
    if strcmp(fields{1}, 'param')
        customModule.readField(cfg.userParams, ref);
    else
        root = strtok(char(ref), '.');
        if ~any(strcmp({cfg.in.name}, root))
            error('customModule:Argument', 'Argument %d references ctx.%s; declare %s in inputPorts.', i, char(ref), root);
        end
    end
end
end

function ports = parsePorts(text)
ports = struct('name', {}, 'type', {}, 'required', {}, 'source', {});
if isempty(text), return; end
items = regexp(text, '[,;\s]+', 'split');
for i = 1:numel(items)
    item = regexp(items{i}, '^([A-Za-z]\w*)(?::([A-Za-z]\w*))?$', 'tokens', 'once');
    if isempty(item) || ~isvarname(item{1})
        error('customModule:Ports', 'Invalid port "%s". Use names separated by commas, optionally name:type.', items{i});
    end
    name = item{1};
    type = 'generic';
    if numel(item) > 1 && ~isempty(item{2})
        type = item{2};
    else
        names = {'images','fovList','roiList','channels','masks','dataSeries','shallow','tables','files','artifacts'};
        types = {'imageSet','fovList','roiList','channelSet','maskSet','dataSeriesSet','projectHandle','tableSet','fileSet','artifactSet'};
        idx = find(strcmp(names, name), 1);
        if ~isempty(idx), type = types{idx}; end
    end
    ports(end+1) = struct('name', name, 'type', type, 'required', true, 'source', 'edge'); %#ok<AGROW>
end
if numel(unique({ports.name})) ~= numel(ports)
    error('customModule:Ports', 'Port names must be unique.');
end
end
