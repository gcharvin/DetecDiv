function tests = testPipelineClassifierReferencePolicy
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.before = path;
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'helpers'),fullfile(root,'structure','io'));
end

function teardownOnce(tc)
path(tc.TestData.before);
end

function setup(tc)
tc.TestData.path = path;
tc.TestData.root = tempname;
tc.TestData.pkg = 'referencePolicyProbe';
tc.TestData.packageDir = fullfile(tc.TestData.root,['+' tc.TestData.pkg]);
mkdir(tc.TestData.packageDir);
writeText(fullfile(tc.TestData.packageDir,'classify.m'), ...
    'function out=classify(varargin), error(''fixture:Inference'',''Must not infer''); out=[]; end');
addpath(tc.TestData.root,'-begin');
clearFixtureFunctions;
end

function teardown(tc)
path(tc.TestData.path);
clearFixtureFunctions;
folder = char(java.io.File(tc.TestData.root).getCanonicalPath());
assert(strcmpi(fileparts(folder),char(java.io.File(tempdir).getCanonicalPath())));
if isfolder(folder), rmdir(folder,'s'); end
end

function testExplicitFalseDoesNotRequireOrDisplayUnusedSnapshot(tc)
writeSpec(tc,'spec=struct(''requiresRuntimeClassifier'',false,''inputKeys'',{{''mask''}});');
before = path;
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyFalse(tc,policy.required);
verifyTrue(tc,policy.declared);
verifyFalse(tc,policy.hasReference);
verifyFalse(tc,policy.showReference);
verifyTrue(tc,policy.specAvailable);
verifyEqual(tc,policy.spec.inputKeys,{'mask'});
verifyEqual(tc,policy.metadataStatus,'ok');
verifyFalse(tc,policy.semanticContractDeclared);
verifyEqual(tc,path,before);
end

function testUnspecifiedRequirementRemainsConservative(tc)
writeSpec(tc,'spec=struct(''summary'',''Legacy classifier'');');
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyTrue(tc,policy.required);
verifyTrue(tc,policy.showReference);
verifyFalse(tc,policy.declared);
verifyTrue(tc,policy.specAvailable);
end

