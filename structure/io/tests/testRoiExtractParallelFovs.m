function tests = testRoiExtractParallelFovs
%TESTROIEXTRACTPARALLELFOVS Integration test for isolated FOV tasks.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function testTwoFovsAreExtractedThroughProcessPool(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));

existingPool = gcp('nocreate');
if isempty(existingPool)
    addTeardown(testCase, @() closeOwnedPool());
end

project = shallow();
project.io = struct('path', root, 'file', 'parallel_project.mat');
project.projectId = 'parallel-test';
project.fov = [makeFov(root, 'Pos1_1', 10), makeFov(root, 'Pos2_2', 20)];

ctx = struct();
ctx.shallow = project;
ctx.resume = false;
ctx.saveProgress = false;
ctx.io = struct('persistOutputs', true, 'cachePolicy', 'disk');
ctx.roiExtract = struct('correctDrift', false, 'parallelFovWorkers', 2);

out = roiExtract.process(ctx);

for i = 1:2
    roiId = project.fov(i).roi(1).id;
    h5File = fullfile(root, 'parallel_project', project.fov(i).id, ['im_' roiId '.h5']);
    verifyTrue(testCase, isfile(h5File));
    image = squeeze(h5read(h5File, '/raw'));
    verifySize(testCase, image, [4 5 2]);
end
verifyEqual(testCase, numel(out.roiList), 2);
end

function f = makeFov(root, id, baseValue)
rawDir = fullfile(root, ['raw_' id]);
mkdir(rawDir);
for frame = 1:2
    imwrite(uint16((baseValue + frame) * ones(4, 5)), ...
        fullfile(rawDir, sprintf('frame_%03d.tif', frame)));
end

f = fov();
f.id = id;
f.number = 1;
f.channel = {'raw'};
f.frames = 2;
f.interval = 1;
f.srcpath = {rawDir};
f.srclist = {dir(fullfile(rawDir, '*.tif'))};
r = roi([id '_roi_1'], [1 1 5 4]);
r.path = '';
f.roi = r;
end

function closeOwnedPool()
pool = gcp('nocreate');
if ~isempty(pool)
    delete(pool);
end
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
