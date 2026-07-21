function out = format(classif, rois, ctx)
% trackastra.format  Export selected DetecDiv ROIs to Trackastra CTC data.

if nargin < 3 || isempty(ctx), ctx = struct(); end
out = trackastra.utils.outInitSafe('trackastra.format');
if isempty(classif.trainingParam)
    classif.trainingParam = trackastra.utils.defaultTrainingParam();
end
if isfield(ctx,'params') && isstruct(ctx.params)
    classif.trainingParam = trackastra.utils.applyParamOverrides(classif.trainingParam, ctx.params);
end
trackastra.ensureClassMetadata(classif);

if nargin < 2 || isempty(rois)
    try
        rois = classif.dataset.split.train;
    catch
        rois = classif.trainingset;
    end
end
nRois = numel(classif.roi);
trainRois = normalizeRois(rois, nRois);
valRois = [];
testRois = [];
try
    valRois = normalizeRois(classif.dataset.split.val, nRois);
    testRois = normalizeRois(classif.dataset.split.test, nRois);
catch
end
trainRois = setdiff(trainRois, testRois, 'stable');
valRois = setdiff(valRois, testRois, 'stable');
if isempty(valRois)
    [trainRois, valRois] = splitValidation(trainRois, classif.trainingParam.validationFraction);
end
if isempty(trainRois)
    error('trackastra:NoTrainingROIs', 'No training ROI remains after split normalization.');
end
if isempty(valRois)
    error('trackastra:NoValidationROIs', ...
        'Trackastra training requires at least one validation ROI or a splittable training set.');
end

folderName = 'trainingdataset';
if isfield(ctx,'params') && isstruct(ctx.params) && isfield(ctx.params,'foldername') && ~isempty(ctx.params.foldername)
    folderName = char(string(ctx.params.foldername));
end
frames = [];
if isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'frames')
    frames = ctx.sel.frames;
end

report = trackastra.exportCtcDataset(classif, trainRois, valRois, ...
    'FolderName', folderName, 'Frames', frames);
out.status = "OK";
out.artifacts.layout = 'ctc_trackastra_v1';
out.artifacts.datasetRoot = report.datasetRoot;
out.artifacts.trainSequences = report.trainSequences;
out.artifacts.validationSequences = report.validationSequences;
out.artifacts.manifest = report.manifest;
out.metrics.trainingRois = numel(trainRois);
out.metrics.validationRois = numel(valRois);
out.metrics.frames = report.frameCount;
out.metrics.outputCount = report.frameCount;
out.metrics.droppedParentEdges = report.droppedParentEdgeCount;
end

function rois = normalizeRois(rois, nRois)
if isempty(rois), rois = []; return; end
rois = unique(round(double(rois(:)')), 'stable');
rois = rois(isfinite(rois) & rois >= 1 & rois <= nRois);
end

function [trainRois, valRois] = splitValidation(trainRois, fraction)
fraction = double(fraction);
if ~isscalar(fraction) || ~isfinite(fraction) || fraction <= 0 || fraction >= 1
    fraction = 0.2;
end
valRois = [];
if numel(trainRois) < 2, return; end
nVal = min(numel(trainRois)-1, max(1, round(numel(trainRois)*fraction)));
valRois = trainRois(end-nVal+1:end);
trainRois = trainRois(1:end-nVal);
end
