classdef RunSetup < handle
    % Run configuration controls; no image access, execution or persistence.
    properties
        OnChanged = []
    end
    properties (SetAccess = private)
        Controls = struct()
    end
    methods
        function obj = RunSetup(parent)
            grid = uigridlayout(parent,[11 2]); grid.Padding = [4 4 4 4];
            grid.ColumnWidth = {115,'1x'};
            grid.RowHeight = repmat({28},1,11); grid.RowSpacing = 6; grid.Scrollable = 'on';
            obj.text(grid,'runId','Run ID','Automatic');
            obj.choice(grid,'inputSourceMode','Input',{'Project data','Raw images'}, ...
                {'existing_rois','raw_dataloader'});
            obj.text(grid,'rawDataPath','Raw data','Folder');
            obj.text(grid,'fovs','FOVs','all / 1,3 / 1:4 / FOV ID');
            obj.text(grid,'rois','ROIs','all / 1,3 / 1:4 / ROI ID');
            obj.text(grid,'frames','Frames','all / 1,3 / 1:50');
            obj.choice(grid,'runPolicy','Progress',{'Resume','Restart'},{'resume','restart'});
            obj.choice(grid,'outputPolicy','Existing outputs',{'Skip','Replace','Append/update','Error'}, ...
                {'skip','replace','upsert','error'});
            obj.choice(grid,'gpuPolicy','Device',{'Auto','GPU','CPU'},{'module_default','gpu','cpu'});
            obj.choice(grid,'executionTarget','Execution',{'Local','Local WSL','Hub'},{'local','local_wsl','hub'});
            obj.text(grid,'description','Description','');
            obj.load(struct());
        end
        function load(obj,settings)
            defaults = struct('runId','','inputSourceMode','existing_rois','rawDataPath','', ...
                'fovs','all','rois','all','frames','all','runPolicy','resume', ...
                'outputPolicy','skip','gpuPolicy','module_default','executionTarget','local','description','');
            for item = fieldnames(defaults)'
                key = item{1}; value = defaults.(key);
                if isfield(settings,key), value = settings.(key); end
                obj.Controls.(key).Value = value;
            end
            obj.Controls.rawDataPath.Enable = detecdivui.RunSetup.onOff(strcmp(obj.Controls.inputSourceMode.Value,'raw_dataloader'));
        end
        function settings = values(obj)
            settings = struct();
            for item = fieldnames(obj.Controls)'
                key = item{1}; settings.(key) = obj.Controls.(key).Value;
            end
        end
    end
    methods (Access = private)
        function text(obj,parent,key,label,placeholder)
            uilabel(parent,'Text',label);
            obj.Controls.(key) = uieditfield(parent,'text','Placeholder',placeholder, ...
                'Tag',['pipeline-run-' key],'Tooltip',[label ': ' placeholder], ...
                'ValueChangedFcn',@(~,~)obj.changed());
        end
        function choice(obj,parent,key,label,items,data)
            uilabel(parent,'Text',label);
            obj.Controls.(key) = uidropdown(parent,'Items',items,'ItemsData',data, ...
                'Tag',['pipeline-run-' key],'Tooltip',label,'ValueChangedFcn',@(~,~)obj.changed());
        end
        function changed(obj)
            obj.Controls.rawDataPath.Enable = detecdivui.RunSetup.onOff(strcmp(obj.Controls.inputSourceMode.Value,'raw_dataloader'));
            if ~isempty(obj.OnChanged), obj.OnChanged(); end
        end
    end
    methods (Static)
        function selected = selection(text,ids)
            % Parse a UI selector without evaluating MATLAB expressions.
            if nargin < 2, ids = {}; end
            text = strtrim(char(string(text))); selected = [];
            if isempty(text) || strcmpi(text,'all'), return; end
            groups = regexp(regexprep(text,'^\[|\]$',''),'[,;]+','split'); tokens = {};
            for k = 1:numel(groups)
                group = strtrim(groups{k});
                if any(strcmp(ids,group))
                    tokens{end+1} = group; %#ok<AGROW>
                else
                    tokens = [tokens regexp(group,'\s+','split')]; %#ok<AGROW>
                end
            end
            for k = 1:numel(tokens)
                token = tokens{k};
                if isempty(token), continue; end
                if ~isempty(regexp(token,'^\d+(:\d+){0,2}$','once'))
                    parts = str2double(strsplit(token,':'));
                    assert(all(isfinite(parts)) && all(parts >= 1) && all(parts <= 1e7), ...
                        'detecdivui:Selection','Enter positive indices or an exact ID.');
                    if isscalar(parts)
                        values = parts;
                    elseif numel(parts) == 2
                        assert(parts(2)-parts(1) < 100000,'detecdivui:Selection','Selection range is too large.');
                        values = parts(1):parts(2);
                    else
                        assert((parts(3)-parts(1))/parts(2) < 100000,'detecdivui:Selection','Selection range is too large.');
                        values = parts(1):parts(2):parts(3);
                    end
                    assert(~isempty(values) && numel(values) <= 100000, ...
                        'detecdivui:Selection','Selection range is empty or too large.');
                else
                    values = find(strcmp(ids,token));
                    assert(isscalar(values),'detecdivui:Selection','Unknown or ambiguous selection: %s',token);
                end
                selected = [selected values]; %#ok<AGROW>
            end
            selected = unique(selected,'stable');
            assert(~isempty(selected),'detecdivui:Selection','Selection is empty.');
        end
    end
    methods (Static, Access = private)
        function text = onOff(value)
            text = 'off'; if value, text = 'on'; end
        end
    end
end
