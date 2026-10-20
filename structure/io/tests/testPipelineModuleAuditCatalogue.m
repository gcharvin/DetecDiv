function tests = testPipelineModuleAuditCatalogue
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
tc.TestData.originalPath = path;
addpath(fullfile(root, 'helpers'), fullfile(root, 'structure', 'io'));
end

function teardownOnce(tc)
path(tc.TestData.originalPath);
end

function testDefaultAuditDoesNotCallOnPathModuleMetadata(tc)
[root, cleanup] = temporaryRoot(); %#ok<ASGLU>
pkg = makeModule(root, 'auditMetadataProbe', 'detecdiv.audit-metadata-probe');
originalPath = path;
pathCleanup = onCleanup(@()path(originalPath)); %#ok<NASGU>
addpath(fileparts(pkg));
global DETECDIV_AUDIT_METADATA_PROBE
DETECDIV_AUDIT_METADATA_PROBE = 0;
probeCleanup = onCleanup(@clearProbe); %#ok<NASGU>
before = path;
[audit, diagnostics] = pipelineModuleAudit('Root', root, 'PluginRoots', {});
verifyEqual(tc, height(audit), 1);
verifyEqual(tc, audit.ContractStatus, {'NOT_INSPECTED'});
verifyEqual(tc, audit.SetparamStatus, {'NOT_INSPECTED'});
verifyEqual(tc, audit.Summary, {'Metadata-only probe'});
verifyEqual(tc, audit.ModuleId, {'detecdiv.audit-metadata-probe'});
verifyEqual(tc, audit.CatalogueStatus, {'ok'});
verifyEqual(tc, DETECDIV_AUDIT_METADATA_PROBE, 0);
verifyEqual(tc, path, before);
verifyEmpty(tc, diagnostics);
end

function testExternalOffPathDescriptorIsAuditableWithoutPathMutation(tc)
[root, cleanup] = temporaryRoot(); %#ok<ASGLU>
pkg = makeModule(fullfile(root, 'external'), 'auditExternalProbe', 'detecdiv.audit-external');
before = path;
audit = pipelineModuleAudit('Root', root, 'PluginRoots', {}, 'PackagePaths', {pkg});
verifyEqual(tc, height(audit), 1);
verifyEqual(tc, audit.Distribution, {'external'});
verifyEqual(tc, audit.DescriptorStatus, {'declared'});
verifyEqual(tc, audit.ContractStatus, {'NOT_INSPECTED'});
verifyFalse(tc, audit.OnPath(1));
verifyEqual(tc, path, before);
inspected = pipelineModuleAudit('Root', root, 'PluginRoots', {}, ...
    'PackagePaths', {pkg}, 'InspectContracts', true);
verifyEqual(tc, inspected.ContractStatus, {'NOT_ON_PATH'});
verifyEqual(tc, inspected.SetparamStatus, {'NOT_ON_PATH'});
verifyEqual(tc, path, before);
end

function testLegacyColumnsAndLegacyModulesRemainAvailable(tc)
[root, cleanup] = temporaryRoot(); %#ok<ASGLU>
pkg = fullfile(root, 'engine', 'classification', '+auditLegacyProbe');
mkdir(pkg);
writeText(fullfile(pkg, 'classify.m'), sprintf('function out=classify(varargin)\nout=[];\nend\n'));
audit = pipelineModuleAudit('Root', root, 'PluginRoots', {});
expected = {'Type','Package','BindingInputs','BindingOutputs','RuntimeParams', ...
    'StaticParams','SetparamFields','ContractStatus','SetparamStatus','Summary'};
verifyEqual(tc, audit.Properties.VariableNames(1:10), expected);
verifyEqual(tc, audit.Type, {'classifier'});
verifyEqual(tc, audit.Package, {'auditLegacyProbe'});
verifyEqual(tc, audit.DescriptorStatus, {'legacy'});
verifyEqual(tc, audit.ContractStatus, {'NOT_INSPECTED'});
end

function testDefaultRootDoesNotDependOnWorkingDirectory(tc)
[root, cleanup] = temporaryRoot(); %#ok<ASGLU>
before = pipelineModuleAudit('PluginRoots', {});
previous = pwd;
cwdCleanup = onCleanup(@()cd(previous)); %#ok<NASGU>
cd(root);
after = pipelineModuleAudit('PluginRoots', {});
verifyNotEmpty(tc, before);
verifyEqual(tc, after, before);
end

function testInvalidAndConflictingCandidatesAreNeverInspected(tc)
[root, cleanup] = temporaryRoot(); %#ok<ASGLU>
first = makeModule(root, 'auditConflictFirst', 'detecdiv.audit-conflict');
second = makeModule(fullfile(root, 'external'), 'auditConflictSecond', 'detecdiv.audit-conflict');
invalid = makeModule(root, 'auditInvalidProbe', 'detecdiv.audit-invalid');
writeText(fullfile(invalid, 'module.json'), '{ invalid json');
previous = path;
pathCleanup = onCleanup(@()path(previous)); %#ok<NASGU>
addpath(fileparts(first), fileparts(second));
global DETECDIV_AUDIT_METADATA_PROBE
DETECDIV_AUDIT_METADATA_PROBE = 0;
probeCleanup = onCleanup(@clearProbe); %#ok<NASGU>
audit = pipelineModuleAudit('Root', root, 'PluginRoots', {}, ...
    'PackagePaths', {second}, 'InspectContracts', true);
