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
objective = trainingChoice(tp.trainingObjective,'relation_ensemble');
stamp = char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));
root = fullfile(classif.path,'validation',['run_' stamp]);
architecture = trainingChoice(tp.architectureVersion,'lineage_only_v1');
if strcmp(architecture,'detecdiv_composite_v1')
    out = validateComposite(classif,rois,ctx,tp,root);
    return;
end
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
if strcmp(objective,'continuous_lineage')
    cfg = struct( ...
        'schema_version',1, ...
        'dataset_manifest',normalizedPath(formatted.manifestFile), ...
        'checkpoint',normalizedPath(checkpoint), ...
        'output_dir',normalizedPath(inferenceDir), ...
        'split','validation', ...
        'device',device);
    command = 'validate-detecdiv-continuous';
    reportFile = fullfile(inferenceDir,'validation_report.json');
else
    cfg = struct( ...
        'schema_version',1, ...
        'dataset',normalizedPath(formatted.datasetDir), ...
        'checkpoint',normalizedPath(checkpoint), ...
        'output',normalizedPath(inferenceDir), ...
        'split','validation', ...
        'device',device);
    command = 'infer-from-config';
    reportFile = fullfile(inferenceDir,'relations.json');
end
writeJson(configFile,cfg);
cellLatentModel.utils.runPythonModule( ...
    command,configFile,ctx,stdoutFile);
if ~isfile(reportFile)
    error('cellLatentModel:ValidationIncomplete', ...
        'Validation produced no relation report.');
end
report = jsondecode(fileread(reportFile));
out = cellLatentModel.utils.outInitSafe('cellLatentModel.validate');
out.metrics = report.summary;
out.artifacts.dataset = formatted.datasetDir;
if strcmp(objective,'continuous_lineage')
    out.artifacts.validation = reportFile;
else
    out.artifacts.relations = reportFile;
    out.artifacts.candidateScores = ...
        fullfile(inferenceDir,'candidate_scores.csv');
end
out.artifacts.config = configFile;
out.refs.rois = rois;
out.status = "OK";
end

function out = validateComposite(classif,rois,ctx,tp,root)
if ~isstruct(classif.executionParam) || ...
        ~strcmpi(char(string(classif.executionParam.backend)), ...
            'causal_composite')
    error('cellLatentModel:ValidationRequiresCompositeModel', ...
        'Train the composite latent model before end-to-end validation.');
end
if exist(root,'dir')~=7,mkdir(root);end
[~,validationRunId]=fileparts(root);
validationTrackName=['pred_eval_cell_latent_tracks_' validationRunId];
validationFamilyName=['pred_eval_cell_latent_lineage_' validationRunId];
reports=repmat(struct('roi_id','','report','','audit',''),0,1);
trackingTotals=struct('ground_truth_detections',0, ...
    'predicted_detections',0,'matched_detections',0, ...
    'identity_true_positive',0,'identity_false_positive',0, ...
    'identity_false_negative',0,'continuation_correct',0, ...
    'continuation_total',0,'reference_fragment_switches',0, ...
    'predicted_id_reuse_switches',0);
lineageTotals=struct('ground_truth_events',0,'linked_events',0, ...
    'null_events',0,'event_recovered',0,'mother_null_correct',0, ...
    'linked_correct',0,'null_correct',0);
for i=1:numel(rois)
    roiIndex=double(rois(i));
    roiobj=classif.roi(roiIndex);
    if isempty(roiobj.image),roiobj.load;end
    gtName=textValue(tp.trackChannelName);
    gtMask=readChannel(roiobj,gtName,true);
    [model,~]=roiobj.loadCellModel('MigrateLegacy',true);
    frames=1:size(gtMask,3);
    [gtTracks,gtFamily]=cellLatentTracker.materializeStableTracks( ...
        gtMask,model,frames,gtName);
    eventModel=cellModel.normalize(model);
    [eventModel,~]=cellModel.canonicalizeParentageEvents(eventModel);
    gtRelations=familyRelations(eventModel,gtFamily.family_id);
    roiFolder=fullfile(root,safeName(roiobj.id));
    if exist(roiFolder,'dir')~=7,mkdir(roiFolder);end
    roiCtx=ctx;
    if ~isfield(roiCtx,'store')||~isstruct(roiCtx.store)
        roiCtx.store=struct();
    end
    roiCtx.store.workDir=roiFolder;
    % Validation predictions use a run-scoped namespace.  Reusing the
    % normal inference output would make a second validation treat the
    % previous prediction family as its own immutable tracking source.
    if ~isfield(roiCtx,'params')||~isstruct(roiCtx.params)
        roiCtx.params=struct();
    end
    roiCtx.params.outputTrackChannelName=validationTrackName;
    roiCtx.params.outputFamilyName=validationFamilyName;
    roiCtx.params.overwriteOutputFamily=false;
    classified=cellLatentModel.classify(roiobj,classif,roiCtx);
    predTracks=readChannel( ...
        roiobj,classified.refs.outputTrackChannelName,true);
    inputFile=fullfile(roiFolder,'pred_and_gt_tracks.h5');
    writeStack(inputFile,'/pred_stable_tracks',predTracks,'uint32');
    writeStack(inputFile,'/gt_stable_tracks',gtTracks,'uint32');
    predictionFile=fullfile(roiFolder,'prediction_for_evaluation.json');
    writeJson(predictionFile,classified.prediction);
    reportFile=fullfile(roiFolder,'composite_evaluation.json');
    configFile=fullfile(roiFolder,'composite_evaluation_config.json');
    cfg=struct('schema_version',1, ...
        'input_path',normalizedPath(inputFile), ...
        'predicted_tracks_dataset','/pred_stable_tracks', ...
        'ground_truth_tracks_dataset','/gt_stable_tracks', ...
        'prediction_path',normalizedPath(predictionFile), ...
        'ground_truth_relations',gtRelations, ...
        'roi_id',char(string(roiobj.id)), ...
        'output_path',normalizedPath(reportFile));
    writeJson(configFile,cfg);
    stdoutFile=fullfile(roiFolder,'composite_evaluation_stdout.txt');
    cellLatentModel.utils.runPythonModule( ...
        'evaluate-detecdiv-composite',configFile,ctx,stdoutFile);
    report=jsondecode(fileread(reportFile));
    trackingTotals=accumulate(trackingTotals,report.tracking);
    lineageTotals=accumulate(lineageTotals,report.lineage);
    reports(end+1,1)=struct('roi_id',char(string(roiobj.id)), ...
        'report',normalizedPath(reportFile), ...
        'audit',normalizedPath(classified.artifacts.audit)); %#ok<AGROW>
