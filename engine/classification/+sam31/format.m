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

internal = sam31.utils.internalDefaults();
writeLegacyCtc = logical(sam31.utils.getParam(internal, 'writeLegacyCtc', false));
if isfield(ctx,'params') && isstruct(ctx.params) && isfield(ctx.params,'writeLegacyCtc')
    writeLegacyCtc = logical(ctx.params.writeLegacyCtc);
end

ctcSubfolder = sam31.utils.getParam(classif.trainingParam, 'ctcSubfolder', '');
if isfield(ctx,'params') && isstruct(ctx.params) && isfield(ctx.params,'ctcSubfolder')
    ctcSubfolder = ctx.params.ctcSubfolder;
end
ctcSubfolder = char(string(ctcSubfolder));

framebankOut = sam31.exportFramebankDataset(classif, trainrois, valrois, ...
    'foldername', foldername, ...
    'writePreview', true);

out.status = "OK";
out.artifacts.layout = 'sam31_framebank_json';
out.artifacts.sam31DirectRoot = fullfile(classif.path, foldername);
out.artifacts.framebank = framebankOut.framebank;
out.artifacts.manTrackParentage = true;
out.metrics.framebankFrames = framebankOut.frames;

if writeLegacyCtc
    output = formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois, ...
        'layoutMode', "split_root", ...
        'datasetSubfolder', ctcSubfolder, ...
        'runQA', false, ...
        'qa_write_png', false, ...
        'runCocoConversion', false, ...
        'writeOverlayMovies', false);
    if isempty(strtrim(ctcSubfolder)) || strcmp(strtrim(ctcSubfolder), '.')
        out.artifacts.ctcRoot = fullfile(classif.path, foldername);
    else
        out.artifacts.ctcRoot = fullfile(classif.path, foldername, ctcSubfolder);
    end
    out.artifacts.legacyCtcWritten = true;
    if isnumeric(output)
        out.metrics.legacyCtcFrameCount = output;
    end
else
    out.artifacts.legacyCtcWritten = false;
end
end
