function tests = testCellposeModuleContract
% Pure metadata tests; no Python, model files, ROI, or GPU is needed.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path;
classificationRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(classificationRoot);
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testDefaultMatchesLegacySegmentation(testCase)
contract = cellposesam.moduleContract();
verifyEqual(testCase, {contract.in.name}, {'roiList'});
verifyEqual(testCase, {contract.out.name}, {'roiList','masks'});
verifyEqual(testCase, {contract.resources.out.type}, {'mask'});
verifyEqual(testCase, contract.requirements.roi.channelsMin, 1);
verifyEqual(testCase, contract.binding.mode, 'singleChannel');
verifyEqual(testCase, contract.binding.exactCount, 1);
verifyEqual(testCase, contract.binding.resolveAt, 'design');
verifyTrue(testCase, contract.capabilities.outputsMasks);
verifyFalse(testCase, contract.capabilities.outputsChannels);
verifyFalse(testCase, contract.capabilities.outputsDataSeries);
verifyEqual(testCase, contract.semantics.outputIdentity, 'propagated_instance_ids');
end

function testOutputModes(testCase)
modes = {'segmentation','proba','probability','both'};
expectedPorts = {{'roiList','masks'}, {'roiList','channels'}, ...
    {'roiList','channels'}, {'roiList','masks','channels'}};
for i = 1:numel(modes)
    contract = cellposesam.moduleContract(struct('outputType', modes{i}));
    verifyEqual(testCase, {contract.out.name}, expectedPorts{i});
    verifyEqual(testCase, contract.capabilities.outputsMasks, ...
        any(strcmp(modes{i}, {'segmentation','both'})));
    verifyEqual(testCase, contract.capabilities.outputsChannels, ...
        any(strcmp(modes{i}, {'proba','probability','both'})));
    verifyFalse(testCase, contract.capabilities.roiDataSeries);
end
end

function testChoiceCellsUseLastNonemptyValue(testCase)
params = struct();
params.outputType = {'segmentation','probability','both','probability',''};
contract = cellposesam.moduleContract(params);
verifyEqual(testCase, {contract.out.name}, {'roiList','channels'});
params.outputType = {[], '', 'both', []};
contract = cellposesam.moduleContract(params);
verifyEqual(testCase, {contract.out.name}, {'roiList','masks','channels'});
end

function testOutputModeFallbackAndPrecedence(testCase)
contract = cellposesam.moduleContract(struct('outputMode', 'probability'));
verifyEqual(testCase, {contract.out.name}, {'roiList','channels'});
contract = cellposesam.moduleContract(struct('outputType', '', 'outputMode', 'both'));
verifyEqual(testCase, {contract.out.name}, {'roiList','masks','channels'});
contract = cellposesam.moduleContract(struct('outputType', 'segmentation', 'outputMode', 'both'));
verifyEqual(testCase, {contract.out.name}, {'roiList','masks'});
end

function testInvalidAndStaleModesKeepLegacyFallback(testCase)
invalidModes = {'invalid','probabilities','probability-map','all','postprocessing', 42, {[],''}};
for i = 1:numel(invalidModes)
    params = struct();
    params.outputType = invalidModes{i};
    contract = cellposesam.moduleContract(params);
    verifyEqual(testCase, {contract.out.name}, {'roiList','masks'});
end
contract = cellposesam.moduleContract(struct('outputType', ' Both '));
verifyEqual(testCase, {contract.out.name}, {'roiList','masks','channels'});
end

function testStaticKeysAndSummaryComeFromExecutionSpec(testCase)
contract = cellposesam.moduleContract(struct('diameter', 40, 'min_size', -1));
spec = cellposesam.executionSpec();
verifyEqual(testCase, contract.parameters.static, spec.staticKeys);
verifyEqual(testCase, contract.summary, spec.summary);
end

function testTrackInstancesOnlyAddsSemanticIdentity(testCase)
defaultContract = cellposesam.moduleContract();
falseValues = {false, 0, 'false', 'off'};
for i = 1:numel(falseValues)
    params = struct();
    params.trackInstances = falseValues{i};
    contract = cellposesam.moduleContract(params);
    verifyEqual(testCase, contract.semantics.outputIdentity, 'frame_local_instances');
    verifyEqual(testCase, rmfield(contract, 'semantics'), rmfield(defaultContract, 'semantics'));
end
contract = cellposesam.moduleContract(struct('trackInstances', 'yes'));
verifyEqual(testCase, contract.semantics.outputIdentity, 'propagated_instance_ids');
contract = cellposesam.moduleContract(struct('outputType', 'probability', 'trackInstances', false));
verifyEqual(testCase, contract.semantics.outputIdentity, 'probability');
end

function testOutputNamesRemainExplicitResourceBindings(testCase)
params = struct('outputType', 'both', 'outputName', 'my_masks', ...
    'probabilityOutputName', 'my_probability');
contract = cellposesam.moduleContract(params);
verifyEqual(testCase, {contract.resources.out.param}, {'outputName','probabilityOutputName'});
verifyEqual(testCase, {contract.resources.out.nameParam}, {'outputName','probabilityOutputName'});
verifyEqual(testCase, {contract.resources.out.symbol}, {'segmentation','cellprob'});
verifyEqual(testCase, {contract.resources.in.param}, {'channels'});
end

function testMetadataCallDoesNotMutateInputsOrPath(testCase)
params = struct('outputType', 'both', 'channel', 'brightfield', ...
    'unusedHistoricalValue', struct('preserved', 5));
beforeParams = params;
beforePath = path;
first = cellposesam.moduleContract(params);
second = cellposesam.moduleContract(params);
verifyEqual(testCase, params, beforeParams);
verifyEqual(testCase, path, beforePath);
verifyEqual(testCase, first, second);
end
