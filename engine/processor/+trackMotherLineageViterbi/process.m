function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% trackMotherLineageViterbi.process  Pipeline-compatible mother/bud tracker.

if nargin < 3
    ctx = struct();
elseif ~isstruct(ctx)
    ctx = struct('frames', ctx);
end

if nargin == 0 || isempty(param)
    paramout = trackMotherLineageViterbi.setparam(ctx);
    dataout = [];
    imageout = [];
    return;
end

paramout = trackMotherLineageViterbi.normalizeParam(param);
explicitOutputChannelName = '';
if isfield(paramout, 'outputChannelName') && ~isempty(paramout.outputChannelName)
    explicitOutputChannelName = char(string(paramout.outputChannelName));
end

if isfield(ctx, 'channels') && ~isempty(ctx.channels) && ...
        (~isfield(paramout, 'instanceChannelName') || isempty(readChoiceLocal(paramout.instanceChannelName)))
    ch = ctx.channels;
    if iscell(ch)
        paramout.instanceChannelName = ch(:).';
        paramout.instanceChannelName{end+1} = ch{1};
    else
        paramout.instanceChannelName = {char(string(ch)), char(string(ch))};
    end
end

if isempty(strtrim(explicitOutputChannelName)) && isfield(ctx, 'outputName') && ~isempty(ctx.outputName)
    paramout.outputChannelName = char(string(ctx.outputName));
elseif isempty(strtrim(explicitOutputChannelName)) && isfield(ctx, 'names') && isstruct(ctx.names) && ...
        isfield(ctx.names, 'outputName') && ~isempty(ctx.names.outputName)
    paramout.outputChannelName = char(string(ctx.names.outputName));
end

frames = [];
if isfield(ctx, 'frames') && ~isempty(ctx.frames)
    frames = ctx.frames;
end

if isempty(frames) || (isnumeric(frames) && isequal(frames, -1))
    [paramout, dataout, imageout] = trackMotherLineageViterbi.core(paramout, roiobj);
else
    [paramout, dataout, imageout] = trackMotherLineageViterbi.core(paramout, roiobj, frames);
end
end

function v = readChoiceLocal(val)
if iscell(val)
    if isempty(val)
        v = '';
    else
        v = char(string(val{end}));
    end
else
    v = char(string(val));
end
v = strtrim(v);
if strcmpi(v, 'N/A') || strcmpi(v, 'none')
    v = '';
end
end
