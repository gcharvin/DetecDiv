function p = normalizeParam(param,ctx,classif)
%CELLLATENTMODEL.NORMALIZEPARAM Normalize runtime and artifact parameters.
if nargin < 2, ctx = struct(); end
if nargin < 3, classif = []; end
defaults = cellLatentModel.utils.defaultExecutionParam();
try
    if ~isempty(classif) && isa(classif,'classi') && ...
            isstruct(classif.executionParam)
        defaults = cellLatentModel.utils.applyOverrides( ...
            defaults,classif.executionParam);
    end
catch
end
if nargin < 1 || isempty(param), param = struct(); end
p = cellLatentModel.utils.applyOverrides(defaults,param);
obsolete = {'pythonExecutable','repositoryRoot','modelPackage', ...
    'cellLatentRepository'};
present = obsolete(isfield(p,obsolete));
if ~isempty(present), p = rmfield(p,present); end

p.trackChannelName = readChoice(p.trackChannelName);
p.gfpChannelName = readChoice(p.gfpChannelName);
runtimeChannels = collectRuntimeChannels(param,ctx,classif);
if isMissingChoice(p.trackChannelName)
    p.trackChannelName = preferred(runtimeChannels, ...
        {'trackastra','track','label','mask'},1);
end
if isMissingChoice(p.gfpChannelName)
    p.gfpChannelName = preferred(runtimeChannels,{'gfp','nuc'},2);
end
if isMissingChoice(p.gfpChannelName), p.gfpChannelName = ''; end
p.inputFamily = readChoice(p.inputFamily);
p.outputFamilyName = strtrim(char(string(p.outputFamilyName)));
p.modelSource = lower(readChoice(p.modelSource));
p.modelPath = strtrim(readChoice(p.modelPath));
p.device = lower(readChoice(p.device));
if isempty(p.modelSource), p.modelSource = 'builtin'; end
if isempty(p.device), p.device = 'auto'; end

numericNames = {'frameEnd','minLifetime','maxBirthArea','minParentAge', ...
    'maxParentCentroidDistance','maxParentContourDistance','maxCandidates', ...
    'maxNewTracksPerFrame'};
for i = 1:numel(numericNames)
    name = numericNames{i};
    p.(name) = readScalar(p.(name),defaults.(name));
end
p.frameEnd = floor(p.frameEnd);
p.minLifetime = max(2,floor(p.minLifetime));
p.maxBirthArea = max(1,p.maxBirthArea);
p.minParentAge = max(1,floor(p.minParentAge));
p.maxParentCentroidDistance = max(0,p.maxParentCentroidDistance);
p.maxParentContourDistance = max(0,p.maxParentContourDistance);
p.maxCandidates = max(1,min(12,floor(p.maxCandidates)));
p.maxNewTracksPerFrame = max(0,floor(p.maxNewTracksPerFrame));
p.trackingLoadGuard = logical(p.trackingLoadGuard);
p.overwriteOutputFamily = logical(p.overwriteOutputFamily);
p.debug = logical(p.debug);

if strcmp(p.modelSource,'trained')
    if isempty(p.modelPath)
        try
            candidate = fullfile(classif.path,'models','latest','ensemble.pt');
            if isfile(candidate), p.modelPath = candidate; end
        catch
        end
    elseif ~isfile(p.modelPath)
        try
            candidate = fullfile(classif.path,p.modelPath);
            if isfile(candidate), p.modelPath = candidate; end
        catch
        end
    end
end
if isMissingChoice(p.trackChannelName)
    error('cellLatentModel:MissingTrackChannel', ...
        'Select a tracked-label channel.');
end
if isempty(p.outputFamilyName)
    error('cellLatentModel:MissingOutputFamily', ...
        'Output family name cannot be empty.');
end
if ~any(strcmp(p.modelSource,{'builtin','trained'}))
    error('cellLatentModel:InvalidModelSource', ...
        'modelSource must be builtin or trained.');
end
if strcmp(p.modelSource,'trained') && ...
        (isempty(p.modelPath) || ~isfile(p.modelPath))
    error('cellLatentModel:MissingTrainedModel', ...
        'The trained ensemble checkpoint was not found.');
end
if ~any(strcmp(p.device,{'auto','cuda','cpu'}))
    error('cellLatentModel:InvalidDevice', ...
        'device must be auto, cuda, or cpu.');
end
end

function channels = collectRuntimeChannels(param,ctx,classif)
channels = {};
sources = {};
try sources{end+1} = classif.channelName; catch, end
try sources{end+1} = classif.channelName2; catch, end
try sources{end+1} = ctx.io.requiredChannels; catch, end
try sources{end+1} = ctx.params.channels; catch, end
try sources{end+1} = ctx.params.channel; catch, end
try sources{end+1} = param.channels; catch, end
try sources{end+1} = param.channel; catch, end
for i = 1:numel(sources)
    values = cellstr(string(sources{i}));
    values = values(strlength(string(values)) > 0);
    channels = [channels values(:)']; %#ok<AGROW>
end
channels = unique(channels,'stable');
end

function value = preferred(channels,patterns,fallback)
value = '';
for i = 1:numel(patterns)
    hit = find(contains(lower(string(channels)),patterns{i}),1,'last');
    if ~isempty(hit), value = channels{hit}; return; end
end
if numel(channels) >= fallback, value = channels{fallback}; end
end

function value = readChoice(value)
if iscell(value)
    if isempty(value), value = ''; else, value = value{end}; end
end
value = strtrim(char(string(value)));
end

function value = readScalar(value,fallback)
if iscell(value)
    if isempty(value), value = fallback; else, value = value{end}; end
end
if ischar(value) || isstring(value), value = str2double(string(value)); end
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    value = fallback;
end
value = double(value);
end

function tf = isMissingChoice(value)
value = strtrim(char(string(value)));
tf = isempty(value) || strcmpi(value,'N/A') || ...
    strcmpi(value,'<none>') || strcmpi(value,'<auto>');
end
