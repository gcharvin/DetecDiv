function out = format(classif, rois, ctx)
% sam31.format  Export DetecDiv annotations to the SAM3.1 CTC source layout.

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

ctcSubfolder = sam31.utils.getParam(classif.trainingParam, 'ctcSubfolder', '');
if isfield(ctx,'params') && isstruct(ctx.params) && isfield(ctx.params,'ctcSubfolder')
    ctcSubfolder = ctx.params.ctcSubfolder;
end
ctcSubfolder = char(string(ctcSubfolder));

output = formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois, ...
    'layoutMode', "split_root", ...
    'datasetSubfolder', ctcSubfolder, ...
    'runQA', false, ...
    'qa_write_png', false, ...
    'runCocoConversion', false, ...
    'writeOverlayMovies', false);

out.status = "OK";
if isempty(strtrim(ctcSubfolder)) || strcmp(strtrim(ctcSubfolder), '.')
    out.artifacts.ctcRoot = fullfile(classif.path, foldername);
else
    out.artifacts.ctcRoot = fullfile(classif.path, foldername, ctcSubfolder);
end
out.artifacts.layout = 'split_root_ctc';
out.artifacts.manTrackParentage = true;
if isnumeric(output)
    out.metrics.outputCount = output;
end
end
