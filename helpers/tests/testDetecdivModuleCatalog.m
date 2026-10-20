function tests = testDetecdivModuleCatalog
% Discovery must remain metadata-only and preserve invalid/conflicting rows.
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
tc.TestData.originalFolder = pwd;
mkdir(tc.TestData.fixtureRoot);
tc.TestData.root = fullfile(tc.TestData.fixtureRoot, 'repo');
mkdir(fullfile(tc.TestData.root, 'engine', 'classification'));
mkdir(fullfile(tc.TestData.root, 'engine', 'processor'));
end

function teardown(tc)
cd(tc.TestData.originalFolder);
if isfolder(tc.TestData.fixtureRoot)
    folder = char(java.io.File(tc.TestData.fixtureRoot).getCanonicalPath());
    safeRoot = char(java.io.File(tempdir).getCanonicalPath());
    assert(startsWith(folder, [safeRoot filesep], 'IgnoreCase', true), ...
        'testModuleCatalog:UnsafeCleanup', 'Fixture cleanup escaped the temporary root.');
    rmdir(folder, 's');
end
end

function testBundledExternalAndExplicitPackagesShareOneCatalog(tc)
bundled = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', ...
    'classification'), 'catalogSam', 'test.CellposeSAM', 'classifier');
pluginRoot = fullfile(tc.TestData.fixtureRoot, 'hoct');
external = makeDeclaredPackage(fullfile(pluginRoot, 'plugins', ...
    'classifier'), 'catalogHoct', 'test.HOCT', 'classifier');
explicit = makeDeclaredPackage(fullfile(tc.TestData.fixtureRoot, ...
    'linked'), 'catalogLatent', 'test.CellLatentModel', 'classifier');

pathBefore = path;
[modules, diagnostics] = detecdiv_modules_list('Root', tc.TestData.root, ...
    'PluginRoots', {pluginRoot}, 'PackagePaths', {explicit});

verifyEqual(tc, numel(modules), 3);
verifyEqual(tc, path, pathBefore, 'Discovery must not modify the MATLAB path.');
verifyNoErrors(tc, diagnostics);
sam = selectPackage(tc, modules, 'catalogSam');
hoct = selectPackage(tc, modules, 'catalogHoct');
latent = selectPackage(tc, modules, 'catalogLatent');
verifyEqual(tc, sam.id, 'test.CellposeSAM', 'Stable IDs retain their case.');
verifyEqual(tc, sam.distribution, 'bundled');
verifyEqual(tc, hoct.distribution, 'external');
verifyEqual(tc, latent.distribution, 'external');
verifyEqual(tc, sam.entrypoint, 'catalogSam.classify');
verifyEqual(tc, sam.entrypoints.parameters, 'catalogSam.executionSpec');
verifyEqual(tc, sam.adapterVersion, '0.1.0');
verifyEqual(tc, sam.compatibility.pipelineContract, 'legacy');
verifyEqual(tc, sam.provenance.repository, 'https://example.test/repo');
verifyEqual(tc, sam.capabilities(:), {'segmentation'; 'probability-mapping'});
verifyEqual(tc, {modules.descriptorStatus}, {'declared', 'declared', 'declared'});
verifyEqual(tc, {modules.status}, {'ok', 'ok', 'ok'});
verifyFalse(tc, any([modules.onPath]));
for packagePath = {bundled, external, explicit}
    verifyFalse(tc, isfile(fullfile(packagePath{1}, 'evaluated.txt')), ...
        'Discovery must not execute a module or its parameter provider.');
end
end

function testDeclaredProcessorUsesSameDescriptor(tc)
makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', 'processor'), ...
    'catalogMetrics', 'test.metrics', 'processor');
[modules, diagnostics] = listFixture(tc);
verifyNoErrors(tc, diagnostics);
verifyEqual(tc, numel(modules), 1);
verifyEqual(tc, modules.type, 'processor');
verifyEqual(tc, modules.entrypoint, 'catalogMetrics.process');
verifyEqual(tc, modules.status, 'ok');
end

