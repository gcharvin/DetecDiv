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
