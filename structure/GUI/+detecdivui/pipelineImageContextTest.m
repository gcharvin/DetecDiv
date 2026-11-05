function pipelineImageContextTest(previewPath)
%PIPELINEIMAGECONTEXTTEST Pipeline ROI requests share the main image safely.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); cleanFolder = onCleanup(@()rmdir(folder,'s'));
initialFigures = findall(groot,'Type','figure');
project = shallow(); project.io.path = folder; project.io.file = 'Pipeline image context';
mkdir(fullfile(folder,project.io.file));
rawFiles = {}; rawPixels = {}; originalROIs = cell(1,2);
for position = 1:2
    project.fov(position) = fov(); f = project.fov(position);
    f.id = sprintf('Pos_%d',position); f.channel = {'Phase','Fluorescence'};
    f.frames = [2 2]; f.interval = [1 1];
    for channel = 1:2
        source = fullfile(folder,sprintf('pos%d_ch%d',position,channel)); mkdir(source);
        for frame = 1:2
            pixels = uint16(magic(24)+1000*position+100*channel+10*frame);
            file = fullfile(source,sprintf('frame%d.tif',frame)); imwrite(pixels,file);
            rawFiles{end+1} = file; rawPixels{end+1} = pixels; %#ok<AGROW>
        end
        f.srcpath{channel} = source; f.srclist{channel} = dir(fullfile(source,'*.tif'));
    end
    f.roi = roi(sprintf('Original_%d',position),[1 1 3 3]);
    f.roi.image = uint16(position*ones(3));
    originalROIs{position} = f.roi;
end
template = pipeline(); template.strid = 'ROI context';
params = roiManual.setparam(); params.fovIndex = 2;
node = struct('id','manual_a','name','First manual definition','type','roiManual', ...
    'pkg','roiManual','func','roiManual.process','params',params,'enabled',true);
template.nodes = [node node]; template.nodes(2).id = 'manual_b';
template.nodes(2).name = 'Second manual definition'; originalNodes = template.nodes;
v = detecdiv_ui(project,'Visible','off','DiscoverWorkspace',false,'LayoutFile','', ...
    'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanViewer = onCleanup(@()deleteIfValid(v)); stop(timerfindall('Tag','DetecDivDockMenu'));
w = v.Pipeline; w.addTemplate(template);
assert(v.Session.Position == 1 && isempty(findall(v.roiAxes(),'Type','image')));
editor = w.editModule('manual_a'); assert(~isempty(editor));
cleanEditor = onCleanup(@()deleteIfValid(editor));
button = findall(editor.TabGroup.SelectedTab,'Type','uibutton','Text','Define ROIs...');
assert(isscalar(button) && strcmp(button.Enable,'on'));
button.ButtonPushedFcn(button,[]);
assert(v.Session.Position == 2 && v.Session.Zone == 0);
assert(isempty(findall(v.roiAxes(),'Type','image')),'Opening the ROI assistant loaded raw pixels.');
assert(strcmp(editor.UIFigure.Visible,'on') && isempty(editor.exportViewerDraft().project));
apply = findall(v.widgetFigure('Display'),'Tag','roi-apply');
assert(strcmp(apply.Text,'Use in Pipeline'));
target = findall(v.widgetFigure('Display'),'Tag','roi-target');
assert(contains(target.Text,'manual_a') && contains(target.Text,'FOV 2'));
assertNoWorkflow(initialFigures);

% Drawing loads the requested FOV only when pixels are needed. Two modules
% retain independent unsubmitted shapes while sharing that same viewport.
rectA = [3 4 5 6]; rectB = [12 4 4 6];
v.ROIs.addRectangle(rectA);
assert(~isempty(findall(v.roiAxes(),'Tag','roi-draft-shape')));
editor.selectViewerModule('manual_b'); editor.requestViewerRois('manual_b');
assert(isempty(v.ROIs.Rects)); v.ROIs.addRectangle(rectB);
editor.requestViewerRois('manual_a'); assert(isequal(v.ROIs.Rects,rectA));
editor.requestViewerRois('manual_b'); assert(isequal(v.ROIs.Rects,rectB));
ctx = v.ROIs.apply(); assert(~isempty(ctx));
state = editor.exportViewerDraft();
assert(isempty(state.project) && isequal(state.pipeline.nodes(2).params.manualRois.rect,rectB));
assert(strcmp(editor.UIFigure.Visible,'on'));
assert(state.pipeline.nodes(2).params.manualRois.fovIndex == 2);
assert(isequaln(template.nodes,originalNodes)); checkProject();
if ~isempty(previewPath)
    v.Host.show(); drawnow; pause(.3); v.Host.capture(previewPath);
end

% A response captured before a type change, or before the editor is closed,
% must not become a result in another module or a standalone Create ROIs.
editor.requestViewerRois('manual_a'); assert(isequal(v.ROIs.Rects,rectA));
editor.changeViewerModuleType('manual_a',struct('type','roiGrid','pkg','roiGrid'));
assert(isempty(v.ROIs.apply()),'An obsolete module request was accepted.');
editor.requestViewerRois('manual_b'); v.ROIs.addRectangle([12 13 4 4]);
editor.discardViewerDraft(); clear cleanEditor;
assert(isempty(v.ROIs.apply()),'A response was accepted after closing its owner.');
assert(isequaln(template.nodes,originalNodes)); checkProject();

% Native Run Settings must honor a named FOV selection when the ROI module
% has no explicit FOV. The visible FOV is intentionally different.
native = pipeline(); native.strid = 'Native ROI selection';
native.nodes = node; native.nodes.id = 'manual_native'; native.nodes.params.fovIndex = [];
nativeOriginal = native.nodes;
v.Session.selectPosition(1); v.loadCurrentImage();
w.addTemplate(native); w.newRun();
control = w.Setup.Controls.fovs; control.Value = 'Pos_2'; control.ValueChangedFcn(control,[]);
w.defineROIs(); assert(v.Session.Position == 2 && isempty(v.ROIs.Rects));
v.ROIs.addRectangle([5 13 6 4]); assert(~isempty(v.ROIs.apply()));
effective = w.Draft.effectiveNodes();
assert(effective.params.manualRois.fovIndex == 2 && isequaln(native.nodes,nativeOriginal));
checkProject();

% A pattern captured at a new frame/channel must supersede old run
% overrides, both through the native assistant and through the runtime bridge.
pattern = pipeline(); pattern.strid = 'Pattern image context';
pattern.nodes = node; pattern.nodes.id = 'pattern'; pattern.nodes.type = 'roiPattern';
pattern.nodes.pkg = 'roiPattern'; pattern.nodes.func = 'roiPattern.process';
pattern.nodes.params = roiPattern.setparam(); pattern.nodes.params.fovIndex = 2;
patternOriginal = pattern.nodes;
w.addTemplate(pattern); w.newRun();
settings = w.Setup.values();
w.Draft.import(settings,struct('id','pattern','params',struct('referenceFrame',1,'channelIndex',1)));
w.refresh(); w.defineROIs();
selectPlane(2,2); patchRect = [4 5 5 6]; v.ROIs.setPattern(patchRect);
expected = uint16(magic(24)+2000+200+20); expected = expected(5:10,4:8);
assert(isequal(v.ROIs.Params.pattern.image,expected));
assert(~isempty(v.ROIs.apply())); effective = w.Draft.effectiveNodes();
assert(effective.params.referenceFrame == 2 && effective.params.channelIndex == 2);
assert(isequal(effective.params.pattern.image,expected));

published = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(project.io.file),evalin('base','who'),namelengthmax);
cleanPublished = onCleanup(@()evalin('base',['clear ' published]));
editor = w.openEditor(); assert(~isempty(editor)); cleanEditor = onCleanup(@()deleteIfValid(editor));
editor.requestViewerRois('pattern'); selectPlane(1,1); v.ROIs.setPattern(patchRect);
assert(~isempty(v.ROIs.apply())); state = editor.exportViewerDraft();
effective = pipelineApplyRunNodeParams(state.pipeline.nodes,state.ctx.run.nodeParams);
assert(effective.params.referenceFrame == 1 && effective.params.channelIndex == 1);
assert(isequaln(pattern.nodes,patternOriginal));
editor.clearViewerBridge(); delete(editor); clear cleanEditor cleanPublished;
checkProject();