function testReferenceRequirementOverridesNoPreloadedModel(tc)
writeSpec(tc,['spec=struct(''requiresClassifierReference'',true,' ...
    '''requiresRuntimeClassifier'',false);']);
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyTrue(tc,policy.required);
verifyTrue(tc,policy.showReference);
verifyTrue(tc,policy.declared);
verifyEqual(tc,policy.requirementSource,'requiresClassifierReference');
end

function testOptionalReferenceOverridesPreloadedModelFlag(tc)
writeSpec(tc,['spec=struct(''requiresClassifierReference'',false,' ...
    '''requiresRuntimeClassifier'',true);']);
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyFalse(tc,policy.required);
verifyFalse(tc,policy.showReference);
verifyTrue(tc,policy.declared);
verifyEqual(tc,policy.requirementSource,'requiresClassifierReference');
end

function testMissingMetadataRemainsConservative(tc)
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyTrue(tc,policy.required);
verifyFalse(tc,policy.specAvailable);
verifyEqual(tc,policy.metadataStatus,'metadata_unavailable');
end

function testExistingLegacyReferencesRemainVisible(tc)
writeSpec(tc,'spec=struct(''requiresRuntimeClassifier'',false);');
keys = {'modulePath','moduleVar','moduleId'};
for i = 1:numel(keys)
    node = fixtureNode(tc);
    node.params.(keys{i}) = ['legacy_' keys{i}];
    policy = pipelineClassifierReferencePolicy(node);
    verifyFalse(tc,policy.required);
    verifyTrue(tc,policy.hasReference,keys{i});
    verifyTrue(tc,policy.showReference,keys{i});
    verifyEqual(tc,node.params.(keys{i}),['legacy_' keys{i}]);
end
end

function testShadowedMetadataIsNotInvokedOrTrusted(tc)
otherRoot = fullfile(tc.TestData.root,'other');
otherPackage = fullfile(otherRoot,['+' tc.TestData.pkg]); mkdir(otherPackage);
writeText(fullfile(otherPackage,'executionSpec.m'), ...
    'function spec=executionSpec(varargin), error(''fixture:WrongCopy'',''Must not inspect another package''); spec=struct(); end');
addpath(otherRoot,'-end'); rehash;
before = path;
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyTrue(tc,policy.required);
verifyFalse(tc,policy.specAvailable);
verifyEqual(tc,policy.metadataStatus,'metadata_mismatch');
verifyEqual(tc,fileparts(policy.selectedExecutable),tc.TestData.packageDir);
verifyEqual(tc,fileparts(policy.metadataPath),otherPackage);
verifyEqual(tc,path,before);
end

function testFailingMetadataDoesNotWaiveRequirement(tc)
writeSpec(tc,'error(''fixture:BrokenMetadata'',''Metadata unavailable''); spec=struct();');
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyTrue(tc,policy.required);
verifyFalse(tc,policy.specAvailable);
verifyEqual(tc,policy.metadataStatus,'metadata_failed');
verifySubstring(tc,policy.message,'Metadata unavailable');
end

function testZeroArgumentMetadataIsSupported(tc)
writeText(fullfile(tc.TestData.packageDir,'executionSpec.m'), ...
    'function spec=executionSpec(), spec=struct(''requiresRuntimeClassifier'',false); end');
rehash;
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyTrue(tc,policy.specAvailable);
verifyFalse(tc,policy.required);
end

function testInvalidFlagDoesNotWaiveRequirement(tc)
writeSpec(tc,'spec=struct(''requiresRuntimeClassifier'',''false'');');
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyTrue(tc,policy.required);
verifyFalse(tc,policy.declared);
verifyTrue(tc,policy.specAvailable);
verifyEqual(tc,policy.metadataStatus,'metadata_invalid');
end

function testSemanticContractFromExecutionMetadata(tc)
writeSpec(tc,'spec=struct(''requiresRuntimeClassifier'',false,''pipelineContract'',struct(''summary'',''Declared''));');
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyTrue(tc,policy.semanticContractDeclared);
verifyEqual(tc,policy.semanticContractSource,'executionSpec.pipelineContract');
end

function testSemanticContractMustBelongToSelectedCopy(tc)
writeSpec(tc,'spec=struct(''requiresRuntimeClassifier'',false);');
writeDescriptor(tc);
otherRoot = fullfile(tc.TestData.root,'other');
otherPackage = fullfile(otherRoot,['+' tc.TestData.pkg]); mkdir(otherPackage);
writeText(fullfile(otherPackage,'moduleContract.m'), ...
    'function out=moduleContract(varargin), error(''fixture:Contract'',''Must not call contract''); out=[]; end');
addpath(otherRoot,'-end'); rehash;
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyFalse(tc,policy.semanticContractDeclared);
verifyEqual(tc,which([tc.TestData.pkg '.moduleContract']), ...
    fullfile(otherPackage,'moduleContract.m'));
end

function testSelectedDescriptorContractIsDeclaredWithoutInvokingIt(tc)
writeSpec(tc,'spec=struct(''requiresRuntimeClassifier'',false);');
writeDescriptor(tc);
writeText(fullfile(tc.TestData.packageDir,'moduleContract.m'), ...
    'function out=moduleContract(varargin), error(''fixture:Contract'',''Must not call contract''); out=[]; end');
rehash;
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyTrue(tc,policy.semanticContractDeclared);
verifyEqual(tc,policy.semanticContractSource,fullfile(tc.TestData.packageDir,'module.json'));
end

function testDescriptorContractDoesNotDependOnExecutionMetadata(tc)
writeDescriptor(tc);
writeText(fullfile(tc.TestData.packageDir,'moduleContract.m'), ...
    'function out=moduleContract(varargin), error(''fixture:Contract'',''Must not call contract''); out=[]; end');
rehash;
policy = pipelineClassifierReferencePolicy(fixtureNode(tc));
verifyTrue(tc,policy.semanticContractDeclared);
verifyFalse(tc,policy.specAvailable);
verifyTrue(tc,policy.required);
end

function testValidationDoesNotWarnAboutAnUnneededSnapshot(tc)
writeSpec(tc,'spec=struct(''requiresRuntimeClassifier'',false);');
[pipe,ctx] = fixturePipeline(tc);
before = path;
[ok,report] = validatePipeline(pipe,ctx,struct('allowGui',false, ...
    'readOnlyModuleDiscovery',true,'moduleCatalogue',struct([])));
verifyTrue(tc,ok,strjoin(report.errors,' | '));
verifyEqual(tc,report.classifierArtifacts.status,'not_required');
verifyFalse(tc,any(contains(report.warnings,'is not linked to an existing classi object')));
verifyEqual(tc,path,before);
end

function testValidationStillReportsExplicitBrokenReference(tc)
writeSpec(tc,'spec=struct(''requiresRuntimeClassifier'',false);');
[pipe,ctx] = fixturePipeline(tc);
pipe.nodes.params.modulePath = fullfile(tc.TestData.root,'missing_classifier');
[~,report] = validatePipeline(pipe,ctx,struct('allowGui',false, ...
    'readOnlyModuleDiscovery',true,'moduleCatalogue',struct([])));
verifyEqual(tc,report.classifierArtifacts.status,'missing_module_path');
verifyTrue(tc,any(contains([report.errors report.warnings],'Linked classifier folder is not accessible')));
end

function node = fixtureNode(tc)
node = struct('id','tracking','type','classifier','pkg',tc.TestData.pkg, ...
    'func',[tc.TestData.pkg '.classify'],'params',struct('pkg',tc.TestData.pkg));
end

function [pipe,ctx] = fixturePipeline(tc)
pipe = struct('nodes',fixtureNode(tc),'edges',struct([]),'branches',struct([]));
ctx = struct('roiList',1,'channels',{{'BF'}},'roiChannels',{{'BF'}});
end

function writeSpec(tc,body)
writeText(fullfile(tc.TestData.packageDir,'executionSpec.m'), ...
    ['function spec=executionSpec(varargin), ' body ' end']);
clear('referencePolicyProbe.executionSpec'); rehash;
end

function writeDescriptor(tc)
descriptor = struct('format','detecdiv.module.v1','package',tc.TestData.pkg, ...
    'type','classifier','entrypoints',struct( ...
    'execute',[tc.TestData.pkg '.classify'],'parameters',[tc.TestData.pkg '.executionSpec'], ...
    'contract',[tc.TestData.pkg '.moduleContract']), ...
    'compatibility',struct('pipelineContract','detecdiv.module_contract.v1'));
writeText(fullfile(tc.TestData.packageDir,'module.json'),jsonencode(descriptor));
end

function clearFixtureFunctions
clear('referencePolicyProbe.classify','referencePolicyProbe.executionSpec', ...
    'referencePolicyProbe.moduleContract');
end

function writeText(file,value)
fid = fopen(file,'w'); assert(fid>=0);
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,value,'char');
end
