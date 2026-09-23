function result = exportRuntime(classif,destinationRoot)
%EXPORTRUNTIME Export an immutable, inference-only cellLatentModel bundle.
% The release's explicit runtimePackage allowlist is the only copy source.

plan = cellLatentModel.planRuntimeExport(classif);
if ~plan.canExport
    error('cellLatentModel:RuntimeExportPreflightFailed', ...
        'Runtime export preflight failed:%s- %s',newline, ...
        strjoin(plan.blockers,[newline '- ']));
end
destinationRoot = char(string(destinationRoot));
if isempty(destinationRoot) || ~isfolder(destinationRoot)
    error('cellLatentModel:InvalidRuntimeExportDestination', ...
        'Choose an existing runtime_bundles directory.');
end
[~,destinationName] = fileparts(destinationRoot);
if ~strcmpi(destinationName,'runtime_bundles')
    error('cellLatentModel:InvalidRuntimeExportDestination', ...
        'Choose the contract-owned runtime_bundles directory.');
end
classifierRoot = fullfile(destinationRoot,plan.classifierId);
finalRoot = fullfile(classifierRoot,plan.releaseId);
if isfolder(finalRoot) || isfile(finalRoot)
    error('cellLatentModel:RuntimeBundleAlreadyExists', ...
        'Runtime bundles are immutable; this destination already exists: %s',finalRoot);
end
if ~isfolder(classifierRoot) && ~mkdir(classifierRoot)
    error('cellLatentModel:RuntimeExportWriteFailed', ...
        'Could not create destination folder: %s',classifierRoot);
end
stageRoot = tempname(classifierRoot);
if ~mkdir(stageRoot)
    error('cellLatentModel:RuntimeExportWriteFailed', ...
        'Could not create runtime export staging folder.');
end
cleanup = onCleanup(@()cleanupStage(stageRoot)); %#ok<NASGU>

runtimeFiles = repmat(struct('path','','sha256','','bytes',0),0,1);
for i = 1:numel(plan.files)
    entry = plan.files(i);
    target = bundlePath(stageRoot,entry.targetPath);
    ensureParent(target);
    [ok,msg] = copyfile(entry.sourcePath,target,'f');
    if ~ok
        error('cellLatentModel:RuntimeExportCopyFailed', ...
            'Could not copy %s: %s',entry.sourcePath,msg);
    end
    [~,~,ext] = fileparts(target);
    hasJsonOperations = ~isempty(entry.rewrites) || ...
        ~isempty(entry.hashes) || ~isempty(entry.removeJsonPointers);
    if strcmpi(ext,'.json') && hasJsonOperations
        rewriteJsonFile(target,entry.targetPath,entry.rewrites, ...
            entry.removeJsonPointers,plan.files);
    end
end
applyHashReferences(stageRoot,plan.files);
for i = 1:numel(plan.files)
    runtimeFiles(end+1,1) = fileRecord(stageRoot, ...
        plan.files(i).targetPath); %#ok<AGROW>
end

release = jsondecode(fileread(plan.releasePath));
release.executionDefaults = sanitizeExecutionDefaults(release.executionDefaults);
release.artifacts = relocateArtifacts(release,plan.artifactTargets, ...
    stageRoot,plan.releaseId);
if isfield(release,'runtimePackage'),release = rmfield(release,'runtimePackage');end
if isfield(release,'sourcePaths'),release = rmfield(release,'sourcePaths');end
if isfield(release,'code'),release = rmfield(release,'code');end
% Supersession links point back to workstation release manifests. They are
% useful in the authoring channel, but are not part of an inference bundle.
if isfield(release,'supersedes'),release = rmfield(release,'supersedes');end
releaseRel = fullfile('releases',plan.releaseId,'release.json');
releasePath = bundlePath(stageRoot,releaseRel);
ensureParent(releasePath);
writeJson(releasePath,release);
runtimeFiles(end+1,1) = fileRecord(stageRoot,releaseRel); %#ok<AGROW>

