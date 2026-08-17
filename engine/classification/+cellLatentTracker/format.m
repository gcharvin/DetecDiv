function out = format(classif,rois,ctx)
%CELLLATENTTRACKER.FORMAT Export immutable EDGE/APPEAR/END supervision.
if nargin < 2, rois = []; end
if nargin < 3 || isempty(ctx), ctx = struct(); end
out = cellLatentModel.utils.outInitSafe('cellLatentTracker.format');
cellLatentTracker.ensureClassMetadata(classif);
tp = cellLatentTracker.utils.defaultTrainingParam();
if isstruct(classif.trainingParam)
    tp = cellLatentModel.utils.applyOverrides(tp,classif.trainingParam);
end
if isfield(ctx,'params') && isstruct(ctx.params)
    tp = cellLatentModel.utils.applyOverrides(tp,ctx.params);
end
classif.trainingParam = tp;
out.refs.trainingScope = classifierBinding.trainingScopeSpec(classif);
[trainRois,valRois] = resolveSplits(classif,rois,tp.validationFraction);
if isempty(trainRois) || isempty(valRois)
    error('cellLatentTracker:IncompleteSplit', ...
        ['Latent tracker formatting requires at least one training ROI and ' ...
         'one ROI-disjoint validation ROI.']);
end

instanceName = textValue(tp.instanceChannelName);
gtName = textValue(tp.groundTruthChannelName);
brightfieldName = textValue(tp.brightfieldChannelName);
if isempty(instanceName) || isempty(gtName)
    error('cellLatentTracker:MissingTrainingChannels', ...
        ['Select both the frame-local instance input and the reviewed ' ...
         'stable-ID tracking GT.']);
end
% Both bindings may reference the same reviewed mask geometry.  The input
% consumes only frame-local connected-component labels, whereas persistent
% target identity is reconstructed separately from
% cellModel.instances.track_id.  Equality of the channel names therefore
% does not leak stable IDs into the tracker.

stamp = char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));
datasetDir = fullfile(classif.path,'trainingdataset', ...
    ['latent_tracking_dataset_' stamp]);
runDir = fullfile(classif.path,'trainingdataset','runs',stamp);
if exist(runDir,'dir') ~= 7, mkdir(runDir); end
stageRoot = fullfile(runDir,'staging');
mkdir(stageRoot);
stageCleanup = onCleanup(@() removeFolder(stageRoot));
entries = [splitEntries(trainRois,'train'); splitEntries(valRois,'validation')];
specs = repmat(emptySpec(),0,1);
requestedFrames = [];
try requestedFrames = ctx.sel.frames; catch, end
for i = 1:numel(entries)
    roiIndex = entries(i).index;
    roiobj = classif.roi(roiIndex);
    if isempty(roiobj.image), roiobj.load; end
    instances = readStack(roiobj,instanceName,true);
    gtMaskLabels = readStack(roiobj,gtName,true);
    brightfield = [];
    if ~isempty(brightfieldName)
        brightfield = readStack(roiobj,brightfieldName,false);
    end
    frames = trainingBounds.frames(classif,roiIndex,size(instances,3), ...
        requestedFrames,'RoiPosition',i,'SplitName',entries(i).split);
    if isempty(frames) || any(diff(frames) ~= 1)
        error('cellLatentTracker:NonContiguousFrames', ...
            'ROI %s needs one non-empty contiguous frame interval.', ...
            char(string(roiobj.id)));
    end
    instances = instances(:,:,frames);
    gtMaskLabels = gtMaskLabels(:,:,frames);
    [cellState,~] = roiobj.loadCellModel('MigrateLegacy',true);
    [gt,gtFamily] = cellLatentTracker.materializeStableTracks( ...
        gtMaskLabels,cellState,frames,gtName);
    if ~isempty(brightfield), brightfield = brightfield(:,:,frames); end
    inputFile = fullfile(stageRoot,sprintf('roi_%03d_input_and_gt.h5',roiIndex));
    writeStack(inputFile,'/input_frame_local_instances',instances,'uint32');
    writeStack(inputFile,'/gt_stable_tracks',gt,'uint32');
    if ~isempty(brightfield)
        writeStack(inputFile,'/input_brightfield',brightfield,'single');
    end
    spec = emptySpec();
    spec.roi_id = char(string(roiobj.id));
    spec.source_roi_path = normalizedPath(roiobj.path);
    spec.source_frames = frames;
    spec.input_path = normalizedPath(inputFile);
    spec.instances_dataset = '/input_frame_local_instances';
    spec.tracking_gt_dataset = '/gt_stable_tracks';
    if ~isempty(brightfield), spec.brightfield_dataset = '/input_brightfield'; end
    spec.instance_channel = instanceName;
    spec.tracking_gt_channel = gtName;
    spec.tracking_gt_family = gtFamily.name;
    spec.tracking_gt_representation = 'cell_model_track_id';
    spec.brightfield_channel = brightfieldName;
    spec.frame_interval_minutes = positiveScalar( ...
        tp.frameIntervalMinutes,'frameIntervalMinutes');
    spec.domain = textValue(tp.trainingDomain);
    spec.split = entries(i).split;
    specs(end+1,1) = spec; %#ok<AGROW>
end
configFile = fullfile(runDir,'format_config.json');
stdoutFile = fullfile(runDir,'format_stdout.txt');
cfg = struct('schema_version',1, ...
    'output_dir',normalizedPath(datasetDir), ...
    'rois',specs, ...
    'top_k',positiveInteger(tp.topK,'topK'), ...
    'minimum_truth_overlap',bounded(tp.minimumTruthOverlap,0,1, ...
        'minimumTruthOverlap',false), ...
    'minimum_detection_coverage',bounded(tp.minimumDetectionCoverage,0,1, ...
        'minimumDetectionCoverage',true));
