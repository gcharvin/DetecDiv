function separationTest(previewPath)
%SEPARATIONTEST Shared configuration and ROI drawing on the main image.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); cleanup = onCleanup(@()rmdir(folder,'s'));
pixels = uint16(magic(24)); file = fullfile(folder,'frame1.tif'); imwrite(pixels,file);
project = shallow(); project.io.path = folder; project.io.file = 'ROI project'; mkdir(fullfile(folder,project.io.file));
project.fov.id = 'Pos0'; project.fov.srcpath = {folder}; project.fov.srclist = {dir(file)};
project.fov.channel = {'Phase'}; project.fov.frames = 1; project.fov.interval = 1;
existing = roi('Original',[1 1 3 3]); existing.image = uint16(ones(3,3)); project.fov.roi = existing;
viewer = detecdiv_ui(project,'Visible','off','LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','');
closeViewer = onCleanup(@()delete(viewer));
viewer.openROITool(); viewer.ROIs.addRectangle([3 4 5 6]);
assert(isempty(project.processing.pipelineRun) && isequal(project.fov.roi,existing));
assert(isequal(viewer.ROIs.Rects,[3 4 5 6]));
assert(~isempty(findall(viewer.roiAxes(),'Tag','roi-draft-shape')));
gesture = viewer.beginROIGesture(); %#ok<NASGU>
overlay = findall(viewer.roiAxes(),'Tag','zone-overlay'); detecdivui.Callback.call(overlay(1).ButtonDownFcn,overlay(1),[]);
assert(viewer.Session.Zone == 0); clear gesture;
ctx = viewer.ROIs.apply(); assert(~isempty(ctx));
assert(numel(project.fov.roi) == 2 && isequal(project.fov.roi(1).image,uint16(ones(3,3))));
assert(isempty(dir(fullfile(folder,'**','*.h5'))));
assert(isequal(project.fov.roi(2).value,uint16([3 4 5 6])));
assert(viewer.saveProject());
[reloaded,message] = shallowLoad(fullfile(folder,[project.io.file '.json']));
assert(~isempty(reloaded),message); assert(numel(reloaded.fov.roi) == 2);
assert(isempty(dir(fullfile(folder,'**','*.h5'))) && isequal(existing.image,uint16(ones(3,3))));
template = pipelineConstruct(folder,'Manual pipeline',1);
p = roiManual.setparam();
template.nodes = struct('id','manual_1','name','Define ROIs','type','roiManual', ...
    'pkg','roiManual','func','roiManual.process','params',p,'enabled',true);