channel = struct('schemaVersion',1, ...
    'format','detecdiv.cell_latent_model.channel.v1', ...
    'channel','stable','releaseId',plan.releaseId, ...
    'releaseManifest',strrep(fullfile(plan.releaseId,'release.json'),'\','/'), ...
    'releaseManifestSha256',sha256File(releasePath));
channelRel = fullfile('releases','detecdiv_stable.json');
writeJson(bundlePath(stageRoot,channelRel),channel);
runtimeFiles(end+1,1) = fileRecord(stageRoot,channelRel); %#ok<AGROW>

classifierRel = fullfile('classifier',plan.classifierId, ...
    [plan.classifierId '_classification.mat']);
classifierSnapshot = bundlePath(stageRoot,classifierRel);
ensureParent(classifierSnapshot);
exportClassifierSnapshot(classif,plan,finalRoot,classifierSnapshot,release);
runtimeFiles(end+1,1) = fileRecord(stageRoot,classifierRel); %#ok<AGROW>

defaultsRel = fullfile('classifier',plan.classifierId, ...
    'training_execution_defaults.json');
writeJson(bundlePath(stageRoot,defaultsRel), ...
    runtimeDefaults(release.executionDefaults,plan.classifierId));
runtimeFiles(end+1,1) = fileRecord(stageRoot,defaultsRel); %#ok<AGROW>

manifest = struct('schemaVersion',1, ...
    'format','detecdiv.cell_latent_model.runtime_bundle.v1', ...
    'classifierId',plan.classifierId,'releaseId',plan.releaseId, ...
    'profile','pipeline','createdAt',utcTimestamp(), ...
    'sourceReleaseSha256',sha256File(plan.releasePath), ...
    'files',runtimeFiles, ...
    'excluded',{{'classifier.roi','classifier.trainingset', ...
        'classifier.trainingParam','classifier.dataset','classifier.runProfiles', ...
        'datasets','detecdiv_projects','training ROI image stores', ...
        'unlisted experiment files'}});
writeJson(fullfile(stageRoot,'runtime_manifest.json'),manifest);
cellLatentModel.validateRuntimeManifest(stageRoot);

[ok,msg] = movefile(stageRoot,finalRoot);
if ~ok
    error('cellLatentModel:RuntimeExportPublishFailed', ...
        'Could not publish runtime bundle: %s',msg);
end
result = struct('bundleRoot',string(finalRoot), ...
    'classifierId',string(plan.classifierId),'releaseId',string(plan.releaseId), ...
    'fileCount',numel(runtimeFiles),'totalBytes',sum([runtimeFiles.bytes]), ...
    'validated',true);
end

function artifacts = relocateArtifacts(release,targets,stageRoot,releaseId)
artifacts = release.artifacts;
releasePrefix = ['releases/' lower(char(string(releaseId))) '/'];
for i = 1:numel(artifacts)
    key = textField(artifacts(i),'parameter');
    if isempty(key) || ~isfield(targets,key)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'No runtime target declared for release artifact "%s".',key);
    end
    rel = strrep(char(string(targets.(key))),'\','/');
    target = bundlePath(stageRoot,rel);
    if ~isfile(target)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Declared runtime artifact was not copied: %s',rel);
    end
    if ~startsWith(lower(rel),releasePrefix)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'Artifact target is outside its release folder: %s',rel);
    end
    artifacts(i).path = rel(numel(releasePrefix)+1:end);
    artifacts(i).sha256 = sha256File(target);
end
end

function exportClassifierSnapshot(sourceClassif,plan,finalRoot,target,release)
source = fullfile(char(string(sourceClassif.path)), ...
    [plan.classifierId '_classification.mat']);
loaded = load(source,'classiObj');
if ~isfield(loaded,'classiObj') || ~isa(loaded.classiObj,'classi')
    error('cellLatentModel:InvalidRuntimeClassifierSnapshot', ...
        'Expected a classiObj in %s.',source);