writeJson(configFile,cfg);
detecdiv_check_cancel(ctx,'cellLatentTracker before formatting');
runtime = cellLatentModel.utils.runPythonModule( ...
    'format-detecdiv-tracking',configFile,ctx,stdoutFile);
detecdiv_check_cancel(ctx,'cellLatentTracker after formatting');
manifestFile = fullfile(datasetDir,'manifest.json');
if ~isfile(manifestFile)
    error('cellLatentTracker:MissingManifest', ...
        'Latent tracker formatter produced no manifest.');
end
pointerFile = fullfile(classif.path,'trainingdataset', ...
    'latest_latent_tracking_dataset.json');
writeJson(pointerFile,struct('schema_version',1, ...
    'manifest',normalizedPath(manifestFile), ...
    'created_at',char(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ssXXX'))));
try classiSave(classif); catch, end
manifest = jsondecode(fileread(manifestFile));
out.status = "OK";
out.artifacts.dataset = datasetDir;
out.artifacts.manifest = manifestFile;
out.artifacts.pointer = pointerFile;
out.artifacts.config = configFile;
out.artifacts.stdout = stdoutFile;
out.metrics = manifest.counts;
out.refs.trainRois = trainRois;
out.refs.validationRois = valRois;
out.refs.runtime = runtime;
clear stageCleanup;
removeFolder(stageRoot);
end

function rows = splitEntries(indices,split)
rows = repmat(struct('index',0,'split',''),numel(indices),1);
for i = 1:numel(indices), rows(i)=struct('index',indices(i),'split',split); end
end
function s = emptySpec()
s = struct('roi_id','','source_roi_path','','source_frames',[], ...
    'input_path','','instances_dataset','','tracking_gt_dataset','', ...
    'brightfield_dataset','','instance_channel','', ...
    'tracking_gt_channel','','tracking_gt_family','', ...
    'tracking_gt_representation','','brightfield_channel','', ...
    'frame_interval_minutes',1,'domain','','split','');
end
function [train,val] = resolveSplits(classif,requested,fraction)
n=numel(classif.roi); train=normalize(requested,n); val=[]; test=[];
try
    if isempty(train), train=normalize(classif.dataset.split.train,n); end
    val=normalize(classif.dataset.split.val,n);
    test=normalize(classif.dataset.split.test,n);
catch
end
if isempty(train), try train=normalize(classif.trainingset,n); catch, end, end
train=setdiff(train,[val test],'stable'); val=setdiff(val,test,'stable');
if isempty(val) && numel(train)>1
    fraction=double(fraction); if ~isscalar(fraction)||~isfinite(fraction)||fraction<=0||fraction>=1, fraction=.2; end
    count=max(1,min(numel(train)-1,round(numel(train)*fraction)));
    val=train(end-count+1:end); train=train(1:end-count);
end
end
function value=normalize(value,n)
if isempty(value), value=[]; return; end
value=unique(round(double(value(:)')),'stable');
value=value(isfinite(value)&value>=1&value<=n);
end
function stack=readStack(roiobj,name,isLabels)
try idx=roiobj.findChannelID(name,'exact'); catch, idx=roiobj.findChannelID(name); end
if isempty(idx), error('cellLatentTracker:ChannelNotFound','ROI %s has no channel "%s".',char(string(roiobj.id)),name); end
stack=squeeze(roiobj.image(:,:,idx(1),:));
if ismatrix(stack), stack=reshape(stack,size(stack,1),size(stack,2),1); end
if isLabels
    values=double(stack(:));
    if any(~isfinite(values))||any(values<0)||any(mod(values,1)~=0)
        error('cellLatentTracker:InvalidLabels','Channel "%s" must contain non-negative integer labels.',name);
    end
    stack=uint32(stack);
else
    stack=single(stack);
end
end
function writeStack(filename,dataset,stack,datatype)
stored=permute(stack,[2 1 3]); sz=[size(stack,2),size(stack,1),size(stack,3)];
h5create(filename,dataset,sz,'Datatype',datatype, ...
    'ChunkSize',[min(sz(1),256),min(sz(2),256),1],'Deflate',1);
h5write(filename,dataset,stored); h5writeatt(filename,dataset,'axis_order','time,y,x');
end
function writeJson(filename,value)
folder=fileparts(filename); if ~isempty(folder)&&exist(folder,'dir')~=7, mkdir(folder); end
fid=fopen(filename,'w'); if fid<0, error('cellLatentTracker:ConfigWriteFailed','Cannot write %s.',filename); end
cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end
function removeFolder(folder),if isfolder(folder),try rmdir(folder,'s');catch,end,end,end
function value=normalizedPath(value),value=strrep(char(string(value)),'\','/');end
function value=textValue(value),while iscell(value),if isempty(value),value='';return;else,value=value{end};end,end,value=strtrim(char(string(value)));end
function value=positiveScalar(raw,name),value=double(raw);if ~isscalar(value)||~isfinite(value)||value<=0,error('cellLatentTracker:InvalidParameter','%s must be positive.',name);end,end
function value=positiveInteger(raw,name),value=round(positiveScalar(raw,name));end
function value=bounded(raw,low,high,name,allowLow),value=double(raw);if ~isscalar(value)||~isfinite(value)||value>high||(allowLow&&value<low)||(~allowLow&&value<=low),error('cellLatentTracker:InvalidParameter','%s is outside its allowed range.',name);end,end
