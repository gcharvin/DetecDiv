function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% computeMetrics.process  Pipeline-compatible wrapper for computeMetrics.

if nargin < 3
    ctx = struct();
elseif ~isstruct(ctx)
    ctx = struct('frames', ctx);
end

if nargin == 0 || isempty(param)
    paramout = computeMetrics.setparam(ctx);
    dataout = [];
    imageout = [];
    return;
end

ctxWithParams = ctx;
if isstruct(ctxWithParams)
    ctxWithParams.params = param;
end
paramout = mergeComputeMetricsDefaults(computeMetrics.setparam(ctxWithParams), param);
if shouldDebugFrames(ctx)
    paramout.debugFrames = true;
end
dataout = [];
imageout = [];

frames = [];
if isfield(ctx,'frames') && ~isempty(ctx.frames)
    frames = ctx.frames;
elseif isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'frames') && ~isempty(ctx.sel.frames)
    frames = ctx.sel.frames;
end

if shouldDebugFrames(ctx)
    fprintf('[computeMetrics.process] file=%s ctx.frames=%s selectedFrames=%s\n', ...
        which('computeMetrics.process'), frameText(getfielddefaultLocal(ctx, 'frames', [])), frameText(frames));
end

if isempty(frames) || (isnumeric(frames) && all(frames == -1))
    [paramout, dataout, imageout] = computeMetrics.core(paramout, roiobj);
else
    [paramout, dataout, imageout] = computeMetrics.core(paramout, roiobj, frames);
end
end

function out = mergeComputeMetricsDefaults(defaults, override)
out = defaults;
if isempty(override)
    return;
end
if ~isstruct(override)
    out = override;
    return;
end
names = fieldnames(override);
for i = 1:numel(names)
    out.(names{i}) = override.(names{i});
end
end

function tf = shouldDebugFrames(ctx)
tf = false;
try
    tf = isstruct(ctx) && isfield(ctx, 'run') && isstruct(ctx.run) ...
        && isfield(ctx.run, 'debugFrames') && logical(ctx.run.debugFrames);
catch
    tf = false;
end
end

function out = getfielddefaultLocal(s, fieldName, defaultValue)
out = defaultValue;
if isstruct(s) && isfield(s, fieldName)
    out = s.(fieldName);
end
end

function txt = frameText(frames)
if isempty(frames)
    txt = '[]';
elseif isnumeric(frames) || islogical(frames)
    txt = mat2str(frames(:).');
else
    try
        txt = mat2str(double(frames(:).'));
    catch
        txt = char(string(frames));
    end
end
end
