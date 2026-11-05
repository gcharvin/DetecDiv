function progressTest(previewPath)
%#ok<*NASGU> Scope objects are intentionally retained until clear.
%PROGRESSTEST Ownership, nested scopes, backend callback, failures and closure.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); cleanup = onCleanup(@()rmdir(folder,'s'));
viewer = detecdiv_ui([],'Visible','off','LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
closeViewer = onCleanup(@()delete(viewer));
progress = viewer.Progress; pipelineProgress = viewer.Pipeline.Progress;
assert(~progress.Active && strcmp(progress.View.Visible,'off'));
outer = progress.begin('Loading image...');
assert(progress.Active && isnan(progress.Fraction));
progress.report(struct('message','Reading channels','fraction',.25));
assert(progress.Fraction == .25 && progress.View.Data.known);
inner = progress.begin('Rendering layers...'); assert(isnan(progress.Fraction));
clear inner;
assert(strcmp(progress.Message,'Reading channels') && progress.Fraction == .25);
viewer.Host.focusWidget('Pipeline');
other = pipelineProgress.begin('Checking pipeline...');
clear outer;
assert(~progress.Active && pipelineProgress.Active); clear other;
try
    failWithProgress(progress);
catch err
    assert(strcmp(err.identifier,'detecdivui:ProgressProbe'));
end
assert(~progress.Active && strcmp(progress.View.Visible,'off'));
% Outer scopes can end first without hiding the active nested operation.
outer = progress.begin('Outer'); inner = progress.begin('Inner'); clear outer;
assert(progress.Active && strcmp(progress.Message,'Inner')); clear inner;
assert(~progress.Active);
viewer.Host.setWidgetVisible('Pipeline',false);
other = pipelineProgress.begin('Checking hidden pipeline...');
assert(progress.Active && ~pipelineProgress.Active);
pipelineProgress.update('Checking step',.5); assert(progress.Fraction == .5);
clear other; assert(~progress.Active); viewer.Host.setWidgetVisible('Pipeline',true);
% The real loader supplies fractional metadata progress without reading pixels.
project = shallow(); project.io.path = folder; project.io.file = 'Progress project';
project.fov.id = 'Pos0'; project.fov.frames = 1;
file = shallowProjectExportLight(project);
viewer.openProject(file);
assert(viewer.ActiveProject > 0 && ~viewer.ProjectProgress.Active);
assert(viewer.ProjectProgress.View.Data.known && viewer.ProjectProgress.View.Data.value > .9);
rois = viewer.Session.Project.fov.roi;
assert(isempty(rois) || all(arrayfun(@(r)isempty(r.image),rois)));
viewer.openProject(fullfile(folder,'missing.json'));
assert(~viewer.ProjectProgress.Active && ~progress.Active);
viewer.Pipeline.openTemplate(fullfile(folder,'missing-pipeline.json'));
assert(~pipelineProgress.Active);
% Legacy dialogs: manual close, caller failure and parent deletion are safe.
figure = uifigure('Visible','on'); closeFigure = onCleanup(@()delete(figure));
dialog = uiprogressdlg(figure,'Message','Probe','Cancelable','on');
guard = onCleanup(@()detecdiv_close_progress(dialog)); delete(dialog); clear guard;
dialog = uiprogressdlg(figure,'Message','Probe');
guard = onCleanup(@()detecdiv_close_progress(dialog)); clear guard;
assert(~isvalid(dialog));
dialog = uiprogressdlg(figure,'Message','Probe');
guard = onCleanup(@()detecdiv_close_progress(dialog)); clear closeFigure; clear guard;
if ~isempty(previewPath)
    viewer.Host.show(); viewer.Host.focusWidget('Pipeline');
    projects = viewer.ProjectProgress.begin('Loading project metadata...');
    image = progress.begin('Reading image channels...');
    pipeline = pipelineProgress.begin('Validating pipeline...');
    pipelineProgress.update('Checking step 2 / 5',.4);
    drawnow; pause(.5); viewer.Host.capture(previewPath);
    clear projects image pipeline;
end
scope = progress.begin('Closing viewer...'); delete(viewer); clear scope;
assert(~progress.Active); clear closeViewer;
disp('Progress test passed: scoped ownership, nesting, failures, real loader callback and deleted parents.');
end
function failWithProgress(progress)
activity = progress.begin('Failing operation...');
error('detecdivui:ProgressProbe','Expected test failure.');
end
