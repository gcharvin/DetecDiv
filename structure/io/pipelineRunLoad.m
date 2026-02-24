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
