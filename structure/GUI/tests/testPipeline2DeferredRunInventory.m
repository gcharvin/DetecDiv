function tests = testPipeline2DeferredRunInventory
% Opening a run must not inspect ROI files; bindings remain usable on demand.
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

function testOpenDoesNotReadRoiFilesOrValidateModels(tc)
f = fixture();
cleanup = onCleanup(@()removeFixture(f)); %#ok<NASGU>
profile clear;
profile on;
profileCleanup = onCleanup(@()profile('off')); %#ok<NASGU>
t = tic;
app = pipeline2(f.project, f.run, 'EditExistingRun', true);
fprintf('[fast-open] Synthetic run opened in %.3f seconds\n', toc(t));
appCleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
profile off;
info = profile('info');
files = string({info.FunctionTable.FileName});
names = string({info.FunctionTable.FunctionName});
verifyFalse(tc, any(contains(files, fullfile('@roi','load.m'))));
verifyFalse(tc, any(names == "h5info"));
verifyFalse(tc, any(names == "parseInputData"));
verifyFalse(tc, any(names == "validatePipeline"));
verifyEmpty(tc, f.roi.data.data);
verifyEqual(tc, app.RuntimeFovsEditField.Value, '1');
verifyEqual(tc, app.RuntimeFramesEditField.Value, '1,2');
verifyEqual(tc, f.run.ctx.run.nodeParams.combine.Channel1, 'disk_only_mask');
dropdown = bindingDropdown(app, 'disk_only_mask');
verifyFalse(tc, any(contains(string(dropdown.Items), '[INVALID]')));
verifyEqual(tc, char(dropdown.Enable), 'on');
verifyFalse(tc, contains(lower(string(app.PipelineandRuncheckreportLabel.Text)), 'error'));
end

function testRunWithLoaderSnapshotAndMapOverridesOpens(tc)
f = fixture();
cleanup = onCleanup(@()removeFixture(f)); %#ok<NASGU>
% A full saved graph includes the loader even when this run only processes
% existing ROIs and has no loader override (as in daughter_lineage_9).
loader = struct('id','loader','type','dataLoader','params',struct('path',''));
f.run.ctx.pipelineSpec = struct('nodes',loader,'edges',struct([]));
savedParams = f.run.ctx.run.nodeParams;
app = pipeline2(f.project, f.run, 'EditExistingRun', true);
appCleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
verifyEqual(tc, f.run.ctx.run.nodeParams, savedParams);
verifyEqual(tc, size(app.UISelectedModuleTable.Data,1), 2);
verifyEqual(tc, app.RuntimeFramesEditField.Value, '1,2');
verifyEqual(tc, char(bindingDropdown(app, 'disk_only_mask').Enable), 'on');
verifyEmpty(tc, f.roi.data.data);
end

function testOpeningInputListsDiscoversDiskChannelsAndVariablesWithoutChangingBindings(tc)
f = fixture();
cleanup = onCleanup(@()removeFixture(f)); %#ok<NASGU>
app = pipeline2(f.project, f.run, 'EditExistingRun', true);
appCleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
dropdown = bindingDropdown(app, 'disk_only_mask');
verifyFalse(tc, any(strcmp(dropdown.Items, 'extra_disk_channel')));
dropdown.DropDownOpeningFcn(dropdown, []);
verifyTrue(tc, any(strcmp(dropdown.Items, 'extra_disk_channel')));
verifyEqual(tc, dropdown.Value, 'disk_only_mask');
verifyEqual(tc, f.roi.data.groupid, 'disk_series');
verifyEqual(tc, f.run.ctx.run.nodeParams.combine.Channel1, 'disk_only_mask');
series = findall(app.UIFigure, 'Tag', 'NumericSeries_feature1');
variable = findall(app.UIFigure, 'Tag', 'NumericVariable_feature1');
assertNumElements(tc, series, 1);
assertNumElements(tc, variable, 1);
series.DropDownOpeningFcn(series, []);
variable.DropDownOpeningFcn(variable, []);
component = findall(app.UIFigure, 'Tag', 'NumericComponent_feature1');
assertNumElements(tc, component, 1);
component.DropDownOpeningFcn(component, []);
verifyEqual(tc, component.ItemsData, [1 2]);
verifyEqual(tc, component.Value, 1);
verifyTrue(tc, any(strcmp(series.Items, 'disk_series')));
verifyTrue(tc, any(strcmp(variable.Items, 'other_trace')));
verifyEqual(tc, series.Value, 'disk_series');
verifyEqual(tc, variable.Value, 'trace');
verifyEqual(tc, f.run.ctx.run.nodeParams.traces.feature1, 'disk_series / trace');
% Cached choices should not reopen the files on the next list interaction.
profile clear;
profile on;
profileCleanup = onCleanup(@()profile('off')); %#ok<NASGU>
dropdown.DropDownOpeningFcn(dropdown, []);
variable.DropDownOpeningFcn(variable, []);
profile off;
info = profile('info');
verifyFalse(tc, any(contains(string({info.FunctionTable.FileName}), fullfile('@roi','load.m'))));
verifyFalse(tc, any(string({info.FunctionTable.FunctionName}) == "h5info"));
end

