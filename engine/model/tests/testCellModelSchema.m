function tests = testCellModelSchema
%TESTCELLMODELSCHEMA Regression tests for compact model editing and storage.
tests = functiontests(localfunctions);
end

function testEditAndRoundTrip(testCase)
model = modelFixture();
mask = uint16([1 1 0; 1 0 2; 0 2 2]);
[model, ~] = cellModel.syncFrame(model, 1, 1, mask, ...
    'TrackPolicy', 'preserve_or_label');
[model, ~] = cellModel.setParent(model, 1, 1, 2, 1);
[model, ~] = cellModel.relabelFrame(model, 1, 1, 2, 3, 'merge');
model.instances.state_id(model.instances.mask_label == 3) = uint16(2);

verifyTrue(testCase, cellModel.validate(model).ok);
verifyEmpty(testCase, cellModel.findInstance(model, 1, 1, 2));
verifyEqual(testCase, cellModel.findInstance(model, 1, 1, 3).track_id, uint64(2));

filename = [tempname '.h5'];
cleanup = onCleanup(@()deleteIfPresent(filename)); %#ok<NASGU>
cellModel.writeH5(filename, model, 'KeepBackup', false);
loaded = cellModel.readH5(filename);
verifyTrue(testCase, cellModel.validate(loaded).ok);
verifyEqual(testCase, loaded.instances.state_id(loaded.instances.mask_label == 3), uint16(2));
end

function testRejectsAmbiguousTrackGeometry(testCase)
model = modelFixture();
model.instances.object_id = uint64([1;2]);
model.instances.family_id = uint32([1;1]);
model.instances.frame = uint32([1;1]);
model.instances.mask_label = uint32([1;2]);
model.instances.track_id = uint64([7;7]);
model.instances.state_id = uint16([0;0]);
report = cellModel.validate(model);
verifyFalse(testCase, report.ok);
verifyTrue(testCase, any(contains(string(report.errors), ...
    'only one mask label')));
end

function testIndependentFamilyProviders(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@()rmdir(folder, 's')); %#ok<NASGU>
roiobj = roi('providers', [1 1 2 2]);
roiobj.path = folder;
roiobj.image = zeros(2,2,2,1,'uint16');
roiobj.channelid = [1 2];
displayState = roiobj.display;
displayState.channel = {'mask_a','mask_b'};
displayState.indexed = [true true];
displayState.rgb = [1 0 0;0 1 0];
roiobj.display = displayState;

model = cellModel.create('providers');
model.families.family_id = uint32([1;2]);
model.families.name = {'family_a';'family_b'};
model.families.mask_provider = {'mask_a';'mask_b'};
model.families.lineage_source = {'a';'b'};
model.families.color_rgb = uint8([255 0 0;0 255 0]);
roiobj.saveCellModel(model, 'KeepBackup', false);
score_setObjectDisplayConfig(roiobj, 'mask_a', ...
    struct('objectFamily','family_b','maskProvider','mask_a'));

[provider, ~, pix, familyId] = score_resolveMaskProvider(roiobj, 'mask_a');
verifyEqual(testCase, provider, 'mask_b');
verifyEqual(testCase, pix, 2);
verifyEqual(testCase, familyId, uint32(2));
end

function model = modelFixture()
model = cellModel.create('test');
model.families.family_id = uint32(1);
model.families.name = {'buds'};
model.families.mask_provider = {'mask'};
model.families.lineage_source = {'manual'};
model.families.color_rgb = uint8([10 20 30]);
model.states.state_id = uint16([1;2]);
model.states.name = {'G1';'budded'};
model.states.color_rgb = uint8([0 255 0;255 0 0]);
end

function deleteIfPresent(filename)
if isfile(filename), delete(filename); end
end
