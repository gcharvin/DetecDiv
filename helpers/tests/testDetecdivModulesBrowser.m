function tests = testDetecdivModulesBrowser
% Browsing and selecting a module must only read catalogue metadata.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
tc.TestData.originalPath = path;
addpath(fullfile(tc.TestData.repoRoot, 'helpers'));
end

function teardownOnce(tc)
path(tc.TestData.originalPath);
end

function setup(tc)
tc.TestData.fixture = tempname;
tc.TestData.root = fullfile(tc.TestData.fixture, 'detecdiv');
mkdir(fullfile(tc.TestData.root, 'engine', 'classification'));
tc.TestData.pluginRoot = fullfile(tc.TestData.fixture, 'hoct');
end

function teardown(tc)
if isfolder(tc.TestData.fixture)
    fixture = char(java.io.File(tc.TestData.fixture).getCanonicalPath());
    temporaryRoot = char(java.io.File(tempdir).getCanonicalPath());
    assert(startsWith(fixture, [temporaryRoot filesep], 'IgnoreCase', true), ...
        'testModuleBrowser:UnsafeCleanup', 'Fixture escaped temporary root.');
    rmdir(fixture, 's');
end
end

function testThreePilotsUseOneReadOnlyCatalogue(tc)
sam = makePackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'browserSamProbe', 'CellposeSAM', 'test.browserSam');
latent = makePackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'browserLatentProbe', 'CellLatentModel', 'test.browserLatent');
hoct = makePackage(fullfile(tc.TestData.pluginRoot, 'plugins', 'classifier'), ...
    'browserHoctProbe', 'HOCT', 'test.browserHoct');
before = path;
manifestBefore = fileread(fullfile(hoct, 'module.json'));
fig = fixtureBrowser(tc);
cleanup = onCleanup(@()delete(fig)); %#ok<NASGU>

verifyEqual(tc, char(fig.Visible), 'off');
table = findall(fig, 'Tag', 'DetecdivModuleCatalogueTable');
verifyNumElements(tc, table, 1);
verifyEqual(tc, size(table.Data), [3 6]);
verifyEqual(tc, sort(string(table.Data(:,1))), ...
    sort(["CellposeSAM"; "CellLatentModel"; "HOCT"]));
hoctRow = find(strcmp(table.Data(:,1), 'HOCT'), 1);
verifyEqual(tc, table.Data{hoctRow,4}, 'external');
verifyEqual(tc, table.Data{hoctRow,5}, 'fixture-adapter');
verifyTrue(tc, all(strcmp(table.Data(~strcmp(table.Data(:,1),'HOCT'),4), ...
    'bundled')));
verifyTrue(tc, all(~[table.UserData.canAdd]), ...
    'Catalogue discovery must not activate packages absent from MATLAB path.');

callback = table.SelectionChangedFcn;
for row = 1:3
    table.Selection = [row 1];
    callback(table, struct('Selection', [row 1]));
    details = findall(fig, 'Tag', 'DetecdivModuleCatalogueDetails');
    verifyTrue(tc, contains(strjoin(string(details.Value), newline), ...
        table.UserData(row).module.id));
end
refresh = findall(fig, 'Type', 'uibutton', 'Text', 'Refresh');
callback = refresh.ButtonPushedFcn;
callback(refresh, []);

verifyEqual(tc, path, before);
verifyEqual(tc, fileread(fullfile(hoct, 'module.json')), manifestBefore);
for package = {sam, latent, hoct}
    verifyFalse(tc, isfile(fullfile(package{1}, 'metadata_evaluated.txt')), ...
        'Opening, selecting and refreshing must not execute module hooks.');
end
end

function testInvalidAndConflictingCandidatesRemainVisible(tc)
first = makePackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'browserConflictProbe', 'Source candidate', 'test.browserConflict');
second = makePackage(fullfile(tc.TestData.pluginRoot, 'plugins', 'classifier'), ...
    'browserConflictProbe', 'Other candidate', 'test.browserConflict');
