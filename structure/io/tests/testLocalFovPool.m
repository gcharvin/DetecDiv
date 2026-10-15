function tests=testLocalFovPool
tests=functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(root);detecdiv_setup_path(root,'ResetPath',false,'Verbose',false);
end

function testPlanIsBoundedByCpusAndFovSelection(tc)
[project,payload]=fixture(tc);
limits=struct('AvailableBytes',128*2^30,'CpuCores',3);
p=detecdiv_local_plan_fov_pool(payload,project,struct('NumWorkers',16),limits);
verifyEqual(tc,p.poolWorkers,2);verifyEqual(tc,p.cpuLimit,2);
payload.run_request.selection.fovs=2;
p=detecdiv_local_plan_fov_pool(payload,project,struct('NumWorkers',16),limits);
verifyEqual(tc,p.poolWorkers,0);verifyEqual(tc,p.reason,'single_fov');
end

function testMemoryIncludesCoordinatorAndClusterCapacity(tc)
[project,payload]=fixture(tc);
limits=struct('AvailableBytes',128*2^30,'CpuCores',8);
p=detecdiv_local_plan_fov_pool(payload,project,struct('NumWorkers',16),limits);
limits.AvailableBytes=p.coordinatorBytes+2.5*p.peakBytesPerFov;
p=detecdiv_local_plan_fov_pool(payload,project,struct('NumWorkers',16),limits);
verifyEqual(tc,p.poolWorkers,2);verifyEqual(tc,p.memoryLimit,2);
limits.AvailableBytes=p.coordinatorBytes+.5*p.peakBytesPerFov;
p=detecdiv_local_plan_fov_pool(payload,project,struct('NumWorkers',16),limits);
verifyEqual(tc,p.poolWorkers,0);
limits.AvailableBytes=128*2^30;
p=detecdiv_local_plan_fov_pool(payload,project,struct('NumWorkers',2),limits);
verifyEqual(tc,p.poolWorkers,0);verifyEqual(tc,p.clusterLimit,1);
end

function testSequentialAndUnselectedNodesDoNotReservePool(tc)
[project,payload]=fixture(tc);
payload.run_request.node_params=struct('extract',struct('executionMode','sequential'));
p=detecdiv_local_plan_fov_pool(payload,project,struct('NumWorkers',16));
verifyEqual(tc,p.poolWorkers,0);
payload.run_request.node_params=struct();payload.run_request.selected_nodes={'other_node'};
p=detecdiv_local_plan_fov_pool(payload,project,struct('NumWorkers',16));
verifyEqual(tc,p.poolWorkers,0);
end

function testServerNeverUsesLocalPlanner(tc)
payload=struct('execution',struct('requested_mode','server'));
p=detecdiv_local_plan_fov_pool(payload,[],[]);
verifyEqual(tc,p.poolWorkers,0);verifyEqual(tc,p.reason,'not_local');
end

function testRawMoviesAreProbedBeforeProjectImport(tc)
[~,payload,~,root]=fixture(tc);
raw=fullfile(root,'movies');mkdir(raw);
for i=1:2
    file=fullfile(raw,sprintf('movie%d.tif',i));
    imwrite(uint16(i*ones(8,8)),file);
    imwrite(uint16((i+1)*ones(8,8)),file,'WriteMode','append');
end
[pipe,msg]=pipelineLoad(payload.pipeline_ref.pipeline_json_path);assert(~isempty(pipe),msg);
loader=pipe.nodes(1);loader.id='load';loader.type='dataLoader';loader.pkg='dataLoader';
loader.func='dataLoader.process';loader.params=struct('path',raw,'useExistingProjectSources',false);
pipe.nodes=[loader pipe.nodes];pipelineSave(pipe,'Artifacts',false);
payload.run_request.selected_nodes={'load','extract'};
emptyProject=shallow();
p=detecdiv_local_plan_fov_pool(payload,emptyProject,struct('NumWorkers',16), ...
    struct('AvailableBytes',128*2^30,'CpuCores',8));
verifyEqual(tc,p.fovCount,2);verifyEqual(tc,p.poolWorkers,2);
verifyEqual(tc,numel(emptyProject.fov),1);verifyEmpty(tc,emptyProject.fov.id);
end

