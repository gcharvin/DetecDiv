function movieHubTest()
%MOVIEHUBTEST Existing Score submit boundary, shared auth and path/code pinning.
% Only network endpoints are replaced; no user preferences or sessions change.
folder=tempname; mkdir(folder); mocks=fullfile(folder,'transport'); mkdir(mocks);
global DETECDIV_MOVIE_HUB_TEST %#ok<GVMIS> Isolated transport fixture shared with generated endpoint stubs.
DETECDIV_MOVIE_HUB_TEST=struct('probes',0,'offline',false,'submitted',false);
DETECDIV_MOVIE_HUB_TEST.hub=struct('baseUrl','http://test.invalid','sessionToken','test-only', ...
    'defaultLocalProjectRoot',folder,'defaultRemoteProjectRoot','/movie-test');
writeMock(mocks,'detecdiv_hub_settings_get',[
    "function h=detecdiv_hub_settings_get()"
    "global DETECDIV_MOVIE_HUB_TEST; h=DETECDIV_MOVIE_HUB_TEST.hub;"
    "end"]);
writeMock(mocks,'detecdiv_hub_get_current_user',[
    "function u=detecdiv_hub_get_current_user(h)"
    "global DETECDIV_MOVIE_HUB_TEST; s=DETECDIV_MOVIE_HUB_TEST;"
    "assert(isequal(h,s.hub)); DETECDIV_MOVIE_HUB_TEST.probes=s.probes+1;"
    "assert(~s.offline,'movieTest:Offline','Session expired'); u=struct('id',1);"
    "end"]);
writeMock(mocks,'detecdiv_hub_list_execution_targets',[
    "function t=detecdiv_hub_list_execution_targets(h)"
    "global DETECDIV_MOVIE_HUB_TEST; assert(isequal(h,DETECDIV_MOVIE_HUB_TEST.hub));"
    "t=struct('id',{'win','linux','python'},'display_name',{'Windows','Linux','Python'}, ..."
    "'status',{'online','busy','online'},'supports_matlab',{true,true,false});"
    "end"]);
writeMock(mocks,'detecdiv_hub_submit_pipeline_run',[
    "function [job,run]=detecdiv_hub_submit_pipeline_run(run,project,varargin)"
    "global DETECDIV_MOVIE_HUB_TEST; DETECDIV_MOVIE_HUB_TEST.submitted=true;"
    "DETECDIV_MOVIE_HUB_TEST.args=varargin; DETECDIV_MOVIE_HUB_TEST.project=project;"
    "DETECDIV_MOVIE_HUB_TEST.params=run.ctx.run.nodeParams.movie_export_1;"
    "job=struct('id','export-test','status','queued');"
    "end"]);
addpath(mocks,'-begin'); clearTransport(); cleanup=onCleanup(@()finish(mocks,folder));
connection=detecdivui.HubConnection(); assert(DETECDIV_MOVIE_HUB_TEST.probes==0);
assert(~connection.Connected); connection.refresh();
assert(connection.Connected&&DETECDIV_MOVIE_HUB_TEST.probes==1);
[names,ids]=connection.targetItems(); assert(isequal(ids,{'','win','linux'})&&numel(names)==3);
assert(isequal(connection.settings(),DETECDIV_MOVIE_HUB_TEST.hub));
p=shallow(); p.io.path=folder; p.io.file='Project';
params=movieExport.setparam(struct()); params.sourceType='viewer_snapshot'; params.outputMode='images';
params.outputPath=fullfile(folder,'frames'); params.snapshotPath=fullfile(folder,'snapshot','snapshot.mat');
params.snapshotChecksum=repmat('b',1,64); code=repmat('a',1,40);
[~,result]=detecdiv_movie_export_submit(p,params,'Target','hub', ...
    'Hub',connection.settings(),'ExecutionTargetId','win','CodeCommit',code);
assert(strcmp(result.job.id,'export-test')&&strcmp(result.status,'queued'));
s=DETECDIV_MOVIE_HUB_TEST; args=s.args;
assert(isequal(args{find(strcmp(args(1:2:end),'Hub'))*2},s.hub));
assert(strcmp(args{find(strcmp(args(1:2:end),'CodeCommit'))*2},code));
assert(strcmp(args{find(strcmp(args(1:2:end),'ExecutionTargetId'))*2},'win'));
assert(isequal(s.project,p)&&strcmp(s.params.outputPath,'/movie-test/frames'));
assert(strcmp(s.params.snapshotPath,'/movie-test/snapshot/snapshot.mat'));
assert(strcmp(s.params.snapshotChecksum,params.snapshotChecksum)&&~s.params.useRunArtifactFolder);
% Unmapped inputs fail before creating a submitted job.
DETECDIV_MOVIE_HUB_TEST.submitted=false; params.snapshotPath='Q:\unmapped\snapshot.mat'; failed=false;
try, detecdiv_movie_export_submit(p,params,'Target','hub','Hub',connection.settings());
catch e, failed=strcmp(e.identifier,'detecdiv_movie_export_submit:SnapshotUnmapped'); end
assert(failed&&~DETECDIV_MOVIE_HUB_TEST.submitted);
DETECDIV_MOVIE_HUB_TEST.offline=true; connection.refresh();
assert(~connection.Connected&&isempty(fieldnames(connection.User))&&isempty(connection.Targets));
disp('Movie Hub passed: shared auth, no startup request, MATLAB targets, Score submit helper, mapped snapshot/output, code pin and expired-session handling.');
end
function writeMock(folder,name,lines)
fid=fopen(fullfile(folder,[name '.m']),'w'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',lines);
end
function clearTransport()
clear detecdiv_hub_settings_get detecdiv_hub_get_current_user detecdiv_hub_list_execution_targets detecdiv_hub_submit_pipeline_run
end
function finish(mocks,folder)
rmpath(mocks); clearTransport(); clear global DETECDIV_MOVIE_HUB_TEST
assert(startsWith(char(java.io.File(mocks).getCanonicalPath()),[char(java.io.File(folder).getCanonicalPath()) filesep]));
rmdir(folder,'s');
end
