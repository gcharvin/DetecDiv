function out = format(classif, rois, ctx)
%BUDMOTHERLINKER.FORMAT Export reviewed lineage candidates for training.

if nargin < 2, rois = []; end
if nargin < 3 || isempty(ctx), ctx = struct(); end
budMotherLinker.ensureClassMetadata(classif);
out = budMotherLinker.utils.outInitSafe('budMotherLinker.format');

tp = budMotherLinker.utils.defaultTrainingParam();
if isstruct(classif.trainingParam)
    tp = budMotherLinker.utils.applyOverrides(tp, classif.trainingParam);
end
if isfield(ctx,'params') && isstruct(ctx.params)
    tp = budMotherLinker.utils.applyOverrides(tp, ctx.params);
end
classif.trainingParam = tp;
out.refs.trainingScope = classifierBinding.trainingScopeSpec(classif);

[trainRois, valRois] = resolveSplits(classif, rois, tp.validationFraction);
if isempty(trainRois)
    error('budMotherLinker:NoTrainingROIs', ...
        'Select at least one training ROI in classifierGUI.');
end
frames = [];
try frames = ctx.sel.frames; catch, end

trainData = budMotherLinker.datasetFromRois( ...
    classif, trainRois, 'train', tp, frames);
valData = budMotherLinker.datasetFromRois( ...
    classif, valRois, 'validation', tp, frames);
dataset = concatenateDatasets(trainData, valData);
if isempty(dataset.y) || ~any(dataset.y == 1) || ~any(dataset.y == 0)
    error('budMotherLinker:InsufficientTrainingData', ...
        ['The formatted dataset must contain positive and negative candidate ' ...
         'links. Check the GT family and candidate geometry parameters.']);
end

root = fullfile(classif.path, 'trainingdataset');
if exist(root,'dir') ~= 7, mkdir(root); end
datasetFile = fullfile(root, 'bud_mother_dataset.mat');
manifestFile = fullfile(root, 'bud_mother_dataset_manifest.json');
save(datasetFile, 'dataset', '-v7');

manifest = struct( ...
    'schema_version',1, ...
    'format','detecdiv_bud_mother_candidates_v1', ...
    'created_at',char(datetime('now','TimeZone','local', ...
        'Format','yyyy-MM-dd''T''HH:mm:ssXXX')), ...
    'feature_names',{dataset.feature_names}, ...
    'train_rois',trainRois, ...
    'validation_rois',valRois, ...
    'candidate_rows',numel(dataset.y), ...
    'events',numel(unique(dataset.event_id)), ...
    'positive_rows',nnz(dataset.y == 1), ...
    'missed_gt_candidates',dataset.summary.missed_gt_candidates, ...
    'skipped_unreviewed_events',dataset.summary.skipped_unreviewed_events, ...
    'ground_truth_source',char(string(tp.groundTruthSource)), ...
    'ground_truth_sha256',fileSha256(tp.groundTruthSource), ...
    'dataset_file','bud_mother_dataset.mat');
writeJson(manifestFile, manifest);

out.artifacts.dataset = datasetFile;
out.artifacts.manifest = manifestFile;
out.metrics.outputCount = numel(dataset.y);
out.metrics.events = numel(unique(dataset.event_id));
out.metrics.trainEvents = numel(unique(dataset.event_id(strcmp(dataset.split,'train'))));
out.metrics.validationEvents = numel(unique(dataset.event_id(strcmp(dataset.split,'validation'))));
out.metrics.missedGtCandidates = dataset.summary.missed_gt_candidates;
out.refs.trainRois = trainRois;
out.refs.validationRois = valRois;
out.status = "OK";
end

function [trainRois, valRois] = resolveSplits(classif, requested, fraction)
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
    count = max(1, min(numel(trainRois)-1, round(numel(trainRois)*fraction)));
    valRois = trainRois(end-count+1:end);
    trainRois = trainRois(1:end-count);
end
end

function out = normalizeIndices(value,n)
if isempty(value), out=[]; return; end
out = unique(round(double(value(:)')),'stable');
out = out(isfinite(out) & out >= 1 & out <= n);
end

function out = concatenateDatasets(a,b)
out = a;
if ~isempty(b.event_id)
    b.event_id = b.event_id + max([a.event_id; 0]);
end
fields = {'X','y','event_id','roi_index','roi_id','child_track_id', ...
    'parent_track_id','event_frame','split'};
for i = 1:numel(fields)
    name = fields{i};
    if isempty(out.(name)), out.(name) = b.(name);
    elseif ~isempty(b.(name)), out.(name) = [out.(name); b.(name)]; end
end
out.gt_family_by_roi = [a.gt_family_by_roi; b.gt_family_by_roi];
out.summary.rois = a.summary.rois + b.summary.rois;
out.summary.events = a.summary.events + b.summary.events;
out.summary.reviewed_events = a.summary.reviewed_events + b.summary.reviewed_events;
out.summary.skipped_unreviewed_events = ...
    a.summary.skipped_unreviewed_events + b.summary.skipped_unreviewed_events;
out.summary.missed_gt_candidates = ...
    a.summary.missed_gt_candidates + b.summary.missed_gt_candidates;
end

function writeJson(filename,value)
fid = fopen(filename,'w');
if fid < 0
    error('budMotherLinker:ManifestWriteFailed', ...
        'Cannot create dataset manifest: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end

function value = fileSha256(filename)
filename = char(string(filename));
if isempty(filename) || ~isfile(filename), value=''; return; end
fid=fopen(filename,'r');
if fid<0, value=''; return; end
cleanup=onCleanup(@()fclose(fid));
bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');
hash=typecast(digest.digest(bytes),'uint8');
value=lower(reshape(dec2hex(hash,2).',1,[]));
end
