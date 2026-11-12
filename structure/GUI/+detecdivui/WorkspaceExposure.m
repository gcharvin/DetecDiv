classdef WorkspaceExposure
    % Optional references to open objects in MATLAB's base workspace.
    methods (Static)
        function value = enabled()
            value = logical(getpref('DetecDivUI','ExposeWorkspaceObjects',false));
        end
        function setEnabled(value)
            setpref('DetecDivUI','ExposeWorkspaceObjects',logical(value));
            if ~value, detecdivui.WorkspaceExposure.clearManaged(); end
        end
        function publish(object)
            if ~detecdivui.WorkspaceExposure.enabled() || isempty(object) || ~isvalid(object), return; end
            entries = detecdivui.workspaceObjects();
            for k = 1:numel(entries)
                if strcmp(entries(k).kind,class(object)) && entries(k).object == object, return; end
            end
            if isa(object,'shallow')
                label = ['project_' char(string(object.io.file))];
            elseif isa(object,'classi')
                label = ['classifier_' char(string(object.strid))];
            else
                return;
            end
            base = matlab.lang.makeValidName(label,'ReplacementStyle','underscore');
            names = evalin('base','who');
            name = matlab.lang.makeUniqueStrings(base,names,namelengthmax);
            assignin('base',name,object);
            records = detecdivui.WorkspaceExposure.records();
            records(end+1) = struct('name',name,'object',object);
            setappdata(0,'DetecDivUIWorkspaceBindings',records);
        end
        function forget(object)
            records = detecdivui.WorkspaceExposure.records();
            keep = true(size(records));
            for k = 1:numel(records)
                if isa(records(k).object,class(object)) && isvalid(records(k).object) && records(k).object == object
                    detecdivui.WorkspaceExposure.clearIfOwned(records(k));
                    keep(k) = false;
                end
            end
            setappdata(0,'DetecDivUIWorkspaceBindings',records(keep));
        end
        function clearManaged()
            records = detecdivui.WorkspaceExposure.records();
            for k = 1:numel(records)
                detecdivui.WorkspaceExposure.clearIfOwned(records(k));
            end
            setappdata(0,'DetecDivUIWorkspaceBindings',struct('name',{},'object',{}));
        end
    end
    methods (Static, Access = private)
        function value = records()
            value = struct('name',{},'object',{});
            if isappdata(0,'DetecDivUIWorkspaceBindings')
                value = getappdata(0,'DetecDivUIWorkspaceBindings');
            end
        end
        function clearIfOwned(record)
            if ~isvarname(record.name) || ~evalin('base',sprintf('exist(''%s'',''var'')',record.name)), return; end
            value = evalin('base',record.name);
            if isa(value,class(record.object)) && isscalar(value) && isvalid(value) && ...
                    isvalid(record.object) && value == record.object
                evalin('base',['clear ' record.name]);
            end
        end
    end
end
