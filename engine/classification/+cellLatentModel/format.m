function out = format(classif,rois,ctx)
%CELLLATENTMODEL.FORMAT Build a versioned multimodal relation dataset.
if nargin < 2, rois = []; end
if nargin < 3 || isempty(ctx), ctx = struct(); end
cellLatentModel.ensureClassMetadata(classif);
out = cellLatentModel.utils.outInitSafe('cellLatentModel.format');
tp = cellLatentModel.utils.defaultTrainingParam();
if isstruct(classif.trainingParam)
    tp = cellLatentModel.utils.applyOverrides(tp,classif.trainingParam);
end
if isfield(ctx,'params') && isstruct(ctx.params)
    tp = cellLatentModel.utils.applyOverrides(tp,ctx.params);
end
classif.trainingParam = tp;
[trainRois,valRois] = resolveSplits( ...
    classif,rois,tp.validationFraction);
if isempty(trainRois)
    error('cellLatentModel:NoTrainingROIs', ...
        'Select at least one training ROI in classifierGUI.');
end
if isempty(valRois)
    error('cellLatentModel:NoValidationROIs', ...
        ['At least two imported ROIs are required: one for training and ' ...
         'one for ROI-level validation.']);
end
root = fullfile(classif.path,'trainingdataset');
result = cellLatentModel.formatDataset( ...
    classif,trainRois,valRois,root,ctx,tp);
out.artifacts.dataset = result.datasetDir;
out.artifacts.manifest = result.manifestFile;
out.artifacts.config = result.configFile;
out.artifacts.stdout = result.stdoutFile;
out.metrics.rows = double(result.manifest.rows);
out.metrics.events = double(result.manifest.events);
out.refs.trainRois = trainRois;
out.refs.validationRois = valRois;
out.status = "OK";
end

function [trainRois,valRois] = resolveSplits(classif,requested,fraction)
n = numel(classif.roi);
trainRois = normalizeIndices(requested,n);
if isempty(trainRois)
    try trainRois = normalizeIndices(classif.dataset.split.train,n); catch, end
end
if isempty(trainRois)
    try trainRois = normalizeIndices(classif.trainingset,n); catch, end
end
valRois = [];
testRois = [];
try
    valRois = normalizeIndices(classif.dataset.split.val,n);
    testRois = normalizeIndices(classif.dataset.split.test,n);
catch
end
trainRois = setdiff(trainRois,testRois,'stable');
valRois = setdiff(valRois,testRois,'stable');
trainRois = setdiff(trainRois,valRois,'stable');
if isempty(valRois) && numel(trainRois) > 1 && fraction > 0
    count = max(1,min(numel(trainRois)-1, ...
        round(numel(trainRois)*fraction)));
    valRois = trainRois(end-count+1:end);
    trainRois = trainRois(1:end-count);
end
end

function out = normalizeIndices(value,n)
if isempty(value), out = []; return; end
out = unique(round(double(value(:)')),'stable');
out = out(isfinite(out) & out >= 1 & out <= n);
end
