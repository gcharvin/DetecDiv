function tests = testRoiExtractParallelFovs
%TESTROIEXTRACTPARALLELFOVS Integration test for isolated FOV tasks.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function testThreeFovsAreQueuedThroughTwoProcessSlots(testCase)
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
project.fov = [makeFov(root, 'Pos1_1', 10), makeFov(root, 'Pos2_2', 20), ...
    makeFov(root, 'Pos3_3', 30)];

ctx = struct();
ctx.shallow = project;
ctx.resume = false;
ctx.saveProgress = false;
ctx.io = struct('persistOutputs', true, 'cachePolicy', 'disk');
ctx.roiExtract = struct('correctDrift', false, 'parallelFovWorkers', 2);

out = roiExtract.process(ctx);

for i = 1:3
    roiId = project.fov(i).roi(1).id;
    h5File = fullfile(root, 'parallel_project', project.fov(i).id, ['im_' roiId '.h5']);
    verifyTrue(testCase, isfile(h5File));
    image = squeeze(h5read(h5File, '/raw'));
    verifySize(testCase, image, [4 5 2]);
end
verifyEqual(testCase, numel(out.roiList), 3);
end

function testWorkerPipelineExtractsEveryFovWithoutNestedPool(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));
pool = gcp('nocreate');
if isempty(pool)
    pool = parpool('Processes', 1);
    addTeardown(testCase, @() closeOwnedPool());
end
poolSize = pool.NumWorkers;
future = parfeval(pool, @extractInsideWorker, 1, root);
result = fetchOutputs(future);
verifyTrue(testCase, result.insideWorker);
verifySubstring(testCase, result.log, 'Local batch has no reserved FOV pool');
verifyEqual(testCase, result.roiCount, 3);
for i = 1:3
    id = sprintf('Pos%d_%d', i, i);
    h5File = fullfile(root, 'worker_project', id, ['im_' id '_roi_1.h5']);
    verifyTrue(testCase, isfile(h5File));
    images = squeeze(h5read(h5File, '/raw'));
    verifySize(testCase, images, [4 5 2]);
    verifyEqual(testCase, images(:,:,1), uint16((10*i+1)*ones(4,5)));
    verifyEqual(testCase, images(:,:,2), uint16((10*i+2)*ones(4,5)));
end
verifyEqual(testCase, pool.NumWorkers, poolSize);
end

function result = extractInsideWorker(root)
project = shallow();
project.io = struct('path', root, 'file', 'worker_project.mat');
project.projectId = 'worker-extraction-test';
project.fov = [makeFov(root, 'Pos1_1', 10), makeFov(root, 'Pos2_2', 20), ...
    makeFov(root, 'Pos3_3', 30)];
ctx = struct('shallow', project, 'resume', false, 'saveProgress', false, ...
    'execution', struct('requested_mode','local_process'), ...
    'io', struct('persistOutputs', true, 'cachePolicy', 'disk'), ...
    'roiExtract', struct('correctDrift', false, 'executionMode', 'parallel', 'parallelFovWorkers', 2));
insideWorker = ~isempty(getCurrentTask());
log = evalc('out = roiExtract.process(ctx);');
result = struct('insideWorker', insideWorker, 'log', log, 'roiCount', numel(out.roiList));
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
if isfolder(folder)
    resolved = char(java.io.File(folder).getCanonicalPath());
    safeRoot = char(java.io.File(tempdir).getCanonicalPath());
    assert(startsWith(resolved, [safeRoot filesep], 'IgnoreCase', true));
    rmdir(resolved, 's');
end
end