function testNamespacedExtensionsPreserveModuleMetadata(tc)
packagePath=makeDeclaredPackage(fullfile(tc.TestData.root,'engine','classification'), ...
    'catalogExtensionProbe','test.extensions','classifier');
filename=fullfile(packagePath,'module.json');
manifest=jsondecode(fileread(filename));
manifest.compatibility.detecdiv=NaN;
extension=struct('divisionModes',{{'budding','binary_fission'}},'defaultDivisionMode','budding');
manifest.extensions=struct('hoctModel',extension);
writeText(filename,jsonencode(manifest));
[modules,diagnostics]=listFixture(tc);
verifyNoErrors(tc,diagnostics);
verifyEqual(tc,modules.extensions.hoctModel.defaultDivisionMode,'budding');
verifyEqual(tc,modules.extensions.hoctModel.divisionModes(:),{'budding';'binary_fission'});
verifyEqual(tc,modules.extensions,modules.manifest.extensions);
manifest.extensions.hoctModel=42;
writeText(filename,jsonencode(manifest));
[modules,diagnostics]=listFixture(tc);
verifyEqual(tc,modules.status,'invalid');
verifyHasErrorForPath(tc,diagnostics,packagePath);
end

function testNullAdapterVersionRemainsUnknown(tc)
packagePath = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', ...
    'classification'), 'catalogUnversioned', 'test.unversioned', 'classifier');
descriptor = jsondecode(fileread(fullfile(packagePath, 'module.json')));
descriptor.adapterVersion = NaN; % jsonencode writes JSON null.
descriptor.compatibility.detecdiv = NaN;
writeText(fullfile(packagePath, 'module.json'), jsonencode(descriptor));
[modules, diagnostics] = listFixture(tc);
verifyNoErrors(tc, diagnostics);
verifyEqual(tc, modules.adapterVersion, '');
verifyEqual(tc, modules.status, 'ok');
end

function testMalformedAndIncompleteDescriptorsRemainVisible(tc)
brokenJson = makePackage(fullfile(tc.TestData.root, 'engine', ...
    'classification'), 'catalogBrokenJson', 'classify');
writeText(fullfile(brokenJson, 'module.json'), '{ "format": ');
incomplete = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', ...
    'classification'), 'catalogIncomplete', 'test.incomplete', 'classifier');
descriptor = jsondecode(fileread(fullfile(incomplete, 'module.json')));
descriptor = rmfield(descriptor, 'id');
writeText(fullfile(incomplete, 'module.json'), jsonencode(descriptor));

[modules, diagnostics] = listFixture(tc);
verifyEqual(tc, numel(modules), 2);
verifyEqual(tc, {modules.descriptorStatus}, {'invalid', 'invalid'});
verifyEqual(tc, {modules.status}, {'invalid', 'invalid'});
verifyTrue(tc, all(arrayfun(@(m) ~isempty(m.issues), modules)));
verifyHasErrorForPath(tc, diagnostics, brokenJson);
verifyHasErrorForPath(tc, diagnostics, incomplete);
end

function testUnknownDescriptorFormatIsRejected(tc)
packagePath = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', ...
    'classification'), 'catalogFuture', 'test.future', 'classifier');
descriptor = jsondecode(fileread(fullfile(packagePath, 'module.json')));
descriptor.format = 'detecdiv.module.v999';
writeText(fullfile(packagePath, 'module.json'), jsonencode(descriptor));
[modules, diagnostics] = listFixture(tc);
verifyEqual(tc, numel(modules), 1);
verifyEqual(tc, modules.status, 'invalid');
verifyHasErrorForPath(tc, diagnostics, packagePath);
end

function testRawJsonTypesAndKeysCannotBypassDescriptorSchema(tc)
% jsondecode collapses null/[] and normalizes object keys. Validate the
% original JSON shape too, before those transformations lose information.
cases = { ...
    'null capabilities', ...
        '"capabilities":["segmentation","probability-mapping"]', '"capabilities":null'; ...
    'array adapter version', '"adapterVersion":"0.1.0"', '"adapterVersion":[]'; ...
    'array DetecDiv constraint', '"detecdiv":null', '"detecdiv":[]'; ...
    'numeric capabilities', ...
        '"capabilities":["segmentation","probability-mapping"]', '"capabilities":[1,2]'; ...
    'normalized object key', '"id":', '"id ":'; ...
    'duplicate object key', '"id":', '"id":"test.duplicate","id":' ...
    };
