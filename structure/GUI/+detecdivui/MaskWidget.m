classdef MaskWidget < handle
    % Contextual mask editor on the shared Image viewport.
    properties (SetAccess = private)
        Drafts = {}
        Progress
        Active = false
    end
    properties (Access = private)
        Viewer
        Projects = {}
        ContextROI = []
        Target
        Provider
        Label
        Tool
        Shape
        Radius
        Overwrite
        Status
        Outline = []
        Stroke = []
        Callbacks = {}
        AxesState = {}
        ResolveFigure = []
        ResolveQueue = {}
        ResolveStatus
        ResolveProgress
        OnResolved = []
        ResolveGeneration = 0
        ResolveBusy = false
        FillKey = 'k'
        AlphaKeys = {'g','h'}
    end
    methods
        function obj = MaskWidget(parent,viewer)
            obj.Viewer = viewer;
            [~,keys,prefs] = detecdiv_prefs_get_shortcuts();
            if ~isempty(keys{4}), obj.FillKey = lower(keys{4}{1}); end
            if numel(keys{5}) == 2, obj.AlphaKeys = cellfun(@lower,keys{5},'UniformOutput',false); end
            radius = 7;
            if isfield(prefs,'painting_normal_brush_radius'), radius = prefs.painting_normal_brush_radius; end
            radius = min(256,max(1,round(double(radius))));
            grid = uigridlayout(parent,[12 1]); grid.Padding = [6 6 6 6];
            grid.RowHeight = {24,28,28,28,28,28,28,28,24,'1x',28,24};
            header = uigridlayout(grid,[1 2]); header.Padding = [0 0 0 0]; header.ColumnWidth = {'1x',60};
            obj.Target = uilabel(header,'Text','','Interpreter','none','Tag','mask-target');
            uibutton(header,'Text','Done','Tag','mask-done','Tooltip','Close the assistant and keep mask drafts', ...
                'ButtonPushedFcn',@(~,~)viewer.closeContourTool());
            obj.Provider = uidropdown(grid,'Items',{'—'},'Tag','mask-provider', ...
                'Tooltip','Authoritative mask provider resolved by Score', ...
                'ValueChangedFcn',@(~,~)obj.providerChanged());
            row = uigridlayout(grid,[1 3]); row.Padding = [0 0 0 0]; row.ColumnWidth = {45,'1x',70};
            uilabel(row,'Text','Label');
            obj.Label = uieditfield(row,'numeric','Value',0,'Limits',[0 65535],'RoundFractionalValues','on', ...
                'Tag','mask-label','Tooltip','Mask label, distinct from track ID', ...
                'ValueChangedFcn',@(~,~)obj.showSelection());
            uibutton(row,'Text','New ID','ButtonPushedFcn',@(~,~)obj.newLabel());
            obj.Tool = uidropdown(grid,'Items',{'Select','Brush','Eraser'},'Tag','mask-tool', ...
                'Tooltip','Click to select; drag to paint; Shift temporarily erases');
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x',75};
            obj.Shape = uidropdown(row,'Items',{'Polygon','Freehand'},'Tag','mask-shape');
            uibutton(row,'Text','Draw','Tag','mask-draw','Tooltip','Double-click to finish; Escape cancels', ...
                'ButtonPushedFcn',@(~,~)obj.draw(false));
            row = uigridlayout(grid,[1 3]); row.Padding = [0 0 0 0];
            uibutton(row,'Text','Edit','Tag','mask-edit','Tooltip','Move contour vertices; double-click to apply', ...
                'ButtonPushedFcn',@(~,~)obj.draw(true));
            uibutton(row,'Text','Fill Holes','Tag','mask-fill','ButtonPushedFcn',@(~,~)obj.action('fill'));
            uibutton(row,'Text','Delete','Tag','mask-delete','Tooltip','Delete selected label on this frame only', ...
                'ButtonPushedFcn',@(~,~)obj.action('delete'));
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0]; row.ColumnWidth = {45,'1x'};
            uilabel(row,'Text','Radius');
            obj.Radius = uieditfield(row,'numeric','Value',radius,'Limits',[1 256], ...
                'RoundFractionalValues','on','Tag','mask-radius','Tooltip','Brush radius in source pixels');
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0];
            uibutton(row,'Text','Undo','Tag','mask-undo','ButtonPushedFcn',@(~,~)obj.action('undo'));
            uibutton(row,'Text','Redo','Tag','mask-redo','ButtonPushedFcn',@(~,~)obj.action('redo'));
            obj.Overwrite = uicheckbox(grid,'Text','Overwrite other labels','Value',false,'Tag','mask-overwrite');
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0];
            row.Layout.Row = 11;
            uibutton(row,'Text','Save Masks','Tag','mask-save','Tooltip','Save masks, cell model and annotation lifecycle data', ...
                'ButtonPushedFcn',@(~,~)obj.action('save'));
            uibutton(row,'Text','Discard','Tag','mask-discard','Tooltip','Discard this provider draft', ...
                'ButtonPushedFcn',@(~,~)obj.action('discard'));
            obj.Status = uilabel(grid,'Text','Ready','Interpreter','none','Tag','mask-status');
            obj.Status.Layout.Row = 12;
            obj.Progress = detecdivui.Progress(grid,obj.Status,'mask-progress');
            grid.RowHeight = {24,28,28,28,28,28,28,28,24,'1x',28,24};
        end
        function keys = shortcuts(obj)
            keys = [{'delete','escape','uparrow','downarrow',obj.FillKey},obj.AlphaKeys];
        end
        function key(obj,key,ctrl)
            if ~obj.Active, return; end
            if ctrl
                if strcmp(key,'z'), obj.action('undo'); elseif strcmp(key,'y'), obj.action('redo'); end
            elseif strcmp(key,'delete'), obj.action('delete');
            elseif strcmp(key,'escape'), obj.cancelStroke(); obj.Tool.Value = 'Select';
            elseif strcmp(key,obj.FillKey), obj.action('fill');
            elseif any(strcmp(key,[obj.AlphaKeys {'uparrow','downarrow'}]))
                up = strcmp(key,obj.AlphaKeys{2}) || strcmp(key,'uparrow');
                obj.Viewer.contourOpacity(.1*(2*up-1),obj.Provider.Value);
            end
        end
        function setActive(obj,active)
            entering = active && ~obj.Active;
            selected = [];
            if entering, selected = obj.Viewer.selectedAnnotation(); end
            if active && ~obj.Active
                fig = obj.Viewer.Figure;
                obj.Callbacks = {fig.WindowButtonDownFcn,fig.WindowButtonMotionFcn,fig.WindowButtonUpFcn,fig.Pointer};
                fig.WindowButtonDownFcn = @(~,~)obj.mouseDown();
                fig.WindowButtonMotionFcn = @(~,~)obj.mouseMove();
                fig.WindowButtonUpFcn = @(~,~)obj.mouseUp();
            elseif ~active && obj.Active
                obj.cancelStroke(); fig = obj.Viewer.Figure;
                liveFigure = isvalid(fig);
                if liveFigure
                    fig.WindowButtonDownFcn = obj.Callbacks{1}; fig.WindowButtonMotionFcn = obj.Callbacks{2};
                    fig.WindowButtonUpFcn = obj.Callbacks{3}; fig.Pointer = obj.Callbacks{4};
                end
                obj.clearOutline(); obj.Callbacks = {};
                for k = 1:numel(obj.AxesState)
                    state = obj.AxesState{k};
                    if liveFigure && isvalid(state.axes)
                        state.axes.Interactions = state.interactions; state.axes.Toolbar.Visible = state.toolbar;
                    end
                end
                obj.AxesState = {};
            end
            obj.Active = logical(active);
            if obj.Active, obj.refresh(); end
            if entering && ~isempty(selected)
                if any(strcmp(obj.Provider.Items,selected.channel)), obj.Provider.Value = selected.channel; end
                if strcmp(obj.current().Channel,selected.channel)
                    obj.Label.Value = selected.label; obj.showSelection();
                end
            end
        end
        function onRender(obj)
            if ~obj.Active, return; end
            obj.cancelStroke();
            try
                obj.refresh();
            catch err, obj.Viewer.closeContourTool(); obj.status(err.message);
            end
        end
        function saveAll(obj)
            scope = obj.Progress.begin('Saving annotation edits...'); %#ok<NASGU>
            try
                for k = 1:numel(obj.Drafts)
                    if obj.Drafts{k}.Dirty, obj.assertEditable(obj.Drafts{k},false); end
                end
                for k = 1:numel(obj.Drafts)
                    if obj.Drafts{k}.Dirty, obj.Drafts{k}.save(); obj.followSave(obj.Drafts{k}); end
                end
                obj.Viewer.contourChanged(); obj.status('Annotation edits saved');
            catch err, obj.status(err.message);
            end
        end
        function draft = current(obj)
            c = obj.Viewer.contourContext(); draft = [];
            if isempty(c.roi), return; end
            draft = obj.draftFor(c.roi,obj.Provider.Value,c.project);
        end
        function selectProvider(obj,channel,label)
            if nargin < 3, label = 0; end
            assert(obj.Active,'detecdivui:MaskInactive','Open the object editor first.');
            validateattributes(label,{'numeric'},{'real','scalar','integer','nonnegative','<=',65535});
            c = obj.Viewer.contourContext();
            assert(~isempty(c.roi) && any(strcmp(c.masks,channel)), ...
                'detecdivui:MaskProvider','Load the selected mask layer first.');
            obj.cancelStroke(); obj.refresh();
            obj.Provider.Value = char(string(channel)); obj.Label.Value = double(label);
            obj.Tool.Value = 'Select'; obj.refresh();
        end
        function selectObject(obj,label)
            obj.selectProvider(obj.Provider.Value,label);
        end
        function draft = draftFor(obj,source,channel,project)
            [provider,~,~] = score_resolveMaskProvider(source,channel);
            for k = 1:numel(obj.Drafts)
                candidate = obj.Drafts{k};
                if isequal(candidate.Source,source) && strcmp(candidate.Channel,provider)
                    if ~candidate.Dirty && ~candidate.matchesSource()
                        candidate = detecdivui.MaskDraft(source,channel); obj.Drafts{k} = candidate;
                    end
                    draft = candidate; return;
                end
            end
            draft = detecdivui.MaskDraft(source,channel);
            obj.Drafts{end+1} = draft; obj.Projects{end+1} = project;
        end
        function saved(obj,draft)
            obj.followSave(draft); obj.Viewer.contourChanged();
        end
        function assertEditable(obj,draft,modelMutation)
            assert(obj.Viewer.annotationEditingAllowed(draft.Source),'detecdivui:ClassifierReview', ...
                'Switch this classifier to Edit before modifying or saving annotations.');
            for k = 1:numel(obj.Drafts)
                other = obj.Drafts{k};
                if other == draft || ~isequal(other.Source,draft.Source) || ~other.Dirty, continue; end
                assert(~modelMutation && ~other.hasModelEdits(),'detecdivui:AnnotationProviderBusy', ...
                    'Save or discard pending edits on provider "%s" before editing this provider. The ROI shares one cell model.',other.Channel);
            end
        end
        function plane = override(obj,session,index,frame,plane)
            if session.Zone == 0, return; end
            source = session.Project.fov(session.Position).roi(session.Zone);
            [names,~,~] = session.dimensions();
            if ~detecdivui.MaskDraft.isLabel(source,names{index}), return; end
            for k = 1:numel(obj.Drafts)
                d = obj.Drafts{k};
                if ~d.Dirty || ~isequal(d.Source,source), continue; end
                [provider,~,~] = score_resolveMaskProvider(source,names{index});
                if strcmp(provider,d.Channel), plane = d.read(frame); return; end
            end
        end
        function yes = dirty(obj,source)
            yes = false;
            for k = 1:numel(obj.Drafts)
                d = obj.Drafts{k};
                if d.Dirty && (nargin < 2 || isequal(d.Source,source)), yes = true; return; end
            end
        end
        function ok = resolve(obj,project,callback)
            if nargin < 2, project = []; end
            if nargin < 3, callback = []; end
            ok = false;
            if ~isempty(obj.ResolveFigure) && isvalid(obj.ResolveFigure), return; end
            obj.ResolveQueue = {};
            for k = 1:numel(obj.Drafts)
                d = obj.Drafts{k};
                if d.Dirty && (isempty(project) || isequal(obj.Projects{k},project))
                    obj.ResolveQueue{end+1} = d;
                end
            end
            if isempty(obj.ResolveQueue), ok = true; return; end
            obj.OnResolved = callback; obj.nextResolution();
        end
        function forgetProject(obj,project)
            keep = ~cellfun(@(p)isequal(p,project),obj.Projects);
            if any(cellfun(@(d)isequal(d.Source,obj.ContextROI),obj.Drafts(~keep))), obj.ContextROI = []; end
            obj.Drafts = obj.Drafts(keep); obj.Projects = obj.Projects(keep);
        end
        function recover(obj)
            for k = 1:numel(obj.Drafts)
                if ~obj.Drafts{k}.Dirty, continue; end
                folder = fullfile(prefdir,'DetecDivUI','mask-recovery');
                if ~isfolder(folder), mkdir(folder); end
                file = fullfile(folder,[char(matlab.lang.internal.uuid) '.mat']);
                draft = obj.Drafts{k}.recovery();
                save(file,'draft','-v7.3');
                warning('detecdivui:MaskRecovery','Unsaved annotation draft recovered to %s',file);
            end
        end
        function action(obj,action)
            try
                obj.cancelStroke();
                message = 'Editing masks...';
                if strcmp(action,'save'), message = 'Saving masks and annotation data...'; end
                scope = obj.Progress.begin(message); %#ok<NASGU>
                d = obj.current(); if isempty(d), return; end
                if ~strcmp(action,'discard')
                    obj.assertEditable(d,any(strcmp(action,{'undo','redo'})) && d.historyTouchesModel(action));
                end
                c = obj.Viewer.contourContext();
                switch action
                    case 'undo', d.undo();
                    case 'redo', d.redo();
                    case 'save'
                        d.save();
                        obj.followSave(d);
                    case 'discard', d.discard();
                    otherwise, d.edit(c.frame,action,[],obj.Label.Value,obj.Radius.Value,obj.Overwrite.Value);
                end
                obj.Viewer.contourChanged(); obj.refresh();
            catch err, obj.status(err.message);
            end
        end
        function select(obj,x,y)
            d = obj.current(); c = obj.Viewer.contourContext();
            mask = d.read(c.frame); x = round(x); y = round(y);
            if x < 1 || y < 1 || x > size(mask,2) || y > size(mask,1), return; end
            obj.Label.Value = double(mask(y,x)); obj.showSelection();
        end
        function draw(obj,editing)
            shape = [];
            try
                d = obj.current(); c = obj.Viewer.contourContext(); ax = obj.Viewer.roiAxes();
                obj.assertEditable(d,false);
                mask = d.read(c.frame); holes = false(size(mask));
                if obj.Label.Value == 0, obj.newLabel(); end
                label = obj.Label.Value; args = {};
                if editing
                    selected = mask == label; components = bwconncomp(selected);
                    assert(components.NumObjects == 1,'detecdivui:MaskComponents', ...
                        'Select one connected object. Use Brush for objects with multiple components.');
                    b = bwboundaries(selected,'noholes'); args = {'Position',fliplr(b{1})};
                    holes = imfill(selected,'holes') & ~selected;
                end
                guard = obj.Viewer.beginROIGesture(); %#ok<NASGU>
                if strcmp(obj.Shape.Value,'Freehand'), shape = drawfreehand(ax,args{:},'Color',[1 .7 .1]);
                else, shape = drawpolygon(ax,args{:},'Color',[1 .7 .1]); end
                if isempty(shape) || ~isvalid(shape), return; end
                if editing, wait(shape); end
                if ~isvalid(shape), return; end
                afterContext = obj.Viewer.contourContext();
                assert(isequal(c.roi,afterContext.roi) && c.frame == afterContext.frame, ...
                    'detecdivui:MaskContext','View changed; contour was not applied.');
                coverage = createMask(shape) & ~holes; delete(shape); shape = [];
                action = 'draw'; if editing, action = 'replace'; end
                d.edit(c.frame,action,coverage,label,obj.Radius.Value,obj.Overwrite.Value);
                clear guard; obj.Viewer.contourChanged();
            catch err, obj.status(err.message);
            end
            if ~isempty(shape) && isvalid(shape), delete(shape); end
        end
        function delete(obj)
            obj.deleteResolution();
            obj.setActive(false); obj.clearOutline();
        end
    end
    methods (Access = private)
        function nextResolution(obj)
            obj.deleteResolution();
            if isempty(obj.ResolveQueue)
                callback = obj.OnResolved; obj.OnResolved = [];
                obj.Viewer.contourChanged(); detecdivui.Callback.call(callback); return;
            end
            token = obj.ResolveGeneration;
            d = obj.ResolveQueue{1};
            obj.ResolveFigure = uifigure('Name','Unsaved Annotations','Tag','mask-close-dialog', ...
                'Position',[300 300 460 160],'WindowStyle','modal', ...
                'CloseRequestFcn',@(~,~)obj.resolveChoice('Cancel',token));
            grid = uigridlayout(obj.ResolveFigure,[3 1]); grid.RowHeight = {44,24,28};
            message = sprintf('Unsaved annotations: %s / %s',d.Source.id,d.Channel);
            uilabel(grid,'Text',message,'Tooltip',message,'Interpreter','none');
            obj.ResolveStatus = uilabel(grid,'Text','','Interpreter','none','Tag','mask-close-status');
            buttons = uigridlayout(grid,[1 3]); buttons.Padding = [0 0 0 0];
            for choice = {'Save','Discard','Cancel'}
                action = choice{1};
                uibutton(buttons,'Text',action,'Tag',['mask-close-' lower(action)], ...
                    'ButtonPushedFcn',@(~,~)obj.resolveChoice(action,token));
            end
            obj.ResolveProgress = detecdivui.Progress(grid,obj.ResolveStatus,'mask-close-progress');
        end
        function resolveChoice(obj,choice,token)
            if token ~= obj.ResolveGeneration || obj.ResolveBusy || isempty(obj.ResolveQueue), return; end
            if strcmp(choice,'Cancel')
                obj.ResolveQueue = {}; obj.OnResolved = []; obj.deleteResolution(); return;
            end
            obj.ResolveBusy = true;
            try
                d = obj.ResolveQueue{1};
                scope = obj.ResolveProgress.begin('Saving annotations...'); %#ok<NASGU>
                if strcmp(choice,'Save'), obj.assertEditable(d,false); d.save(); obj.followSave(d); else, d.discard(); end
                clear scope; obj.ResolveBusy = false;
                obj.ResolveQueue(1) = []; obj.nextResolution();
            catch err
                obj.ResolveBusy = false; obj.ResolveStatus.Text = err.message; obj.ResolveStatus.Tooltip = err.message;
            end
        end
        function deleteResolution(obj)
            obj.ResolveGeneration = obj.ResolveGeneration+1;
            if ~isempty(obj.ResolveFigure) && isvalid(obj.ResolveFigure), delete(obj.ResolveFigure); end
            obj.ResolveFigure = [];
        end
        function refresh(obj)
            axes = findall(obj.Viewer.Figure,'Type','axes');
            for ax = reshape(axes,1,[])
                if ~any(cellfun(@(state)isequal(state.axes,ax),obj.AxesState))
                    obj.AxesState{end+1} = struct('axes',ax,'interactions',ax.Interactions,'toolbar',ax.Toolbar.Visible);
                    ax.Interactions = []; ax.Toolbar.Visible = 'off';
                end
            end
            c = obj.Viewer.contourContext();
            if isempty(c.roi) || isempty(c.masks), obj.Viewer.closeContourTool(); return; end
            if ~isequal(obj.ContextROI,c.roi) || ~any(strcmp(obj.Provider.Value,c.masks))
                obj.ContextROI = c.roi; obj.Provider.Items = c.masks; obj.Provider.Value = c.masks{1};
                obj.Label.Value = 0;
            end
            d = obj.current(); marker = ''; if d.Dirty, marker = ' *'; end
            obj.Target.Text = sprintf('%s · Frame %d%s',c.roi.id,c.frame,marker);
            if d.SaveFailed, obj.status(['Save incomplete: ' d.LastError]);
            elseif d.Dirty, obj.status('Unsaved annotations'); else, obj.status('Ready'); end
            obj.showSelection();
        end
        function providerChanged(obj)
            obj.cancelStroke(); obj.Label.Value = 0; obj.refresh();
        end
        function newLabel(obj)
            d = obj.current(); value = double(max(d.Masks(:)))+1;
            assert(value <= 65535,'detecdivui:MaskLabels','No free uint16 label remains.');
            obj.Label.Value = value;
        end
        function showSelection(obj)
            obj.clearOutline(); if ~obj.Active, return; end
            d = obj.current(); c = obj.Viewer.contourContext(); mask = d.read(c.frame);
            label = obj.Label.Value;
            if label == 0 || ~any(mask(:) == label), label = 0; end
            obj.Viewer.rememberAnnotation(c.roi,d.Channel,c.frame,label,'Contours');
            if label == 0, return; end
            b = bwboundaries(mask == label,'noholes');
            ax = obj.Viewer.roiAxes(); hold(ax,'on');
            for k = 1:numel(b)
                obj.Outline(end+1) = plot(ax,b{k}(:,2),b{k}(:,1),'Color',[1 .75 0], ...
                    'LineWidth',2,'HitTest','off','PickableParts','none','Tag','mask-selection');
            end
            hold(ax,'off');
        end
        function clearOutline(obj)
            delete(obj.Outline(isgraphics(obj.Outline))); obj.Outline = gobjects(0);
        end
        function mouseDown(obj)
            if ~obj.Active || obj.Viewer.contourGestureActive(), return; end
            try
                obj.cancelStroke(); ax = ancestor(hittest(obj.Viewer.Figure),'axes');
                if isempty(ax) || ~isequal(ancestor(ax,'figure'),obj.Viewer.Figure), return; end
                point = ax.CurrentPoint(1,1:2); d = obj.current(); c = obj.Viewer.contourContext();
                if strcmp(obj.Tool.Value,'Select'), obj.select(point(1),point(2)); return; end
                obj.assertEditable(d,false);
                if ~strcmp(obj.Viewer.Figure.SelectionType,'normal'), return; end
                erase = strcmp(obj.Tool.Value,'Eraser') || any(strcmp(obj.Viewer.Figure.CurrentModifier,'shift'));
                if obj.Label.Value == 0 && ~erase
                    mask = d.read(c.frame); x = round(point(1)); y = round(point(2));
                    if x >= 1 && x <= size(mask,2) && y >= 1 && y <= size(mask,1) && mask(y,x) > 0
                        obj.Label.Value = double(mask(y,x));
                    else
                        obj.newLabel();
                    end
                end
                label = obj.Label.Value; if erase, label = 0; end
                obj.Stroke = struct('draft',d,'roi',c.roi,'frame',c.frame,'points',point,'label',label,'axes',ax,'line',[]);
                obj.Viewer.Figure.Pointer = 'cross';
            catch err, obj.cancelStroke(); obj.status(err.message);
            end
        end
        function mouseMove(obj)
            if isempty(obj.Stroke), return; end
            ax = obj.Stroke.axes;
            if ~isvalid(ax), obj.cancelStroke(); return; end
            point = ax.CurrentPoint(1,1:2); previous = obj.Stroke.points(end,:);
            count = max(2,ceil(norm(point-previous))+1);
            if count > 10000, return; end
            points = [linspace(previous(1),point(1),count).' linspace(previous(2),point(2),count).'];
            obj.Stroke.points = [obj.Stroke.points; points(2:end,:)];
            if isempty(obj.Stroke.line) || ~isgraphics(obj.Stroke.line)
                hold(ax,'on'); obj.Stroke.line = plot(ax,obj.Stroke.points(:,1),obj.Stroke.points(:,2), ...
                    'Color',[1 .6 .1],'LineWidth',2,'HitTest','off','Tag','mask-stroke'); hold(ax,'off');
            else
                obj.Stroke.line.XData = obj.Stroke.points(:,1); obj.Stroke.line.YData = obj.Stroke.points(:,2);
            end
        end
        function mouseUp(obj)
            if isempty(obj.Stroke), return; end
            stroke = obj.Stroke; obj.cancelStroke(); c = obj.Viewer.contourContext();
            if ~isequal(c.roi,stroke.roi) || c.frame ~= stroke.frame, return; end
            try
                stroke.draft.edit(stroke.frame,'paint',stroke.points,stroke.label,obj.Radius.Value,obj.Overwrite.Value);
                obj.Viewer.contourChanged();
            catch err, obj.status(err.message);
            end
        end
        function cancelStroke(obj)
            if ~isempty(obj.Stroke) && ~isempty(obj.Stroke.line) && isgraphics(obj.Stroke.line), delete(obj.Stroke.line); end
            obj.Stroke = []; if isvalid(obj.Viewer.Figure), obj.Viewer.Figure.Pointer = 'arrow'; end
        end
        function status(obj,message)
            obj.Status.Text = message; obj.Status.Tooltip = message;
        end
        function followSave(obj,draft)
            for k = 1:numel(obj.Drafts), obj.Drafts{k}.followSave(draft); end
        end
    end
end
