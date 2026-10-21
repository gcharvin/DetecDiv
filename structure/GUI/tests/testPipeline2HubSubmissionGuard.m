function tests = testPipeline2HubSubmissionGuard
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.before = path;
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(root,fullfile(root,'helpers'),fullfile(root,'structure','io'), ...
    fullfile(root,'structure','classes'),fullfile(root,'structure','GUI'), ...
    fullfile(root,'engine','processor'),fullfile(root,'engine','classification'));
folder = tempname; mkdir(folder);
tc.TestData.stubs = folder;
writeFile(fullfile(folder,'detecdiv_hub_request.m'), [ ...
    "function data = detecdiv_hub_request(method,url,varargin)"
    "global DETECDIV_TEST_HUB"
    "s=DETECDIV_TEST_HUB; s.calls{end+1}={method,url}; DETECDIV_TEST_HUB=s;"
    "assert(strcmp(method,'GET'),'Test:UnexpectedMutation','No POST/cancel is allowed.');"
    "if ~isempty(s.onRequest), DETECDIV_TEST_HUB.onRequest=[]; s.onRequest(); end"
    "if s.failRead, error('detecdiv_hub_request:Unreachable','Offline'); end"
    "if strcmp(url,'/auth/session'), data=struct('user',struct('user_key','gilles'));"
    "elseif endsWith(url,'/locks'), data=struct('active_locks',s.locks);"
    "else, data=s.job; end"
    "end"]);
writeFile(fullfile(folder,'detecdiv_hub_broker.m'), [ ...
    "function out=detecdiv_hub_broker(action,varargin)"
    "global DETECDIV_TEST_HUB"
    "if strcmp(action,'register') && DETECDIV_TEST_HUB.failMonitor"
    "error('Test:MonitorOffline','Monitor offline'); end"
    "if strcmp(action,'register'), DETECDIV_TEST_HUB.callback=varargin{3}; end"
    "out='mock-monitor';"
    "end"]);
addpath(folder,'-begin');
clear detecdiv_hub_request detecdiv_hub_broker
end

function teardownOnce(tc)
path(tc.TestData.before);
clear detecdiv_hub_request detecdiv_hub_broker
clear global DETECDIV_TEST_HUB
rmdir(tc.TestData.stubs,'s');
end

function setup(~)
global DETECDIV_TEST_HUB
job = struct('id','job-1','project_id','project-1','status','running', ...
    'params_json',struct('run_request',struct('run_id','saved_run')));
lock = struct('lock_kind','server_job','job_id','job-1');
DETECDIV_TEST_HUB = struct('job',job,'locks',lock,'calls',{{}}, ...
    'failRead',false,'failMonitor',false,'onRequest',[]);
end

function testFindsRunFromServerLockWithoutSavedJobId(tc)
global DETECDIV_TEST_HUB
r = pipelineRun(); r.runId='saved_run';
before = r.ctx;
j = detecdiv_hub_find_active_pipeline_run(r,struct('project_id','project-1'),struct());
verifyEqual(tc,j.id,'job-1');
verifyEqual(tc,r.ctx,before);
verifyNumElements(tc,DETECDIV_TEST_HUB.calls,2);
end

function testKnownJobUsesSingleRead(tc)
global DETECDIV_TEST_HUB
r = pipelineRun(); r.runId='saved_run';
r.ctx.hub = struct('job_id','job-1','project_id','project-1');
j = detecdiv_hub_find_active_pipeline_run(r,[],struct());
verifyEqual(tc,j.id,'job-1');
verifyNumElements(tc,DETECDIV_TEST_HUB.calls,1);
end

function testOtherRunLockIsNotAdopted(tc)
global DETECDIV_TEST_HUB
DETECDIV_TEST_HUB.job.params_json.run_request.run_id='other_run';
r = pipelineRun(); r.runId='saved_run';
verifyEmpty(tc,detecdiv_hub_find_active_pipeline_run(r,struct('project_id','project-1'),struct()));
end

function testOtherProjectIsNotAdopted(tc)
global DETECDIV_TEST_HUB
DETECDIV_TEST_HUB.job.project_id='other-project';
r = pipelineRun(); r.runId='saved_run';
verifyEmpty(tc,detecdiv_hub_find_active_pipeline_run(r,struct('project_id','project-1'),struct()));
end

function testTerminalJobAllowsNewExecution(tc)
global DETECDIV_TEST_HUB
DETECDIV_TEST_HUB.job.status='done';
r = pipelineRun(); r.runId='saved_run';
verifyEmpty(tc,detecdiv_hub_find_active_pipeline_run(r,struct('project_id','project-1'),struct()));
end