packagePaths = cell(1, size(cases, 1));
for k = 1:size(cases, 1)
    packagePaths{k} = makeDeclaredPackage(fullfile(tc.TestData.root, ...
        'engine', 'classification'), sprintf('catalogRawShape%d', k), ...
        sprintf('test.raw%d', k), 'classifier');
    manifestPath = fullfile(packagePaths{k}, 'module.json');
    original = fileread(manifestPath);
    malformed = strrep(original, cases{k, 2}, cases{k, 3});
    assertNotEqual(tc, malformed, original, ...
        ['Fixture did not replace JSON token for ' cases{k, 1}]);
    writeText(manifestPath, malformed);
end
[modules, diagnostics] = listFixture(tc);
verifyEqual(tc, numel(modules), size(cases, 1), ...
    'Invalid JSON metadata must remain visible as catalogue rows.');
for k = 1:size(cases, 1)
    module = selectPackage(tc, modules, sprintf('catalogRawShape%d', k));
    verifyEqual(tc, module.status, 'invalid', cases{k, 1});
    verifyEqual(tc, module.descriptorStatus, 'invalid', cases{k, 1});
    verifyHasErrorForPath(tc, diagnostics, packagePaths{k});
end
end

function testLegacyPackagesAndPluginManifestStayDiscoverable(tc)
makePackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'catalogLegacyClassifier', 'classify');
makePackage(fullfile(tc.TestData.root, 'engine', 'processor'), ...
    'catalogLegacyProcessor', 'process');
pluginRoot = fullfile(tc.TestData.fixtureRoot, 'legacyHoct');
packagePath = makePackage(fullfile(pluginRoot, 'plugins', 'classifier'), ...
    'catalogLegacyPlugin', 'classify');
legacy = struct('name', 'catalogLegacyPlugin', 'version', '0.2.4', ...
    'summary', 'Historical HOCT plugin metadata', ...
    'entrypoint', 'catalogLegacyPlugin.classify');
writeText(fullfile(packagePath, 'plugin.json'), jsonencode(legacy));

[modules, diagnostics] = detecdiv_modules_list('Root', tc.TestData.root, ...
    'PluginRoots', {pluginRoot}, 'PackagePaths', {});
verifyNoErrors(tc, diagnostics);
verifyEqual(tc, numel(modules), 3);
verifyEqual(tc, {modules.descriptorStatus}, {'legacy', 'legacy', 'legacy'});
verifyEqual(tc, {modules.status}, {'ok', 'ok', 'ok'});
verifyTrue(tc, all(arrayfun(@(m) ~isempty(m.id), modules)));
plugin = selectPackage(tc, modules, 'catalogLegacyPlugin');
verifyEqual(tc, plugin.summary, legacy.summary);
verifyEqual(tc, plugin.manifest.version, '0.2.4');
verifyEqual(tc, plugin.entrypoint, legacy.entrypoint);
end

function testMalformedLegacyPluginIsReported(tc)
pluginRoot = fullfile(tc.TestData.fixtureRoot, 'brokenPlugin');
packagePath = makePackage(fullfile(pluginRoot, 'plugins', 'classifier'), ...
    'catalogBrokenPlugin', 'classify');
writeText(fullfile(packagePath, 'plugin.json'), '{broken json');
[modules, diagnostics] = detecdiv_modules_list('Root', tc.TestData.root, ...
    'PluginRoots', {pluginRoot}, 'PackagePaths', {});
verifyEqual(tc, numel(modules), 1);
verifyEqual(tc, modules.status, 'invalid');
verifyNotEmpty(tc, modules.issues);
verifyHasErrorForPath(tc, diagnostics, packagePath);
end

function testUtf8BomAndUnicodeManifestsRemainReadable(tc)
declared = makeDeclaredPackage(fullfile(tc.TestData.root,'engine','classification'), ...
    'catalogUtf8','test.utf8','classifier');
