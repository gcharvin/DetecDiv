function tests = testPipelineRunJobExecutionMode
tests = functiontests(localfunctions);
end

function testLocalWorkerValidatesBundledPlugin(testCase)
[payload, cleanup] = localFixture('local_process'); %#ok<ASGLU>
repoRoot = fileparts(which('detecdiv_run_pipeline_job'));
job = batch(parcluster('Processes'), @detecdiv_run_pipeline_job_guarded, 1, {payload}, ...
    'CurrentFolder', repoRoot, 'AutoAddClientPath', false, ...
    'AutoAttachFiles', false, 'Pool', 0);
jobCleanup = onCleanup(@()delete(job)); %#ok<NASGU>
wait(job);
outputs = fetchOutputs(job);
result = outputs{1};
assert(strcmp(result.status, 'done'), result.error);
[runObj, message] = pipelineRunLoad(result.run_json_path);
assert(~isempty(runObj), message);

verifyEqual(testCase, runObj.ctx.execution.requested_mode, 'local_process');
report = runObj.outputs.report;
verifyTrue(testCase, report.okStrict, char(strjoin(string(report.errors), ' | ')));
verifyEqual(testCase, report.pluginPackages.target, 'local MATLAB execution');
verifyTrue(testCase, report.pluginPackages.accessible);
end

function testTopLevelModeIsPreservedForLegacyPayload(testCase)
[payload, cleanup] = localFixture('local_process'); %#ok<ASGLU>
payload.execution = rmfield(payload.execution, 'requested_mode');
payload.requested_mode = 'local_process';
result = detecdiv_run_pipeline_job(payload);
[runObj, message] = pipelineRunLoad(result.run_json_path);
assert(~isempty(runObj), message);

verifyEqual(testCase, runObj.ctx.execution.requested_mode, 'local_process');
verifyTrue(testCase, runObj.outputs.report.okStrict, ...
    char(strjoin(string(runObj.outputs.report.errors), ' | ')));
end

function testServerWorkerStillRejectsUnmappedWindowsPlugin(testCase)
assumeTrue(testCase, ispc);
[payload, cleanup] = localFixture('server'); %#ok<ASGLU>
result = detecdiv_run_pipeline_job(payload);
[runObj, message] = pipelineRunLoad(result.run_json_path);
assert(~isempty(runObj), message);

verifyEqual(testCase, runObj.ctx.execution.requested_mode, 'server');
report = runObj.outputs.report;
verifyFalse(testCase, report.okStrict);
verifyEqual(testCase, report.pluginPackages.target, 'Hub/server execution');
verifyEqual(testCase, report.pluginPackages.status, 'unmapped_windows_path');
verifyFalse(testCase, report.pluginPackages.accessible);
verifyTrue(testCase, any(contains(report.errors, 'Plugin package for node')));
end

function [payload, cleanup] = localFixture(mode)
root = tempname;
mkdir(root);
originalPath = path;
cleanup = onCleanup(@()localCleanup(root, originalPath));

pluginRoot = fullfile(root, 'assets', 'plugins', 'processor');
pluginDir = fullfile(pluginRoot, '+workerLocalModeProbe');
mkdir(pluginDir);
file = fullfile(pluginDir, 'process.m');
fid = fopen(file, 'w');
assert(fid >= 0);
fprintf(fid, ['function [paramout, dataout, imageout] = process(param, roiobj, ctx)\n' ...
    'error(''test:PluginExecuted'', ''Dry-run must not execute the plugin.'');\n' ...
    'end\n']);
fclose(fid);

project = shallow();
project.io = struct('path', root, 'file', 'worker_project');
project.fov.id = 'worker_fov';
project.fov.channel = {'Channel 1'};
project.fov.roi = roi('worker_roi', [1 1 4 4]);
project.fov.roi.path = fullfile(root, 'worker_project', 'worker_fov');
mkdir(project.fov.roi.path);
projectFile = fullfile(root, 'worker_project.json');
shallowProjectExportLight(project, projectFile);

pipe = pipeline(root, 'worker_plugin', 1);
pipe.nodes = struct('id', 'processor_probe_1', 'type', 'processor', ...
    'pkg', 'workerLocalModeProbe', 'func', 'workerLocalModeProbe.process', ...
    'params', struct('pkg', 'workerLocalModeProbe'), 'enabled', true, ...
    'customPackageRoot', pluginRoot, 'customPackageDir', pluginDir);
pipelineSave(pipe, 'Artifacts', false);
runObj = pipelineRunNew(project, pipe.strid, pipe.path);
payload = pipelineRunJobPayload(runObj, project, ...
    fullfile(pipe.path, 'pipeline.json'), 'RequestedMode', mode);
payload.project_ref.project_mat_path = projectFile;
payload.execution.save_project = false;
payload.execution.dry_run = true;
end

function localCleanup(root, originalPath)
path(originalPath);
if isfolder(root)
    rmdir(root, 's');
end
end