function testQueuedAndCancellingJobsAlsoPreventResubmission(tc)
global DETECDIV_TEST_HUB
r=pipelineRun(); r.runId='saved_run';
for status={'queued','cancelling'}
    DETECDIV_TEST_HUB.job.status=status{1};
    j=detecdiv_hub_find_active_pipeline_run(r,struct('project_id','project-1'),struct());
    verifyEqual(tc,j.status,status{1});
end
end

function testReadFailureDoesNotPretendNoJobExists(tc)
global DETECDIV_TEST_HUB
DETECDIV_TEST_HUB.failRead=true;
r = pipelineRun(); r.runId='saved_run';
verifyError(tc,@()detecdiv_hub_find_active_pipeline_run(r,struct('project_id','project-1'),struct()), ...
    'detecdiv_hub_request:Unreachable');
end

function testExistingRunOpensMonitorAndRepeatedRunDoesNotCancel(tc)
global DETECDIV_TEST_HUB
f=fixture(); cleanup=onCleanup(@()removeFixture(f)); %#ok<NASGU>
% Simulate a second click delivered while the first callback checks the Hub.
DETECDIV_TEST_HUB.onRequest=@()nestedClick(tc,f.app);
f.app.RunButton.ButtonPushedFcn(f.app.RunButton,[]);
verifyEqual(tc,f.app.MainTabGroup.SelectedTab,f.app.MonitorTab);
verifyEqual(tc,char(f.app.RunButton.Enable),'off');
verifyEqual(tc,f.run.ctx.hub.job_id,'job-1');
verifyEqual(tc,char(f.app.CancelrunButton.Enable),'on');
calls = DETECDIV_TEST_HUB.calls;
f.app.RunButton.ButtonPushedFcn(f.app.RunButton,[]);
verifyEqual(tc,DETECDIV_TEST_HUB.calls,calls);
verifyEqual(tc,char(f.app.CancelrunButton.Enable),'on');
verifyEqual(tc,f.run.status,'hub_running');
verifyTrue(tc,isstruct(DETECDIV_TEST_HUB.callback));
job=DETECDIV_TEST_HUB.job; job.status='queued';
verifyTrue(tc,detecdiv_hub_invoke_callback(DETECDIV_TEST_HUB.callback,struct('ok',true,'data',job)));
verifyEqual(tc,f.run.ctx.hub.status,'queued');
verifyTrue(tc,contains(strjoin(string(f.app.ConsoleTextArea.Value)), 'No new job was submitted'));
end

function testMonitorFailureKeepsSubmissionDisabled(tc)
global DETECDIV_TEST_HUB
DETECDIV_TEST_HUB.failMonitor=true;
f=fixture(); cleanup=onCleanup(@()removeFixture(f)); %#ok<NASGU>
f.app.RunButton.ButtonPushedFcn(f.app.RunButton,[]);
verifyEqual(tc,f.app.MainTabGroup.SelectedTab,f.app.MonitorTab);
verifyEqual(tc,char(f.app.RunButton.Enable),'off');
verifyEqual(tc,f.run.ctx.hub.job_id,'job-1');
verifyEqual(tc,f.run.status,'hub_running');
end

function nestedClick(tc,app)
verifyEqual(tc,char(app.RunButton.Enable),'off');
app.RunButton.ButtonPushedFcn(app.RunButton,[]);
end

function f=fixture()
f.folder=tempname; mkdir(f.folder);
p=shallow(); p.io=struct('path',f.folder,'file','project');
p.runProfiles.hub=struct('hub_project_id','project-1');
position=fov(); position.id='Pos1'; position.channel={'phase'}; position.frames=2;
p.fov=position;
pipe=pipeline(f.folder,'guard_template',1);
pipe.nodes=struct('id','combine','name','combine','type','processor', ...
    'pkg','combineMultipleChannels','func','combineMultipleChannels.process', ...
    'params',struct('pkg','combineMultipleChannels','mode','additive', ...
        'requiredChannelCount',1,'Channel1','phase','outputChannelName','combined'), ...
    'enabled',true,'layout',[1 1 1 1]);
pipelineSave(pipe,'Artifacts',false);
r=pipelineRun(); r.runId='saved_run';
r.pipelineRef=struct('id',pipe.strid,'path',fullfile(pipe.path,'pipeline.json'),'version','1');
r.ctx=struct('hub',struct('project_id','project-1','sessionToken','test-token', ...
    'userKey','gilles','status','preflight'), ...
    'run',struct('inputSourceMode','existing_rois','selectedNodes',{{'combine'}}, ...
        'nodeParams',struct()),'sel',struct('fovs',1,'frames',[1 2],'rois',[]));
f.run=r;
f.app=pipeline2(p,r,'EditExistingRun',true,'ExecutionTarget','hub');
end

function removeFixture(f)
delete(f.app);
if isfolder(f.folder), rmdir(f.folder,'s'); end
end

function writeFile(file,lines)
fid=fopen(file,'w'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',lines);
end
