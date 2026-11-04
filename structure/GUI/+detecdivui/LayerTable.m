classdef LayerTable < handle
    % Rich rows hosted in the same web-based FigureDocument as native controls.
    properties
        OnEdit = []
    end
    properties (SetAccess = private)
        View
        State = struct()
    end
    properties (Access = private)
        Revision = 0
    end
    methods
        function obj = LayerTable(parent)
            obj.View = uihtml(parent,'HTMLSource',fullfile(fileparts(mfilename('fullpath')),'layers.html'), ...
                'Tag','layers','DataChangedFcn',@(~,event)obj.receive(event.Data));
        end
        function update(obj,layers,selected)
            obj.Revision = obj.Revision+1;
            obj.State = struct('revision',obj.Revision,'layers',layers,'selected',selected);
            obj.View.Data = obj.State;
        end
        function receive(obj,event)
            if ~isstruct(event) || ~all(isfield(event,{'revision','action','index','value'})) || ...
                    event.revision ~= obj.Revision, return; end
            if ~isempty(obj.OnEdit), obj.OnEdit(char(event.action),event.index,event.value); end
        end
    end
end