function testExplicitCheckStillValidatesInputsAndModels(tc)
f = fixture();
cleanup = onCleanup(@()removeFixture(f)); %#ok<NASGU>
app = pipeline2(f.project, f.run, 'EditExistingRun', true);
appCleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
profile clear;
profile on;
profileCleanup = onCleanup(@()profile('off')); %#ok<NASGU>
app.CheckbuildButton.ButtonPushedFcn(app.CheckbuildButton, []);
profile off;
info = profile('info');
verifyTrue(tc, any(string({info.FunctionTable.FunctionName}) == "validatePipeline"));
verifyEqual(tc, f.roi.data.groupid, 'disk_series');
verifyFalse(tc, contains(string(app.PipelineandRuncheckreportLabel.Text), 'Use Check build'));
end

function testLegacyRawRunDoesNotReparseAtOpen(tc)
f = fixture();
cleanup = onCleanup(@()removeFixture(f)); %#ok<NASGU>
f.run.ctx.run.inputSourceMode = 'raw_dataloader';
f.run.ctx.run.rawDataPath = f.folder;
% Old runs need not have a runtimeInventory snapshot.
profile clear;
profile on;
profileCleanup = onCleanup(@()profile('off')); %#ok<NASGU>
app = pipeline2(f.project, f.run, 'EditExistingRun', true);
appCleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
profile off;
info = profile('info');
verifyFalse(tc, any(string({info.FunctionTable.FunctionName}) == "parseInputData"));
verifyEmpty(tc, f.roi.data.data);
verifyEqual(tc, app.RuntimeFramesEditField.Value, '1,2');
end

function testPartialRunStillRecoversFullTemplateGraph(tc)
f = fixture();
cleanup = onCleanup(@()removeFixture(f)); %#ok<NASGU>
fullSpec = struct('name',f.pipe.strid,'nodes',f.pipe.nodes,'edges',f.pipe.edges);
historical = pipelineRun(f.run.projectPath, 'full_run', 2);
historical.templateId = f.pipe.strid;
historical.pipelineRef = f.run.pipelineRef;
historical.ctx.pipelineSpec = fullSpec;
f.project.processing.pipelineRun = [historical f.run];
f.pipe.nodes = f.pipe.nodes(1);
pipelineSave(f.pipe, 'Artifacts', false);
f.run.ctx.run.selectedNodes = {'combine'};
app = pipeline2(f.project, f.run, 'EditExistingRun', true);
appCleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
verifyEqual(tc, size(app.UISelectedModuleTable.Data,1), 2);
verifyEqual(tc, [app.UISelectedModuleTable.Data{:,1}], [true false]);
verifyEmpty(tc, f.roi.data.data);
end

function testRecentMenuDoesNotProbeMissingFilesAndCatalogueIsReused(tc)
f = fixture();
cleanup = onCleanup(@()removeFixture(f)); %#ok<NASGU>
oldRecent = getpref('DetecDiv','pipeline2RecentPipelines',{});
prefsCleanup = onCleanup(@()setpref('DetecDiv','pipeline2RecentPipelines',oldRecent)); %#ok<NASGU>
missing = fullfile(f.folder,'unavailable_storage','pipeline.json');
setpref('DetecDiv','pipeline2RecentPipelines',{missing});
first = pipeline2(f.project, f.run, 'EditExistingRun', true);
firstCleanup = onCleanup(@()delete(first)); %#ok<NASGU>
first.UIFigure.Visible = 'off';
verifyTrue(tc, any(strcmp(getpref('DetecDiv','pipeline2RecentPipelines'), missing)), ...
    'Displaying recent files must not probe/prune unavailable storage.');
