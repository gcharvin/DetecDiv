function out = format(classif, rois, ctx)
% sam31.format  Export DetecDiv annotations to a generic CTC/MoMA dataset.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end
out = sam31.utils.outInitSafe('sam31.format');

if isempty(classif.trainingParam)
    classif.trainingParam = sam31.utils.defaultTrainingParam();
end
if isfield(ctx,'params') && isstruct(ctx.params)
    classif.trainingParam = sam31.utils.applyParamOverrides(classif.trainingParam, ctx.params);
end
sam31.ensureClassMetadata(classif);

if nargin < 2 || isempty(rois)
    try
        rois = classif.dataset.split.train;
    catch
        rois = classif.trainingset;
    end
end
trainrois = rois;
valrois = [];
try
    if isprop(classif,'dataset') && isstruct(classif.dataset) && ...
            isfield(classif.dataset,'split') && isfield(classif.dataset.split,'val')
        valrois = classif.dataset.split.val;
    end
catch
end

foldername = 'trainingdataset';
if isfield(ctx,'params') && isstruct(ctx.params) && isfield(ctx.params,'foldername')
    foldername = char(string(ctx.params.foldername));
end

output = formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois, ...
    'layoutMode', "split_root", ...
    'runQA', false, ...
    'qa_write_png', false, ...
    'runCocoConversion', false, ...
    'writeOverlayMovies', false);

out.status = "OK";
out.artifacts.ctcRoot = fullfile(classif.path, foldername, 'moma');
if isnumeric(output)
    out.metrics.outputCount = output;
end
end
