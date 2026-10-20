function tests = testCellLatentModuleRuntime
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
root = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(fullfile(root,'engine','classification'),fullfile(root,'structure','io'));
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testVerifiedReleaseAndProtectedPipelinePaths(testCase)
[c,paths] = fixture(testCase);
ctx = struct('params',struct('modelPath','untrusted.pt', ...
    'modelUpdatePolicy','pinned','backend','legacy', ...
    'instanceChannelName','pipeline_instances'));
prepared = cellLatentModel.prepareRuntime(c,ctx);
verifyFalse(testCase,any(strcmp({prepared.diagnostics.severity},'error')));
verifyEqual(testCase,prepared.parameters.backend,'causal_composite');
verifyEqual(testCase,prepared.parameters.modelPath,paths.model);
verifyEqual(testCase,prepared.parameters.instanceChannelName,'pipeline_instances');
verifyEqual(testCase,prepared.provenance.model.releaseId,'release_a');
verifyEqual(testCase,prepared.provenance.model.releaseManifest, ...
    pipelineModuleFileIdentity(paths.release));
verifyEqual(testCase,prepared.provenance.model.verification,'promoted_release_checksums');
verifyEqual(testCase,c.executionParam.modelUpdatePolicy,'follow_promoted');
end

function testPreparedSnapshotDoesNotFollowChangedPointer(testCase)
[c,paths] = fixture(testCase);
ctx = struct('runId','test-run','params',struct('instanceChannelName','instances'));
prepared = cellLatentModel.prepareRuntime(c,ctx);
record = runtimeRecord(c,ctx,prepared);
changed = jsondecode(fileread(paths.channel));
changed.releaseManifest = 'missing_release.json';
writeText(paths.channel,jsonencode(changed));
ctx.moduleRuntime = record;
ctx.params.modelPath = 'cannot_redirect.pt';
pinned = cellLatentModel.resolveInferenceParam(c,ctx);
verifyEqual(testCase,pinned.modelPath,paths.model);
verifyEqual(testCase,pinned.resolvedModelReleaseId,'release_a');
verifyEqual(testCase,pinned.instanceChannelName,'instances');
fresh = cellLatentModel.prepareRuntime(c,rmfield(ctx,'moduleRuntime'));
verifyTrue(testCase,any(strcmp({fresh.diagnostics.severity},'error')));
end

function testPinnedClassifierAndRunIdentityMustMatch(testCase)
[c,~] = fixture(testCase);
ctx = struct('runId','first-run');
prepared = cellLatentModel.prepareRuntime(c,ctx);
ctx.moduleRuntime = runtimeRecord(c,ctx,prepared);
ctx.runId = 'second-run';
verifyError(testCase,@()cellLatentModel.resolveInferenceParam(c,ctx), ...
    'cellLatentModel:InvalidPinnedModuleRuntime');
ctx.runId = 'first-run';
ctx.moduleRuntime.classifierId = 'another-classifier';
verifyError(testCase,@()cellLatentModel.resolveInferenceParam(c,ctx), ...
    'cellLatentModel:InvalidPinnedModuleRuntime');
end

function testAnnotationSnapshotStillHasPriority(testCase)
c = classifier('');
snapshot = struct('schemaVersion',1,'intent','predict_for_annotation', ...
    'classifierId',c.strid,'package','cellLatentModel','usesGroundTruth',false, ...
    'parameters',struct('backend','legacy','modelSource','builtin','trackChannelName','annotation_tracks'));
ctx = struct('annotationPrediction',struct('usePinnedActiveModel',true, ...
    'activeModelSnapshot',snapshot),'moduleRuntime',struct('package','cellLatentModel'));
resolved = cellLatentModel.resolveInferenceParam(c,ctx);
verifyEqual(testCase,resolved.trackChannelName,'annotation_tracks');
end

function testTamperedPromotedArtifactIsDiagnosticError(testCase)
[c,paths] = fixture(testCase);
writeText(paths.model,'tampered');
prepared = cellLatentModel.prepareRuntime(c,struct());
verifyTrue(testCase,any(strcmp({prepared.diagnostics.code}, ...
    'cellLatentModel:ModelReleaseChecksumMismatch')));
verifyTrue(testCase,any(strcmp({prepared.diagnostics.severity},'error')));
end

function testMissingPromotedChannelIsDiagnosticError(testCase)
[c,paths] = fixture(testCase);
delete(paths.channel);
prepared = cellLatentModel.prepareRuntime(c,struct());
verifyTrue(testCase,any(strcmp({prepared.diagnostics.code}, ...
    'cellLatentModel:MissingModelReleaseChannel')));
end

function testLegacyPinnedPolicyDoesNotReadMissingChannel(testCase)
c = classifier(freshFolder(testCase));
c.executionParam = struct('modelUpdatePolicy','pinned', ...
    'modelReleaseChannelPath','missing.json');
