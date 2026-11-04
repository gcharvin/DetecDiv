function pipelineTest(previewPath,checkEditor)
%PIPELINETEST Real widgets, shared validators, no execution and layout migration.
if nargin < 1, previewPath = ''; end
if nargin < 2, checkEditor = false; end
folder = tempname; mkdir(folder);
cleanup = onCleanup(@()rmdir(folder,'s'));
template = pipelineConstruct(folder,'Measure cells',1);
mkdir(fullfile(template.path,'code'));
fid = fopen(fullfile(template.path,'code','pipelineWidgetProbe.m'),'w');
fprintf(fid,'function ctx=pipelineWidgetProbe(ctx)\nerror(''Probe must never execute during validation'');\nend\n');
fclose(fid);
params = customModule.setparam();
params.entryPoint = 'pipelineWidgetProbe'; params.codeFolder = 'code';
params.parametersJson = '{"value":3}'; params.outputPorts = 'tables';
template.nodes = struct('id','measure','name','Measure cells','type','custom', ...
    'pkg','customModule','func','customModule.process','params',params,'enabled',true);
original = template.nodes;
project = shallow(); project.io.file = 'Pipeline experiment';
project.fov.id = 'FOV A'; project.fov.roi = roi('Cells',[1 1 16 16]);
pixels = uint16(magic(16)); project.fov.roi.image = pixels;
project.fov.roi.channelid = 1; project.fov.roi.display.channel = {'Phase'};
viewer = detecdiv_ui(project,'Visible','off','LayoutFile','','AutoSaveLayout',false);
closeViewer = onCleanup(@()delete(viewer));
assert(strcmp(viewer.Host.findCommand('Save Pipeline').Enable,'off'));
viewer.Pipeline.addTemplate(template);
assert(strcmp(viewer.Host.findCommand('Save Pipeline').Enable,'on'));
figure = viewer.Pipeline.SettingsFigure;
steps = findall(figure,'Tag','pipeline-steps');
assert(strcmp(steps.Data{1,1},'Measure cells'));
steps.CellSelectionCallback(steps,struct('Indices',[1 1]));
parameters = findall(figure,'Tag','pipeline-parameters');
assert(any(strcmp(parameters.UserData,'entryPoint')));
viewer.Host.focusWidget('Pipeline');
assert(strcmp(viewer.Host.App.SelectedChild.tag,'pipeline'));
validate = findall(figure,'Tag','pipeline-validate');
validate.ButtonPushedFcn(validate,[]);
assert(viewer.Pipeline.LastOK,strjoin(viewer.Pipeline.LastReport.errors,' | '));
dry = findall(figure,'Tag','pipeline-dry-run'); dry.ButtonPushedFcn(dry,[]);
assert(viewer.Pipeline.LastOK,strjoin(viewer.Pipeline.LastReport.errors,' | '));
assert(isequal(template.nodes,original) && isequal(project.fov.roi.image,pixels));
assert(isempty(project.processing.pipelineRun));
assert(~isfile(fullfile(template.path,'pipeline.json')));
scope = findall(figure,'Tag','pipeline-scope'); scope.Value = 'Current ROI';
scope.ValueChangedFcn(scope,[]); dry.ButtonPushedFcn(dry,[]);
assert(~viewer.Pipeline.LastOK && contains(viewer.Pipeline.LastReport.errors{1},'Select a ROI'));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
node = findall(tree,'Tag','roi-node'); tree.SelectedNodes = node;
tree.SelectionChangedFcn(tree,[]);
ctx = viewer.Pipeline.context();
assert(isequal(ctx.sel.fovs,1) && isequal(ctx.sel.rois,1));
assert(isequal(ctx.roiList,project.fov.roi));
scope.Value = 'Whole project'; scope.ValueChangedFcn(scope,[]);
% Persist/reload via the real pipeline lifecycle functions.
save = findall(figure,'Tag','pipeline-save'); save.ButtonPushedFcn(save,[]);
assert(isfile(fullfile(template.path,'pipeline.json')));
viewer.Pipeline.openTemplate(fullfile(template.path,'pipeline.json'));
assert(isscalar(viewer.Pipeline.Templates));
assert(strcmp(viewer.Pipeline.Template.nodes.params.entryPoint,'pipelineWidgetProbe'));
% Run history is attached to the project, never to the template.
run = pipelineRun(); run.runId = 'review_1'; run.templateId = template.strid; run.status = 'done';
project.processing.pipelineRun = run; viewer.Pipeline.refresh();
runs = findall(figure,'Tag','pipeline-runs'); assert(strcmp(runs.Data{1,1},'review_1'));
project.processing.pipelineRun = [];
if checkEditor
    projectName = matlab.lang.makeValidName(char(string(project.io.file)));
    projectName = matlab.lang.makeUniqueStrings(projectName,evalin('base','who'),namelengthmax);
    clearPublished = onCleanup(@()evalin('base',['clear ' projectName]));
    editor = viewer.Pipeline.openEditor();
    assert(~isempty(editor),'Advanced pipeline editor did not open.');
    closeEditor = onCleanup(@()delete(editor));
    editor.UIFigure.Visible = 'off';
    assert(any(strcmp(editor.UISelectedModuleTable.Data(:,3),'custom')));
    assert(contains(editor.RuntimeProjectTargetEditField.Value,project.io.file));
    clear closeEditor clearPublished;
end
% Float, redock, save and restore the same Pipeline controls.
viewer.Host.setDocked('Pipeline',false);
assert(~viewer.Host.isDocked('Pipeline'));
layout = fullfile(folder,'layout.json'); viewer.Host.saveLayout(layout);
viewer.Host.setDocked('Pipeline',true);
assert(isequal(steps,findall(figure,'Tag','pipeline-steps')));
assert(viewer.Host.restoreLayout(layout) && ~viewer.Host.isDocked('Pipeline'));
viewer.Host.setDocked('Pipeline',true); viewer.Host.resetLayout();
% Migrate a three-widget v1 layout without losing its column weights.
viewer.Host.setWidgetVisible('Pipeline',false);
legacy = viewer.Host.snapshot(); legacy.widgets = rmfield(legacy.widgets,'pipeline');
weights = legacy.layout.documentLayout.columnWeights;
legacyPath = fullfile(folder,'legacy-layout.json');
fid = fopen(legacyPath,'w'); fprintf(fid,'%s',jsonencode(legacy)); fclose(fid);
assert(viewer.Host.restoreLayout(legacyPath),viewer.Host.LastLayoutError);
assert(~viewer.Host.isWidgetVisible('Pipeline'));
current = viewer.Host.snapshot();
assert(max(abs(weights(:)-current.layout.documentLayout.columnWeights(:))) < .02);
viewer.Host.setWidgetVisible('Pipeline',true); viewer.Host.resetLayout();
viewer.Host.focusWidget('Pipeline');
if ~isempty(previewPath)
    viewer.Host.show(); drawnow; pause(.5); viewer.Host.capture(previewPath);
end
disp('Pipeline widget test passed: contracts, dry run, immutability, scopes, save/load, runs, docking and old layouts.');
end
