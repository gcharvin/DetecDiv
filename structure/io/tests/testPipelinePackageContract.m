function tests = testPipelinePackageContract
% Package-owned contracts resolve beside the selected executable only.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
tc.TestData.originalPath = path;
addpath(fullfile(tc.TestData.repoRoot, 'helpers'));
addpath(fullfile(tc.TestData.repoRoot, 'structure', 'io'));
end

function teardownOnce(tc)
path(tc.TestData.originalPath);
end

function setup(tc)
tc.TestData.fixtureRoot = tempname;
tc.TestData.fixturePath = path;
tc.TestData.originalFolder = pwd;
mkdir(tc.TestData.fixtureRoot);
end

function teardown(tc)
path(tc.TestData.fixturePath);
cd(tc.TestData.originalFolder);
root = char(java.io.File(tc.TestData.fixtureRoot).getCanonicalPath());
temporaryRoot = char(java.io.File(tempdir).getCanonicalPath());
assert(strcmpi(fileparts(root), temporaryRoot), ...
    'testPipelinePackageContract:UnsafeCleanup', ...
    'Refusing to remove a fixture outside the temporary root.');
if isfolder(root), rmdir(root, 's'); end
end

function testDeclaredGenericPackageOwnsDynamicContract(tc)
pkg = 'contractDynamicProbe';
package = makeModule(tc.TestData.fixtureRoot, pkg, validHook());
addpath(fileparts(package));
before = path;
node = makeNode(pkg, struct('includeProbability', false));
first = pipelineNodeContract(node);
node.params.includeProbability = true;
second = pipelineNodeContract(node);
verifyEqual(tc, {first.out.name}, {'roiList'});
verifyEqual(tc, {second.out.name}, {'roiList','channels'});
verifyEmpty(tc, first.resources.in);
verifyEmpty(tc, first.resources.out);
verifyEqual(tc, {second.resources.out.role}, {'probability'});
verifyEqual(tc, first.parameters.static, {'gain'});
verifyEmpty(tc, first.parameters.template);
verifyEmpty(tc, first.requirements.params.required);
verifyEqual(tc, first.requirements.roi.channelsMin, 0);
verifyEqual(tc, first.binding.exactCount, []);
verifyEqual(tc, first.summary, 'Owned generic metadata');
verifyEqual(tc, first.semantics.inputIdentity, 'none');
verifyEqual(tc, second.semantics.outputIdentity, 'probability');
verifyFalse(tc, first.capabilities.outputsDataSeries);
verifyTrue(tc, second.capabilities.outputsChannels);
verifyEqual(tc, path, before, 'Contract inspection must not modify the path.');
end

function testDeclaredArraysReplaceSavedAndGenericHints(tc)
pkg = 'contractAuthoritativeProbe';
package = makeModule(tc.TestData.fixtureRoot, pkg, validHook());
addpath(fileparts(package));
node = makeNode(pkg, struct('includeProbability', true));
node.inputs = {'roiList','staleImages'};
node.outputs = {'roiList','masks','dataSeries'};
node.contract = struct('out', struct('name', 'staleOutput', ...
    'type', 'maskSet', 'required', true, 'source', 'edge'));
contract = pipelineNodeContract(node);
verifyEqual(tc, {contract.in.name}, {'roiList'});
verifyEqual(tc, {contract.out.name}, {'roiList','channels'});
verifyEqual(tc, {contract.resources.out.type}, {'channel'});
verifyFalse(tc, contract.capabilities.outputsMasks);
verifyFalse(tc, contract.capabilities.outputsDataSeries);
end

function testHookFailureIsActionableAndDoesNotFallBack(tc)
package = makeModule(tc.TestData.fixtureRoot, 'contractFailureProbe', ...
    sprintf(['function contract=moduleContract(params)\n' ...
    'error(''contractFixture:MetadataFailed'',''Intentional metadata failure'');\nend\n']));
addpath(fileparts(package));
verifyError(tc, @()pipelineNodeContract(makeNode('contractFailureProbe', struct())), ...
    'pipelineNodeContract:ModuleContractFailed');
end

function testMalformedHookResultDoesNotFallBack(tc)
package = makeModule(tc.TestData.fixtureRoot, 'contractMalformedProbe', ...
    sprintf('function contract=moduleContract(params)\ncontract=struct(''summary'',''Incomplete'');\nend\n'));
addpath(fileparts(package));
verifyError(tc, @()pipelineNodeContract(makeNode('contractMalformedProbe', struct())), ...
    'pipelineNodeContract:InvalidModuleContract');
end

