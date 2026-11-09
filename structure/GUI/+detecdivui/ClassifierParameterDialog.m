classdef ClassifierParameterDialog < handle
    % Package-described controls with staged, typed changes.
    properties (SetAccess=private)
        Figure
        Controls=struct()
        View
    end
    properties (Access=private)
        Grid
        Labels=gobjects(0)
        Heights={}
        Kinds={}
        Initial={}
        Advanced
        Status
        OnApply
    end
    methods
        function obj=ClassifierParameterDialog(name,view,onApply)
            obj.View=view; obj.OnApply=onApply;
            kind='Static Parameters'; if view.bindings, kind='Bindings'; end
            obj.Figure=uifigure('Name',[view.stage ' ' kind ' - ' name], ...
                'Position',[250 150 720 590],'Visible','off','Tag','classifier-parameter-dialog', ...
                'CloseRequestFcn',@(~,~)delete(obj));
            root=uigridlayout(obj.Figure,[4 1]); root.RowHeight={26,'1x',28,24};
            obj.Advanced=uicheckbox(root,'Text','Advanced','Value',false,'Tag','classifier-show-advanced', ...
                'ValueChangedFcn',@(~,~)obj.showAdvanced());
            records=view.records; n=numel(records);
            obj.Grid=uigridlayout(root,[max(1,n) 2]); obj.Grid.Scrollable='on';
            obj.Grid.ColumnWidth={230,'1x'}; obj.Grid.Padding=[0 0 0 0];
            obj.Grid.RowHeight=repmat({28},1,max(1,n));
            obj.Labels=gobjects(1,n);
            for k=1:n
                r=records(k); base=r.value; kind=detecdivui.RunDraft.valueKind(base);
                tip=strjoin({r.group r.tip},newline);
                obj.Labels(k)=uilabel(obj.Grid,'Text',r.label,'Interpreter','none','Tooltip',tip);
                obj.Labels(k).Layout.Row=k; obj.Labels(k).Layout.Column=1;
                height=28;
                if ~r.editable
                    kind='readonly';
                    control=uieditfield(obj.Grid,'text','Editable','off', ...
                        'Value',detecdivui.PipelineBindings.valueText(base), ...
                        'Tooltip',[tip newline 'Managed by the annotation package']);
                elseif ~isempty(r.choices)
                    values=reshape(cellstr(string(r.choices)),1,[]);
                    labels=reshape(cellstr(string(r.choiceLabels)),1,[]);
                    if numel(labels)~=numel(values), labels=values; end
                    labels=matlab.lang.makeUniqueStrings(labels);
                    selected=cellstr(string(base));
                    if strcmp(kind,'choice')&&~view.bindings, selected=cellstr(string(base{end})); end
                    if view.bindings && strcmp(r.binding.cardinality,'many')
                        kind='bindings'; height=100;
                        selected=intersect(selected,values,'stable');
                        control=uilistbox(obj.Grid,'Items',labels,'ItemsData',values, ...
                            'Multiselect','on','Value',selected);
                    else
                        if view.bindings, kind='binding'; elseif ~strcmp(kind,'choice'), kind='enum'; end
                        if isempty(selected), selected=values(1); end
                        selected=selected{end};
                        if ~ismember(selected,values), values{end+1}=selected; labels{end+1}=selected; end %#ok<AGROW>
                        control=uidropdown(obj.Grid,'Items',labels,'ItemsData',values,'Value',selected);
                    end
                elseif r.autoNumber
                    kind='special-number'; value=num2str(base); if isnan(base), value='auto'; end
                    control=uieditfield(obj.Grid,'text','Value',value,'Tooltip',[tip newline 'auto, Inf, or a number']);
                else
                    switch kind
                        case 'logical', control=uicheckbox(obj.Grid,'Text','','Value',base);
                        case 'number', control=uieditfield(obj.Grid,'numeric','Value',double(base));
                        case 'text', control=uieditfield(obj.Grid,'text','Value',char(string(base)));
                        otherwise
                            if isnumeric(base)&&isreal(base)&&ismatrix(base)&&all(isfinite(base(:)))
                                kind='array'; height=min(150,max(58,24*(size(base,1)+1)));
                                if isempty(base)
                                    kind='array-text'; height=28;
                                    control=uieditfield(obj.Grid,'text','Value','[]','Tooltip','Numeric array in JSON format');
                                else
                                    control=uitable(obj.Grid,'Data',double(base),'RowName',{},'ColumnName',{}, ...
                                        'ColumnEditable',true(1,size(base,2)));
                                end
                            else
                                kind='readonly';
                                control=uieditfield(obj.Grid,'text','Editable','off', ...
                                    'Value',detecdivui.PipelineBindings.valueText(base), ...
                                    'Tooltip',[tip newline 'Use Advanced in the Classifier widget']);
                            end
                    end
                end
                control.Layout.Row=k; control.Layout.Column=2; control.Tag=['classifier-param-' r.key];
                if isempty(control.Tooltip), control.Tooltip=tip; end
                obj.Controls.(r.key)=control; obj.Kinds{k}=kind; obj.Heights{k}=height;
                if strcmp(kind,'array')
                    obj.Initial{k}=control.Data;
                elseif ~strcmp(kind,'readonly')
                    obj.Initial{k}=control.Value;
                else
                    obj.Initial{k}=[];
                end
            end
            bar=uigridlayout(root,[1 3]); bar.Padding=[0 0 0 0]; bar.ColumnWidth={'1x',90,90};
            uilabel(bar,'Text','');
            uibutton(bar,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(obj));
            applyButton=uibutton(bar,'Text','Apply','Tag','classifier-parameter-apply','ButtonPushedFcn',@(~,~)obj.apply());
            if ~any([records.editable]), applyButton.Enable='off'; end
            obj.Status=uilabel(root,'Text','','Interpreter','none','Tag','classifier-parameter-status');
            obj.showAdvanced(); obj.Figure.Visible='on';
        end
        function changes=requestCurrent(obj)
            changes=struct();
            for k=1:numel(obj.View.records)
                r=obj.View.records(k); base=r.value; control=obj.Controls.(r.key);
                if strcmp(obj.Kinds{k},'array')
                    unchanged=isequaln(control.Data,obj.Initial{k});
                elseif strcmp(obj.Kinds{k},'readonly')
                    continue;
                else
                    unchanged=isequaln(control.Value,obj.Initial{k});
                end
                if unchanged, continue; end
                switch obj.Kinds{k}
                    case 'logical', value=logical(control.Value);
                    case 'number', value=obj.number(control.Value,base);
                    case 'special-number'
                        text=strtrim(control.Value); value=str2double(text);
                        if strcmpi(text,'auto'), value=NaN;
                        else, assert(~isnan(value)||strcmpi(text,'NaN'),'detecdivui:ClassifierNumber','Enter auto, Inf, or a number.'); end
                        value=cast(value,class(base));
                    case {'array','array-text'}
                        if strcmp(obj.Kinds{k},'array'), value=control.Data;
                        else, value=jsondecode(control.Value); end
                        if iscell(value), value=cell2mat(value); end
                        if isempty(value), value=base; else, value=obj.number(value,base); end
                    case 'choice'
                        value=base;
                        if isstring(base{end}), value{end}=string(control.Value);
                        else, value{end}=control.Value; end
                    case {'binding','bindings'}, value=control.Value;
                    case {'enum','text'}
                        value=control.Value; if isstring(base), value=string(value); end
                    otherwise, continue;
                end
                if ~isequaln(value,base), changes.(r.key)=value; end
            end
        end
        function applied=apply(obj)
            applied=false;
            try
                changes=obj.requestCurrent(); detecdivui.Callback.call(obj.OnApply,obj.View,changes);
                applied=true; delete(obj);
            catch err
                obj.Status.Text=err.message; obj.Status.Tooltip=err.message;
            end
        end
        function delete(obj)
            if isgraphics(obj.Figure), delete(obj.Figure); end
        end
    end
    methods (Access=private)
        function showAdvanced(obj)
            heights=obj.Heights;
            for k=1:numel(obj.View.records)
                visible=obj.Advanced.Value||~obj.View.records(k).advanced;
                obj.Labels(k).Visible=matlab.lang.OnOffSwitchState(visible);
                obj.Controls.(obj.View.records(k).key).Visible=matlab.lang.OnOffSwitchState(visible);
                if ~visible, heights{k}=0; end
            end
            if ~isempty(heights), obj.Grid.RowHeight=heights; end
            obj.Advanced.Enable=matlab.lang.OnOffSwitchState(any([obj.View.records.advanced]));
        end
    end
    methods (Static,Access=private)
        function value=number(value,base)
            validateattributes(value,{'numeric'},{'real','finite','2d'});
            if isscalar(base), assert(isscalar(value),'detecdivui:ClassifierNumber','Enter one number.'); end
            if isinteger(base)
                assert(all(value(:)==fix(value(:)))&&all(value(:)>=double(intmin(class(base))))&& ...
                    all(value(:)<=double(intmax(class(base))))&&all(abs(value(:))<=flintmax), ...
                    'detecdivui:ClassifierNumber','Enter integers within the parameter range.');
            end
            value=cast(value,class(base));
            assert(all(isfinite(value(:))),'detecdivui:ClassifierNumber','Value is outside the parameter range.');
        end
    end
end
