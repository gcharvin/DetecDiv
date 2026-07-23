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

if isempty(paramout.trackChannelName) || strcmpi(paramout.trackChannelName, 'N/A')
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
