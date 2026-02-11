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
    S.templateId = runObj.templateId;
    S.templatePath = runObj.templatePath;
    S.projectPath = runObj.projectPath;
    S.projectName = runObj.projectName;
    S.description = runObj.description;
    S.status = runObj.status;
    S.ctx = runObj.ctx;
    S.outputs = runObj.outputs;
    S.progress = runObj.progress;
    S.createdAt = runObj.createdAt;
    S.updatedAt = char(datetime('now'));
end
