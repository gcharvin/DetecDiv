classdef ROIWidget < handle
    % ROI definition tools on the viewer axes; packages own generation.
    properties (SetAccess = private)
        Rects = zeros(0,4)
        Params = struct()
        Progress
    end
    properties (Access = private)
        Viewer
        Project = []
        Position = 0
        Mode
        Target
        Table
        Parameters
        Status
        ApplyButton
        DrawButton
        PreviewButton
        CropButton
        Crop = []
        Handles = {}
        Binding = []
        Records = struct('project',{},'position',{},'rects',{},'params',{},'mode',{},'crop',{})
        Refreshing = false
    end
    methods
        function obj = ROIWidget(parent,viewer)
            obj.Viewer = viewer;
            grid = uigridlayout(parent,[8 1]); grid.Padding = [6 6 6 6];
            grid.RowHeight = {22,28,28,'1x','1x',28,28,24};
            obj.Target = uilabel(grid,'Text','—','Interpreter','none','Tag','roi-target');
            obj.Mode = uidropdown(grid,'Items',{'Manual','Pattern','Grid','Tracked'}, ...
                'ItemsData',{'roiManual','roiPattern','roiGrid','roiTracked'},'Tag','roi-mode', ...
                'Tooltip','ROI definition method','ValueChangedFcn',@(~,~)obj.changeMode());
            buttons = uigridlayout(grid,[1 2]); buttons.Padding = [0 0 0 0];
            obj.DrawButton = uibutton(buttons,'Text','Draw','Tag','roi-draw','Tooltip','Draw on the main raw image', ...
                'ButtonPushedFcn',@(~,~)obj.draw());
            obj.CropButton = uibutton(buttons,'Text','Crop','Tag','roi-crop','Tooltip','Set this FOV pattern-detection inclusion region', ...
                'ButtonPushedFcn',@(~,~)obj.draw('crop'));
            obj.Table = uitable(grid,'Data',zeros(0,4),'ColumnName',{'X','Y','Width','Height'}, ...
                'ColumnEditable',true(1,4),'ColumnWidth','auto','RowName',{},'Tag','roi-draft-rectangles', ...
                'CellEditCallback',@(~,event)obj.editRectangle(event));
            obj.Parameters = uitable(grid,'Data',cell(0,2),'ColumnName',{'Parameter','Value'}, ...
                'ColumnEditable',[false true],'ColumnWidth',{'auto','auto'},'RowName',{}, ...
                'Tag','roi-parameters','CellEditCallback',@(~,event)obj.editParameter(event));
            buttons = uigridlayout(grid,[1 2]); buttons.Padding = [0 0 0 0];
            uibutton(buttons,'Text','Clear Draft','Tooltip','Discard pending shapes; existing ROIs stay intact', ...
                'ButtonPushedFcn',@(~,~)obj.clearDraft());
            obj.PreviewButton = uibutton(buttons,'Text','Preview','Tooltip','Preview ROI definitions on the main image', ...
                'ButtonPushedFcn',@(~,~)obj.preview());
            obj.ApplyButton = uibutton(grid,'Text','Create ROIs','Tag','roi-apply', ...
                'Tooltip','Append ROI definitions using the existing backend; no pixel extraction', ...
                'ButtonPushedFcn',@(~,~)obj.apply());
            obj.Status = uilabel(grid,'Text','Ready','Interpreter','none','Tag','roi-status');
            obj.Progress = detecdivui.Progress(grid,obj.Status,'roi-progress');
            obj.changeMode();
        end
        function setContext(obj,session)
            if isequal(obj.Project,session.Project) && obj.Position == session.Position, return; end
            obj.stash(); obj.clearHandles(); obj.Binding = [];
            obj.ApplyButton.Text = 'Create ROIs'; obj.Mode.Enable = 'on';
            obj.Project = session.Project; obj.Position = session.Position;
            obj.Rects = zeros(0,4); obj.Crop = []; obj.Params = feval([obj.Mode.Value '.setparam']);
            for k = 1:numel(obj.Records)
                r = obj.Records(k);
                if isequal(r.project,obj.Project) && r.position == obj.Position
                    obj.Rects = r.rects; obj.Params = r.params; obj.Mode.Value = r.mode; obj.Crop = r.crop; break;
                end
            end
            if obj.Position > 0
                obj.Target.Text = sprintf('FOV %d · %s',obj.Position,obj.Project.fov(obj.Position).id);
            else
                obj.Target.Text = 'Select a FOV';
            end
            obj.refresh();
        end
        function bind(obj,node,callback)
            mode = node.type; if strcmpi(mode,'roiIdentify'), mode = 'roiPattern'; end
            obj.Mode.Value = mode; obj.Params = feval([mode '.setparam'],node.params);
            obj.Binding = callback; obj.ApplyButton.Text = 'Use in Run'; obj.Rects = zeros(0,4);
            obj.Mode.Enable = 'off';
            if strcmp(mode,'roiManual') && isfield(obj.Params,'manualRois') && ~isempty(obj.Params.manualRois)
                records = obj.Params.manualRois;
                for k = 1:numel(records)
                    record = records(k); index = obj.Position;
                    if isfield(record,'fovIndex') && ~isempty(record.fovIndex), index = record.fovIndex; end
                    rect = obj.recordRect(record);
                    if index == obj.Position && ~isempty(rect), obj.Rects(end+1,:) = rect; end
                end
            elseif isfield(obj.Params,'manualRects') && ~isempty(obj.Params.manualRects)
                obj.Rects = obj.Params.manualRects;
            elseif isfield(obj.Params,'gridRects') && ~isempty(obj.Params.gridRects)
                obj.Rects = obj.Params.gridRects;
            end
            obj.refresh(); obj.onRender();
        end
        function standalone(obj)
            obj.Binding = []; obj.ApplyButton.Text = 'Create ROIs'; obj.Mode.Enable = 'on';
            if isfield(obj.Params,'extract'), obj.Params.extract = false; end
            obj.refresh();
        end
        function draw(obj,kind)
            if nargin < 2, kind = 'roi'; end
            try
                ax = obj.Viewer.prepareROIView();
                gesture = obj.Viewer.beginROIGesture(); %#ok<NASGU>
                handle = drawrectangle(ax,'Color',[1 .65 .12],'LineWidth',1.5);
                if isempty(handle) || ~isvalid(handle), return; end
                rect = handle.Position; delete(handle);
                if strcmp(kind,'crop')
                    obj.setCrop(rect);
                elseif strcmp(obj.Mode.Value,'roiPattern')
                    obj.setPattern(rect);
                else
                    obj.addRectangle(rect);
                end
            catch err
                obj.status(err.message);
            end
        end
        function addRectangle(obj,rect)
            obj.Viewer.prepareROIView(); obj.Rects(end+1,:) = obj.checked(rect);
            obj.refresh(); obj.onRender();
        end
        function setCrop(obj,rect)
            obj.Viewer.prepareROIView(); obj.Crop = obj.checked(rect); obj.onRender();
        end
        function setPattern(obj,rect)
            obj.Viewer.prepareROIView(); rect = obj.checked(rect);
            [plane,frame,channel] = obj.Viewer.roiSource();
            assert(ismatrix(plane),'detecdivui:PatternChannel','Select a single raw channel for the pattern.');
            patch = plane(rect(2):rect(2)+rect(4)-1,rect(1):rect(1)+rect(3)-1);
            obj.Params.pattern = struct('rect',rect,'image',patch,'fovIndex',obj.Position, ...
                'fovId',obj.Project.fov(obj.Position).id,'frame',frame,'channelIndex',channel);
            obj.Params.referenceFrame = frame; obj.Params.channelIndex = channel;
            obj.refresh(); obj.onRender();
        end
        function ctx = apply(obj)
            ctx = []; if isempty(obj.Project) || obj.Position == 0, return; end
            activity = obj.Progress.begin('Applying ROI definition...'); %#ok<NASGU>
            try
                p = obj.definition(); package = obj.Mode.Value;
                ctx = struct('shallow',obj.Project,'shallowObj',obj.Project,'params',p, ...
                    'fovIndex',obj.Position,'sel',struct('fovs',obj.Position), ...
                    'interactive',false,'allowGUI',false,'saveProgress',false, ...
                    'io',struct('existingPolicy','append'));
                ctx.(package) = p;
                if ~isempty(obj.Binding)
                    obj.Binding(ctx);
                    if ~isempty(obj.Crop), obj.Project.fov(obj.Position).crop = obj.Crop; end
                    obj.status('ROI definition applied to run');
                else
                    if ~isempty(obj.Crop), obj.Project.fov(obj.Position).crop = obj.Crop; end
                    ctx = feval([package '.process'],ctx);
                    obj.Rects = zeros(0,4); obj.clearHandles(); obj.Viewer.roisChanged();
                    obj.status('ROIs created');
                end
                obj.stash(); obj.refresh();
            catch err
                obj.status(err.message); ctx = [];
            end
        end
        function preview(obj)
            if strcmp(obj.Mode.Value,'roiTracked'), return; end
            activity = obj.Progress.begin('Previewing ROI definitions...'); %#ok<NASGU>
            try
                obj.Viewer.prepareROIView(); p = obj.definition();
                scratch = shallow();
                for k = 1:numel(obj.Project.fov)
                    copy = fov();
                    meta = metaclass(copy);
                    for j = 1:numel(meta.PropertyList)
                        property = meta.PropertyList(j); name = property.Name;
                        if property.Dependent || property.Constant || ismember(name,{'parent','roi'}), continue; end
                        copy.(name) = obj.Project.fov(k).(name);
                    end
                    scratch.fov(k) = copy;
                end
                if ~isempty(obj.Crop), scratch.fov(obj.Position).crop = obj.Crop; end
                ctx = struct('shallow',scratch,'params',p,'fovIndex',obj.Position, ...
                    'testOnly',true,'interactive',false,'saveProgress',false);
                ctx.io = struct('existingPolicy','append');
                ctx = feval([obj.Mode.Value '.process'],ctx);
                if strcmp(obj.Mode.Value,'roiPattern')
                    detections = ctx.patternDetection;
                else
                    rects = zeros(0,4); rois = scratch.fov(obj.Position).roi;
                    for k = 1:numel(rois)
                        if ~isempty(rois(k).id) && numel(rois(k).value) >= 4, rects(end+1,:) = double(rois(k).value); end %#ok<AGROW>
                    end
                    detections = struct('scaled',rects);
                end
                obj.Viewer.showRoiPreview(detections); obj.status('ROI preview updated');
            catch err
                obj.status(err.message);
            end
        end
        function onRender(obj)
            obj.clearHandles();
            if obj.Viewer.Session.Zone > 0 || obj.Position == 0, return; end
            ax = obj.Viewer.roiAxes();
            if isempty(findall(ax,'Type','image')), return; end
            for k = 1:size(obj.Rects,1), obj.addHandle(obj.Rects(k,:),'roi',k); end
            if isfield(obj.Params,'pattern') && ~isempty(obj.Params.pattern) && isfield(obj.Params.pattern,'rect')
                pattern = obj.Params.pattern(1);
                if (~isfield(pattern,'fovIndex') || pattern.fovIndex == obj.Position) && numel(pattern.rect) == 4
                    obj.addHandle(pattern.rect,'pattern',1);
                end
            end
            if ~isempty(obj.Crop), obj.addHandle(obj.Crop,'crop',1); end
        end
        function clearDraft(obj)
            obj.Rects = zeros(0,4); obj.Crop = [];
            if isfield(obj.Params,'pattern'), obj.Params.pattern = struct([]); end
            obj.clearHandles(); obj.stash(); obj.refresh();
        end
        function delete(obj)
            obj.clearHandles();
        end
        function forgetProject(obj,project)
            obj.Records = obj.Records(~arrayfun(@(r)isequal(r.project,project),obj.Records));
            if isequal(obj.Project,project)
                obj.Project = []; obj.Position = 0; obj.Binding = []; obj.Rects = zeros(0,4); obj.clearHandles();
            end
        end
    end
    methods (Access = private)
        function p = definition(obj)
            p = obj.Params; p.fovIndex = obj.Position;
            switch obj.Mode.Value
                case 'roiManual'
                    assert(~isempty(obj.Rects),'detecdivui:NoRects','Draw at least one ROI.');
                    records = struct('fovIndex',{},'rect',{});
                    if isfield(p,'manualRois') && ~isempty(p.manualRois)
                        for k = 1:numel(p.manualRois)
                            record = p.manualRois(k);
                            if isfield(record,'fovIndex') && ~isempty(record.fovIndex) && record.fovIndex ~= obj.Position
                                rect = obj.recordRect(record);
                                if ~isempty(rect), records(end+1) = struct('fovIndex',record.fovIndex,'rect',rect); end %#ok<AGROW>
                            end
                        end
                    end
                    for k = 1:size(obj.Rects,1), records(end+1) = struct('fovIndex',obj.Position,'rect',obj.Rects(k,:)); end %#ok<AGROW>
                    p.manualRois = records; p.manualRects = []; p.previewRects = []; p.candidateRects = [];
                case 'roiGrid'
                    if ~isempty(obj.Rects), p.gridRects = obj.Rects; end
                case 'roiPattern'
                    assert(isfield(p,'pattern') && ~isempty(p.pattern),'detecdivui:Pattern','Draw a pattern first.');
                case 'roiTracked'
                    if isempty(obj.Binding), p.extract = false; end
            end
            if isfield(p,'keepExisting'), p.keepExisting = true; end
        end
        function rect = checked(obj,rect)
            validateattributes(rect,{'numeric'},{'real','finite','vector','numel',4}); rect = round(double(rect(:)'));
            ax = obj.Viewer.roiAxes(); image = findall(ax,'Type','image');
            assert(~isempty(image),'detecdivui:RawImage','Load a raw image first.'); dims = size(image(1).CData);
            assert(all(rect >= 1) && rect(1)+rect(3)-1 <= dims(2) && rect(2)+rect(4)-1 <= dims(1) && ...
                all(rect <= double(intmax('uint16'))),'detecdivui:RoiBounds','Keep the rectangle inside the raw image.');
        end
        function addHandle(obj,rect,kind,index)
            color = [1 .65 .12]; if strcmp(kind,'crop'), color = [.2 .8 .3]; end
            handle = drawrectangle(obj.Viewer.roiAxes(),'Position',rect,'Color',color, ...
                'LineWidth',1.5,'Tag','roi-draft-shape');
            handle.ContextMenu = [];
            addlistener(handle,'ROIMoved',@(~,event)obj.moved(event.CurrentPosition,kind,index));
            obj.Handles{end+1} = handle;
        end
        function moved(obj,rect,kind,index)
            if obj.Refreshing, return; end
            try
                rect = obj.checked(rect);
                switch kind
                    case 'crop', obj.Crop = rect;
                    case 'pattern', obj.setPattern(rect);
                    otherwise, obj.Rects(index,:) = rect;
                end
                obj.refresh(); obj.stash();
            catch err
                obj.status(err.message); obj.onRender();
            end
        end
        function clearHandles(obj)
            obj.Refreshing = true;
            for k = 1:numel(obj.Handles), if isvalid(obj.Handles{k}), delete(obj.Handles{k}); end, end
            obj.Handles = {}; obj.Refreshing = false;
        end
        function changeMode(obj)
            obj.Params = feval([obj.Mode.Value '.setparam']); obj.Rects = zeros(0,4);
            if isfield(obj.Params,'extract'), obj.Params.extract = false; end
            obj.clearHandles(); obj.refresh();
        end
        function refresh(obj)
            obj.Table.Data = obj.Rects;
            names = fieldnames(obj.Params); data = cell(0,2); keys = {};
            specs = classifierBinding.parameterSpecFromDefaults(obj.Params);
            for k = 1:numel(names)
                key = names{k}; value = obj.Params.(key);
                if isstruct(value) || iscell(value) || isa(value,'function_handle') || ...
                        any(strcmp(key,{'manualRects','previewRects','candidateRects','gridRects','saveArgs', ...
                        'fovIndex','keepExisting','skipExisting','errorOnExisting','openFirstOnly'})) || ...
                        (strcmp(key,'extract') && isempty(obj.Binding))
                    continue;
                end
                if ischar(value) || isstring(value), text = char(value); else, text = jsonencode(value); end
                label = key; index = find(strcmp({specs.param},key),1);
                if ~isempty(index), label = specs(index).label; end
                keys{end+1} = key; data(end+1,:) = {label,text}; %#ok<AGROW>
            end
            obj.Parameters.UserData = keys; obj.Parameters.Data = data;
            obj.DrawButton.Enable = 'on'; if strcmp(obj.Mode.Value,'roiTracked'), obj.DrawButton.Enable = 'off'; end
            obj.PreviewButton.Enable = obj.DrawButton.Enable;
            obj.CropButton.Visible = 'off'; obj.DrawButton.Parent.ColumnWidth = {'1x',0};
            if strcmp(obj.Mode.Value,'roiPattern')
                obj.CropButton.Visible = 'on'; obj.DrawButton.Parent.ColumnWidth = {'1x','1x'};
            end
            heights = obj.Parameters.Parent.RowHeight;
            if isempty(data), heights{5} = 0; obj.Parameters.Visible = 'off';
            else, heights{5} = '1x'; obj.Parameters.Visible = 'on'; end
            obj.Parameters.Parent.RowHeight = heights;
        end
        function editRectangle(obj,event)
            try
                obj.Rects(event.Indices(1),:) = obj.checked(obj.Table.Data(event.Indices(1),:));
            catch err
                obj.status(err.message);
            end
            obj.refresh(); obj.onRender(); obj.stash();
        end
        function editParameter(obj,event)
            try
                key = obj.Parameters.UserData{event.Indices(1)}; base = obj.Params.(key); text = char(string(event.NewData));
                if ischar(base) || isstring(base), value = text;
                else
                    value = jsondecode(text); assert(isnumeric(value) || islogical(value),'Enter a numeric or boolean value.');
                    if islogical(base), value = logical(value); end
                end
                obj.Params.(key) = value; obj.Params = feval([obj.Mode.Value '.setparam'],obj.Params);
            catch err
                obj.status(err.message);
            end
            obj.refresh(); obj.stash();
        end
        function stash(obj)
            if isempty(obj.Project) || obj.Position == 0, return; end
            index = find(arrayfun(@(r)isequal(r.project,obj.Project) && r.position == obj.Position,obj.Records),1);
            if isempty(index), index = numel(obj.Records)+1; end
            obj.Records(index) = struct('project',obj.Project,'position',obj.Position,'rects',obj.Rects, ...
                'params',obj.Params,'mode',obj.Mode.Value,'crop',obj.Crop);
        end
        function status(obj,text)
            obj.Status.Text = text; obj.Status.Tooltip = text;
        end
    end
    methods (Static, Access = private)
        function rect = recordRect(record)
            rect = [];
            for field = {'rect','position','value'}
                if isfield(record,field{1}) && isnumeric(record.(field{1})) && numel(record.(field{1})) >= 4
                    rect = reshape(double(record.(field{1})(1:4)),1,4); return;
                end
            end
        end
    end
end
