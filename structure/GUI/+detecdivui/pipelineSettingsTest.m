function pipelineSettingsTest(previewPath,checkEditor)
%PIPELINESETTINGSTEST Native editing, shared validation, review and run handoff.
if nargin < 1, previewPath = ''; end
if nargin < 2, checkEditor = false; end
folder = tempname; mkdir(folder);
cleanup = onCleanup(@()rmdir(folder,'s'));
pixels = uint16(magic(8));
imwrite(pixels,fullfile(folder,'frame1.tif')); imwrite(pixels+1,fullfile(folder,'frame2.tif'));
project = shallow(); project.io.path = folder; project.io.file = 'Run settings';
project.fov.id = 'FOV A'; project.fov.channel = {'Phase'}; project.fov.frames = 2;
project.fov.interval = 1; project.fov.srcpath = {folder}; project.fov.srclist = {dir(fullfile(folder,'*.tif'))};
project.fov.roi = roi('Cells',[1 1 8 8]); project.fov.roi.image = pixels;
template = pipelineConstruct(folder,'Grid workflow',1);
p = roiGrid.setparam(); p.mode = 'grid'; p.gridCount = 2; p.referenceFrame = 1; p.fovIndex = 1;
template.nodes = struct('id','grid_1','name','Identify ROIs','type','roiGrid', ...
    'pkg','roiGrid','func','roiGrid.process','params',p,'enabled',true);
original = template.nodes;
viewer = detecdiv_ui(project,'Visible','off','LayoutFile','','AutoSaveLayout',false);
closeViewer = onCleanup(@()delete(viewer));
viewer.Pipeline.addTemplate(template); figure = viewer.widgetFigure('Pipeline');
table = findall(figure,'Tag','pipeline-parameters');
row = find(strcmp(table.UserData,'referenceFrame'));
table.CellSelectionCallback(table,struct('Indices',[row 1]));
number = findall(figure,'Tag','pipeline-value-number');
apply = findall(figure,'Tag','pipeline-apply-param'); reset = findall(figure,'Tag','pipeline-reset-param');
assert(strcmp(number.Visible,'on') && strcmp(apply.Enable,'on'));
number.Value = 2; apply.ButtonPushedFcn(apply,[]);
assert(contains(table.Data{row,3},'*'));
ctx = viewer.Pipeline.context(); assert(ctx.run.nodeParams(1).params.referenceFrame == 2);
[ok,report] = viewer.Pipeline.check('dry'); assert(ok,strjoin(report.errors,' | '));
assert(report.nodes(1).params.referenceFrame == 2);
reset.ButtonPushedFcn(reset,[]); assert(~viewer.Pipeline.LastOK);
assert(isempty(viewer.Pipeline.Draft.Overrides) && ~contains(table.Data{row,3},'*'));
% Fixed design parameters have no active Apply button.
fixed = find(strcmp(table.UserData,'gridCount'));
table.CellSelectionCallback(table,struct('Indices',[fixed 1]));
assert(strcmp(apply.Enable,'off'));
table.CellSelectionCallback(table,struct('Indices',[row 1]));
number.Value = 2; apply.ButtonPushedFcn(apply,[]);
% Template Save must not persist a run-specific value.
viewer.Pipeline.saveTemplate(); saved = pipelineLoad(template.path);
assert(saved.nodes.params.referenceFrame == 1 && isequal(template.nodes,original));
draft = viewer.Pipeline.draftRun();
assert(isempty(draft.path) && isempty(project.processing.pipelineRun));
assert(draft.ctx.run.nodeParams(1).params.referenceFrame == 2 && ~isfield(draft.ctx,'shallow'));
second = shallow(); second.io.file = 'Other experiment';
viewer.addProject(second); assert(isempty(viewer.Pipeline.Draft.Overrides));
viewer.addProject(project); assert(viewer.Pipeline.context().run.nodeParams(1).params.referenceFrame == 2);
% Latest-attempt semantics come from the existing run-review backend.
runFolder = fullfile(folder,'run'); mkdir(runFolder);
fid = fopen(fullfile(runFolder,'run_events.jsonl'),'w');
writeEvent(fid,'run_start','2026-11-04 09:00:00.000','','');
writeEvent(fid,'node_failed','2026-11-04 09:00:01.000','grid_1','failed');
writeEvent(fid,'run_start','2026-11-04 09:01:00.000','','');
writeEvent(fid,'node_done','2026-11-04 09:01:02.000','grid_1','done');
writeEvent(fid,'run_done','2026-11-04 09:01:03.000','',''); fclose(fid);
run = pipelineRun(); run.path = runFolder; run.runId = 'run_1'; run.templateId = template.strid;
run.status = 'failed'; project.processing.pipelineRun = run;
viewer.Pipeline.refresh(); runs = findall(figure,'Tag','pipeline-runs');
runs.CellSelectionCallback(runs,struct('Indices',[1 1]));
assert(isempty(fieldnames(viewer.Pipeline.LastRunReview)));
reviewButton = findall(figure,'Tag','pipeline-inspect-run');
reviewButton.ButtonPushedFcn(reviewButton,[]);
review = viewer.Pipeline.LastRunReview;
assert(strcmp(review.status,'done') && review.eventCount == 3 && review.summary.failedNodes == 0);
assert(strcmp(run.status,'failed') && ~isfile(fullfile(runFolder,'run_review.txt')));
nodes = findall(figure,'Tag','pipeline-run-nodes'); assert(strcmp(nodes.Data{1,2},'done'));
assert(strcmp(runs.Data{1,2},'done'));
runs.CellSelectionCallback(runs,struct('Indices',[1 1]));
assert(strcmp(viewer.Pipeline.LastRunReview.status,'done'));
if checkEditor
    projectName = matlab.lang.makeValidName(char(string(project.io.file)));
    projectName = matlab.lang.makeUniqueStrings(projectName,evalin('base','who'),namelengthmax);
    clearPublished = onCleanup(@()evalin('base',['clear ' projectName]));
    editor = viewer.Pipeline.openEditor(); assert(~isempty(editor));
    closeEditor = onCleanup(@()delete(editor)); editor.UIFigure.Visible = 'off';
    assert(contains(editor.RuntimeProjectTargetEditField.Value,project.io.file));
    assert(~strcmp(editor.TemplateidEditField.Value,draft.runId));
    assert(strcmp(editor.ResumeoptionsDropDown.Value,'Resume previous progress'));
    assert(strcmp(editor.RuntimeOutputPolicyDropDown.Value,'skip')); clear closeEditor clearPublished;