end
runtimeClassi = loaded.classiObj;
runtimeClassi.path = fullfile(finalRoot,'classifier',plan.classifierId);
runtimeClassi.strid = plan.classifierId;
runtimeClassi.classifierPkg = 'cellLatentModel';
runtimeClassi.executionParam = cellLatentModel.utils.defaultExecutionParam();
runtimeClassi.executionParam = overlay(runtimeClassi.executionParam,release.executionDefaults);
runtimeClassi.executionParam.modelSource = 'trained';
runtimeClassi.executionParam.modelUpdatePolicy = 'follow_promoted';
runtimeClassi.executionParam.modelReleaseChannelPath = '';
runtimeClassi.executionParam.resolvedModelReleaseId = '';
runtimeClassi.executionParam.resolvedModelReleaseManifestPath = '';
keys = {'modelPath','compositeManifestPath','trackingCheckpointDir', ...
    'stateRuntimeConfigPath','sceneParentRuntimeManifestPath', ...
    'annotationParentRerankerManifestPath','annotationBudneckModelManifestPath', ...
    'runtimeCodeRoot','adaptiveMarkerModelPath'};
for i = 1:numel(keys),runtimeClassi.executionParam.(keys{i})='';end
runtimeClassi.roi = roi('',[]);
runtimeClassi.trainingset = [];
runtimeClassi.trainingParam = [];
runtimeClassi.trainingFun = '';
runtimeClassi.channelName = '';
runtimeClassi.channelName2 = '';
runtimeClassi.outputArg = {};
runtimeClassi.outputFun = [];
runtimeClassi.outputType = '';
runtimeClassi.dataset = struct('classes',{{}},'channels',{{}}, ...
    'split',struct('train',[],'val',[],'test',[]));
runtimeClassi.runProfiles = struct('train',struct(),'classify',struct(), ...
    'format',struct());
runtimeClassi.score = [];
runtimeClassi.userData = [];
runtimeClassi.status = [];
runtimeClassi.run = struct('active',false,'runDir','','runDirAbs','', ...
    'consoleFile','','eventsFile','','metaFile','','startTime',[], ...
    'tag','','fun','');
try
    runtimeClassi.history = table('Size',[0 3], ...
        'VariableTypes',{'datetime','string','string'}, ...
        'VariableNames',{'Date','Category','Message'});
catch
end
try
    runtimeClassi.bounds.Values = [];
    runtimeClassi.bounds.RoiValues = struct('roi_id',{},'roi_index',{}, ...
        'values',{},'updated_at',{});
    runtimeClassi.bounds.Rules = struct([]);
catch
end
classiObj = runtimeClassi; %#ok<NASGU>
save(target,'classiObj','-v7.3');
end

function defaults = runtimeDefaults(values,classifierId)
defaults = struct('schemaVersion',1,'classifierPackage','cellLatentModel', ...
    'classifierId',classifierId,'executionDefaults',values);
if ~isstruct(defaults.executionDefaults),defaults.executionDefaults=struct();end
defaults.executionDefaults.modelSource = 'trained';
defaults.executionDefaults.modelUpdatePolicy = 'follow_promoted';
defaults.executionDefaults.modelReleaseChannelPath = '';
end

function defaults = sanitizeExecutionDefaults(defaults)
if ~isstruct(defaults),defaults=struct();end
keys = {'modelPath','compositeManifestPath','trackingCheckpointDir', ...
    'stateRuntimeConfigPath','sceneParentRuntimeManifestPath', ...
    'annotationParentRerankerManifestPath','annotationBudneckModelManifestPath', ...
    'runtimeCodeRoot','adaptiveMarkerModelPath'};
for i = 1:numel(keys)
    if isfield(defaults,keys{i}),defaults = rmfield(defaults,keys{i});end
end
defaults.modelSource = 'trained';
defaults.modelUpdatePolicy = 'follow_promoted';
defaults.modelReleaseChannelPath = '';
defaults.resolvedModelReleaseId = '';
defaults.resolvedModelReleaseManifestPath = '';
end