end
summary=struct();
summary.tracking=trackingTotals;
summary.tracking.detection_coverage=ratio( ...
    trackingTotals.matched_detections, ...
    trackingTotals.ground_truth_detections);
summary.tracking.idf1=ratio( ...
    2*trackingTotals.identity_true_positive, ...
    2*trackingTotals.identity_true_positive+ ...
    trackingTotals.identity_false_positive+ ...
    trackingTotals.identity_false_negative);
summary.tracking.continuation_recall=ratio( ...
    trackingTotals.continuation_correct, ...
    trackingTotals.continuation_total);
summary.lineage=lineageTotals;
summary.lineage.event_recall=ratio( ...
    lineageTotals.event_recovered,lineageTotals.ground_truth_events);
summary.lineage.mother_null_accuracy=ratio( ...
    lineageTotals.mother_null_correct,lineageTotals.ground_truth_events);
summary.lineage.linked_accuracy=ratio( ...
    lineageTotals.linked_correct,lineageTotals.linked_events);
summary.lineage.null_accuracy=ratio( ...
    lineageTotals.null_correct,lineageTotals.null_events);
combinedFile=fullfile(root,'composite_validation_report.json');
writeJson(combinedFile,struct('schema_version',1, ...
    'format','detecdiv_cell_latent_composite_validation_v1', ...
    'summary',summary,'rois',reports, ...
    'targets_consumed_at_inference',false));
out=cellLatentModel.utils.outInitSafe('cellLatentModel.validate');
out.status="OK";
out.metrics=summary;
out.artifacts.validation=combinedFile;
out.refs.rois=rois;
out.refs.perRoi=reports;
end

function result=accumulate(result,row)
names=fieldnames(result);
for i=1:numel(names)
    if isfield(row,names{i})
        result.(names{i})=double(result.(names{i}))+double(row.(names{i}));
    end
end
end

function value=ratio(numerator,denominator)
if denominator>0,value=double(numerator)/double(denominator);else,value=0;end
end

function relations=familyRelations(model,familyId)
rows=find(model.relations.family_id==uint32(familyId)& ...
    model.relations.type_id==uint8(1));
relations=repmat(struct('child_track_id',0,'parent_track_id',0, ...
    'event_frame',0),numel(rows),1);
for i=1:numel(rows)
    row=rows(i);
    relations(i)=struct( ...
        'child_track_id',double(model.relations.child_track_id(row)), ...
        'parent_track_id',double(model.relations.parent_track_id(row)), ...
        'event_frame',double(model.relations.event_frame(row)));
end
end

function stack=readChannel(roiobj,name,isLabels)
try idx=roiobj.findChannelID(name,'exact');
catch,idx=roiobj.findChannelID(name);
end
if isempty(idx),error('cellLatentModel:ChannelNotFound', ...
        'Channel "%s" was not found.',name);end
stack=squeeze(roiobj.image(:,:,idx(1),:));
if ismatrix(stack),stack=reshape(stack,size(stack,1),size(stack,2),1);end
if isLabels,stack=uint32(stack);else,stack=single(stack);end
end

function writeStack(filename,dataset,stack,datatype)
stored=permute(stack,[2 1 3]);sz=[size(stack,2),size(stack,1),size(stack,3)];
h5create(filename,dataset,sz,'Datatype',datatype, ...
    'ChunkSize',[min(sz(1),256),min(sz(2),256),1],'Deflate',1);
h5write(filename,dataset,stored);
h5writeatt(filename,dataset,'axis_order','time,y,x');
end

function value=safeName(value)
value=regexprep(char(string(value)),'[^A-Za-z0-9_.-]','_');
if isempty(value),value='roi';end
end

function value=textValue(value)
while iscell(value),if isempty(value),value='';return;else,value=value{end};end,end
value=strtrim(char(string(value)));
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
function value = trainingChoice(raw,fallback)
while iscell(raw)
    if isempty(raw), raw = fallback; else, raw = raw{end}; end
end
value = lower(strtrim(char(string(raw))));
if isempty(value), value = fallback; end
end
