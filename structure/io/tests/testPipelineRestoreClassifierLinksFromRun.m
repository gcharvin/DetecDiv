function tests = testPipelineRestoreClassifierLinksFromRun
%TESTPIPELINERESTORECLASSIFIERLINKSFROMRUN Reopen run-owned model links.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(repoRoot,'structure','io'));
end

function testRunLinkRestoresLatentWithoutChangingCellposeOrOtherParams(testCase)
nodes = [node('classifier_cellposesam_4','classifier','cellposesam', ...
    struct('modulePath','X:\matlab\ClassiRepository\cellpose_4\', ...
    'moduleId','cellpose_4','outputName','pred_cellpose')); ...
    node('classifier_celllatentmodel_5','classifier','cellLatentModel', ...
    struct('backend','causal_composite','moduleVar','stale_workspace_var'))];
saved = [node('classifier_cellposesam_4','classifier','cellposesam', ...
    struct('modulePath','X:\matlab\ClassiRepository\cellpose_4\', ...
    'moduleId','cellpose_4')); ...
    node('classifier_celllatentmodel_5','classifier','cellLatentModel', ...
    struct('modulePath', ...
    'X:\matlab\ClassiRepository\latent-v54-runtime\classifier\latent_model_1\', ...
    'moduleId','latent_model_1'))];
ctx = struct('pipelineSpec',struct('nodes',saved));

[restored,ids] = pipelineRestoreClassifierLinksFromRun(nodes,ctx);

verifyEqual(testCase,ids,{'classifier_celllatentmodel_5'});
verifyEqual(testCase,restored(1).params,nodes(1).params);
verifyEqual(testCase,restored(2).params.modulePath, ...
    saved(2).params.modulePath);
verifyEqual(testCase,restored(2).params.moduleId,'latent_model_1');
verifyEqual(testCase,restored(2).params.backend,'causal_composite');
verifyFalse(testCase,isfield(restored(2).params,'moduleVar'));
end

function testMissingRunSnapshotLeavesTemplateUntouched(testCase)
nodes = node('latent','classifier','cellLatentModel', ...
    struct('modulePath','template-model','moduleId','template'));
[restored,ids] = pipelineRestoreClassifierLinksFromRun(nodes,struct());
verifyEqual(testCase,restored,nodes);
verifyEmpty(testCase,ids);
end

function testDifferentPackageCannotReplaceClassifierLink(testCase)
nodes = node('classifier_1','classifier','cellposesam', ...
    struct('modulePath','cellpose-model','moduleId','cellpose'));
saved = node('classifier_1','classifier','cellLatentModel', ...
    struct('modulePath','latent-model','moduleId','latent'));
ctx = struct('pipelineSpec',struct('nodes',saved));
[restored,ids] = pipelineRestoreClassifierLinksFromRun(nodes,ctx);
verifyEqual(testCase,restored,nodes);
verifyEmpty(testCase,ids);
end

function value = node(id,type,pkg,params)
value = struct('id',id,'type',type,'pkg',pkg,'params',params);
end
