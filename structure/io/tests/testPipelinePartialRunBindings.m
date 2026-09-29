function tests = testPipelinePartialRunBindings
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function testExcludedProducerSymbolIsRejectedDespitePersistedOutput(testCase)
[pipe, ctx] = fixture();
ctx.pipelineSpec = pipe;
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
verifyFalse(testCase, ok);
verifyTrue(testCase, any(contains(validation.errors, ...
    'input instanceChannelName references excluded module classifier_cellposesam_4')));

[resolved, report] = pipelineResolveBindings(pipe, ctx, struct('allowGui', false));
verifyEqual(testCase, resolved.nodes(2).params.instanceChannelName, ...
    '@resource:segmentation:classifier_cellposesam_4');
verifyFalse(testCase, any(strcmp({report.applied.nodeId}, pipe.nodes(2).id) & ...
    strcmp({report.applied.param}, 'instanceChannelName')));
end

function testExplicitMasksAndBrightfieldValidateWithoutTrackInput(testCase)
[pipe, ctx] = fixture();
pipe.nodes(2).params.instanceChannelName = 'results_pred_cellposesam_cell';
% An old template's unused field is not an input of causal_composite.
pipe.nodes(2).params.trackChannelName = '@resource:segmentation:classifier_cellposesam_4';
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
verifyTrue(testCase, ok, strjoin(validation.errors, ' | '));
specs = validation.nodes(1).contract.resources.in;
verifyEqual(testCase, {specs(logical([specs.required])).param}, ...
    {'instanceChannelName','brightfieldChannelName'});
verifyFalse(testCase, any(strcmp({specs.param}, 'trackChannelName')));
end

function testExplicitRunOverrideReplacesTemplateSymbol(testCase)
[pipe, ctx] = fixture();
ctx.run.nodeParams = struct('id', pipe.nodes(2).id, ...
    'params', struct('instanceChannelName', 'results_pred_cellposesam_cell'));
executable = pipelineApplyRunNodeParams(pipe.nodes, ctx.run.nodeParams);
verifyEqual(testCase, executable(2).params.instanceChannelName, ...
    'results_pred_cellposesam_cell');
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
verifyTrue(testCase, ok, strjoin(validation.errors, ' | '));
verifyEqual(testCase, validation.nodes(1).params.instanceChannelName, ...
    'results_pred_cellposesam_cell');
end

function testEmptyRunBindingIsPreservedAndBlocksPartialRun(testCase)
[pipe, ctx] = fixture();
key = matlab.lang.makeValidName(pipe.nodes(2).id);
ctx.run.nodeParams.(key) = struct('instanceChannelName', '');
executable = pipelineApplyRunNodeParams(pipe.nodes, ctx.run.nodeParams);
verifyEmpty(testCase, executable(2).params.instanceChannelName);
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
verifyFalse(testCase, ok);
verifyTrue(testCase, any(contains(validation.errors, ...
    'requires an explicit existing input binding for instanceChannelName')));
end

function testBackendOverrideUsesTheCompositeInputContract(testCase)
[pipe, ctx] = fixture();
pipe.nodes(2).params.backend = 'legacy';
pipe.nodes(2).params.trackChannelName = '@resource:segmentation:classifier_cellposesam_4';
ctx.run.nodeParams = struct('id', pipe.nodes(2).id, 'params', ...
    struct('backend','causal_composite', ...
    'instanceChannelName','results_pred_cellposesam_cell'));
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
verifyTrue(testCase, ok, strjoin(validation.errors, ' | '));
verifyFalse(testCase, any(strcmp( ...
    {validation.nodes(1).contract.resources.in.param}, 'trackChannelName')));
end

function testPrefilteredSnapshotStillRequiresExplicitExternalInputs(testCase)
[pipe, ctx] = fixture();
ctx.pipelineSpec = pipe;
pipe.nodes = pipe.nodes(2);
pipe.edges = struct([]);
pipe.nodes.params.instanceChannelName = '';
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
verifyFalse(testCase, ok);
verifyTrue(testCase, any(contains(validation.errors, ...
    'requires an explicit existing input binding for instanceChannelName')));
end

function testGenericRuntimeSourceDoesNotEraseExplicitBrightfield(testCase)
[pipe, ctx] = fixture();
key = matlab.lang.makeValidName(pipe.nodes(2).id);
ctx.run.nodeParams.(key) = struct('brightfieldChannelName', '@source');
executable = pipelineApplyRunNodeParams(pipe.nodes, ctx.run.nodeParams);
verifyEqual(testCase, executable(2).params.brightfieldChannelName, 'BF');
end

