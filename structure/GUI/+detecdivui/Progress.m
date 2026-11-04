classdef Progress < handle
    % Widget-local, scoped progress. No timers, modal windows or fake percent.
    properties
        Route = []
    end
    properties (SetAccess = private)
        View
        Active = false
        Message = ''
        Fraction = NaN
    end
    properties (Access = private)
        Idle
        Stack = struct('id',{},'message',{},'fraction',{})
        NextId = 0
    end
    methods
        function obj = Progress(parent,idle,tag)
            obj.Idle = idle;
            rows = parent.RowHeight; columns = parent.ColumnWidth;
            obj.View = uihtml(parent,'HTMLSource',fullfile(fileparts(mfilename('fullpath')),'progress.html'), ...
                'Tag',tag,'Visible','off');
            obj.View.Layout.Row = idle.Layout.Row; obj.View.Layout.Column = idle.Layout.Column;
            parent.RowHeight = rows; parent.ColumnWidth = columns;
        end
        function scope = begin(obj,message)
            target = obj.target();
            if target ~= obj, scope = target.begin(message); return; end
            obj.NextId = obj.NextId+1; token = obj.NextId;
            obj.Stack(end+1) = struct('id',token,'message',char(string(message)),'fraction',NaN);
            scope = onCleanup(@()obj.finish(token));
            obj.paint(); drawnow nocallbacks;
        end
        function update(obj,message,fraction)
            if nargin < 3, fraction = NaN; end
            if isempty(obj.Stack)
                target = obj.target();
                if target ~= obj, target.update(message,fraction); end
                return;
            end
            if ~isscalar(fraction) || ~isnumeric(fraction) || ~isfinite(fraction), fraction = NaN;
            else, fraction = min(1,max(0,double(fraction))); end
            obj.Stack(end).message = char(string(message)); obj.Stack(end).fraction = fraction;
            obj.paint(); drawnow limitrate nocallbacks;
        end
        function report(obj,payload)
            % Existing shallowLoad callback payload: message / fraction.
            if ~isstruct(payload), return; end
            message = obj.Message; fraction = NaN;
            if isfield(payload,'message'), message = payload.message; end
            if isfield(payload,'fraction'), fraction = payload.fraction; end
            obj.update(message,fraction);
        end
        function finish(obj,token)
            if ~isvalid(obj), return; end
            obj.Stack([obj.Stack.id] == token) = []; obj.paint();
        end
    end
    methods (Access = private)
        function value = target(obj)
            value = obj;
            if isempty(obj.Stack) && ~isempty(obj.Route)
                try
                    candidate = obj.Route();
                catch
                    return;
                end
                if isa(candidate,'detecdivui.Progress') && isvalid(candidate), value = candidate; end
            end
        end
        function paint(obj)
            obj.Active = ~isempty(obj.Stack);
            if ~obj.Active
                obj.Message = ''; obj.Fraction = NaN;
                if isempty(obj.View) || ~isvalid(obj.View), return; end
                obj.View.Visible = 'off';
                if isvalid(obj.Idle), obj.Idle.Visible = 'on'; end
                return;
            end
            obj.Message = obj.Stack(end).message; obj.Fraction = obj.Stack(end).fraction;
            if isempty(obj.View) || ~isvalid(obj.View), return; end
            known = isfinite(obj.Fraction); value = 0; if known, value = obj.Fraction; end
            obj.View.Data = struct('message',obj.Message,'known',known,'value',value);
            obj.Idle.Visible = 'off'; obj.View.Visible = 'on';
        end
    end
end
