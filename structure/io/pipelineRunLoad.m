function [runObj, msg] = pipelineRunLoad(inputPath)
% pipelineRunLoad  Load pipeline run from JSON file or folder.

    msg = '';
    runObj = [];

    if nargin == 0 || isempty(inputPath)
        [file, path] = uigetfile('run.json', 'Select run.json', pwd);
        if isequal(file, 0)
            msg = 'User cancelled.';
            return;
        end
        inputPath = fullfile(path, file);
    end

    if exist(inputPath, 'dir')
        jsonFile = fullfile(inputPath, 'run.json');
    else
        jsonFile = inputPath;
        inputPath = fileparts(jsonFile);
    end

    if ~exist(jsonFile,'file')
        msg = ['Pipeline run JSON not found: ' jsonFile];
        return;
    end

    txt = fileread(jsonFile);
    S = jsondecode(txt);

    runObj = pipelineRun('', '', 1);
    try
        runObj.id = getField(S,'id',1);
        runObj.runId = getField(S,'runId','pipeline_run');

        runObj.templateId = getField(S,'templateId','');
        runObj.templatePath = getField(S,'templatePath','');
        runObj.projectPath = getField(S,'projectPath','');
        runObj.projectName = getField(S,'projectName','');

        runObj.pipelineRef = getField(S,'pipelineRef', struct('id','','path','','version',''));
        runObj.targetRef = getField(S,'targetRef', struct('type','shallow','projectPath','','projectName','', ...
            'fovIds',[],'roiIds',{{}},'classiPath','','notes',''));

        % backfill refs from compatibility keys
        if ~isfield(runObj.pipelineRef,'id') || isempty(runObj.pipelineRef.id)
            runObj.pipelineRef.id = runObj.templateId;
        end
        if ~isfield(runObj.pipelineRef,'path') || isempty(runObj.pipelineRef.path)
            runObj.pipelineRef.path = runObj.templatePath;
        end
        if ~isfield(runObj.pipelineRef,'version')
            runObj.pipelineRef.version = '';
        end

        if ~isfield(runObj.targetRef,'type') || isempty(runObj.targetRef.type)
            runObj.targetRef.type = 'shallow';
        end
        if ~isfield(runObj.targetRef,'projectPath') || isempty(runObj.targetRef.projectPath)
            runObj.targetRef.projectPath = runObj.projectPath;
        end
        if ~isfield(runObj.targetRef,'projectName') || isempty(runObj.targetRef.projectName)
            runObj.targetRef.projectName = runObj.projectName;
        end
        if ~isfield(runObj.targetRef,'fovIds'), runObj.targetRef.fovIds = []; end
        if ~isfield(runObj.targetRef,'roiIds'), runObj.targetRef.roiIds = {}; end
        if ~isfield(runObj.targetRef,'classiPath'), runObj.targetRef.classiPath = ''; end
        if ~isfield(runObj.targetRef,'notes'), runObj.targetRef.notes = ''; end

        runObj.description = getField(S,'description','');
        runObj.status = getField(S,'status','new');
        runObj.ctx = getField(S,'ctx',struct());
        runObj.outputs = getField(S,'outputs',struct());
        runObj.progress = getField(S,'progress',struct());
        runObj.createdAt = getField(S,'createdAt','');
        runObj.updatedAt = getField(S,'updatedAt','');
        runObj.path = inputPath;
        runObj = reconcileRunFromEventLog(runObj);
    catch ME
        msg = ME.message;
        runObj = [];
        return;
    end

    runObj.log(['Pipeline run loaded from ' jsonFile], 'Load');
end

function v = getField(S, name, default)
    if isfield(S, name)
        v = S.(name);
    else
        v = default;
    end
end

function runObj = reconcileRunFromEventLog(runObj)
    try
        events = pipelineRunEventsRead(runObj);
        events = latestRunAttemptEvents(events);
        if isempty(events)
            return;
        end
        status = eventRunStatus(events);
        if ~isempty(status)
            runObj.status = status;
        end
        lastTs = eventText(events(end), 'ts');
        if ~isempty(lastTs)
            runObj.updatedAt = lastTs;
        end
        summary = summarizeLatestEvents(events);
        if ~isstruct(runObj.progress)
            runObj.progress = struct();
        end
        runObj.progress = summary;
        if ~isstruct(runObj.outputs)
            runObj.outputs = struct();
        end
        if ~isfield(runObj.outputs, 'eventSummary') || isempty(runObj.outputs.eventSummary)
            runObj.outputs.eventSummary = summary;
        end
    catch
    end
end

function events = latestRunAttemptEvents(events)
    if isempty(events) || ~isfield(events, 'type')
        return;
    end
    types = string({events.type});
    starts = find(types == "run_start");
    if isempty(starts)
        return;
    end
    events = events(starts(end):end);
end

function status = eventRunStatus(events)
    status = '';
    if isempty(events) || ~isfield(events, 'type')
        return;
    end
    types = string({events.type});
    if any(types == "run_done")
        status = 'done';
    elseif any(types == "run_cancelled")
        status = 'cancelled';
    elseif any(types == "run_failed")
        status = 'failed';
    elseif any(types == "node_start")
        status = 'running_or_interrupted';
    end
end

function summary = summarizeLatestEvents(events)
    summary = struct('totalNodes', 0, 'doneNodes', 0, 'skippedNodes', 0, ...
        'failedNodes', 0, 'cancelledNodes', 0, 'startedAt', '', 'endedAt', '');
    if isempty(events)
        return;
    end
    if isfield(events, 'type')
        types = string({events.type});
        summary.doneNodes = sum(types == "node_done");
        summary.skippedNodes = sum(types == "node_skipped");
        summary.failedNodes = sum(types == "node_failed");
        summary.cancelledNodes = sum(types == "node_cancelled");
    end
    if isfield(events, 'NodeId')
        ids = {};
        for i = 1:numel(events)
            id = eventText(events(i), 'NodeId');
            if ~isempty(strtrim(id))
                ids{end+1} = id; %#ok<AGROW>
            end
        end
        summary.totalNodes = numel(unique(ids, 'stable'));
    else
        summary.totalNodes = summary.doneNodes + summary.skippedNodes + summary.failedNodes + summary.cancelledNodes;
    end
    if isfield(events, 'ts')
        summary.startedAt = eventText(events(1), 'ts');
        summary.endedAt = eventText(events(end), 'ts');
    end
end

function txt = eventText(evt, fieldName)
    txt = '';
    try
        if isfield(evt, fieldName) && ~isempty(evt.(fieldName))
            txt = char(string(evt.(fieldName)));
        end
    catch
        txt = '';
    end
end
