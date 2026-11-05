classdef HistogramView < handle
    % Display-only histogram; pixel statistics are shared with Score.
    properties
        OnEdit = []
        ShowVisible = false
        XScale = 'auto'
        LogCounts = true
    end
    properties (SetAccess = private)
        View
        State = struct()
    end
    properties (Access = private)
        Revision = 0
        Context = {}
        ContextRevision = 0
        Sequence = 0
    end
    methods
        function obj = HistogramView(parent)
            obj.View = uihtml(parent,'HTMLSource',fullfile(fileparts(mfilename('fullpath')),'histogram.html'), ...
                'Tag','display-histogram','DataChangedFcn',@(~,event)obj.receive(event.Data));
        end
        function update(obj,model,frame,selected,context)
            if nargin < 5, context = {}; end
            scope = {model,frame,selected,context,model.Layers(selected).name,model.Layers(selected).kind};
            if ~isequal(scope,obj.Context)
                obj.Context = scope; obj.ContextRevision = obj.ContextRevision+1;
            end
            layers = model.Layers; indices = selected;
            if obj.ShowVisible, indices = unique([find([layers.visible]) selected],'stable'); end
            series = struct('name',{},'edges',{},'counts',{},'color',{},'active',{}); stats = [];
            for index = indices
                if strcmp(layers(index).kind,'Labels'), continue; end
                data = model.histogram(index,frame);
                if index == selected, stats = data; end
                if data.count == 0, continue; end
                series(end+1) = struct('name',layers(index).name,'edges',data.edges,'counts',data.counts, ...
                    'color',layers(index).color,'active',index == selected); %#ok<AGROW>
            end
            obj.Revision = obj.Revision+1;
            obj.State = struct('revision',obj.Revision,'series',series,'selected',selected, ...
                'name',layers(selected).name,'kind',layers(selected).kind,'limits',layers(selected).limits, ...
                'stats',stats,'showVisible',obj.ShowVisible,'xScale',obj.XScale,'logCounts',obj.LogCounts, ...
                'context',sprintf('%d',obj.ContextRevision),'ack',obj.Sequence);
            obj.View.Data = obj.State;
        end
        function clear(obj)
            obj.Context = {}; obj.ContextRevision = obj.ContextRevision+1;
            obj.Revision = obj.Revision+1; obj.State = struct('revision',obj.Revision,'series',[], ...
                'selected',0,'name','','kind','','limits',[],'stats',[], ...
                'showVisible',obj.ShowVisible,'xScale',obj.XScale,'logCounts',obj.LogCounts, ...
                'context',sprintf('%d',obj.ContextRevision),'ack',obj.Sequence);
            obj.View.Data = obj.State;
        end
        function receive(obj,event)
            if ~isstruct(event) || ~all(isfield(event,{'revision','action','value'})), return; end
            if strcmp(event.action,'limits') && all(isfield(event,{'context','sequence','phase'}))
                if ~strcmp(event.context,obj.State.context) || event.sequence <= obj.Sequence || ...
                        ~any(strcmp(event.phase,{'preview','commit','cancel'})), return; end
                obj.Sequence = event.sequence;
                action = 'limits'; if strcmp(event.phase,'preview'), action = 'limits-preview'; end
                detecdivui.Callback.call(obj.OnEdit,action,obj.State.selected,event.value);
                % A coalesced preview may not have rendered yet. Acknowledge it
                % without replacing the in-progress browser marker gesture.
                obj.State.ack = obj.Sequence; obj.View.Data = obj.State;
                return;
            end
            if event.revision ~= obj.Revision, return; end
            switch char(event.action)
                case 'visible', obj.ShowVisible = logical(event.value);
                case 'xscale'
                    if ~any(strcmp(event.value,{'auto','linear','log'})), return; end
                    obj.XScale = char(event.value);
                case 'logcounts', obj.LogCounts = logical(event.value);
                case 'limits'
                    detecdivui.Callback.call(obj.OnEdit,'limits',obj.State.selected,event.value);
                    return;
                otherwise, return;
            end
            detecdivui.Callback.call(obj.OnEdit,'histogram',obj.State.selected,[]);
        end
    end
end
