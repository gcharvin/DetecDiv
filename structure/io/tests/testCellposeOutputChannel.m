function tests = testCellposeOutputChannel
tests = functiontests(localfunctions);
end

function setupOnce(~)
addpath(genpath(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));
end

function testPartialCacheLoadsExistingMasksWithoutDuplicates(t)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
r = roi('output_cache', [1 1 3 3]);
r.path = root;
r.addChannel(uint16(ones(3,3,1,2)), 'raw');
name = 'results_pred_cellposesam_cell';
masks = uint16(7 * ones(3,3,1,2));
r.addChannel(masks, name, [1 1 1], [0 0 0]);
verifyTrue(t, r.save([], false));
r.image = uint16(ones(3,3,1,2));
r.channelid = 1;
verifyEmpty(t, r.findChannelID(name));
pix = cellposesam.utils.loadExistingOutputChannel(r, name);
verifyEqual(t, r.image(:,:,pix,:), masks);
verifyEqual(t, sum(strcmp(r.display.channel, name)), 1);
verifyEqual(t, size(r.image,3), 2);
verifyEqual(t, cellposesam.utils.loadExistingOutputChannel(r,name), pix);
verifyEmpty(t, cellposesam.utils.loadExistingOutputChannel(r,'new_output'));
end

function testPartialCacheLoadsExistingProbabilityWithoutDuplicates(t)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
r = roi('probability_cache', [1 1 3 3]);
r.path = root;
r.addChannel(uint16(ones(3,3,1,2)), 'raw');
name = 'cellpose_prediction_cellprob';
probability = uint16(1234 * ones(3,3,1,2));
r.addChannel(probability, name, [1 0 1], [1 1 1]);
verifyTrue(t, r.save([], false));

% Reproduce pipeline loading of the input plane only.  The display keeps
% the logical HDF5 identity of the unloaded probability channel.
r.image = uint16(ones(3,3,1,2));
r.channelid = 1;
verifyEmpty(t, r.findChannelID(name));

pix = cellposesam.utils.loadExistingOutputChannel(r, name);
verifyEqual(t, r.image(:,:,pix,:), probability);
verifyEqual(t, sum(strcmp(r.display.channel, name)), 1);
verifyEqual(t, size(r.image,3), 2);
end

function testMetadataOnlyOutputIsMaterializedWithoutDuplicateName(t)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
r = roi('metadata_only_output', [1 1 3 3]);
r.path = root;
raw = uint16(42 * ones(3,3,1,2));
r.addChannel(raw, 'raw');
verifyTrue(t, r.save([], false));
r.load('Channel', 'raw', 'Data', false, 'Silent');
name = 'results_cellposeSAM_cell';
% A project/display cache can advertise an output that has never been saved.
r.display.channel{2} = name;
r.display.channel{3} = 'unloaded_other_output';
r.normalizeDisplayCache();
info = h5info(fullfile(root, ['im_' r.id '.h5']));
verifyFalse(t, any(strcmp({info.Datasets.Name}, name)));

pix = cellposesam.utils.loadExistingOutputChannel(r, name);
verifyEqual(t, pix, 2);
verifyEqual(t, r.channelid, [1 2]);
verifyEqual(t, r.image(:,:,1,:), raw);
verifyEqual(t, r.image(:,:,pix,:), zeros(3,3,1,2,'uint16'));
verifyEqual(t, sum(strcmp(r.display.channel, name)), 1);
verifyEqual(t, r.display.channel{3}, 'unloaded_other_output');
% Newly computed frames must save under the existing logical name.
r.image(:,:,pix,2) = 7;
verifyTrue(t, r.save({name}, false));
stored = h5read(fullfile(root, ['im_' r.id '.h5']), ['/' name]);
verifyEqual(t, stored(:,:,1,1), zeros(3,3,'uint16'));
verifyEqual(t, stored(:,:,1,2), uint16(7 * ones(3,3)));
end

function testUnreadableOutputStoreStillFails(t)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
r = roi('invalid_output_store', [1 1 3 3]);
r.path = root;
r.addChannel(uint16(ones(3,3,1,2)), 'raw');
name = 'results_cellposeSAM_cell';
r.display.channel{2} = name;
fid = fopen(fullfile(root, ['im_' r.id '.h5']), 'w');
fwrite(fid, 'not an HDF5 file');
fclose(fid);
% Compare with the underlying reader so this also covers MATLAB versions
% whose HDF5 library reports a different file-open identifier.
try
    h5info(fullfile(root, ['im_' r.id '.h5']));
catch ME
    expectedId = ME.identifier;
end
verifyError(t, @() cellposesam.utils.loadExistingOutputChannel(r, name), expectedId);
verifyEqual(t, size(r.image,3), 1);
end
