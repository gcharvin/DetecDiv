function tests = testPipeline2ModuleLibrarySource
%TESTPIPELINE2MODULELIBRARYSOURCE Guard subtype enumeration from node callbacks.
tests = functiontests(localfunctions);
end

function testSubtypeEnumerationDoesNotUseClassifierLinkState(testCase)
sourcePath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'pipeline2_extracted.m');
source = fileread(sourcePath);
block = regexp(source, ...
    'function items = moduleLibraryPackagesForType.*?(?=\n\s*function )', ...
    'match', 'once');

verifyNotEmpty(testCase, block);
verifyFalse(testCase, contains(block, 'executionPkg'));
verifyFalse(testCase, contains(block, 'classiObj'));
verifyFalse(testCase, contains(block, 'app.Data.nodes'));
end

function testTypedLatentObservationsAcceptPhysicalRoiChannels(testCase)
sourcePath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'pipeline2_extracted.m');
source = fileread(sourcePath);
block = regexp(source, ...
    'function tf = resourceRolesCompatibleForUi.*?(?=\n\s*function )', ...
    'match', 'once');

verifyNotEmpty(testCase, block);
for role = {'brightfield_image','legacy_gfp_fluorescence', ...
        'division_nucleus_fluorescence','bud_neck_fluorescence'}
    verifyTrue(testCase, contains(block, role{1}), ...
        sprintf('Typed role %s must accept a physical ROI channel.',role{1}));
end
verifyTrue(testCase, contains(block, 'roiScorableChannelRolesForUi'));
end

function testLatentBrightfieldBindingValidatesConcreteRoiChannel(testCase)
params=cellLatentModel.utils.defaultExecutionParam();
params.backend='causal_composite';
params.instanceChannelName='instances';
params.brightfieldChannelName='BF';
params.stateUpdateMode='none';
params.outputTrackChannelName='latent_tracks';
params.outputFamilyName='latent_family';
node=struct('id','classifier_latent','name','classifier_latent', ...
    'type','classifier','func','cellLatentModel.classify','gui','', ...
    'guiMode','','paramRequired',{{}},'pkg','cellLatentModel', ...
    'params',params,'inputs',{{}},'outputs',{{}},'enabled',true, ...
    'status','','layout',[]);
pipe=struct('nodes',node,'edges',struct([]),'branches',struct([]));
ctx=struct('roiList',1,'channels',{{'instances','BF'}}, ...
    'roiChannels',{{'instances','BF'}},'masks',{{'instances'}}, ...
    'dataSeries',{{}});

[ok,report]=validatePipeline(pipe,ctx,struct('allowGui',false));
verifyTrue(testCase,ok,strjoin(report.errors,' | '));
end

function testObjectMetricsDeclaresMetricsAndObjectDependencies(testCase)
params=objectMetrics.setparam(struct());
node=struct('id','processor_objectmetrics','type','processor', ...
    'pkg','objectMetrics','func','objectMetrics.process','params',params);
contract=pipelineNodeContract(node);

verifyEmpty(testCase,contract.selectors.channelParam);
verifyEqual(testCase,{contract.resources.in.type},{'dataSeries','cellModel'});
verifyEqual(testCase,{contract.resources.in.role},{'metrics','cellular_objects'});
verifyEqual(testCase,{contract.resources.in.param},{'inputData','family'});
verifyTrue(testCase,all([contract.resources.in.required]));
verifyEqual(testCase,contract.resources.out.role,'object_metrics');
verifyEqual(testCase,contract.requirements.roi.channelsMin,0);
end

function testClassifierLinkAcceptsValidatedLatentRuntimeManifest(testCase)
sourcePath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'pipeline2_extracted.m');
source = fileread(sourcePath);
block = regexp(source, ...
    'function linkClassifierArtifact\(app, node\).*?(?=\n\s*function )', ...
    'match', 'once');

verifyNotEmpty(testCase, block);
verifyTrue(testCase, contains(block, 'runtime_manifest.json'));
verifyTrue(testCase, contains(block, 'cellLatentModel.validateRuntimeManifest(pth,'));
verifyTrue(testCase, contains(block, "'Title', 'Link latent-model runtime'"));
verifyTrue(testCase, contains(block, 'updateClassifierLinkProgress('));
verifyTrue(testCase, contains(block, '''classifier'', manifestClassiId'));
verifyTrue(testCase, contains(block, '[manifestClassiId ''_classification.mat'']'));
verifyTrue(testCase, contains(block, 'ClassifierSnapshotOnly'));
end

function testRuntimeManifestValidatorNormalizesPickerFolder(testCase)
sourcePath = fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))), ...
    'engine','classification','+cellLatentModel','validateRuntimeManifest.m');
source = fileread(sourcePath);
verifyTrue(testCase, contains(source, ...
    "bundleRoot = regexprep(bundleRoot,'[\\/]+$','');"));
end

function testRunLoadRestoresClassifierLinksFromSavedPipelineSpec(testCase)
sourcePath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'pipeline2_extracted.m');
source = fileread(sourcePath);
block = regexp(source, ...
    'function loadRunIntoUi\(app, runObj, refreshUi\).*?(?=\n\s*function )', ...
    'match', 'once');
verifyNotEmpty(testCase,block);
verifyTrue(testCase,contains(block, ...
    'pipelineRestoreClassifierLinksFromRun(app.Data.nodes,ctx)'));
end

function testObjectMetricsAutoResolvesBothUpstreamResources(testCase)
compute=computeMetrics.setparam(struct());
compute.outputName='channel_quantification';
latent=cellLatentModel.utils.defaultExecutionParam();
latent.backend='legacy';
latent.trackChannelName='tracked';
latent.outputFamilyName='latent_family';
object=objectMetrics.setparam(struct());
nodes(1)=pipelineNode('processor_compute','processor','computeMetrics', ...
    'computeMetrics.process',compute);
nodes(2)=pipelineNode('classifier_latent','classifier','cellLatentModel', ...
    'cellLatentModel.classify',latent);
nodes(3)=pipelineNode('processor_objects','processor','objectMetrics', ...
    'objectMetrics.process',object);
pipe=struct('nodes',nodes,'edges',struct([]),'branches',struct([]));
ctx=struct('roiList',1,'channels',{{'tracked'}}, ...
    'roiChannels',{{'tracked'}},'masks',{{'tracked'}}, ...
    'dataSeries',{{}});

[resolved,~]=pipelineResolveBindings(pipe,ctx,struct('allowGui',false));
verifyEqual(testCase,resolved.nodes(3).params.inputData,'channel_quantification');
verifyEqual(testCase,resolved.nodes(3).params.family,'latent_family');
[~,report]=validatePipeline(resolved,ctx,struct('allowGui',false));
resourceEdges=report.edges(strcmpi({report.edges.condition},'resourceBinding'));
toObjects=resourceEdges(strcmp({resourceEdges.to},'processor_objects'));
verifyEqual(testCase,sort({toObjects.from}), ...
    sort({'processor_compute','classifier_latent'}));
end

function node=pipelineNode(id,type,pkg,func,params)
node=struct('id',id,'type',type,'pkg',pkg,'func',func,'params',params);
end
