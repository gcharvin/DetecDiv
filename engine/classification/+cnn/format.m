function out = format(classif, rois, ctx)
% cnn.format  Package entry point for formatting image training data.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end

params = struct();
if isfield(ctx,'params') && isstruct(ctx.params)
    params = ctx.params;
end

if nargin < 2 || isempty(rois)
    rois = classif.trainingset;
end

foldername = 'trainingdataset';
if isfield(params,'foldername') && ~isempty(params.foldername)
    foldername = params.foldername;
end

frames = [];
if isfield(ctx, 'sel') && isstruct(ctx.sel) && isfield(ctx.sel, 'frames')
    frames = ctx.sel.frames;
elseif isfield(params, 'Frames')
    frames = params.Frames;
elseif isfield(params, 'frames')
    frames = params.frames;
end

out = cnn.utils.outInitSafe('cnn.format');
outputCount = formatImageTrainingSet(foldername, classif, rois, 'Frames', frames);
out.metrics.outputCount = outputCount;
out.status = "OK";
end
