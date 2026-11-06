function tests = testHubMonitorFiles
tests = functiontests(localfunctions);
end

function testResubmitArchivesOldFailureAndConsole(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
writeText(fullfile(root, 'progress.json'), '{"status":"failed","message":"old failure"}');
writeText(fullfile(root, 'worker_console.log'), 'previous job console');
writeText(fullfile(root, 'run.json'), '{"runId":"unchanged"}');
archive = detecdiv_prepare_hub_monitor_files(root);
verifyFalse(testCase, isfile(fullfile(root, 'progress.json')));
verifyFalse(testCase, isfile(fullfile(root, 'worker_console.log')));
verifyEqual(testCase, fileread(fullfile(archive, 'progress.json')), ...
    '{"status":"failed","message":"old failure"}');
verifyEqual(testCase, fileread(fullfile(archive, 'worker_console.log')), 'previous job console');
verifyEqual(testCase, fileread(fullfile(root, 'run.json')), '{"runId":"unchanged"}');
verifyEmpty(testCase, detecdiv_prepare_hub_monitor_files(root));
writeText(fullfile(root, 'progress.json'), '{"status":"running"}');
second = detecdiv_prepare_hub_monitor_files(root);
verifyNotEqual(testCase, archive, second);
verifyEqual(testCase, fileread(fullfile(archive, 'progress.json')), ...
    '{"status":"failed","message":"old failure"}');
end

function writeText(path, value)
fid = fopen(path, 'w');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', value);
end
