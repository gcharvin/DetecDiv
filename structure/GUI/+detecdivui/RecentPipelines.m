classdef RecentPipelines < handle
    % Classic recentPipelines.mat plus pipeline2's existing preference.
    % Saved references are normalized lexically, never probed on startup.
    properties (SetAccess = private)
        Paths = strings(0,1)
        File
        LastError = ''
    end
    properties (Access = private)
        SharedPreferences = false
    end
    methods
        function obj = RecentPipelines(file)
            default = fullfile(prefdir,'recentPipelines.mat');
            if nargin < 1, file = default; end
            assert(ischar(file) && (isrow(file) || isempty(file)) || isstring(file) && isscalar(file), ...
                'detecdivui:RecentPipelineStore','A single recent-pipelines file path is required.');
            obj.File = char(file);
            if ~isempty(obj.File)
                obj.File = obj.absolute(obj.File);
                obj.SharedPreferences = obj.equalPath(obj.File,obj.absolute(default));
            end
            obj.reload();
        end
        function reload(obj)
            obj.Paths = strings(0,1); obj.LastError = '';
            if isempty(obj.File), return; end
            if isfile(obj.File)
                try
                    data = load(obj.File,'RecentPipelines');
                    if isfield(data,'RecentPipelines'), obj.Paths = obj.normalize(data.RecentPipelines); end
                catch err
                    obj.LastError = err.message;
                end
            end
            if obj.SharedPreferences
                try
                    legacy = obj.normalize(getpref('DetecDiv','pipeline2RecentPipelines',{}));
                    obj.Paths = obj.normalize([obj.Paths; legacy]);
                catch err
                    obj.LastError = err.message;
                end
            end
        end
        function remember(obj,path)
            path = obj.normalizePath(path);
            if ~isempty(obj.File), obj.reload(); end
            obj.Paths = obj.normalize([string(path); obj.Paths]);
            obj.persist();
        end
        function clear(obj)
            obj.Paths = strings(0,1); obj.persist();
        end
    end
    methods (Access = private)
        function persist(obj)
            obj.LastError = '';
            if isempty(obj.File), return; end
            try
                parent = fileparts(obj.File);
                if ~isempty(parent) && ~isfolder(parent), mkdir(parent); end
                RecentPipelines = obj.Paths;
                temporary = [obj.File '.' char(matlab.lang.internal.uuid) '.tmp'];
                cleanup = onCleanup(@()obj.removeTemporary(temporary));
                save(temporary,'RecentPipelines','-mat');
                [ok,message] = movefile(temporary,obj.File,'f');
                assert(ok,'detecdivui:RecentPipelineSave','%s',message);
                if obj.SharedPreferences
                    % Keep the existing editor's list consistent after an
                    % explicit remember/clear. Reload alone never writes it.
                    setpref('DetecDiv','pipeline2RecentPipelines',cellstr(obj.Paths));
                end
            catch err
                obj.LastError = err.message; rethrow(err);
            end
        end
    end
    methods (Static)
        function path = normalizePath(path)
            assert(ischar(path) && isrow(path) || isstring(path) && isscalar(path) && ~ismissing(path), ...
                'detecdivui:RecentPipelinePath','A single pipeline path is required.');
            path = char(strtrim(string(path)));
            assert(~isempty(path),'detecdivui:RecentPipelinePath','A pipeline path is required.');
            path = detecdivui.RecentPipelines.absolute(path);
            [~,~,extension] = fileparts(path);
            if ~strcmpi(extension,'.json'), path = fullfile(path,'pipeline.json'); end
        end
        function yes = samePath(a,b)
            yes = detecdivui.RecentPipelines.equalPath( ...
                detecdivui.RecentPipelines.normalizePath(a),detecdivui.RecentPipelines.normalizePath(b));
        end
    end
    methods (Static, Access = private)
        function paths = normalize(value)
            paths = strings(0,1);
            if ~(isstring(value) || ischar(value) && (isrow(value) || isempty(value)) || iscellstr(value)), return; end
            value = string(value); value = value(:);
            for k = 1:numel(value)
                if ismissing(value(k)) || strlength(strtrim(value(k))) == 0, continue; end
                try
                    path = string(detecdivui.RecentPipelines.normalizePath(value(k)));
                    if ~any(arrayfun(@(other)detecdivui.RecentPipelines.samePath(other,path),paths))
                        paths(end+1,1) = path; %#ok<AGROW>
                    end
                catch
                    % Malformed values are skipped; inaccessible sources
                    % remain valid saved references and are not inspected.
                end
                if numel(paths) == 10, break; end
            end
        end
        function path = absolute(path)
            % java.nio normalization is lexical: no getCanonicalPath/exists.
            path = char(java.io.File(char(path)).toPath().toAbsolutePath().normalize().toString());
        end
        function yes = equalPath(a,b)
            if ispc, yes = strcmpi(a,b); else, yes = strcmp(a,b); end
        end
        function removeTemporary(file)
            if isfile(file), delete(file); end
        end
    end
end