legacy = makePackage(fullfile(tc.TestData.root,'engine','processor'), ...
    'catalogLegacyUtf8','process');
writeText(fullfile(legacy,'plugin.json'), ...
    jsonencode(struct('name','Legacy UTF-8','summary','Legacy descriptor')));
for filename={fullfile(declared,'module.json'),fullfile(legacy,'plugin.json')}
    contents=jsondecode(fileread(filename{1}));
    contents.summary=['Microscopie ' char(233)];
    if isfield(contents,'compatibility'), contents.compatibility.detecdiv=NaN; end
    encoded=unicode2native(jsonencode(contents),'UTF-8');
    fid=fopen(filename{1},'wb');
    assert(fid>=0);
    cleanup=onCleanup(@()fclose(fid));
    fwrite(fid,[uint8([239 187 191]) encoded],'uint8');
    clear cleanup;
end
[modules,diagnostics]=listFixture(tc);
verifyNoErrors(tc,diagnostics);
verifyEqual(tc,numel(modules),2);
verifyEqual(tc,{modules.status},{'ok','ok'});
verifyEqual(tc,{modules.summary},{['Microscopie ' char(233)],['Microscopie ' char(233)]});
end

function testDuplicateStableIdsPreserveEveryCandidate(tc)
makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'catalogFirst', 'test.shared', 'classifier');
pluginRoot = fullfile(tc.TestData.fixtureRoot, 'duplicateId');
makeDeclaredPackage(fullfile(pluginRoot, 'plugins', 'classifier'), ...
    'catalogSecond', 'test.shared', 'classifier');
[modules, diagnostics] = detecdiv_modules_list('Root', tc.TestData.root, ...
    'PluginRoots', {pluginRoot}, 'PackagePaths', {});
verifyEqual(tc, numel(modules), 2);
verifyEqual(tc, {modules.id}, {'test.shared', 'test.shared'});
verifyEqual(tc, {modules.status}, {'conflict', 'conflict'});
verifyTrue(tc, all(arrayfun(@(m) ~isempty(m.issues), modules)));
verifyTrue(tc, any(strcmpi({diagnostics.severity}, 'error')));
end

function testSameMatlabPackageAtDifferentPathsIsAConflict(tc)
makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'catalogShadowed', 'test.bundled', 'classifier');
pluginRoot = fullfile(tc.TestData.fixtureRoot, 'shadowedPackage');
makeDeclaredPackage(fullfile(pluginRoot, 'plugins', 'classifier'), ...
    'catalogShadowed', 'test.external', 'classifier');
[modules, diagnostics] = detecdiv_modules_list('Root', tc.TestData.root, ...
    'PluginRoots', {pluginRoot}, 'PackagePaths', {});
verifyEqual(tc, numel(modules), 2);
verifyEqual(tc, {modules.pkg}, {'catalogShadowed', 'catalogShadowed'});
verifyEqual(tc, {modules.status}, {'conflict', 'conflict'});
verifyTrue(tc, any(strcmpi({diagnostics.severity}, 'error')));
end

function testCanonicalRepeatedPathsAreDeduplicated(tc)
pluginRoot = fullfile(tc.TestData.fixtureRoot, 'repeated');
packagePath = makeDeclaredPackage(fullfile(pluginRoot, 'plugins', ...
    'classifier'), 'catalogOnce', 'test.once', 'classifier');
[modules, diagnostics] = detecdiv_modules_list('Root', tc.TestData.root, ...
    'PluginRoots', {pluginRoot, fullfile(pluginRoot, '.')}, ...
    'PackagePaths', {packagePath, fullfile(packagePath, '.')});
verifyEqual(tc, numel(modules), 1);
verifyEqual(tc, modules.status, 'ok');
verifyNoErrors(tc, diagnostics);
end

function testMissingAndForeignEntrypointsAreInvalid(tc)
missing = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', ...
    'classification'), 'catalogMissing', 'test.missing', 'classifier');
