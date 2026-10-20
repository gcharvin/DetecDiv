function tests = testDetecdivModulesUi
% Frontends share static catalogue metadata and never activate an adapter.
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
tc.TestData.fixtureRoot = tempname;
tc.TestData.pathBeforeTest = path;
mkdir(tc.TestData.fixtureRoot);
tc.TestData.root = fullfile(tc.TestData.fixtureRoot, 'repo');
mkdir(fullfile(tc.TestData.root, 'engine', 'classification'));
mkdir(fullfile(tc.TestData.root, 'engine', 'processor'));
end

function teardown(tc)
path(tc.TestData.pathBeforeTest);
rehash;
if isfolder(tc.TestData.fixtureRoot)
    folder = char(java.io.File(tc.TestData.fixtureRoot).getCanonicalPath());
    safeRoot = char(java.io.File(tempdir).getCanonicalPath());
    assert(startsWith(folder, [safeRoot filesep], 'IgnoreCase', true), ...
        'testModulesUi:UnsafeCleanup', 'Fixture cleanup escaped the temporary root.');
    rmdir(folder, 's');
end
end

function testPilotRowsUseOneMetadataShapeAndPreserveDistribution(tc)
[packages, pluginRoot] = makePilots(tc);
[rows, items, diagnostics] = listFixture(tc, 'PluginRoots', {pluginRoot});
verifyEqual(tc, size(rows), [3 4]);
verifyEqual(tc, numel(items), 3);
verifyNoErrors(tc, diagnostics);
for k = 1:numel(items)
    verifyEqual(tc, rows{k, 1}, items(k).label);
    verifyEqual(tc, rows{k, 2}, items(k).module.type);
    verifyEqual(tc, rows{k, 3}, items(k).module.pkg);
    verifyTrue(tc, contains(rows{k, 4}, items(k).module.summary));
    verifyFalse(tc, items(k).canAdd, 'An off-path package must not be activated by discovery.');
    verifyNotEmpty(tc, items(k).reason);
    verifyNotEmpty(tc, items(k).statusLabel);
    verifyTrue(tc, iscellstr(items(k).details));
    details = strjoin(items(k).details, newline);
    verifyTrue(tc, contains(details, items(k).module.id));
    verifyTrue(tc, contains(details, items(k).module.path));
    verifyTrue(tc, contains(lower(details), 'not checked'), ...
        'Catalogue browsing must not claim a successful runtime validation.');
end
sam = selectItem(tc, items, 'uiCatalogSam');
latent = selectItem(tc, items, 'uiCatalogLatent');
hoct = selectItem(tc, items, 'uiCatalogHoct');
verifyEqual(tc, sam.module.name, 'CellposeSAM');
verifyEqual(tc, latent.module.name, 'CellLatentModel');
verifyEqual(tc, hoct.module.name, 'HOCT');
verifyEqual(tc, sam.module.distribution, 'bundled');
verifyEqual(tc, latent.module.distribution, 'bundled');
verifyEqual(tc, hoct.module.distribution, 'external');
verifyNoEvaluation(tc, packages);
end

function testOnlyActuallySelectedCopiesCanBeAddedWithoutCallingModuleCode(tc)
[packages, pluginRoot] = makePilots(tc);
for k = 1:numel(packages)
    addpath(fileparts(packages{k}), '-begin');
end
rehash;
pathBefore = path;
[rows, items, diagnostics] = listFixture(tc, 'PluginRoots', {pluginRoot});
verifyEqual(tc, size(rows, 1), 3);
verifyNoErrors(tc, diagnostics);
verifyTrue(tc, all([items.canAdd]));
modules = [items.module];
verifyTrue(tc, all([modules.onPath]));
verifyEqual(tc, path, pathBefore, 'Reading a module library must not alter the MATLAB path.');
verifyNoEvaluation(tc, packages);
end

function testAdapterVersionNeverBecomesAnInventedModelVersion(tc)
package = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'uiCatalogVersion', 'test.uiVersion', 'CellposeSAM', 'classifier');
manifestFile = fullfile(package, 'module.json');
manifest = jsondecode(fileread(manifestFile));
manifest.adapterVersion = NaN; % JSON null means unspecified, never a weight version.
manifest.compatibility.detecdiv = NaN;
writeText(manifestFile, jsonencode(manifest));
[~, items, diagnostics] = listFixture(tc);
verifyNoErrors(tc, diagnostics);
verifyEqual(tc, items.module.adapterVersion, '');
verifyEqual(tc, items.module.descriptorStatus, 'declared');
details = lower(strjoin(items.details, newline));
verifyTrue(tc, contains(details, 'adapter'), 'Display the source of the version being shown.');
verifyTrue(tc, contains(details, 'unspecified') || contains(details, 'unknown') || ...
    contains(details, 'non renseign') || contains(details, 'non spécifi') || ...
    contains(details, 'inconnu'), 'A missing adapter version must remain explicit.');
