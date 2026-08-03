function tests = testPipelineRunJobJsonProjectFallback
tests = functiontests(localfunctions);
end

function testLegacyMatReferenceLoadsJsonSibling(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() localRemoveTree(root)); %#ok<NASGU>

projectName = 'json_only_project';
projectDir = fullfile(root, projectName);
mkdir(projectDir);

shallowObj = shallow();
shallowObj.io.path = root;
shallowObj.io.file = projectName;
jsonPath = fullfile(root, [projectName '.json']);
matPath = fullfile(root, [projectName '.mat']);
shallowProjectExportLight(shallowObj, jsonPath);

resultPath = fullfile(root, 'result.json');
payload = struct( ...
    'job_kind', 'pipeline_run', ...
    'project_ref', struct('project_mat_path', matPath), ...
    'pipeline_ref', struct('pipeline_json_path', fullfile(root, 'missing_pipeline.json')), ...
    'execution', struct('result_json_path', resultPath, 'save_project', false));

try
    detecdiv_run_pipeline_job(payload);
catch ME
    verifyEqual(testCase, ME.identifier, 'detecdiv_run_pipeline_job:ExecutionFailed');
end

verifyTrue(testCase, isfile(resultPath));
result = jsondecode(fileread(resultPath));
verifyEqual(testCase, char(string(result.project_mat_path)), jsonPath);
verifyTrue(testCase, contains(result.error, 'pipeline_json_path is required'));
verifyFalse(testCase, contains(result.error, 'Project file not found'));
end

function localRemoveTree(pathText)
if isfolder(pathText)
    rmdir(pathText, 's');
end
end
