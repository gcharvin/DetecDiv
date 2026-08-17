function out = train(classif, ctx)
%BUDMOTHERLINKER.TRAIN Train sklearn HGB and export native MATLAB trees.

if nargin < 2 || isempty(ctx), ctx = struct(); end
if (ischar(ctx) || isstring(ctx)) && strcmpi(strtrim(char(string(ctx))),'init')
    ctx = struct('mode','init');
end
budMotherLinker.ensureClassMetadata(classif);
out = budMotherLinker.utils.outInitSafe('budMotherLinker.train');

tp = budMotherLinker.utils.defaultTrainingParam();
if isstruct(classif.trainingParam)
    tp = budMotherLinker.utils.applyOverrides(tp,classif.trainingParam);
end
if isfield(ctx,'trainingParam') && isstruct(ctx.trainingParam)
    tp = budMotherLinker.utils.applyOverrides(tp,ctx.trainingParam);
elseif isfield(ctx,'params') && isstruct(ctx.params) && ...
        isfield(ctx.params,'trainingParam') && isstruct(ctx.params.trainingParam)
    tp = budMotherLinker.utils.applyOverrides(tp,ctx.params.trainingParam);
end
classif.trainingParam = tp;
if isempty(classif.executionParam)
    classif.executionParam = budMotherLinker.utils.defaultExecutionParam();
end
if isfield(ctx,'mode') && strcmpi(char(string(ctx.mode)),'init')
    out.refs.trainingParam = classif.trainingParam;
    out.refs.executionParam = classif.executionParam;
    return;
end
out.refs.trainingScope = classifierBinding.logTrainingScope(classif);

detecdiv_check_cancel(ctx,'budMotherLinker train start');
[dataset,datasetFile,manifestFile] = loadFormattedDataset(classif);
trainRows = strcmp(dataset.split,'train');
valRows = strcmp(dataset.split,'validation');
if ~any(trainRows), error('budMotherLinker:EmptyTrainingSplit','Formatted training split is empty.'); end
if numel(unique(dataset.y(trainRows))) < 2
    error('budMotherLinker:SingleTrainingClass', ...
        'The training split must contain positive and negative candidate links.');
end

modelName = safeName(tp.modelName);
modelDir = fullfile(classif.path,'models',modelName);
if exist(modelDir,'dir') ~= 7, mkdir(modelDir); end
modelFile = fullfile(modelDir,'model.mat');
pythonInputFile = fullfile(modelDir,'python_training_input.mat');
pythonExportFile = fullfile(modelDir,'python_hgb_export.mat');
pythonConfigFile = fullfile(modelDir,'python_training_config.json');
pythonReportFile = fullfile(modelDir,'python_training_report.json');
pythonStdoutFile = fullfile(modelDir,'python_training_stdout.txt');

X = double(dataset.X);
y = double(dataset.y(:));
train_rows = logical(trainRows(:));
save(pythonInputFile,'X','y','train_rows','-v7');

parameters = struct( ...
    'max_iter',positiveInteger(tp.maxIter,'maxIter'), ...
    'learning_rate',positiveScalar(tp.learningRate,'learningRate'), ...
    'max_leaf_nodes',positiveInteger(tp.maxLeafNodes,'maxLeafNodes'), ...
    'min_samples_leaf',positiveInteger(tp.minSamplesLeaf,'minSamplesLeaf'), ...
    'l2_regularization',nonnegativeScalar(tp.l2Regularization,'l2Regularization'), ...
    'random_state',nonnegativeInteger(tp.randomState,'randomState'));
cfg = struct( ...
    'input_path',pythonInputFile, ...
    'output_path',pythonExportFile, ...
    'report_path',pythonReportFile, ...
    'parameters',parameters);
writeJson(pythonConfigFile,cfg);
deleteIfExists(pythonExportFile);
deleteIfExists(pythonReportFile);
deleteIfExists(pythonStdoutFile);

detecdiv_check_cancel(ctx,'budMotherLinker before Python HGB training');
budMotherLinker.utils.runPythonModule( ...
    'train-hgb', pythonConfigFile, ctx, pythonStdoutFile);
