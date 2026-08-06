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