descriptor = jsondecode(fileread(fullfile(missing, 'module.json')));
descriptor.entrypoints.execute = 'catalogMissing.absent';
writeText(fullfile(missing, 'module.json'), jsonencode(descriptor));
foreign = makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', ...
    'classification'), 'catalogForeign', 'test.foreign', 'classifier');
descriptor = jsondecode(fileread(fullfile(foreign, 'module.json')));
descriptor.entrypoints.execute = 'anotherPackage.classify';
writeText(fullfile(foreign, 'module.json'), jsonencode(descriptor));
[modules, diagnostics] = listFixture(tc);
verifyEqual(tc, numel(modules), 2);
verifyEqual(tc, {modules.status}, {'invalid', 'invalid'});
verifyHasErrorForPath(tc, diagnostics, missing);
verifyHasErrorForPath(tc, diagnostics, foreign);
end

function testDefaultRootIsIndependentOfCurrentFolder(tc)
makeDeclaredPackage(fullfile(tc.TestData.root, 'engine', 'classification'), ...
    'catalogCwdTrap', 'test.cwd', 'classifier');
[expected, expectedDiagnostics] = detecdiv_modules_list( ...
    'Root', tc.TestData.repoRoot, 'PluginRoots', {}, 'PackagePaths', {});
cd(tc.TestData.root);
[actual, actualDiagnostics] = detecdiv_modules_list( ...
    'PluginRoots', {}, 'PackagePaths', {});
verifyEqual(tc, {actual.path}, {expected.path});
verifyEqual(tc, {actual.id}, {expected.id});
verifyEqual(tc, actualDiagnostics, expectedDiagnostics);
verifyFalse(tc, any(strcmp({actual.pkg}, 'catalogCwdTrap')));
end

function testInvalidSelectedPathsDoNotFallBackToWorkingFolder(tc)
verifyError(tc, @()detecdiv_modules_list('Root',tc.TestData.root, ...
    'PluginRoots',string('')), 'MATLAB:InputParser:ArgumentFailedValidation');
[modules,diagnostics] = detecdiv_modules_list('Root',tc.TestData.root, ...
    'PluginRoots',{},'PackagePaths',{'+relativePackage'});
verifyEmpty(tc,modules);
verifyTrue(tc,any(strcmp({diagnostics.code},'PACKAGE_PATH_INVALID')));
end

function testBundledPilotDescriptorsAreValidWithoutLoadingModels(tc)
[modules, diagnostics] = detecdiv_modules_list('Root', tc.TestData.repoRoot, ...
    'PluginRoots', {}, 'PackagePaths', {});
for pkg = {'cellposesam', 'cellLatentModel'}
    module = selectPackage(tc, modules, pkg{1});
    verifyEqual(tc, module.descriptorStatus, 'declared');
    verifyEqual(tc, module.status, 'ok', strjoin(module.issues, ' | '));
    verifyEqual(tc, module.distribution, 'bundled');
    verifyEqual(tc, module.entrypoint, [pkg{1} '.classify']);
    verifyTrue(tc, isfile(module.manifestPath));
    matching = strcmp({diagnostics.moduleId}, module.id);
    verifyNoErrors(tc, diagnostics(matching));
end
end

function testHoctDescriptorWhenSiblingRepositoryIsInstalled(tc)
hoctRoot = fullfile(fileparts(tc.TestData.repoRoot), 'hoct_model');
manifest = fullfile(hoctRoot, 'plugins', 'classifier', '+hoctModel', 'module.json');
assumeTrue(tc, isfolder(hoctRoot), 'The separate HOCT checkout is optional.');
verifyTrue(tc, isfile(manifest), 'The installed pilot adapter needs its descriptor.');
[modules, diagnostics] = detecdiv_modules_list('Root', tc.TestData.root, ...
    'PluginRoots', {hoctRoot}, 'PackagePaths', {});
module = selectPackage(tc, modules, 'hoctModel');
verifyEqual(tc, module.descriptorStatus, 'declared');
verifyEqual(tc, module.distribution, 'external');
verifyEqual(tc, module.entrypoint, 'hoctModel.classify');
matching = strcmp({diagnostics.moduleId}, module.id);
moduleDiagnostics = diagnostics(matching);
resolved = which(module.entrypoint);
verifyEqual(tc, module.resolvedEntrypoint, resolved);
if isempty(resolved)
    verifyEqual(tc, module.status, 'ok', strjoin(module.issues, ' | '));
    verifyFalse(tc, module.onPath);
    verifyNoErrors(tc, moduleDiagnostics);
