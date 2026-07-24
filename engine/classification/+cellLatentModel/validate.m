function out = validate(classif,rois,ctx)
%CELLLATENTMODEL.VALIDATE Score the trained checkpoint on independent ROIs.
if nargin < 2 || isempty(rois)
    try rois = classif.dataset.split.test; catch, rois = []; end
end
if nargin < 3 || isempty(ctx), ctx = struct(); end
if isempty(rois)
    error('cellLatentModel:NoValidationROIs', ...
        'Select independent test ROIs in classifierGUI.');
end
tp = cellLatentModel.utils.defaultTrainingParam();
if isstruct(classif.trainingParam)
    tp = cellLatentModel.utils.applyOverrides(tp,classif.trainingParam);
end
stamp = char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));
root = fullfile(classif.path,'validation',['run_' stamp]);
formatted = cellLatentModel.formatDataset( ...
    classif,[],rois,root,ctx,tp);
p = cellLatentModel.utils.defaultExecutionParam();
p = cellLatentModel.utils.applyOverrides(p,classif.executionParam);
if ~strcmpi(char(string(p.modelSource)),'trained')
    error('cellLatentModel:ValidationRequiresTrainedModel', ...
        'Train the classifier before independent validation.');
end
checkpoint = char(string(p.modelPath));
if ~isfile(checkpoint), checkpoint = fullfile(classif.path,checkpoint); end
if ~isfile(checkpoint)
    error('cellLatentModel:MissingTrainedModel', ...
        'Trained checkpoint not found.');
end
inferenceDir = fullfile(root,'inference');
configFile = fullfile(root,'validation_config.json');
stdoutFile = fullfile(root,'validation_stdout.txt');
device = char(string(p.device));
if strcmpi(device,'auto'), device = 'cuda'; end
cfg = struct( ...
    'schema_version',1, ...
    'dataset',normalizedPath(formatted.datasetDir), ...
    'checkpoint',normalizedPath(checkpoint), ...
    'output',normalizedPath(inferenceDir), ...
    'split','validation', ...
    'device',device);
writeJson(configFile,cfg);
cellLatentModel.utils.runPythonModule( ...
    'infer-from-config',configFile,ctx,stdoutFile);
reportFile = fullfile(inferenceDir,'relations.json');
if ~isfile(reportFile)
    error('cellLatentModel:ValidationIncomplete', ...
        'Validation produced no relation report.');
end
report = jsondecode(fileread(reportFile));
out = cellLatentModel.utils.outInitSafe('cellLatentModel.validate');
out.metrics = report.summary;
out.artifacts.dataset = formatted.datasetDir;
out.artifacts.relations = reportFile;
out.artifacts.candidateScores = ...
    fullfile(inferenceDir,'candidate_scores.csv');
out.artifacts.config = configFile;
out.refs.rois = rois;
out.status = "OK";
end

function writeJson(filename,value)
fid = fopen(filename,'w');
if fid < 0, error('cellLatentModel:ConfigWriteFailed','Cannot write %s.',filename); end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end
function value = normalizedPath(value)
value = strrep(char(string(value)),'\','/');
end
