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
        runObj.description = getField(S,'description','');
        runObj.status = getField(S,'status','new');
        runObj.ctx = getField(S,'ctx',struct());
        runObj.outputs = getField(S,'outputs',struct());
        runObj.progress = getField(S,'progress',struct());
        runObj.createdAt = getField(S,'createdAt','');
        runObj.updatedAt = getField(S,'updatedAt','');
        runObj.path = inputPath;
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