verifyEmpty(tc, regexp(details, 'model version\s*:\s*0\.1\.0', 'once'));
verifyNoEvaluation(tc, {package});
end

function testInvalidDescriptorRemainsVisibleAndDisabled(tc)
package = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'uiCatalogInvalid', 'test.uiInvalid', 'Broken metadata', 'classifier');
writeText(fullfile(package, 'module.json'), '{ "format": ');
addpath(fileparts(package), '-begin');
rehash;
[rows, items, diagnostics] = listFixture(tc);
verifyEqual(tc, size(rows, 1), 1);
verifyEqual(tc, items.module.status, 'invalid');
verifyFalse(tc, items.canAdd);
verifyNotEmpty(tc, items.reason);
verifyTrue(tc, any(strcmpi({diagnostics.severity}, 'error')));
verifyNoEvaluation(tc, {package});
end

function testDuplicateIdentitiesRemainConflictingAndDisabled(tc)
first = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'uiCatalogDuplicateA', 'test.uiDuplicate', 'First candidate', 'classifier');
second = makeDeclaredPackage(fullfile(tc.TestData.fixtureRoot, 'explicit'), ...
    'uiCatalogDuplicateB', 'test.uiDuplicate', 'Second candidate', 'classifier');
addpath(fileparts(first), '-begin');
addpath(fileparts(second), '-begin');
rehash;
[rows, items, diagnostics] = listFixture(tc, 'PackagePaths', {second});
verifyEqual(tc, size(rows, 1), 2);
modules = [items.module];
verifyEqual(tc, {modules.status}, {'conflict', 'conflict'});
verifyFalse(tc, any([items.canAdd]));
verifyTrue(tc, all(arrayfun(@(item) ~isempty(item.reason), items)));
verifyTrue(tc, any(strcmp({diagnostics.code}, 'DUPLICATE_ID')));
verifyNoEvaluation(tc, {first, second});
end

function testLegacyPackageCanStillBeAddedWhenItIsTheSelectedCopy(tc)
package = makePackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'uiCatalogLegacy', 'classify');
addpath(fileparts(package), '-begin');
rehash;
[rows, items, diagnostics] = listFixture(tc);
verifyNoErrors(tc, diagnostics);
verifyEqual(tc, size(rows, 1), 1);
verifyEqual(tc, items.module.descriptorStatus, 'legacy');
verifyTrue(tc, items.canAdd);
verifyNotEmpty(tc, items.statusLabel);
verifyTrue(tc, contains(lower(strjoin(items.details, newline)), 'legacy'));
verifyNoEvaluation(tc, {package});
end

function testProcessorsUseTheSameRowsAndSelectionRule(tc)
package = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', 'processor'), ...
    'uiCatalogProcessor', 'test.uiProcessor', 'Fixture metrics', 'processor');
addpath(fileparts(package), '-begin');
rehash;
[rows, items, diagnostics] = listFixture(tc);
verifyNoErrors(tc, diagnostics);
verifyEqual(tc, rows{1, 2}, 'processor');
verifyEqual(tc, items.module.entrypoint, 'uiCatalogProcessor.process');
verifyTrue(tc, items.canAdd);
verifyNoEvaluation(tc, {package});
end

function testSelectedInstalledCopyIsIncludedWithoutChangingPath(tc)
registeredRoot = fullfile(tc.TestData.fixtureRoot, 'registered');
registered = makeDeclaredPackage(fullfile(registeredRoot, 'plugins', 'classifier'), ...
    'uiCatalogFrozen', 'test.uiFrozen', 'Registered adapter', 'classifier');
selected = makePackage(fullfile(tc.TestData.fixtureRoot, 'frozenRelease'), ...
    'uiCatalogFrozen', 'classify');
addpath(fileparts(selected), '-begin');
rehash;
pathBefore = path;
[rows, items, diagnostics] = detecdiv_modules_ui('Root', tc.TestData.root, ...
    'PluginRoots', {registeredRoot}, 'PackagePaths', {});