original = template.nodes;
widget = viewer.Pipeline; widget.addTemplate(template); widget.newRun();
assert(isempty(findall(viewer.widgetFigure('Pipeline'),'Tag','pipeline-parameters')));
assert(~isempty(findall(widget.SettingsFigure,'Tag','pipeline-parameters')));
assert(strcmp(widget.SettingsFigure.Visible,'on'));
control = widget.Setup.Controls.runId; control.Value = 'manual_run'; control.ValueChangedFcn(control,[]);
widget.defineROIs(); viewer.ROIs.addRectangle([10 11 4 4]);
ctx = viewer.ROIs.apply(); assert(~isempty(ctx));
assert(numel(project.fov.roi) == 2 && isequal(template.nodes,original));
assert(isequal(widget.Template.nodes.params.manualRois.rect,[10 11 4 4]));
workspaceName = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(project.io.file),evalin('base','who'),namelengthmax);
clearPublished = onCleanup(@()evalin('base',['clear ' workspaceName]));
editor = widget.openEditor();
message = findall(viewer.widgetFigure('Pipeline'),'Tag','pipeline-status');
assert(~isempty(editor),message.Text);
closeEditor = onCleanup(@()deleteIfValid(editor));
assert(strcmp(editor.TemplateidEditField.Value,'manual_run'));
control = editor.RuntimeOutputPolicyDropDown; control.Value = 'upsert'; control.ValueChangedFcn(control,[]);
control = editor.ExecutionDropDown; control.Value = 'CPU';
editor.requestViewerRois('manual_1');
viewer.ROIs.addRectangle([16 3 4 5]); ctx = viewer.ROIs.apply(); assert(~isempty(ctx));
state = editor.exportViewerDraft();
assert(numel(state.pipeline.nodes.params.manualRois) == 2);
editor.returnToViewer(); assert(~isvalid(editor)); clear closeEditor;
ctx = widget.context();
assert(strcmp(ctx.io.existingPolicy,'upsert') && strcmp(ctx.run.gpuPolicy,'cpu'));
assert(strcmp(widget.Setup.Controls.runId.Value,'manual_run'));
assert(numel(widget.Template.nodes.params.manualRois) == 2 && isequal(template.nodes,original));
saved = widget.saveRun(); assert(~isempty(saved) && strcmp(saved.runId,'manual_run'));
assert(isscalar(project.processing.pipelineRun) && strcmp(saved.status,'new'));
assert(numel(saved.ctx.pipelineSpec.nodes.params.manualRois) == 2);
assert(isequal(saved,widget.saveRun()) && isscalar(project.processing.pipelineRun));
[fromDisk,message] = shallowLoad(fullfile(folder,[project.io.file '.json']));
assert(~isempty(fromDisk),message); assert(isscalar(fromDisk.processing.pipelineRun));
saved.status = 'running'; pause(1.7); drawnow;
follow = findall(viewer.widgetFigure('Pipeline'),'Tag','pipeline-run-state');
assert(strcmp(follow.Text,'running')); beforeContext = saved.ctx;
assert(isempty(widget.openEditor()) && isequaln(saved.ctx,beforeContext)); saved.status = 'new';
alias = matlab.lang.makeUniqueStrings('ddUiManualTemplate',evalin('base','who'),namelengthmax);
clearAlias = onCleanup(@()evalin('base',['clear ' alias])); assignin('base',alias,template);
viewer.refreshWorkspace();
assert(numel(widget.Template.nodes.params.manualRois) == 2 && strcmp(widget.Setup.Controls.runId.Value,'manual_run'));
% Pattern capture uses unmodified source pixels and preview keeps project ROIs.
viewer.openROITool(); mode = findall(viewer.widgetFigure('Display'),'Tag','roi-mode');
mode.Value = 'roiPattern'; mode.ValueChangedFcn(mode,[]);
viewer.ROIs.setPattern([3 4 5 6]);
viewer.ROIs.setCrop([1 1 20 20]);
assert(isequal(viewer.ROIs.Params.pattern.image,pixels(4:9,3:7)));
before = project.fov.roi; viewer.ROIs.preview(); assert(isequal(project.fov.roi,before));
assert(isempty(project.fov.crop));
status = findall(viewer.widgetFigure('Display'),'Tag','roi-status');
assert(strcmp(status.Text,'ROI preview updated'),status.Text);
if ~isempty(previewPath)
    viewer.Host.show(); viewer.Host.focusWidget('Pipeline'); drawnow; pause(.3); viewer.Host.capture(previewPath);
    [parent,name,extension] = fileparts(previewPath);
    viewer.openROITool(); drawnow; pause(.3); viewer.Host.capture(fullfile(parent,[name '_rois' extension]));
    widget.openSettings('Run'); drawnow; pause(.3);
    exportapp(widget.SettingsFigure,fullfile(parent,[name '_settings' extension]));
end
assert(~viewer.Progress.Active && ~viewer.ROIs.Progress.Active && ~widget.Progress.Active);
count = numel(viewer.Sessions); viewer.addProject(fromDisk);
assert(numel(viewer.Sessions) == count && isequal(viewer.Session.Project,fromDisk));
assert(strcmp(widget.Setup.Controls.runId.Value,'manual_run'));
delete(viewer); clear closeViewer;
assert(isempty(timerfindall('Tag','DetecDivPipelineFollow')));
disp('Separation test passed: compact widget, shared advanced round-trip, native ROI shapes, backend append and pattern preview.');
end
function deleteIfValid(object)
if isvalid(object), delete(object); end
end