function testMissingDeclaredHookIsReported(tc)
package = makeModule(tc.TestData.fixtureRoot, 'contractMissingProbe', '');
addpath(fileparts(package));
verifyError(tc, @()pipelineNodeContract(makeNode('contractMissingProbe', struct())), ...
    'pipelineNodeContract:ModuleContractMissing');
end

function testHookFromDifferentInstallationIsRejected(tc)
pkg = 'contractShadowedProbe';
selected = makeModule(fullfile(tc.TestData.fixtureRoot, 'selected'), pkg, '');
other = makeModule(fullfile(tc.TestData.fixtureRoot, 'other'), pkg, validHook());
addpath(fileparts(other));
addpath(fileparts(selected));
assertEqual(tc, canonical(which([pkg '.classify'])), canonical(fullfile(selected, 'classify.m')));
assertEqual(tc, canonical(which([pkg '.moduleContract'])), canonical(fullfile(other, 'moduleContract.m')));
before = path;
verifyError(tc, @()pipelineNodeContract(makeNode(pkg, struct())), ...
    'pipelineNodeContract:ModuleContractShadowed');
verifyEqual(tc, path, before);
end

function testLowercaseWindowsPackageAliasUsesCanonicalDeclaration(tc)
assumeTrue(tc, ispc, 'MATLAB package aliases are case-sensitive on other platforms.');
pkg = 'contractWindowsAliasProbe';
package = makeModule(tc.TestData.fixtureRoot, pkg, validHook());
addpath(fileparts(package));
node = makeNode(lower(pkg), struct('includeProbability', true));
resolved = which([node.pkg '.classify']);
before = path;
contract = pipelineNodeContract(node);
if ~isempty(resolved)
    assertEqual(tc, canonical(resolved), canonical(fullfile(package, 'classify.m')));
    verifyEqual(tc, {contract.out.name}, {'roiList','channels'});
    verifyEqual(tc, contract.summary, 'Owned generic metadata');
else
    % Windows filesystem lookup does not guarantee MATLAB package lookup is
    % case-insensitive. Preserve its normal unresolved-package behavior.
    generic = pipelineNodeContract(struct('type', 'classifier', ...
        'pkg', '', 'params', node.params));
    verifyEqual(tc, contract, generic);
    verifyFalse(tc, isfield(contract, 'semantics'));
end
verifyEqual(tc, path, before);
end

function testIncompatibleAndMissingCompatibilityMarkersAreRejected(tc)
pkg = 'contractVersionProbe';
package = makeModule(tc.TestData.fixtureRoot, pkg, validHook());
addpath(fileparts(package));
manifestPath = fullfile(package, 'module.json');
manifest = jsondecode(fileread(manifestPath));
manifest.compatibility.pipelineContract = 'detecdiv.module_contract.v999';
writeText(manifestPath, jsonencode(manifest));
verifyError(tc, @()pipelineNodeContract(makeNode(pkg, struct())), ...
    'pipelineNodeContract:UnsupportedModuleContract');
manifest.compatibility = rmfield(manifest.compatibility, 'pipelineContract');
writeText(manifestPath, jsonencode(manifest));
verifyError(tc, @()pipelineNodeContract(makeNode(pkg, struct())), ...
    'pipelineNodeContract:UnsupportedModuleContract');
manifest.compatibility.pipelineContract = 'legacy';
writeText(manifestPath, jsonencode(manifest));
verifyError(tc, @()pipelineNodeContract(makeNode(pkg, struct())), ...
    'pipelineNodeContract:UnsupportedModuleContract');
end

function testV1MarkerRequiresContractEntrypoint(tc)
pkg = 'contractNoDeclarationProbe';
package = makeModule(tc.TestData.fixtureRoot, pkg, validHook());
addpath(fileparts(package));
manifestPath = fullfile(package, 'module.json');
manifest = jsondecode(fileread(manifestPath));
manifest.entrypoints = rmfield(manifest.entrypoints, 'contract');
writeText(manifestPath, jsonencode(manifest));
verifyError(tc, @()pipelineNodeContract(makeNode(pkg, struct())), ...
    'pipelineNodeContract:InvalidModuleContract');
end

function testParameterMetadataFromDifferentInstallationIsRejected(tc)
pkg = 'contractMetadataShadowProbe';
selected = makeModule(fullfile(tc.TestData.fixtureRoot, 'selected'), pkg, validHook());
other = makeModule(fullfile(tc.TestData.fixtureRoot, 'other'), pkg, validHook());
delete(fullfile(selected, 'executionSpec.m'));
addpath(fileparts(other));
addpath(fileparts(selected));
assertEqual(tc, canonical(which([pkg '.classify'])), canonical(fullfile(selected, 'classify.m')));
assertEqual(tc, canonical(which([pkg '.moduleContract'])), canonical(fullfile(selected, 'moduleContract.m')));
assertEqual(tc, canonical(which([pkg '.executionSpec'])), canonical(fullfile(other, 'executionSpec.m')));
before = path;
verifyError(tc, @()pipelineNodeContract(makeNode(pkg, struct())), ...
    'pipelineNodeContract:ModuleMetadataShadowed');