conflicts = strcmp(audit.CatalogueStatus, 'conflict');
bad = strcmp(audit.CatalogueStatus, 'invalid');
verifyEqual(tc, nnz(conflicts), 2);
verifyEqual(tc, nnz(bad), 1);
verifyTrue(tc, all(strcmp(audit.ContractStatus(conflicts), 'SKIPPED_CONFLICT')));
verifyTrue(tc, all(strcmp(audit.SetparamStatus(conflicts), 'SKIPPED_CONFLICT')));
verifyEqual(tc, audit.ContractStatus(bad), {'SKIPPED_INVALID'});
verifyEqual(tc, DETECDIV_AUDIT_METADATA_PROBE, 0);
end

function testInspectionRejectsMetadataFromAnotherPackageDirectory(tc)
[root, cleanup] = temporaryRoot(); %#ok<ASGLU>
first = makeModule(root, 'auditShadowProbe', 'detecdiv.audit-shadow');
second = makeModule(fullfile(root, 'external'), 'auditShadowProbe', 'detecdiv.audit-shadow-external');
% The execution function resolves locally, but executionSpec falls through
% to another installation of the package. Inspecting it would mix versions.
delete(fullfile(first, 'executionSpec.m'));
manifestPath = fullfile(first, 'module.json');
manifest = jsondecode(fileread(manifestPath));
manifest.entrypoints = rmfield(manifest.entrypoints, 'parameters');
writeText(manifestPath, jsonencode(manifest));
previous = path;
pathCleanup = onCleanup(@()path(previous)); %#ok<NASGU>
addpath(fileparts(second));
addpath(fileparts(first));
global DETECDIV_AUDIT_METADATA_PROBE
DETECDIV_AUDIT_METADATA_PROBE = 0;
probeCleanup = onCleanup(@clearProbe); %#ok<NASGU>
audit = pipelineModuleAudit('Root', root, 'PluginRoots', {}, 'InspectContracts', true);
verifyEqual(tc, height(audit), 1);
verifyEqual(tc, audit.ContractStatus, {'SKIPPED_SHADOWED'});
verifyEqual(tc, audit.SetparamStatus, {'SKIPPED_SHADOWED'});
verifyEqual(tc, DETECDIV_AUDIT_METADATA_PROBE, 0);
end

function testExplicitInspectionRetainsLegacyDefaultsInspection(tc)
[root, cleanup] = temporaryRoot(); %#ok<ASGLU>
pkg = makeModule(root, 'auditInspectProbe', 'detecdiv.audit-inspect');
writeText(fullfile(pkg, 'executionSpec.m'), sprintf( ...
    'function spec=executionSpec()\nspec=struct(''summary'',''Inspected contract'');\nend\n'));
writeText(fullfile(pkg, 'setparam.m'), sprintf( ...
    'function p=setparam(varargin)\np=struct(''channel'',''TL'',''threshold'',0.5);\nend\n'));
previous = path;
pathCleanup = onCleanup(@()path(previous)); %#ok<NASGU>
addpath(fileparts(pkg));
audit = pipelineModuleAudit('Root', root, 'PluginRoots', {}, 'InspectContracts', true);
verifyEqual(tc, audit.ContractStatus, {'OK'});
verifyEqual(tc, audit.SetparamStatus, {'OK'});
verifyEqual(tc, audit.SetparamFields, {'channel, threshold'});
verifyEqual(tc, audit.Summary, {'Inspected contract'});
end

function [root, cleanup] = temporaryRoot()
root = tempname;
mkdir(root);
originalPath = path;
originalFolder = pwd;
cleanup = onCleanup(@()cleanupRoot(root, originalPath, originalFolder));
end

function cleanupRoot(root, originalPath, originalFolder)
path(originalPath);
cd(originalFolder);
resolvedRoot = char(java.io.File(root).getCanonicalPath());
resolvedTemp = char(java.io.File(tempdir).getCanonicalPath());
% These fixtures are always direct children of tempdir, never arbitrary
% paths supplied by the catalogue. Verify that boundary before recursion.
assert(strcmpi(fileparts(resolvedRoot), resolvedTemp), ...
    'Refusing to remove an audit fixture outside the temporary directory.');
if isfolder(resolvedRoot)
    rmdir(resolvedRoot, 's');
end
end

function pkg = makeModule(root, name, id)
pkg = fullfile(root, 'engine', 'classification', ['+' name]);
mkdir(pkg);
manifest = struct('format', 'detecdiv.module.v1', 'id', id, 'name', name, ...
    'type', 'classifier', 'package', name, 'adapterVersion', '0.1.0', ...
    'summary', 'Metadata-only probe', 'capabilities', {{'segmentation'}}, ...
    'entrypoints', struct('execute', [name '.classify'], 'parameters', [name '.executionSpec']), ...
    'compatibility', struct('detecdiv', '*', 'pipelineContract', 'legacy'), ...
    'provenance', struct('repository', 'https://example.test/detecdiv-audit-probe'));
writeText(fullfile(pkg, 'module.json'), jsonencode(manifest));
for method = {'classify', 'executionSpec', 'setparam'}
    writeText(fullfile(pkg, [method{1} '.m']), sprintf([ ...
        'function out=%s(varargin)\n' ...
        'global DETECDIV_AUDIT_METADATA_PROBE\n' ...
        'DETECDIV_AUDIT_METADATA_PROBE=DETECDIV_AUDIT_METADATA_PROBE+1;\n' ...
        'error(''testPipelineModuleAudit:Executed'',''Module code was invoked'');\n' ...
        'out=[];\nend\n'], method{1}));
end
end

function writeText(file, text)
fid = fopen(file, 'w');
assert(fid >= 0, 'Cannot create audit test fixture.');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', text);
end

function clearProbe()
clear global DETECDIV_AUDIT_METADATA_PROBE
end
