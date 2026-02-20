function runObj = pipelineRunNew(shallowObj, templateId, templatePath, varargin)
% pipelineRunNew  Create and attach a new pipeline run to a project.

    if nargin < 1 || isempty(shallowObj) || ~isa(shallowObj,'shallow')
        error('pipelineRunNew:MissingProject','A shallow project is required.');
    end
    if nargin < 2 || isempty(templateId)
        templateId = 'pipeline';
    end
    if nargin < 3
        templatePath = '';
    end

    % optional args
    runId = '';
    description = '';
    ctx = struct();
    status = 'new';

    for i = 1:numel(varargin)
        if strcmpi(varargin{i}, 'runId')
            runId = varargin{i+1};
        elseif strcmpi(varargin{i}, 'description')
            description = varargin{i+1};
        elseif strcmpi(varargin{i}, 'ctx')
            ctx = varargin{i+1};
        elseif strcmpi(varargin{i}, 'status')
            status = varargin{i+1};
        end
    end

    % compute runId if missing
    if isempty(runId)
        runId = nextRunId(shallowObj, templateId);
    end

    projectPath = fullfile(shallowObj.io.path, shallowObj.io.file);
    runObj = pipelineRun(projectPath, runId, numel(shallowObj.processing.pipeline)+1);
    runObj.projectPath = projectPath;
    runObj.projectName = shallowObj.io.file;
    runObj.templateId = templateId;
    runObj.templatePath = templatePath;
    runObj.description = description;
    runObj.ctx = ctx;
    runObj.status = status;

    % attach to project
    if ~isfield(shallowObj.processing,'pipeline') || isempty(shallowObj.processing.pipeline)
        shallowObj.processing.pipeline = pipelineRun.empty;
    end
    shallowObj.processing.pipeline(end+1) = runObj;
end

function runId = nextRunId(shallowObj, templateId)
    runId = [templateId '_1'];
    if ~isfield(shallowObj.processing,'pipeline') || isempty(shallowObj.processing.pipeline)
        return;
    end
    existing = shallowObj.processing.pipeline;
    names = arrayfun(@(p) p.runId, existing, 'UniformOutput', false);
    n = 1;
    while any(strcmp(names, [templateId '_' num2str(n)]))
        n = n + 1;
    end
    runId = [templateId '_' num2str(n)];
end