verifyEqual(tc, path, before);
end

function testMissingDeclaredParameterMetadataIsRejected(tc)
pkg = 'contractMetadataMissingProbe';
package = makeModule(tc.TestData.fixtureRoot, pkg, validHook());
delete(fullfile(package, 'executionSpec.m'));
addpath(fileparts(package));
verifyError(tc, @()pipelineNodeContract(makeNode(pkg, struct())), ...
    'pipelineNodeContract:ModuleMetadataMissing');
end

function testDeclarationCannotChangeSelectedPackageIdentity(tc)
for scenario=1:4
    pkg=sprintf('contractIdentityProbe%d',scenario);
    package=makeModule(tc.TestData.fixtureRoot,pkg,validHook());
    addpath(fileparts(package));
    manifestPath=fullfile(package,'module.json');
    manifest=jsondecode(fileread(manifestPath));
    switch scenario
        case 1, manifest.package='anotherPackage';
        case 2, manifest.entrypoints.execute='anotherPackage.classify';
        case 3, manifest.entrypoints.parameters=42;
        case 4, manifest.type='processor';
    end
    writeText(manifestPath,jsonencode(manifest));
    verifyError(tc,@()pipelineNodeContract(makeNode(pkg,struct())), ...
        'pipelineNodeContract:InvalidModuleDescriptor');
end
end

function testOlderSelectedReleaseDoesNotUseNewerDeclaration(tc)
pkg = 'contractLegacyReleaseProbe';
selected = makeModule(fullfile(tc.TestData.fixtureRoot, 'selected'), pkg, '');
delete(fullfile(selected, 'module.json'));
% The legacy executionSpec is the metadata of the selected release.
writeText(fullfile(selected, 'executionSpec.m'), sprintf([ ...
    'function spec=executionSpec()\n' ...
    'spec=struct(''summary'',''Selected historical release'');\nend\n']));
other = makeModule(fullfile(tc.TestData.fixtureRoot, 'other'), pkg, ...
    sprintf(['function contract=moduleContract(params)\n' ...
    'error(''contractFixture:WrongRelease'',''New source metadata was invoked'');\nend\n']));
addpath(fileparts(other));
addpath(fileparts(selected));
assertEqual(tc, canonical(which([pkg '.classify'])), canonical(fullfile(selected, 'classify.m')));
assertEqual(tc, canonical(which([pkg '.moduleContract'])), canonical(fullfile(other, 'moduleContract.m')));
before = path;
contract = pipelineNodeContract(makeNode(pkg, struct()));
verifyEqual(tc, contract.summary, 'Selected historical release');
verifyEqual(tc, {contract.out.name}, {'roiList','dataSeries'});
verifyFalse(tc, isfield(contract, 'semantics'));
verifyEqual(tc, path, before);
end

function testDiscoveryAcceptsDeclarationWithoutEvaluatingHook(tc)
pkg = 'contractDiscoveryProbe';
root = fullfile(tc.TestData.fixtureRoot, 'repo');
package = makeModule(fullfile(root, 'engine', 'classification'), pkg, ...
    sprintf(['function contract=moduleContract(params)\n' ...
    'error(''contractFixture:DiscoveryExecutedHook'',''Hook must remain unevaluated'');\nend\n']));
addpath(fileparts(package));
before = path;
[modules, diagnostics] = detecdiv_modules_list('Root', root, 'PluginRoots', {});
verifyEqual(tc, numel(modules), 1);
verifyEqual(tc, modules.status, 'ok', strjoin(modules.issues, ' | '));
verifyEqual(tc, modules.entrypoints.contract, [pkg '.moduleContract']);
verifyEqual(tc, modules.compatibility.pipelineContract, 'detecdiv.module_contract.v1');
verifyFalse(tc, any(strcmpi({diagnostics.severity}, 'error')));
verifyEqual(tc, path, before);
end

