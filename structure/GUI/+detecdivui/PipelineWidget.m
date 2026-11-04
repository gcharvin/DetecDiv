classdef PipelineWidget < handle
    % Dockable pipeline frontend. Contracts, validation and editors stay shared.
    properties (SetAccess = private)
        Templates = {}
        Template = []
        LastReport = struct()
        LastOK = false
        Draft
        LastRunReview = struct()
        Graph
        RunGraph
        Setup
        Progress
        SettingsFigure
        CompactGraph
        AdvancedEditor = []
    end
    properties
        OnStatus = []
        OnChanged = []
        OnDefineROIs = []
        OnProjectUpdated = []
    end
    properties (Access = private)
        Session
        Selector
        Target
        Scope
        Steps
        Params
        SelectedStep = 0
        ParamKeys = {}
        ParamSpecs
        SelectedParam = 0
        ValueText
        ValueNumber
        ValueLogical
        ValueChoice
        ApplyParam
        ResetParam
        Checks
        Runs
        RunObjects = []
        RunReviews = {}
        Inspect
        MoreRun
        RunSummary
        RunNodes
        RunIssues
        Save
        Validate
        DryRun
        Tabs
        StepsTab
        ChecksTab
        Status
        Busy = false
        RunTab
        SaveRun
        NewRun
        RunPicker
        RunState
        SettingsButton
        Syncing = false
        DefinitionContext = 0
        FollowTimer = []
    end
    methods
        function obj = PipelineWidget(parent)
            obj.Draft = detecdivui.RunDraft();
            obj.SettingsFigure = uifigure('Name','Run Settings','Visible','off', ...
                'Position',[230 140 700 580],'Tag','pipeline-settings-dialog', ...
                'CloseRequestFcn',@(~,~)set(obj.SettingsFigure,'Visible','off'));
            root = uigridlayout(obj.SettingsFigure,[6 1]);
            root.Padding = [8 6 8 6]; root.RowHeight = {28,62,22,28,'1x',24};
            obj.Selector = uidropdown(root,'Items',{'—'},'ItemsData',0,'Enable','off', ...
                'Tag','pipeline-template','Tooltip','Select an independent pipeline template', ...
                'ValueChangedFcn',@(~,~)obj.selectTemplate());
            actions = uigridlayout(root,[2 2]); actions.Padding = [0 0 0 0];
            actions.ColumnWidth = {'1x','1x'}; actions.RowHeight = {26,26};
            uibutton(actions,'Text','Open...','Tag','pipeline-open','Tooltip','Open pipeline JSON', ...
                'ButtonPushedFcn',@(~,~)obj.openTemplate());
            obj.Save = uibutton(actions,'Text','Save','Enable','off','Tag','pipeline-save', ...
                'Tooltip','Save the template; run overrides remain local to this session', ...
                'ButtonPushedFcn',@(~,~)obj.saveTemplate());
            obj.NewRun = uibutton(actions,'Text','New Run','Tag','pipeline-new-run','Enable','off', ...
                'Tooltip','Start a new run configuration for this project and template', ...
                'ButtonPushedFcn',@(~,~)obj.newRun());
            uibutton(actions,'Text','Editor...','Tag','pipeline-editor', ...
                'Tooltip','Open the existing advanced pipeline editor and run configuration', ...
                'ButtonPushedFcn',@(~,~)obj.openEditor());
            obj.Target = uilabel(root,'Text','—','Interpreter','none','Tag','pipeline-target');
            obj.Scope = uidropdown(root,'Items',{'Current FOV','Current ROI','Whole project','Run selection'}, ...
                'Enable','off','Tag','pipeline-scope','Tooltip','Target used for validation and dry run', ...
                'ValueChangedFcn',@(~,~)obj.invalidate());
            obj.Tabs = uitabgroup(root);
            obj.RunTab = uitab(obj.Tabs,'Title','Run');
            runGrid = uigridlayout(obj.RunTab,[2 1]); runGrid.Padding = [4 4 4 4];
            runGrid.RowHeight = {'1x',28};
            obj.Setup = detecdivui.RunSetup(runGrid);
            obj.Setup.OnChanged = @()obj.settingsChanged();
            obj.SaveRun = uibutton(runGrid,'Text','Save Run','Enable','off','Tag','pipeline-save-run', ...
                'Tooltip','Save a new run configuration without starting processing', ...
                'ButtonPushedFcn',@(~,~)obj.saveRun());
            stepsTab = uitab(obj.Tabs,'Title','Steps');
            obj.StepsTab = stepsTab;
            stepsGrid = uigridlayout(stepsTab,[4 1]); stepsGrid.Padding = [4 4 4 4];
            stepsGrid.RowHeight = {'1x','1x',28,28};
            views = uitabgroup(stepsGrid);
            graphTab = uitab(views,'Title','Graph'); listTab = uitab(views,'Title','List');
            obj.Graph = detecdivui.PipelineGraph(graphTab,'pipeline-graph');
            obj.Graph.OnSelect = @(index)obj.showParams(index);
            obj.Graph.OnToggle = @(index)obj.toggleStep(index);
            listGrid = uigridlayout(listTab,[1 1]); listGrid.Padding = [0 0 0 0];
            obj.Steps = uitable(listGrid,'Data',cell(0,3),'RowName',{}, ...
                'ColumnName',{'Step','Type','State'},'ColumnWidth',{'auto',70,65}, ...
                'Tag','pipeline-steps','Tooltip','Select a step to inspect its parameters', ...
                'CellSelectionCallback',@(~,event)obj.selectStep(event));
            obj.Params = uitable(stepsGrid,'Data',cell(0,3),'RowName',{}, ...
                'ColumnName',{'Parameter','Value','Scope'},'ColumnWidth',{'auto','auto',65}, ...
                'Tag','pipeline-parameters','Tooltip','Select a run parameter to edit; * marks a run override', ...
                'CellSelectionCallback',@(~,event)obj.selectParam(event));
            edit = uigridlayout(stepsGrid,[1 3]); edit.Padding = [0 0 0 0];
            edit.ColumnWidth = {'1x',48,48};
            input = uigridlayout(edit,[1 1]); input.Padding = [0 0 0 0];
            obj.ValueText = uieditfield(input,'text','Enable','off','Tag','pipeline-value-text', ...
                'Placeholder','Select a run parameter');
            obj.ValueNumber = uieditfield(input,'numeric','Visible','off','Tag','pipeline-value-number');
            obj.ValueLogical = uicheckbox(input,'Text','','Visible','off','Tag','pipeline-value-logical');
            obj.ValueChoice = uidropdown(input,'Items',{'—'},'Visible','off','Tag','pipeline-value-choice');
            for item = {obj.ValueText,obj.ValueNumber,obj.ValueLogical,obj.ValueChoice}
                control = item{1}; control.Layout.Row = 1; control.Layout.Column = 1;
            end
            input.RowHeight = {'1x'}; input.ColumnWidth = {'1x'};
            obj.ApplyParam = uibutton(edit,'Text','Apply','Enable','off','Tag','pipeline-apply-param', ...
                'Tooltip','Apply this value to the run draft without changing the template', ...
                'ButtonPushedFcn',@(~,~)obj.applyParameter());
            obj.ResetParam = uibutton(edit,'Text','Reset','Enable','off','Tag','pipeline-reset-param', ...
                'Tooltip','Use the template value for this run parameter', ...
                'ButtonPushedFcn',@(~,~)obj.resetParameter());
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
            runsGrid = uigridlayout(runsTab,[3 1]); runsGrid.Padding = [4 4 4 4];
            runsGrid.RowHeight = {'1x','1x',28};
            obj.Runs = uitable(runsGrid,'Data',cell(0,2),'RowName',{}, ...
                'ColumnName',{'Run','Status'},'ColumnWidth',{'auto',80},'Tag','pipeline-runs', ...
                'CellSelectionCallback',@(~,event)obj.selectRun(event));
            details = uitabgroup(runsGrid);
            summary = uitab(details,'Title','Summary');
            nodes = uitab(details,'Title','Steps'); issues = uitab(details,'Title','Issues');
            grid = uigridlayout(summary,[1 1]); grid.Padding = [0 0 0 0];
            obj.RunSummary = uitable(grid,'Data',cell(0,2),'RowName',{}, ...
                'ColumnName',{'','Value'},'ColumnWidth',{90,'auto'},'Tag','pipeline-run-summary');
            nodeViews = uitabgroup(nodes);
            nodeGraph = uitab(nodeViews,'Title','Graph'); nodeList = uitab(nodeViews,'Title','List');
            obj.RunGraph = detecdivui.PipelineGraph(nodeGraph,'pipeline-run-graph');
            grid = uigridlayout(nodeList,[1 1]); grid.Padding = [0 0 0 0];
            obj.RunNodes = uitable(grid,'Data',cell(0,3),'RowName',{}, ...
                'ColumnName',{'Step','Status','Seconds'},'ColumnWidth',{'auto',70,65},'Tag','pipeline-run-nodes');
            grid = uigridlayout(issues,[1 1]); grid.Padding = [0 0 0 0];
            obj.RunIssues = uitable(grid,'Data',cell(0,1),'RowName',{}, ...
                'ColumnName',{'Message'},'ColumnWidth',{'auto'},'Tag','pipeline-run-issues');
            actions = uigridlayout(runsGrid,[1 3]); actions.Padding = [0 0 0 0];
            actions.ColumnWidth = {'1x','1x','1x'};
            obj.Inspect = uibutton(actions,'Text','Review','Enable','off', ...
                'Tag','pipeline-inspect-run','Tooltip','Read the selected run review and event log', ...
                'ButtonPushedFcn',@(~,~)obj.reviewRun());
            obj.MoreRun = uibutton(actions,'Text','More...','Enable','off','Tag','pipeline-more-run', ...
                'Tooltip','Open the existing detailed run inspector', ...
                'ButtonPushedFcn',@(~,~)obj.inspectRun());
            uibutton(actions,'Text','Refresh','Tag','pipeline-refresh', ...
                'Tooltip','Refresh steps and project runs from live objects', ...
                'ButtonPushedFcn',@(~,~)obj.refresh());
            obj.Tabs.SelectedTab = obj.StepsTab;
            obj.Status = uilabel(root,'Text','Ready','Interpreter','none','Tag','pipeline-status');
            % The dialog edits the same controls/model used by context/save.
            compact = uigridlayout(parent,[8 1]); compact.Padding = [8 6 8 6];
            compact.RowHeight = {28,22,28,28,'1x',22,28,24};
            obj.Selector.Parent = compact; obj.Selector.Layout.Row = 1; obj.Selector.Layout.Column = 1;
            obj.Target.Parent = compact; obj.Target.Layout.Row = 2; obj.Target.Layout.Column = 1;
            buttons = uigridlayout(compact,[1 2]); buttons.Padding = [0 0 0 0]; buttons.Layout.Row = 3;
            obj.NewRun.Parent = buttons; obj.NewRun.Layout.Row = 1; obj.NewRun.Layout.Column = 1;
            obj.SettingsButton = uibutton(buttons,'Text','Settings...','Tag','pipeline-settings', ...
                'Tooltip','Edit the current run configuration','ButtonPushedFcn',@(~,~)obj.openSettings('Run'));
            obj.RunPicker = uidropdown(compact,'Items',{'Draft'},'ItemsData',{'draft'}, ...
                'Tag','pipeline-run-picker','Tooltip','Select a run or the current draft', ...
                'ValueChangedFcn',@(~,~)obj.selectCompactRun());
            obj.RunPicker.Layout.Row = 4;
            panel = uipanel(compact,'BorderType','none'); panel.Layout.Row = 5;
            obj.CompactGraph = detecdivui.PipelineGraph(panel,'pipeline-compact-graph');
            obj.CompactGraph.OnSelect = @(index)obj.openStep(index);
            obj.RunState = uilabel(compact,'Text','Draft','Tag','pipeline-run-state','Interpreter','none');
            obj.RunState.Layout.Row = 6;
            buttons = uigridlayout(compact,[1 2]); buttons.Padding = [0 0 0 0]; buttons.Layout.Row = 7;
            uibutton(buttons,'Text','Refresh','Tooltip','Refresh the selected run and its review', ...
                'ButtonPushedFcn',@(~,~)obj.refreshSelectedRun());
            uibutton(buttons,'Text','Details...','Tooltip','Open checks and run details', ...
                'ButtonPushedFcn',@(~,~)obj.openSettings('Runs'));
            obj.Status.Parent = compact; obj.Status.Layout.Row = 8; obj.Status.Layout.Column = 1;
            obj.Progress = detecdivui.Progress(compact,obj.Status,'pipeline-progress');
            root.RowHeight = {0,0,0,0,'1x',28};
            footer = uigridlayout(root,[1 2]); footer.Padding = [0 0 0 0]; footer.Layout.Row = 6;
            uibutton(footer,'Text','Done','ButtonPushedFcn',@(~,~)set(obj.SettingsFigure,'Visible','off'));
            advanced = findall(obj.SettingsFigure,'Tag','pipeline-editor');
            advanced.Parent = footer; advanced.Layout.Row = 1; advanced.Layout.Column = 2; advanced.Text = 'Advanced...';
            define = uibutton(checks,'Text','Define ROIs...','Tag','pipeline-define-rois', ...
                'Tooltip','Define ROIs on the main image','ButtonPushedFcn',@(~,~)obj.defineROIs());
            define.Layout.Row = 1; define.Layout.Column = 3;
            checks.ColumnWidth = {'1x','1x','1x'};
            obj.FollowTimer = timer('ExecutionMode','fixedSpacing','Period',1.5,'BusyMode','drop', ...
                'Tag','DetecDivPipelineFollow','TimerFcn',@(~,~)obj.followRun());
            start(obj.FollowTimer);
        end
        function openSettings(obj,page)
            if nargin < 2, page = 'Run'; end
            if ~obj.syncAdvanced(), return; end
            obj.loadSelectedRun();
            tabs = obj.Tabs.Children;
            index = find(strcmp({tabs.Title},page),1);
            if ~isempty(index), obj.Tabs.SelectedTab = tabs(index); end
            obj.SettingsFigure.Visible = 'on'; figure(obj.SettingsFigure);
        end
        function delete(obj)
            if ~isempty(obj.FollowTimer) && isvalid(obj.FollowTimer), stop(obj.FollowTimer); delete(obj.FollowTimer); end
            if ~isempty(obj.SettingsFigure) && isvalid(obj.SettingsFigure), delete(obj.SettingsFigure); end
            if ~isempty(obj.AdvancedEditor) && isvalid(obj.AdvancedEditor)
                editor = obj.AdvancedEditor; editor.clearViewerBridge();
                if ~editor.viewerHasActiveRun(), delete(editor); end
            end
        end
        function setContext(obj,session)
            if ~isempty(obj.Session) && ~isequal(obj.Session.Project,session.Project)
                if ~obj.syncAdvanced(), return; end
                obj.SettingsFigure.Visible = 'off';
            end
            obj.Session = session;
            project = session.Project;
            obj.Draft.select(project,obj.Template);
            obj.loadSettings();
            obj.NewRun.Enable = obj.onOff(~isempty(project) && ~isempty(obj.Template));
            obj.SaveRun.Enable = obj.NewRun.Enable;
            if isempty(project)
                obj.Target.Text = '—'; obj.Scope.Enable = 'off';
            else
                obj.Target.Text = char(string(project.io.file));
                obj.Target.Tooltip = session.breadcrumb(); obj.Scope.Enable = 'on';
            end
            if obj.SelectedStep > 0 && ~isempty(obj.Template) && obj.SelectedStep <= numel(obj.Template.nodes)
                obj.showParams(obj.SelectedStep);
            end
            obj.invalidate(); obj.refreshRuns();
            obj.updateGraph();
            obj.draftNotice();
        end
        function addTemplate(obj,template)
            if ~obj.Syncing && ~obj.syncAdvanced(), return; end
            assert(isa(template,'pipeline') && isscalar(template) && isvalid(template), ...
                'detecdivui:Pipeline','A live pipeline template is required.');
            if isempty(obj.Template) || obj.Template ~= template, obj.DefinitionContext = obj.DefinitionContext+1; end
            index = [];
            for k = 1:numel(obj.Templates)
                other = obj.Templates{k};
                if isvalid(other) && (isequal(other,template) || ...
                        (~isempty(template.path) && strcmpi(template.path,other.path)))
                    if other ~= template, obj.Draft.forgetTemplate(other); end
                    index = k; break;
                end
            end
            if isempty(index), index = numel(obj.Templates)+1; end
            obj.Templates{index} = template; obj.Template = template;
            obj.refresh();
        end
        function importWorkspace(obj,entries)
            if ~obj.syncAdvanced(), return; end
            active = obj.Template;
            for k = find(strcmp({entries.kind},'pipeline'))
                entry = entries(k).object;
                if ~isempty(active) && isvalid(active) && ~isempty(active.path) && ...
                        entry ~= active && strcmpi(entry.path,active.path), continue; end
                obj.addTemplate(entry);
            end
            if ~isempty(active) && isvalid(active), obj.addTemplate(active); end
        end
        function openTemplate(obj,path)
            try
                if nargin < 2
                    [file,folder] = uigetfile('*.json','Open Pipeline');
                    if isequal(file,0), return; end
                    path = fullfile(folder,file);
                end
                activity = obj.Progress.begin('Loading pipeline...'); %#ok<NASGU>
                [template,message] = pipelineLoad(path);
                assert(~isempty(template),'detecdivui:PipelineLoad','%s',message);
                obj.addTemplate(template); obj.setStatus('Pipeline opened');
            catch err
                obj.setStatus(err.message);
            end
        end
        function refresh(obj)
            activity = obj.Progress.begin('Refreshing pipeline...'); %#ok<NASGU>
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
            obj.SelectedStep = 0; obj.clearParamEditor();
            project = []; if ~isempty(obj.Session), project = obj.Session.Project; end
            obj.Draft.select(project,obj.Template);
            obj.loadSettings();
            available = ~isempty(obj.Template);
            obj.Save.Enable = obj.onOff(available && ~isempty(obj.Template.path));
            obj.SettingsButton.Enable = obj.onOff(available);
            obj.NewRun.Enable = obj.onOff(available && ~isempty(project));
            obj.SaveRun.Enable = obj.NewRun.Enable;
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
            obj.updateGraph();
            obj.draftNotice();
            if ~isempty(obj.OnChanged), obj.OnChanged(); end
        end
        function [ok,report] = check(obj,mode)
            ok = false; report = struct();
            if ~obj.syncAdvanced(), return; end
            if obj.Busy || isempty(obj.Template), return; end
            obj.Busy = true; finish = onCleanup(@()obj.endCheck());
            activity = obj.Progress.begin('Checking pipeline...'); %#ok<NASGU>
            obj.Validate.Enable = 'off'; obj.DryRun.Enable = 'off';
            obj.setStatus('Checking pipeline...');
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
            obj.Draft.reconcile();
            if obj.Draft.takeDiscarded() > 0
                obj.refresh();
                error('detecdivui:RunDraftChanged','Run settings reset after template changes. Review the parameters and validate again.');
            end
            ctx = struct('allowGUI',false,'interactive',false);
            ctx.run = struct('nodeParams',obj.Draft.Overrides);
            included = obj.includedSteps();
            assert(any(included),'detecdivui:RunSteps','Select at least one enabled step.');
            selectedIds = {obj.Template.nodes(included).id};
            ctx.run.selectedNodes = selectedIds;
            if isempty(obj.Session) || isempty(obj.Session.Project), return; end
            session = obj.Session; project = session.Project;
            [~,indices] = session.positionItems(); roiIndex = [];
            settings = obj.Setup.values();
            rawMode = strcmp(settings.inputSourceMode,'raw_dataloader');
            if strcmp(obj.Scope.Value,'Run selection')
                if rawMode
                    indices = detecdivui.RunSetup.selection(settings.fovs);
                    roiIndex = detecdivui.RunSetup.selection(settings.rois);
                else
                    indices = detecdivui.RunSetup.selection(settings.fovs,cellstr(string({project.fov.id})));
                    if isempty(indices), [~,indices] = session.positionItems(); end
                    assert(all(indices <= numel(project.fov)),'detecdivui:FOVSelection','FOV index is out of range.');
                    roiIndex = detecdivui.RunSetup.selection(settings.rois,obj.roiIds(indices));
                end
            elseif ~strcmp(obj.Scope.Value,'Whole project')
                assert(session.Position > 0,'detecdivui:PipelineTarget','Select a FOV first.');
                indices = session.Position;
            end
            if strcmp(obj.Scope.Value,'Current ROI')
                assert(session.Zone > 0,'detecdivui:PipelineTarget','Select a ROI first.');
                roiIndex = session.Zone;
            end
            ctx.shallow = project; ctx.shallowObj = project;
            if ~rawMode
                ctx.fovList = project.fov(indices);
                ctx.images = ctx.fovList;
            end
            rois = [];
            roiFovs = indices; if rawMode, roiFovs = []; end
            for k = roiFovs
                candidates = project.fov(k).roi;
                if ~isempty(roiIndex)
                    assert(all(roiIndex <= numel(candidates)),'detecdivui:ROISelection','ROI index is out of range for a selected FOV.');
                    candidates = candidates(roiIndex);
                end
                for j = 1:numel(candidates)
                    item = candidates(j);
                    if strlength(string(item.id)) > 0 || ~isempty(item.value) || ~isempty(item.image)
                        if isempty(rois), rois = item; else, rois(end+1) = item; end %#ok<AGROW>
                    end
                end
            end
            if ~isempty(rois), ctx.roiList = rois; ctx.rois = rois; end
            frames = detecdivui.RunSetup.selection(settings.frames);
            ctx.sel = struct('fovs',indices,'rois',roiIndex,'frames',frames);
            ctx.run = struct('fovIndex',indices,'rois',roiIndex,'frames',frames, ...
                'nodeParams',obj.Draft.Overrides);
            ctx.run.selectedNodes = selectedIds;
            ctx.run.runPolicy = settings.runPolicy; ctx.run.resume = strcmp(settings.runPolicy,'resume');
            ctx.run.gpuPolicy = settings.gpuPolicy; ctx.run.executionTarget = settings.executionTarget;
            ctx.run.inputSourceMode = settings.inputSourceMode;
            ctx.run.useExistingProjectSources = strcmp(settings.inputSourceMode,'existing_rois');
            ctx.run.rawDataPath = settings.rawDataPath;
            ctx.run.projectPath = fullfile(project.io.path,project.io.file);
            ctx.io = struct('existingPolicy',settings.outputPolicy,'globalExistingPolicy',settings.outputPolicy, ...
                'rawDataPath',settings.rawDataPath,'projectPath',ctx.run.projectPath);
            ctx.rawDataPath = settings.rawDataPath;
            ctx.dataLoader = struct('path',settings.rawDataPath,'useExistingProjectSources',ctx.run.useExistingProjectSources);
            for k = 1:numel(obj.Template.nodes)
                node = obj.Template.nodes(k);
                if ~strcmpi(node.type,'dataLoader'), continue; end
                index = find(strcmp({ctx.run.nodeParams.id},node.id),1);
                if isempty(index)
                    ctx.run.nodeParams(end+1) = struct('id',node.id,'params',struct()); index = numel(ctx.run.nodeParams);
                end
                ctx.run.nodeParams(index).params.useExistingProjectSources = ~rawMode;
                if rawMode, ctx.run.nodeParams(index).params.path = settings.rawDataPath; end
            end
            if strcmp(settings.inputSourceMode,'raw_dataloader')
                assert(~isempty(strtrim(settings.rawDataPath)),'detecdivui:RawDataPath','Choose a raw data folder in Run.');
                ctx = rmfield(ctx,intersect(fieldnames(ctx),{'fovList','images','roiList','rois'}));
            end
            if isfield(obj.Draft.Settings,'extraContext')
                extra = obj.Draft.Settings.extraContext;
                if isfield(extra,'run'), ctx.run = obj.overlay(extra.run,ctx.run); end
                if isfield(extra,'io'), ctx.io = obj.overlay(extra.io,ctx.io); end
                for key = {'hub','exec','names','executionPolicy'}
                    if isfield(extra,key{1}), ctx.(key{1}) = extra.(key{1}); end
                end
            end
        end
        function run = draftRun(obj)
            assert(~isempty(obj.Template),'detecdivui:Pipeline','Select a pipeline.');
            run = pipelineRun(); run.runId = obj.nextRunId();
            run.templateId = obj.Template.strid; run.templatePath = obj.Template.path;
            run.pipelineRef = struct('id',obj.Template.strid,'path',obj.Template.path,'version',obj.Template.version);
            ctx = obj.context();
            ctx = rmfield(ctx,intersect(fieldnames(ctx),{'shallow','shallowObj','images','fovList','roiList','rois'}));
            run.ctx = ctx;
            run.ctx.pipelineSpec = struct('name',obj.Template.strid,'path',obj.Template.path, ...
                'nodes',obj.Template.nodes,'edges',obj.Template.edges,'branches',obj.Template.branches);
            settings = obj.Setup.values(); run.description = settings.description;
            if ~isempty(strtrim(settings.runId)), run.runId = strtrim(settings.runId); end
            if ~isempty(obj.Session) && ~isempty(obj.Session.Project)
                project = obj.Session.Project; run.projectName = project.io.file;
                if ~isempty(project.io.path), run.projectPath = fullfile(project.io.path,project.io.file); end
                run.targetRef.projectPath = run.projectPath; run.targetRef.projectName = run.projectName;
                run.targetRef.fovIds = ctx.sel.fovs; run.targetRef.roiIds = ctx.sel.rois;
            end
        end
        function forgetProject(obj,project)
            if ~isempty(obj.Session) && isequal(obj.Session.Project,project), obj.syncAdvanced(); end
            obj.Draft.forgetProject(project);
        end
        function newRun(obj)
            if ~obj.syncAdvanced(), return; end
            if isempty(obj.Template) || isempty(obj.Session) || isempty(obj.Session.Project), return; end
            % Starting over is explicit; it never creates a folder or starts work.
            obj.Draft.newRun(); obj.Setup.load(struct());
            settings = obj.Setup.values();
            if obj.Session.Position > 0, settings.fovs = num2str(obj.Session.Position); end
            if obj.Session.Zone > 0, settings.rois = num2str(obj.Session.Zone); end
            obj.Draft.configure(settings); obj.loadSettings();
            obj.Scope.Value = 'Run selection'; obj.refresh(); obj.Tabs.SelectedTab = obj.RunTab;
            obj.setStatus('New run draft');
            obj.RunPicker.Value = 'draft'; obj.openSettings('Run');
            obj.updateGraph();
        end
        function run = saveRun(obj)
            run = [];
            if ~obj.syncAdvanced(), return; end
            activity = obj.Progress.begin('Saving run...'); %#ok<NASGU>
            try
                draft = obj.draftRun(); project = obj.Session.Project;
                assert(~isempty(project.io.path) && isfolder(fullfile(project.io.path,project.io.file)), ...
                    'detecdivui:ProjectPath','Save the project before saving a run.');
                settings = obj.Setup.values(); id = strtrim(settings.runId);
                assert(isempty(id) || (~isempty(regexp(id,'^[A-Za-z0-9][A-Za-z0-9_.-]*$','once')) && ~ismember(id,{'.','..'})), ...
                    'detecdivui:RunId','Use letters, numbers, dots, underscores or hyphens for the run ID.');
                existing = project.processing.pipelineRun; names = {};
                if ~isempty(existing), names = {existing.runId}; end
                update = [];
                if ~isempty(id) && any(strcmp(names,id))
                    update = existing(find(strcmp(names,id),1));
                    assert(strcmp(update.status,'new'),'detecdivui:RunExists', ...
                        'This run has execution history. Use New Run or Advanced to resume it.');
                elseif ~isempty(id)
                    assert(~any(strcmp(names,id)) && ~isfolder(fullfile(project.io.path,project.io.file,'pipeline',id)), ...
                        'detecdivui:RunExists','Run ID already exists. Choose a new ID.');
                else
                    base = matlab.lang.makeValidName(char(string(obj.Template.strid))); n = 1;
                    id = sprintf('%s_%d',base,n);
                    while any(strcmp(names,id)) || isfolder(fullfile(project.io.path,project.io.file,'pipeline',id))
                        n = n+1; id = sprintf('%s_%d',base,n);
                    end
                end
                if isempty(update)
                    run = pipelineRunNew(project,obj.Template.strid,obj.Template.path,'runId',id, ...
                    'ctx',draft.ctx,'description',draft.description,'pipelineRef',draft.pipelineRef, ...
                    'targetRef',draft.targetRef,'notifyWorkspace',false);
                else
                    run = update; run.ctx = draft.ctx; run.description = draft.description;
                    run.pipelineRef = draft.pipelineRef; run.targetRef = draft.targetRef;
                end
                pipelineRunSave(run,struct('sidecars',false,'verbose',false));
                shallowSave(project,'shallowObj');
                settings.runId = run.runId;
                if isfield(obj.Draft.Settings,'selectedNodes'), settings.selectedNodes = obj.Draft.Settings.selectedNodes; end
                obj.Draft.configure(settings); obj.Setup.load(settings);
                obj.refreshRuns(); obj.setStatus(['Run saved: ' run.runId]);
                obj.RunPicker.Value = run.runId; obj.selectCompactRun();
            catch err
                obj.setStatus(err.message);
            end
        end
        function saveTemplate(obj)
            if ~obj.syncAdvanced(), return; end
            if isempty(obj.Template), return; end
            activity = obj.Progress.begin('Saving pipeline...'); %#ok<NASGU>
            try
                pipelineSave(obj.Template); obj.setStatus('Pipeline saved');
            catch err
                obj.setStatus(err.message);
            end
        end
        function editor = openEditor(obj)
            if ~isempty(obj.AdvancedEditor) && isvalid(obj.AdvancedEditor)
                editor = obj.AdvancedEditor; editor.UIFigure.Visible = 'on'; return;
            end
            obj.loadSelectedRun();
            editor = [];
            activity = obj.Progress.begin('Opening pipeline editor...'); %#ok<NASGU>
            try
                args = {};
                if ~isempty(obj.Template), args{end+1} = obj.Template; end
                if ~isempty(obj.Session) && ~isempty(obj.Session.Project)
                    projectName = matlab.lang.makeValidName(char(string(obj.Session.Project.io.file)));
                    if isempty(projectName), projectName = 'project'; end
                    projectName = matlab.lang.makeUniqueStrings(projectName,evalin('base','who'),namelengthmax);
                    args = [args {obj.Session.Project,'UnlockRuntime',true,'ProjectVarName',projectName}];
                    if obj.Session.Position > 0 && ~ismember(obj.Scope.Value,{'Whole project','Run selection'})
                        args = [args {'fovs',mat2str(obj.Session.Position)}];
                        if strcmp(obj.Scope.Value,'Current ROI') && obj.Session.Zone > 0
                            args = [args {'rois',mat2str(obj.Session.Zone)}];
                        end
                    end
                end
                hasDraft = ~isempty(obj.Template) && ~isempty(obj.Session) && ~isempty(obj.Session.Project);
                if hasDraft
                    ids = matlab.lang.makeValidName({obj.Template.nodes.id});
                    assert(numel(unique(ids)) == numel(ids),'detecdivui:EditorNodeIds', ...
                        'Step IDs collide in the advanced editor. Reset run overrides and rename the step IDs.');
                    draft = obj.draftRun();
                    existing = obj.Session.Project.processing.pipelineRun;
                    if ~isempty(existing)
                        index = find(strcmp({existing.runId},draft.runId),1);
                        if ~isempty(index)
                            assert(~any(strcmp(existing(index).status,{'running','queued','hub_running','hub_queued','preflight'})), ...
                                'detecdivui:RunActive','This run is active. Use its advanced window to monitor it or choose New Run.');
                            existing(index).ctx = obj.overlay(existing(index).ctx,draft.ctx);
                            draft = existing(index);
                        end
                    end
                    args{end+1} = draft;
                    args = [args {'EditExistingRun',true}];
                end
                editor = pipeline2(args{:});
                if hasDraft
                    % A seed run normally recommends restart/replace. This
                    % is a new unsaved draft: restore the user's explicit
                    % run policy and output choice through existing callbacks.
                    settings = obj.Setup.values();
                    progress = 'Resume previous progress';
                    if strcmp(settings.runPolicy,'restart'), progress = 'Restart from scratch'; end
                    editor.ResumeoptionsDropDown.Value = progress;
                    editor.ResumeoptionsDropDown.ValueChangedFcn(editor.ResumeoptionsDropDown,[]);
                    editor.RuntimeOutputPolicyDropDown.Value = settings.outputPolicy;
                    editor.RuntimeOutputPolicyDropDown.ValueChangedFcn(editor.RuntimeOutputPolicyDropDown,[]);
                    values = editor.ExecutionDropDown.ItemsData;
                    if isempty(values), values = editor.ExecutionDropDown.Items; end
                    device = settings.gpuPolicy; if strcmp(device,'module_default'), device = 'auto'; end
                    index = find(strcmpi(values,device),1);
                    if ~isempty(index), editor.ExecutionDropDown.Value = values{index}; end
                    existing = []; names = {}; occupied = false;
                    if ~isempty(obj.Session) && ~isempty(obj.Session.Project)
                        project = obj.Session.Project; existing = project.processing.pipelineRun;
                        occupied = isfolder(fullfile(project.io.path,project.io.file,'pipeline',strtrim(settings.runId)));
                    end
                    if ~isempty(existing), names = {existing.runId}; end
                    if ~isempty(strtrim(settings.runId)) && ~any(strcmp(names,strtrim(settings.runId))) && ~occupied
                        editor.TemplateidEditField.Value = strtrim(settings.runId);
                        editor.TemplateidEditField.ValueChangedFcn(editor.TemplateidEditField,[]);
                    end
                end
                if hasDraft
                    obj.AdvancedEditor = editor;
                    editor.configureViewerBridge(@(state)obj.acceptAdvanced(state),obj.OnDefineROIs);
                    obj.SettingsFigure.Visible = 'off';
                end
            catch err
                obj.setStatus(err.message);
            end
        end
        function ok = syncAdvanced(obj)
            ok = true;
            if obj.Syncing || isempty(obj.AdvancedEditor) || ~isvalid(obj.AdvancedEditor), return; end
            activity = obj.Progress.begin('Applying advanced settings...'); %#ok<NASGU>
            try
                state = obj.AdvancedEditor.exportViewerDraft();
                if state.busy
                    obj.AdvancedEditor.clearViewerBridge(); obj.AdvancedEditor = []; return;
                end
                editor = obj.AdvancedEditor; obj.AdvancedEditor = [];
                obj.acceptAdvanced(state); editor.clearViewerBridge(); delete(editor);
            catch err
                if exist('editor','var') && isvalid(editor), obj.AdvancedEditor = editor; end
                ok = false; obj.setStatus(err.message);
            end
        end
        function acceptAdvanced(obj,state)
            obj.Syncing = true; release = onCleanup(@()obj.endSync());
            if ~isempty(obj.Session) && ~isequal(state.project,obj.Session.Project) && ~isempty(obj.OnProjectUpdated)
                old = obj.Session.Project; fresh = state.project;
                sameId = ~isempty(old) && strlength(string(old.projectId)) > 0 && strcmp(old.projectId,fresh.projectId);
                samePath = ~isempty(old) && strlength(string(old.io.path)) > 0 && ...
                    strcmpi(fullfile(old.io.path,old.io.file),fullfile(fresh.io.path,fresh.io.file));
                if sameId || samePath, obj.OnProjectUpdated(fresh); end
            end
            assert(~isempty(obj.Session) && isequal(state.project,obj.Session.Project), ...
                'detecdivui:RunContext','Select the original project before applying advanced settings.');
            spec = state.pipeline;
            if ~isequaln(spec.nodes,obj.Template.nodes) || ~isequaln(spec.edges,obj.Template.edges) || ...
                    ~isequaln(spec.branches,obj.Template.branches)
                copy = pipeline();
                for field = properties(obj.Template)', copy.(field{1}) = obj.Template.(field{1}); end
                copy.nodes = spec.nodes; copy.edges = spec.edges; copy.branches = spec.branches;
                index = find(cellfun(@(p)p == obj.Template,obj.Templates),1);
                obj.Templates{index} = copy; obj.Template = copy;
            end
            settings = state.settings; settings.extraContext = state.ctx;
            obj.Draft.select(obj.Session.Project,obj.Template);
            obj.Draft.import(settings,state.ctx.run.nodeParams);
            obj.refresh(); obj.setStatus('Advanced settings applied');
            obj.RunPicker.Value = 'draft'; obj.updateGraph();
        end
        function defineROIs(obj)
            if isempty(obj.OnDefineROIs) || isempty(obj.Template) || obj.SelectedStep < 1, return; end
            node = obj.Template.nodes(obj.SelectedStep);
            if ~any(strcmpi(node.type,{'roiManual','roiPattern','roiIdentify','roiGrid','roiTracked'}))
                obj.setStatus('Select an ROI definition step'); return;
            end
            obj.SettingsFigure.Visible = 'off';
            project = obj.Session.Project; token = obj.DefinitionContext;
            obj.OnDefineROIs(project,node,@(ctx)obj.acceptRoiDefinition(token,project,node,ctx));
        end
        function acceptRoiDefinition(obj,token,project,node,ctx)
            assert(token == obj.DefinitionContext && isequal(project,obj.Session.Project), ...
                'detecdivui:ROIContext','The project or pipeline changed. Open Define ROIs again.');
            index = find(strcmp({obj.Template.nodes.id},node.id),1);
            assert(~isempty(index) && strcmpi(obj.Template.nodes(index).type,node.type), ...
                'detecdivui:ROIContext','The ROI step changed. Open Define ROIs again.');
            % ROI geometry is a definition; edit a working template copy only.
            state = struct('project',obj.Session.Project,'pipeline',struct('nodes',obj.Template.nodes, ...
                'edges',obj.Template.edges,'branches',obj.Template.branches),'settings',obj.Draft.Settings, ...
                'ctx',struct('run',struct('nodeParams',obj.Draft.Overrides)));
            values = obj.Setup.values();
            for field = fieldnames(values)', state.settings.(field{1}) = values.(field{1}); end
            state.pipeline.nodes(index).params = ctx.params;
            obj.acceptAdvanced(state);
        end
        function review = reviewRun(obj)
            review = struct(); index = obj.Inspect.UserData;
            if isempty(index), return; end
            activity = obj.Progress.begin('Reading run review...'); %#ok<NASGU>
            obj.LastRunReview = struct(); obj.RunNodes.Data = cell(0,3); obj.RunIssues.Data = cell(0,1);
            obj.RunReviews{index} = [];
            try
                obj.setStatus('Reading run review...');
                [review,~] = pipelineRunReview(obj.RunObjects(index));
                obj.RunReviews{index} = review; obj.showRunReview(review);
                obj.Runs.Data{index,2} = review.status;
                obj.setStatus(['Run ' review.status]);
            catch err
                obj.RunIssues.Data = {err.message};
                obj.setStatus(err.message);
            end
        end
    end
    methods (Access = private)
        function id = nextRunId(obj)
            base = matlab.lang.makeValidName(char(string(obj.Template.strid))); n = 1; names = {}; root = '';
            if isempty(base), base = 'pipeline'; end
            if ~isempty(obj.Session) && ~isempty(obj.Session.Project)
                project = obj.Session.Project; runs = project.processing.pipelineRun;
                if ~isempty(runs), names = {runs.runId}; end
                if ~isempty(project.io.path), root = fullfile(project.io.path,project.io.file,'pipeline'); end
            end
            id = sprintf('%s_%d',base,n);
            while any(strcmp(names,id)) || (~isempty(root) && isfolder(fullfile(root,id)))
                n = n+1; id = sprintf('%s_%d',base,n);
            end
        end
        function followRun(obj)
            if obj.Busy || obj.Syncing || isempty(obj.RunPicker) || ~isvalid(obj.RunPicker) || ...
                    strcmp(obj.RunPicker.Value,'draft') || isempty(obj.RunObjects), return; end
            index = find(strcmp({obj.RunObjects.runId},obj.RunPicker.Value),1);
            if isempty(index) || ~isvalid(obj.RunObjects(index)), return; end
            run = obj.RunObjects(index); obj.RunState.Text = char(string(run.status));
            if isfield(run.progress,'message') && ~isempty(run.progress.message)
                obj.RunState.Tooltip = char(string(run.progress.message));
            end
            obj.Runs.Data{index,2} = run.status;
        end
        function loadSelectedRun(obj)
            if strcmp(obj.RunPicker.Value,'draft') || strcmp(obj.RunPicker.Value,obj.Setup.Controls.runId.Value), return; end
            index = find(strcmp({obj.RunObjects.runId},obj.RunPicker.Value),1);
            if isempty(index), return; end
            run = obj.RunObjects(index); ctx = run.ctx; settings = obj.Setup.values();
            settings.runId = run.runId; settings.description = run.description;
            settings.fovs = 'all'; settings.rois = 'all'; settings.frames = 'all';
            if isfield(ctx,'sel')
                for field = {'fovs','rois','frames'}
                    if isfield(ctx.sel,field{1}) && ~isempty(ctx.sel.(field{1}))
                        value = ctx.sel.(field{1});
                        if isnumeric(value), settings.(field{1}) = mat2str(value(:)');
                        else, settings.(field{1}) = strjoin(cellstr(string(value)),','); end
                    end
                end
            end
            if ~isfield(ctx,'run'), ctx.run = struct(); end
            for field = {'runPolicy','gpuPolicy','executionTarget','inputSourceMode','rawDataPath','selectedNodes'}
                if isfield(ctx.run,field{1}), settings.(field{1}) = ctx.run.(field{1}); end
            end
            if isfield(ctx,'io') && isfield(ctx.io,'existingPolicy'), settings.outputPolicy = ctx.io.existingPolicy; end
            if ~isfield(ctx.run,'nodeParams'), ctx.run.nodeParams = struct('id',{},'params',{}); end
            spec = struct('nodes',obj.Template.nodes,'edges',obj.Template.edges,'branches',obj.Template.branches);
            if isfield(ctx,'pipelineSpec'), spec = ctx.pipelineSpec; end
            obj.acceptAdvanced(struct('project',obj.Session.Project,'pipeline',spec,'settings',settings,'ctx',ctx));
        end
        function endSync(obj)
            obj.Syncing = false;
        end
        function openStep(obj,index)
            if strcmp(obj.RunPicker.Value,'draft')
                obj.openSettings('Steps'); obj.showParams(index);
            else
                obj.openSettings('Runs');
            end
        end
        function selectCompactRun(obj)
            if strcmp(obj.RunPicker.Value,'draft')
                obj.Inspect.UserData = []; obj.RunState.Text = 'Draft'; obj.updateGraph(); return;
            end
            index = find(strcmp({obj.RunObjects.runId},obj.RunPicker.Value),1);
            if ~isempty(index), obj.selectRun(struct('Indices',[index 1])); end
        end
        function refreshSelectedRun(obj)
            obj.refresh();
            if ~strcmp(obj.RunPicker.Value,'draft'), obj.selectCompactRun(); obj.reviewRun(); end
        end
        function selectTemplate(obj)
            index = obj.Selector.Value;
            if ~obj.syncAdvanced(), return; end
            if obj.Template ~= obj.Templates{index}, obj.DefinitionContext = obj.DefinitionContext+1; end
            obj.Template = obj.Templates{index}; obj.refresh();
        end
        function selectStep(obj,event)
            if isempty(event.Indices), return; end
            obj.showParams(event.Indices(1,1));
        end
        function showParams(obj,index)
            obj.SelectedStep = index;
            nodes = obj.Draft.effectiveNodes(); node = nodes(index);
            params = obj.field(node,'params',struct());
            data = cell(0,3);
            obj.ParamKeys = {}; obj.ParamSpecs = struct([]); obj.clearParamEditor();
            if isstruct(params) && isscalar(params)
                spec = classifierBinding.parameterSpecFromDefaults(params);
                keys = {spec.param}; obj.ParamKeys = keys; obj.ParamSpecs = spec;
                for k = 1:numel(keys)
                    value = params.(keys{k});
                    if strcmp(detecdivui.RunDraft.valueKind(value),'choice')
                        text = char(string(value{end}));
                    elseif ischar(value) || (isstring(value) && isscalar(value))
                        text = char(string(value));
                    elseif (isnumeric(value) || islogical(value)) && numel(value) <= 12
                        text = mat2str(value);
                    else
                        text = sprintf('%s %s',mat2str(size(value)),class(value));
                    end
                    scope = pipelineParamScope(node,keys{k});
                    if obj.Draft.has(node.id,keys{k}), scope = sprintf('%s *',scope); end
                    data(end+1,:) = {spec(k).label,text,scope}; %#ok<AGROW>
                end
            end
            obj.Params.Data = data; obj.Params.UserData = obj.ParamKeys;
            obj.updateGraph();
        end
        function loadSettings(obj)
            obj.Setup.load(obj.Draft.Settings);
            if ~isempty(fieldnames(obj.Draft.Settings))
                obj.Scope.Value = 'Run selection';
            elseif strcmp(obj.Scope.Value,'Run selection')
                obj.Scope.Value = 'Current FOV';
            end
            if isempty(fieldnames(obj.Draft.Settings)) && ~isempty(obj.Session)
                if obj.Session.Position > 0, obj.Setup.Controls.fovs.Value = num2str(obj.Session.Position); end
                if obj.Session.Zone > 0, obj.Setup.Controls.rois.Value = num2str(obj.Session.Zone); end
            end
        end
        function settingsChanged(obj)
            settings = obj.Setup.values();
            if isfield(obj.Draft.Settings,'extraContext'), settings.extraContext = obj.Draft.Settings.extraContext; end
            if isfield(obj.Draft.Settings,'selectedNodes'), settings.selectedNodes = obj.Draft.Settings.selectedNodes; end
            obj.Draft.configure(settings); obj.Scope.Value = 'Run selection'; obj.invalidate(); obj.updateGraph();
        end
        function included = includedSteps(obj)
            included = false(1,0);
            if isempty(obj.Template), return; end
            nodes = obj.Template.nodes; included = true(1,numel(nodes));
            if isfield(nodes,'enabled'), included = logical([nodes.enabled]); end
            if isfield(obj.Draft.Settings,'selectedNodes')
                included = included & ismember(string({nodes.id}),string(obj.Draft.Settings.selectedNodes));
            end
        end
        function updateGraph(obj)
            if isempty(obj.Template)
                obj.Graph.show(struct([]),struct([]),0); obj.CompactGraph.show(struct([]),struct([]),0); return;
            end
            obj.Graph.show(obj.Template.nodes,obj.Template.edges,obj.SelectedStep,obj.includedSteps());
            if strcmp(obj.RunPicker.Value,'draft')
                obj.CompactGraph.show(obj.Template.nodes,obj.Template.edges,obj.SelectedStep,obj.includedSteps());
                obj.RunState.Text = sprintf('Draft · %d / %d steps',nnz(obj.includedSteps()),numel(obj.Template.nodes));
            end
            included = obj.includedSteps();
            for k = 1:numel(included)
                state = 'Excluded'; if included(k), state = 'Included'; end
                obj.Steps.Data{k,3} = state;
            end
        end
        function toggleStep(obj,index)
            if isempty(obj.Template) || index > numel(obj.Template.nodes), return; end
            node = obj.Template.nodes(index);
            if isfield(node,'enabled') && ~node.enabled, obj.setStatus('Enable this step in Editor first'); return; end
            included = obj.includedSteps(); included(index) = ~included(index);
            settings = obj.Setup.values();
            if strcmp(obj.Scope.Value,'Whole project'), settings.fovs = 'all'; settings.rois = 'all';
            elseif strcmp(obj.Scope.Value,'Current FOV')
                settings.fovs = num2str(obj.Session.Position); settings.rois = 'all';
            elseif strcmp(obj.Scope.Value,'Current ROI')
                settings.fovs = num2str(obj.Session.Position); settings.rois = num2str(obj.Session.Zone);
            end
            settings.selectedNodes = {obj.Template.nodes(included).id};
            obj.Draft.configure(settings); obj.invalidate(); obj.updateGraph();
            obj.setStatus(sprintf('%d steps selected',nnz(included)));
        end
        function ids = roiIds(obj,indices)
            ids = {};
            if isempty(indices), return; end
            fovs = obj.Session.Project.fov; ids = cellstr(string({fovs(indices(1)).roi.id}));
            text = obj.Setup.Controls.rois.Value;
            if ~strcmpi(strtrim(text),'all') && ~isempty(regexp(text,'[A-Za-z_]','once'))
                for k = indices(2:end)
                    assert(isequal(ids,cellstr(string({fovs(k).roi.id}))), ...
                        'detecdivui:ROISelection','Use numeric ROI indices across FOVs with different ROI IDs.');
                end
            end
        end
        function selectParam(obj,event)
            if isempty(event.Indices), return; end
            row = event.Indices(1,1);
            if row < 1 || row > numel(obj.ParamKeys), return; end
            obj.clearParamEditor(); obj.SelectedParam = row;
            nodes = obj.Draft.effectiveNodes(); node = nodes(obj.SelectedStep);
            key = obj.ParamKeys{row}; value = node.params.(key);
            kind = detecdivui.RunDraft.valueKind(value);
            editable = strcmp(pipelineParamScope(node,key),'run') && ~strcmp(kind,'complex');
            obj.ValueText.Visible = 'off';
            switch kind
                case 'number'
                    control = obj.ValueNumber; control.Value = double(value);
                case 'logical'
                    control = obj.ValueLogical; control.Value = value;
                case 'choice'
                    control = obj.ValueChoice;
                    control.Items = unique(cellstr(string(value(1:end-1))),'stable');
                    control.Value = char(string(value{end}));
                otherwise
                    control = obj.ValueText;
                    if strcmp(kind,'text'), control.Value = char(value); else, control.Value = ''; end
            end
            control.Visible = 'on'; control.Enable = obj.onOff(editable);
            control.Tooltip = obj.ParamSpecs(row).tip;
            if isempty(control.Tooltip), control.Tooltip = key; end
            obj.ApplyParam.Enable = obj.onOff(editable);
            obj.ResetParam.Enable = obj.onOff(obj.Draft.has(node.id,key));
            if ~editable, obj.setStatus('Use Editor for this parameter'); end
        end
        function applyParameter(obj)
            if obj.SelectedParam == 0, return; end
            try
                row = obj.SelectedParam; nodes = obj.Draft.effectiveNodes(); node = nodes(obj.SelectedStep);
                key = obj.ParamKeys{row}; kind = detecdivui.RunDraft.valueKind(node.params.(key));
                switch kind
                    case 'number', value = obj.ValueNumber.Value;
                    case 'logical', value = obj.ValueLogical.Value;
                    case 'choice', value = obj.ValueChoice.Value;
                    otherwise, value = obj.ValueText.Value;
                end
                obj.Draft.set(node.id,key,value); obj.invalidate();
                obj.showParams(obj.SelectedStep); obj.selectParam(struct('Indices',[row 1]));
                obj.setStatus('Run parameter updated');
            catch err
                obj.setStatus(err.message);
            end
        end
        function resetParameter(obj)
            if obj.SelectedParam == 0, return; end
            row = obj.SelectedParam; node = obj.Template.nodes(obj.SelectedStep);
            obj.Draft.reset(node.id,obj.ParamKeys{row}); obj.invalidate();
            obj.showParams(obj.SelectedStep); obj.selectParam(struct('Indices',[row 1]));
            obj.setStatus('Template value restored');
        end
        function clearParamEditor(obj)
            obj.SelectedParam = 0;
            for item = {obj.ValueText,obj.ValueNumber,obj.ValueLogical,obj.ValueChoice}
                control = item{1}; control.Visible = 'off'; control.Enable = 'off';
            end
            obj.ValueText.Visible = 'on'; obj.ValueText.Value = '';
            obj.ApplyParam.Enable = 'off'; obj.ResetParam.Enable = 'off';
        end
        function refreshRuns(obj)
            selected = obj.RunPicker.Value;
            obj.RunObjects = []; obj.Runs.Data = cell(0,2); obj.Inspect.Enable = 'off';
            obj.RunPicker.ItemsData = {}; obj.RunPicker.Items = {'Draft'}; obj.RunPicker.ItemsData = {'draft'};
            obj.RunPicker.Value = 'draft'; obj.RunState.Text = 'Draft';
            obj.Inspect.UserData = [];
            obj.MoreRun.Enable = 'off'; obj.LastRunReview = struct();
            obj.RunReviews = {};
            obj.RunSummary.Data = cell(0,2); obj.RunNodes.Data = cell(0,3); obj.RunIssues.Data = cell(0,1);
            obj.RunGraph.show(struct([]),struct([]),0);
            if isempty(obj.Template) || isempty(obj.Session) || isempty(obj.Session.Project), return; end
            [runs,~] = obj.Template.findDependentRuns(obj.Session.Project);
            runs = runs(isvalid(runs)); obj.RunObjects = runs;
            obj.RunReviews = cell(size(runs));
            data = cell(numel(runs),2);
            for k = 1:numel(runs), data(k,:) = {runs(k).runId,runs(k).status}; end
            obj.Runs.Data = data;
            if ~isempty(runs)
                obj.RunPicker.ItemsData = {}; obj.RunPicker.Items = [{'Draft'} {runs.runId}];
                obj.RunPicker.ItemsData = [{'draft'} {runs.runId}];
                if any(strcmp(obj.RunPicker.ItemsData,selected))
                    obj.RunPicker.Value = selected; obj.selectCompactRun();
                end
            end
        end
        function selectRun(obj,event)
            if isempty(event.Indices), return; end
            obj.Inspect.UserData = event.Indices(1,1); obj.Inspect.Enable = 'on';
            obj.RunPicker.Value = obj.RunObjects(obj.Inspect.UserData).runId;
            if ~isempty(obj.RunReviews{obj.Inspect.UserData})
                obj.MoreRun.Enable = 'on'; obj.showRunReview(obj.RunReviews{obj.Inspect.UserData}); return;
            end
            obj.MoreRun.Enable = 'on'; obj.LastRunReview = struct();
            obj.RunNodes.Data = cell(0,3); obj.RunIssues.Data = cell(0,1);
            run = obj.RunObjects(obj.Inspect.UserData);
            obj.RunState.Text = run.status;
            obj.showRunGraph(run,struct());
            obj.RunSummary.Data = {'Run',run.runId;'Status',run.status;'Created',run.createdAt; ...
                'Updated',run.updatedAt;'Folder',run.path};
        end
        function showRunReview(obj,review)
            obj.LastRunReview = review;
            obj.RunSummary.Data = {'Run',review.runId;'Status',review.status; ...
                'Started',review.summary.startedAt;'Updated',review.summary.lastEventAt; ...
                'Completed steps',review.summary.doneNodes;'Failed steps',review.summary.failedNodes; ...
                'Folder',review.runPath};
            data = cell(numel(review.nodes),3);
            for k = 1:numel(review.nodes)
                data(k,:) = {review.nodes(k).nodeId,review.nodes(k).status,review.nodes(k).durationSec};
            end
            obj.RunNodes.Data = data; obj.RunIssues.Data = reshape(review.issues,[],1);
            obj.showRunGraph(obj.RunObjects(obj.Inspect.UserData),review);
        end
        function showRunGraph(obj,run,review)
            nodes = struct([]); edges = struct([]);
            if isfield(run.ctx,'pipelineSpec') && isfield(run.ctx.pipelineSpec,'nodes')
                nodes = run.ctx.pipelineSpec.nodes;
                if isfield(run.ctx.pipelineSpec,'edges'), edges = run.ctx.pipelineSpec.edges; end
            elseif isfield(review,'nodes')
                for k = 1:numel(review.nodes)
                    nodes(k).id = review.nodes(k).nodeId; nodes(k).name = review.nodes(k).nodeId; nodes(k).type = '';
                end
            end
            included = true(1,numel(nodes)); statuses = repmat({''},1,numel(nodes));
            if ~isempty(nodes) && isfield(run.ctx,'run') && isfield(run.ctx.run,'selectedNodes') && ~isempty(run.ctx.run.selectedNodes)
                included = ismember(string({nodes.id}),string(run.ctx.run.selectedNodes));
            end
            if isfield(review,'nodes')
                for k = 1:numel(nodes)
                    index = find(strcmp({review.nodes.nodeId},nodes(k).id),1);
                    if ~isempty(index), statuses{k} = review.nodes(index).status; end
                end
            end
            obj.RunGraph.show(nodes,edges,0,included,statuses);
            if ~strcmp(obj.RunPicker.Value,'draft')
                obj.CompactGraph.show(nodes,edges,0,included,statuses);
                status = run.status; if isfield(review,'status'), status = review.status; end
                obj.RunState.Text = char(string(status));
            end
        end
        function inspectRun(obj)
            index = obj.Inspect.UserData;
            if isempty(index), return; end
            activity = obj.Progress.begin('Opening run inspector...'); %#ok<NASGU>
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
        function draftNotice(obj)
            if obj.Draft.takeDiscarded() > 0, obj.setStatus('Run settings reset after template changes'); end
        end
    end
    methods (Static, Access = private)
        function value = overlay(value,fields)
            for key = fieldnames(fields)', value.(key{1}) = fields.(key{1}); end
        end
        function value = field(item,name,default)
            value = default;
            if isstruct(item) && isfield(item,name), value = item.(name); end
        end
        function value = onOff(condition)
            if condition, value = 'on'; else, value = 'off'; end
        end
    end
end
