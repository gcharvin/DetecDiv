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

function testCompositeTrainingScopeIsShownFirst(testCase)
folder = tempname;
mkdir(folder);
folderCleanup = onCleanup(@()removeFolder(folder)); %#ok<NASGU>

c = classi(folder, 'ui_composite_scope', 1);
c.classifierPkg = 'cellLatentModel';
c.trainingFun = 'cellLatentModel.train';
c.classifyFun = 'cellLatentModel.classify';
c.description = {'cellLatentModel','','cellLatentModel'};
c.category = {'Image'};
c.classes = {'cell'};
c.trainingParam = cellLatentModel.utils.defaultTrainingParam();

app = classifierGUI(c);
appCleanup = onCleanup(@()deleteClassifierGUI(app)); %#ok<NASGU>
drawnow;

tableData = app.UITableParam.Data;
expected = {'architectureVersion'; 'trainTrackingActions'; ...
    'trainMotherNull'; 'stateUpdateMode'};
verifyEqual(testCase,tableData.Param(1:4),expected);
verifyTrue(testCase,all(strcmp(tableData.Group(1:4),'Training scope')));
verifyEqual(testCase,app.UITableParam.ColumnName{3}, ...
    'Model component / category');
verifyEqual(testCase,tableData.Group{5},'Shared > Dataset');
verifyTrue(testCase,all(ismember( ...
    {'Tracking head > Input','Tracking head > Ground truth', ...
     'Tracking head > GT quality','Tracking head > Candidates', ...
     'Tracking head > Initialization','Tracking head > Loss weights', ...
     'Tracking head > Optimization','Mother/NULL head > Input', ...
     'Mother/NULL head > Ground truth', ...
     'Mother/NULL head > Architecture', ...
     'Mother/NULL head > Temporal context', ...
     'Mother/NULL head > Optimization', ...
     'Mother/NULL head > Model selection'},tableData.Group)));
verifyTrue(testCase,all(ismember( ...
    {'trackingMinimumTruthOverlap','trackingInitialCheckpoint', ...
     'trackingAssociationLossWeight', ...
     'trackingSuccessorLossWeight', ...
     'motherNullEarlyStoppingPatience', ...
     'motherNullEarlyStoppingMinDelta'},tableData.Param)));
verifyFalse(testCase,any(ismember( ...
    {'continuousMaxCandidates','continuousBlockEmbeddingDim', ...
     'maxEventHistoryTokens','minLifetime','latentDim','seedCount', ...
     'transfer_learning'},tableData.Param)));
verifyTrue(testCase,isfield(c.trainingParam,'continuousMaxCandidates'), ...
    'Hidden backend parameters must remain stored on the classifier.');

% Changing a scope control must immediately recompute the ownership text.
dropDowns = findall(app.SettrainingparametersTab,'Type','uidropdown');
verifyNumElements(testCase,dropDowns,1);
dropDowns(1).Value = 'lineage_only_v1';
callback = dropDowns(1).ValueChangedFcn;
callback(dropDowns(1),[]);
drawnow;
scopeAreas = findall(app.SettrainingparametersTab,'Type','uitextarea');
verifyNumElements(testCase,scopeAreas,1);
scopeText = strjoin(string(scopeAreas(1).Value),' ');
verifyTrue(testCase,contains(scopeText,'Architecture=lineage_only_v1'));
verifyTrue(testCase,contains(scopeText, ...
    'FROZEN: CellposeSAM, Trackastra, EDGE/APPEAR/END tracking head'));
verifyEqual(testCase,app.UITableParam.Data.Value{1},'lineage_only_v1');
end

function testPersistedValidDraftRequiresExplicitValidation(testCase)
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
entry.revision = uint32(7);
entry.validation_status = 'valid';
entry.validated_revision = entry.revision;
entry.validated_at = '2026-08-15T09:00:00+02:00';
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
validationColumn = find(strcmp(app.UITableData.ColumnName, 'Validation'), 1);
verifyTrue(testCase, app.UITableData.Data{1, annotatedColumn});
verifyEmpty(testCase, validatedColumn, ...
    'The duplicate validated checkbox must not remain user-visible.');
verifyEmpty(testCase, validationColumn, ...
    'The duplicate validation column must not remain user-visible.');
verifyEqual(testCase, app.UITableData.Data{1, statusColumn}, 'Draft', ...
    ['Draft+valid is inconsistent historical metadata; only the atomic ' ...
     'Validate GT transition may make it training-ready.']);
end

function testRemoveSelectedRoiRemapsTrainingSelection(testCase)
folder = tempname;
mkdir(folder);
folderCleanup = onCleanup(@()removeFolder(folder)); %#ok<NASGU>

c = classi(folder, 'ui_remove_roi', 1);
c.classifierPkg = 'cnn';
c.trainingFun = 'cnn.train';
c.classifyFun = 'cnn.classify';
c.description = {'cnn','','cnn'};
c.category = {'Image'};
c.classes = {'negative','positive'};
c.trainingParam = cnn.utils.defaultTrainingParam();

rois(1) = localGuiTestRoi('R1', folder);
rois(2) = localGuiTestRoi('R2', folder);
rois(3) = localGuiTestRoi('R3', folder);
rois(4) = localGuiTestRoi('R4', folder);
c.roi = rois;
c.trainingset = [1 4];
c.dataset.split = struct('train', [1 4], 'val', 3, 'test', 2);
c.channelName = {'BF'};
c.dataset.channels = {'BF'};
c.score = struct('stale', true);

app = classifierGUI(c);
appCleanup = onCleanup(@()deleteClassifierGUI(app)); %#ok<NASGU>
drawnow;
tabCallback = app.SettrainingandvalidationsetROIsTab.ButtonDownFcn;
tabCallback(app.SettrainingandvalidationsetROIsTab, []);
drawnow;

% R2 is the test ROI. Removing it must retain R1/R3/R4 and remap each
% explicit split without collapsing validation into testing.
row = find(cellfun(@(value)isequal(double(value), 2), ...
    app.UITableData.Data(:,3)), 1);
verifyNotEmpty(testCase, row);
app.Data.annotationSession = annotationManager.createSession(c, 3);
app.UITableData.Selection = [row 1];
callback = app.removeselectedROIButton.ButtonPushedFcn;
callback(app.removeselectedROIButton, []);
drawnow;

verifyEqual(testCase, {c.roi.id}, {'R1','R3','R4'});
verifyEqual(testCase, c.trainingset, [1 3]);
verifyEqual(testCase, c.dataset.split.train, [1 3]);
verifyEqual(testCase, c.dataset.split.val, 2);
verifyEmpty(testCase, c.dataset.split.test);
verifyEmpty(testCase, c.score);
verifyEmpty(testCase, app.Data.annotationSession);
verifyEmpty(testCase, app.UITableData.Selection);

% Multi-selection and deleting every remaining ROI must leave a clean
% placeholder and no stale train/validation/test indices.
app.UITableData.Selection = [1 1; 2 1; 3 1];
callback(app.removeselectedROIButton, []);
drawnow;
verifyNumElements(testCase, c.roi, 1);
verifyEmpty(testCase, c.roi(1).id);
verifyEmpty(testCase, c.trainingset);
verifyEmpty(testCase, c.dataset.split.train);
verifyEmpty(testCase, c.dataset.split.val);
verifyEmpty(testCase, c.dataset.split.test);
end

function r = localGuiTestRoi(id, folder)
r = roi(id, [1 1 4 4]);
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
