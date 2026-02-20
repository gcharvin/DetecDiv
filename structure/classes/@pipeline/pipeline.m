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
            obj.strid = [name '_' num2str(id)];
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

        function log(obj, msg, category)
            if nargin < 3, category = "Info"; end
            try
                obj.history(end+1,:) = {datetime('now'), string(category), string(msg)};
            catch
            end
        end
    end
end
