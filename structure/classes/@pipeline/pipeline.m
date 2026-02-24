classdef pipeline < handle
    properties
        id = []
        path = ''
        strid = ''
        description = ''
        version = '1.0'
        nodes = struct([])
        edges = struct([])
        branches = struct([])
        runState = struct()
        runProfiles = struct()
        history = table('Size',[1 3], ...
            'VariableTypes',{'datetime','string','string'}, ...
            'VariableNames',{'Date','Category','Message'})
    end

    methods
        function obj = pipeline(path,name,id)
            if nargin < 1
                path = '';
                name = '';
                id = 1;
            end
            if nargin < 2 || isempty(name)
                name = 'pipeline';
            end
            if nargin < 3 || isempty(id)
                id = 1;
            end

            obj.id = id;
            obj.strid = char(string(name));
            obj.path = path;

            if ~isempty(path)
                if ~exist(path,'dir')
                    mkdir(path);
                end
                if ~exist(fullfile(path, obj.strid),'dir')
                    mkdir(path, obj.strid);
                end
                obj.path = fullfile(path, obj.strid);
            end
        end

        function [path,file] = getPath(obj)
            path = obj.path;
            file = obj.strid;
        end

        function obj = setPath(obj, pathe, file)
            if nargin < 2
                return;
            end
            obj.path = pathe;
            if nargin >= 3 && ~isempty(file)
                obj.strid = file;
            end
        end


        function [runs, idx] = findDependentRuns(obj, shallowObj)
            % findDependentRuns  Return project runs linked to this pipeline template.
            runs = pipelineRun.empty;
            idx = [];

            if nargin < 2 || isempty(shallowObj) || ~isa(shallowObj,'shallow')
                return;
            end
            if ~isfield(shallowObj.processing,'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
                return;
            end

            for i = 1:numel(shallowObj.processing.pipelineRun)
                pr = shallowObj.processing.pipelineRun(i);
                if obj.isLinked(pr, obj)
                    runs(end+1) = pr; %#ok<AGROW>
                    idx(end+1) = i; %#ok<AGROW>
                end
            end
        end

        function tf = isLinked(~, runObj, pipeObj)
            tf = false;

            if isprop(runObj,'pipelineRef') && isstruct(runObj.pipelineRef)
                ref = runObj.pipelineRef;
                if isfield(ref,'id') && strcmp(char(string(ref.id)), char(string(pipeObj.strid)))
                    tf = true;
                    return;
                end
                if isfield(ref,'path') && ~isempty(ref.path) && ~isempty(pipeObj.path)
                    if strcmp(normPath(ref.path), normPath(pipeObj.path))
                        tf = true;
                        return;
                    end
                end
            end

            % legacy fallback
            if isprop(runObj,'templateId') && strcmp(char(string(runObj.templateId)), char(string(pipeObj.strid)))
                tf = true;
                return;
            end
            if isprop(runObj,'templatePath') && ~isempty(runObj.templatePath) && ~isempty(pipeObj.path)
                tf = strcmp(normPath(runObj.templatePath), normPath(pipeObj.path));
            end

            function p = normPath(in)
                p = lower(strrep(char(string(in)), '\', '/'));
                p = regexprep(p, '/+$', '');
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