else
    resolvedFolder = char(java.io.File(fileparts(resolved)).getCanonicalPath());
    discoveredFolder = char(java.io.File(module.path).getCanonicalPath());
    if strcmpi(resolvedFolder, discoveredFolder)
        verifyEqual(tc, module.status, 'ok', strjoin(module.issues, ' | '));
        verifyTrue(tc, module.onPath);
        verifyNoErrors(tc, moduleDiagnostics);
    else
        % A frozen installed release can legitimately be earlier on the user's
        % path. The catalogue must report that conflict without changing it.
        verifyEqual(tc, module.status, 'conflict');
        verifyFalse(tc, module.onPath);
        shadowed = strcmp({moduleDiagnostics.code}, 'ENTRYPOINT_SHADOWED');
        verifyTrue(tc, any(shadowed & strcmpi({moduleDiagnostics.severity}, 'error')));
        verifyTrue(tc, any(contains({moduleDiagnostics(shadowed).message}, resolved)));
        verifyNoErrors(tc, moduleDiagnostics(~shadowed));
    end
end
end

function [modules, diagnostics] = listFixture(tc)
[modules, diagnostics] = detecdiv_modules_list('Root', tc.TestData.root, ...
    'PluginRoots', {}, 'PackagePaths', {});
end

function module = selectPackage(tc, modules, pkg)
selected = strcmp({modules.pkg}, pkg);
assertEqual(tc, nnz(selected), 1, ['Expected exactly one package ' pkg]);
module = modules(selected);
end

function verifyNoErrors(tc, diagnostics)
verifyFalse(tc, any(strcmpi({diagnostics.severity}, 'error')), ...
    strjoin({diagnostics.message}, ' | '));
end

function verifyHasErrorForPath(tc, diagnostics, packagePath)
matchesPath = arrayfun(@(d) startsWith(lower(d.path), lower(packagePath)), diagnostics);
verifyTrue(tc, any(matchesPath & strcmpi({diagnostics.severity}, 'error')), ...
    ['Expected an explicit error for ' packagePath]);
end

function packagePath = makeDeclaredPackage(parent, pkg, id, type)
executeName = 'classify';
if strcmp(type, 'processor'), executeName = 'process'; end
packagePath = makePackage(parent, pkg, executeName);
descriptor = struct('format', 'detecdiv.module.v1', 'id', id, ...
    'name', [pkg ' display name'], 'type', type, 'package', pkg, ...
    'adapterVersion', '0.1.0', 'summary', ['Fixture for ' pkg], ...
    'capabilities', {{'segmentation', 'probability-mapping'}}, ...
    'entrypoints', struct('execute', [pkg '.' executeName], ...
        'parameters', [pkg '.executionSpec']), ...
    'compatibility', struct('detecdiv', NaN, 'pipelineContract', 'legacy'), ...
    'provenance', struct('repository', 'https://example.test/repo'));
writeText(fullfile(packagePath, 'module.json'), jsonencode(descriptor));
end

function packagePath = makePackage(parent, pkg, executeName)
packagePath = fullfile(parent, ['+' pkg]);
mkdir(packagePath);
marker = strrep(fullfile(packagePath, 'evaluated.txt'), '''', '''''');
for name = {executeName, 'executionSpec'}
    source = sprintf(['function varargout = %s(varargin)\n' ...
        'fid = fopen(''%s'', ''w''); fclose(fid);\n' ...
        'error(''testModuleCatalog:ModuleEvaluated'', ' ...
        '''Discovery executed fixture code.'');\nend\n'], name{1}, marker);
    writeText(fullfile(packagePath, [name{1} '.m']), source);
end
end

function writeText(filename, text)
fid = fopen(filename, 'w', 'n', 'UTF-8');
assert(fid >= 0, ['Could not create fixture ' filename]);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', text);
end
