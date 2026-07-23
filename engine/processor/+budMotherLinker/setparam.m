function paramout = setparam(ctx)
%BUDMOTHERLINKER.SETPARAM Defaults for the builtin generic lineage linker.

if nargin < 1 || isempty(ctx), ctx = struct(); end
channels = availableChannels(ctx);
if isempty(channels), channels = {'N/A'}; end

preferred = channels{end};
for i = 1:numel(channels)
    name = lower(char(string(channels{i})));
    if contains(name, 'trackastra') || contains(name, 'track')
        preferred = channels{i};
    end
end

paramout = struct();
paramout.trackChannelName = [{'N/A'}, channels(:).', {preferred}];
paramout.inputFamily = {'<auto>', '<auto>'};
paramout.outputFamilyName = 'Bud mother HGB16';
paramout.modelPackage = 'auto';
paramout.lynRepository = 'auto';
paramout.lynCheckpoint = 'auto';
paramout.pythonExecutable = 'auto';
paramout.frameEnd = -1;
paramout.minLifetime = 5;
paramout.maxBirthArea = 400;
paramout.minParentAge = 2;
paramout.maxParentCentroidDistance = 60;
paramout.maxParentContourDistance = 20;
paramout.maxCandidates = 4;
paramout.overwriteOutputFamily = true;
paramout.keepRuntimeFiles = false;
paramout.debug = false;
paramout.tip = { ...
    'Tracked indexed-mask channel. Labels must be stable track identifiers.', ...
    'Input cell-model family used to preserve existing latent cell states; auto resolves from the mask provider.', ...
    'Dedicated output family. It shares the mask provider but owns an independent genealogy.', ...
    'Frozen HGB-16 model package, or auto for environment/sibling-repository discovery.', ...
    'LYN-trace source repository used only to calculate the published 16 descriptors.', ...
    'LYN checkpoint used to initialize its feature extractor; the neural-network score is not used.', ...
    'Python executable, or auto for DetecDiv/pyenv discovery.', ...
    'Last frame to analyze; -1 means the complete sequence.', ...
    'Minimum number of visible frames for a newly appearing bud track.', ...
    'Maximum bud area at first appearance.', ...
    'Minimum age in frames of a candidate mother.', ...
    'Maximum mother/bud centroid distance in pixels.', ...
    'Maximum mother/bud contour distance in pixels.', ...
    'Maximum candidate mothers evaluated by HGB-16.', ...
    'Replace the genealogy previously produced in the named output family.', ...
    'Keep the temporary exported track stack for debugging.', ...
    'Print backend paths and inference summary.'};
end

function channels = availableChannels(ctx)
channels = {};
if isfield(ctx, 'channels') && ~isempty(ctx.channels)
    channels = normalizeList(ctx.channels);
end
if isempty(channels) && ~(isfield(ctx, 'useProvidedChannels') && ctx.useProvidedChannels)
    try channels = normalizeList(listAvailableChannels); catch, channels = {}; end
end
end

function out = normalizeList(value)
if isempty(value), out = {}; return; end
if ischar(value), value = cellstr(value); end
if isstring(value) || isnumeric(value) || islogical(value) || iscategorical(value)
    value = cellstr(string(value(:)));
elseif ~iscell(value)
    value = {char(string(value))};
end
out = {};
for i = 1:numel(value)
    if isempty(value{i}), continue; end
    vals = cellstr(string(value{i}));
    out = [out, vals(:).']; %#ok<AGROW>
end
out = cellfun(@(x) char(strtrim(string(x))), out, 'UniformOutput', false);
out = unique(out(~cellfun(@isempty, out)), 'stable');
end
