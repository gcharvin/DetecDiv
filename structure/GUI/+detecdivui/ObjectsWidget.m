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
        Families
        FrameText
        Items
        Controls = {}
        Status
        Busy = false
        Revision = 0
        LastError = ''
        StyledFamily = -1
        StyledObject = -1
    end
    methods
        function obj = ObjectsWidget(parent,viewer)
            obj.Viewer = viewer;
            grid = uigridlayout(parent,[7 1]); grid.Padding = [6 6 6 6];
            grid.RowHeight = {24,64,20,'1x',26,26,22}; grid.RowSpacing = 4;
            row = uigridlayout(grid,[1 2]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x',65};
            obj.Target = uilabel(row,'Text','—','Interpreter','none','Tag','objects-target');
            obj.Load = uibutton(row,'Text','Load','Tag','objects-load','Enable','off', ...
                'Tooltip','Load the selected ROI masks and object model on demand', ...
                'ButtonPushedFcn',@(~,~)obj.loadObjects());
            obj.Families = uitable(grid,'Data',cell(0,2),'RowName',{}, ...
                'ColumnName',{'Family','Layer'},'ColumnWidth',{'auto','auto'}, ...
                'ColumnEditable',[false false],'Tag','objects-families', ...
                'Tooltip','Select a family to show its mask layer in multicolor and enable object selection');
            obj.FrameText = uilabel(grid,'Text','Objects','Interpreter','none','Tag','objects-frame');
            obj.Items = uitable(grid,'Data',cell(0,4),'RowName',{}, ...
                'ColumnName',{'Label','Track','Parent','State'},'ColumnWidth',{50,80,80,'auto'}, ...
                'ColumnEditable',false(1,4),'Tag','objects-table', ...
                'Tooltip','Mask label, track identity and parent are separate values; select an object to locate it on the image');
            row = uigridlayout(grid,[1 3]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x','1x','1x'};
            for name = {'Contours','Tracks','Lineage'}
                action = lower(name{1});
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
            obj.setContext();
        end
        function resumed = resumeSelection(obj)
            resumed = false;
            if obj.Busy || isempty(obj.Source) || ~obj.Viewer.Host.isWidgetVisible('Objects'), return; end
            context = obj.Viewer.contourContext(); row = obj.selectedRow();
            if isempty(row) || ~isequal(context.roi,obj.Source) || ...
                    ~any(strcmp(context.masks,obj.SelectedProvider)), return; end
            obj.Busy = true; cleanup = onCleanup(@()obj.finish());
            obj.LastError = '';
            try
                obj.activateFamily(row,obj.SelectedLabel); resumed = true;
            catch err, obj.LastError = err.message;
            end
        end
        function loadObjects(obj)
            if obj.Busy || isempty(obj.Source), return; end
            obj.Busy = true; cleanup = onCleanup(@()obj.finish());
            obj.LastError = '';
            scope = obj.Progress.begin('Loading ROI objects...'); %#ok<NASGU>
            source = obj.Source;
            try
                obj.Viewer.loadCurrentImage();
                context = obj.Viewer.contourContext();
                assert(isequal(context.roi,source),'detecdivui:ObjectsContext','Load an extracted ROI with label masks.');
                [~,status] = score_getCellModel(source);
                assert(any(strcmp(status,{'ok','missing'})),'detecdivui:ObjectsModel','Cannot read the cellular model: %s',status);
                obj.refresh();
                row = obj.selectedRow();
                if isempty(row) && ~isempty(obj.Rows), row = 1; end
                if ~isempty(row), obj.activateFamily(row,0); end
                obj.status('Ready');
            catch err, obj.LastError = err.message;
            end
        end
        function selectFamily(obj,row)
            if obj.Busy || row < 1 || row > numel(obj.Rows), return; end
            obj.Busy = true; cleanup = onCleanup(@()obj.finish());
            obj.LastError = '';
            scope = obj.Progress.begin('Selecting object family...'); %#ok<NASGU>
            try
                obj.activateFamily(row,0);
            catch err, obj.LastError = err.message;
            end
        end
        function selectObject(obj,row)
            if obj.Busy || row < 1 || row > numel(obj.ObjectsRows), return; end
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
            scope = obj.Progress.begin('Opening object tools...'); %#ok<NASGU>
            try
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
            if ~isvalid(obj) || ~isvalid(obj.Viewer) || ~obj.Viewer.Host.isWidgetVisible('Objects') || ...
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
                obj.Families.Data = cell(0,2); obj.Items.Data = cell(0,4);
                obj.FrameText.Text = 'Objects'; obj.Revision = obj.Revision+1;
                obj.enableTools(false);
                obj.status(['Object model unavailable: ' err.message]);
            end
        end
        function activateFamily(obj,row,label)
            assert(obj.Viewer.Host.isWidgetVisible('Objects'),'detecdivui:ObjectsHidden', ...
                'Open Objects before selecting an object family.');
            item = obj.Rows(row); context = obj.Viewer.contourContext();
            if ~isequal(context.roi,obj.Source)
                obj.Viewer.loadCurrentImage(); context = obj.Viewer.contourContext();
            end
            assert(obj.Viewer.Host.isWidgetVisible('Objects'),'detecdivui:ObjectsHidden', ...
                'Objects was hidden while the ROI was loading.');
            assert(isequal(context.roi,obj.Source) && any(strcmp(context.masks,item.provider)), ...
                'detecdivui:ObjectsMask','Load this ROI and its mask layer before editing objects.');
            obj.SelectedFamily = item.familyId; obj.SelectedProvider = item.provider; obj.SelectedLabel = double(label);
            obj.Viewer.selectObjectFamily(item.provider,item.familyId,label);
        end
        function refresh(obj)
            if isempty(obj.Source)
                obj.Rows = obj.Rows([]); obj.ObjectsRows = obj.ObjectsRows([]);
                obj.Families.Data = cell(0,2); obj.Items.Data = cell(0,4); obj.FrameText.Text = 'Objects';
                obj.enableTools(false); obj.status('Select a ROI'); return;
            end
            model = obj.currentModel(); obj.Rows = obj.familyRows(model);
            familyData = cell(numel(obj.Rows),2);
            for k = 1:numel(obj.Rows), familyData(k,:) = {obj.Rows(k).name,obj.Rows(k).provider}; end
            if ~isequal(obj.Families.Data,familyData)
                removeStyle(obj.Families); obj.StyledFamily = -1; obj.Families.Data = familyData;
            end
            selection = obj.Viewer.selectedAnnotation();
            if ~isempty(selection) && any(strcmp({obj.Rows.provider},selection.channel))
                obj.SelectedProvider = selection.channel; obj.SelectedLabel = double(selection.label);
                if isfield(selection,'family') && selection.family > 0, obj.SelectedFamily = uint32(selection.family); end
            end
            row = obj.selectedRow();
            if isempty(row)
                obj.SelectedProvider = ''; obj.SelectedFamily = uint32(0); obj.SelectedLabel = 0;
            end
            frame = obj.Viewer.annotationFrame();
            obj.ObjectsRows = obj.instanceRows(model,frame);
            data = cell(numel(obj.ObjectsRows),4);
            for k = 1:numel(obj.ObjectsRows)
                item = obj.ObjectsRows(k);
                data(k,:) = {num2str(item.label),obj.idText(item.track),obj.idText(item.parent),item.state};
            end
            if ~isequal(obj.Items.Data,data)
                removeStyle(obj.Items); obj.StyledObject = -1; obj.Items.Data = data;
            end
            selectedObject = find([obj.ObjectsRows.label] == obj.SelectedLabel,1);
            obj.styleSelection(obj.Families,row,'StyledFamily');
            obj.styleSelection(obj.Items,selectedObject,'StyledObject');
            obj.FrameText.Text = sprintf('Frame %d · %d objects',frame,numel(obj.ObjectsRows));
            obj.Revision = obj.Revision+1; revision = obj.Revision;
            obj.Families.UserData = obj.Rows; obj.Items.UserData = obj.ObjectsRows;
            obj.Families.CellSelectionCallback = @(~,event)obj.selectEvent('family',event,revision);
            obj.Items.CellSelectionCallback = @(~,event)obj.selectEvent('object',event,revision);
            context = obj.Viewer.contourContext(); ready = ~isempty(row) && isequal(context.roi,obj.Source);
            obj.enableTools(ready);
            if ~isempty(row), obj.Families.Tooltip = [obj.Rows(row).name ' · ' obj.Rows(row).provider]; end
            if isempty(obj.Rows), obj.status('No object families or label layers');
            elseif isempty(row), obj.status('Select a family');
            elseif ~ready, obj.status('Load the ROI to edit objects');
            else
                draft = obj.existingDraft();
                if ~isempty(draft) && draft.SaveFailed
                    obj.status(['Save incomplete: ' draft.LastError]);
                elseif ~isempty(draft) && draft.Dirty
                    obj.status('Unsaved annotations');
                elseif obj.SelectedFamily == 0
                    obj.status('Mask labels · no registered family');
                else
                    obj.status('Ready');
                end
            end
            if ~isempty(obj.LastError), obj.status(obj.LastError); end
        end
        function model = currentModel(obj)
            model = [];
            if isstruct(obj.Source.cellModel) && isfield(obj.Source.cellModel,'schema_version'), model = obj.Source.cellModel; end
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
                if isempty(draft) || frame > size(draft.Masks,4), return; end
                labels = unique(draft.read(frame)); labels = labels(labels > 0);
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
