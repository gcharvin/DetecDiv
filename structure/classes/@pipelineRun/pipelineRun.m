classdef pipelineRun < handle
    properties
        id = []
        runId = ''
        templateId = ''
        templatePath = ''
        pipelineRef = struct('id','','path','','version','')
        projectPath = ''
        projectName = ''
        targetRef = struct('type','shallow','projectPath','','projectName','','fovIds',[], ...
            'roiIds',{{}},'classiPath','','notes','')
        path = ''
        status = 'new' % new/running/done/failed
        ctx = struct()
        outputs = struct()
        progress = struct()
        description = ''
        createdAt = ''
        updatedAt = ''
        history = table('Size',[1 3], ...
            'VariableTypes',{'datetime','string','string'}, ...
            'VariableNames',{'Date','Category','Message'})
    end

    methods
        function obj = pipelineRun(projectPath, runId, id)
            if nargin < 1
                projectPath = '';
                runId = '';
                id = 1;
            end
            if nargin < 2 || isempty(runId)
                runId = 'pipeline_run';
            end
            if nargin < 3 || isempty(id)
                id = 1;
            end

            obj.id = id;
            obj.runId = runId;
            obj.projectPath = projectPath;

            if ~isempty(projectPath)
                obj.path = fullfile(projectPath, 'pipeline', runId);
                if ~exist(obj.path, 'dir')
                    mkdir(obj.path);
                end

                [~, projectName] = fileparts(projectPath);
                obj.projectName = projectName;
                obj.targetRef.projectPath = projectPath;
                obj.targetRef.projectName = projectName;
            end

            obj.createdAt = char(datetime('now'));
            obj.updatedAt = obj.createdAt;
        end

        function [path,file] = getPath(obj)
            path = obj.path;
            file = obj.runId;
        end

        function obj = setPath(obj, pathe, file)
            if nargin < 2
                return;
            end
            obj.path = pathe;
            if nargin >= 3 && ~isempty(file)
                obj.runId = file;
            end
        end

        function log(obj, msg, category)
            if nargin < 3, category = "Info"; end
            try
                obj.history(end+1,:) = {datetime('now'), string(category), string(msg)};
            catch
            end
        end
    end
end
