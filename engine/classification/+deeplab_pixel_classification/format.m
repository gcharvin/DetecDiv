function out = format(classif, rois, ctx)
% deeplab_pixel_classification.format
% Build the legacy pixel training set used by trainPixelDeeplabNetFun.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end

out = deeplab_pixel_classification.utils.outInitSafe('deeplab_pixel_classification.format');

if nargin < 2 || isempty(rois)
    try
        if isprop(classif, 'dataset') && isstruct(classif.dataset) && ...
                isfield(classif.dataset, 'split') && isfield(classif.dataset.split, 'train') && ...
                ~isempty(classif.dataset.split.train)
            rois = classif.dataset.split.train;
        else
            rois = classif.trainingset;
        end
    catch
        rois = classif.trainingset;
    end
end

foldername = 'trainingdataset';
if isfield(ctx, 'params') && isstruct(ctx.params) && ...
        isfield(ctx.params, 'foldername') && ~isempty(ctx.params.foldername)
    foldername = char(string(ctx.params.foldername));
end

outputCount = formatPixelTrainingSet(foldername, classif, rois);

out.metrics.outputCount = outputCount;
out.status = "OK";
end
