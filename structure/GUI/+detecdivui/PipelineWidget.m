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
        Proposal = []
        Planner = []
        PlanHistory = struct('project',{},'event',{})
        RecentPipelines
    end
    properties
        OnStatus = []
        OnChanged = []
        OnDefineROIs = []
        OnProjectUpdated = []
        OnTemplateOpened = []
        OnRunsChanged = []
    end
    properties (Access = private)
        Session
        Selector
        Target
        Scope
        Steps
        Params
        SelectedStep = 0
        ModuleLabel
        EditModuleButton
        ChangeTypeButton
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
        ProposalProject = []
        ApplyingProposal = false
        ProposalTemplate = []
        PlanHistoryFigure = []
        CompactTabs
        PipelineTab
        WorkflowTab % Compatibility alias for viewers created before the tab rename.
        CompactRunsTab
        CompactRuns
        UseRunPipeline
        RunsProject = []
        RunTemplates = struct('project',{},'run',{},'template',{},'signature',{})
        DefinitionEditor = false
        DefinitionTemplate = []
        LibraryTab
        LibraryTree
        LibraryName
        LibraryPath
        LibraryCopy
        LibraryOpen
        UpdatingLibrary = false
        LibraryPanel
        GraphPanel
        ViewName
        MainActions
        BindingTable
        BindingRows = struct([])
        BindingChoice
        BindingScope
        BindingApply
        BindingReset
        SelectedBinding = 0
        ParameterViews
        BindingsTab
        RunParametersTab
        StaticButton
        StaticDialog = []
    end
    methods
        function obj = PipelineWidget(parent,recentFile)
            if nargin < 2, recentFile = fullfile(prefdir,'recentPipelines.mat'); end
            obj.RecentPipelines = detecdivui.RecentPipelines(recentFile);
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
            runGrid = uigridlayout(obj.RunTab,[4 1]); runGrid.Padding = [4 4 4 4];
            runGrid.RowHeight = {22,28,'1x',28};
            obj.Target.Parent = runGrid; obj.Target.Layout.Row = 1; obj.Target.Layout.Column = 1;
            obj.RunPicker = uidropdown(runGrid,'Items',{'Draft'},'ItemsData',{'draft'}, ...
                'Tag','pipeline-run-picker','Tooltip','Run configuration', ...
                'ValueChangedFcn',@(~,~)obj.selectCompactRun());
            obj.Setup = detecdivui.RunSetup(runGrid);
            obj.Setup.OnChanged = detecdivui.Callback(obj,'widgetEvent','settings');
            obj.SaveRun = uibutton(runGrid,'Text','Save Run','Enable','off','Tag','pipeline-save-run', ...
                'Tooltip','Save a new run configuration without starting processing', ...
                'ButtonPushedFcn',@(~,~)obj.saveRun());
            stepsTab = uitab(obj.Tabs,'Title','Steps');
            obj.StepsTab = stepsTab;
            stepsGrid = uigridlayout(stepsTab,[5 1]); stepsGrid.Padding = [4 4 4 4];
            stepsGrid.RowHeight = {'1x',28,'1x',28,28};
            views = uitabgroup(stepsGrid);
            graphTab = uitab(views,'Title','Graph'); listTab = uitab(views,'Title','List');
            obj.Graph = detecdivui.PipelineGraph(graphTab,'pipeline-graph');
            obj.Graph.OnSelect = detecdivui.Callback(obj,'widgetEvent','select');
            obj.Graph.OnToggle = detecdivui.Callback(obj,'widgetEvent','toggle');
            listGrid = uigridlayout(listTab,[1 1]); listGrid.Padding = [0 0 0 0];
            obj.Steps = uitable(listGrid,'Data',cell(0,3),'RowName',{}, ...
                'ColumnName',{'Step','Type','State'},'ColumnWidth',{'auto',70,65}, ...
                'Tag','pipeline-steps','Tooltip','Select a step to inspect its parameters', ...
                'CellSelectionCallback',@(~,event)obj.selectStep(event));
            moduleActions = uigridlayout(stepsGrid,[1 4]); moduleActions.Padding = [0 0 0 0];
            moduleActions.ColumnWidth = {'1x',126,100,100};
            obj.ModuleLabel = uilabel(moduleActions,'Text','—','Interpreter','none','Tag','pipeline-selected-module');
            obj.StaticButton = uibutton(moduleActions,'Text','Static Parameters...','Enable','off', ...
                'Tag','pipeline-static-parameters','ButtonPushedFcn',@(~,~)obj.openStaticParameters());
            obj.EditModuleButton = uibutton(moduleActions,'Text','Edit Module...','Enable','off', ...
                'Tag','pipeline-edit-module','Tooltip','Edit the selected module in Pipeline Designer', ...
                'ButtonPushedFcn',@(~,~)obj.editModule());
            obj.ChangeTypeButton = uibutton(moduleActions,'Text','Change Type...','Enable','off', ...
                'Tag','pipeline-change-type','Tooltip','Replace the selected module using the existing module catalogue', ...
                'ButtonPushedFcn',@(~,~)obj.editModule('',true));
            obj.ParameterViews = uitabgroup(stepsGrid,'Tag','pipeline-parameter-views');
            obj.BindingsTab = uitab(obj.ParameterViews,'Title','Parameter Bindings','Tag','pipeline-bindings-tab');
            obj.RunParametersTab = uitab(obj.ParameterViews,'Title','Run Parameters','Tag','pipeline-run-parameters-tab');
            bindings = uigridlayout(obj.BindingsTab,[2 1]); bindings.Padding = [4 4 4 4];
            bindings.RowHeight = {'1x',28};
            obj.BindingTable = uitable(bindings,'Data',cell(0,4),'RowName',{}, ...
                'ColumnName',{'Direction','Resource','Binding','Value Scope'},'ColumnWidth',{62,100,'auto',85}, ...
                'Tag','pipeline-bindings','CellSelectionCallback',@(~,event)obj.selectBinding(event));
            bindingEdit = uigridlayout(bindings,[1 4]); bindingEdit.Padding = [0 0 0 0];
            bindingEdit.ColumnWidth = {'1x',100,48,48};
            obj.BindingChoice = uidropdown(bindingEdit,'Items',{'—'},'Editable','on','Enable','off','Tag','pipeline-binding-value');
            obj.BindingScope = uidropdown(bindingEdit,'Items',{'Pipeline','This Run'},'Enable','off','Tag','pipeline-binding-scope');
            obj.BindingApply = uibutton(bindingEdit,'Text','Apply','Enable','off','Tag','pipeline-binding-apply', ...
                'ButtonPushedFcn',@(~,~)obj.applyBinding());
            obj.BindingReset = uibutton(bindingEdit,'Text','Reset','Enable','off','Tag','pipeline-binding-reset', ...
                'ButtonPushedFcn',@(~,~)obj.resetBinding());
            runParams = uigridlayout(obj.RunParametersTab,[2 1]); runParams.Padding = [4 4 4 4];
            runParams.RowHeight = {'1x',28};
            obj.Params = uitable(runParams,'Data',cell(0,3),'RowName',{}, ...
                'ColumnName',{'Parameter','Value','Scope'},'ColumnWidth',{'auto','auto',65}, ...
                'Tag','pipeline-parameters','Tooltip','Select a run parameter to edit; * marks a run override', ...
                'CellSelectionCallback',@(~,event)obj.selectParam(event));
            edit = uigridlayout(runParams,[1 3]); edit.Padding = [0 0 0 0];
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
            checks.Layout.Row = 5; stepsGrid.RowHeight = {'1x',28,'1x',0,28};
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
            actions = uigridlayout(runsGrid,[1 4]); actions.Padding = [0 0 0 0];
            actions.ColumnWidth = {'1x','1x','1x','1x'};
            obj.Inspect = uibutton(actions,'Text','Review','Enable','off', ...
                'Tag','pipeline-inspect-run','Tooltip','Read the selected run review and event log', ...
                'ButtonPushedFcn',@(~,~)obj.reviewRun());
            obj.MoreRun = uibutton(actions,'Text','More...','Enable','off','Tag','pipeline-more-run', ...
                'Tooltip','Open the existing detailed run inspector', ...
                'ButtonPushedFcn',@(~,~)obj.inspectRun());
            uibutton(actions,'Text','Refresh','Tag','pipeline-refresh', ...
                'Tooltip','Refresh steps and project runs from live objects', ...
                'ButtonPushedFcn',@(~,~)obj.refresh());
            obj.UseRunPipeline = uibutton(actions,'Text','Use Pipeline','Enable','off', ...
                'Tag','pipeline-use-run','Tooltip','Create an editable draft from the saved run pipeline', ...
                'ButtonPushedFcn',@(~,~)obj.useRunPipeline());
            obj.Tabs.SelectedTab = obj.StepsTab;
            obj.Status = uilabel(root,'Text','Ready','Interpreter','none','Tag','pipeline-status');
            % The dialog edits the same controls/model used by context/save.
            compact = uigridlayout(parent,[7 1]); compact.Padding = [8 6 8 6];
            compact.RowHeight = {164,22,'1x',22,28,28,24};
            obj.LibraryPanel = uipanel(compact,'BorderType','none','Tag','pipeline-library-panel');
            obj.LibraryPanel.Layout.Row = 1;
            obj.ViewName = uilabel(compact,'Text','Pipeline','Interpreter','none', ...
                'FontWeight','bold','Tag','pipeline-view-name'); obj.ViewName.Layout.Row = 2;
            runMenu = uicontextmenu(ancestor(parent,'figure'));
            uimenu(runMenu,'Text','Use Pipeline','Tag','pipeline-use-run-menu', ...
                'Enable','off','MenuSelectedFcn',@(~,~)obj.useRunPipeline());
            obj.ViewName.ContextMenu = runMenu;
            obj.GraphPanel = uipanel(compact,'BorderType','none','Tag','pipeline-graph-panel');
            obj.GraphPanel.Layout.Row = 3;
            obj.CompactGraph = detecdivui.PipelineGraph(obj.GraphPanel,'pipeline-compact-graph');
            obj.createLibrary();
            obj.CompactGraph.OnSelect = detecdivui.Callback(obj,'widgetEvent','openStep');
            obj.RunState = uilabel(compact,'Text','Draft','Tag','pipeline-run-state','Interpreter','none');
            obj.RunState.Layout.Row = 4;
            buttons = uigridlayout(compact,[1 2]); buttons.Padding = [0 0 0 0]; buttons.Layout.Row = 5;
            buttons.ColumnWidth = {'1x','1x'}; obj.MainActions = buttons;
            obj.NewRun.Parent = buttons; obj.NewRun.Layout.Row = 1; obj.NewRun.Layout.Column = 1;
            obj.SettingsButton = uibutton(buttons,'Text','Settings...','Tag','pipeline-settings','Enable','off', ...
                'Tooltip','Edit the current run configuration','ButtonPushedFcn',@(~,~)obj.openSettings('Run'));
            buttons = uigridlayout(compact,[1 3]); buttons.Padding = [0 0 0 0]; buttons.Layout.Row = 6;
            uibutton(buttons,'Text','Plan...','Tag','pipeline-plan','Tooltip','Propose a workflow from an intended outcome', ...
                'ButtonPushedFcn',@(~,~)obj.openPlanner());
            uibutton(buttons,'Text','Refresh','Tooltip','Refresh the selected run and its review', ...
                'ButtonPushedFcn',@(~,~)obj.refreshSelectedRun());
            uibutton(buttons,'Text','Details...','Tooltip','Open checks and run details', ...
                'ButtonPushedFcn',@(~,~)obj.openSettings('Runs'));
            obj.Status.Parent = compact; obj.Status.Layout.Row = 7; obj.Status.Layout.Column = 1;
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
                'Tag','DetecDivPipelineFollow','TimerFcn', ...
                {@detecdivui.Callback.event,detecdivui.Callback(obj,'widgetEvent','follow')});
            start(obj.FollowTimer);
            obj.refreshLibrary();
        end
        function openSettings(obj,page)
            if nargin < 2, page = 'Run'; end
            if ~obj.syncAdvanced(), return; end
            if ~strcmp(page,'Runs') && ~obj.loadSelectedRun(), return; end
            tabs = obj.Tabs.Children;
            index = find(strcmp({tabs.Title},page),1);
            if ~isempty(index), obj.Tabs.SelectedTab = tabs(index); end
            obj.SettingsFigure.Visible = 'on'; figure(obj.SettingsFigure);
        end
        function openPlanner(obj,intent)
            if nargin<2, intent = ''; end
            try
                assert(isempty(obj.AdvancedEditor) || ~isvalid(obj.AdvancedEditor), ...
                    'detecdivui:PlannerEditor','Close the advanced editor before proposing a workflow change.');
                assert(~isempty(obj.Session) && obj.Session.Position>0, ...
                    'detecdivui:PlannerTarget','Select a FOV or ROI first.');
                if isempty(obj.Planner) || ~isvalid(obj.Planner), obj.Planner = detecdivui.IntentDialog(obj); end
                obj.Planner.open(intent);
            catch err, obj.setStatus(err.message);
            end
        end
        function [base,state,target] = planningContext(obj)
            assert(~isempty(obj.Session),'detecdivui:PlannerTarget','Select a project.');
            base = detecdivui.IntentPlanner.snapshot(obj.Template,obj.Draft.effectiveNodes());
            base.settings = obj.Setup.values();
            base.settings = obj.overlay(base.settings,obj.Draft.Settings);
            base.source = 'draft';
            if ~strcmp(obj.RunPicker.Value,'draft')
                index = find(strcmp({obj.RunObjects.runId},obj.RunPicker.Value),1);
                assert(~isempty(index),'detecdivui:PlannerRun','This run is no longer available.');
                run = obj.RunObjects(index);
                assert(isfield(run.ctx,'pipelineSpec'),'detecdivui:PlannerRun','This run has no pipeline snapshot.');
                spec = run.ctx.pipelineSpec; base.nodes = spec.nodes;
                if isfield(run.ctx,'run') && isfield(run.ctx.run,'nodeParams')
                    base.nodes = pipelineApplyRunNodeParams(base.nodes,run.ctx.run.nodeParams);
                end
                base.edges = spec.edges; base.branches = obj.field(spec,'branches',struct([]));
                base.name = run.templateId; base.path = run.templatePath; base.source = ['run:' run.runId];
                base.version = obj.field(spec,'version','1.0'); base.runProfiles = obj.field(spec,'runProfiles',struct());
                base.settings = detecdivui.RunSetup.fromRun(run);
            end
            state = detecdivui.ProjectInventory.inspect(obj.Session); target = obj.Session.breadcrumb();
        end
        function proposal = proposeIntent(obj,intent,choices,catalogue)
            assert(isempty(obj.AdvancedEditor) || ~isvalid(obj.AdvancedEditor), ...
                'detecdivui:PlannerEditor','Close the advanced editor and refresh the proposal.');
            [base,state] = obj.planningContext();
            proposal = detecdivui.IntentPlanner.propose(base,state,intent,choices,catalogue);
            proposal.applied = false;
            obj.Proposal = proposal; obj.ProposalProject = obj.Session.Project; obj.ProposalTemplate = obj.Template;
            obj.renderProposal();
        end
        function template = applyProposal(obj)
            assert(~isempty(obj.Proposal) && ~obj.Proposal.applied && obj.Proposal.canApply, ...
                'detecdivui:PlannerIncomplete','Choose the missing methods before using the draft.');
            [base,state] = obj.planningContext(); proposal = obj.Proposal;
            assert(isequal(obj.Session.Project,obj.ProposalProject) && isequal(obj.Template,obj.ProposalTemplate) && ...
                strcmp(jsonencode(base),proposal.baseSignature) && strcmp(state.signature,proposal.inventorySignature), ...
                'detecdivui:PlannerStale','The pipeline or project selection changed. Refresh the proposal.');
            assert(isempty(obj.AdvancedEditor) || ~isvalid(obj.AdvancedEditor), ...
                'detecdivui:PlannerEditor','Close the advanced editor and refresh the proposal.');
            activity = obj.Progress.begin('Creating workflow draft...'); %#ok<NASGU>
            obj.ApplyingProposal = true; guard = onCleanup(@()obj.finishProposal());
            template = pipeline(); prefix = [matlab.lang.makeValidName(base.name) '_workflow'];
            names = cellfun(@(p)p.strid,obj.Templates,'UniformOutput',false);
            template.strid = matlab.lang.makeUniqueStrings(prefix,names,namelengthmax);
            template.description = proposal.label; template.nodes = proposal.nodes;
            template.version = base.version; template.runProfiles = base.runProfiles;
            template.edges = proposal.edges; template.branches = proposal.branches;
            settings = obj.freshPlanSettings(base.settings);
            settings.runId = ''; settings.description = proposal.label;
            settings.fovs = num2str(obj.Session.Position); settings.rois = 'all';
            if obj.Session.Zone>0, settings.rois = num2str(obj.Session.Zone); end
            if isfield(settings,'selectedNodes')
                ids = proposal.changes(ismember(proposal.changes(:,3),{'Added','Reused step'}),1);
                settings.selectedNodes = union(settings.selectedNodes,reshape(ids,1,[]),'stable');
            end
            parent = ''; if isfield(base.settings,'intentProposal'), parent = base.settings.intentProposal.id; end
            event = struct('format','detecdiv.ui.intent_proposal.v1','id',proposal.id,'parentProposal',parent, ...
                'intent',proposal.intent,'label',proposal.label, ...
                'createdAt',char(datetime('now')),'scope',proposal.scope,'changes',{proposal.changes}, ...
                'checks',{proposal.questions},'base',struct('name',base.name,'path',base.path,'source',base.source));
            event.graphSignature = detecdivui.IntentPlanner.configurationSignature(struct('nodes',template.nodes, ...
                'edges',template.edges,'branches',template.branches));
            settings.intentProposal = event;
            obj.addTemplate(template); obj.Draft.configure(settings); obj.Setup.load(settings);
            obj.Scope.Value = 'Run selection'; obj.RunPicker.Value = 'draft';
            proposal.applied = true; obj.Proposal = proposal; obj.ProposalTemplate = template;
            [current,~] = obj.planningContext(); obj.Proposal.appliedSignature = jsonencode(current);
            obj.PlanHistory(end+1) = struct('project',obj.Session.Project,'event',event);
            if numel(obj.PlanHistory)>100, obj.PlanHistory = obj.PlanHistory(end-99:end); end
            obj.updateGraph(); obj.setStatus('Workflow draft created · validation required');
        end
        function cancelProposal(obj)
            if isempty(obj.Proposal) || obj.ApplyingProposal, return; end
            obj.Proposal = []; obj.ProposalProject = []; obj.ProposalTemplate = [];
            obj.Graph.OnToggle = detecdivui.Callback(obj,'widgetEvent','toggle'); obj.updateGraph();
        end
        function showPlanHistory(obj)
            if isgraphics(obj.PlanHistoryFigure), delete(obj.PlanHistoryFigure); end
            obj.PlanHistoryFigure = uifigure('Name','Workflow History','Tag','intent-history-dialog','Position',[260 180 800 420]);
            grid = uigridlayout(obj.PlanHistoryFigure,[2 1]); grid.RowHeight = {'1x',100};
            events = {};
            for k = 1:numel(obj.PlanHistory)
                if isequal(obj.PlanHistory(k).project,obj.Session.Project), events{end+1} = obj.PlanHistory(k).event; end %#ok<AGROW>
            end
            if ~isempty(obj.Session.Project)
                runs = obj.Session.Project.processing.pipelineRun;
                for k = 1:numel(runs)
                    if isfield(runs(k).ctx,'workflowIntent')
                        event = runs(k).ctx.workflowIntent;
                        event.label = [event.label ' · run ' runs(k).runId ' · ' runs(k).status];
                        events{end+1} = event; %#ok<AGROW>
                    end
                end
            end
            rows = cell(numel(events),3);
            for k = 1:numel(events)
                e = events{k}; rows(k,:) = {e.createdAt,e.label,sprintf('FOV %d / ROI %d',e.scope.fov,e.scope.roi)};
            end
            details = uitextarea(grid,'Editable','off','Value',{''},'Tag','intent-history-details'); details.Layout.Row = 2;
            list = uitable(grid,'Data',rows,'ColumnName',{'Time','Action','Scope'},'RowName',{}, ...
                'Tag','intent-history-list','CellSelectionCallback',@(~,e)obj.historySelected(e,events,details));
            list.Layout.Row = 1;
        end
        function delete(obj)
            if ~isempty(obj.StaticDialog) && isvalid(obj.StaticDialog), delete(obj.StaticDialog); end
            if ~isempty(obj.Planner) && isvalid(obj.Planner), delete(obj.Planner); end
            if isgraphics(obj.PlanHistoryFigure), delete(obj.PlanHistoryFigure); end
            if ~isempty(obj.FollowTimer) && isvalid(obj.FollowTimer), stop(obj.FollowTimer); delete(obj.FollowTimer); end
            if ~isempty(obj.SettingsFigure) && isvalid(obj.SettingsFigure), delete(obj.SettingsFigure); end
            if ~isempty(obj.AdvancedEditor) && isvalid(obj.AdvancedEditor)
                editor = obj.AdvancedEditor; editor.clearViewerBridge();
                if ~editor.viewerHasActiveRun(), delete(editor); end
            end
        end
        function rebindCallbacks(obj)
            obj.repairCompactViews();
            obj.Setup.OnChanged = detecdivui.Callback(obj,'widgetEvent','settings');
            obj.Graph.OnSelect = detecdivui.Callback(obj,'widgetEvent','select');
            obj.Graph.OnToggle = detecdivui.Callback(obj,'widgetEvent','toggle');
            obj.CompactGraph.OnSelect = detecdivui.Callback(obj,'widgetEvent','openStep');
            status = detecdivui.Callback(obj,'widgetEvent','graphStatus');
            obj.Graph.OnStatus = status; obj.CompactGraph.OnStatus = status; obj.RunGraph.OnStatus = status;
            for name = {'Graph','CompactGraph','RunGraph'}
                graph = obj.(name{1});
                graph.OnEdit = detecdivui.Callback(obj,'widgetEvent','editModule',name{1});
                graph.OnChangeType = detecdivui.Callback(obj,'widgetEvent','changeType',name{1});
            end
            if ~isempty(obj.FollowTimer) && isvalid(obj.FollowTimer)
                obj.FollowTimer.TimerFcn = {@detecdivui.Callback.event,detecdivui.Callback(obj,'widgetEvent','follow')};
            end
        end
        function result = widgetEvent(obj,action,varargin)
            result = [];
            switch action
                case 'settings', obj.settingsChanged();
                case 'select', obj.openPlanStep(varargin{:},false);
                case 'toggle', obj.toggleStep(varargin{:});
                case 'openStep', obj.openPlanStep(varargin{:},true);
                case 'advanced', obj.acceptAdvanced(varargin{:});
                case 'roiDefinition', obj.acceptRoiDefinition(varargin{:});
                case 'editorROIs', result = obj.requestEditorROIs(varargin{:});
                case 'editorROIResult', obj.acceptEditorROIs(varargin{:});
                case 'follow', obj.followRun();
                case 'graphStatus', obj.setStatus(varargin{1});
                case 'graphView', obj.selectCompactView('pipeline');
                case 'library', obj.showLibrary();
                case 'librarySelect', obj.selectLibraryItem();
                case 'libraryOpen', obj.openLibrarySelection();
                case 'libraryCopy', obj.copyLibraryPath();
                case 'libraryClear', obj.clearRecentPipelines();
                case 'editModule', obj.editGraphModule(varargin{:},false);
                case 'changeType', obj.editGraphModule(varargin{:},true);
                case 'static', obj.openStaticParameters(varargin{:});
                otherwise, error('detecdivui:WidgetEvent','Unknown pipeline widget event.');
            end
        end
        function setContext(obj,session)
            if ~isempty(obj.Session) && ~isequal(obj.Session.Project,session.Project)
                if ~obj.syncAdvanced()
                    obj.NewRun.Enable = 'off'; obj.SettingsButton.Enable = 'off'; obj.SaveRun.Enable = 'off'; return;
                end
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
        function showRuns(obj)
            obj.refreshRuns(); obj.openSettings('Runs');
        end
        function selected = selectProjectRun(obj,runId,project)
            selected = false;
            if nargin > 2 && (isempty(obj.Session) || ~isequal(obj.Session.Project,project))
                obj.setStatus('Close or apply the pipeline editor before switching project runs'); return;
            end
            if ~obj.syncAdvanced(), return; end
            obj.refreshRuns();
            if isempty(obj.RunObjects), obj.setStatus('No runs in the selected project'); return; end
            index = find(strcmp({obj.RunObjects.runId},char(string(runId))),1);
            if isempty(index), obj.setStatus('This run is no longer available in the selected project'); return; end
            if ~isempty(obj.Proposal), obj.cancelProposal(); end
            obj.selectRun(struct('Indices',[index 1]));
            obj.selectCompactView('pipeline');
            selected = true;
        end
        function showLibrary(obj)
            if isempty(obj.RecentPipelines), obj.RecentPipelines = detecdivui.RecentPipelines(); end
            if ~isempty(obj.RecentPipelines.File), obj.RecentPipelines.reload(); end
            obj.refreshLibrary(); obj.selectCompactView('library');
        end
        function template = openRecent(obj,path)
            template = [];
            try
                path = detecdivui.RecentPipelines.normalizePath(path);
                if ~obj.syncAdvanced(), return; end
                for k = 1:numel(obj.Templates)
                    candidate = obj.Templates{k};
                    if isvalid(candidate) && ~isempty(candidate.path) && ...
                            detecdivui.RecentPipelines.samePath(candidate.path,path)
                        obj.addTemplate(candidate); obj.selectDraft();
                        obj.setStatus('Pipeline selected');
                        obj.rememberPipeline(path); template = candidate; return;
                    end
                end
                template = obj.openTemplate(path);
            catch err, obj.setStatus(err.message);
            end
        end
        function template = openLibrarySelection(obj)
            template = [];
            if isempty(obj.LibraryTree.SelectedNodes), return; end
            data = obj.LibraryTree.SelectedNodes(1).UserData;
            if ~isstruct(data) || ~isfield(data,'kind'), return; end
            if strcmp(data.kind,'recent')
                template = obj.openRecent(data.path);
            elseif strcmp(data.kind,'open') && isvalid(data.template)
                candidate = data.template;
                index = find(cellfun(@(p)isequal(p,candidate) || (~isempty(candidate.path) && ...
                    ~isempty(p.path) && detecdivui.RecentPipelines.samePath(p.path,candidate.path)),obj.Templates),1);
                if isempty(index) || ~obj.syncAdvanced(), return; end
                obj.addTemplate(obj.Templates{index}); obj.selectDraft(); template = obj.Template;
                if ~isempty(template.path), obj.rememberPipeline(template.path); end
            end
        end
        function clearRecentPipelines(obj)
            try
                obj.RecentPipelines.clear(); obj.refreshLibrary(); obj.setStatus('Recent pipelines cleared');
            catch err, obj.setStatus(err.message);
            end
        end
        function selectDraft(obj)
            obj.RunPicker.Value = 'draft'; obj.selectCompactRun(); obj.selectCompactView('pipeline');
        end
        function template = newTemplate(obj,name)
            template = [];
            if ~obj.syncAdvanced(), return; end
            if nargin < 2 || isempty(name), name = 'untitled_pipeline'; end
            names = cellfun(@(p)p.strid,obj.Templates,'UniformOutput',false);
            template = pipeline(); template.strid = matlab.lang.makeUniqueStrings(char(name),names);
            obj.addTemplate(template); obj.RunPicker.Value = 'draft'; obj.selectCompactRun();
            obj.selectCompactView('pipeline');
            detecdivui.Callback.call(obj.OnTemplateOpened,template);
        end
        function editor = openDefinitionEditor(obj,nodeId)
            editor = [];
            if nargin < 2, nodeId = ''; end
            if obj.DefinitionEditor && ~isempty(obj.AdvancedEditor) && isvalid(obj.AdvancedEditor)
                editor = obj.AdvancedEditor;
                if ~isempty(nodeId), editor.selectViewerModule(nodeId); end
                editor.UIFigure.Visible = 'on'; figure(editor.UIFigure); return;
            end
            if ~obj.syncAdvanced(), return; end
            if ~isempty(obj.selectedRun()) && isempty(obj.useRunPipeline()), return; end
            if isempty(obj.Template), obj.newTemplate(); end
            activity = obj.Progress.begin('Opening pipeline designer...'); %#ok<NASGU>
            try
                editor = pipeline2(obj.Template,'ViewerDefinitionOnly',true);
                obj.DefinitionEditor = true; obj.DefinitionTemplate = obj.Template;
                obj.AdvancedEditor = editor;
                editor.configureViewerBridge(detecdivui.Callback(obj,'widgetEvent','advanced'), ...
                    detecdivui.Callback(obj,'widgetEvent','editorROIs'),true);
                if ~isempty(nodeId), editor.selectViewerModule(nodeId); end
            catch err, obj.setStatus(err.message);
            end
        end
        function editor = editModule(obj,nodeId,changeType)
            editor = [];
            if nargin < 3, changeType = false; end
            if nargin < 2 || isempty(nodeId)
                if isempty(obj.Template) || obj.SelectedStep < 1 || obj.SelectedStep > numel(obj.Template.nodes), return; end
                nodeId = obj.Template.nodes(obj.SelectedStep).id;
            end
            try
                if ~isempty(obj.Proposal) && ~obj.Proposal.applied
                    obj.setStatus('Apply the workflow proposal before editing its modules'); return;
                end
                editor = obj.openDefinitionEditor(nodeId);
                if isempty(editor), return; end
                selected = find(strcmp({obj.Template.nodes.id},nodeId),1);
                if ~isempty(selected), obj.showParams(selected); end
                obj.SettingsFigure.Visible = 'off';
                if changeType, editor.changeViewerModuleType(nodeId); end
            catch err, obj.setStatus(err.message);
            end
        end
        function dialog = openStaticParameters(obj,nodeId)
            dialog = [];
            if nargin < 2, nodeId = ''; end
            if ~isempty(obj.AdvancedEditor) && isvalid(obj.AdvancedEditor)
                obj.setStatus('Close the Pipeline Designer before editing static parameters'); return;
            end
            if ~obj.syncAdvanced(), return; end
            if ~isempty(obj.selectedRun()) && isempty(obj.useRunPipeline()), return; end
            if isempty(obj.Template), return; end
            index = obj.SelectedStep;
            if ~isempty(nodeId), index = find(strcmp({obj.Template.nodes.id},nodeId),1); end
            if isempty(index) || index < 1, return; end
            node = obj.Template.nodes(index);
            [~,keys] = detecdivui.PipelineBindings.describe(node,obj.Template.nodes);
            token = obj.parameterToken(node.id);
            if ~isempty(obj.StaticDialog) && isvalid(obj.StaticDialog), delete(obj.StaticDialog); end
            dialog = detecdivui.StaticParameterDialog(node,keys, ...
                detecdivui.Callback(obj,'applyStaticParameters',token),detecdivui.Callback(obj,'editStaticAdvanced',token));
            obj.StaticDialog = dialog;
        end
        function applyStaticParameters(obj,token,nodeId,params)
            obj.assertParameterToken(token,nodeId);
            index = find(strcmp({obj.Template.nodes.id},nodeId),1);
            [~,keys] = detecdivui.PipelineBindings.describe(obj.Template.nodes(index),obj.Template.nodes);
            changed = struct();
            for k = 1:numel(keys)
                key = keys{k};
                if ~isequaln(params.(key),obj.Template.nodes(index).params.(key)), changed.(key) = params.(key); end
            end
            if ~isempty(fieldnames(changed)), obj.modifyDefinition(nodeId,changed); end
        end
        function editStaticAdvanced(obj,token,nodeId)
            obj.assertParameterToken(token,nodeId);
            obj.editModule(nodeId);
        end
        function template = useRunPipeline(obj)
            template = [];
            if ~obj.syncAdvanced(), return; end
            run = obj.selectedRun(); if isempty(run), return; end
            try
                template = detecdivui.ProjectRuns.snapshot(run);
                overrides = obj.field(obj.field(run.ctx,'run',struct()),'nodeParams',struct('id',{},'params',{}));
                template.nodes = pipelineApplyRunNodeParams(template.nodes,overrides);
                names = cellfun(@(p)p.strid,obj.Templates,'UniformOutput',false);
                template.strid = matlab.lang.makeUniqueStrings([template.strid '_from_' run.runId],names);
                obj.addTemplate(template);
                settings = detecdivui.RunSetup.fromRun(run); settings = obj.freshPlanSettings(settings);
                settings.description = ['Based on run ' run.runId];
                obj.Draft.configure(settings); obj.loadSettings();
                obj.RunPicker.Value = 'draft'; obj.selectCompactRun();
                obj.selectCompactView('pipeline');
                detecdivui.Callback.call(obj.OnTemplateOpened,template);
                obj.setStatus(['Pipeline draft from ' run.runId]);
            catch err, template = []; obj.setStatus(err.message);
            end
        end
        function refreshProjectRuns(obj)
            if isempty(obj.Session) || isempty(obj.Session.Project), return; end
            activity = obj.Progress.begin('Finding project run records...'); %#ok<NASGU>
            [added,issues] = detecdivui.ProjectRuns.discover(obj.Session.Project);
            obj.refresh();
            if isempty(issues), obj.setStatus(sprintf('%d runs · %d discovered',numel(obj.RunObjects),added));
            else, obj.setStatus(strjoin(issues,'; ')); end
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
                        (~isempty(template.path) && ~isempty(other.path) && detecdivui.RecentPipelines.samePath(template.path,other.path)))
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
                        entry ~= active && ~isempty(entry.path) && detecdivui.RecentPipelines.samePath(entry.path,active.path), continue; end
                obj.addTemplate(entry);
            end
            if ~isempty(active) && isvalid(active), obj.addTemplate(active); end
        end
        function template = openTemplate(obj,path)
            template = [];
            try
                if nargin < 2
                    [file,folder] = uigetfile('*.json','Open Pipeline');
                    if isequal(file,0), return; end
                    path = fullfile(folder,file);
                end
                path = detecdivui.RecentPipelines.normalizePath(path);
                for k = 1:numel(obj.Templates)
                    if isvalid(obj.Templates{k}) && ~isempty(obj.Templates{k}.path) && ...
                            detecdivui.RecentPipelines.samePath(obj.Templates{k}.path,path)
                        template = obj.openRecent(path); return;
                    end
                end
                activity = obj.Progress.begin('Loading pipeline...'); %#ok<NASGU>
                [template,message] = pipelineLoad(path);
                assert(~isempty(template),'detecdivui:PipelineLoad','%s',message);
                obj.addTemplate(template);
                if ~isequal(obj.Template,template), template = []; return; end
                obj.selectDraft();
                detecdivui.Callback.call(obj.OnTemplateOpened,template);
                obj.setStatus('Pipeline opened');
                obj.rememberPipeline(path);
            catch err
                template = [];
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
            obj.BindingTable.Data = cell(0,4); obj.BindingRows = struct([]); obj.SelectedBinding = 0;
            obj.StaticButton.Enable = 'off'; obj.BindingChoice.Enable = 'off'; obj.BindingScope.Enable = 'off';
            obj.BindingApply.Enable = 'off'; obj.BindingReset.Enable = 'off';
            obj.SelectedStep = 0; obj.clearParamEditor();
            obj.ModuleLabel.Text = '—'; obj.ModuleLabel.Tooltip = '';
            obj.EditModuleButton.Enable = 'off'; obj.ChangeTypeButton.Enable = 'off';
            project = []; if ~isempty(obj.Session), project = obj.Session.Project; end
            obj.Draft.select(project,obj.Template);
            obj.loadSettings();
            available = ~isempty(obj.Template);
            obj.Save.Enable = obj.onOff(available);
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
            obj.refreshLibrary();
            obj.updateGraph();
            obj.draftNotice();
            detecdivui.Callback.call(obj.OnChanged);
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
            if isfield(obj.Draft.Settings,'intentProposal')
                ctx.workflowIntent = obj.Draft.Settings.intentProposal;
                effective = struct('nodes',obj.Draft.effectiveNodes(),'edges',obj.Template.edges,'branches',obj.Template.branches);
                ctx.workflowIntent.modifiedAfterProposal = ~isfield(ctx.workflowIntent,'graphSignature') || ...
                    ~strcmp(ctx.workflowIntent.graphSignature,detecdivui.IntentPlanner.configurationSignature(effective));
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
                'nodes',obj.Template.nodes,'edges',obj.Template.edges,'branches',obj.Template.branches, ...
                'version',obj.Template.version,'runProfiles',obj.Template.runProfiles);
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
            obj.RunTemplates = obj.RunTemplates(~arrayfun(@(item)isequal(item.project,project),obj.RunTemplates));
            if isequal(obj.ProposalProject,project), obj.cancelProposal(); end
            obj.PlanHistory = obj.PlanHistory(~arrayfun(@(item)isequal(item.project,project),obj.PlanHistory));
            if isgraphics(obj.PlanHistoryFigure), delete(obj.PlanHistoryFigure); end
        end
        function rebindProject(obj,oldProject,newProject)
            obj.Draft.rebindProject(oldProject,newProject);
            obj.RunTemplates = obj.RunTemplates(~arrayfun(@(item)isequal(item.project,oldProject),obj.RunTemplates));
            for k = 1:numel(obj.PlanHistory)
                if isequal(obj.PlanHistory(k).project,oldProject), obj.PlanHistory(k).project = newProject; end
            end
            if isequal(obj.ProposalProject,oldProject), obj.cancelProposal(); end
        end
        function newRun(obj)
            if ~obj.syncAdvanced(), return; end
            if ~obj.loadSelectedRun(), return; end
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
        function saveTemplate(obj,parent)
            if ~obj.syncAdvanced(), return; end
            if isempty(obj.Template), return; end
            activity = obj.Progress.begin('Saving pipeline...'); %#ok<NASGU>
            try
                if isempty(obj.Template.path)
                    if nargin<2, parent = uigetdir(pwd,'Choose a parent folder for this pipeline'); end
                    if isequal(parent,0), return; end
                    destination = fullfile(parent,obj.Template.strid);
                    assert(~isfolder(destination),'detecdivui:PlanDestination','Choose another folder; this pipeline directory already exists.');
                    saved = pipeline();
                    for key = properties(obj.Template)', saved.(key{1}) = obj.Template.(key{1}); end
                    saved.path = destination; pipelineSave(saved,'Artifacts',false);
                    obj.Template.path = destination; obj.setStatus('Pipeline saved'); obj.rememberPipeline(destination); return;
                end
                pipelineSave(obj.Template); obj.setStatus('Pipeline saved'); obj.rememberPipeline(obj.Template.path);
            catch err
                obj.setStatus(err.message);
            end
        end
        function editor = openEditor(obj)
            if obj.DefinitionEditor && ~obj.syncAdvanced(), editor = []; return; end
            if ~isempty(obj.AdvancedEditor) && isvalid(obj.AdvancedEditor)
                editor = obj.AdvancedEditor; editor.UIFigure.Visible = 'on'; return;
            end
            editor = [];
            if ~obj.loadSelectedRun(), return; end
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
                    editor.configureViewerBridge(detecdivui.Callback(obj,'widgetEvent','advanced'), ...
                        detecdivui.Callback(obj,'widgetEvent','editorROIs'));
                    obj.SettingsFigure.Visible = 'off';
                end
            catch err
                obj.setStatus(err.message);
            end
        end
        function ok = syncAdvanced(obj)
            ok = true;
            if obj.Syncing, return; end
            if isempty(obj.AdvancedEditor) || ~isvalid(obj.AdvancedEditor)
                obj.AdvancedEditor = []; obj.DefinitionEditor = false; obj.DefinitionTemplate = []; return;
            end
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
            if obj.DefinitionEditor
                assert(~isempty(obj.DefinitionTemplate) && isequal(obj.Template,obj.DefinitionTemplate), ...
                    'detecdivui:TemplateContext','Select the original pipeline before applying its definition.');
                settings = obj.Draft.Settings; overrides = obj.Draft.Overrides;
                originalNodes = obj.Template.nodes;
                selectedId = '';
                if obj.SelectedStep > 0 && obj.SelectedStep <= numel(originalNodes), selectedId = originalNodes(obj.SelectedStep).id; end
                copy = pipeline();
                for field = properties(obj.Template)', copy.(field{1}) = obj.Template.(field{1}); end
                for field = {'nodes','edges','branches'}, copy.(field{1}) = obj.field(state.pipeline,field{1},struct([])); end
                copy.strid = obj.field(state.pipeline,'name',copy.strid);
                copy.path = obj.field(state.pipeline,'path',copy.path);
                nodeIds = {}; if isfield(copy.nodes,'id'), nodeIds = {copy.nodes.id}; end
                index = find(cellfun(@(p)p == obj.Template,obj.Templates),1);
                obj.Templates{index} = copy; obj.Template = copy;
                % A replacement module gets fresh defaults. Keep the run's
                % other settings/overrides; do not shadow edited parameters.
                for k = numel(overrides):-1:1
                    before = find(strcmp({originalNodes.id},overrides(k).id),1);
                    after = find(strcmp(nodeIds,overrides(k).id),1);
                    if isempty(before) || isempty(after) || ...
                            ~strcmp(originalNodes(before).type,copy.nodes(after).type) || ...
                            ~strcmp(obj.field(originalNodes(before),'pkg',''),obj.field(copy.nodes(after),'pkg','')) || ...
                            ~isequaln(obj.field(originalNodes(before),'func',''),obj.field(copy.nodes(after),'func',''))
                        overrides(k) = []; continue;
                    end
                    keys = fieldnames(overrides(k).params);
                    for j = 1:numel(keys)
                        key = keys{j};
                        if ~isequaln(obj.field(originalNodes(before).params,key,[]),obj.field(copy.nodes(after).params,key,[]))
                            overrides(k).params = rmfield(overrides(k).params,key);
                        end
                    end
                end
                if isfield(settings,'selectedNodes'), settings.selectedNodes = intersect(settings.selectedNodes,nodeIds,'stable'); end
                project = []; if ~isempty(obj.Session), project = obj.Session.Project; end
                obj.Draft.select(project,copy); obj.Draft.import(settings,overrides);
                obj.DefinitionEditor = false; obj.DefinitionTemplate = [];
                obj.refresh(); obj.RunPicker.Value = 'draft'; obj.updateGraph();
                selected = find(strcmp(nodeIds,selectedId),1);
                if ~isempty(selected), obj.showParams(selected); end
                detecdivui.Callback.call(obj.OnTemplateOpened,copy); obj.setStatus('Pipeline definition applied'); return;
            end
            if ~isempty(obj.Session) && ~isequal(state.project,obj.Session.Project) && ~isempty(obj.OnProjectUpdated)
                old = obj.Session.Project; fresh = state.project;
                sameId = ~isempty(old) && strlength(string(old.projectId)) > 0 && strcmp(old.projectId,fresh.projectId);
                samePath = ~isempty(old) && strlength(string(old.io.path)) > 0 && ...
                    strcmpi(fullfile(old.io.path,old.io.file),fullfile(fresh.io.path,fresh.io.file));
                if sameId || samePath, detecdivui.Callback.call(obj.OnProjectUpdated,fresh); end
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
            if isfield(state.ctx,'workflowIntent'), settings.intentProposal = state.ctx.workflowIntent;
            elseif isfield(obj.Draft.Settings,'intentProposal'), settings.intentProposal = obj.Draft.Settings.intentProposal; end
            obj.Draft.select(obj.Session.Project,obj.Template);
            obj.Draft.import(settings,state.ctx.run.nodeParams);
            obj.refresh(); obj.setStatus('Advanced settings applied');
            obj.RunPicker.Value = 'draft'; obj.updateGraph();
        end
        function defineROIs(obj)
            if isempty(obj.OnDefineROIs) || isempty(obj.Template) || obj.SelectedStep < 1, return; end
            if isempty(obj.Session) || isempty(obj.Session.Project) || obj.Session.Position == 0
                obj.setStatus('Select a project FOV in the viewer before defining ROIs.'); return;
            end
            nodes = obj.Draft.effectiveNodes(); node = nodes(obj.SelectedStep);
            if ~any(strcmpi(node.type,{'roiManual','roiPattern','roiIdentify','roiGrid','roiTracked'}))
                obj.setStatus('Select an ROI definition step'); return;
            end
            project = obj.Session.Project; token = obj.DefinitionContext; position = obj.Session.Position;
            indices = obj.field(node.params,'fovIndex',[]);
            settings = obj.Setup.values();
            if isempty(indices) && strcmp(obj.Scope.Value,'Run selection')
                try
                    indices = detecdivui.RunSetup.selection(settings.fovs,cellstr(string({project.fov.id})));
                catch err, obj.setStatus(err.message); return;
                end
            end
            if ~isempty(indices) && ~ismember(position,indices), position = indices(1); end
            if strcmp(settings.inputSourceMode,'raw_dataloader') && ~obj.matchesRawSource(project,position,settings.rawDataPath)
                obj.setStatus('Open the selected raw acquisition in Projects before defining ROIs on it.'); return;
            end
            obj.SettingsFigure.Visible = 'off';
            signature = jsonencode(obj.Template.nodes(obj.SelectedStep));
            callback = detecdivui.Callback(obj,'widgetEvent','roiDefinition',token,project,position,node,signature);
            scope = struct('pipeline',obj.Template.strid,'node',node.id,'position',position,'definitionOnly',false);
            detecdivui.Callback.call(obj.OnDefineROIs,project,node,callback,scope);
        end
        function opened = requestEditorROIs(obj,project,node,callback,source)
            opened = false;
            if nargin < 5, source = struct(); end
            try
                assert(isa(callback,'detecdivui.Callback') && ~isempty(obj.AdvancedEditor) && ...
                    isvalid(obj.AdvancedEditor) && isequal(callback.Owner,obj.AdvancedEditor), ...
                    'detecdivui:ROIEditor','Reopen the module in the active pipeline editor.');
                assert(~isempty(obj.Session) && ~isempty(obj.Session.Project) && obj.Session.Position > 0, ...
                    'detecdivui:ROIContext','Select a project FOV in the viewer before defining ROIs.');
                if isempty(project), project = obj.Session.Project; end
                assert(isequal(project,obj.Session.Project),'detecdivui:ROIContext', ...
                    'Select the pipeline editor''s project in the viewer.');
                position = obj.Session.Position;
                indices = obj.field(node.params,'fovIndex',[]);
                if ~isempty(indices) && ~ismember(position,indices), position = indices(1); end
                if strcmp(obj.field(source,'inputSourceMode',''),'raw_dataloader')
                    raw = obj.field(source,'rawDataPath','');
                    assert(obj.matchesRawSource(project,position,raw),'detecdivui:ROIRawSource', ...
                        'Open the selected raw acquisition in Projects before defining ROIs on it.');
                end
                scope = struct('pipeline',obj.Template.strid,'node',node.id,'position',position, ...
                    'definitionOnly',obj.DefinitionEditor);
                bound = detecdivui.Callback(obj,'widgetEvent','editorROIResult', ...
                    obj.AdvancedEditor,obj.DefinitionContext,project,position,callback);
                opened = detecdivui.Callback.call(obj.OnDefineROIs,project,node,bound,scope);
            catch err, obj.setStatus(err.message);
            end
        end
        function acceptEditorROIs(obj,editor,token,project,position,callback,ctx)
            assert(~isempty(obj.AdvancedEditor) && isvalid(editor) && isequal(obj.AdvancedEditor,editor) && ...
                token == obj.DefinitionContext && isequal(project,obj.Session.Project) && ...
                obj.Session.Position == position && isequal(ctx.shallow,project) && ctx.fovIndex == position, ...
                'detecdivui:ROIContext','The image or pipeline context changed. Reopen Define ROIs from the module.');
            detecdivui.Callback.call(callback,ctx);
        end
        function acceptRoiDefinition(obj,token,project,position,node,signature,ctx)
            assert(token == obj.DefinitionContext && isequal(project,obj.Session.Project) && ...
                obj.Session.Position == position && ctx.fovIndex == position && isequal(ctx.shallow,project), ...
                'detecdivui:ROIContext','The project or pipeline changed. Open Define ROIs again.');
            index = find(strcmp({obj.Template.nodes.id},node.id),1);
            assert(~isempty(index) && strcmp(jsonencode(obj.Template.nodes(index)),signature), ...
                'detecdivui:ROIContext','The ROI step changed. Open Define ROIs again.');
            % ROI geometry is a definition; edit a working template copy only.
            state = struct('project',obj.Session.Project,'pipeline',struct('nodes',obj.Template.nodes, ...
                'edges',obj.Template.edges,'branches',obj.Template.branches),'settings',obj.Draft.Settings, ...
                'ctx',struct('run',struct('nodeParams',obj.Draft.Overrides)));
            values = obj.Setup.values();
            for field = fieldnames(values)', state.settings.(field{1}) = values.(field{1}); end
            state.pipeline.nodes(index).params = ctx.params;
            at = find(strcmp({state.ctx.run.nodeParams.id},node.id),1);
            if isempty(at)
                state.ctx.run.nodeParams(end+1) = struct('id',node.id,'params',struct()); at = numel(state.ctx.run.nodeParams);
            end
            for key = fieldnames(ctx.params)'
                if strcmp(pipelineParamScope(state.pipeline.nodes(index),key{1}),'run')
                    state.ctx.run.nodeParams(at).params.(key{1}) = ctx.params.(key{1});
                end
            end
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
        function createLibrary(obj)
            if isgraphics(obj.LibraryTree), return; end
            grid = uigridlayout(obj.LibraryPanel,[2 1]); grid.Padding = [0 0 0 0];
            grid.RowHeight = {24,'1x'}; grid.RowSpacing = 4;
            buttons = uigridlayout(grid,[1 3]); buttons.Padding = [0 0 0 0]; buttons.ColumnWidth = {'1x',65,65};
            obj.LibraryName = uilabel(buttons,'Text','Pipelines','FontWeight','bold','Tag','pipeline-library-name');
            uibutton(buttons,'Text','New...','Tag','pipeline-library-new', ...
                'Tooltip','Create an independent pipeline','ButtonPushedFcn',@(~,~)obj.newTemplate());
            obj.LibraryOpen = uibutton(buttons,'Text','Open...','Tag','pipeline-library-file', ...
                'Tooltip','Open a pipeline JSON file','ButtonPushedFcn',@(~,~)obj.openTemplate());
            obj.LibraryTree = uitree(grid,'Tag','pipeline-library', ...
                'Tooltip','Select an open or recent pipeline', ...
                'SelectionChangedFcn',{@detecdivui.Callback.event,detecdivui.Callback(obj,'widgetEvent','librarySelect')});
            menu = uicontextmenu(ancestor(grid,'figure'),'Tag','pipeline-recent-menu');
            obj.LibraryCopy = uimenu(menu,'Text','Copy Pipeline Path','Enable','off','Tag','pipeline-library-copy', ...
                'MenuSelectedFcn',{@detecdivui.Callback.event,detecdivui.Callback(obj,'widgetEvent','libraryCopy')});
            uimenu(menu,'Text','Clear Recent Pipelines','Tag','pipeline-clear-recent', ...
                'MenuSelectedFcn',{@detecdivui.Callback.event,detecdivui.Callback(obj,'widgetEvent','libraryClear')});
            obj.LibraryTree.ContextMenu = menu;
        end
        function refreshLibrary(obj)
            if obj.UpdatingLibrary, return; end
            if isempty(obj.RecentPipelines), obj.RecentPipelines = detecdivui.RecentPipelines(); end
            obj.createLibrary();
            selected = struct();
            if ~isempty(obj.LibraryTree.SelectedNodes), selected = obj.LibraryTree.SelectedNodes(1).UserData; end
            obj.UpdatingLibrary = true; release = onCleanup(@()obj.endLibraryUpdate());
            obj.LibraryTree.SelectedNodes = []; delete(obj.LibraryTree.Children);
            open = uitreenode(obj.LibraryTree,'Text','Open','Tag','pipeline-open-group'); open.UserData = struct('kind','group');
            recent = uitreenode(obj.LibraryTree,'Text','Recent','Tag','pipeline-recent-group'); recent.UserData = struct('kind','group');
            chosen = [];
            names = cell(1,numel(obj.Templates));
            for k = 1:numel(obj.Templates)
                if isvalid(obj.Templates{k}), names{k} = char(string(obj.Templates{k}.strid)); end
            end
            for k = 1:numel(obj.Templates)
                template = obj.Templates{k}; if ~isvalid(template), continue; end
                name = char(string(template.strid)); if isempty(name), name = 'Untitled Pipeline'; end
                path = ''; if ~isempty(template.path), path = detecdivui.RecentPipelines.normalizePath(template.path); end
                if nnz(strcmp(names,template.strid)) > 1 && ~isempty(path), name = obj.disambiguateLibraryName(name,path); end
                node = uitreenode(open,'Text',name,'Tag','pipeline-library-item');
                node.UserData = struct('kind','open','template',template,'path',path);
                if strcmp(obj.RunPicker.Value,'draft') && isequal(obj.Template,template)
                    chosen = node;
                end
            end
            recentNames = arrayfun(@(path)obj.pipelineFileLabel(path),obj.RecentPipelines.Paths,'UniformOutput',false);
            for path = reshape(obj.RecentPipelines.Paths,1,[])
                alreadyOpen = any(cellfun(@(p)isvalid(p) && ~isempty(p.path) && ...
                    detecdivui.RecentPipelines.samePath(p.path,path),obj.Templates));
                if alreadyOpen, continue; end
                name = obj.pipelineFileLabel(path);
                if nnz(strcmp(recentNames,name)) > 1, name = obj.disambiguateLibraryName(name,path); end
                node = uitreenode(recent,'Text',name,'Tag','pipeline-library-item');
                node.UserData = struct('kind','recent','path',char(path));
                if isstruct(selected) && isfield(selected,'kind') && strcmp(selected.kind,'recent') && ...
                    detecdivui.RecentPipelines.samePath(path,selected.path), chosen = node; end
            end
            expand(open); expand(recent);
            if ~isempty(chosen), obj.LibraryTree.SelectedNodes = chosen; end
            obj.selectLibraryItem(false);
        end
        function endLibraryUpdate(obj)
            obj.UpdatingLibrary = false;
        end
        function selectLibraryItem(obj,activate)
            if nargin < 2, activate = true; end
            if activate && obj.UpdatingLibrary, return; end
            obj.LibraryCopy.Enable = 'off'; obj.LibraryCopy.UserData = '';
            obj.LibraryTree.Tooltip = 'Select an open or recent pipeline';
            if isempty(obj.LibraryTree.SelectedNodes), return; end
            data = obj.LibraryTree.SelectedNodes(1).UserData;
            if ~isstruct(data) || ~isfield(data,'path'), return; end
            if ~isempty(data.path)
                obj.LibraryTree.Tooltip = data.path;
                obj.LibraryCopy.Enable = 'on'; obj.LibraryCopy.UserData = data.path;
            else
                obj.LibraryTree.Tooltip = 'Unsaved pipeline';
            end
            if activate, obj.openLibrarySelection(); end
        end
        function copyLibraryPath(obj)
            if isempty(obj.LibraryCopy.UserData), return; end
            try
                clipboard('copy',obj.LibraryCopy.UserData); obj.setStatus('Pipeline path copied');
            catch err
                obj.setStatus(err.message);
            end
        end
        function rememberPipeline(obj,path)
            try
                obj.RecentPipelines.remember(path); obj.refreshLibrary();
            catch err, obj.setStatus(['Pipeline is available; recent history was not saved: ' err.message]);
            end
        end
        function repairCompactViews(obj)
            if isgraphics(obj.GraphPanel) && isgraphics(obj.LibraryPanel)
                assert(~isempty(obj.CompactGraph) && isvalid(obj.CompactGraph) && isgraphics(obj.CompactGraph.Axes), ...
                    'detecdivui:PipelineViews','Pipeline view is no longer available. Reopen the viewer.');
                return;
            end
            % Class edits can leave a newly renamed cached property empty in
            % live viewers. Recover the existing views from their content;
            % recreating tabs here would lose graph/history UI state.
            assert(~isempty(obj.CompactGraph) && isvalid(obj.CompactGraph) && isgraphics(obj.CompactGraph.Axes) && ...
                isgraphics(obj.CompactRuns),'detecdivui:PipelineViews','Pipeline views are no longer available. Reopen the viewer.');
            graphTab = ancestor(obj.CompactGraph.Axes,'uitab');
            runsTab = ancestor(obj.CompactRuns,'uitab');
            assert(~isempty(graphTab) && ~isempty(runsTab) && isgraphics(graphTab.Parent,'uitabgroup') && ...
                isequal(graphTab.Parent,runsTab.Parent),'detecdivui:PipelineViews','Pipeline views are no longer available. Reopen the viewer.');
            obj.CompactTabs = graphTab.Parent; obj.PipelineTab = graphTab; obj.WorkflowTab = graphTab;
            obj.CompactRunsTab = runsTab;
            graphTab.Title = 'Pipeline'; graphTab.Tag = 'pipeline-graph-tab'; runsTab.Tag = 'pipeline-runs-tab';
            buttons = findall(runsTab,'Type','uibutton','Text','Graph');
            for button = reshape(buttons,1,[])
                button.Tag = 'pipeline-show-graph';
                button.ButtonPushedFcn = {@detecdivui.Callback.event,detecdivui.Callback(obj,'widgetEvent','graphView')};
            end
        end
        function selectCompactView(obj,view)
            obj.repairCompactViews();
            if isgraphics(obj.GraphPanel), return; end
            if strcmp(view,'runs')
                tab = obj.CompactRunsTab;
            elseif strcmp(view,'library')
                obj.createLibrary(); tab = obj.LibraryTab;
            else
                tab = obj.PipelineTab;
            end
            obj.CompactTabs.SelectedTab = tab;
        end
        function editGraphModule(obj,graph,index,changeType)
            graph = obj.(graph); nodes = graph.Model.nodes;
            if index < 1 || index > numel(nodes), return; end
            obj.editModule(nodes(index).id,changeType);
        end
        function finishProposal(obj)
            obj.ApplyingProposal = false; obj.updateGraph();
        end
        function renderProposal(obj)
            if isempty(obj.Proposal) || obj.ApplyingProposal, return; end
            [base,state] = obj.planningContext(); p = obj.Proposal;
            expected = p.baseSignature; if p.applied, expected = p.appliedSignature; end
            if ~isequal(obj.ProposalProject,obj.Session.Project) || ~isequal(obj.ProposalTemplate,obj.Template) || ...
                    ~strcmp(expected,jsonencode(base)) || ~strcmp(p.inventorySignature,state.signature)
                obj.Proposal = []; obj.ProposalProject = []; obj.ProposalTemplate = [];
                obj.Graph.OnToggle = detecdivui.Callback(obj,'widgetEvent','toggle');
                if ~isempty(obj.Planner) && isvalid(obj.Planner), obj.Planner.invalidate('Context changed · Refresh to propose again'); end
                return;
            end
            obj.Graph.OnToggle = [];
            obj.Graph.show(p.viewNodes,p.viewEdges,0,true(1,numel(p.viewNodes)),p.statuses);
            obj.CompactGraph.show(p.viewNodes,p.viewEdges,0,true(1,numel(p.viewNodes)),p.statuses);
            label = 'Proposal'; if p.applied, label = 'Workflow draft'; end
            obj.RunState.Text = sprintf('%s · %d added / %d reused',label, ...
                nnz(strcmp(p.statuses,'Added')),nnz(strcmp(p.statuses,'Reused step')));
            obj.RunState.Tooltip = 'Reused step means a configuration was preserved; scientific results still require checks.';
        end
        function openPlanStep(obj,index,open)
            if ~isempty(obj.Proposal)
                nodes = obj.Proposal.viewNodes;
                if index<1 || index>numel(nodes), return; end
                id = nodes(index).id; target = [];
                if ~isempty(obj.Template), target = find(strcmp({obj.Template.nodes.id},id),1); end
                if ~isempty(target)
                    if open, obj.openSettings('Steps'); end
                    obj.showParams(target);
                else
                    at = find(strcmp(obj.Proposal.changes(:,1),id),1);
                    if ~isempty(at), obj.setStatus(strjoin(obj.Proposal.changes(at,[2 3 4]),' · ')); end
                end
            elseif open
                obj.openStep(index);
            else
                obj.showParams(index);
            end
        end
        function historySelected(~,event,events,details)
            if isempty(event.Indices), return; end
            selected = events{event.Indices(1,1)};
            details.Value = cellstr(splitlines(string(jsonencode(selected,'PrettyPrint',true))));
        end
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
            if obj.Busy || obj.Syncing, return; end
            obj.notifyRunsChanged();
            if ~isempty(obj.Proposal) || isempty(obj.RunPicker) || ~isvalid(obj.RunPicker) || ...
                    strcmp(obj.RunPicker.Value,'draft') || isempty(obj.RunObjects), return; end
            index = find(strcmp({obj.RunObjects.runId},obj.RunPicker.Value),1);
            if isempty(index) || ~isvalid(obj.RunObjects(index)), return; end
            run = obj.RunObjects(index); obj.RunState.Text = char(string(run.status));
            if isfield(run.progress,'message') && ~isempty(run.progress.message)
                obj.RunState.Tooltip = char(string(run.progress.message));
            end
            obj.Runs.Data{index,2} = run.status;
            if isgraphics(obj.CompactRuns)
                obj.CompactRuns.Data{index,2} = run.status;
                obj.CompactRuns.Data{index,4} = run.updatedAt;
            end
        end
        function ok = loadSelectedRun(obj)
            ok = true;
            if strcmp(obj.RunPicker.Value,'draft'), return; end
            index = find(strcmp({obj.RunObjects.runId},obj.RunPicker.Value),1);
            if isempty(index), return; end
            run = obj.RunObjects(index);
            try
                template = obj.templateForRun(run);
            catch err
                ok = false; obj.setStatus(err.message); return;
            end
            if isempty(obj.Template) || ~isequal(obj.Template,template), obj.addTemplate(template); end
            ctx = run.ctx; settings = detecdivui.RunSetup.fromRun(run); settings.runId = run.runId;
            if ~isfield(ctx,'run'), ctx.run = struct(); end
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
            if ~obj.ApplyingProposal && ~isempty(obj.Proposal), obj.cancelProposal(); end
            if strcmp(obj.RunPicker.Value,'draft')
                obj.Inspect.UserData = []; obj.Inspect.Enable = 'off'; obj.MoreRun.Enable = 'off';
                obj.UseRunPipeline.Enable = 'off'; obj.RunState.Text = 'Draft'; obj.updateGraph();
                obj.refreshLibrary(); return;
            end
            index = find(strcmp({obj.RunObjects.runId},obj.RunPicker.Value),1);
            if ~isempty(index), obj.selectRun(struct('Indices',[index 1])); end
        end
        function refreshSelectedRun(obj)
            obj.refreshProjectRuns();
            if ~strcmp(obj.RunPicker.Value,'draft'), obj.selectCompactRun(); obj.reviewRun(); end
        end
        function selectTemplate(obj)
            index = obj.Selector.Value;
            if ~obj.syncAdvanced(), return; end
            if obj.Template ~= obj.Templates{index}, obj.DefinitionContext = obj.DefinitionContext+1; end
            obj.Template = obj.Templates{index}; obj.RunPicker.Value = 'draft'; obj.refresh();
            obj.selectCompactView('pipeline');
            if ~isempty(obj.Template.path), obj.rememberPipeline(obj.Template.path); end
        end
        function selectStep(obj,event)
            if isempty(event.Indices), return; end
            obj.showParams(event.Indices(1,1));
        end
        function showParams(obj,index)
            obj.SelectedStep = index;
            nodes = obj.Draft.effectiveNodes(); node = nodes(index);
            obj.ModuleLabel.Text = sprintf('%s · %s',node.id,obj.field(node,'pkg',node.type));
            obj.ModuleLabel.Tooltip = obj.ModuleLabel.Text;
            obj.EditModuleButton.Enable = 'on'; obj.ChangeTypeButton.Enable = 'on';
            params = obj.field(node,'params',struct());
            [obj.BindingRows,staticKeys] = detecdivui.PipelineBindings.describe(node,nodes);
            bindings = cell(numel(obj.BindingRows),4);
            for k = 1:numel(obj.BindingRows)
                row = obj.BindingRows(k); scope = 'Pipeline';
                if obj.Draft.has(node.id,row.param), scope = 'This Run *'; end
                bindings(k,:) = {row.direction,row.resource,row.text,scope};
            end
            obj.BindingTable.Data = bindings; obj.BindingTable.UserData = obj.BindingRows;
            obj.SelectedBinding = 0; obj.BindingChoice.Enable = 'off'; obj.BindingScope.Enable = 'off';
            obj.BindingApply.Enable = 'off'; obj.BindingReset.Enable = 'off';
            obj.StaticButton.Enable = obj.onOff(~isempty(staticKeys));
            bindingKeys = {}; if ~isempty(obj.BindingRows), bindingKeys = {obj.BindingRows.param}; end
            data = cell(0,3);
            obj.ParamKeys = {}; obj.ParamSpecs = struct([]); obj.clearParamEditor();
            if isstruct(params) && isscalar(params)
                spec = classifierBinding.parameterSpecFromDefaults(params);
                keep = arrayfun(@(s)~ismember(s.param,bindingKeys) && ...
                    (~ismember(s.param,staticKeys) || obj.Draft.has(node.id,s.param)) && ...
                    strcmp(pipelineParamScope(node,s.param),'run'),spec);
                spec = spec(keep);
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
            if isfield(obj.Draft.Settings,'intentProposal'), settings.intentProposal = obj.Draft.Settings.intentProposal; end
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
            obj.updateViewIdentity();
            if isempty(obj.Template)
                obj.Graph.show(struct([]),struct([]),0); obj.CompactGraph.show(struct([]),struct([]),0);
                run = obj.selectedRun(); if ~isempty(run), obj.showRunGraph(run,obj.LastRunReview); end
                obj.renderProposal(); return;
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
            obj.renderProposal();
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
            obj.ParameterViews.SelectedTab = obj.RunParametersTab;
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
            if ~editable, obj.setStatus('Use Edit Module for this parameter'); end
        end
        function selectBinding(obj,event)
            if isempty(event.Indices), return; end
            index = event.Indices(1,1);
            if index < 1 || index > numel(obj.BindingRows), return; end
            obj.SelectedBinding = index; row = obj.BindingRows(index);
            choices = [{row.text},row.choices];
            isChoice = strcmp(detecdivui.RunDraft.valueKind(row.value),'choice');
            if isChoice, choices = [choices reshape(cellstr(string(row.value(1:end-1))),1,[])]; end
            choices = unique(choices,'stable');
            obj.BindingChoice.Items = choices; obj.BindingChoice.Value = row.text;
            editable = isChoice || (ischar(row.value) && (isempty(row.value) || isrow(row.value))) || ...
                (isstring(row.value) && isscalar(row.value)) || ...
                ((isnumeric(row.value) || islogical(row.value)) && isscalar(row.value) && ...
                (~isinteger(row.value) || abs(double(row.value)) <= flintmax));
            obj.BindingChoice.Enable = obj.onOff(editable); obj.BindingChoice.Tooltip = sprintf('%s · %s · %s',row.param,row.type,row.scope);
            obj.BindingScope.Items = {'Pipeline'};
            if strcmp(row.scope,'run'), obj.BindingScope.Items = {'Pipeline','This Run'}; end
            obj.BindingScope.Value = 'Pipeline'; obj.BindingScope.Enable = 'on';
            node = obj.Template.nodes(obj.SelectedStep);
            if obj.Draft.has(node.id,row.param), obj.BindingScope.Value = 'This Run'; end
            obj.BindingApply.Enable = obj.onOff(editable); obj.BindingReset.Enable = obj.onOff(obj.Draft.has(node.id,row.param));
            obj.ParameterViews.SelectedTab = obj.BindingsTab;
            if ~editable, obj.setStatus('Use Edit Module for this structured binding'); end
        end
        function applyBinding(obj)
            if obj.SelectedBinding < 1 || obj.SelectedBinding > numel(obj.BindingRows), return; end
            try
                row = obj.BindingRows(obj.SelectedBinding); node = obj.Template.nodes(obj.SelectedStep);
                assert(isempty(obj.AdvancedEditor) || ~isvalid(obj.AdvancedEditor), ...
                    'detecdivui:AdvancedParameters','Close the Pipeline Designer before editing bindings');
                assert(strcmp(obj.RunPicker.Value,'draft'),'detecdivui:BindingRun','Open Settings for the selected run before editing bindings');
                assert(strcmp(obj.BindingApply.Enable,'on'),'detecdivui:BindingType','Use Edit Module for this structured binding');
                unchanged = strcmp(obj.BindingChoice.Value,row.text);
                hasOverride = obj.Draft.has(node.id,row.param);
                if unchanged && hasOverride == strcmp(obj.BindingScope.Value,'This Run')
                    obj.setStatus('Binding unchanged'); return;
                end
                value = row.value;
                if ~unchanged, value = detecdivui.PipelineBindings.storeValue(obj.BindingChoice.Value); end
                if ~unchanged && strcmp(detecdivui.RunDraft.valueKind(row.value),'choice')
                    selected = value; options = row.value(1:end-1);
                    if isstring(row.value{end}), selected = string(selected); end
                    if ~any(strcmp(string(options),string(selected))), options{end+1} = selected; end
                    value = [reshape(options,1,[]) {selected}];
                end
                if ~unchanged && (isnumeric(row.value) || islogical(row.value))
                    value = jsondecode(char(value));
                    validateattributes(value,{'numeric','logical'},{'scalar','real','finite'});
                    if islogical(row.value), assert(islogical(value),'detecdivui:BindingLogical','Enter true or false.');
                    elseif isinteger(row.value)
                        validateattributes(value,{'numeric'},{'integer','>=',double(intmin(class(row.value))),'<=' ,double(intmax(class(row.value)))});
                    end
                    value = cast(value,class(row.value));
                end
                if strcmp(obj.BindingScope.Value,'This Run')
                    overrides = obj.Draft.Overrides; at = find(strcmp({overrides.id},node.id),1);
                    if isempty(at), overrides(end+1) = struct('id',node.id,'params',struct()); at = numel(overrides); end
                    overrides(at).params.(row.param) = value;
                    obj.Draft.import(obj.Draft.Settings,overrides); obj.invalidate(); obj.showParams(obj.SelectedStep);
                else
                    params = struct(); params.(row.param) = value; obj.modifyDefinition(node.id,params);
                end
                obj.setStatus('Binding updated');
            catch err, obj.setStatus(err.message);
            end
        end
        function resetBinding(obj)
            if obj.SelectedBinding < 1 || obj.SelectedBinding > numel(obj.BindingRows), return; end
            if ~strcmp(obj.RunPicker.Value,'draft'), obj.setStatus('Open Settings for this run before editing bindings'); return; end
            if ~isempty(obj.AdvancedEditor) && isvalid(obj.AdvancedEditor)
                obj.setStatus('Close the Pipeline Designer before editing bindings'); return;
            end
            node = obj.Template.nodes(obj.SelectedStep); row = obj.BindingRows(obj.SelectedBinding);
            obj.Draft.reset(node.id,row.param); obj.invalidate(); obj.showParams(obj.SelectedStep);
        end
        function token = parameterToken(obj,nodeId)
            project = []; if ~isempty(obj.Session), project = obj.Session.Project; end
            index = find(strcmp({obj.Template.nodes.id},nodeId),1);
            token = struct('template',obj.Template,'project',project,'revision',obj.DefinitionContext,'view',obj.RunPicker.Value, ...
                'node',jsonencode(obj.Template.nodes(index)));
        end
        function assertParameterToken(obj,token,nodeId)
            assert(isempty(obj.AdvancedEditor) || ~isvalid(obj.AdvancedEditor),'detecdivui:AdvancedParameters', ...
                'Close the Pipeline Designer before applying these parameters.');
            project = []; if ~isempty(obj.Session), project = obj.Session.Project; end
            index = []; if ~isempty(obj.Template), index = find(strcmp({obj.Template.nodes.id},nodeId),1); end
            assert(isequal(obj.Template,token.template) && isequal(project,token.project) && ...
                strcmp(obj.RunPicker.Value,token.view) && obj.DefinitionContext == token.revision && isscalar(index) && ...
                strcmp(jsonencode(obj.Template.nodes(index)),token.node),'detecdivui:StaticContext', ...
                'The pipeline or project changed. Open Static Parameters again.');
        end
        function modifyDefinition(obj,nodeId,params)
            settings = obj.Draft.Settings; overrides = obj.Draft.Overrides;
            copy = pipeline(); for key = properties(obj.Template)', copy.(key{1}) = obj.Template.(key{1}); end
            index = find(strcmp({copy.nodes.id},nodeId),1);
            for key = fieldnames(params)'
                name = key{1}; copy.nodes(index).params.(name) = params.(name);
                at = find(strcmp({overrides.id},nodeId),1);
                if ~isempty(at) && isfield(overrides(at).params,name), overrides(at).params = rmfield(overrides(at).params,name); end
            end
            at = find(cellfun(@(p)isequal(p,obj.Template),obj.Templates),1);
            obj.Templates{at} = copy; obj.Template = copy; obj.DefinitionContext = obj.DefinitionContext+1;
            project = []; if ~isempty(obj.Session), project = obj.Session.Project; end
            obj.Draft.select(project,copy); obj.Draft.import(settings,overrides);
            obj.refresh(); obj.selectDraft(); obj.showParams(index);
            obj.setStatus('Pipeline draft updated');
        end
        function applyParameter(obj)
            if obj.SelectedParam == 0, return; end
            try
                assert(strcmp(obj.RunPicker.Value,'draft') && (isempty(obj.AdvancedEditor) || ~isvalid(obj.AdvancedEditor)), ...
                    'detecdivui:RunParameterOwner','Close the Pipeline Designer and select a draft before editing run parameters.');
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
            if ~strcmp(obj.RunPicker.Value,'draft') || ~isempty(obj.AdvancedEditor) && isvalid(obj.AdvancedEditor)
                obj.setStatus('Close the Pipeline Designer and select a draft before editing run parameters'); return;
            end
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
            obj.repairCompactViews();
            selected = obj.RunPicker.Value;
            obj.RunObjects = []; obj.Runs.Data = cell(0,2); obj.Inspect.Enable = 'off';
            obj.RunPicker.ItemsData = {}; obj.RunPicker.Items = {'Draft'}; obj.RunPicker.ItemsData = {'draft'};
            obj.RunPicker.Value = 'draft'; obj.RunState.Text = 'Draft';
            obj.Inspect.UserData = [];
            obj.MoreRun.Enable = 'off'; obj.LastRunReview = struct();
            obj.RunReviews = {};
            obj.RunSummary.Data = cell(0,2); obj.RunNodes.Data = cell(0,3); obj.RunIssues.Data = cell(0,1);
            obj.RunGraph.show(struct([]),struct([]),0);
            obj.UseRunPipeline.Enable = 'off';
            if isgraphics(obj.CompactRuns), obj.CompactRuns.Data = cell(0,4); obj.CompactRunsTab.Title = 'Runs'; end
            if isempty(obj.Session) || isempty(obj.Session.Project)
                obj.RunsProject = []; obj.updateViewIdentity(); obj.notifyRunsChanged(); return;
            end
            changed = ~isequal(obj.RunsProject,obj.Session.Project); obj.RunsProject = obj.Session.Project;
            if changed, selected = 'draft'; end
            runs = detecdivui.ProjectRuns.cached(obj.Session.Project);
            runs = runs(isvalid(runs)); obj.RunObjects = runs;
            obj.RunReviews = cell(size(runs));
            data = cell(numel(runs),2);
            for k = 1:numel(runs), data(k,:) = {runs(k).runId,runs(k).status}; end
            obj.Runs.Data = data;
            history = cell(numel(runs),4);
            for k = 1:numel(runs), history(k,:) = {runs(k).runId,runs(k).status,detecdivui.ProjectRuns.pipelineName(runs(k)),runs(k).updatedAt}; end
            if isgraphics(obj.CompactRuns)
                obj.CompactRuns.Data = history; obj.CompactRunsTab.Title = sprintf('Runs (%d)',numel(runs));
            end
            if ~isempty(runs)
                obj.RunPicker.ItemsData = {}; obj.RunPicker.Items = [{'Draft'} {runs.runId}];
                obj.RunPicker.ItemsData = [{'draft'} {runs.runId}];
                if any(strcmp(obj.RunPicker.ItemsData,selected))
                    obj.RunPicker.Value = selected; obj.selectCompactRun();
                end
            end
            obj.updateViewIdentity(); obj.notifyRunsChanged();
        end
        function selectRun(obj,event)
            if isempty(event.Indices), return; end
            obj.SelectedBinding = 0; obj.BindingApply.Enable = 'off'; obj.BindingReset.Enable = 'off';
            obj.BindingChoice.Enable = 'off'; obj.BindingScope.Enable = 'off'; obj.clearParamEditor();
            if strcmp(obj.SettingsFigure.Visible,'on'), obj.Tabs.SelectedTab = ancestor(obj.Runs,'uitab'); end
            obj.Inspect.UserData = event.Indices(1,1); obj.Inspect.Enable = 'on';
            obj.UseRunPipeline.Enable = 'on';
            obj.RunPicker.Value = obj.RunObjects(obj.Inspect.UserData).runId;
            obj.updateViewIdentity(); obj.refreshLibrary();
            if ~isempty(obj.RunReviews{obj.Inspect.UserData})
                obj.MoreRun.Enable = 'on'; obj.showRunReview(obj.RunReviews{obj.Inspect.UserData}); return;
            end
            obj.MoreRun.Enable = 'on'; obj.LastRunReview = struct();
            obj.RunNodes.Data = cell(0,3); obj.RunIssues.Data = cell(0,1);
            run = obj.RunObjects(obj.Inspect.UserData);
            obj.RunPicker.Tooltip = [run.runId ' · ' detecdivui.ProjectRuns.pipelineName(run)];
            obj.RunState.Text = run.status;
            obj.showRunGraph(run,struct());
            obj.RunSummary.Data = {'Run',run.runId;'Status',run.status;'Created',run.createdAt; ...
                'Updated',run.updatedAt;'Pipeline',detecdivui.ProjectRuns.pipelineName(run); ...
                'Pipeline source',run.templatePath;'Folder',run.path};
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
                obj.updateViewIdentity();
            end
        end
        function updateViewIdentity(obj)
            if ~isgraphics(obj.ViewName), return; end
            run = obj.selectedRun();
            ready = ~isempty(obj.Template) || ~isempty(run);
            hasProject = ~isempty(obj.Session) && ~isempty(obj.Session.Project);
            obj.SettingsButton.Enable = obj.onOff(ready);
            obj.NewRun.Enable = obj.onOff(ready && hasProject);
            obj.SaveRun.Enable = obj.onOff(~isempty(obj.Template) && hasProject);
            menu = findall(obj.ViewName.ContextMenu,'Tag','pipeline-use-run-menu');
            menu.Enable = obj.onOff(~isempty(run));
            if isempty(run)
                name = 'Pipeline'; if ~isempty(obj.Template), name = char(string(obj.Template.strid)); end
                obj.ViewName.Text = name; obj.ViewName.Tooltip = name;
                obj.SettingsButton.Tooltip = 'Edit the selected pipeline draft and run settings';
            else
                obj.ViewName.Text = [run.runId ' · ' detecdivui.ProjectRuns.pipelineName(run)];
                obj.ViewName.Tooltip = ['Saved run · ' obj.ViewName.Text ' · ' char(string(obj.Session.Project.io.file))];
                obj.SettingsButton.Tooltip = 'Configure a new run from this saved configuration';
            end
            if ~isempty(obj.Session) && ~isempty(obj.Session.Project)
                obj.NewRun.Tooltip = ['New run for ' char(string(obj.Session.Project.io.file))];
            end
        end
        function notifyRunsChanged(obj)
            project = []; if ~isempty(obj.Session), project = obj.Session.Project; end
            detecdivui.Callback.call(obj.OnRunsChanged,project);
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
        function run = selectedRun(obj)
            run = [];
            if strcmp(obj.RunPicker.Value,'draft') || isempty(obj.RunObjects), return; end
            index = find(strcmp({obj.RunObjects.runId},obj.RunPicker.Value),1);
            if ~isempty(index) && isvalid(obj.RunObjects(index)), run = obj.RunObjects(index); end
        end
        function template = templateForRun(obj,run)
            signature = '';
            if isfield(run.ctx,'pipelineSpec'), signature = jsonencode(run.ctx.pipelineSpec); end
            for k = 1:numel(obj.RunTemplates)
                record = obj.RunTemplates(k);
                if isequal(record.project,obj.Session.Project) && isequal(record.run,run) && ...
                        isvalid(record.template) && strcmp(record.signature,signature)
                    template = record.template; return;
                end
            end
            template = detecdivui.ProjectRuns.snapshot(run);
            obj.RunTemplates(end+1) = struct('project',obj.Session.Project,'run',run,'template',template,'signature',signature);
        end
        function endCheck(obj)
            obj.Busy = false;
            obj.Validate.Enable = obj.onOff(~isempty(obj.Template));
            obj.DryRun.Enable = obj.Validate.Enable;
        end
        function setStatus(obj,message)
            obj.Status.Text = message; obj.Status.Tooltip = message;
            detecdivui.Callback.call(obj.OnStatus,message);
        end
        function draftNotice(obj)
            if obj.Draft.takeDiscarded() > 0, obj.setStatus('Run settings reset after template changes'); end
        end
    end
    methods (Static, Access = private)
        function name = pipelineFileLabel(path)
            [folder,name,extension] = fileparts(char(path));
            if strcmpi([name extension],'pipeline.json'), [~,name] = fileparts(folder);
            else, name = [name extension]; end
        end
        function name = disambiguateLibraryName(name,path)
            folder = fileparts(char(path)); [parent,leaf] = fileparts(folder); [~,label] = fileparts(parent);
            if isempty(label), label = leaf; end
            name = sprintf('%s (%s)',name,label);
        end
        function matches = matchesRawSource(project,position,raw)
            matches = false;
            if isempty(raw) || position < 1 || position > numel(project.fov), return; end
            root = regexprep(strrep(char(string(raw)),'\','/'),'/+$','');
            paths = cellstr(string(project.fov(position).srcpath));
            for k = 1:numel(paths)
                path = regexprep(strrep(paths{k},'\','/'),'/+$','');
                if strcmpi(path,root) || startsWith(lower(path),[lower(root) '/']), matches = true; return; end
            end
        end
        function settings = freshPlanSettings(settings)
            settings.runId = '';
            if ~isfield(settings,'extraContext'), return; end
            extra = settings.extraContext;
            invocation = {'runId','path','runPath','eventLogPath','cancelTokenPath','progressJsonPath','jobId','hubJobId','job'};
            for key = {'run','io','store','hub'}
                name = key{1};
                if isfield(extra,name) && isstruct(extra.(name))
                    extra.(name) = rmfield(extra.(name),intersect(fieldnames(extra.(name)),invocation));
                end
            end
            extra = rmfield(extra,intersect(fieldnames(extra),{'runId','cancel','progress','progressDlg','progressCallback'}));
            settings.extraContext = extra;
        end
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