function testBatchPoolIsAvailableAndMemoryCanReduceConcurrency(tc)
[project,payload,runObj,root]=fixture(tc);
limits=struct('AvailableBytes',128*2^30,'CpuCores',4,'MaxPoolWorkers',2);
plan=detecdiv_local_plan_fov_pool(payload,project,parcluster('Processes'),limits);
verifyEqual(tc,plan.poolWorkers,2);
payload.execution.local_fov_pool=plan;
payload.execution.roi_extract_parallel_fov_workers=2;
payload.execution.roi_extract_parallel_fov_threads=1;
repo=fileparts(which('detecdiv_run_pipeline_job'));
paths=detecdiv_setup_path(repo,'ResetPath',false,'Verbose',false);
job=batch(parcluster('Processes'),@detecdiv_run_pipeline_job_guarded,1,{payload}, ...
    'CurrentFolder',repo,'AdditionalPaths',paths,'Pool',2, ...
    'AutoAttachFiles',false,'AutoAddClientPath',false);
addTeardown(tc,@() delete(job));wait(job);outputs=fetchOutputs(job);result=outputs{1};
assert(strcmp(result.status,'done'),result.error);
[saved,msg]=pipelineRunLoad(fullfile(runObj.path,'run.json'));assert(~isempty(saved),msg);
verifyEqual(tc,saved.ctx.execution.localFovPool.actualPoolWorkers,2);
console=fileread(fullfile(runObj.path,'worker_console.log'));
verifySubstring(tc,console,'Batch FOV pool available: 2 worker(s)');
counts=regexp(console,'FOV batch: (\d+) process worker','tokens');
used=cellfun(@(x)str2double(x{1}),counts);
if isempty(used)
    verifySubstring(tc,console,'admitted 1.');used=1;
end
verifyTrue(tc,all(used>=1 & used<=2));
fprintf('Batch pool reuse verified: 2 reserved workers, 3 exact FOV crops, max admitted concurrency %d.\n',max(used));
verifyCrops(tc,root);
end

function testReservedBatchPoolExecutesTwoFovsConcurrently(tc)
[project,~,~,root]=fixture(tc);
% These crops contain only 40 bytes per frame. Use a RAM fixture so unrelated
% host workloads cannot turn this concurrency regression into a serial test.
% Admission against real resource measurements is covered separately.
memoryRoot=fullfile(root,'memory_fixture');mkdir(fullfile(memoryRoot,'+roiExtract'));
fid=fopen(fullfile(memoryRoot,'+roiExtract','availableMemoryBytes.m'),'w');
fprintf(fid,'function [bytes,note]=availableMemoryBytes(varargin)\nbytes=64*2^30;note=''tiny-image test RAM fixture'';\nend\n');fclose(fid);
repo=fileparts(which('detecdiv_run_pipeline_job'));
paths=detecdiv_setup_path(repo,'ResetPath',false,'Verbose',false);
paths{end+1}=fileparts(mfilename('fullpath'));
job=batch(parcluster('Processes'),@extractWithReservedPool,1,{project,memoryRoot}, ...
    'CurrentFolder',repo,'AdditionalPaths',paths,'Pool',2, ...
    'AutoAttachFiles',false,'AutoAddClientPath',false);
addTeardown(tc,@() delete(job));wait(job);outputs=fetchOutputs(job);out=outputs{1};
verifyEqual(tc,out.poolBefore,2);verifyEqual(tc,out.poolAfter,2);
verifyEqual(tc,out.roiCount,3);verifySubstring(tc,out.log,'FOV batch: 2 process worker(s)');
verifyCrops(tc,root);
fprintf('Actual concurrent FOV extraction verified on two batch pool workers; all pixels match.\n');
end

function out=extractWithReservedPool(project,memoryRoot)
addpath(memoryRoot,'-begin');clear('roiExtract.availableMemoryBytes');
assert(startsWith(which('roiExtract.availableMemoryBytes'),memoryRoot));
ctx=struct('shallow',project,'resume',false,'saveProgress',false, ...
    'execution',struct('requested_mode','local_process'), ...
    'io',struct('persistOutputs',true,'cachePolicy','disk'), ...
    'roiExtract',struct('correctDrift',false,'executionMode','parallel','parallelFovWorkers',2));
pool=gcp('nocreate');before=pool.NumWorkers;
log=evalc('result=roiExtract.process(ctx);');
pool=gcp('nocreate');
out=struct('poolBefore',before,'poolAfter',pool.NumWorkers,'roiCount',numel(result.roiList),'log',log);
end

