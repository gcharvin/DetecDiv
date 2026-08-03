function tests = testPipelineRunJobPayloadSelection
tests = functiontests(localfunctions);
end

function testClassifierRoiSelectionComesFromContext(testCase)
runObj = localClassifierRun();
runObj.ctx.sel = struct('fovs', [], 'frames', [], 'rois', 1, 'channels', {{}});

payload = pipelineRunJobPayload(runObj, [], 'pipeline.json');

verifyEqual(testCase, payload.run_request.selection.rois, 1);
roundTrip = jsondecode(jsonencode(payload));
verifyEqual(testCase, roundTrip.run_request.selection.rois, 1);
end

function testClassifierRoiSelectionFallsBackToTargetRef(testCase)
runObj = localClassifierRun();
runObj.ctx.sel = struct('fovs', [], 'frames', [], 'rois', [], 'channels', {{}});
runObj.targetRef.roiIds = 1;

payload = pipelineRunJobPayload(runObj, [], 'pipeline.json');

verifyEqual(testCase, payload.run_request.selection.rois, 1);
roundTrip = jsondecode(jsonencode(payload));
verifyEqual(testCase, roundTrip.run_request.selection.rois, 1);
end

function testPayloadKeepsCompleteTemplateSeparateFromExecutableSnapshot(testCase)
runObj = localClassifierRun();
templateDir = fullfile(tempdir, 'detecdiv_complete_template');
runObj.pipelineRef = struct('id', 'complete_pipeline', ...
    'path', templateDir, 'version', '1.0');
runObj.templatePath = fullfile(templateDir, 'pipeline.json');

payload = pipelineRunJobPayload(runObj, [], fullfile('run', 'pipeline_snapshot', 'pipeline.json'));

verifyEqual(testCase, payload.pipeline_ref.pipeline_json_path, ...
    fullfile('run', 'pipeline_snapshot', 'pipeline.json'));
verifyEqual(testCase, payload.pipeline_ref.template_json_path, ...
    fullfile(templateDir, 'pipeline.json'));
end

function runObj = localClassifierRun()
runObj = pipelineRun('', 'selection_test', 1);
runObj.targetRef = struct( ...
    'type', 'classi', ...
    'projectPath', '', ...
    'projectName', '', ...
    'fovIds', [], ...
    'roiIds', [], ...
    'classiPath', 'C:\classifier', ...
    'notes', 'test');
runObj.ctx = struct( ...
    'run', struct( ...
        'inputSource', 'classifier attached rois', ...
        'selectedNodes', {{'classifier_cellposesam_1'}}, ...
        'nodeParams', struct('id', {}, 'params', {})), ...
    'io', struct('existingPolicy', 'skip'));
end