detecdiv_check_cancel(ctx,'budMotherLinker after Python HGB training');
if ~isfile(pythonExportFile) || ~isfile(pythonReportFile)
    error('budMotherLinker:PythonTrainingIncomplete', ...
        'Python training completed without producing the HGB export and report.');
end

exported = load(pythonExportFile);
pythonReport = jsondecode(fileread(pythonReportFile));
required = {'feature_mean','feature_scale','baseline','feature_idx', ...
    'threshold','left','right','value','is_leaf','missing_go_left','node_count', ...
    'python_scores'};
if ~all(isfield(exported,required))
    error('budMotherLinker:InvalidPythonExport', ...
        'The Python HGB export is incomplete.');
end
artifact = struct( ...
    'schema_version',2, ...
    'tool_version','cell_lineage_linker-0.1.0', ...
    'model_type','sklearn.ensemble.HistGradientBoostingClassifier', ...
    'feature_names',{dataset.feature_names}, ...
    'feature_mean',exported.feature_mean, ...
    'feature_scale',exported.feature_scale, ...
    'baseline',exported.baseline, ...
    'feature_idx',exported.feature_idx, ...
    'threshold',exported.threshold, ...
    'left',exported.left, ...
    'right',exported.right, ...
    'value',exported.value, ...
    'is_leaf',exported.is_leaf, ...
    'missing_go_left',exported.missing_go_left, ...
    'node_count',exported.node_count, ...
    'hgb_parameters',parameters, ...
    'python_environment',pythonReport, ...
    'rank_margin_threshold',0, ...
    'target_auto_precision',double(tp.targetAutoPrecision), ...
    'tracking_load_guard_enabled',true, ...
    'max_new_tracks_per_frame',7, ...
    'created_at',char(datetime('now','TimeZone','local', ...
        'Format','yyyy-MM-dd''T''HH:mm:ssXXX')));
save(modelFile,'artifact','-v7');

predictionParam = struct('modelSource','trained','modelPath',modelFile);
scores = budMotherLinker.predictHGB(dataset.X,predictionParam);
pythonScores = double(exported.python_scores(:));
maxExportError = max(abs(scores-pythonScores),[],'omitnan');
if isempty(maxExportError), maxExportError = 0; end
if ~isfinite(maxExportError) || maxExportError > 1e-10
    error('budMotherLinker:NativeExportMismatch', ...
        ['Native MATLAB inference differs from sklearn after tree export ' ...
         '(maximum absolute probability error %.3g).'],maxExportError);
end
trainMetrics = budMotherLinker.evaluateScores(dataset,scores,trainRows,0);
calibrationRows = valRows;
calibrationSplit = 'validation';
if ~any(calibrationRows)
    calibrationRows = trainRows;
    calibrationSplit = 'training_fallback';
end
[threshold,calibrationMetrics] = calibrateMargin( ...
    dataset,scores,calibrationRows,double(tp.targetAutoPrecision));

artifact.rank_margin_threshold = threshold;
artifact.training_metrics = trainMetrics;
artifact.calibration_split = calibrationSplit;
artifact.calibration_metrics = calibrationMetrics;
artifact.native_export_max_abs_error = maxExportError;
save(modelFile,'artifact','-v7');

reportFile = fullfile(modelDir,'training_report.json');
report = rmfield(artifact,{'feature_mean','feature_scale','baseline', ...
    'feature_idx','threshold','left','right','value','is_leaf', ...
    'missing_go_left','node_count'});
report.dataset = datasetFile;
report.dataset_manifest = manifestFile;
report.python_training_input = pythonInputFile;
report.python_training_config = pythonConfigFile;
report.python_training_report = pythonReportFile;
report.python_training_stdout = pythonStdoutFile;
writeJson(reportFile,report);

relativeModel = fullfile('models',modelName,'model.mat');
classif.executionParam = budMotherLinker.utils.applyOverrides( ...
    budMotherLinker.utils.defaultExecutionParam(),classif.executionParam);
