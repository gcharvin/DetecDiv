function paramout = normalizeParam(param, ctx, classif)
%BUDMOTHERLINKER.NORMALIZEPARAM Upgrade aliases and fill classifier defaults.

if nargin < 2, ctx = struct(); end
if nargin < 3, classif = []; end
defaults = budMotherLinker.utils.defaultExecutionParam();
try
    if ~isempty(classif) && isa(classif, 'classi') && ...
            isstruct(classif.executionParam)
        defaults = budMotherLinker.utils.applyOverrides( ...
            defaults, classif.executionParam);
    end
catch
end
if nargin < 1 || isempty(param), param = struct(); end
paramout = param;

aliases = { ...
    'inputChannelName','trackChannelName'; ...
    'instanceChannelName','trackChannelName'; ...
    'outputName','outputFamilyName'};
for i = 1:size(aliases,1)
    old = aliases{i,1}; new = aliases{i,2};
    if isfield(paramout, old) && ~isfield(paramout, new)
        paramout.(new) = paramout.(old);
    end
end
obsolete = {'modelPackage','lynRepository','lynCheckpoint','pythonExecutable', ...
    'modelDir','lynRepo','lynModel','python','keepRuntimeFiles'};
present = obsolete(isfield(paramout, obsolete));
if ~isempty(present), paramout = rmfield(paramout, present); end

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

numericNames = {'frameEnd','minLifetime','maxBirthArea','minParentAge', ...
    'maxParentCentroidDistance','maxParentContourDistance','maxCandidates', ...
    'rankMarginThreshold','maxNewTracksPerFrame','motherRefractoryFrames', ...
    'youngMotherFrames','solverBeamSize'};
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
if paramout.rankMarginThreshold >= 0
    paramout.rankMarginThreshold = min(1, paramout.rankMarginThreshold);
end
paramout.maxNewTracksPerFrame = max(0, floor(paramout.maxNewTracksPerFrame));
paramout.motherRefractoryFrames = max(0, floor(paramout.motherRefractoryFrames));
paramout.youngMotherFrames = max(0, floor(paramout.youngMotherFrames));
paramout.solverBeamSize = max(1, floor(paramout.solverBeamSize));
paramout.trackingLoadGuard = logical(paramout.trackingLoadGuard);
paramout.globalSolver = logical(paramout.globalSolver);
paramout.reviewGlobalReassignments = logical(paramout.reviewGlobalReassignments);
paramout.overwriteOutputFamily = logical(paramout.overwriteOutputFamily);
paramout.debug = logical(paramout.debug);
paramout.modelSource = lower(strtrim(readChoice(paramout.modelSource)));
paramout.modelPath = strtrim(readChoice(paramout.modelPath));
if isempty(paramout.modelSource), paramout.modelSource = 'builtin'; end
if strcmp(paramout.modelSource, 'trained') && isempty(paramout.modelPath)
    try
        if ~isempty(classif) && isprop(classif, 'path')
            candidate = fullfile(classif.path, 'models', 'latest', 'model.mat');
            if isfile(candidate), paramout.modelPath = candidate; end
        end
    catch
    end
end
if ~isempty(paramout.modelPath) && ~isfile(paramout.modelPath)
    try
        if ~isempty(classif) && isprop(classif, 'path')
            candidate = fullfile(classif.path, paramout.modelPath);
            if isfile(candidate), paramout.modelPath = candidate; end
        end
    catch
    end
end

if isMissingChoice(paramout.trackChannelName)
    error('budMotherLinker:MissingTrackChannel', 'Select a tracked label channel.');
end
if isempty(paramout.outputFamilyName)
    error('budMotherLinker:MissingOutputFamily', 'Output family name cannot be empty.');
end
if ~any(strcmp(paramout.modelSource, {'builtin','trained'}))
    error('budMotherLinker:InvalidModelSource', ...
        'modelSource must be builtin or trained.');
end
if strcmp(paramout.modelSource, 'trained') && ...
        (isempty(paramout.modelPath) || ~isfile(paramout.modelPath))
    error('budMotherLinker:MissingTrainedModel', ...
        'The trained model artifact was not found. Format and train this classifier first.');
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
