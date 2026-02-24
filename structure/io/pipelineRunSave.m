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