function testActualLocalLauncherCompletesAllFovs(tc)
[project,payload,runObj,root]=fixture(tc);
key=matlab.lang.makeValidName(['LocalPoolTest_' char(java.util.UUID.randomUUID)]);
submission=detecdiv_local_submit_pipeline_run(runObj,project, ...
    payload.pipeline_ref.pipeline_json_path,'PoolSize',2, ...
    'CompletionCallback',@(result,~,~) setappdata(0,key,result));
addTeardown(tc,@() cleanupSubmission(submission,key));
started=tic;
while ~isappdata(0,key) && toc(started)<180,pause(.2);end
assert(isappdata(0,key),'Local launcher completion timed out.');
result=getappdata(0,key);assert(strcmp(result.status,'done'),result.error);
[saved,msg]=pipelineRunLoad(result.run_json_path);assert(~isempty(saved),msg);
verifyEqual(tc,saved.ctx.execution.requested_mode,'local_process');
verifyEqual(tc,saved.ctx.execution.localFovPool.actualPoolWorkers,submission.poolPlan.poolWorkers);
verifyTrue(tc,isfile(fullfile(runObj.path,'local_pool_plan.json')));
fprintf('Local submitter verified: %d pool workers admitted from actual CPU/RAM budget.\n',submission.poolPlan.poolWorkers);
verifyCrops(tc,root);
end

function verifyCrops(tc,root)
for i=1:3
    id=sprintf('Pos%d',i);
    images=squeeze(h5read(fullfile(root,'local_pool_project',id,['im_' id '_roi.h5']),'/raw'));
    verifyEqual(tc,size(images),[4 5 2]);
    verifyEqual(tc,images(:,:,1),uint16((i*10+1)*ones(4,5)));
    verifyEqual(tc,images(:,:,2),uint16((i*10+2)*ones(4,5)));
end
end

function [project,payload,runObj,root]=fixture(tc)
root=tempname;mkdir(root);addTeardown(tc,@() removeFixture(root));
project=shallow();project.io=struct('path',root,'file','local_pool_project');project.projectId='local-pool-test';
for i=1:3
    id=sprintf('Pos%d',i);raw=fullfile(root,['raw_' id]);mkdir(raw);
    for frame=1:2,imwrite(uint16((i*10+frame)*ones(4,5)),fullfile(raw,sprintf('%03d.tif',frame)));end
    f=fov();f.id=id;f.channel={'raw'};f.frames=2;f.interval=1;
    f.srcpath={raw};f.srclist={dir(fullfile(raw,'*.tif'))};
    f.roi=roi([id '_roi'],[1 1 5 4]);f.roi.path='';project.fov(i)=f;
end
shallowProjectExportLight(project,fullfile(root,'local_pool_project.json'));
pipe=pipelineConstruct(root,'local_pool',1);
pipe.nodes=struct('id','extract','type','roiExtract','pkg','roiExtract', ...
    'func','roiExtract.process','enabled',true, ...
    'params',struct('correctDrift',false,'executionMode','parallel','extractChannels','raw'));
pipelineSave(pipe,'Artifacts',false);
ctx=struct('run',struct('selectedNodes',{{'extract'}},'inputSource','existing_project', ...
    'runPolicy','restart','availableChannels',{{'raw'}}), ...
    'channels',{{'raw'}},'io',struct('globalExistingPolicy','replace','cachePolicy','disk'));
runObj=pipelineRunNew(project,pipe.strid,pipe.path,'RunId','local_pool_run','Ctx',ctx,'NotifyWorkspace',false);
pipelineRunSave(runObj);
payload=pipelineRunJobPayload(runObj,project,fullfile(pipe.path,'pipeline.json'),'RequestedMode','local_process', ...
    'ConsolePath',fullfile(runObj.path,'worker_console.log'));
end

function cleanupSubmission(s,key)
if isappdata(0,key),rmappdata(0,key);end
try,if isvalid(s.job),cancel(s.job);delete(s.job);end,catch,end
try,if isvalid(s.future),cancel(s.future);end,catch,end
try,detecdiv_local_run_lock('release',s.lock.token);catch,end
end

function removeFixture(root)
if ~isfolder(root),return;end
resolved=char(java.io.File(root).getCanonicalPath());safe=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith(resolved,[safe filesep],'IgnoreCase',true));rmdir(resolved,'s');
end
