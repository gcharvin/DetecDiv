function tests = testFovFileSourceReconstruction
% File-series chronology must survive lightweight project reconstruction.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(repoRoot);
detecdiv_setup_path(repoRoot, 'ResetPath', false, 'Verbose', false);
end

function testEmptySrclistUsesNaturalFrameOrder(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
frameNumbers = [99 100 101 999 1000 1023];
writeFrames(root, 'legacy-', frameNumbers, 0);
field = fileFov({root}, {'phase'}, numel(frameNumbers));

verifyEmpty(testCase, field.srclist);
verifyFrameValues(testCase, field, 1, frameNumbers);
verifyEqual(testCase, {field.srclist{1}.name}, ...
    arrayfun(@(f)sprintf('legacy-%03d.tif', f), frameNumbers, ...
    'UniformOutput', false));
end

function testJsonRoundTripReconstructsNaturalOrderForEachChannel(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
frameNumbers = [99 100 101 999 1000 1023];
phaseDir = fullfile(root, 'phase');
gfpDir = fullfile(root, 'gfp');
mkdir(phaseDir);
mkdir(gfpDir);
writeFrames(phaseDir, 'legacy-ch1-', frameNumbers, 0);
writeFrames(gfpDir, 'legacy-ch2-', frameNumbers, 10000);

project = shallow();
project.io.path = root;
project.io.file = 'file_order_project';
mkdir(fullfile(root, project.io.file));
field = fileFov({phaseDir, gfpDir}, {'phase', 'gfp'}, numel(frameNumbers));
field.parent = project;
project.fov = field;
% Warm the source cache before saving, as happens during raw image preview.
verifyFrameValues(testCase, field, 1, frameNumbers);
verifyFrameValues(testCase, field, 2, frameNumbers + 10000);

jsonPath = fullfile(root, [project.io.file '.json']);
shallowProjectExportLight(project, jsonPath);
loaded = shallowProjectImportLight(jsonPath);
verifyEmpty(testCase, loaded.fov(1).srclist);
verifyFrameValues(testCase, loaded.fov(1), 1, frameNumbers);
verifyFrameValues(testCase, loaded.fov(1), 2, frameNumbers + 10000);
end

function testSharedFolderKeepsPhysicalChannelAndZMapping(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
frameNumbers = [99 100 101 999 1000 1023];
for i = 1:numel(frameNumbers)
    frame = frameNumbers(i);
    imwrite(uint16(frame .* ones(3, 4)), fullfile(root, ...
        sprintf('img_channel000_position000_time%03d_z001.tif', frame)));
    imwrite(uint16((frame + 10000) .* ones(3, 4)), fullfile(root, ...
        sprintf('img_channel001_position000_time%03d_z000.tif', frame)));
    % These planes share the folder but belong to neither requested source.
    imwrite(uint16(50000 .* ones(3, 4)), fullfile(root, ...
        sprintf('img_channel000_position000_time%03d_z000.tif', frame)));
end
field = fileFov({root, root}, ...
    {'channel000_z001', 'channel001_z000'}, numel(frameNumbers));

verifyFrameValues(testCase, field, 1, frameNumbers);
verifyFrameValues(testCase, field, 2, frameNumbers + 10000);
verifyEqual(testCase, numel(field.srclist{1}), numel(frameNumbers));
verifyEqual(testCase, numel(field.srclist{2}), numel(frameNumbers));
end

function testExistingExplicitSrclistOrderIsPreserved(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
writeFrames(root, 'legacy-', [99 100 1000], 0);
field = fileFov({root}, {'phase'}, 3);
files = dir(fullfile(root, '*.tif'));
names = {files.name};
requestedNames = {'legacy-1000.tif', 'legacy-099.tif', 'legacy-100.tif'};
[~, order] = ismember(requestedNames, names);
field.srclist = {files(order)};

verifyFrameValues(testCase, field, 1, [1000 99 100]);
verifyEqual(testCase, {field.srclist{1}.name}, requestedNames);
end

function field = fileFov(folders, channels, frameCount)
field = fov();
field.id = 'FileSeries_1';
field.srcpath = folders;
field.channel = channels;
field.frames = repmat(frameCount, 1, numel(channels));
field.interval = ones(1, numel(channels));
field.binning = ones(1, numel(channels));
field.roi = roi.empty;
end

function writeFrames(folder, prefix, frameNumbers, offset)
for frame = frameNumbers
    imwrite(uint16((frame + offset) .* ones(3, 4)), ...
        fullfile(folder, sprintf('%s%03d.tif', prefix, frame)));
end
end

function verifyFrameValues(testCase, field, channel, expectedValues)
for index = 1:numel(expectedValues)
    actual = field.readImage(index, channel);
    verifyEqual(testCase, actual, uint16(expectedValues(index) .* ones(3, 4)), ...
        sprintf('Channel %d frame index %d has the wrong source.', channel, index));
end
end
