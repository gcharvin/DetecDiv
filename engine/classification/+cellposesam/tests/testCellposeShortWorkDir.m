function tests = testCellposeShortWorkDir
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(fullfile(root, 'engine', 'classification'));
end

function testLongJobTemporaryDirectoryFits(testCase)
root = fixtureRoot();
mkdir(root);
addTeardown(testCase, @()removeFolder(root));
jobTemp = fullfile(root, repmat('w', 1, max(1, 165-numel(root))));
mkdir(jobTemp);
first = cellposesam.utils.createShortWorkDir({jobTemp});
second = cellposesam.utils.createShortWorkDir({jobTemp});
verifyNotEqual(testCase, first, second);
verifyTrue(testCase, startsWith(first, [jobTemp filesep]));
verifyLessThanOrEqual(testCase, numel(fullfile(first, ...
    'classify_cellposesam_config.json')), 240);
end

function testOverlongTemporaryRootUsesNextCandidate(testCase)
root = fixtureRoot();
mkdir(root);
addTeardown(testCase, @()removeFolder(root));
tooLong = fullfile(root, repmat('x', 1, 240));
chosen = cellposesam.utils.createShortWorkDir({tooLong, root});
verifyTrue(testCase, startsWith(chosen, [root filesep]));
verifyFalse(testCase, isfolder(tooLong));
end

function testNoUsableTemporaryRootHasClearError(testCase)
tooLong = fullfile(tempdir, repmat('x', 1, 240));
verifyError(testCase, @()cellposesam.utils.createShortWorkDir({tooLong}), ...
    'cellposesam:NoShortWorkDir');
end

function testPlatformTemporaryDirectory(testCase)
folder = cellposesam.utils.createShortWorkDir();
addTeardown(testCase, @()removeFolder(folder));
verifyTrue(testCase, isfolder(folder));
verifyLessThanOrEqual(testCase, numel(fullfile(folder, ...
    'classify_cellposesam_config.json')), 240);
end

function testMatlabPythonExchange(testCase)
python = getenv('DETECDIV_TEST_PYTHON');
assumeTrue(testCase, ~isempty(python), ...
    'Set DETECDIV_TEST_PYTHON to check the actual inference runtime.');
root = fixtureRoot();
mkdir(root);
addTeardown(testCase, @()removeFolder(root));
jobTemp = fullfile(root, repmat('w', 1, max(1, 165-numel(root))));
mkdir(jobTemp);
folders = {cellposesam.utils.createShortWorkDir(), ...
    cellposesam.utils.createShortWorkDir({jobTemp})};
for folderIdx = 1:numel(folders)
    folder = folders{folderIdx};
    addTeardown(testCase, @()removeFolder(folder));
    gfp = uint8(reshape(1:48, [4 4 1 3]));
    frames = 1:3;
    save(fullfile(folder, 'tmp.mat'), 'gfp', 'frames');
    cfg = struct('tmp_mat_path', fullfile(folder, 'tmp.mat'), 'classif_path', folder);
    configPath = fullfile(folder, 'classify_cellposesam_config.json');
    fid = fopen(configPath, 'w');
    assert(fid >= 0);
    fwrite(fid, jsonencode(cfg), 'char');
    fclose(fid);
    script = fullfile(fileparts(mfilename('fullpath')), 'fixtures', 'scratch_roundtrip.py');
    [status, output] = system(sprintf('"%s" "%s" "%s"', python, script, configPath));
    verifyEqual(testCase, status, 0, output);
    result = load(fullfile(folder, 'results.mat'));
    verifyEqual(testCase, result.masks, uint16(reshape(1:48, [4 4 1 3])));
    fprintf('Cellpose scratch exchange: config path %d characters (%s)\n', ...
        numel(configPath), configPath);
end
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end

function root = fixtureRoot()
% Keep fixture parents outside an intentionally long inherited job TEMP.
if ispc && ~isempty(getenv('LOCALAPPDATA'))
    root = tempname(fullfile(getenv('LOCALAPPDATA'), 'Temp'));
else
    root = tempname;
end
end
