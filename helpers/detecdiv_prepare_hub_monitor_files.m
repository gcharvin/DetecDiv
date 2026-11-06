function archivePath = detecdiv_prepare_hub_monitor_files(runPath)
% Preserve previous monitor output before submitting a new Hub invocation.
% A reused pipelineRun directory must not replay the previous job's failure.
runPath = char(string(runPath));
archivePath = '';
if isempty(runPath)
    error('detecdiv:MissingRunPath', 'Save the pipeline run before submitting it to the Hub.');
end
names = {'worker_console.log', 'progress.json'};
for i = 1:numel(names)
    source = fullfile(runPath, names{i});
    if exist(source, 'file') ~= 2
        continue;
    end
    if isempty(archivePath)
        [~, token] = fileparts(tempname);
        archivePath = fullfile(runPath, 'monitor_history', token);
        [ok, message] = mkdir(archivePath);
        if ~ok
            error('detecdiv:MonitorArchiveFailed', '%s', message);
        end
    end
    [ok, message] = movefile(source, fullfile(archivePath, names{i}));
    if ~ok
        error('detecdiv:MonitorArchiveFailed', ...
            'Cannot archive previous Hub monitor file %s: %s', source, message);
    end
end
end
