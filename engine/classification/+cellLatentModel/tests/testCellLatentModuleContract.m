function tests = testCellLatentModuleContract
%TESTCELLLATENTMODULECONTRACT Semantic declarations require no runtime/model.
tests = functiontests(localfunctions);
end

function testMissingBackendRetainsLegacyInputs(testCase)
contract = cellLatentModel.moduleContract();
verifyEqual(testCase, contract.binding.selectorKeys, {'trackChannelName','gfpChannelName'});
verifyEqual(testCase, {contract.resources.in.role}, ...
    {'mask_roi_image','legacy_gfp_fluorescence'});
verifyEqual(testCase, {contract.resources.in.symbol}, ...
    {'tracked_masks','legacy_gfp_fluorescence'});
verifyEqual(testCase, [contract.resources.in.required], [true false]);
verifyEqual(testCase, contract.semantics.inputIdentity, 'stable_tracks');
verifyFalse(testCase, contract.capabilities.outputsChannels);
verifyEqual(testCase, {contract.out.name}, {'roiList','dataSeries','objects'});
verifyEqual(testCase, {contract.resources.out.role}, {'lineage','cellular_objects'});
end

function testGeometryHasOnlyStableMasks(testCase)
contract = cellLatentModel.moduleContract(struct('backend','temporal_lineage'));
verifyEqual(testCase, contract.binding.selectorKeys, {'trackChannelName'});
verifyEqual(testCase, {contract.resources.in.param}, {'trackChannelName'});
verifyTrue(testCase, contract.resources.in.required);
verifyEqual(testCase, contract.semantics.inputIdentity, 'stable_tracks');
end

function testObservedTemporalMarkersHaveExplicitRoles(testCase)
params = struct('backend','temporal_lineage','temporalVariant','all_observed', ...
    'gfpChannelName','legacy-gfp');
contract = cellLatentModel.moduleContract(params);
verifyEqual(testCase, contract.binding.selectorKeys, ...
    {'trackChannelName','nucleusChannelName','budneckChannelName'});
verifyEqual(testCase, {contract.resources.in.role}, ...
    {'mask_roi_image','division_nucleus_fluorescence','bud_neck_fluorescence'});
verifyEqual(testCase, [contract.resources.in.required], [true false false]);
verifyFalse(testCase, any(strcmp({contract.resources.in.param}, 'gfpChannelName')));
end

function testContinuousObservationsStayOptional(testCase)
contract = cellLatentModel.moduleContract(struct( ...
    'backend','continuous_cell_state','stateUpdateMode','promoted_frozen_bf'));
verifyEqual(testCase, contract.binding.selectorKeys, ...
    {'trackChannelName','brightfieldChannelName','nucleusChannelName','budneckChannelName'});
verifyEqual(testCase, {contract.resources.in.role}, {'mask_roi_image', ...
    'brightfield_image','division_nucleus_fluorescence','bud_neck_fluorescence'});
verifyEqual(testCase, [contract.resources.in.required], [true false false false]);
verifyFalse(testCase, contract.capabilities.outputsChannels);
verifyEqual(testCase, contract.semantics.outputIdentity, 'stable_tracks');
end

function testCompositeCreatesStableTrackChannel(testCase)
contract = cellLatentModel.moduleContract(struct('backend','causal_composite'));
verifyEqual(testCase, contract.selectors.channelParam, 'instanceChannelName');
verifyEqual(testCase, contract.resources.in(1).symbol, 'frame_local_instances');
verifyEqual(testCase, [contract.resources.in.required], [true false false false]);
verifyTrue(testCase, contract.capabilities.outputsChannels);
verifyTrue(testCase, contract.capabilities.roiChannels);
verifyEqual(testCase, {contract.out.name}, {'roiList','dataSeries','objects','channels'});
verifyEqual(testCase, {contract.resources.out.role}, {'tracking','lineage','cellular_objects'});
verifyEqual(testCase, contract.resources.out(1).param, 'outputTrackChannelName');
verifyEqual(testCase, contract.semantics.inputIdentity, 'frame_local_instances');
verifyEqual(testCase, contract.semantics.outputIdentity, 'stable_tracks');
end

function testCompositeFrozenStateRequiresBrightfield(testCase)
contract = cellLatentModel.moduleContract(struct( ...
    'backend','causal_composite','stateUpdateMode','promoted_frozen_bf'));
verifyEqual(testCase, [contract.resources.in.required], [true true false false]);
verifyEqual(testCase, contract.resources.in(2).param, 'brightfieldChannelName');
end

function testChoiceCellsAndInvalidValuesPreserveCompatibility(testCase)
params = struct();
params.backend = {'legacy', '', 'Causal Composite', ''};
params.stateUpdateMode = {'none','promoted-frozen-bf'};
contract = cellLatentModel.moduleContract(params);
verifyEqual(testCase, contract.resources.in(1).symbol, 'frame_local_instances');
verifyTrue(testCase, contract.resources.in(2).required);

params.backend = 'temporal-lineage';
params.temporalVariant = {'temporal_geometry','all observed'};
contract = cellLatentModel.moduleContract(params);
verifyEqual(testCase, contract.binding.selectorKeys, ...
    {'trackChannelName','nucleusChannelName','budneckChannelName'});

params.backend = 'unknown';
contract = cellLatentModel.moduleContract(params);
verifyEqual(testCase, contract.binding.selectorKeys, {'trackChannelName','gfpChannelName'});
params.backend = 'causal_composite';
params.stateUpdateMode = 'unknown';
contract = cellLatentModel.moduleContract(params);
verifyFalse(testCase, contract.resources.in(2).required);
end

function testStaticOrderAndSummaryStayCompatible(testCase)
contract = cellLatentModel.moduleContract(struct('backend','causal_composite'));
spec = cellLatentModel.executionSpec();
semanticKeys = {'backend','temporalVariant','frameIntervalMinutes', ...
    'causalSolverFeedback','materializeCellStates','primaryStateAxis', ...
    'statePositiveThreshold','stateNegativeThreshold'};
verifyEqual(testCase, contract.parameters.static, ...
    unique([semanticKeys spec.staticKeys], 'stable'));
verifyEqual(testCase, contract.summary, spec.summary);
verifyEmpty(testCase, contract.selectors.channelsParam);
verifyEmpty(testCase, contract.selectors.framesParam);
verifyEmpty(testCase, contract.binding.exactCount);
verifyEmpty(testCase, contract.binding.defaultCount);
end

function testMetadataDoesNotResolveArtifactsOrChangeSession(testCase)
sessionPath = path;
sessionFolder = pwd;
randomState = rng;
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder)); %#ok<NASGU>
params = struct('backend','causal_composite','stateUpdateMode','promoted_frozen_bf', ...
    'pythonExecutable',fullfile(folder,'missing-python.exe'), ...
    'runtimeCodeRoot',fullfile(folder,'missing-runtime'), ...
    'modelPath',fullfile(folder,'missing-model.pt'), ...
    'compositeManifestPath',fullfile(folder,'missing-composite.json'), ...
    'modelReleaseChannelPath',fullfile(folder,'missing-release.json'));
before = params;
contract = cellLatentModel.moduleContract(params);
verifyTrue(testCase, isscalar(contract));
verifyEqual(testCase, params, before);
verifyEqual(testCase, path, sessionPath);
verifyEqual(testCase, pwd, sessionFolder);
verifyEqual(testCase, rng, randomState);
contents = dir(folder);
verifyEmpty(testCase, contents(~ismember({contents.name},{'.','..'})));
end
