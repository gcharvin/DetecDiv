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
