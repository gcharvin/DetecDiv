function tests = testDetecdivRunEditorRefresh
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.before = path;
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(root, fullfile(root,'helpers'), fullfile(root,'structure','io'), ...
    fullfile(root,'structure','GUI'), fullfile(root,'structure','classes'), ...
    fullfile(root,'engine','processor'), fullfile(root,'engine','classification'));
end

function teardownOnce(tc)
path(tc.TestData.before);
end

function testEditRunDoesNotReloadWorkspaceRuns(tc)
f = fixture();
cleanup = onCleanup(@()removeFixture(f)); %#ok<NASGU>
nodes = findall(f.app.Tree, 'Tag', 'ProjectpipelineRun');
assertNumElements(tc, nodes, 2);
f.app.Tree.SelectedNodes = nodes(1);
profile clear;
profile on;
profileCleanup = onCleanup(@()profile('off')); %#ok<NASGU>
f.app.EditRunButton.ButtonPushedFcn(f.app.EditRunButton, []);
profile off;
info = profile('info');
names = string({info.FunctionTable.FunctionName});
verifyFalse(tc, any(names == "pipelineRunLoad"));
verifyFalse(tc, any(names == "pipelineRunEventsRead"));
verifyTrue(tc, any(contains(names, 'loadRunIntoUi')));
verifyEqual(tc, numel(findall(f.app.Tree,'Tag','ProjectpipelineRun')), 2);
end

function testExplicitTreeRefreshStillReconcilesExecutionJournal(tc)
f = fixture();
cleanup = onCleanup(@()removeFixture(f)); %#ok<NASGU>
% An external execution completes after the tree has initially loaded.
fid = fopen(fullfile(f.run.path,'run_events.jsonl'),'w');
assert(fid >= 0);
fprintf(fid, '%s\n', jsonencode(struct('ts','2026-01-01T12:00:00', ...
    'type','run_start','runId',f.run.runId)));
fprintf(fid, '%s\n', jsonencode(struct('ts','2026-01-01T12:01:00', ...
    'type','run_done','runId',f.run.runId)));
fclose(fid);
profile clear;
profile on;
profileCleanup = onCleanup(@()profile('off')); %#ok<NASGU>
f.app.RefreshtreewindowMenu.MenuSelectedFcn(f.app.RefreshtreewindowMenu, []);
profile off;
info = profile('info');
names = string({info.FunctionTable.FunctionName});
verifyTrue(tc, any(names == "pipelineRunEventsRead"));
verifyTrue(tc, any(contains(names,'updateWorkspaceRefreshProgress')));
verifyTrue(tc, any(contains(names,'finishWorkspaceRefresh')));
nodes = findall(f.app.Tree, 'Tag', 'ProjectpipelineRun');
verifyTrue(tc, any(contains(string({nodes.Text}), 'run_1 (done)')));
end

function f = fixture()
f.folder = tempname;
mkdir(f.folder);
f.figuresBefore = findall(groot,'Type','figure');
f.varName = 'detecdivTreeRefreshTestProject';
assert(~evalin('base',sprintf('exist(''%s'',''var'')',f.varName)));
p = shallow();
p.io = struct('path',f.folder,'file','project');
position = fov();
position.id = 'Pos1';
position.channel = {'phase'};
position.frames = 2;
p.fov = position;
pipe = pipeline(f.folder,'refresh_template',1);
pipe.nodes = struct('id','combine','name','combine','type','processor', ...
    'pkg','combineMultipleChannels','func','combineMultipleChannels.process', ...
    'params',struct('pkg','combineMultipleChannels','mode','additive', ...
        'requiredChannelCount',1,'Channel1','phase','outputChannelName','combined'), ...
    'enabled',true,'layout',[1 1 1 1]);
pipelineSave(pipe,'Artifacts',false);
p.processing.pipelineRun = pipelineRun.empty;
for i = 1:2
    r = pipelineRun(fullfile(f.folder,'project'),sprintf('run_%d',i),i);
    r.templateId = pipe.strid;
    r.templatePath = fullfile(pipe.path,'pipeline.json');
    r.pipelineRef = struct('id',pipe.strid,'path',r.templatePath,'version','1.0');
    r.ctx = struct('run',struct('inputSourceMode','existing_rois', ...
        'selectedNodes',{{'combine'}},'nodeParams',struct()), ...
        'sel',struct('fovs',1,'frames',[1 2],'rois',[]));
    pipelineRunSave(r,struct('verbose',false));
    p.processing.pipelineRun(i) = r;
    if i == 1, f.run = r; end
end
assignin('base', f.varName, p);
f.app = detecdiv();
end

function removeFixture(f)
if isvalid(f.app), delete(f.app); end
newFigures = setdiff(findall(groot,'Type','figure'),f.figuresBefore);
delete(newFigures);
evalin('base',sprintf('clear %s pipelineGUI2', f.varName));
if isfolder(f.folder), rmdir(f.folder,'s'); end
end