verifyEqual(tc, size(rows, 1), 2, 'The actually selected installed adapter must remain visible.');
verifyTrue(tc, any(arrayfun(@(item) samePath(item.module.path, selected), items)));
verifyTrue(tc, any(arrayfun(@(item) samePath(item.module.path, registered), items)));
verifyFalse(tc, any([items.canAdd]), 'Discovery must not silently choose between duplicate packages.');
verifyTrue(tc, any(strcmp({diagnostics.code}, 'DUPLICATE_PACKAGE')));
verifyEqual(tc, path, pathBefore);
verifyEqual(tc, which('uiCatalogFrozen.classify'), fullfile(selected, 'classify.m'));
verifyNoEvaluation(tc, {registered, selected});
end

function testActiveRescanCanBeDisabledForDeterministicLibraries(tc)
registeredRoot = fullfile(tc.TestData.fixtureRoot, 'registered');
registered = makeDeclaredPackage(fullfile(registeredRoot, 'plugins', 'classifier'), ...
    'uiCatalogNoRescan', 'test.uiNoRescan', 'Registered adapter', 'classifier');
selected = makePackage(fullfile(tc.TestData.fixtureRoot, 'frozenRelease'), ...
    'uiCatalogNoRescan', 'classify');
addpath(fileparts(selected), '-begin');
rehash;
[rows, items, diagnostics] = listFixture(tc, 'PluginRoots', {registeredRoot});
verifyEqual(tc, size(rows, 1), 1);
verifyTrue(tc, samePath(items.module.path, registered));
verifyFalse(tc, items.canAdd);
verifyEqual(tc, items.module.status, 'conflict');
verifyTrue(tc, any(strcmp({diagnostics.code}, 'ENTRYPOINT_SHADOWED')));
verifyNoEvaluation(tc, {registered, selected});
end

function testExplicitActivePackageIsNotDuplicatedByRescan(tc)
package = makeDeclaredPackage(fullfile(tc.TestData.fixtureRoot, 'explicit'), ...
    'uiCatalogExplicit', 'test.uiExplicit', 'External adapter', 'classifier');
addpath(fileparts(package), '-begin');
rehash;
[rows, items, diagnostics] = detecdiv_modules_ui('Root', tc.TestData.root, ...
    'PluginRoots', {}, 'PackagePaths', {package});
verifyNoErrors(tc, diagnostics);
verifyEqual(tc, size(rows, 1), 1);
verifyTrue(tc, items.canAdd);
verifyEqual(tc, items.module.distribution, 'external');
verifyNoEvaluation(tc, {package});
end

function testLegacyRoiIdentifyAliasKeepsRawPackageIdentity(tc)
package = makePackage(fullfile(tc.TestData.root, 'engine', 'dataloading'), ...
    'roiIdentify', 'process');
addpath(fileparts(package), '-begin');
rehash;
[rows, items, diagnostics] = listFixture(tc);
verifyNoErrors(tc, diagnostics);
verifyEqual(tc, size(rows, 1), 1);
verifyEqual(tc, rows{1, 2}, 'roiPattern', ...
    'The editor must preserve its established ROI-definition alias.');
verifyEqual(tc, rows{1, 3}, 'roiIdentify');
verifyEqual(tc, items.module.type, 'roiIdentify', ...
    'Presentation aliases must not rewrite raw catalogue metadata.');
verifyEqual(tc, items.module.pkg, 'roiIdentify');
verifyEqual(tc, items.module.entrypoint, 'roiIdentify.process');
verifyTrue(tc, items.canAdd);
verifyNoEvaluation(tc, {package});
end

function testRefreshDisablesMetadataSelectedFromAnotherPackageCopy(tc)
package = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'uiCatalogMixedMetadata', 'test.uiMixedMetadata', 'Metadata provenance fixture', 'classifier');
addpath(fileparts(package), '-begin');
rehash;
[~, initial] = listFixture(tc);
verifyTrue(tc, initial.canAdd);

