function pipelineRunSave(runObj)
% pipelineRunSave  Save pipeline run to JSON in its folder.

    if nargin < 1 || isempty(runObj)
        return;
    end

    [path, ~] = runObj.getPath;
    if isempty(path)
        error('pipelineRunSave:NoPath','Pipeline run path is empty.');
    end
    if ~exist(path,'dir')
        mkdir(path);
    end

    jsonFile = fullfile(path, 'run.json');

    runObj.updatedAt = char(datetime('now'));
    S = pipelineRunToStruct(runObj);

    try
        txt = jsonencode(S, 'PrettyPrint', true);
    catch
        txt = jsonencode(S);
    end

    fid = fopen(jsonFile, 'w');
    if fid < 0
        error('pipelineRunSave:IO','Unable to write %s', jsonFile);
    end
    fwrite(fid, txt, 'char');
    fclose(fid);

    writeRunSummaryFile(runObj, S, path);

    runObj.log(['Pipeline run saved to ' jsonFile], 'Save');
    fprintf('Pipeline run saved: %s\n', jsonFile);
end

function S = pipelineRunToStruct(runObj)
    S = struct();
    S.runId = runObj.runId;
    S.id = runObj.id;

    S.pipelineRef = getOrDefaultStruct(runObj, 'pipelineRef', struct('id','','path','','version',''));
    S.targetRef = getOrDefaultStruct(runObj, 'targetRef', struct('type','shallow','projectPath','','projectName','', ...
        'fovIds',[],'roiIds',{{}},'classiPath','','notes',''));

    % compatibility keys
    S.templateId = runObj.templateId;
    S.templatePath = runObj.templatePath;
    S.projectPath = runObj.projectPath;
    S.projectName = runObj.projectName;

    S.description = runObj.description;
    S.status = runObj.status;
    S.ctx = sanitizeForJson(runObj.ctx);
    S.outputs = sanitizeForJson(runObj.outputs);
    S.progress = sanitizeForJson(runObj.progress);
    S.createdAt = runObj.createdAt;
    S.updatedAt = char(datetime('now'));
end

function S = getOrDefaultStruct(obj, fieldName, defaultValue)
    if isprop(obj, fieldName)
        S = obj.(fieldName);
        if isempty(S) || ~isstruct(S)
            S = defaultValue;
        end
    else
        S = defaultValue;
    end
end

function writeRunSummaryFile(runObj, S, runPath)
    txtFile = fullfile(runPath, 'run_summary.txt');
    txt = buildRunSummaryText(runObj, S);
    fid = fopen(txtFile, 'w');
    if fid < 0
        warning('pipelineRunSave:SummaryIO', 'Unable to write %s', txtFile);
        return;
    end
    fwrite(fid, txt, 'char');
    fclose(fid);
end

