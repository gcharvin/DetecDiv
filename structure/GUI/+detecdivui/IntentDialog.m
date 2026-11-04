classdef IntentDialog < handle
    % One proposal surface for all intents; main Pipeline owns the graph/draft.
    properties (SetAccess=private)
        Figure
    end
    properties (Access=private)
        Owner
        Intent
        Target
        Methods
        Controls = struct()
        Questions
        Changes
        Apply
        Status
        Progress
        Catalogue
    end
    methods
        function obj = IntentDialog(owner)
            obj.Owner = owner;
            obj.Figure = uifigure('Name','Plan Workflow','Tag','intent-dialog','Visible','off', ...
                'Position',[220 140 700 620],'CloseRequestFcn',@(~,~)obj.close());
            grid = uigridlayout(obj.Figure,[7 1]); grid.RowHeight = {28,24,175,'1x',90,28,24};
            profiles = detecdivui.IntentProfile.all();
            obj.Intent = uidropdown(grid,'Items',{profiles.label},'ItemsData',{profiles.id}, ...
                'Tag','intent-goal','Tooltip','Choose the intended outcome; no processing starts here', ...
                'ValueChangedFcn',@(~,~)obj.refresh(false));
            obj.Target = uilabel(grid,'Text','—','Interpreter','none','Tag','intent-target');
            obj.Methods = uigridlayout(grid,[1 2]); obj.Methods.ColumnWidth = {190,'1x'};
            obj.Methods.Padding = [0 0 0 0]; obj.Methods.Scrollable = 'on';
            obj.Changes = uitable(grid,'ColumnName',{'Step','Change','Details'}, ...
                'ColumnEditable',false,'ColumnWidth',{160,110,'auto'},'RowName',{},'Data',cell(0,3),'Tag','intent-changes');
            obj.Questions = uilistbox(grid,'Items',{'—'},'Tag','intent-questions', ...
                'Tooltip','Outstanding checks and settings; applying a draft never launches processing', ...
                'ValueChangedFcn',@(src,~)set(src,'Tooltip',src.Value));
            buttons = uigridlayout(grid,[1 4]); buttons.Padding = [0 0 0 0];
            uibutton(buttons,'Text','Refresh','Tag','intent-refresh','ButtonPushedFcn',@(~,~)obj.refresh(true));
            uibutton(buttons,'Text','Cancel','Tag','intent-cancel','ButtonPushedFcn',@(~,~)obj.close());
            uibutton(buttons,'Text','History...','Tag','intent-history','ButtonPushedFcn',@(~,~)owner.showPlanHistory());
            obj.Apply = uibutton(buttons,'Text','Use Draft','Tag','intent-apply','Enable','off', ...
                'Tooltip','Create an independent editable pipeline draft; no images or results are written', ...
                'ButtonPushedFcn',@(~,~)obj.apply());
            obj.Status = uilabel(grid,'Text','Ready','Interpreter','none','Tag','intent-status');
            obj.Progress = detecdivui.Progress(grid,obj.Status,'intent-progress');
        end
        function open(obj,intent)
            if nargin>1 && ~isempty(intent), obj.Intent.Value = intent; end
            obj.Figure.Visible = 'on'; obj.refresh(true);
        end
        function refresh(obj,preserve)
            scope = obj.Progress.begin('Inspecting project metadata...'); %#ok<NASGU>
            try
                old = obj.choices(); if ~preserve, old = struct(); end
                [base,state,target] = obj.Owner.planningContext();
                obj.Target.Text = target; obj.Target.Tooltip = target;
                obj.Catalogue = detecdiv_modules_list();
                delete(obj.Methods.Children); obj.Controls = struct();
                roles = detecdivui.IntentPlanner.roles(state,obj.Intent.Value);
                roles = roles(cellfun(@(r)detecdivui.IntentPlanner.needsMethod(state,obj.Intent.Value,r),roles));
                obj.Methods.RowHeight = repmat({28},1,max(1,numel(roles)));
                for k = 1:numel(roles)
                    role = roles{k}; uilabel(obj.Methods,'Text',detecdivui.IntentProfile.label(role));
                    labels = {'Choose / reuse existing step'}; ids = {'auto'};
                    for j = 1:numel(base.nodes)
                        node = base.nodes(j);
                        if detecdivui.IntentProfile.matches(node,role)
                            labels{end+1} = ['Existing: ' node.id]; ids{end+1} = ['step:' node.id]; %#ok<AGROW>
                        end
                    end
                    methods = detecdivui.IntentPlanner.methods(role,obj.Catalogue);
                    for j = 1:numel(methods)
                        labels{end+1} = ['Add: ' methods(j).name]; ids{end+1} = ['module:' methods(j).id]; %#ok<AGROW>
                    end
                    control = uidropdown(obj.Methods,'Items',labels,'ItemsData',ids, ...
                        'Tag',['intent-method-' role],'ValueChangedFcn',@(~,~)obj.preview());
                    if isfield(old,role) && any(strcmp(ids,old.(role))), control.Value = old.(role); end
                    obj.Controls.(role) = control;
                end
                obj.preview();
            catch err
                obj.Owner.cancelProposal(); obj.invalidate(err.message);
            end
        end
        function preview(obj)
            try
                proposal = obj.Owner.proposeIntent(obj.Intent.Value,obj.choices(),obj.Catalogue);
                obj.Changes.Data = proposal.changes(:,[2 3 4]);
                items = proposal.questions; if isempty(items), items = {'No additional checks identified by the planner'}; end
                obj.Questions.Items = items; obj.Apply.Enable = obj.onOff(proposal.canApply);
                obj.Status.Text = 'Proposal · no execution'; obj.Status.Tooltip = obj.Status.Text;
            catch err
                obj.Owner.cancelProposal(); obj.invalidate(err.message);
            end
        end
        function invalidate(obj,message)
            obj.Apply.Enable = 'off'; obj.Status.Text = message; obj.Status.Tooltip = message;
        end
        function close(obj)
            obj.Owner.cancelProposal(); obj.Figure.Visible = 'off';
        end
        function delete(obj)
            if isgraphics(obj.Figure), delete(obj.Figure); end
        end
    end
    methods (Access=private)
        function values = choices(obj)
            values = struct();
            for key = fieldnames(obj.Controls)'
                control = obj.Controls.(key{1});
                if isvalid(control), values.(key{1}) = control.Value; end
            end
        end
        function apply(obj)
            try
                obj.Owner.applyProposal(); obj.Figure.Visible = 'off';
            catch err, obj.invalidate(err.message);
            end
        end
    end
    methods (Static,Access=private)
        function value = onOff(yes)
            value = 'off'; if yes, value = 'on'; end
        end
    end
end
