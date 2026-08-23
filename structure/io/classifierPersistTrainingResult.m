function report = classifierPersistTrainingResult(classiObj)
%CLASSIFIERPERSISTTRAININGRESULT Persist trained metadata without ROI loss.
%
% Pipeline workers intentionally receive only their selected ROIs.  When a
% full classifier snapshot already exists, merge the trained parameters and
% artifacts into that authoritative object instead of replacing its ROI
% catalog, split, bounds, or annotation state with the worker subset.

report=struct('usedAuthoritativeSnapshot',false, ...
    'workerRoiCount',roiCount(classiObj),'savedRoiCount',0,'file','', ...
    'executionDefaultsFile','');
if isempty(classiObj),return;end
pathValue='';id='';
try
    [pathValue,id]=classiObj.getPath();
    pathValue=char(string(pathValue));
    id=char(string(id));
catch
    try pathValue=char(string(classiObj.path));catch,end
    try id=char(string(classiObj.strid));catch,end
end
if isempty(pathValue)||isempty(id)
    error('classifierPersistTrainingResult:MissingIdentity', ...
        'Classifier path and identifier are required.');
end
target=fullfile(pathValue,[id '_classification.mat']);
report.file=target;
toSave=classiObj;
if isfile(target)
    try
        loaded=load(target,'classiObj');
        if isfield(loaded,'classiObj')&&isa(loaded.classiObj,'classi')
            authoritative=loaded.classiObj;
            if sameClassifier(authoritative,classiObj)
                authoritative.trainingParam=classiObj.trainingParam;
                authoritative.executionParam=classiObj.executionParam;
                try authoritative.classifierPkg=classiObj.classifierPkg;catch,end
                try authoritative.trainingFun=classiObj.trainingFun;catch,end
                try authoritative.classifyFun=classiObj.classifyFun;catch,end
                toSave=authoritative;
                report.usedAuthoritativeSnapshot=true;
            end
        end
    catch ME
        warning('classifierPersistTrainingResult:SnapshotLoadFailed', ...
            ['Could not merge the existing classifier snapshot; the worker ' ...
             'object will not overwrite it: %s'],ME.message);
        return;
    end
end
% Training does not modify ROI content.  Save only the merged classifier
% snapshot, atomically, so worker-local ROI handles are never flushed to the
% authoritative project as a side effect of persisting model metadata.
temporary=[tempname(pathValue) '.mat'];
cleanup=onCleanup(@()deleteIfPresent(temporary));
classiObj=toSave;
save(temporary,'classiObj','-v7.3');
% Direct package training does not pass through classi.trainClassifier,
% which historically left this deployable snapshot pointing at the
% previous model even after the authoritative MAT had advanced. Refresh it
% from the exact merged object. Publish the sidecar before the MAT and keep
% a rollback copy: if either step fails, callers must not observe a new MAT
% paired with stale execution defaults while training reports failure.
sidecar=fullfile(pathValue,'training_execution_defaults.json');
[hadSidecar,sidecarBytes]=readOptionalBytes(sidecar);
try
    report.executionDefaultsFile= ...
        classifierPersistTrainingExecutionDefaults(toSave);
    [ok,message]=movefile(temporary,target,'f');
    if ~ok
        error('classifierPersistTrainingResult:MoveFailed', ...
            'Could not publish %s: %s',target,message);
    end
catch ME
    try
        restoreSidecar(sidecar,hadSidecar,sidecarBytes);
    catch restoreError
        warning('classifierPersistTrainingResult:SidecarRollbackFailed', ...
            'Could not roll back %s after persistence failure: %s', ...
            sidecar,restoreError.message);
    end
    rethrow(ME);
end
report.savedRoiCount=roiCount(toSave);
end

function tf=sameClassifier(left,right)
tf=false;
try
    tf=strcmp(char(string(left.strid)),char(string(right.strid)))&& ...
        strcmpi(normalizedPath(left.path),normalizedPath(right.path));
catch
end
end

function value=normalizedPath(value)
value=char(string(value));
value=strrep(value,'/','\');
while numel(value)>3&&endsWith(value,'\'),value(end)=[];end
end

function count=roiCount(classif)
count=0;try count=numel(classif.roi);catch,end
end

function deleteIfPresent(file)
if isfile(file),delete(file);end
end

function [exists,bytes]=readOptionalBytes(filename)
exists=isfile(filename);
bytes=uint8([]);
if ~exists,return;end
fid=fopen(filename,'r');
if fid<0
    error('classifierPersistTrainingResult:SidecarBackupFailed', ...
        'Could not read existing sidecar %s.',filename);
end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
end

function restoreSidecar(filename,existed,bytes)
if ~existed
    if isfile(filename),delete(filename);end
    return;
end
temporary=[tempname(fileparts(filename)) '.json'];
cleanup=onCleanup(@()deleteIfPresent(temporary));
fid=fopen(temporary,'w');
if fid<0
    error('classifierPersistTrainingResult:SidecarRollbackFailed', ...
        'Could not create rollback file for %s.',filename);
end
closeFile=onCleanup(@()fclose(fid));
written=fwrite(fid,bytes,'uint8');
if written~=numel(bytes)
    error('classifierPersistTrainingResult:SidecarRollbackFailed', ...
        'Incomplete rollback write for %s.',filename);
end
clear closeFile;
[ok,message]=movefile(temporary,filename,'f');
if ~ok
    error('classifierPersistTrainingResult:SidecarRollbackFailed', ...
        'Could not restore %s: %s',filename,message);
end
clear cleanup;
end
