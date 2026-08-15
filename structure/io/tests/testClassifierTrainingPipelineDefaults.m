function tests = testClassifierTrainingPipelineDefaults
tests = functiontests(localfunctions);
end

function testTrainingBindingsOverrideInferenceDefaults(testCase)
params = struct( ...
    'trackChannelName', '', ...
    'gfpChannelName', 'stale_gfp', ...
    'brightfieldChannelName', 'stale_bf', ...
    'outputFamilyName', 'keep_me');
training = struct( ...
    'trackChannelName', 'latent_model_1_cell', ...
    'gfpChannelName', '', ...
    'brightfieldChannelName', 'Channel1_z2', ...
    'notAnInput', 'ignored');

actual = classifierApplyTrainingInputBindings(params, training, ...
    {'trackChannelName','gfpChannelName','brightfieldChannelName'});

verifyEqual(testCase, actual.trackChannelName, 'latent_model_1_cell');
verifyEqual(testCase, actual.gfpChannelName, '');
verifyEqual(testCase, actual.brightfieldChannelName, 'Channel1_z2');
verifyEqual(testCase, actual.outputFamilyName, 'keep_me');
verifyFalse(testCase, isfield(actual, 'notAnInput'));
end

function testTrainingBindingAcceptsLegacyChoiceEncoding(testCase)
actual = classifierApplyTrainingInputBindings(struct(), ...
    struct('trackChannelName', {{'first_mask','reviewed_mask'}}), ...
    {'trackChannelName'});

verifyEqual(testCase, actual.trackChannelName, 'reviewed_mask');
end

function testLocalOnlyClassifierDefaultsToLocal(testCase)
hub = localHubMapping();
actual = classifierDefaultExecutionTarget( ...
    'C:\Users\Gilles\SynologyDrive\Data\classifier', hub);
verifyEqual(testCase, actual, 'local');
end

function testMappedWindowsClassifierDefaultsToHub(testCase)
hub = localHubMapping();
actual = classifierDefaultExecutionTarget( ...
    'X:\ClassiRepository\latent_model_1', hub);
verifyEqual(testCase, actual, 'hub');
end

function testServerClassifierDefaultsToHub(testCase)
actual = classifierDefaultExecutionTarget( ...
    '/data/ClassiRepository/latent_model_1', struct());
verifyEqual(testCase, actual, 'hub');
end

function hub = localHubMapping()
hub = struct();
hub.defaultLocalProjectRoot = '';
hub.defaultRemoteProjectRoot = '';
hub.pathMappings = struct('localRoot', 'X:\', 'remoteRoot', '/data');
end
