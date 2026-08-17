function out = format(classif, rois, ctx)
% deeplab_pixel_classification.format
% Build the legacy pixel training set used by trainPixelDeeplabNetFun.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end

out = deeplab_pixel_classification.utils.outInitSafe('deeplab_pixel_classification.format');
out.refs.trainingScope = classifierBinding.trainingScopeSpec(classif);

if nargin < 2 || isempty(rois)
    try
        rois = classif.getTrainingROIIndices();
    catch
        rois = classif.trainingset;
    end
end

foldername = 'trainingdataset';
if isfield(ctx, 'params') && isstruct(ctx.params) && ...
        isfield(ctx.params, 'foldername') && ~isempty(ctx.params.foldername)
    foldername = char(string(ctx.params.foldername));
end

frames = [];
if isfield(ctx, 'sel') && isstruct(ctx.sel) && isfield(ctx.sel, 'frames')
    frames = ctx.sel.frames;
elseif isfield(ctx, 'params') && isstruct(ctx.params) && isfield(ctx.params, 'Frames')
    frames = ctx.params.Frames;
elseif isfield(ctx, 'params') && isstruct(ctx.params) && isfield(ctx.params, 'frames')
    frames = ctx.params.frames;
end

outputCount = formatPixelTrainingSet(foldername, classif, rois, 'Frames', frames);

out.metrics.outputCount = outputCount;
out.status = "OK";
end