invalid = makePackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'browserInvalidProbe', 'Invalid candidate', 'test.browserInvalid');
writeText(fullfile(invalid, 'module.json'), '{"format":"invalid"}');

fig = fixtureBrowser(tc);
cleanup = onCleanup(@()delete(fig)); %#ok<NASGU>
table = findall(fig, 'Tag', 'DetecdivModuleCatalogueTable');
verifyEqual(tc, size(table.Data,1), 3);
verifyTrue(tc, all(~[table.UserData.canAdd]));
items = table.UserData;
modules = [items.module];
verifyEqual(tc, sum(strcmp({modules.status}, 'conflict')), 2);
verifyEqual(tc, sum(strcmp({modules.descriptorStatus}, 'invalid')), 1);
diagnostics = findall(fig, 'Tag', 'DetecdivModuleCatalogueDiagnostics');
text = strjoin(string(diagnostics.Value), newline);
verifyTrue(tc, contains(text, 'DUPLICATE_ID'));
verifyTrue(tc, contains(text, 'browserInvalidProbe'));
for package = {first, second, invalid}
    verifyFalse(tc, isfile(fullfile(package{1}, 'metadata_evaluated.txt')));
end
end

function testEmptyCatalogueAndUnknownOptions(tc)
fig = fixtureBrowser(tc);
cleanup = onCleanup(@()delete(fig)); %#ok<NASGU>
table = findall(fig, 'Tag', 'DetecdivModuleCatalogueTable');
verifyEmpty(tc, table.Data);
details = findall(fig, 'Tag', 'DetecdivModuleCatalogueDetails');
verifyTrue(tc, contains(strjoin(string(details.Value),' '), 'No module'));
verifyError(tc, @()detecdiv_modules_browser('Unsupported', true), ...
    'detecdiv_modules_browser:BadInput');
end

function fig = fixtureBrowser(tc)
fig = detecdiv_modules_browser('Root', tc.TestData.root, ...
    'PluginRoots', {tc.TestData.pluginRoot}, ...
    'IncludeActivePackages', false, 'Visible', 'off');
end

function folder = makePackage(parent, package, name, id)
folder = fullfile(parent, ['+' package]);
mkdir(folder);
manifest = struct('format', 'detecdiv.module.v1', 'id', id, ...
    'name', name, 'type', 'classifier', 'package', package, ...
    'adapterVersion', 'fixture-adapter', 'summary', 'Read-only browser fixture.', ...
    'capabilities', {{'tracking'}}, ...
    'entrypoints', struct('execute', [package '.classify'], ...
        'parameters', [package '.executionSpec'], ...
        'contract', [package '.moduleContract'], ...
        'validate', [package '.validateModule'], ...
        'prepare', [package '.prepareRuntime']), ...
    'compatibility', struct('detecdiv', NaN, ...
        'pipelineContract', 'detecdiv.module_contract.v1', ...
        'runtimeContract', 'detecdiv.module_runtime.v1'), ...
    'provenance', struct('repository', 'https://example.test/browser'));
writeText(fullfile(folder, 'module.json'), jsonencode(manifest));
for entry = {'classify','executionSpec','moduleContract','validateModule', ...
        'prepareRuntime','setparam'}
    code = sprintf(['function out=%s(varargin)\n' ...
        'fid=fopen(fullfile(fileparts(mfilename(''fullpath'')),''metadata_evaluated.txt''),''w'');\n' ...
        'fclose(fid); error(''fixture:MustNotExecute'',''Browser executed module code.'');\n' ...
        'out=[];\nend\n'], entry{1});
    writeText(fullfile(folder, [entry{1} '.m']), code);
end
end

function writeText(filename, value)
fid = fopen(filename, 'w');
assert(fid >= 0);
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', value);
end