function testCatalogueEnforcesContractAndCompatibilityTogether(tc)
root = fullfile(tc.TestData.fixtureRoot, 'repo');
parent = fullfile(root, 'engine', 'classification');
missing = makeModule(parent, 'contractCatalogueMissingProbe', validHook());
legacy = makeModule(parent, 'contractCatalogueLegacyProbe', validHook());
manifestPath = fullfile(missing, 'module.json');
manifest = jsondecode(fileread(manifestPath));
manifest.entrypoints = rmfield(manifest.entrypoints, 'contract');
writeText(manifestPath, jsonencode(manifest));
manifestPath = fullfile(legacy, 'module.json');
manifest = jsondecode(fileread(manifestPath));
manifest.compatibility.pipelineContract = 'legacy';
writeText(manifestPath, jsonencode(manifest));
before = path;
[modules, diagnostics] = detecdiv_modules_list('Root', root, 'PluginRoots', {});
verifyEqual(tc, numel(modules), 2);
verifyEqual(tc, {modules.status}, {'invalid','invalid'});
verifyTrue(tc, all(arrayfun(@(m) ~isempty(m.issues), modules)));
invalid = strcmp({diagnostics.code}, 'INVALID_DESCRIPTOR');
verifyEqual(tc, nnz(invalid), 2);
verifyTrue(tc, all(strcmpi({diagnostics(invalid).severity}, 'error')));
verifyEqual(tc, path, before);
end

function node = makeNode(pkg, params)
node = struct('type', 'classifier', 'pkg', pkg, ...
    'func', [pkg '.classify'], 'params', params);
end

function package = makeModule(parent, pkg, hook)
package = fullfile(parent, ['+' pkg]);
mkdir(package);
manifest = struct('format', 'detecdiv.module.v1', ...
    'id', ['test.' pkg], 'name', pkg, 'type', 'classifier', ...
    'package', pkg, 'adapterVersion', '0.1.0', ...
    'summary', 'Generic package-owned metadata fixture', ...
    'capabilities', {{'probability-mapping'}}, ...
    'entrypoints', struct('execute', [pkg '.classify'], ...
        'parameters', [pkg '.executionSpec'], 'contract', [pkg '.moduleContract']), ...
    'compatibility', struct('detecdiv', '*', ...
        'pipelineContract', 'detecdiv.module_contract.v1'), ...
    'provenance', struct('repository', 'https://example.test/contract-fixture'));
writeText(fullfile(package, 'module.json'), jsonencode(manifest));
for method = {'classify','executionSpec','setparam'}
    writeText(fullfile(package, [method{1} '.m']), sprintf([ ...
        'function out=%s(varargin)\n' ...
        'error(''contractFixture:UnexpectedExecution'',''Only moduleContract may be evaluated'');\nend\n'], method{1}));
end
if ~isempty(hook), writeText(fullfile(package, 'moduleContract.m'), hook); end
end

function source = validHook()
lines = {
    'function contract=moduleContract(params)'
    'contract=struct();'
    'contract.format=''detecdiv.module_contract.v1'';'
    'contract.in=struct(''name'',''roiList'',''type'',''roiList'',''required'',true,''source'',''edge'');'
    'contract.out=contract.in;'
    'emptyResources=struct(''type'',{},''role'',{},''symbol'',{},''param'',{},''port'',{},''nameParam'',{},''required'',{},''transfer'',{});'
    'contract.resources=struct();'
    'contract.resources.in=emptyResources;'
    'contract.resources.out=emptyResources;'
    'contract.parameters=struct(''static'',{{''gain''}},''template'',{{}});'
    'contract.requirements=struct(''roi'',struct(''channelsMin'',0),''params'',struct(''required'',{{}}));'
    'contract.capabilities=struct(''outputsMasks'',false,''roiMasks'',false,''outputsDataSeries'',false,''roiDataSeries'',false);'
    'contract.selectors=struct(''channelParam'','''',''channelsParam'','''');'
    'contract.binding=struct(''mode'',''none'',''selectorKeys'',{{}},''minCount'',0,''exactCount'',[]);'
    'contract.summary=''Owned generic metadata'';'
    'contract.semantics=struct(''inputIdentity'',''none'',''outputIdentity'',''none'');'
    'if isfield(params,''includeProbability'') && params.includeProbability'
    '    contract.out(end+1)=struct(''name'',''channels'',''type'',''channelSet'',''required'',false,''source'',''edge'');'
    '    contract.resources.out=struct(''type'',''channel'',''role'',''probability'',''symbol'',''test_probability'',''param'',''outputName'',''port'',''channels'',''nameParam'',''outputName'',''required'',false,''transfer'',''roiChannel'');'
    '    contract.semantics.outputIdentity=''probability'';'
    'end'
    'end'
    };
source = strjoin(lines, newline);
end

function resolved = canonical(filename)
resolved = char(java.io.File(filename).getCanonicalPath());
if ispc, resolved = lower(resolved); end
end

function writeText(filename, contents)
fid = fopen(filename, 'w');
assert(fid >= 0, 'Cannot create contract fixture.');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', contents);
end