classif.executionParam.modelSource = 'trained';
classif.executionParam.modelPath = relativeModel;
classif.executionParam.rankMarginThreshold = -1;
try classiSave(classif); catch ME
    warning('budMotherLinker:ClassifierSaveFailed', ...
        'Model trained, but classifier metadata could not be saved: %s',ME.message);
end

out.artifacts.dataset = datasetFile;
out.artifacts.manifest = manifestFile;
out.artifacts.model = modelFile;
out.artifacts.report = reportFile;
out.artifacts.pythonTrainingReport = pythonReportFile;
out.metrics.training = trainMetrics;
out.metrics.calibration = calibrationMetrics;
out.metrics.nativeExportMaxAbsError = maxExportError;
out.refs.executionParam = classif.executionParam;
out.status = "OK";
detecdiv_check_cancel(ctx,'budMotherLinker train complete');
end

function [dataset,datasetFile,manifestFile] = loadFormattedDataset(classif)
root = fullfile(classif.path,'trainingdataset');
datasetFile = fullfile(root,'bud_mother_dataset.mat');
manifestFile = fullfile(root,'bud_mother_dataset_manifest.json');
if ~isfile(datasetFile) || ~isfile(manifestFile)
    error('budMotherLinker:MissingFormattedDataset', ...
        ['Formatted lineage dataset is missing. Use "Format training set" ' ...
         'in classifierGUI before training.']);
end
manifest = jsondecode(fileread(manifestFile));
if ~isfield(manifest,'format') || ...
        ~strcmp(char(string(manifest.format)),'detecdiv_bud_mother_candidates_v1')
    error('budMotherLinker:InvalidFormattedDataset', ...
        'Dataset manifest is incompatible; format the training set again.');
end
payload = load(datasetFile,'dataset');
if ~isfield(payload,'dataset') || size(payload.dataset.X,2) ~= 16
    error('budMotherLinker:InvalidFormattedDataset', ...
        'Dataset payload is incompatible; format the training set again.');
end
dataset = payload.dataset;
if ~isreal(dataset.X) || any(~isfinite(dataset.X),'all')
    error('budMotherLinker:InvalidFormattedDataset', ...
        'Dataset contains complex or non-finite descriptors; format it again.');
end
end

function [threshold,metrics] = calibrateMargin(dataset,scores,rows,target)
base = budMotherLinker.evaluateScores(dataset,scores,rows,-Inf);
margins = base.event_margins;
correct = base.event_correct;
thresholds = unique(margins(isfinite(margins)));
thresholds = sort(thresholds,'ascend');
threshold = Inf;
bestCoverage = -1;
for i = 1:numel(thresholds)
    selected = margins >= thresholds(i);
    if ~any(selected), continue; end
    precision = mean(correct(selected));
    coverage = mean(selected);
    if precision >= target && coverage > bestCoverage
        threshold = thresholds(i);
        bestCoverage = coverage;
    end
end
metrics = budMotherLinker.evaluateScores(dataset,scores,rows,threshold);
metrics.target_precision = target;
metrics.threshold = threshold;
end

function value = positiveScalar(raw,name)
value = double(raw);
if ~isscalar(value) || ~isfinite(value) || value <= 0
    error('budMotherLinker:InvalidTrainingParameter','%s must be positive.',name);
end
end
function value = positiveInteger(raw,name)
value = round(positiveScalar(raw,name));
end
function value = nonnegativeScalar(raw,name)
value = double(raw);
if ~isscalar(value) || ~isfinite(value) || value < 0
    error('budMotherLinker:InvalidTrainingParameter', ...
        '%s must be a non-negative scalar.',name);
end
end
function value = nonnegativeInteger(raw,name)
value = round(nonnegativeScalar(raw,name));
end
function value = safeName(raw)
value = regexprep(char(string(raw)),'[^A-Za-z0-9_.-]','_');
if isempty(value), value='bud_mother_boosted16'; end
end
function writeJson(filename,value)
fid=fopen(filename,'w');
if fid<0, error('budMotherLinker:ReportWriteFailed','Cannot write %s.',filename); end
cleanup=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end

function deleteIfExists(filename)
if isfile(filename), delete(filename); end
end
