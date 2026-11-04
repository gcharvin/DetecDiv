classdef TracksWidget < handle
    % Contextual track identity/parentage editing on the shared annotation draft.
    properties (SetAccess = private)
        Active = false
        Progress
    end
    properties (Access = private)
        Viewer
        Target
        Provider
        Family
        Info
        InfoValues = gobjects(0)
        Destination
        Scope
        Status
        ImportButton
        ROI = []
        Project = []
        SelectedTrack = uint64(0)
        SelectedLabel = 0
        SelectedFrame = 0
        Pick = []
        DownCallback = []
        AxesState = {}
        Overlays = gobjects(0)
    end
    methods
        function obj = TracksWidget(parent,viewer)
            obj.Viewer = viewer;
            grid = uigridlayout(parent,[12 1]); grid.Padding = [6 6 6 6];
            grid.RowSpacing = 6; grid.Scrollable = 'on';
            grid.RowHeight = {24,28,28,130,28,28,28,28,28,94,28,24};
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x',60};
            obj.Target = uilabel(row,'Text','','Interpreter','none','Tag','tracks-target');
            uibutton(row,'Text','Done','Tag','tracks-done','Tooltip','Close Tracks and retain the annotation draft', ...
                'ButtonPushedFcn',@(~,~)viewer.closeTracksTool());
            obj.Provider = uidropdown(grid,'Items',{'—'},'Tag','tracks-provider', ...
                'Tooltip','Authoritative mask provider','ValueChangedFcn',@(~,~)obj.resetContext());
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x',100};
            obj.Family = uidropdown(row,'Items',{'—'},'ItemsData',0,'Tag','tracks-family', ...
                'Tooltip','Object family','ValueChangedFcn',@(~,~)obj.resetSelection());
            obj.ImportButton = uibutton(row,'Text','Import Legacy','Tag','tracks-import', ...
                'Tooltip','Explicitly import existing mask IDs as track IDs with cellModel.fromLegacy; Save Edits persists it', ...
                'ButtonPushedFcn',@(~,~)obj.action('import'));
            obj.Info = uipanel(grid,'BorderType','none','Tag','tracks-info');
            properties = uigridlayout(obj.Info,[6 2]); properties.Padding = [0 0 0 0];
            properties.RowHeight = repmat({20},1,6); properties.RowSpacing = 2; properties.ColumnWidth = {50,'1x'};
            for name = {'Label','Track','Parent','Event','First','Last'}
                uilabel(properties,'Text',name{1});
                obj.InfoValues(end+1) = uieditfield(properties,'text','Value','—','Editable','off', ...
                    'Tag',['tracks-info-' lower(name{1})]);
            end
            row = uigridlayout(grid,[1 3]); row.Padding = [0 0 0 0]; row.ColumnWidth = {42,'1x',65};
            uilabel(row,'Text','Target');
            obj.Destination = uieditfield(row,'text','Value','1','Tag','tracks-destination', ...
                'Tooltip','Destination track ID or parent track ID; exact decimal uint64', ...
                'ValueChangedFcn',@(~,~)obj.cancelLink());
            uibutton(row,'Text','Pick','Tag','tracks-pick','Tooltip','Select the source object, then pick its destination track on any frame', ...
                'ButtonPushedFcn',@(~,~)obj.beginPick('assign'));
            obj.Scope = uidropdown(grid,'Items',{'This frame','From this frame','Whole track'}, ...
                'ItemsData',{'frame','to-last','all'},'Tag','tracks-scope', ...
                'Tooltip','Scope for Assign / New Track / Pick Track','ValueChangedFcn',@(~,~)obj.cancelLink());
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0];
            uibutton(row,'Text','Assign','Tag','tracks-assign','ButtonPushedFcn',@(~,~)obj.action('assign'));
            uibutton(row,'Text','New Track','Tag','tracks-new','ButtonPushedFcn',@(~,~)obj.action('new'));
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0];
            uibutton(row,'Text','Set Parent','Tag','tracks-parent','Tooltip','Set the selected child track parent from Destination; canonical birth frame applies', ...
                'ButtonPushedFcn',@(~,~)obj.action('parent'));
            uibutton(row,'Text','Pick Parent','Tag','tracks-pick-parent','Tooltip','Select the child, then pick a parent on the image; Escape cancels', ...
                'ButtonPushedFcn',@(~,~)obj.beginPick('parent'));
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0];
            uibutton(row,'Text','Remove Parent','Tag','tracks-unparent','ButtonPushedFcn',@(~,~)obj.action('unparent'));
            uibutton(row,'Text','Swap IDs (all)','Tag','tracks-swap','Tooltip','Swap both complete track identities, including links and censoring, across all frames', ...
                'ButtonPushedFcn',@(~,~)obj.action('swap'));
            tools = uigridlayout(grid,[3 2]); tools.Padding = [0 0 0 0];
            tools.RowHeight = {28,28,28};
            uibutton(tools,'Text','Undo','Tag','tracks-undo','ButtonPushedFcn',@(~,~)obj.action('undo'));
            uibutton(tools,'Text','Redo','Tag','tracks-redo','ButtonPushedFcn',@(~,~)obj.action('redo'));
            button = uibutton(tools,'Text','Delete Track (all frames)','Tag','tracks-delete', ...
                'Tooltip','Remove this entire track, all its contours, parent/child links and censoring; Undo restores them', ...
                'ButtonPushedFcn',@(~,~)obj.action('delete'));
            button.Layout.Row = 2; button.Layout.Column = [1 2];
            button = uibutton(tools,'Text','Discard Edits','Tag','tracks-discard', ...
                'Tooltip','Discard the shared mask and track draft for this provider', ...
                'ButtonPushedFcn',@(~,~)obj.action('discard'));
            button.Layout.Row = 3; button.Layout.Column = [1 2];
            uibutton(grid,'Text','Save Edits','Tag','tracks-save', ...
                'Tooltip','Save the shared pending mask, track and annotation lifecycle edits for this provider', ...
                'ButtonPushedFcn',@(~,~)obj.action('save'));
            obj.Status = uilabel(grid,'Text','Ready','Interpreter','none','Tag','tracks-status');
            obj.Progress = detecdivui.Progress(grid,obj.Status,'tracks-progress');
        end
        function setActive(obj,active)
            entering = active && ~obj.Active; selected = [];
            if entering, selected = obj.Viewer.selectedAnnotation(); end
            if active && ~obj.Active
                obj.DownCallback = obj.Viewer.Figure.WindowButtonDownFcn;
                obj.Viewer.Figure.WindowButtonDownFcn = @(~,~)obj.mouseDown();
            elseif ~active && obj.Active
                liveFigure = isvalid(obj.Viewer.Figure);
                if liveFigure, obj.Viewer.Figure.WindowButtonDownFcn = obj.DownCallback; end
                obj.cancelPick(); obj.clearOverlays();
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
                if any(strcmp(obj.Provider.Items,selected.channel)), obj.Provider.Value = selected.channel; obj.refresh(); end
                d = obj.current(); c = obj.Viewer.contourContext();
                if strcmp(d.Channel,selected.channel)
                    instance = cellModel.findInstance(d.previewModel(),obj.Family.Value,c.frame,selected.label);
                    if ~isempty(instance)
                        obj.SelectedTrack = instance.track_id; obj.SelectedLabel = selected.label; obj.SelectedFrame = c.frame;
                    elseif strcmp(selected.tool,'Contours')
                        obj.clearSelection();
                    end
                    obj.refresh();
                end
            end
        end
        function onRender(obj)
            if ~obj.Active, return; end
            try
                obj.refresh();
            catch err, obj.Viewer.closeTracksTool(); obj.status(err.message);
            end
        end
        function draft = current(obj)
            c = obj.Viewer.contourContext();
            assert(~isempty(c.roi),'detecdivui:TrackROI','Select an extracted ROI first.');
            draft = obj.Viewer.annotationDraft(obj.Provider.Value);
        end
        function pick(obj,x,y)
            try
                c = obj.Viewer.contourContext(); d = obj.current(); model = d.previewModel();
                assert(isfield(model,'schema_version') && obj.Family.Value > 0, ...
                    'detecdivui:TrackModel','Import legacy tracks or select a registered object family first.');
                mask = d.read(c.frame); x = round(x); y = round(y);
                if x < 1 || y < 1 || x > size(mask,2) || y > size(mask,1), return; end
                label = double(mask(y,x));
                if label == 0 && isempty(obj.Pick), obj.clearSelection(); obj.refresh(); return; end
                instance = cellModel.findInstance(model,obj.Family.Value,c.frame,label);
                assert(~isempty(instance),'detecdivui:TrackPick','Select an object in the selected mask family.');
                if ~isempty(obj.Pick)
                    anchor = obj.Pick;
                    assert(isequal(anchor.roi,c.roi) && strcmp(anchor.channel,d.Channel) && ...
                        anchor.family == obj.Family.Value,'detecdivui:TrackPickContext','The linking context changed; select the child again.');
                    child = cellModel.findInstance(model,anchor.family,anchor.frame,anchor.label);
                    assert(~isempty(child) && child.track_id == anchor.track,'detecdivui:TrackPickContext', ...
                        'The source object changed while picking; select it again.');
                    assert(instance.track_id > 0,'detecdivui:TrackPick','Pick an assigned destination track.');
                    obj.Destination.Value = char(string(instance.track_id));
                    obj.Viewer.Masks.assertEditable(d,true);
                    d.editTrack(anchor.action,anchor.family,anchor.frame,anchor.label,instance.track_id,anchor.scope);
                    updated = cellModel.findInstance(d.previewModel(),anchor.family,anchor.frame,anchor.label);
                    if ~isempty(updated)
                        obj.SelectedTrack = updated.track_id; obj.SelectedLabel = anchor.label; obj.SelectedFrame = anchor.frame;
                    end
                    obj.cancelPick(); obj.Viewer.contourChanged(); return;
                end
                obj.SelectedTrack = instance.track_id; obj.SelectedLabel = label; obj.SelectedFrame = c.frame;
                obj.refresh();
            catch err, obj.status(err.message);
            end
        end
        function beginPick(obj,action)
            try
                [c,d,instance] = obj.selection();
                obj.Viewer.Masks.assertEditable(d,true);
                assert(instance.track_id > 0 || strcmp(action,'assign'),'detecdivui:TrackPick','Assign a child track first.');
                obj.Pick = struct('roi',c.roi,'channel',d.Channel,'family',obj.Family.Value, ...
                    'frame',c.frame,'label',double(instance.mask_label),'track',instance.track_id, ...
                    'scope',obj.Scope.Value,'action',action);
                obj.status('Pick a destination object; Escape cancels');
                obj.Viewer.Host.focusWidget('Image');
            catch err, obj.status(err.message);
            end
        end
        function key(obj,key,ctrl)
            if ~obj.Active, return; end
            if ctrl && strcmp(key,'z'), obj.action('undo');
            elseif ctrl && strcmp(key,'y'), obj.action('redo');
            elseif strcmp(key,'escape'), obj.cancelPick(); obj.refresh();
            elseif strcmp(key,'delete')
                obj.action('deleteFrame');
            end
        end
        function cancelLink(obj)
            obj.cancelPick(); obj.refresh();
        end
        function action(obj,action)
            try
                obj.cancelPick();
                message = 'Editing tracks...';
                if strcmp(action,'save'), message = 'Saving annotation edits...'; end
                scope = obj.Progress.begin(message); %#ok<NASGU>
                d = obj.current(); c = obj.Viewer.contourContext(); label = obj.currentLabel(d.previewModel(),c.frame);
                if ~strcmp(action,'discard')
                    changesModel = any(strcmp(action,{'assign','new','parent','unparent','swap','delete','import'})) || ...
                        (any(strcmp(action,{'undo','redo'})) && d.historyTouchesModel(action));
                    obj.Viewer.Masks.assertEditable(d,changesModel);
                end
                switch action
                    case 'undo', d.undo();
                    case 'redo', d.redo();
                    case 'discard', d.discard();
                    case 'save', d.save(); obj.Viewer.Masks.saved(d);
                    case 'import', d.importLegacy();
                    otherwise
                        [~,~,instance] = obj.selection();
                        if strcmp(action,'deleteFrame')
                            d.edit(c.frame,'delete',[],double(instance.mask_label),7,false);
                        else
                            target = uint64(0);
                            if any(strcmp(action,{'assign','swap','parent'})), target = detecdivui.trackId(obj.Destination.Value); end
                            d.editTrack(action,obj.Family.Value,c.frame,double(instance.mask_label),target,obj.Scope.Value);
                        end
                end
                if label > 0
                    instance = cellModel.findInstance(d.previewModel(),obj.Family.Value,c.frame,label);
                    if ~isempty(instance), obj.SelectedTrack = instance.track_id; obj.SelectedLabel = label; obj.SelectedFrame = c.frame; end
                end
                obj.Viewer.contourChanged();
            catch err, obj.status(err.message);
            end
        end
        function delete(obj)
            obj.setActive(false); obj.clearOverlays();
        end
        function forgetProject(obj,project)
            if isequal(obj.Project,project), obj.ROI = []; obj.Project = []; obj.clearSelection(); end
        end
    end
    methods (Access = private)
        function refresh(obj)
            c = obj.Viewer.contourContext();
            if isempty(c.roi) || isempty(c.masks), obj.Viewer.closeTracksTool(); return; end
            if ~isequal(obj.ROI,c.roi) || ~any(strcmp(obj.Provider.Value,c.masks))
                obj.ROI = c.roi; obj.Project = c.project; obj.Provider.Items = c.masks; obj.Provider.Value = c.masks{1};
                obj.clearSelection();
            end
            d = obj.current(); model = d.previewModel();
            items = {'—'}; ids = 0;
            if isfield(model,'schema_version')
                rows = find(strcmp(model.families.mask_provider,d.Channel));
                if ~isempty(rows)
                    items = model.families.name(rows).'; ids = double(model.families.family_id(rows)).';
                end
            end
            previous = obj.Family.Value;
            obj.Family.Items = items; obj.Family.ItemsData = ids;
            if any(ids == previous), obj.Family.Value = previous; else, obj.Family.Value = ids(1); obj.clearSelection(); end
            obj.Family.Enable = obj.onOff(any(ids > 0));
            obj.ImportButton.Enable = obj.onOff(~isfield(model,'schema_version'));
            marker = ''; if d.Dirty, marker = ' *'; end
            obj.Target.Text = sprintf('%s · Frame %d%s',c.roi.id,c.frame,marker);
            rows = obj.infoRows(model,c.frame); obj.Info.UserData = rows;
            for k = 1:size(rows,1), obj.InfoValues(k).Value = rows{k,2}; obj.InfoValues(k).Tooltip = rows{k,2}; end
            obj.Viewer.rememberAnnotation(c.roi,d.Channel,c.frame,obj.currentLabel(model,c.frame),'Tracks');
            obj.drawOverlays(d,model,c.frame);
            for ax = reshape(findall(obj.Viewer.Figure,'Type','axes'),1,[])
                if ~any(cellfun(@(state)isequal(state.axes,ax),obj.AxesState))
                    obj.AxesState{end+1} = struct('axes',ax,'interactions',ax.Interactions,'toolbar',ax.Toolbar.Visible);
                    ax.Interactions = []; ax.Toolbar.Visible = 'off';
                end
            end
            message = 'Ready';
            if d.Dirty, message = 'Unsaved annotations'; end
            if ~isfield(model,'schema_version'), message = 'No cellular model'; end
            if isfield(model,'schema_version') && obj.Family.Value == 0, message = 'No family for this mask provider'; end
            if ~isempty(obj.Pick), message = 'Pick a destination object; Escape cancels'; end
            if d.SaveFailed, message = ['Save incomplete: ' d.LastError]; end
            obj.status(message);
        end
        function [c,d,instance] = selection(obj)
            c = obj.Viewer.contourContext(); d = obj.current(); model = d.previewModel();
            assert(isfield(model,'schema_version') && obj.Family.Value > 0, ...
                'detecdivui:TrackModel','Import legacy tracks or select a registered object family first.');
            label = obj.currentLabel(model,c.frame);
            instance = cellModel.findInstance(model,obj.Family.Value,c.frame,label);
            assert(~isempty(instance),'detecdivui:TrackSelection','Select an object present on this frame.');
        end
        function label = currentLabel(obj,model,frame)
            label = 0;
            if ~isfield(model,'schema_version') || obj.Family.Value == 0, return; end
            if obj.SelectedTrack > 0
                instance = cellModel.findTrackInstance(model,obj.Family.Value,frame,obj.SelectedTrack);
            elseif obj.SelectedLabel > 0 && obj.SelectedFrame == frame
                instance = cellModel.findInstance(model,obj.Family.Value,frame,obj.SelectedLabel);
            else
                instance = [];
            end
            if ~isempty(instance), label = double(instance.mask_label); end
        end
        function rows = infoRows(obj,model,frame)
            rows = {'Label','—';'Track','—';'Parent','—';'Event','—';'First','—';'Last','—'};
            if ~isfield(model,'schema_version') || obj.Family.Value == 0, return; end
            label = obj.currentLabel(model,frame);
            if label > 0, rows{1,2} = num2str(label); end
            if obj.SelectedTrack == 0, return; end
            rows{2,2} = char(string(obj.SelectedTrack));
            selected = model.instances.family_id == obj.Family.Value & model.instances.track_id == obj.SelectedTrack;
            frames = double(model.instances.frame(selected));
            if ~isempty(frames), rows{5,2} = num2str(min(frames)); rows{6,2} = num2str(max(frames)); end
            relation = find(model.relations.family_id == obj.Family.Value & ...
                model.relations.child_track_id == obj.SelectedTrack & model.relations.type_id == 1,1);
            if ~isempty(relation)
                rows{3,2} = char(string(model.relations.parent_track_id(relation)));
                rows{4,2} = char(string(model.relations.event_frame(relation)));
            end
        end
        function drawOverlays(obj,draft,model,frame)
            obj.clearOverlays(); if ~isfield(model,'schema_version') || obj.Family.Value == 0, return; end
            ax = obj.Viewer.roiAxes(); mask = draft.read(frame); hold(ax,'on');
            rows = find(model.instances.family_id == obj.Family.Value & model.instances.frame == frame);
            for row = reshape(rows,1,[])
                label = model.instances.mask_label(row); [y,x] = find(mask == label);
                if isempty(x), continue; end
                track = model.instances.track_id(row); color = [1 1 1];
                if track == obj.SelectedTrack && track > 0, color = [1 .75 0]; end
                obj.Overlays(end+1) = text(ax,mean(x),mean(y),char(string(track)), ...
                    'Color',color,'FontWeight','bold','HitTest','off','PickableParts','none','Tag','track-label');
            end
            label = obj.currentLabel(model,frame);
            if label > 0
                boundaries = bwboundaries(mask == label,'noholes');
                for k = 1:numel(boundaries)
                    obj.Overlays(end+1) = plot(ax,boundaries{k}(:,2),boundaries{k}(:,1), ...
                        'Color',[1 .75 0],'LineWidth',2,'HitTest','off','PickableParts','none','Tag','track-selection');
                end
            end
            segments = cellModelLineageSegments(model,obj.Family.Value,frame,draft.Masks,true);
            cfg = score_getObjectDisplayConfig(draft.Source,draft.Channel);
            for segment = reshape(segments,1,[])
                obj.Overlays(end+1) = plot(ax,[segment.parentXY(1) segment.childXY(1)], ...
                    [segment.parentXY(2) segment.childXY(2)],'Color',cfg.genealogyLinkColor, ...
                    'LineWidth',cfg.linkWidthPx,'HitTest','off','PickableParts','none','Tag','track-link');
            end
            hold(ax,'off');
        end
        function mouseDown(obj)
            if ~obj.Active || obj.Viewer.contourGestureActive() || ~strcmp(obj.Viewer.Figure.SelectionType,'normal'), return; end
            ax = ancestor(hittest(obj.Viewer.Figure),'axes');
            if isempty(ax) || ~isequal(ancestor(ax,'figure'),obj.Viewer.Figure), return; end
            point = ax.CurrentPoint(1,1:2); obj.pick(point(1),point(2));
        end
        function resetContext(obj)
            obj.clearSelection(); obj.refresh();
        end
        function resetSelection(obj)
            obj.clearSelection(); obj.refresh();
        end
        function clearSelection(obj)
            obj.SelectedTrack = uint64(0); obj.SelectedLabel = 0; obj.SelectedFrame = 0; obj.cancelPick();
        end
        function cancelPick(obj)
            obj.Pick = [];
        end
        function clearOverlays(obj)
            delete(obj.Overlays(isgraphics(obj.Overlays))); obj.Overlays = gobjects(0);
        end
        function status(obj,message)
            obj.Status.Text = message; obj.Status.Tooltip = message;
        end
    end
    methods (Static,Access=private)
        function value = onOff(yes)
            value = 'off'; if yes, value = 'on'; end
        end
    end
end
