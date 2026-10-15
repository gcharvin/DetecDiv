function tests = testCellposeFailureRollback
tests = functiontests(localfunctions);
end

function setupOnce(~)
addpath(genpath(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));
end

function testFailedFirstInferenceCannotExportGhostChannel(t)
[root, r, classifier, ctx] = fixture(t);
before = snapshot(r);

verifyError(t, @() cellposesam.classify(r, classifier, ctx), 'runPipeline:Cancelled');
verifyEqual(t, snapshot(r), before);
verifyEmpty(t, r.findChannelID('results_cellposeSAM_cell'));
info = h5info(fullfile(root, ['im_' r.id '.h5']));
verifyEqual(t, {info.Datasets.Name}, {'raw'});

% The Hub saves the project metadata even after a node fails. Exercise that
% same exporter and prove that the failed producer cannot advertise output.
project = shallow();
project.io = struct('path', root, 'file', 'failure_project');
field = fov();
field.id = 'fov_1';
field.roi = r;
project.fov = field;
shallowProjectExportLight(project);
metadata = jsondecode(fileread(fullfile(root, 'failure_project', ...
    'project_metadata', 'fov_00001.json')));
verifyEqual(t, string(metadata.rois(1).display.channel), "raw");
end

function testFailedPartialRerunRestoresCacheAndExistingMasks(t)
[root, r, classifier, ctx] = fixture(t);
name = 'results_cellposeSAM_cell';
masks = uint16(7 * ones(3,3,1,2));
r.addChannel(masks, name, [1 1 1], [0 0 0]);
verifyTrue(t, r.save([], false));
r.load('Channel', 'raw', 'Data', false, 'Silent');
verifyEqual(t, size(r.image,3), 1);
before = snapshot(r);
ctx.sel.frames = 2;

verifyError(t, @() cellposesam.classify(r, classifier, ctx), 'runPipeline:Cancelled');
verifyEqual(t, snapshot(r), before);
verifyEqual(t, h5read(fullfile(root, ['im_' r.id '.h5']), ['/' name]), masks);
end

function [root, r, classifier, ctx] = fixture(t)
root = tempname;
mkdir(root);
addTeardown(t, @() removeFolder(root));
r = roi('failed_inference', [1 1 3 3]);
r.path = root;
r.image = uint16(reshape(1:18,3,3,1,2));
r.channelid = 1;
r.display.channel = {'raw'};
verifyTrue(t, r.save([], false));
r.load('Channel', 'raw', 'Data', false, 'Silent');
classifier = struct('strid', 'cellpose', 'path', root, ...
    'classes', {{'cell'}}, 'outputType', 'segmentation');
token = fullfile(root, 'cancel.token');
fid = fopen(token, 'w');
fclose(fid);
ctx = struct('sel', struct('frames', 1:2, 'channels', {{'raw'}}), ...
    'names', struct('outputName', 'results_cellposeSAM_cell'), ...
    'run', struct('runPath', root), ...
    'cancel', struct('tokenFile', token));
end

function state = snapshot(r)
state = struct('image', r.image, 'channelid', r.channelid, 'display', r.display);
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
