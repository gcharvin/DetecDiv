classdef PipelineWidget < handle
    % Dockable pipeline frontend. Contracts, validation and editors stay shared.
    properties (SetAccess = private)
        Templates = {}
        Template = []
        LastReport = struct()
        LastOK = false
    end
    properties
        OnStatus = []
        OnChanged = []
    end
    properties (Access = private)
        Session
        Selector
        Target
        Scope
        Steps
        Params
        Checks
        Runs
        RunObjects = []
        Inspect
        Save
        Validate
        DryRun
        Tabs
        StepsTab
        ChecksTab
        Status
        Busy = false
    end
    methods
        function obj = PipelineWidget(parent)
            root = uigridlayout(parent,[6 1]);
            root.Padding = [8 6 8 6]; root.RowHeight = {28,62,22,28,'1x',24};
            obj.Selector = uidropdown(root,'Items',{'—'},'ItemsData',0,'Enable','off', ...
                'Tag','pipeline-template','Tooltip','Select an independent pipeline template', ...
                'ValueChangedFcn',@(~,~)obj.selectTemplate());
            actions = uigridlayout(root,[2 2]); actions.Padding = [0 0 0 0];
            actions.ColumnWidth = {'1x','1x'}; actions.RowHeight = {26,26};
            uibutton(actions,'Text','Open...','Tag','pipeline-open','Tooltip','Open pipeline JSON', ...
                'ButtonPushedFcn',@(~,~)obj.openTemplate());
            obj.Save = uibutton(actions,'Text','Save','Enable','off','Tag','pipeline-save', ...
                'Tooltip','Save this template with pipelineSave', ...
                'ButtonPushedFcn',@(~,~)obj.saveTemplate());
            uibutton(actions,'Text','Editor...','Tag','pipeline-editor', ...
                'Tooltip','Open the existing advanced pipeline editor and run configuration', ...
                'ButtonPushedFcn',@(~,~)obj.openEditor());
            uibutton(actions,'Text','Refresh','Tag','pipeline-refresh', ...
                'Tooltip','Refresh steps and project runs from live objects', ...
                'ButtonPushedFcn',@(~,~)obj.refresh());
            obj.Target = uilabel(root,'Text','—','Interpreter','none','Tag','pipeline-target');
            obj.Scope = uidropdown(root,'Items',{'Current FOV','Current ROI','Whole project'}, ...
                'Enable','off','Tag','pipeline-scope','Tooltip','Target used for validation and dry run', ...
                'ValueChangedFcn',@(~,~)obj.invalidate());
            obj.Tabs = uitabgroup(root);
            stepsTab = uitab(obj.Tabs,'Title','Steps');
            obj.StepsTab = stepsTab;
            stepsGrid = uigridlayout(stepsTab,[3 1]); stepsGrid.Padding = [4 4 4 4];
            stepsGrid.RowHeight = {'1x','1x',28};
            obj.Steps = uitable(stepsGrid,'Data',cell(0,3),'RowName',{}, ...
                'ColumnName',{'Step','Type','State'},'ColumnWidth',{'auto',70,65}, ...
                'Tag','pipeline-steps','Tooltip','Select a step to inspect its parameters', ...
                'CellSelectionCallback',@(~,event)obj.selectStep(event));
            obj.Params = uitable(stepsGrid,'Data',cell(0,3),'RowName',{}, ...
                'ColumnName',{'Parameter','Value','Scope'},'ColumnWidth',{'auto','auto',65}, ...
                'Tag','pipeline-parameters','Tooltip','Template values; edit using the advanced editor');
            checks = uigridlayout(stepsGrid,[1 2]); checks.Padding = [0 0 0 0];
            checks.ColumnWidth = {'1x','1x'};
            obj.Validate = uibutton(checks,'Text','Validate','Enable','off','Tag','pipeline-validate', ...
                'Tooltip','Validate template contracts against the selected target', ...
                'ButtonPushedFcn',@(~,~)obj.check('validate'));
            obj.DryRun = uibutton(checks,'Text','Dry Run','Enable','off','Tag','pipeline-dry-run', ...
                'Tooltip','Resolve bindings and check prerequisites without executing steps', ...
                'ButtonPushedFcn',@(~,~)obj.check('dry'));
            obj.ChecksTab = uitab(obj.Tabs,'Title','Checks');
            checksGrid = uigridlayout(obj.ChecksTab,[1 1]); checksGrid.Padding = [4 4 4 4];
            obj.Checks = uitable(checksGrid,'Data',cell(0,2),'RowName',{}, ...
                'ColumnName',{'Level','Message'},'ColumnWidth',{65,'auto'},'Tag','pipeline-checks');
            runsTab = uitab(obj.Tabs,'Title','Runs');
            runsGrid = uigridlayout(runsTab,[2 1]); runsGrid.Padding = [4 4 4 4];
            runsGrid.RowHeight = {'1x',28};
            obj.Runs = uitable(runsGrid,'Data',cell(0,2),'RowName',{}, ...
                'ColumnName',{'Run','Status'},'ColumnWidth',{'auto',80},'Tag','pipeline-runs', ...
                'CellSelectionCallback',@(~,event)obj.selectRun(event));
            obj.Inspect = uibutton(runsGrid,'Text','Inspect...','Enable','off', ...
                'Tag','pipeline-inspect-run','Tooltip','Inspect the selected pipeline run', ...
                'ButtonPushedFcn',@(~,~)obj.inspectRun());
            obj.Status = uilabel(root,'Text','Ready','Interpreter','none','Tag','pipeline-status');
        end
        function setContext(obj,session)
            obj.Session = session;
            project = session.Project;
            if isempty(project)
                obj.Target.Text = '—'; obj.Scope.Enable = 'off';
            else
                obj.Target.Text = char(string(project.io.file));
                obj.Target.Tooltip = session.breadcrumb(); obj.Scope.Enable = 'on';
            end
            obj.invalidate(); obj.refreshRuns();
        end
        function addTemplate(obj,template)
            assert(isa(template,'pipeline') && isscalar(template) && isvalid(template), ...
                'detecdivui:Pipeline','A live pipeline template is required.');
            index = [];
            for k = 1:numel(obj.Templates)
                other = obj.Templates{k};
                if isvalid(other) && (isequal(other,template) || ...
                        (~isempty(template.path) && strcmpi(template.path,other.path)))
                    index = k; break;
                end
            end
            if isempty(index), index = numel(obj.Templates)+1; end
            obj.Templates{index} = template; obj.Template = template;
            obj.refresh();
        end
        function importWorkspace(obj,entries)
            active = obj.Template;
            for k = find(strcmp({entries.kind},'pipeline')), obj.addTemplate(entries(k).object); end
            if ~isempty(active) && isvalid(active), obj.addTemplate(active); end
        end
        function openTemplate(obj,path)
            try
                if nargin < 2
                    [file,folder] = uigetfile('*.json','Open Pipeline');
                    if isequal(file,0), return; end
                    path = fullfile(folder,file);
                end
                [template,message] = pipelineLoad(path);
                assert(~isempty(template),'detecdivui:PipelineLoad','%s',message);
                obj.addTemplate(template); obj.setStatus('Pipeline opened');
            catch err
                obj.setStatus(err.message);
            end
        end
        function refresh(obj)
            obj.Templates = obj.Templates(cellfun(@(item)isvalid(item),obj.Templates));
            names = cellfun(@(item)char(string(item.strid)),obj.Templates,'UniformOutput',false);
            for k = 1:numel(names), if isempty(names{k}), names{k} = 'Untitled Pipeline'; end, end
            obj.Selector.ItemsData = [];
            if isempty(names)
                obj.Template = []; obj.Selector.Items = {'—'}; obj.Selector.ItemsData = 0;
                obj.Selector.Value = 0; obj.Selector.Enable = 'off';
            else
                obj.Selector.Items = matlab.lang.makeUniqueStrings(names);
                obj.Selector.ItemsData = 1:numel(names); obj.Selector.Enable = 'on';
                index = find(cellfun(@(item)isequal(item,obj.Template),obj.Templates),1);
                if isempty(index), index = 1; end
                obj.Selector.Value = index; obj.Template = obj.Templates{index};
            end
            obj.Steps.Data = cell(0,3); obj.Params.Data = cell(0,3);
            available = ~isempty(obj.Template);
            obj.Save.Enable = obj.onOff(available && ~isempty(obj.Template.path));
            obj.Validate.Enable = obj.onOff(available); obj.DryRun.Enable = obj.onOff(available);
            if available
                obj.Selector.Tooltip = obj.Template.path;
                nodes = obj.Template.nodes; data = cell(numel(nodes),3);
                for k = 1:numel(nodes)
                    name = obj.field(nodes(k),'name',obj.field(nodes(k),'id',''));
                    state = 'Enabled';
                    if ~obj.field(nodes(k),'enabled',true), state = 'Disabled'; end
                    data(k,:) = {char(string(name)),char(string(obj.field(nodes(k),'type',''))),state};
                end
                obj.Steps.Data = data;
                if ~isempty(nodes), obj.showParams(1); end
            end
            obj.invalidate(); obj.refreshRuns();
            if ~isempty(obj.OnChanged), obj.OnChanged(); end
        end
        function [ok,report] = check(obj,mode)
            ok = false; report = struct();
            if obj.Busy || isempty(obj.Template), return; end
            obj.Busy = true; finish = onCleanup(@()obj.endCheck());
            obj.Validate.Enable = 'off'; obj.DryRun.Enable = 'off';
            obj.setStatus('Checking pipeline...'); drawnow;
            try
                ctx = obj.context();
                % The shared binding resolver can mutate handle templates.
                % Validate a value snapshot so Dry Run preserves the live template.
                template = struct('name',obj.Template.strid,'path',obj.Template.path, ...
                    'nodes',obj.Template.nodes,'edges',obj.Template.edges,'branches',obj.Template.branches);
                if strcmp(mode,'dry')
                    [ok,report] = runPipelineDry(template,ctx,struct('allowGui',false));
                else
                    [ok,report] = validatePipeline(template,ctx,struct('allowGui',false));
                end
                data = cell(0,2);
                for level = {'errors','warnings'}
                    messages = obj.field(report,level{1},{});
                    label = 'Error'; if strcmp(level{1},'warnings'), label = 'Warning'; end
                    for k = 1:numel(messages), data(end+1,:) = {label,char(string(messages{k}))}; end %#ok<AGROW>
                end
                if isempty(data), data = {'OK','No issues found'}; end
                obj.Checks.Data = data; obj.LastReport = report; obj.LastOK = ok;
                label = 'Validation'; if strcmp(mode,'dry'), label = 'Dry run'; end
                result = 'passed'; if ~ok, result = 'failed'; end
                obj.setStatus([label ' ' result]);
            catch err
                obj.LastOK = false; obj.LastReport = struct('errors',{{err.message}});
                report = obj.LastReport;
                obj.Checks.Data = {'Error',err.message}; obj.setStatus(err.message);
            end
            obj.Tabs.SelectedTab = obj.ChecksTab;
        end
        function ctx = context(obj)
            ctx = struct('allowGUI',false,'interactive',false);
            if isempty(obj.Session) || isempty(obj.Session.Project), return; end
            session = obj.Session; project = session.Project;
            [~,indices] = session.positionItems(); roiIndex = [];
            if ~strcmp(obj.Scope.Value,'Whole project')
                assert(session.Position > 0,'detecdivui:PipelineTarget','Select a FOV first.');
                indices = session.Position;
            end
            if strcmp(obj.Scope.Value,'Current ROI')
                assert(session.Zone > 0,'detecdivui:PipelineTarget','Select a ROI first.');
                roiIndex = session.Zone;
            end
            ctx.shallow = project; ctx.shallowObj = project;
            ctx.fovList = project.fov(indices);
            ctx.images = ctx.fovList;
            rois = [];
            for k = indices
                candidates = project.fov(k).roi;
                if ~isempty(roiIndex), candidates = candidates(roiIndex); end
                for j = 1:numel(candidates)
                    item = candidates(j);
                    if strlength(string(item.id)) > 0 || ~isempty(item.value) || ~isempty(item.image)
                        if isempty(rois), rois = item; else, rois(end+1) = item; end %#ok<AGROW>
                    end
                end
            end
            if ~isempty(rois), ctx.roiList = rois; ctx.rois = rois; end
            ctx.sel = struct('fovs',indices,'rois',roiIndex,'frames',[]);
            ctx.run = struct('fovIndex',indices,'rois',roiIndex,'frames',[]);
        end
        function saveTemplate(obj)
            if isempty(obj.Template), return; end
            try
                pipelineSave(obj.Template); obj.setStatus('Pipeline saved');
            catch err
                obj.setStatus(err.message);
            end
        end
        function editor = openEditor(obj)
            editor = [];
            try
                args = {};
                if ~isempty(obj.Template), args{end+1} = obj.Template; end
                if ~isempty(obj.Session) && ~isempty(obj.Session.Project)
                    args = [args {obj.Session.Project,'UnlockRuntime',true}];
                    if obj.Session.Position > 0 && ~strcmp(obj.Scope.Value,'Whole project')
                        args = [args {'fovs',mat2str(obj.Session.Position)}];
                        if strcmp(obj.Scope.Value,'Current ROI') && obj.Session.Zone > 0
                            args = [args {'rois',mat2str(obj.Session.Zone)}];
                        end
                    end
                end
                editor = pipeline2(args{:});
            catch err
                obj.setStatus(err.message);
            end
        end
    end
    methods (Access = private)
        function selectTemplate(obj)
            obj.Template = obj.Templates{obj.Selector.Value}; obj.refresh();
        end
        function selectStep(obj,event)
            if isempty(event.Indices), return; end
            obj.showParams(event.Indices(1,1));
        end
        function showParams(obj,index)
            node = obj.Template.nodes(index); params = obj.field(node,'params',struct());
            data = cell(0,3);
            if isstruct(params) && isscalar(params)
                keys = fieldnames(params);
                for k = 1:numel(keys)
                    value = params.(keys{k});
                    if ischar(value) || (isstring(value) && isscalar(value))
                        text = char(string(value));
                    elseif (isnumeric(value) || islogical(value)) && numel(value) <= 12
                        text = mat2str(value);
                    else
                        text = sprintf('%s %s',mat2str(size(value)),class(value));
                    end
                    data(end+1,:) = {keys{k},text,pipelineParamScope(node,keys{k})}; %#ok<AGROW>
                end
            end
            obj.Params.Data = data;
        end
        function refreshRuns(obj)
            obj.RunObjects = []; obj.Runs.Data = cell(0,2); obj.Inspect.Enable = 'off';
            obj.Inspect.UserData = [];
            if isempty(obj.Template) || isempty(obj.Session) || isempty(obj.Session.Project), return; end
            [runs,~] = obj.Template.findDependentRuns(obj.Session.Project);
            runs = runs(isvalid(runs)); obj.RunObjects = runs;
            data = cell(numel(runs),2);
            for k = 1:numel(runs), data(k,:) = {runs(k).runId,runs(k).status}; end
            obj.Runs.Data = data;
        end
        function selectRun(obj,event)
            if isempty(event.Indices), return; end
            obj.Inspect.UserData = event.Indices(1,1); obj.Inspect.Enable = 'on';
        end
        function inspectRun(obj)
            index = obj.Inspect.UserData;
            if isempty(index), return; end
            try
                pipelineRunInspector(obj.RunObjects(index),obj.Session.Project);
            catch err
                obj.setStatus(err.message);
            end
        end
        function invalidate(obj)
            obj.LastReport = struct(); obj.LastOK = false;
            obj.Checks.Data = cell(0,2); obj.setStatus('Ready');
            if isequal(obj.Tabs.SelectedTab,obj.ChecksTab), obj.Tabs.SelectedTab = obj.StepsTab; end
        end
        function endCheck(obj)
            obj.Busy = false;
            obj.Validate.Enable = obj.onOff(~isempty(obj.Template));
            obj.DryRun.Enable = obj.Validate.Enable;
        end
        function setStatus(obj,message)
            obj.Status.Text = message; obj.Status.Tooltip = message;
            if ~isempty(obj.OnStatus), obj.OnStatus(message); end
        end
    end
    methods (Static, Access = private)
        function value = field(item,name,default)
            value = default;
            if isstruct(item) && isfield(item,name), value = item.(name); end
        end
        function value = onOff(condition)
            if condition, value = 'on'; else, value = 'off'; end
        end
    end
end