function txt = buildRunSummaryText(runObj, S)
    lines = {};
    lines{end+1} = sprintf('Run ID: %s', char(string(runObj.runId))); %#ok<AGROW>
    lines{end+1} = sprintf('Status: %s', char(string(runObj.status))); %#ok<AGROW>
    lines{end+1} = sprintf('Project: %s', char(string(getFieldOrDefault(S, 'projectPath', '')))); %#ok<AGROW>
    lines{end+1} = sprintf('Pipeline: %s', char(string(getNestedOrDefault(S, {'pipelineRef','id'}, '')))); %#ok<AGROW>
    lines{end+1} = sprintf('Created: %s', char(string(getFieldOrDefault(S, 'createdAt', '')))); %#ok<AGROW>
    lines{end+1} = sprintf('Updated: %s', char(string(getFieldOrDefault(S, 'updatedAt', '')))); %#ok<AGROW>

    report = struct();
    outputs = getFieldOrDefault(S, 'outputs', struct());
    if isstruct(outputs) && isfield(outputs, 'report') && isstruct(outputs.report)
        report = outputs.report;
    end

    if ~isempty(fieldnames(report))
        lines{end+1} = '';
        lines{end+1} = 'Summary'; %#ok<AGROW>
        summary = getFieldOrDefault(report, 'summary', struct());
        if isstruct(summary) && ~isempty(fieldnames(summary))
            keys = {'totalNodes','doneNodes','skippedNodes','failedNodes'};
            for i = 1:numel(keys)
                if isfield(summary, keys{i})
                    lines{end+1} = sprintf('  %s: %s', keys{i}, valueToChar(summary.(keys{i}))); %#ok<AGROW>
                end
            end
        end
        if isfield(report, 'startedAt')
            lines{end+1} = sprintf('  startedAt: %s', valueToChar(report.startedAt)); %#ok<AGROW>
        end
        if isfield(report, 'endedAt')
            lines{end+1} = sprintf('  endedAt: %s', valueToChar(report.endedAt)); %#ok<AGROW>
        end

        nodeRuns = getFieldOrDefault(report, 'nodeRuns', struct([]));
        if isstruct(nodeRuns) && ~isempty(nodeRuns)
            lines{end+1} = '';
            lines{end+1} = 'Nodes'; %#ok<AGROW>
            for i = 1:numel(nodeRuns)
                row = nodeRuns(i);
                base = sprintf('- %s [%s] status=%s', ...
                    valueToChar(getFieldOrDefault(row,'nodeId','')), ...
                    valueToChar(getFieldOrDefault(row,'nodeType','')), ...
                    valueToChar(getFieldOrDefault(row,'status','')));
                pol = sprintf(' runPolicy=%s existingPolicy=%s', ...
                    valueToChar(getFieldOrDefault(row,'runPolicy','')), ...
                    valueToChar(getFieldOrDefault(row,'existingPolicy','')));
                dur = sprintf(' duration=%.3fs', double(getFieldOrDefault(row,'durationSec',0)));
                delta = '';
                before = getFieldOrDefault(row,'before', struct());
                after = getFieldOrDefault(row,'after', struct());
                if isstruct(before) && isstruct(after) && isfield(before,'fovCount') && isfield(after,'fovCount') ...
                        && isfield(before,'roiCount') && isfield(after,'roiCount')
                    delta = sprintf(' fov=%d->%d roi=%d->%d', ...
                        double(before.fovCount), double(after.fovCount), ...
                        double(before.roiCount), double(after.roiCount));
                end
                lines{end+1} = [base pol dur delta]; %#ok<AGROW>
                msg = valueToChar(getFieldOrDefault(row,'message',''));
                if ~isempty(strtrim(msg))
                    lines{end+1} = ['  message: ' msg]; %#ok<AGROW>
                end
            end
        end
    end

    if isprop(runObj, 'history') && ~isempty(runObj.history)
        lines{end+1} = '';
        lines{end+1} = 'History'; %#ok<AGROW>
        try
            startIdx = max(1, height(runObj.history) - 20 + 1);
            for i = startIdx:height(runObj.history)
                row = runObj.history(i,:);
                lines{end+1} = sprintf('- %s [%s] %s', ...
                    char(string(row.Date)), char(string(row.Category)), char(string(row.Message))); %#ok<AGROW>
            end
        catch
        end
    end

    txt = strjoin(lines, newline);
    txt = [txt newline];
end

function v = getFieldOrDefault(S, name, defaultVal)
    v = defaultVal;
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        v = S.(name);
    end
end

function v = getNestedOrDefault(S, pathParts, defaultVal)
    v = defaultVal;
    cur = S;
    for i = 1:numel(pathParts)
        if ~isstruct(cur) || ~isfield(cur, pathParts{i})
            return;
        end
        cur = cur.(pathParts{i});
    end
    if ~isempty(cur)
        v = cur;
    end
end

function txt = valueToChar(v)
    if isstring(v)
        txt = char(string(v));
    elseif ischar(v)
        txt = v;
    elseif isnumeric(v) || islogical(v)
        txt = num2str(v);
    else
        try
            txt = char(string(v));
        catch
            txt = '';
        end
    end
end

function out = sanitizeForJson(in)
    if isempty(in)
        out = in;
        return;
    end

    if isstruct(in)
        out = in;
        fn = fieldnames(in);
        for k = 1:numel(in)
            for i = 1:numel(fn)
                out(k).(fn{i}) = sanitizeForJson(in(k).(fn{i}));
            end
        end
        return;
    end

    if iscell(in)
        out = cell(size(in));
        for i = 1:numel(in)
            out{i} = sanitizeForJson(in{i});
        end
        return;
    end

    if isnumeric(in) || islogical(in) || ischar(in)
        out = in;
        return;
    end

    if isstring(in)
        out = cellstr(in);
        return;
    end

    if isdatetime(in)
        out = char(in);
        return;
    end

    if isa(in,'handle')
        out = struct('className', class(in), 'note', 'handle omitted for JSON');
        return;
    end

    try
        jsonencode(in);
        out = in;
    catch
        out = struct('className', class(in), 'note', 'value omitted for JSON');
    end
end