function rewriteJsonFile(path,sourceRel,rewrites,removePointers,files)
payload = jsondecode(fileread(path));
for i = 1:numel(removePointers)
    payload = applyJsonPointer(payload,removePointers{i},[],true);
end
for i = 1:numel(rewrites)
    pointer = textField(rewrites(i),'jsonPointer');
    targetRel = strrep(textField(rewrites(i),'targetPath'),'\','/');
    idx = find(strcmpi({files.targetPath},targetRel),1,'first');
    if isempty(idx) && ~isAllowlistedDirectory(files,targetRel)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'JSON rewrite target is not an allowlisted file or directory: %s', ...
            targetRel);
    end
    reference = relativeBundlePath(sourceRel,targetRel);
    payload = applyJsonPointer(payload,pointer,reference,false);
end
assertNoAbsoluteJsonPaths(payload,path);
writeJson(path,payload);
end

function tf = isAllowlistedDirectory(files,target)
target = lower(strrep(char(string(target)),'\','/'));
prefix = [target '/'];
known = lower(strrep({files.targetPath},'\','/'));
tf = any(startsWith(known,prefix));
end

function applyHashReferences(stageRoot,files)
state = zeros(numel(files),1);
for i = 1:numel(files)
    state = applyHashReferencesForFile(i,stageRoot,files,state);
end
end

function state = applyHashReferencesForFile(index,stageRoot,files,state)
if state(index) == 2,return;end
if state(index) == 1
    error('cellLatentModel:InvalidRuntimePackage', ...
        'Runtime JSON hash references contain a cycle.');
end
state(index) = 1;
hashes = files(index).hashes;
for i = 1:numel(hashes)
    targetRel = strrep(textField(hashes(i),'targetPath'),'\','/');
    targetIndex = find(strcmpi({files.targetPath},targetRel),1,'first');
    if isempty(targetIndex)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'JSON hash target is not in the runtime allowlist: %s',targetRel);
    end
    state = applyHashReferencesForFile(targetIndex,stageRoot,files,state);
end
if ~isempty(hashes)
    source = bundlePath(stageRoot,files(index).targetPath);
    payload = jsondecode(fileread(source));
    for i = 1:numel(hashes)
        pointer = textField(hashes(i),'jsonPointer');
        target = bundlePath(stageRoot, ...
            strrep(textField(hashes(i),'targetPath'),'\','/'));
        payload = applyJsonPointer(payload,pointer,sha256File(target),false);
    end
    writeJson(source,payload);
end
state(index) = 2;
end

function payload = applyJsonPointer(payload,pointer,value,removeValue)
parts = strsplit(char(string(pointer)),'/');
parts = parts(2:end);
for i = 1:numel(parts)
    parts{i} = strrep(strrep(parts{i},'~1','/'),'~0','~');
end
if isempty(parts)
    error('cellLatentModel:InvalidRuntimePackage','Root JSON pointer is unsupported.');
end
payload = applyAt(payload,parts,1,value,removeValue,pointer);
end

function node = applyAt(node,parts,index,value,removeValue,pointer)
key = parts{index};
last = index == numel(parts);
if isstruct(node) && isscalar(node)
    if ~isfield(node,key)
        error('cellLatentModel:InvalidRuntimePackage', ...
            'JSON pointer does not exist: %s',pointer);
    end
    if last
        if removeValue,node=rmfield(node,key);else,node.(key)=value;end
    else
        node.(key)=applyAt(node.(key),parts,index+1,value,removeValue,pointer);
    end
elseif isstruct(node) && numel(node)>1
    at = pointerIndex(key,numel(node),pointer);
    if last
        if removeValue
            error('cellLatentModel:InvalidRuntimePackage', ...
                'Removing an array element is unsupported: %s',pointer);
        end
        node(at)=value;
    else
        node(at)=applyAt(node(at),parts,index+1,value,removeValue,pointer);
    end
elseif iscell(node)
    at = pointerIndex(key,numel(node),pointer);
    if last
        if removeValue,node(at)=[];else,node{at}=value;end
    else
        node{at}=applyAt(node{at},parts,index+1,value,removeValue,pointer);
    end
else
    error('cellLatentModel:InvalidRuntimePackage', ...
        'JSON pointer traverses a non-object: %s',pointer);
end
end

function at = pointerIndex(value,count,pointer)
number = str2double(value);
if ~isfinite(number) || number < 0 || number >= count || number ~= floor(number)
    error('cellLatentModel:InvalidRuntimePackage', ...
        'Invalid JSON array index in pointer: %s',pointer);
end
at = number + 1;
end

function assertNoAbsoluteJsonPaths(value,label)
if isstruct(value)
    for i = 1:numel(value)
        keys = fieldnames(value(i));
        for j = 1:numel(keys),assertNoAbsoluteJsonPaths(value(i).(keys{j}),label);end
    end
elseif iscell(value)
    for i = 1:numel(value),assertNoAbsoluteJsonPaths(value{i},label);end
elseif ischar(value) || (isstring(value) && isscalar(value))
    text = char(string(value));
    if ~isempty(regexp(text,'(^|[\s=:])([A-Za-z]:[\\/]|\\\\|/(?!/))', ...
            'once'))
        error('cellLatentModel:NonPortableRuntimeManifest', ...
            'Absolute host path remains in runtime JSON %s: %s',label,text);
    end
end
end

function record = fileRecord(root,relative)
path = bundlePath(root,relative);
info = dir(path);
record = struct('path',strrep(char(string(relative)),'\','/'), ...
    'sha256',sha256File(path),'bytes',double(info.bytes));
end

function path = bundlePath(root,relative)
relative = char(string(relative));
if ~safeRelativePath(relative)
    error('cellLatentModel:InvalidRuntimePackage', ...
        'Unsafe bundle-relative path: %s',relative);
end
path = fullfile(root,strrep(relative,'/',filesep));
end

function tf = safeRelativePath(value)
value = strrep(char(string(value)),'\','/');
tf = ~isempty(value) && ~startsWith(value,'/') && ...
    isempty(regexp(value,'^[A-Za-z]:','once')) && ...
    ~any(strcmp(strsplit(value,'/'),'..')) && ~contains(value,':');
end

function relative = relativeBundlePath(fromFile,toFile)
from = strsplit(strrep(char(string(fromFile)),'\','/'),'/');
from = from(1:end-1);
to = strsplit(strrep(char(string(toFile)),'\','/'),'/');
common = 0;
limit = min(numel(from),numel(to));
for i = 1:limit
    if ~strcmpi(from{i},to{i}),break;end
    common = i;
end
parts = [repmat({'..'},1,numel(from)-common),to(common+1:end)];
relative = strjoin(parts,'/');
if isempty(relative),relative='.';end
end

function writeJson(path,value)
text = jsonencode(value,'PrettyPrint',true);
fid = fopen(path,'w');
if fid < 0
    error('cellLatentModel:RuntimeExportWriteFailed', ...
        'Could not write JSON: %s',path);
end
cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,text,'char');
end

function ensureParent(path)
parent = fileparts(path);
if ~isfolder(parent) && ~mkdir(parent)
    error('cellLatentModel:RuntimeExportWriteFailed', ...
        'Could not create folder: %s',parent);
end
end

function cleanupStage(path)
if isfolder(path),try,rmdir(path,'s');catch,end,end
end

function digest = sha256File(path)
engine = java.security.MessageDigest.getInstance('SHA-256');
file = java.io.File(path);
content = javaMethod('readAllBytes','java.nio.file.Files',file.toPath());
bytes = typecast(engine.digest(content),'uint8');
digest = lower(reshape(dec2hex(bytes,2).',1,[]));
end

function value = utcTimestamp()
value = char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
end

function value = textField(source,key)
value = '';
try
    if isstruct(source) && isfield(source,key),value = strtrim(char(string(source.(key))));end
catch
end
end

function out = overlay(out,source)
if ~isstruct(source),return;end
keys = fieldnames(source);
for i = 1:numel(keys),out.(keys{i})=source.(keys{i});end
end