function testOptionalSymbolToExcludedProducerAlsoBlocks(testCase)
[pipe, ctx] = fixture();
pipe.nodes(2).params.instanceChannelName = 'results_pred_cellposesam_cell';
pipe.nodes(2).params.nucleusChannelName = ...
    '@resource:derived_roi_image:processor_combine_0';
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
verifyFalse(testCase, ok);
verifyTrue(testCase, any(contains(validation.errors, ...
    'input nucleusChannelName references excluded module processor_combine_0')));
end

function testUnconfiguredExternalInputIsNotAutomaticallyChosen(testCase)
[pipe, ctx] = fixture();
pipe.nodes(2).params.instanceChannelName = '';
pipe.nodes(2).params.brightfieldChannelName = '';
pipe.nodes(2).params.stateUpdateMode = 'none';
ctx.channels = {'results_pred_cellposesam_cell'};
ctx.roiChannels = ctx.channels;
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
verifyFalse(testCase, ok);
verifyTrue(testCase, any(contains(validation.errors, ...
    'requires an explicit existing input binding for instanceChannelName')));
[resolved, report] = pipelineResolveBindings(pipe, ctx, struct('allowGui', false));
verifyEmpty(testCase, resolved.nodes(2).params.instanceChannelName);
verifyFalse(testCase, any(strcmp({report.applied.param}, 'instanceChannelName')));
end

function testSymbolBetweenSelectedModulesStillResolvesInPartialRun(testCase)
[pipe, ctx] = fixture();
omitted = node('roiextract_3', 'roiExtract', 'roiExtract', ...
    struct('extractChannels', {{'BF'}}));
pipe.nodes = [omitted pipe.nodes];
ctx.run.selectedNodes = {'classifier_cellposesam_4','classifier_celllatentmodel_5'};
ctx.channels = {'BF'};
ctx.roiChannels = {'BF'};
ctx.masks = {};
[resolved, report] = pipelineResolveBindings(pipe, ctx, struct('allowGui', false));
verifyEqual(testCase, resolved.nodes(3).params.instanceChannelName, ...
    'results_pred_cellposesam_cell');
verifyTrue(testCase, any(strcmp({report.applied.nodeId}, pipe.nodes(3).id) & ...
    strcmp({report.applied.param}, 'instanceChannelName')));
[ok, validation] = validatePipeline(resolved, ctx, struct('allowGui', false));
verifyTrue(testCase, ok, strjoin(validation.errors, ' | '));
end

function testLegacyModuleOutputSymbolAlsoBlocks(testCase)
[pipe, ctx] = fixture();
pipe.nodes(2).params.instanceChannelName = '@classifier_cellposesam_4.channels';
[ok, validation] = validatePipeline(pipe, ctx, struct('allowGui', false));
verifyFalse(testCase, ok);
verifyTrue(testCase, any(contains(validation.errors, ...
    'input instanceChannelName references excluded module classifier_cellposesam_4')));
end

function [pipe, ctx] = fixture()
cellpose = node('classifier_cellposesam_4', 'classifier', 'cellposesam', ...
    struct('pkg','cellposesam','channel','BF','outputType','segmentation', ...
    'outputName','pred_cellposesam'));
latent = node('classifier_celllatentmodel_5', 'classifier', 'cellLatentModel', ...
    struct('pkg','cellLatentModel','backend','causal_composite', ...
    'instanceChannelName','@resource:segmentation:classifier_cellposesam_4', ...
    'brightfieldChannelName','BF','stateUpdateMode','promoted_frozen_bf', ...
    'frameIntervalMinutes',5,'outputTrackChannelName','pred_latent_tracks', ...
    'outputFamilyName','pred_latent_lineage'));
pipe = struct('nodes',[cellpose latent], 'edges', ...
    struct('from',cellpose.id,'to',latent.id,'fromPort','','toPort','','condition',''), ...
    'branches',struct([]));
ctx = struct('images',1,'roiList',1, ...
    'channels',{{'BF','results_pred_cellposesam_cell'}}, ...
    'roiChannels',{{'BF','results_pred_cellposesam_cell'}}, ...
    'masks',{{'results_pred_cellposesam_cell'}}, ...
    'run',struct('selectedNodes',{{latent.id}}));
end

function value = node(id, type, pkg, params)
if strcmpi(type, 'classifier')
    fun = [pkg '.classify'];
else
    fun = [pkg '.process'];
end
value = struct('id',id,'name',id,'type',type,'pkg',pkg,'func',fun, ...
    'params',params,'enabled',true);
end
