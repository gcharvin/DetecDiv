classdef RecentClassifiers < handle
    % Shared classic MAT history; source paths are never probed on startup.
    properties (SetAccess=private)
        Paths = strings(0,1)
        File
        LastError = ''
    end
    methods
        function obj=RecentClassifiers(file)
            if nargin<1, file=fullfile(prefdir,'recentClassifiers.mat'); end
            assert(ischar(file)&&(isrow(file)||isempty(file)) || isstring(file)&&isscalar(file)&&~ismissing(file), ...
                'detecdivui:RecentClassifierStore','A single recent-classifiers file path is required.');
            obj.File=char(file); obj.reload();
        end
        function reload(obj)
            obj.Paths=strings(0,1); obj.LastError='';
            if isempty(obj.File)||~isfile(obj.File), return; end
            try
                data=load(obj.File,'RecentClassifiers');
                if isfield(data,'RecentClassifiers'), obj.Paths=obj.normalize(data.RecentClassifiers); end
            catch err, obj.LastError=err.message;
            end
        end
        function remember(obj,path)
            path=detecdivui.RecentClassifiers.normalizePath(path);
            if ~isempty(obj.File), obj.reload(); end
            obj.Paths=obj.normalize([string(path);obj.Paths]); obj.persist();
        end
        function clear(obj)
            obj.Paths=strings(0,1); obj.persist();
        end
    end
    methods (Access=private)
        function persist(obj)
            obj.LastError=''; if isempty(obj.File), return; end
            try
                parent=fileparts(obj.File);
                if ~isempty(parent)&&~isfolder(parent), mkdir(parent); end
                RecentClassifiers=obj.Paths;
                temporary=[obj.File '.' char(matlab.lang.internal.uuid) '.tmp'];
                cleanup=onCleanup(@()obj.removeTemporary(temporary));
                save(temporary,'RecentClassifiers','-mat');
                [ok,message]=movefile(temporary,obj.File,'f');
                assert(ok,'detecdivui:RecentClassifierSave','%s',message);
            catch err, obj.LastError=err.message; rethrow(err);
            end
        end
    end
    methods (Static)
        function path=normalizePath(path)
            assert(ischar(path)&&isrow(path) || isstring(path)&&isscalar(path)&&~ismissing(path), ...
                'detecdivui:RecentClassifierPath','A single classifier file path is required.');
            path=char(strtrim(string(path)));
            assert(~isempty(path),'detecdivui:RecentClassifierPath','A classifier file path is required.');
            path=char(java.io.File(path).toPath().toAbsolutePath().normalize().toString());
            [~,~,extension]=fileparts(path);
            if isempty(extension), path=[path '.mat'];
            else, assert(strcmpi(extension,'.mat'),'detecdivui:RecentClassifierPath','Choose a classifier MAT file.'); end
        end
        function yes=samePath(a,b)
            a=detecdivui.RecentClassifiers.normalizePath(a); b=detecdivui.RecentClassifiers.normalizePath(b);
            if ispc, yes=strcmpi(a,b); else, yes=strcmp(a,b); end
        end
    end
    methods (Static,Access=private)
        function paths=normalize(value)
            paths=strings(0,1);
            if ~(isstring(value)||ischar(value)&&(isrow(value)||isempty(value))||iscellstr(value)), return; end
            value=string(value); value=value(:);
            for k=1:numel(value)
                if ismissing(value(k))||strlength(strtrim(value(k)))==0, continue; end
                try
                    path=string(detecdivui.RecentClassifiers.normalizePath(value(k)));
                    if ~any(arrayfun(@(other)detecdivui.RecentClassifiers.samePath(other,path),paths))
                        paths(end+1,1)=path; %#ok<AGROW>
                    end
                catch
                    % Ignore malformed entries, retaining unavailable drives.
                end
                if numel(paths)==10, break; end
            end
        end
        function removeTemporary(file)
            if isfile(file), delete(file); end
        end
    end
end