profile clear;
profile on;
profileCleanup = onCleanup(@()profile('off')); %#ok<NASGU>
second = pipeline2(f.project, f.run, 'EditExistingRun', true);
secondCleanup = onCleanup(@()delete(second)); %#ok<NASGU>
second.UIFigure.Visible = 'off';
profile off;
info = profile('info');
verifyFalse(tc, any(string({info.FunctionTable.FunctionName}) == "detecdiv_modules_ui"), ...
    'An unchanged catalogue must be reused between editor windows.');
menus = findall(second.UIFigure,'Type','uimenu');
refresh = menus(strcmp({menus.Text},'Refresh module catalogue'));
profile clear;
profile on;
refresh.MenuSelectedFcn(refresh, []);
profile off;
info = profile('info');
verifyTrue(tc, any(string({info.FunctionTable.FunctionName}) == "detecdiv_modules_ui"), ...
    'Explicit refresh must bypass the catalogue cache.');
end

function dropdown = bindingDropdown(app, value)
controls = findall(app.UIFigure, 'Type', 'uidropdown');
keep = arrayfun(@(ctrl)isequal(ctrl.Value, value), controls);
dropdown = controls(keep);
assert(numel(dropdown) == 1, 'Expected one saved input binding.');
end

function f = fixture()
folder = tempname;
mkdir(folder);
project = shallow();
project.io = struct('path', folder, 'file', 'remote_project');
projectFolder = fullfile(folder, 'remote_project');
mkdir(projectFolder);
r = roi('trap1', [1 1 2 2]);
r.path = projectFolder;
r.display.channel = {'phase'};
r.data = dataseries();
position = fov();
position.id = 'Pos1';
position.channel = {'phase'};
position.frames = 2;
position.roi = r;
project.fov = position;
imageFile = fullfile(projectFolder, 'im_trap1.h5');
h5create(imageFile, '/disk_only_mask', [2 2 1 2], 'Datatype', 'uint16');
h5create(imageFile, '/extra_disk_channel', [2 2 1 2], 'Datatype', 'uint16');
data = dataseries();
data.groupid = 'disk_series';
data.data = table([1 2;3 4], [3;4], 'VariableNames', {'trace','other_trace'});
save(fullfile(projectFolder, 'data_trap1.mat'), 'data');
pipe = pipeline(folder, 'fast_open_template', 1);
p = struct('pkg','combineMultipleChannels','mode','additive', ...
    'requiredChannelCount',1,'Channel1','disk_only_mask', ...
    'outputChannelName','combined');
combine = struct('id','combine','name','combine','type','processor', ...
    'pkg','combineMultipleChannels','func','combineMultipleChannels.process', ...
    'params',p,'enabled',true,'layout',[1 1 1 1]);
p = lstm_timeseries.parameters([], struct('featureCount',1, ...
    'feature1','disk_series / trace','featureColumn1',1));
traces = struct('id','traces','name','traces','type','classifier', ...
    'pkg','lstm_timeseries','func','lstm_timeseries.classify', ...
    'params',p,'enabled',true,'layout',[2 1 1 1]);
pipe.nodes = [combine traces];
pipelineSave(pipe, 'Artifacts', false);
run = pipelineRun(projectFolder, 'saved_run', 1);
run.templateId = pipe.strid;
run.templatePath = fullfile(pipe.path, 'pipeline.json');
run.pipelineRef = struct('id',pipe.strid,'path',run.templatePath,'version','1.0');
run.ctx = struct('run',struct('inputSourceMode','existing_rois', ...
    'selectedNodes',{{'combine','traces'}}, ...
    'nodeParams',struct('combine',struct('Channel1','disk_only_mask'), ...
        'traces',struct('feature1','disk_series / trace'))), ...
    'sel',struct('fovs',1,'frames',[1 2],'rois',1));
f = struct('folder',folder,'project',project,'roi',r,'pipe',pipe,'run',run);
end

function removeFixture(f)
% Only remove the absolute directory created by this fixture.
if isfolder(f.folder), rmdir(f.folder, 's'); end
end