prepared = cellLatentModel.prepareRuntime(c,struct());
verifyEqual(testCase,prepared.parameters.backend,'legacy');
verifyFalse(testCase,any(strcmp({prepared.diagnostics.severity},'error')));
end

function testReadOnlyPythonSelectionCannotBootstrap(testCase)
folder = freshFolder(testCase);
originalPath = path;
variables = {'USERPROFILE','CELL_LATENT_MODEL_PYTHON','DETECDIV_PYTHON_EXE'};
original = cellfun(@getenv,variables,'UniformOutput',false);
cleanup = onCleanup(@()restoreEnvironment(originalPath,variables,original)); %#ok<NASGU>
writeText(fullfile(folder,'pyenv.m'),sprintf([ ...
    'function value=pyenv(varargin)\n' ...
    'value=struct(''Status'',''NotLoaded'',''Executable'','''',''Version'','''');\nend\n']));
marker = fullfile(folder,'bootstrap_called.txt');
escapedMarker = strrep(marker,'''','''''');
writeText(fullfile(folder,'select_and_load_conda_env.m'),sprintf([ ...
    'function value=select_and_load_conda_env(varargin)\n' ...
    'fid=fopen(''%s'',''w''); fclose(fid); value=[];\nend\n'],escapedMarker));
setenv('USERPROFILE',folder);
setenv('CELL_LATENT_MODEL_PYTHON','');
setenv('DETECDIV_PYTHON_EXE','');
addpath(folder,'-begin');
clear pyenv select_and_load_conda_env;
runtime = cellLatentModel.utils.resolvePythonRuntime(struct(),'ReadOnly',true);
verifyEqual(testCase,runtime.pythonExecutable,'');
verifyEqual(testCase,runtime.packageSource,'deferred');
verifyFalse(testCase,isfile(marker));
end

function testStaticValidationDefersUnspecifiedBindings(testCase)
verifyEmpty(testCase,cellLatentModel.validateModule(struct()));
verifyEmpty(testCase,cellLatentModel.validateModule(struct('backend','legacy')));
diagnostics = cellLatentModel.validateModule(struct('device','unknown'));
verifyEqual(testCase,diagnostics.severity,'error');
verifyEqual(testCase,diagnostics.parameter,'device');
diagnostics = cellLatentModel.validateModule(struct('frameIntervalMinutes',0));
verifyEqual(testCase,diagnostics.code,'InvalidFrameInterval');
end

function testExplicitPathCommandPreservesRequestedSourceWithoutProbing(testCase)
folder = freshFolder(testCase);
originalPath = path;
cleanup = onCleanup(@()restoreSelectionPath(originalPath)); %#ok<NASGU>
writeText(fullfile(folder,'system.m'),sprintf([ ...
    'function varargout=system(varargin)\n' ...
    'error(''runtime_test:UnexpectedProcess'',''Read-only selection probed a process.'');\nend\n']));
writeText(fullfile(folder,'select_and_load_conda_env.m'),sprintf([ ...
    'function value=select_and_load_conda_env(varargin)\n' ...
    'error(''runtime_test:UnexpectedBootstrap'',''Read-only selection bootstrapped Python.'');\nend\n']));
addpath(folder,'-begin');
requested = struct('pythonExecutable','python3', ...
    'repositoryRoot',fullfile(folder,'requested_source'), ...
    'lineageRepositoryRoot',fullfile(folder,'requested_lineage'), ...
    'packageSource','explicit_request','backend','local');
runtime = cellLatentModel.utils.resolvePythonRuntime( ...
    struct('resolvedPythonRuntime',requested),'ReadOnly',true);
verifyEqual(testCase,runtime.pythonExecutable,'python3');
verifyEqual(testCase,runtime.repositoryRoot,requested.repositoryRoot);
verifyEqual(testCase,runtime.lineageRepositoryRoot,requested.lineageRepositoryRoot);
verifyEqual(testCase,runtime.packageSource,'requested_unverified');
prepared = cellLatentModel.prepareRuntime(classifier(folder), ...
    struct('resolvedPythonRuntime',requested));
verifyEqual(testCase,prepared.context.resolvedPythonRuntime.pythonExecutable,'python3');
verifyEqual(testCase,prepared.context.resolvedPythonRuntime.repositoryRoot,requested.repositoryRoot);
verifyEqual(testCase,prepared.provenance.environment.status,'requested_unverified');
end

function testTrainingDefaultsKeepDeploymentResolutionByDefault(testCase)
folder = freshFolder(testCase);
[c,marker,cleanup] = resolverCounter(testCase,classifier(folder),folder); %#ok<ASGLU>
c.trainingParam = struct('device','cpu');
spec = struct('staticKeys',{{'device'}},'artifactKeys',{{}},'outputKeys',{{}});
resolved = classifierApplyTrainingExecutionDefaults(struct(),c,spec,'pipeline');
verifyTrue(testCase,isfile(marker));
verifyEqual(testCase,resolved.device,'cpu');
verifyTrue(testCase,resolved.deploymentHookCalled);
delete(marker);
unresolved = classifierApplyTrainingExecutionDefaults(struct(),c,spec,'pipeline', ...
    'ResolveDeployment',false);
verifyFalse(testCase,isfile(marker));
verifyEqual(testCase,unresolved.device,'cpu');
verifyFalse(testCase,isfield(unresolved,'deploymentHookCalled'));
end

function testLatentPreparationResolvesDeploymentOnlyAtFinalStage(testCase)
[c,paths] = fixture(testCase);
[c,marker,cleanup] = resolverCounter(testCase,c,fileparts(paths.channel)); %#ok<ASGLU>
prepared = cellLatentModel.prepareRuntime(c,struct('params',struct('backend','legacy')));
% The generic training-defaults phase must not invoke a deployment hook.
% The package's final native resolver still verifies and pins release_a.
verifyFalse(testCase,isfile(marker));
verifyFalse(testCase,any(strcmp({prepared.diagnostics.severity},'error')));
verifyEqual(testCase,prepared.parameters.resolvedModelReleaseId,'release_a');
verifyEqual(testCase,prepared.parameters.backend,'causal_composite');
end

function [c,marker,cleanup] = resolverCounter(testCase,c,folder)
packageRoot = fullfile(folder,'+runtimeResolutionCounter');
mkdir(packageRoot);
writeText(fullfile(packageRoot,'resolvePromotedRelease.m'),sprintf([ ...
    'function params=resolvePromotedRelease(classif,params)\n' ...
    'fid=fopen(getenv(''DETECDIV_RUNTIME_TEST_MARKER''),''a'');\n' ...
    'fwrite(fid,''called''); fclose(fid); params.deploymentHookCalled=true;\nend\n']));
originalPath = path;
testCase.addTeardown(@()path(originalPath));
addpath(folder,'-begin');
marker = fullfile(folder,'deployment_hook_called.txt');
previous = getenv('DETECDIV_RUNTIME_TEST_MARKER');
setenv('DETECDIV_RUNTIME_TEST_MARKER',marker);
cleanup = onCleanup(@()setenv('DETECDIV_RUNTIME_TEST_MARKER',previous));
c.classifierPkg = 'runtimeResolutionCounter';
end

function [c,paths] = fixture(testCase)
folder = freshFolder(testCase);
c = classifier(folder);
releaseDir = fullfile(folder,'release'); mkdir(releaseDir);
paths.model = fullfile(releaseDir,'parent.pt'); writeText(paths.model,'weights');
paths.composite = fullfile(releaseDir,'manifest.json'); writeText(paths.composite,'{}');
tracking = fullfile(releaseDir,'tracking'); mkdir(tracking);
trackingManifest = fullfile(tracking,'manifest.json'); writeText(trackingManifest,'{}');
identities = [artifact('modelPath','parent.pt','file',paths.model); ...
    artifact('compositeManifestPath','manifest.json','file',paths.composite); ...
    artifact('trackingCheckpointDir','tracking/manifest.json','directory_manifest',trackingManifest)];
release = struct('format','detecdiv.cell_latent_model.release.v1','status','promoted', ...
    'releaseId','release_a','executionDefaults',struct('modelSource','trained', ...
    'backend','causal_composite'),'artifacts',identities);
paths.release = fullfile(releaseDir,'release.json');
writeText(paths.release,jsonencode(release));
identity = pipelineModuleFileIdentity(paths.release);
channel = struct('format','detecdiv.cell_latent_model.channel.v1','channel','stable', ...
    'releaseManifest','release.json','releaseManifestSha256',identity.sha256);
paths.channel = fullfile(releaseDir,'stable.json'); writeText(paths.channel,jsonencode(channel));
c.executionParam = struct('modelUpdatePolicy','follow_promoted', ...
    'modelReleaseChannelPath',paths.channel);
end

function value = artifact(parameter,path,kind,file)
identity = pipelineModuleFileIdentity(file);
value = struct('parameter',parameter,'path',path,'kind',kind,'sha256',identity.sha256);
end

function record = runtimeRecord(c,ctx,prepared)
record = prepared;
record.package = 'cellLatentModel';
record.classifierId = c.strid;
record.status = 'ready';
record.runId = ctx.runId;
end

function c = classifier(folder)
c = struct('strid','test_latent','path',folder,'classifierPkg','cellLatentModel', ...
    'trainingParam',struct(),'executionParam',struct());
end

function folder = freshFolder(testCase)
folder = tempname; mkdir(folder);
testCase.addTeardown(@()removeFolder(folder));
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder,'s'); end
end

function writeText(path,value)
fid = fopen(path,'w'); assert(fid >= 0);
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,value,'char');
end

function restoreEnvironment(originalPath,variables,values)
path(originalPath);
for i = 1:numel(variables), setenv(variables{i},values{i}); end
clear pyenv select_and_load_conda_env;
end

function restoreSelectionPath(originalPath)
path(originalPath);
clear system select_and_load_conda_env;
end
