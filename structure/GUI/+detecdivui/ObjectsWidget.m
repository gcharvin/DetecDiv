classdef ObjectsWidget < handle
    % Object-family browser over the shared annotation model and mask drafts.
    properties (SetAccess = private)
        Progress
        Rows = struct('familyId',{},'name',{},'provider',{},'registered',{})
        ObjectsRows = struct('label',{},'track',{},'parent',{},'state',{})
        SelectedFamily = uint32(0)
        SelectedProvider = ''
        SelectedLabel = 0
    end
    properties (Access = private)
        Viewer
        Source = []
        Target
        Load
        FamilyText
        FrameText
        Items
        Controls = {}
        Status
        Busy = false
        Revision = 0
        LastError = ''
        StyledObject = -1
        NewTracks
        Separate
        Shared = false
    end
    methods
        function obj = ObjectsWidget(parent,viewer)
            obj.Viewer = viewer;
            grid = uigridlayout(parent,[8 1]); grid.Padding = [6 6 6 6];
            grid.RowHeight = {24,22,20,'1x',28,26,26,22}; grid.RowSpacing = 4;
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x',65};
            obj.Target = uilabel(row,'Text','—','Interpreter','none','Tag','objects-target');
            obj.Load = uibutton(row,'Text','Load','Tag','objects-load','Enable','off', ...
                'Tooltip','Load this ROI mask layers and tracking results on demand', ...
                'ButtonPushedFcn',@(~,~)obj.loadObjects());
            obj.FamilyText = uilabel(grid,'Text','—','Interpreter','none','Tag','objects-family', ...
                'Tooltip','Annotation target associated with the selected Display layer');
            obj.FrameText = uilabel(grid,'Text','Masks','Interpreter','none','Tag','objects-frame');
            obj.Items = uitable(grid,'Data',cell(0,4),'RowName',{}, ...
                'ColumnName',{'Mask','Track','Parent','State'},'ColumnWidth',{50,80,80,'auto'}, ...
                'ColumnEditable',false(1,4),'Tag','objects-table', ...
                'Tooltip','Select a region to locate its mask and track on Image');
            row = uigridlayout(grid,[1 2]); row.Padding=[0 0 0 0];
            obj.NewTracks=uibutton(row,'Text','New Tracks...','Tag','annotations-new-tracks', ...
                'Tooltip','Copy the active masks to a dedicated manual tracking layer', ...
                'ButtonPushedFcn',@(~,~)viewer.createAnnotationLayers('new'));
            obj.Separate=uibutton(row,'Text','Separate Layers...','Tag','annotations-separate-layers', ...
                'Tooltip','Give shared tracking results independent mask layers before editing', ...
                'ButtonPushedFcn',@(~,~)viewer.createAnnotationLayers());
            row = uigridlayout(grid,[1 3]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x','1x','1x'};
            for name = {'Masks','Tracks','Lineage'}
                action = lower(name{1});
                if strcmp(action,'masks'), action='contours'; end % Preserve callback/tag compatibility.
                obj.Controls{end+1} = uibutton(row,'Text',[name{1} '...'],'Tag',['objects-' action], ...
                    'Enable','off','ButtonPushedFcn',@(~,~)obj.action(action));
            end
            row = uigridlayout(grid,[1 3]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x','1x','1x'};
            for name = {'Undo','Redo','Save Edits'}
                action = lower(strrep(name{1},' Edits',''));
                obj.Controls{end+1} = uibutton(row,'Text',name{1},'Tag',['objects-' action], ...
                    'Enable','off','Tooltip','Use the shared mask and track draft', ...
                    'ButtonPushedFcn',@(~,~)obj.action(action));
            end
            obj.Status = uilabel(grid,'Text','Ready','Interpreter','none','Tag','objects-status');
            obj.Progress = detecdivui.Progress(grid,obj.Status,'objects-progress');
            obj.setContext();
        end
        function setContext(obj)
            source = [];
            session = obj.Viewer.Session;
            if session.Zone > 0, source = session.Project.fov(session.Position).roi(session.Zone); end
            if ~isequal(source,obj.Source)
                obj.Source = source; obj.SelectedFamily = uint32(0); obj.SelectedProvider = ''; obj.SelectedLabel = 0;
                obj.LastError = '';
                obj.Revision = obj.Revision+1;
            end
            obj.Load.Enable = obj.onOff(~isempty(source)); obj.Target.Text = '—'; obj.Target.Tooltip = '';
            if ~isempty(source), obj.Target.Text = source.id; obj.Target.Tooltip = source.path; end
            obj.safeRefresh();
        end
        function onRender(obj)
            if obj.Busy, return; end
            previous = obj.SelectedProvider;
            obj.setContext();
            if ~strcmp(previous,obj.SelectedProvider) || isempty(obj.SelectedProvider)
                % Keep existing drafts, but never leave image editing attached
                % to the previously selected Display layer.
                obj.Viewer.closeTracksTool(); obj.Viewer.closeContourTool();
            end
            if ~isempty(obj.SelectedProvider) && obj.Viewer.objectsBrowserActive() && obj.Viewer.annotationLayerEditable(obj.SelectedProvider)
                masks = obj.Viewer.Masks; draft = [];
                if ~isempty(masks) && isvalid(masks) && masks.Active, draft = masks.current(); end
                if isempty(draft) || ~isequal(draft.Source,obj.Source) || ~strcmp(draft.Channel,obj.SelectedProvider)
                    obj.resumeSelection();
                end
            end
        end
        function resumed = resumeSelection(obj)
            resumed = false;
            if obj.Busy || isempty(obj.Source) || ~obj.Viewer.Host.isWidgetVisible('Annotations'), return; end
            context = obj.Viewer.contourContext(); row = obj.selectedRow();
            if isempty(row) || ~isequal(context.roi,obj.Source) || ...
                    ~any(strcmp(context.masks,obj.SelectedProvider)), return; end
            obj.Busy = true; cleanup = onCleanup(@()obj.finish());
            obj.LastError = '';
            try
                obj.activateFamily(row,obj.SelectedLabel); resumed = obj.Viewer.annotationLayerEditable(obj.SelectedProvider);
            catch err, obj.LastError = err.message;
            end
        end
        function loadObjects(obj)
            if obj.Busy || isempty(obj.Source), return; end
            obj.Busy = true; cleanup = onCleanup(@()obj.finish());
            obj.LastError = '';
            scope = obj.Progress.begin('Loading ROI annotations...'); %#ok<NASGU>
            source = obj.Source;
            try
                obj.Viewer.loadCurrentImage();
                context = obj.Viewer.contourContext();
                assert(isequal(context.roi,source),'detecdivui:ObjectsContext','Load an extracted ROI with label masks.');
                [~,status] = score_getCellModel(source);
                assert(any(strcmp(status,{'ok','missing'})),'detecdivui:ObjectsModel','Cannot read the cellular model: %s',status);
                obj.refresh();
                row = obj.selectedRow();
                if ~isempty(row) && ~obj.Shared, obj.activateFamily(row,0); end
                if ~obj.Shared, obj.status('Ready'); end
            catch err, obj.LastError = err.message;
            end
        end
        function selectFamily(obj,row)
            if obj.Busy || row < 1 || row > numel(obj.Rows), return; end
            obj.Busy = true; cleanup = onCleanup(@()obj.finish());
            obj.LastError = '';
            scope = obj.Progress.begin('Selecting tracking result...'); %#ok<NASGU>
            try
                obj.activateFamily(row,0);
            catch err, obj.LastError = err.message;
            end
        end
        function selectObject(obj,row)
            if obj.Busy || row < 1 || row > numel(obj.ObjectsRows), return; end
            if obj.Shared
                obj.Viewer.selectObjectFamily(obj.SelectedProvider,uint32(0),obj.ObjectsRows(row).label); return;
            end
            family = obj.selectedRow(); if isempty(family), return; end
            obj.Busy = true; cleanup = onCleanup(@()obj.finish());
            obj.LastError = '';
            try
                obj.activateFamily(family,obj.ObjectsRows(row).label);
            catch err, obj.LastError = err.message;
            end
        end
        function action(obj,action)
            if obj.Busy || isempty(obj.SelectedProvider), return; end
            obj.Busy = true; cleanup = onCleanup(@()obj.finish());
            obj.LastError = '';
            scope = obj.Progress.begin('Opening annotation tools...'); %#ok<NASGU>
            try
                assert(obj.Viewer.annotationLayerEditable(obj.SelectedProvider),'detecdivui:AnnotationReadOnly', ...
                    'Select an editable mask layer; shared results need dedicated layers first.');
                switch action
                    case 'contours'
                        obj.Viewer.openContourTool();
                        obj.Viewer.Masks.selectProvider(obj.SelectedProvider,obj.SelectedLabel);
                    case {'tracks','lineage'}
                        obj.Viewer.openTracksTool();
                        obj.Viewer.Tracks.selectProvider(obj.SelectedProvider,obj.SelectedFamily,obj.SelectedLabel);
                        if strcmp(action,'lineage'), obj.Viewer.Tracks.showLineage(); end
                    case {'undo','redo','save'}
                        draft = obj.Viewer.annotationDraft(obj.SelectedProvider);
                        obj.Viewer.Masks.assertEditable(draft,any(strcmp(action,{'undo','redo'})) && draft.historyTouchesModel(action));
                        if strcmp(action,'save'), draft.save(); obj.Viewer.Masks.saved(draft);
                        else, feval(action,draft); obj.Viewer.contourChanged(); end
                end
            catch err, obj.LastError = err.message;
            end
        end
        function selectEvent(obj,kind,event,revision)
            if ~isvalid(obj) || ~isvalid(obj.Viewer) || ~obj.Viewer.Host.isWidgetVisible('Annotations') || ...
                    revision ~= obj.Revision || isempty(event.Indices), return; end
            row = event.Indices(1,1);
            if strcmp(kind,'family'), obj.selectFamily(row); else, obj.selectObject(row); end
        end
        function delete(obj)
            obj.Source = []; obj.Rows = obj.Rows([]); obj.ObjectsRows = obj.ObjectsRows([]);
        end
    end
    methods (Access = private)
        function finish(obj)
            obj.Busy = false; obj.safeRefresh();
        end
        function safeRefresh(obj)
            try
                obj.refresh();
            catch err
                % Optional object metadata cannot invalidate the image view.
                obj.Rows = obj.Rows([]); obj.ObjectsRows = obj.ObjectsRows([]);
                obj.SelectedProvider = ''; obj.SelectedFamily = uint32(0); obj.SelectedLabel = 0;
                obj.FamilyText.Text = '—'; obj.Items.Data = cell(0,4);
                obj.FrameText.Text = 'Annotations'; obj.Revision = obj.Revision+1;
                obj.enableTools(false);
                obj.status(['Object model unavailable: ' err.message]);
            end
        end
        function activateFamily(obj,row,label)
            assert(~obj.Shared,'detecdivui:AnnotationShared','Separate the tracking results into dedicated mask layers before selecting a result.');
            assert(obj.Viewer.Host.isWidgetVisible('Annotations'),'detecdivui:ObjectsHidden', ...
                'Open Annotations before selecting a tracking result.');
            item = obj.Rows(row); context = obj.Viewer.contourContext();
            if ~isequal(context.roi,obj.Source)
                obj.Viewer.loadCurrentImage(); context = obj.Viewer.contourContext();
            end
            assert(obj.Viewer.Host.isWidgetVisible('Annotations'),'detecdivui:ObjectsHidden', ...
                'Annotations was hidden while the ROI was loading.');
            assert(isequal(context.roi,obj.Source) && any(strcmp(context.masks,item.provider)), ...
                'detecdivui:ObjectsMask','Load this ROI and its mask layer before editing annotations.');
            obj.SelectedFamily = item.familyId; obj.SelectedProvider = item.provider; obj.SelectedLabel = double(label);
            obj.Viewer.selectObjectFamily(item.provider,item.familyId,label);
        end
        function refresh(obj)
            if isempty(obj.Source)
                obj.Rows = obj.Rows([]); obj.ObjectsRows = obj.ObjectsRows([]);
                obj.FamilyText.Text = '—'; obj.Items.Data = cell(0,4); obj.FrameText.Text = 'Annotations';
                obj.enableTools(false); obj.status('Select a ROI'); return;
            end
            model = obj.currentModel(); obj.Rows = obj.familyRows(model);
            provider = obj.Viewer.activeLayer();
            if ~strcmp(provider,obj.SelectedProvider)
                obj.SelectedProvider = provider; obj.SelectedFamily = uint32(0); obj.SelectedLabel = 0;
            end
            selection = obj.Viewer.selectedAnnotation();
            if ~isempty(selection) && strcmp(selection.channel,provider)
                obj.SelectedProvider = selection.channel; obj.SelectedLabel = double(selection.label);
                if isfield(selection,'family') && selection.family > 0, obj.SelectedFamily = uint32(selection.family); end
            end
            matching = find(strcmp({obj.Rows.provider},provider)); obj.Shared = numel(matching)>1;
            row = obj.selectedRow();
            if isempty(row), row = find(strcmp({obj.Rows.provider},provider),1); end
            if isempty(row)
                obj.SelectedProvider = ''; obj.SelectedFamily = uint32(0); obj.SelectedLabel = 0;
                obj.FamilyText.Text = '—'; obj.FamilyText.Tooltip = 'Select a mask layer in Display';
            else
                obj.SelectedProvider = obj.Rows(row).provider; obj.SelectedFamily = obj.Rows(row).familyId;
                obj.FamilyText.Text = obj.Rows(row).name;
                obj.FamilyText.Tooltip = [obj.Rows(row).name ' · ' obj.Rows(row).provider];
                target=obj.Viewer.annotationTarget(provider);
                obj.FamilyText.Text=[target.role ' · ' provider];
                if obj.Shared
                    obj.SelectedFamily=uint32(0); obj.FamilyText.Text=sprintf('%s · %d tracking results',provider,numel(matching));
                elseif obj.SelectedFamily>0
                    obj.FamilyText.Tooltip=[obj.Rows(row).name ' · ' provider];
                end
            end
            frame = obj.Viewer.annotationFrame();
            obj.ObjectsRows = obj.instanceRows(model,frame);
            target=[]; if ~isempty(obj.SelectedProvider), target=obj.Viewer.annotationTarget(obj.SelectedProvider); end
            data = cell(numel(obj.ObjectsRows),4);
            for k = 1:numel(obj.ObjectsRows)
                item = obj.ObjectsRows(k);
                track=obj.idText(item.track);
                if item.track==0 && ~obj.Shared, track='Unassigned'; end
                data(k,:) = {num2str(item.label),track,obj.idText(item.parent),item.state};
                if ~isempty(target) && target.semantic
                    if item.label<=numel(target.classes), data{k,1}=target.classes{item.label}; end
                    data(k,2:3)={'—','—'};
                elseif obj.Shared
                    data(k,2:4)={'—','—',''};
                end
            end
            if ~isequal(obj.Items.Data,data)
                removeStyle(obj.Items); obj.StyledObject = -1; obj.Items.Data = data;
            end
            selectedObject = find([obj.ObjectsRows.label] == obj.SelectedLabel,1);
            obj.styleSelection(obj.Items,selectedObject,'StyledObject');
            obj.FrameText.Text = sprintf('Frame %d · %d regions',frame,numel(obj.ObjectsRows));
            obj.Revision = obj.Revision+1; revision = obj.Revision;
            obj.Items.UserData = obj.ObjectsRows;
            obj.Items.CellSelectionCallback = @(~,event)obj.selectEvent('object',event,revision);
            context = obj.Viewer.contourContext(); ready = ~isempty(row) && isequal(context.roi,obj.Source);
            obj.enableTools(ready);
            obj.Separate.Enable=obj.onOff(ready && obj.Shared && obj.Viewer.annotationEditingAllowed());
            obj.NewTracks.Enable=obj.onOff(ready && ~obj.Shared && isempty(obj.Viewer.Session.Classifier) && obj.Viewer.annotationEditingAllowed());
            if ready
                target=obj.Viewer.annotationTarget(provider);
                if target.semantic
                    for k=1:numel(obj.Controls)
                        if any(strcmp(obj.Controls{k}.Tag,{'objects-tracks','objects-lineage'})), obj.Controls{k}.Enable='off'; end
                    end
                    obj.NewTracks.Enable='off';
                end
            end
            if isempty(row), obj.status('No masks for the active layer');
            elseif ~ready, obj.status('Load the ROI to edit annotations');
            else
                draft = obj.existingDraft();
                if ~isempty(draft) && draft.SaveFailed
                    obj.status(['Save incomplete: ' draft.LastError]);
                elseif ~isempty(draft) && draft.Dirty
                    obj.status('Unsaved annotations');
                elseif obj.Shared
                    obj.status('Shared masks · separate layers to edit each tracking result');
                elseif obj.SelectedFamily == 0
                    obj.status('Masks · no tracking result');
                else
                    obj.status('Ready');
                end
            end
            if ~isempty(obj.LastError), obj.status(obj.LastError); end
        end
        function model = currentModel(obj)
            model = [];
            if isstruct(obj.Source.cellModel) && isfield(obj.Source.cellModel,'schema_version'), model = obj.Source.cellModel; end
            if isempty(model)&&detecdivui.MaskDraft.isLabel(obj.Source,obj.Viewer.activeLayer())
                [model,status]=score_getCellModel(obj.Source);
                assert(any(strcmp(status,{'ok','missing'})),'detecdivui:ObjectsModel','Cannot read the cellular model: %s',status);
            end
            draft = obj.existingDraft();
            if ~isempty(draft), model = draft.previewModel(); end
        end
        function draft = existingDraft(obj)
            draft = [];
            masks = obj.Viewer.Masks;
            if isempty(masks) || ~isvalid(masks), return; end
            for k = 1:numel(masks.Drafts)
                candidate = masks.Drafts{k};
                if isequal(candidate.Source,obj.Source) && strcmp(candidate.Channel,obj.SelectedProvider)
                    draft = candidate; return;
                end
            end
        end
        function rows = familyRows(obj,model)
            rows = obj.Rows([]);
            if isstruct(model) && isfield(model,'families') && isfield(model.families,'family_id')
                families = model.families;
                for k = 1:numel(families.family_id)
                    rows(end+1) = struct('familyId',uint32(families.family_id(k)), ...
                        'name',char(string(families.name{k})),'provider',char(string(families.mask_provider{k})), ...
                        'registered',true); %#ok<AGROW>
                end
            end
            names = cellstr(string(obj.Source.display.channel));
            for k = 1:numel(names)
                name = names{k};
                if detecdivui.MaskDraft.isLabel(obj.Source,name) && ~any(strcmp({rows.provider},name))
                    rows(end+1) = struct('familyId',uint32(0),'name',[name ' (labels)'],'provider',name,'registered',false); %#ok<AGROW>
                end
            end
        end
        function rows = instanceRows(obj,model,frame)
            rows = obj.ObjectsRows([]);
            if isempty(obj.SelectedProvider), return; end
            if obj.SelectedFamily > 0 && isstruct(model) && isfield(model,'instances')
                instances = model.instances;
                indices = find(instances.family_id == obj.SelectedFamily & instances.frame == frame);
                for index = reshape(indices,1,[])
                    track = instances.track_id(index); parent = uint64(0); state = '';
                    relation = find(model.relations.family_id == obj.SelectedFamily & ...
                        model.relations.child_track_id == track & model.relations.type_id == 1,1);
                    if ~isempty(relation), parent = model.relations.parent_track_id(relation); end
                    at = find(model.states.state_id == instances.state_id(index),1);
                    if ~isempty(at), state = model.states.name{at}; end
                    rows(end+1) = struct('label',double(instances.mask_label(index)), ...
                        'track',uint64(track),'parent',uint64(parent),'state',state); %#ok<AGROW>
                end
            else
                draft = obj.existingDraft();
                if ~isempty(draft) && frame <= size(draft.Masks,4)
                    plane = draft.read(frame);
                else
                    pix = obj.Source.findChannelID(obj.SelectedProvider);
                    if ~isscalar(pix) || pix > size(obj.Source.image,3) || frame > size(obj.Source.image,4), return; end
                    plane = obj.Source.image(:,:,pix,frame);
                end
                labels = unique(plane); labels = labels(labels > 0);
                for label = reshape(labels,1,[])
                    rows(end+1) = struct('label',double(label),'track',uint64(0),'parent',uint64(0),'state',''); %#ok<AGROW>
                end
            end
        end
        function row = selectedRow(obj)
            row = find(strcmp({obj.Rows.provider},obj.SelectedProvider) & [obj.Rows.familyId] == obj.SelectedFamily,1);
        end
        function styleSelection(obj,table,index,cache)
            if isempty(index), index = 0; end
            if obj.(cache) == index, return; end
            removeStyle(table);
            if index > 0
                addStyle(table,uistyle('BackgroundColor',[.86 .93 .99],'FontWeight','bold'),'row',index);
            end
            obj.(cache) = index;
        end
        function enableTools(obj,ready)
            ready = ready && obj.Viewer.annotationLayerEditable(obj.SelectedProvider);
            obj.NewTracks.Enable='off'; obj.Separate.Enable='off';
            for k = 1:numel(obj.Controls), obj.Controls{k}.Enable = obj.onOff(ready); end
            obj.Controls{3}.Enable = obj.onOff(ready && obj.SelectedFamily > 0);
            draft = obj.existingDraft();
            obj.Controls{4}.Enable = obj.onOff(ready && ~isempty(draft) && ~isempty(draft.UndoStack));
            obj.Controls{5}.Enable = obj.onOff(ready && ~isempty(draft) && ~isempty(draft.RedoStack));
            obj.Controls{6}.Enable = obj.onOff(ready && ~isempty(draft) && draft.Dirty);
        end
        function status(obj,message)
            obj.Status.Text = message; obj.Status.Tooltip = message;
        end
    end
    methods (Static,Access=private)
        function value = onOff(yes)
            value = 'off'; if yes, value = 'on'; end
        end
        function value = idText(id)
            value = '—'; if id > 0, value = char(string(id)); end
        end
    end
end
