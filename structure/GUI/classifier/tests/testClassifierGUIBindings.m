function tests = testClassifierGUIBindings
%TESTCLASSIFIERGUIBINDINGS Typed-binding table integration smoke test.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath'))))));
addpath(repoRoot);
detecdiv_setup_path;
end

function testVirtualMultiChannelBindingPersistsLegacyAndDatasetFields(testCase)
folder = tempname;
mkdir(folder);
folderCleanup = onCleanup(@()removeFolder(folder)); %#ok<NASGU>

c = classi(folder, 'ui_binding', 1);
c.classifierPkg = 'cnn';
c.trainingFun = 'cnn.train';
c.classifyFun = 'cnn.classify';
c.description = {'cnn','','cnn'};
c.category = {'Image'};
c.classes = {'negative','positive'};
c.trainingParam = cnn.utils.defaultTrainingParam();

r = roi('R1', [1 1 4 4]);
r.path = folder;
r.image = uint16(ones(4,4,2,2));
r.channelid = [1 2];
r.display.channel = {'BF','GFP'};
r.display.intensity = ones(2,3);
r.display.rgb = ones(2,3);
r.display.selectedchannel = [true false];
r.display.indexed = [false false];
r.display.alpha = [1 1];
r.display.contour = [false false];
r.display.width = [1 1];
c.roi = r;
c.channelName = {'BF'};
c.dataset.channels = {'BF'};

app = classifierGUI(c);
appCleanup = onCleanup(@()deleteClassifierGUI(app)); %#ok<NASGU>
drawnow;

% Exercise the App Designer callback path used when the ROI tab is opened.
% Coverage formatters are private app methods after the runtime .mlapp is
% packed, so their calls must retain the app instance as the first argument.
tabCallback = app.SettrainingandvalidationsetROIsTab.ButtonDownFcn;
tabCallback(app.SettrainingandvalidationsetROIsTab, []);
drawnow;
coverageColumn = find(strcmp(app.UITableData.ColumnName, 'Coverage'), 1);
verifyNotEmpty(testCase, coverageColumn);
verifyTrue(testCase, contains(string(app.UITableData.Data{1, coverageColumn}), '/'));

spec = classifierBinding.trainingSpec(c);
tableData = app.UITableParam.Data;
verifyTrue(testCase, all(ismember({spec.param}, tableData.Param)));
verifyTrue(testCase, all(strcmp( ...
    tableData.Group(ismember(tableData.Param, {spec.param})), ...
    'Data bindings')));
verifyEqual(testCase, char(app.ChannelListBox.Visible), 'off');

inputRow = find(strcmp(tableData.Param, 'inputChannelNames'), 1);
verifyEqual(testCase, tableData.Type{inputRow}, 'binding_multi');
gtRow = find(strcmp(tableData.Param, 'groundTruthLabels'), 1);
verifyEqual(testCase, tableData.Type{gtRow}, 'binding_fixed');
verifyTrue(testCase, contains(tableData.Value{gtRow}, 'labels_training'));

editors = findall(app.SettrainingparametersTab, 'Type', 'uilistbox');
verifyNumElements(testCase, editors, 1);
editors(1).Value = {'BF','GFP'};
callback = editors(1).ValueChangedFcn;
callback(editors(1), []);

verifyEqual(testCase, c.channelName, {'BF','GFP'});
verifyEqual(testCase, c.dataset.channels, {'BF','GFP'});
verifyEqual(testCase, c.getInputChannels(), {'BF','GFP'});
end

function testManagedDraftSetsLegacyAnnotatedIndicator(testCase)
folder = tempname;
mkdir(folder);
folderCleanup = onCleanup(@()removeFolder(folder)); %#ok<NASGU>

c = classi(folder, 'ui_annotation', 1);
c.classifierPkg = 'cnn';
c.trainingFun = 'cnn.train';
c.classifyFun = 'cnn.classify';
c.description = {'cnn','','cnn'};
c.category = {'Image'};
c.classes = {'negative','positive'};
c.trainingParam = cnn.utils.defaultTrainingParam();

r = roi('R1', [1 1 4 4]);
r.path = folder;
r.image = uint16(ones(4,4,1,2));
r.channelid = 1;
r.display.channel = {'BF'};
r.display.intensity = ones(1,3);
r.display.rgb = ones(1,3);
r.display.selectedchannel = true;
r.display.indexed = false;
r.display.alpha = 1;
r.display.contour = false;
r.display.width = 1;
c.roi = r;
c.channelName = {'BF'};
c.dataset.channels = {'BF'};

spec = annotationManager.specForClassifier(c);
entry = annotationManager.newEntry(spec, 2);
entry.status = 'draft';
manifest = struct('schema_version', uint16(1), 'entries', entry);
annotationManager.writeManifest(r, manifest);

app = classifierGUI(c);
appCleanup = onCleanup(@()deleteClassifierGUI(app)); %#ok<NASGU>
drawnow;
tabCallback = app.SettrainingandvalidationsetROIsTab.ButtonDownFcn;
tabCallback(app.SettrainingandvalidationsetROIsTab, []);
drawnow;

annotatedColumn = find(strcmp(app.UITableData.ColumnName, 'is annotated'), 1);
validatedColumn = find(strcmp(app.UITableData.ColumnName, 'is validated'), 1);
statusColumn = find(strcmp(app.UITableData.ColumnName, 'Annotation status'), 1);
verifyTrue(testCase, app.UITableData.Data{1, annotatedColumn});
verifyFalse(testCase, app.UITableData.Data{1, validatedColumn});
verifyEqual(testCase, app.UITableData.Data{1, statusColumn}, 'Draft');
end

function deleteClassifierGUI(app)
try
    if ~isempty(app) && isvalid(app), delete(app); end
catch
end
try, close(findall(0, 'Type', 'figure')); catch, end
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
