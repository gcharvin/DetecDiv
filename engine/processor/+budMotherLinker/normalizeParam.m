function paramout = normalizeParam(param, ctx)
%BUDMOTHERLINKER.NORMALIZEPARAM Upgrade aliases and fill builtin defaults.

if nargin < 2, ctx = struct(); end
defaults = budMotherLinker.setparam(ctx);
if nargin < 1 || isempty(param), param = struct(); end
paramout = param;

aliases = { ...
    'inputChannelName','trackChannelName'; ...
    'instanceChannelName','trackChannelName'; ...
    'outputName','outputFamilyName'; ...
    'modelDir','modelPackage'; ...
    'lynRepo','lynRepository'; ...
    'lynModel','lynCheckpoint'; ...
    'python','pythonExecutable'};
for i = 1:size(aliases,1)
    old = aliases{i,1}; new = aliases{i,2};
    if isfield(paramout, old) && ~isfield(paramout, new)
        paramout.(new) = paramout.(old);
    end
end

names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(paramout, names{i}) || isempty(paramout.(names{i}))
        paramout.(names{i}) = defaults.(names{i});
    end
end

paramout.trackChannelName = readChoice(paramout.trackChannelName);
if isMissingChoice(paramout.trackChannelName)
    paramout.trackChannelName = runtimeTrackChannel(param, ctx);
end
paramout.inputFamily = readChoice(paramout.inputFamily);
paramout.outputFamilyName = strtrim(char(string(paramout.outputFamilyName)));
paramout.modelPackage = strtrim(char(string(paramout.modelPackage)));
paramout.lynRepository = strtrim(char(string(paramout.lynRepository)));
paramout.lynCheckpoint = strtrim(char(string(paramout.lynCheckpoint)));
paramout.pythonExecutable = strtrim(char(string(paramout.pythonExecutable)));

numericNames = {'frameEnd','minLifetime','maxBirthArea','minParentAge', ...
    'maxParentCentroidDistance','maxParentContourDistance','maxCandidates'};
for i = 1:numel(numericNames)
    name = numericNames{i};
    paramout.(name) = readScalar(paramout.(name), defaults.(name));
end
paramout.frameEnd = floor(paramout.frameEnd);
paramout.minLifetime = max(2, floor(paramout.minLifetime));
paramout.maxBirthArea = max(1, paramout.maxBirthArea);
paramout.minParentAge = max(1, floor(paramout.minParentAge));
paramout.maxParentCentroidDistance = max(0, paramout.maxParentCentroidDistance);
paramout.maxParentContourDistance = max(0, paramout.maxParentContourDistance);
paramout.maxCandidates = max(1, min(12, floor(paramout.maxCandidates)));
paramout.overwriteOutputFamily = logical(paramout.overwriteOutputFamily);
paramout.keepRuntimeFiles = logical(paramout.keepRuntimeFiles);
paramout.debug = logical(paramout.debug);

if isMissingChoice(paramout.trackChannelName)
    error('budMotherLinker:MissingTrackChannel', 'Select a tracked label channel.');
end
if isempty(paramout.outputFamilyName)
    error('budMotherLinker:MissingOutputFamily', 'Output family name cannot be empty.');
end
end

function value = readChoice(value)
if iscell(value)
    if isempty(value), value = ''; else, value = value{end}; end
end
value = strtrim(char(string(value)));
end

function value = readScalar(value, fallback)
if iscell(value)
    if isempty(value), value = fallback; else, value = value{end}; end
end
if ischar(value) || isstring(value), value = str2double(string(value)); end
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value), value = fallback; end
value = double(value);
end

function value = runtimeTrackChannel(param, ctx)
% Generic processor bindings historically inject `channels`/`channel`.
% Prefer the node-local binding, then the resolved processor context.
value = firstConcreteChoice(param, {'channels','channel'});
if ~isempty(value), return; end

if isstruct(ctx) && isfield(ctx, 'params') && isstruct(ctx.params)
    value = firstConcreteChoice(ctx.params, {'trackChannelName','channels','channel'});
    if ~isempty(value), return; end
end
if isstruct(ctx) && isfield(ctx, 'io') && isstruct(ctx.io)
    value = firstConcreteChoice(ctx.io, {'requiredChannels'});
    if ~isempty(value), return; end
end
value = firstConcreteChoice(ctx, {'trackChannelName','channels','roiChannels'});
end

function value = firstConcreteChoice(source, fields)
value = '';
if ~isstruct(source), return; end
for i = 1:numel(fields)
    name = fields{i};
    if ~isfield(source, name) || isempty(source.(name)), continue; end
    candidates = normalizeChoices(source.(name));
    candidates = candidates(~cellfun(@isMissingChoice, candidates));
    if isempty(candidates), continue; end
    if numel(candidates) > 1
        preferred = find(contains(lower(string(candidates)), 'trackastra') | ...
            contains(lower(string(candidates)), 'track'), 1, 'last');
        if ~isempty(preferred)
            value = candidates{preferred};
            return;
        end
    end
    value = candidates{end};
    return;
end
end

function choices = normalizeChoices(value)
if iscell(value)
    choices = {};
    for i = 1:numel(value)
        choices = [choices, normalizeChoices(value{i})]; %#ok<AGROW>
    end
elseif ischar(value)
    choices = {value};
elseif isstring(value) || isnumeric(value) || islogical(value)
    choices = cellstr(string(value(:))).';
else
    choices = {char(string(value))};
end
choices = cellfun(@(x) strtrim(char(string(x))), choices, 'UniformOutput', false);
choices = choices(~cellfun(@isempty, choices));
end

function tf = isMissingChoice(value)
if isempty(value)
    tf = true;
    return;
end
value = strtrim(char(string(value)));
tf = isempty(value) || strcmpi(value, 'N/A') || strcmpi(value, '<none>');
end