partialPackage = fullfile(tc.TestData.fixtureRoot, 'partial', '+uiCatalogMixedMetadata');
mkdir(partialPackage);
marker = strrep(fullfile(partialPackage, 'evaluated.txt'), '''', '''''');
source = sprintf(['function varargout=executionSpec(varargin)\n' ...
    'fid=fopen(''%s'',''w''); fclose(fid);\n' ...
    'error(''testModulesUi:ModuleEvaluated'',''Library evaluated shadowed metadata.'');\nend\n'], marker);
writeText(fullfile(partialPackage, 'executionSpec.m'), source);
addpath(fileparts(partialPackage), '-begin');
rehash;
pathBefore = path;
[~, refreshed] = listFixture(tc);
verifyFalse(tc, refreshed.canAdd, ...
    'A refreshed catalogue cannot configure one executable from another copy''s metadata.');
verifyNotEmpty(tc, refreshed.reason);
verifyEqual(tc, path, pathBefore);
verifyNoEvaluation(tc, {package, partialPackage});
end

function [rows, items, diagnostics] = listFixture(tc, varargin)
args = {'Root', tc.TestData.root, 'IncludeActivePackages', false};
keys = varargin(1:2:end);
if ~any(strcmpi(keys, 'PluginRoots')), args = [args {'PluginRoots', {}}]; end
if ~any(strcmpi(keys, 'PackagePaths')), args = [args {'PackagePaths', {}}]; end
[rows, items, diagnostics] = detecdiv_modules_ui(args{:}, varargin{:});
end

function [packages, pluginRoot] = makePilots(tc)
parent = fullfile(tc.TestData.root, 'engine', 'classification');
packages = cell(1, 3);
packages{1} = makeDeclaredPackage(parent, 'uiCatalogSam', ...
    'test.uiCellposeSAM', 'CellposeSAM', 'classifier');
packages{2} = makeDeclaredPackage(parent, 'uiCatalogLatent', ...
    'test.uiCellLatentModel', 'CellLatentModel', 'classifier');
pluginRoot = fullfile(tc.TestData.fixtureRoot, 'hoct');
packages{3} = makeDeclaredPackage(fullfile(pluginRoot, 'plugins', 'classifier'), ...
    'uiCatalogHoct', 'test.uiHOCT', 'HOCT', 'classifier');
end

function item = selectItem(tc, items, pkg)
selected = arrayfun(@(candidate) strcmp(candidate.module.pkg, pkg), items);
assertEqual(tc, nnz(selected), 1, ['Expected exactly one UI package ' pkg]);
item = items(selected);
end

function verifyNoErrors(tc, diagnostics)
verifyFalse(tc, any(strcmpi({diagnostics.severity}, 'error')), ...
    strjoin({diagnostics.message}, ' | '));
end

function verifyNoEvaluation(tc, packages)
for k = 1:numel(packages)
    verifyFalse(tc, isfile(fullfile(packages{k}, 'evaluated.txt')), ...
        'Library discovery must not call parameter, contract, runtime or execution functions.');
end
end

function tf = samePath(first, second)
first = char(java.io.File(first).getCanonicalPath());
second = char(java.io.File(second).getCanonicalPath());
if ispc, tf = strcmpi(first, second); else, tf = strcmp(first, second); end
end

function packagePath = makeDeclaredPackage(parent, pkg, id, name, type)
execute = 'classify';
if strcmp(type, 'processor'), execute = 'process'; end
packagePath = makePackage(parent, pkg, execute);
descriptor = struct('format', 'detecdiv.module.v1', 'id', id, ...
    'name', name, 'type', type, 'package', pkg, 'adapterVersion', '0.1.0', ...
    'summary', ['Static fixture for ' name], 'capabilities', {{'segmentation'}}, ...
    'entrypoints', struct('execute', [pkg '.' execute], ...
        'parameters', [pkg '.executionSpec'], 'contract', [pkg '.moduleContract'], ...
        'validate', [pkg '.validateModule'], 'prepare', [pkg '.prepareRuntime']), ...
    'compatibility', struct('detecdiv', NaN, ...
        'pipelineContract', 'detecdiv.module_contract.v1', ...
        'runtimeContract', 'detecdiv.module_runtime.v1'), ...
    'provenance', struct('repository', 'https://example.test/catalogue'));
writeText(fullfile(packagePath, 'module.json'), jsonencode(descriptor));
end

function packagePath = makePackage(parent, pkg, execute)
packagePath = fullfile(parent, ['+' pkg]);
mkdir(packagePath);
marker = strrep(fullfile(packagePath, 'evaluated.txt'), '''', '''''');
for functionName = {execute, 'setparam', 'executionSpec', 'moduleContract', ...
        'validateModule', 'prepareRuntime'}
    source = sprintf(['function varargout = %s(varargin)\n' ...
        'fid = fopen(''%s'', ''w''); fclose(fid);\n' ...
        'error(''testModulesUi:ModuleEvaluated'', ''Library evaluated module code.'');\nend\n'], ...
        functionName{1}, marker);
    writeText(fullfile(packagePath, [functionName{1} '.m']), source);
end
end

function writeText(filename, content)
fid = fopen(filename, 'w', 'n', 'UTF-8');
assert(fid >= 0, ['Could not create fixture ' filename]);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', content);
end
