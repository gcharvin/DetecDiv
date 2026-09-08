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
