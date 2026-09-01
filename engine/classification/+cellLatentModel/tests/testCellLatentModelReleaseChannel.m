function tests = testCellLatentModelReleaseChannel
%TESTCELLLATENTMODELRELEASECHANNEL Stable promoted-model resolution tests.
tests=functiontests(localfunctions);
end

function setupOnce(~)
repoRoot=fileparts(fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath'))))));
addpath(repoRoot);
detecdiv_setup_path;
end

function testFollowPromotedResolvesAndVerifiesArtifacts(testCase)
[c,params,expected]=fixture(testCase);
resolved=cellLatentModel.resolvePromotedRelease(c,params);
verifyEqual(testCase,resolved.resolvedModelReleaseId,'latent-v5-stable');
verifyEqual(testCase,resolved.modelPath,expected.modelPath);
verifyEqual(testCase,resolved.compositeManifestPath, ...
    expected.compositeManifestPath);
verifyEqual(testCase,resolved.trackingCheckpointDir, ...
    expected.trackingCheckpointDir);
verifyEqual(testCase,resolved.sceneParentRuntimeManifestPath, ...
    expected.sceneParentRuntimeManifestPath);
verifyEqual(testCase,resolved.runtimeCodeRoot,expected.runtimeCodeRoot);
verifyEqual(testCase,resolved.modelSource,'trained');
verifyEqual(testCase,resolved.backend,'causal_composite');
end

function testPinnedPolicyDoesNotReadChannel(testCase)
folder=freshFolder(testCase);
c=classi(folder,'release_pinned',1);
params=struct('modelUpdatePolicy','pinned', ...
    'modelReleaseChannelPath',fullfile(folder,'missing.json'), ...
    'modelPath','owned.pt');
resolved=cellLatentModel.resolvePromotedRelease(c,params);
verifyEqual(testCase,resolved,params);
end

function testChecksumMismatchFailsClosed(testCase)
[c,params,expected]=fixture(testCase);
writeText(expected.modelPath,'tampered');
verifyError(testCase,@()cellLatentModel.resolvePromotedRelease(c,params), ...
    'cellLatentModel:ModelReleaseChecksumMismatch');
end

function testRuntimeCodeContentMismatchFailsClosed(testCase)
[c,params,expected]=fixture(testCase);
writeText(fullfile(expected.runtimeCodeRoot,'src','cell_latent_model', ...
    '__init__.py'),'tampered');
verifyError(testCase,@()cellLatentModel.resolvePromotedRelease(c,params), ...
    'cellLatentModel:ModelReleaseChecksumMismatch');
end

function testPromotedReleaseOverridesStalePipelineBackend(testCase)
[c,params,~]=fixture(testCase);
c.classifierPkg='cellLatentModel';
c.executionParam=struct('frameIntervalMinutes',5);
c.executionParam.modelUpdatePolicy=params.modelUpdatePolicy;
c.executionParam.modelReleaseChannelPath=params.modelReleaseChannelPath;
snapshot=struct('schemaVersion',1,'classifierId',c.strid, ...
    'classifierPackage','cellLatentModel','executionDefaults',struct( ...
    'backend','causal_composite', ...
    'instanceChannelName','training_instances', ...
    'brightfieldChannelName','Channel1_z2'));
writeText(fullfile(c.path,'training_execution_defaults.json'), ...
    jsonencode(snapshot,'PrettyPrint',true));
ctx=struct('params',struct('backend','legacy', ...
    'frameIntervalMinutes',[], ...
    'instanceChannelName','@resource:segmentation:cellpose', ...
    'brightfieldChannelName','ch1-PH'));
resolved=cellLatentModel.resolveInferenceParam(c,ctx);
verifyEqual(testCase,resolved.backend,'causal_composite');
verifyEqual(testCase,resolved.frameIntervalMinutes,5);
verifyEqual(testCase,resolved.resolvedModelReleaseId,'latent-v5-stable');
verifyEqual(testCase,resolved.instanceChannelName, ...
    '@resource:segmentation:cellpose');
verifyEqual(testCase,resolved.brightfieldChannelName,'ch1-PH');
end

function [c,params,expected]=fixture(testCase)
folder=freshFolder(testCase);
c=classi(folder,'release_follow',1);
releaseDir=fullfile(folder,'release');mkdir(releaseDir);
modelPath=fullfile(releaseDir,'parent.pt');writeText(modelPath,'v5-parent');
compositePath=fullfile(releaseDir,'manifest.json');
writeText(compositePath,'{"format":"composite"}');
trackingDir=fullfile(releaseDir,'tracking');mkdir(trackingDir);
trackingManifest=fullfile(trackingDir,'manifest.json');
writeText(trackingManifest,'{"format":"tracking"}');
sceneParentPath=fullfile(releaseDir,'scene_parent_ensemble.json');
writeText(sceneParentPath,'{"format":"scene-parent-v54"}');
codeRoot=fullfile(releaseDir,'code');
mkdir(fullfile(codeRoot,'src','cell_latent_model'));
codeFile=fullfile(codeRoot,'src','cell_latent_model','__init__.py');
writeText(codeFile,'# pinned runtime');
codeManifest=fullfile(codeRoot,'manifest.json');
writeText(codeManifest,jsonencode(struct('generated_files',struct( ...
    'path','src/cell_latent_model/__init__.py', ...
    'sha256',sha256(codeFile))),'PrettyPrint',true));
artifacts=[artifact('modelPath','parent.pt','file',sha256(modelPath)); ...
    artifact('compositeManifestPath','manifest.json','file', ...
        sha256(compositePath)); ...
    artifact('trackingCheckpointDir','tracking/manifest.json', ...
        'directory_manifest',sha256(trackingManifest)); ...
    artifact('sceneParentRuntimeManifestPath', ...
        'scene_parent_ensemble.json','file',sha256(sceneParentPath)); ...
    artifact('runtimeCodeRoot','code/manifest.json', ...
        'directory_manifest',sha256(codeManifest))];
release=struct('schemaVersion',1, ...
    'format','detecdiv.cell_latent_model.release.v1', ...
    'releaseId','latent-v5-stable','status','promoted', ...
    'executionDefaults',struct('modelSource','trained', ...
        'backend','causal_composite'), ...
    'artifacts',artifacts);
releasePath=fullfile(releaseDir,'release.json');
writeText(releasePath,jsonencode(release,'PrettyPrint',true));
channel=struct('schemaVersion',1, ...
    'format','detecdiv.cell_latent_model.channel.v1', ...
    'channel','stable','releaseManifest','release.json', ...
    'releaseManifestSha256',sha256(releasePath));
channelPath=fullfile(releaseDir,'stable.json');
writeText(channelPath,jsonencode(channel,'PrettyPrint',true));
params=struct('modelUpdatePolicy','follow_promoted', ...
    'modelReleaseChannelPath',channelPath);
expected=struct('modelPath',modelPath, ...
    'compositeManifestPath',compositePath, ...
    'trackingCheckpointDir',trackingDir, ...
    'sceneParentRuntimeManifestPath',sceneParentPath, ...
    'runtimeCodeRoot',codeRoot);
end

function value=artifact(parameter,path,kind,hash)
value=struct('parameter',parameter,'path',path,'kind',kind,'sha256',hash);
end

function digest=sha256(path)
engine=java.security.MessageDigest.getInstance('SHA-256');
file=java.io.File(path);
content=javaMethod('readAllBytes','java.nio.file.Files',file.toPath());
bytes=typecast(engine.digest(content),'uint8');
digest=lower(reshape(dec2hex(bytes,2).',1,[]));
end

function folder=freshFolder(testCase)
folder=tempname;mkdir(folder);
testCase.addTeardown(@()removeFolder(folder));
end

function writeText(path,value)
fid=fopen(path,'w');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,value,'char');
end

function removeFolder(folder)
if isfolder(folder),rmdir(folder,'s');end
end
