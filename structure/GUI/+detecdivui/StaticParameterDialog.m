classdef StaticParameterDialog < handle
    % Typed, staged edits of module parameters; Apply is the only handoff.
    properties (SetAccess = private)
        Figure
        Controls = struct()
        Parameters
        Keys = {}
    end
    properties (Access = private)
        NodeId
        Records = struct('key',{},'kind',{},'base',{},'control',{})
        OnApply
        OnAdvanced
        Status
    end
    methods
        function obj = StaticParameterDialog(node,keys,onApply,onAdvanced)
            if nargin < 4, onAdvanced = []; end
            obj.NodeId = char(string(node.id)); obj.Parameters = node.params;
            obj.Keys = reshape(cellstr(string(keys)),1,[]);
            obj.Keys = obj.Keys(ismember(obj.Keys,fieldnames(obj.Parameters)));
            obj.OnApply = onApply; obj.OnAdvanced = onAdvanced;
            obj.Figure = uifigure('Name',['Static Parameters - ' obj.NodeId], ...
                'Position',[250 170 690 570],'Visible','off','Tag','pipeline-static-dialog', ...
                'CloseRequestFcn',@(~,~)delete(obj));
            root = uigridlayout(obj.Figure,[4 1]); root.Padding = [10 8 10 8];
            root.RowHeight = {24,'1x',28,24};
            uilabel(root,'Text',obj.NodeId,'FontWeight','bold','Interpreter','none');
            grid = uigridlayout(root,[max(1,numel(obj.Keys)) 2]); grid.Scrollable = 'on';
            grid.Padding = [0 0 0 0]; grid.ColumnWidth = {195,'1x'};
            grid.RowHeight = repmat({28},1,max(1,numel(obj.Keys)));
            specs = classifierBinding.parameterSpecFromDefaults(obj.Parameters);
            for k = 1:numel(obj.Keys)
                key = obj.Keys{k}; base = obj.Parameters.(key);
                selected = find(strcmp({specs.param},key),1);
                label = key; tooltip = '';
                if ~isempty(selected), label = specs(selected).label; tooltip = specs(selected).tip; end
                text = uilabel(grid,'Text',label,'Interpreter','none','Tooltip',tooltip);
                text.Layout.Row = k; text.Layout.Column = 1;
                kind = detecdivui.RunDraft.valueKind(base);
                switch kind
                    case 'logical'
                        control = uicheckbox(grid,'Text','','Value',base);
                    case 'number'
                        control = uieditfield(grid,'numeric','Value',double(base));
                    case 'text'
                        control = uieditfield(grid,'text','Value',char(string(base)));
                    case 'choice'
                        choices = unique(cellstr(string(base(1:end-1))),'stable');
                        control = uidropdown(grid,'Items',choices,'Value',char(string(base{end})));
                    otherwise
                        if isnumeric(base) && isreal(base) && ismatrix(base) && all(isfinite(base(:))) && ...
                                (~isinteger(base) || all(abs(double(base(:))) <= flintmax))
                            if isempty(base)
                                kind = 'array-text';
                                control = uieditfield(grid,'text','Value','[]', ...
                                    'Tooltip','Numeric array in JSON format; for example [1,2,3]');
                            else
                                kind = 'array';
                                control = uitable(grid,'Data',double(base),'RowName',{},'ColumnName',{}, ...
                                    'ColumnEditable',true(1,size(base,2)));
                                grid.RowHeight{k} = min(150,max(58,24*(size(base,1)+1)));
                            end
                        else
                            kind = 'readonly';
                            control = uieditfield(grid,'text','Editable','off', ...
                                'Value',detecdivui.PipelineBindings.valueText(base), ...
                                'Tooltip','Edit this value in Pipeline Designer');
                        end
                end
                control.Layout.Row = k; control.Layout.Column = 2;
                control.Tag = ['pipeline-static-' key];
                if isempty(control.Tooltip), control.Tooltip = tooltip; end
                obj.Controls.(key) = control;
                obj.Records(end+1) = struct('key',key,'kind',kind,'base',{base},'control',control);
            end
            buttons = uigridlayout(root,[1 3]); buttons.Padding = [0 0 0 0];
            buttons.ColumnWidth = {'1x',90,90};
            advanced = uibutton(buttons,'Text','Edit Module...','Tag','pipeline-static-advanced', ...
                'Tooltip','Open module-specific and structured parameters in Pipeline Designer', ...
                'ButtonPushedFcn',@(~,~)obj.advanced());
            if isempty(onAdvanced), advanced.Enable = 'off'; end
            uibutton(buttons,'Text','Cancel','Tag','pipeline-static-cancel','ButtonPushedFcn',@(~,~)delete(obj));
            apply = uibutton(buttons,'Text','Apply','Tag','pipeline-static-apply','ButtonPushedFcn',@(~,~)obj.apply());
            if isempty(obj.Keys), apply.Enable = 'off'; end
            obj.Status = uilabel(root,'Text','','Interpreter','none','Tag','pipeline-static-status');
            obj.Figure.Visible = 'on';
        end
        function params = requestCurrent(obj)
            params = obj.Parameters;
            for k = 1:numel(obj.Records)
                record = obj.Records(k); control = record.control; base = record.base;
                switch record.kind
                    case 'logical', value = logical(control.Value);
                    case 'number', value = obj.castNumeric(control.Value,base,record.key);
                    case 'text'
                        value = control.Value; if isstring(base), value = string(value); end
                    case 'choice'
                        value = base;
                        if isstring(base{end}), value{end} = string(control.Value); else, value{end} = control.Value; end
                    case 'array'
                        value = control.Data;
                        if iscell(value)
                            assert(all(cellfun(@(item)isnumeric(item) && isscalar(item),value(:))), ...
                                'detecdivui:StaticArray','Enter numeric cells for %s.',record.key);
                            value = cell2mat(value);
                        end
                        value = obj.castNumeric(value,base,record.key);
                    case 'array-text'
                        value = jsondecode(control.Value);
                        assert(isnumeric(value) && isreal(value) && ismatrix(value), ...
                            'detecdivui:StaticArray','Enter a numeric JSON array for %s.',record.key);
                        if isempty(value), value = base; else, value = obj.castNumeric(value,base,record.key); end
                    otherwise, continue;
                end
                params.(record.key) = value;
            end
        end
        function applied = apply(obj)
            applied = false;
            try
                params = obj.requestCurrent();
                detecdivui.Callback.call(obj.OnApply,obj.NodeId,params);
                applied = true; delete(obj);
            catch err
                if isgraphics(obj.Status), obj.Status.Text = err.message; obj.Status.Tooltip = err.message; end
            end
        end
        function delete(obj)
            if isgraphics(obj.Figure), delete(obj.Figure); end
        end
    end
    methods (Access = private)
        function advanced(obj)
            try
                detecdivui.Callback.call(obj.OnAdvanced,obj.NodeId); delete(obj);
            catch err
                obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
    end
    methods (Static, Access = private)
        function value = castNumeric(value,base,key)
            validateattributes(value,{'numeric'},{'real','finite'});
            if isinteger(base)
                assert(all(abs(double(value(:))) <= flintmax) && all(value(:) == fix(value(:))) && ...
                    all(value(:) >= double(intmin(class(base)))) && all(value(:) <= double(intmax(class(base)))), ...
                    'detecdivui:StaticNumber','Enter integers within the range of %s for %s.',class(base),key);
            end
            value = cast(value,class(base));
            assert(all(isfinite(value(:))),'detecdivui:StaticNumber','Value is outside the range for %s.',key);
        end
    end
end
