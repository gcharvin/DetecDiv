function tests = testBudMotherLinkerContract
tests = functiontests(localfunctions);
end

function testGenericRuntimeChannelsBinding(testCase)
param = budMotherLinker.setparam(struct( ...
    'useProvidedChannels', true, ...
    'channels', {{'N/A'}}));
param.channels = 'results_trackastra';

actual = budMotherLinker.normalizeParam(param, struct());

verifyEqual(testCase, actual.trackChannelName, 'results_trackastra');
end

function testExplicitChannelTakesPrecedence(testCase)
param = budMotherLinker.setparam(struct( ...
    'useProvidedChannels', true, ...
    'channels', {{'manual_tracks'}}));
param.channels = 'results_trackastra';

actual = budMotherLinker.normalizeParam(param, struct());

verifyEqual(testCase, actual.trackChannelName, 'manual_tracks');
end

function testProcessorContractExposesStaticParameters(testCase)
node = struct( ...
    'type', 'processor', ...
    'pkg', 'budMotherLinker', ...
    'func', 'budMotherLinker.process', ...
    'params', struct());

contract = pipelineNodeContract(node);

verifyTrue(testCase, ismember('minLifetime', contract.parameters.static));
verifyTrue(testCase, ismember('modelPackage', contract.parameters.static));
verifyEqual(testCase, contract.binding.mode, 'singleChannel');
verifyEqual(testCase, contract.binding.selectorKeys, {'trackChannelName'});
verifyEqual(testCase, contract.resources.in.param, 'trackChannelName');
verifyEmpty(testCase, contract.resources.out);
verifyFalse(testCase, contract.capabilities.outputsDataSeries);
end