end
viewer.Host.setDocked('Pipeline',false); viewer.Host.setDocked('Pipeline',true);
assert(isequal(table,findall(figure,'Tag','pipeline-parameters')));
viewer.closeProject(2);
assert(viewer.Pipeline.context().run.nodeParams(1).params.referenceFrame == 2);
assert(isequal(project.fov.roi.image,pixels));
if ~isempty(previewPath)
    table.CellSelectionCallback(table,struct('Indices',[row 1]));
    viewer.Host.resetLayout(); viewer.Host.show(); viewer.Host.snapshot();
    viewer.Host.focusWidget('Pipeline'); drawnow; pause(.4); viewer.Host.capture(previewPath);
    runTab = findall(figure,'Type','uitab','Title','Runs'); runTab.Parent.SelectedTab = runTab;
    drawnow; pause(.3);
    [parent,name,extension] = fileparts(previewPath);
    viewer.Host.capture(fullfile(parent,[name '_review' extension]));
end
template.nodes.params.referenceFrame = [1 2];
[ok,report] = viewer.Pipeline.check('dry');
assert(~ok && contains(report.errors{1},'Run settings reset'));
assert(isempty(viewer.Pipeline.Draft.Overrides)); template.nodes = original;
viewer.closeProject(); assert(isempty(viewer.Pipeline.Draft.Overrides));
disp('Pipeline settings test passed: native edits, scope, validation, isolation, save, review and docking.');
end
function writeEvent(fid,type,ts,node,status)
event = struct('type',type,'ts',ts,'runId','run_1','NodeId',node,'Status',status);
fprintf(fid,'%s\n',jsonencode(event));
end
