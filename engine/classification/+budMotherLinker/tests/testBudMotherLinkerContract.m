function tests = testBudMotherLinkerContract
tests = functiontests(localfunctions);
end

function testRuntimeChannelsBinding(testCase)
param = budMotherLinker.utils.defaultExecutionParam();
param.channels = 'results_trackastra';
actual = budMotherLinker.normalizeParam(param,struct());
verifyEqual(testCase,actual.trackChannelName,'results_trackastra');
end

function testExplicitChannelTakesPrecedence(testCase)
param = budMotherLinker.utils.defaultExecutionParam();
param.trackChannelName = 'manual_tracks';
param.channels = 'results_trackastra';
actual = budMotherLinker.normalizeParam(param,struct());
verifyEqual(testCase,actual.trackChannelName,'manual_tracks');
end

function testClassifierContract(testCase)
node = struct('type','classifier','pkg','budMotherLinker', ...
    'func','budMotherLinker.classify','params',struct());
contract = pipelineNodeContract(node);
verifyTrue(testCase,ismember('minLifetime',contract.parameters.static));
verifyEqual(testCase,contract.binding.mode,'singleChannel');
verifyEqual(testCase,contract.binding.selectorKeys,{'trackChannelName'});
verifyEqual(testCase,contract.resources.in.param,'trackChannelName');
verifyEqual(testCase,contract.resources.out.role,'lineage');
verifyTrue(testCase,contract.capabilities.outputsDataSeries);
forbidden = {'modelPackage','lynRepository','lynCheckpoint','pythonExecutable','modelPath'};
verifyFalse(testCase,any(ismember(forbidden,contract.parameters.static)));
end

function testExecutionSpecSeparatesArtifactPath(testCase)
spec = budMotherLinker.executionSpec();
verifyTrue(testCase,ismember('modelPath',spec.artifactKeys));
verifyFalse(testCase,ismember('modelPath',spec.staticKeys));
verifyEqual(testCase,spec.category,'Tracking');
verifyFalse(testCase,spec.requiresRuntimeClassifier);
end

function testSetparamSupportsClassifierGUI(testCase)
root = tempname;
cleanup = onCleanup(@() cleanupFolder(root));
c = classi(root,'budlink',1,'InitTraining',false);
result = budMotherLinker.setparam(c);
verifyEqual(testCase,c.classifierPkg,'budMotherLinker');
verifyEqual(testCase,c.trainingFun,'budMotherLinker.train');
verifyEqual(testCase,c.classifyFun,'budMotherLinker.classify');
verifyEqual(testCase,c.category,{'Tracking'});
verifyTrue(testCase,isfield(c.trainingParam,'tip'));
verifyTrue(testCase,isfield(c.executionParam,'modelSource'));
verifyEqual(testCase,result.status,"OK");
clear cleanup;
end

function testLegacyPythonFieldsAreRemoved(testCase)
param = budMotherLinker.utils.defaultExecutionParam();
param.trackChannelName = 'results_trackastra';
param.modelPackage = 'legacy';
param.lynRepository = 'legacy';
param.lynCheckpoint = 'legacy';
param.pythonExecutable = 'legacy';
actual = budMotherLinker.normalizeParam(param,struct());
forbidden = {'modelPackage','lynRepository','lynCheckpoint','pythonExecutable'};
verifyFalse(testCase,any(isfield(actual,forbidden)));
end

function testNativeHgbMatchesSklearnReference(testCase)
model = load(fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'model','project47_v002','hgb_lyn16.mat'));
features = [model.feature_mean; zeros(1,16); (0:15)/10];
expected = [0.0005665560020132839; 0.9049295836325778; 0.009259448529673229];
actual = budMotherLinker.predictHGB(features);
verifyEqual(testCase,actual,expected,'AbsTol',1e-12);
end

function testTrainedArtifactUsesSameNativeEvaluator(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() cleanupFolder(root));
artifact = load(fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'model','project47_v002','hgb_lyn16.mat'));
modelFile = fullfile(root,'model.mat');
save(modelFile,'artifact','-v7');
features = [artifact.feature_mean; zeros(1,16); (0:15)/10];
expected = budMotherLinker.predictHGB(features);
param = struct('modelSource','trained','modelPath',modelFile);
actual = budMotherLinker.predictHGB(features,param);
verifyEqual(testCase,actual,expected,'AbsTol',1e-14);
clear cleanup;
end

function testTrainingDefaultsAreExactSklearnHgb(testCase)
p = budMotherLinker.utils.defaultTrainingParam();
verifyEqual(testCase,p.maxIter,200);
verifyEqual(testCase,p.learningRate,0.05);
verifyEqual(testCase,p.maxLeafNodes,15);
verifyEqual(testCase,p.minSamplesLeaf,20);
verifyEqual(testCase,p.l2Regularization,0.01);
verifyEqual(testCase,p.randomState,23);
verifyFalse(testCase,any(isfield(p, ...
    {'numLearningCycles','learnRate','maxNumSplits','minLeafSize'})));
end

function testEventMetricsAreGrouped(testCase)
dataset = struct('event_id',[1;1;2;2],'y',logical([1;0;0;1]));
scores = [0.8;0.2;0.7;0.6];
metrics = budMotherLinker.evaluateScores(dataset,scores,true(4,1),0.15);
verifyEqual(testCase,metrics.events,2);
verifyEqual(testCase,metrics.top1_accuracy,0.5);
verifyEqual(testCase,metrics.selected,1);
verifyEqual(testCase,metrics.auto_precision,1);
end

function cleanupFolder(root)
if exist(root,'dir') == 7
    try rmdir(root,'s'); catch, end
end
end
