classdef RecentProjects < handle
    % Shared classic recentProjects.mat format; no path probes during startup.
    properties (SetAccess = private)
        Paths = strings(0,1)
        File
        LastError = ''
    end
    methods
        function obj = RecentProjects(file)
            if nargin < 1, file = fullfile(prefdir,'recentProjects.mat'); end
            obj.File = char(file); obj.reload();
        end
        function reload(obj)
            obj.Paths = strings(0,1); obj.LastError = '';
            if isempty(obj.File) || ~isfile(obj.File), return; end
            try
                data = load(obj.File,'RecentProjects');
                if isfield(data,'RecentProjects')
                    obj.Paths = obj.normalize(data.RecentProjects);
                end
            catch err
                obj.LastError = err.message;
            end
        end
        function remember(obj,path)
            path = obj.absolute(path);
            if ~isempty(obj.File), obj.reload(); end
            obj.Paths = obj.normalize([string(path); obj.Paths]); obj.persist();
        end
        function clear(obj)
            obj.Paths = strings(0,1); obj.persist();
        end
    end
    methods (Access = private)
        function persist(obj)
            if isempty(obj.File), return; end
            parent = fileparts(obj.File);
            if ~isempty(parent) && ~isfolder(parent), mkdir(parent); end
            RecentProjects = obj.Paths;
            temporary = [obj.File '.' char(matlab.lang.internal.uuid) '.tmp'];
            cleanup = onCleanup(@()obj.removeTemporary(temporary));
            save(temporary,'RecentProjects','-mat');
            [ok,message] = movefile(temporary,obj.File,'f');
            assert(ok,'detecdivui:RecentSave','%s',message);
        end
    end
    methods (Static)
        function yes = samePath(a,b)
            a = regexprep(detecdivui.RecentProjects.absolute(a),'(?i)\.(mat|json)$','');
            b = regexprep(detecdivui.RecentProjects.absolute(b),'(?i)\.(mat|json)$','');
            yes = strcmpi(a,b);
        end
        function path = resolve(path)
            % Only called on explicit open, matching shallowLoad's JSON preference.
            path = detecdivui.RecentProjects.absolute(path);
            [folder,name,extension] = fileparts(path);
            if isempty(extension) || strcmpi(extension,'.mat')
                candidate = fullfile(folder,[name '.json']);
                if isfile(candidate), path = candidate; return; end
                if isempty(extension)
                    candidate = fullfile(folder,[name '.mat']);
                    if isfile(candidate), path = candidate; end
                end
            elseif strcmpi(extension,'.json') && ~isfile(path)
                candidate = fullfile(folder,[name '.mat']);
                if isfile(candidate), path = candidate; end
            end
        end
    end
    methods (Static, Access = private)
        function paths = normalize(value)
            paths = strings(0,1);
            if ~(isstring(value) || ischar(value) || iscellstr(value)), return; end
            value = string(value); value = value(:);
            for k = 1:numel(value)
                if ismissing(value(k)) || strlength(strtrim(value(k))) == 0, continue; end
                try
                    path = string(detecdivui.RecentProjects.absolute(value(k)));
                    if ~any(arrayfun(@(p)detecdivui.RecentProjects.samePath(p,path),paths))
                        paths(end+1,1) = path; %#ok<AGROW>
                    end
                catch
                    % Skip malformed entries; unavailable drives remain in history.
                end
                if numel(paths) == 10, break; end
            end
        end
        function path = absolute(path)
            validateattributes(path,{'char','string'},{'nonempty'});
            assert(ischar(path) && isrow(path) || isstring(path) && isscalar(path), ...
                'detecdivui:RecentPath','A single project path is required.');
            path = char(strtrim(string(path)));
            assert(~isempty(path),'detecdivui:RecentPath','A project path is required.');
            % Lexical normalization only, including unavailable mapped/UNC paths.
            path = char(java.io.File(path).toPath().toAbsolutePath().normalize().toString());
        end
        function removeTemporary(file)
            if isfile(file), delete(file); end
        end
    end
end