% Independent design remains usable without a dataset; requesting pixels
% leaves the editor available and reports the missing FOV instead of Workflow.
empty = detecdiv_ui([],'Visible','off','DiscoverWorkspace',false,'LayoutFile','', ...
    'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanEmpty = onCleanup(@()deleteIfValid(empty)); stop(timerfindall('Tag','DetecDivDockMenu'));
independent = empty.Pipeline.newTemplate('No dataset'); independent.nodes = node;
empty.Pipeline.refresh(); other = empty.Pipeline.editModule('manual_a');
cleanOther = onCleanup(@()deleteIfValid(other));
other.requestViewerRois('manual_a');
status = findall(empty.widgetFigure('Pipeline'),'Tag','pipeline-status');
assert(strcmp(other.UIFigure.Visible,'on') && contains(lower(status.Text),'fov'));
assert(isempty(other.exportViewerDraft().project) && isempty(empty.Session.Project));
assertNoWorkflow(initialFigures); checkProject();
disp('Pipeline image context test passed: exact shared-image FOV, lazy pixels, independent module drafts, stale-response rejection, named run scope, effective frame/channel edits and independent design without Workflow.');

    function selectPlane(frame,channel)
        control = findall(v.widgetFigure('Image'),'Tag','frame-number');
        control.Value = frame; control.ValueChangedFcn(control,[]);
        control = findall(v.widgetFigure('Display'),'Tag','channels');
        control.Value = channel; control.ValueChangedFcn(control,[]);
    end
    function checkProject()
        assert(isempty(project.processing.pipelineRun) && isempty(dir(fullfile(folder,'**','*.h5'))));
        for k = 1:2
            assert(isequal(project.fov(k).roi,originalROIs{k}) && isempty(project.fov(k).crop));
            assert(isequal(project.fov(k).roi.image,uint16(k*ones(3))));
        end
        for k = 1:numel(rawFiles), assert(isequal(imread(rawFiles{k}),rawPixels{k})); end
    end
end

function assertNoWorkflow(initialFigures)
figures = findall(groot,'Type','figure'); figures = figures(~ismember(figures,initialFigures));
for figure = reshape(figures,1,[])
    assert(~startsWith(lower(figure.Name),'workflow'),'A separate Workflow image frontend was opened.');
end
end

function deleteIfValid(object)
if ~isempty(object) && isvalid(object), delete(object); end
end
