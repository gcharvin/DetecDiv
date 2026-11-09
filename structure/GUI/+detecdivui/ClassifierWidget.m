classdef ClassifierWidget < handle
    % Classifier library, dataset browser and staged parameter editing.
    properties (SetAccess = private)
        Classifiers = {}
        Current = []
        Progress
    end
    properties (Access = private)
        Viewer
        Figure
        Selector
        ROIs
        RoiIndices = []
        SelectedROI = 0
        SummarySource = []
        AnnotationRows = struct([])
        Name
        Path
        Scope
        Parameters
        Status
        Editor = []
        Advanced = []
        AdvancedSource = []
        Actions = gobjects(0)
    end
    methods
        function obj = ClassifierWidget(figure,viewer)
            obj.Figure = figure; obj.Viewer = viewer;
            root = uigridlayout(figure,[7 1]); root.Padding = [6 4 6 4];
            root.RowHeight = {60,'2x',22,48,28,'1x',22};
            bar = uigridlayout(root,[2 2]); bar.Padding = [0 0 0 0];
            bar.ColumnWidth = {'1x','1x'}; bar.RowHeight = {28,28};
            bar.RowSpacing = 4;
            uibutton(bar,'Text','Open...','Tag','classifier-open','ButtonPushedFcn',@(~,~)viewer.openClassifier());
            obj.Actions(1) = uibutton(bar,'Text','Save','Tag','classifier-save','ButtonPushedFcn',@(~,~)obj.save());
            uibutton(bar,'Text','Refresh','Tag','classifier-refresh','ButtonPushedFcn',@(~,~)obj.refreshCurrent());
            obj.Actions(2) = uibutton(bar,'Text','Advanced...','Tag','classifier-advanced', ...
                'Tooltip','Open the existing Classifier GUI for dataset preparation, training, validation and runtime export', ...
                'ButtonPushedFcn',@(~,~)obj.openAdvanced());
            dataset = uigridlayout(root,[2 1]); dataset.Padding = [0 0 0 0]; dataset.RowHeight = {28,'1x'};
            obj.Selector = uidropdown(dataset,'Items',{'—'},'ItemsData',0,'Enable','off', ...
                'Tag','classifier-selector','Tooltip','Open classifiers','ValueChangedFcn',@(~,~)obj.selected());
            obj.ROIs = uitable(dataset,'Data',cell(0,6),'RowName',{}, ...
                'ColumnName',{'ROI','ID','Set','Frame bounds','Status','Coverage'}, ...
                'ColumnWidth',{36,'auto',78,88,80,80}, ...
                'ColumnFormat',{'numeric','char',{'Training','Test','Validation'},'char','char','char'}, ...
                'ColumnEditable',[false false true true false false],'Tag','classifier-rois');
            obj.Name = uilabel(root,'Text','Classifier','FontWeight','bold','Interpreter','none');
            row = uigridlayout(root,[1 2]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x',48};
            obj.Path = uitextarea(row,'Editable','off','Value',{'—'},'Tag','classifier-path');
            uibutton(row,'Text','Copy','Tooltip','Copy the classifier folder', ...
                'ButtonPushedFcn',@(~,~)obj.copyPath());
            controls = uigridlayout(root,[1 2]); controls.Padding = [0 0 0 0]; controls.ColumnWidth = {'1x',68};
            obj.Scope = uidropdown(controls,'Items',{'Properties','Training Parameters','Execution Parameters'}, ...
                'Tag','classifier-parameter-scope','ValueChangedFcn',@(~,~)obj.parameters());
            obj.Actions(3) = uibutton(controls,'Text','Edit...','Tag','classifier-edit', ...
                'ButtonPushedFcn',@(~,~)obj.editParameters());
            obj.Parameters = uitable(root,'ColumnName',{'Parameter','Value'},'RowName',{}, ...
                'ColumnWidth',{140,'auto'},'Data',cell(0,2),'Tag','classifier-parameters');
            obj.Status = uilabel(root,'Text','Ready','Interpreter','none','Tag','classifier-status');
            obj.Progress = detecdivui.Progress(root,obj.Status,'classifier-progress');
            obj.Progress.Route = detecdivui.Callback(viewer,'widgetEvent','progressOwner','Classifier');
            obj.parameters();
        end
        function add(obj,classifier,focus)
            if nargin < 3, focus = true; end
            assert(isa(classifier,'classi') && isscalar(classifier) && isvalid(classifier));
            index = find(cellfun(@(c)isequal(c,classifier),obj.Classifiers),1);
            if isempty(index), obj.Classifiers{end+1} = classifier; end
            if focus, obj.Current = classifier; end
            obj.refresh();
            if focus
                obj.Viewer.Host.focusWidget('Classifier');
                obj.Viewer.showClassifierROI(classifier,0);
                obj.scanAnnotations([]); obj.datasetRows();
            end
        end
        function importWorkspace(obj,entries)
            for entry = reshape(entries,1,[])
                if strcmp(entry.kind,'classi'), obj.add(entry.object,false); end
            end
        end
        function refresh(obj)
            obj.Classifiers = obj.Classifiers(cellfun(@isvalid,obj.Classifiers));
            if ~isempty(obj.Current) && ~isvalid(obj.Current), obj.Current = []; end
            obj.Selector.ItemsData = [];
            if isempty(obj.Classifiers)
                obj.Selector.Items = {'—'}; obj.Selector.ItemsData = 0; obj.Selector.Value = 0; obj.Selector.Enable = 'off';
            else
                labels = cellfun(@(c)char(string(c.strid)),obj.Classifiers,'UniformOutput',false);
                obj.Selector.Items = matlab.lang.makeUniqueStrings(labels); obj.Selector.ItemsData = 1:numel(labels);
                index = find(cellfun(@(c)isequal(c,obj.Current),obj.Classifiers),1);
                if isempty(index), index = 1; obj.Current = obj.Classifiers{1}; obj.SelectedROI = 0; end
                obj.Selector.Value = index; obj.Selector.Enable = 'on';
            end
            obj.datasetRows();
            obj.parameters();
        end
        function selectROI(obj,classifier,index)
            obj.Current = classifier;
            obj.SelectedROI = index; obj.refresh();
            obj.parameters();
        end
        function editor = editParameters(obj)
            editor = [];
            if isempty(obj.Current), return; end
            if ~isempty(obj.Editor) && isvalid(obj.Editor), delete(obj.Editor); end
            [base,field,keys] = obj.values(); source = obj.Current;
            assert(isempty(obj.Advanced) || ~isvalid(obj.Advanced), ...
                'detecdivui:ClassifierEditor','Close Advanced before editing parameters here.');
            node = struct('id',char(string(source.strid)),'params',base);
            editor = detecdivui.StaticParameterDialog(node,keys, ...
                @(~,values)obj.apply(source,field,base,values));
            editor.Figure.Name = ['Classifier Parameters - ' char(string(source.strid))];
            editor.Figure.Tag = 'classifier-parameter-dialog'; obj.Editor = editor;
        end
        function save(obj,source)
            if isempty(obj.Current), return; end
            try
                if nargin > 1
                    assert(isequal(source,obj.Current),'detecdivui:ClassifierContext', ...
                        'The active classifier changed. Save it again from its own context.');
                end
                assert(isempty(obj.Advanced) || ~isvalid(obj.Advanced), ...
                    'detecdivui:ClassifierEditor','Close Advanced before saving from this widget.');
                if ~obj.Viewer.prepareClassifierSave(obj.Current), return; end
                scope = obj.Progress.begin('Saving classifier...'); %#ok<NASGU>
                [folder,name] = obj.Current.getPath();
                assert(isfolder(folder),'detecdivui:ClassifierPath','Classifier folder is unavailable.');
                classiSave(obj.Current);
                assert(isfile(fullfile(folder,[name '_classification.mat'])), ...
                    'detecdivui:ClassifierSave','The classifier file was not written.');
                obj.refresh(); obj.Status.Text = 'Classifier saved';
            catch err
                obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
        function openAdvanced(obj)
            if isempty(obj.Current), return; end
            try
                if ~isempty(obj.Editor) && isvalid(obj.Editor), delete(obj.Editor); end
                scope = obj.Progress.begin('Opening classifier editor...'); %#ok<NASGU>
                if ~isempty(obj.Advanced) && isvalid(obj.Advanced)
                    assert(isequal(obj.AdvancedSource,obj.Current), ...
                        'detecdivui:ClassifierEditor','Close the current Advanced editor before opening another classifier.');
                    figure(obj.Advanced.ClassifierUIFigure); return;
                end
                obj.Advanced = classifierGUI(obj.Current);
                obj.AdvancedSource = obj.Current;
            catch err
                obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
        function delete(obj)
            if ~isempty(obj.Editor) && isvalid(obj.Editor), delete(obj.Editor); end
            % The legacy editor owns its save/close flow; never force-close it.
        end
    end
    methods (Access = private)
        function datasetRows(obj)
            c = obj.Current;
            if isempty(c)
                obj.ROIs.Data = cell(0,6); obj.RoiIndices = []; return;
            end
            if ~isequal(c,obj.SummarySource)
                obj.SummarySource = c; obj.AnnotationRows = struct([]);
            end
            indices = [];
            for k = 1:numel(c.roi)
                r = c.roi(k);
                if strlength(string(r.id)) > 0 || ~isempty(r.image) || ~isempty(r.value), indices(end+1) = k; end %#ok<AGROW>
            end
            rows = cell(numel(indices),6); globalBounds = false;
            for row = 1:numel(indices)
                k = indices(row); subset = 'Test';
                if ismember(k,c.trainingset), subset = 'Training'; end
                if isstruct(c.dataset) && isfield(c.dataset,'split') && isfield(c.dataset.split,'val') && ...
                        ismember(k,c.dataset.split.val), subset = 'Validation'; end
                [bounds,info] = trainingBounds.resolve(c,k);
                globalBounds = globalBounds || strcmp(info.source,'global');
                status = 'Not checked'; coverage = '—';
                hit = [];
                if ~isempty(obj.AnnotationRows), hit = find([obj.AnnotationRows.roiIndex] == k & ...
                        strcmp({obj.AnnotationRows.roiId},char(string(c.roi(k).id))),1); end
                if ~isempty(hit)
                    summary = obj.AnnotationRows(hit);
                    if strcmpi(summary.status,'missing')
                        status = 'Missing';
                    elseif strcmpi(summary.validationStatus,'invalid')
                        status = 'Invalid';
                    elseif strcmpi(summary.status,'approved') || strcmpi(summary.validationStatus,'valid')
                        status = 'Ready';
                    else
                        status = 'Draft';
                    end
                    if summary.total > 0, coverage = sprintf('%d/%d',summary.reviewed,summary.total); end
                end
                rows(row,:) = {k,char(string(c.roi(k).id)),subset,trainingBounds.text(bounds),status,coverage};
            end
            obj.RoiIndices = indices; obj.ROIs.Data = rows;
            editable = isempty(obj.Advanced) || ~isvalid(obj.Advanced);
            obj.ROIs.ColumnEditable = [false false editable editable && ~globalBounds false false];
            obj.ROIs.Tooltip = 'Select a ROI to open it; edit Set or inclusive Frame bounds (for example 10:100 or all)';
            if globalBounds, obj.ROIs.Tooltip = 'Frame bounds are controlled by global bounds; use Advanced to change the mode'; end
            at = find(indices == obj.SelectedROI,1);
            if isempty(at), obj.ROIs.Selection = []; else, obj.ROIs.Selection = [at 1]; end
            sources = c.roi(indices);
            obj.ROIs.CellSelectionCallback = @(~,event)obj.roiSelected(event,c,indices,sources);
            obj.ROIs.CellEditCallback = @(~,event)obj.roiEdited(event,c,indices,sources);
        end
        function valid = currentRow(obj,c,indices,sources,row)
            valid = isequal(c,obj.Current) && row >= 1 && row <= numel(indices) && ...
                indices(row) <= numel(c.roi) && isequal(c.roi(indices(row)),sources(row));
        end
        function roiSelected(obj,event,c,indices,sources)
            if isempty(event.Indices), return; end
            row = event.Indices(1,1);
            if ~obj.currentRow(c,indices,sources,row), return; end
            obj.SelectedROI = indices(row);
            if all(ismember(event.Indices(:,2),[3 4])), return; end
            obj.Viewer.showClassifierROI(c,obj.SelectedROI);
            obj.scanAnnotations(obj.SelectedROI); obj.datasetRows();
        end
        function roiEdited(obj,event,c,indices,sources)
            if isempty(event.Indices), return; end
            row = event.Indices(1,1); column = event.Indices(1,2);
            if ~obj.currentRow(c,indices,sources,row), return; end
            try
                assert(isempty(obj.Advanced) || ~isvalid(obj.Advanced), ...
                    'detecdivui:ClassifierEditor','Close Advanced before editing this dataset.');
                index = indices(row);
                if column == 3
                    c.setRoiSet(index,event.NewData);
                elseif column == 4
                    [~,info] = trainingBounds.resolve(c,index);
                    assert(~strcmp(info.source,'global'),'detecdivui:ClassifierBounds', ...
                        'Global frame bounds are active. Change their mode in Advanced first.');
                    count = annotationManager.frameCount(c.roi(index));
                    trainingBounds.setRoi(c,index,event.NewData,'FrameCount',count);
                    obj.scanAnnotations(index);
                else, return;
                end
                obj.datasetRows(); obj.parameters(); obj.Status.Text = 'Dataset updated; save classifier to persist';
            catch err
                obj.datasetRows(); obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
        function scanAnnotations(obj,indices)
            if isempty(obj.Current), return; end
            c = obj.Current;
            if ~isequal(obj.SummarySource,c) || isempty(indices)
                obj.SummarySource = c; obj.AnnotationRows = struct([]);
            end
            scope = obj.Progress.begin('Checking ROI annotations...'); %#ok<NASGU>
            try
                rows = annotationManager.summarizeClassifier(c,indices,'Fast',true, ...
                    'ProgressFcn',@(done,total)obj.Progress.update('Checking ROI annotations...',done/max(total,1)));
                if ~isequal(c,obj.Current), return; end
                if isempty(obj.AnnotationRows), obj.AnnotationRows = rows;
                else
                    obj.AnnotationRows(ismember([obj.AnnotationRows.roiIndex],[rows.roiIndex])) = [];
                    obj.AnnotationRows = [obj.AnnotationRows(:); rows(:)];
                end
            catch err
                obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
        function refreshCurrent(obj)
            index = obj.SelectedROI;
            obj.scanAnnotations([]);
            obj.refresh();
            if ~isempty(obj.Current)
                if index > numel(obj.Current.roi), index = 0; end
                obj.Viewer.showClassifierROI(obj.Current,index);
            end
        end
        function selected(obj)
            if obj.Selector.Value < 1, return; end
            obj.Current = obj.Classifiers{obj.Selector.Value}; obj.SelectedROI = 0;
            obj.refresh(); obj.Viewer.showClassifierROI(obj.Current,0);
            obj.scanAnnotations([]); obj.datasetRows();
        end
        function parameters(obj)
            available = ~isempty(obj.Current);
            for item = reshape(obj.Actions,1,[]), item.Enable = matlab.lang.OnOffSwitchState(available); end
            if ~available
                obj.Parameters.Data = cell(0,2); return;
            end
            c = obj.Current; obj.Name.Text = char(string(c.strid));
            obj.Path.Value = {char(string(c.path))};
            [params,field,keys] = obj.values(); rows = cell(numel(keys),2);
            for k = 1:numel(keys)
                rows(k,:) = {keys{k},detecdivui.PipelineBindings.valueText(params.(keys{k}))};
            end
            if isempty(field)
                rows = [{'Package',char(string(c.classifierPkg)); ...
                    'Category',char(strjoin(string(c.category),', ')); ...
                    'Training function',char(string(c.trainingFun)); ...
                    'Inference function',char(string(c.classifyFun)); ...
                    'Output type',char(string(c.outputType))}; rows];
            end
            obj.Parameters.Data = rows;
            obj.Status.Text = sprintf('%d ROIs | %d training',numel(obj.RoiIndices),numel(intersect(c.trainingset,obj.RoiIndices)));
        end
        function [params,field,keys] = values(obj)
            c = obj.Current;
            switch obj.Scope.Value
                case 'Training Parameters', field = 'trainingParam'; params = c.trainingParam;
                case 'Execution Parameters', field = 'executionParam'; params = c.executionParam;
                otherwise
                    field = '';
                    description = c.description;
                    if iscell(description)
                        description = strjoin(cellfun(@detecdivui.PipelineBindings.valueText, ...
                            description(:)','UniformOutput',false),' | ');
                    end
                    params = struct('description',string(description),'channel',c.channel, ...
                        'channelName',c.channelName,'classes',strjoin(string(c.classes),' '));
            end
            if ~isstruct(params) || ~isscalar(params), params = struct(); end
            keys = fieldnames(params);
        end
        function apply(obj,source,field,base,params)
            assert(isvalid(source) && isequal(source,obj.Current), ...
                'detecdivui:ClassifierContext','The active classifier changed. Reopen its parameters.');
            [current,currentField] = obj.values();
            assert(strcmp(field,currentField) && isequaln(base,current), ...
                'detecdivui:ClassifierStale','Parameters changed elsewhere. Reopen the editor.');
            assert(isempty(obj.Advanced) || ~isvalid(obj.Advanced), ...
                'detecdivui:ClassifierEditor','Close Advanced before applying parameters.');
            if isempty(field)
                if ~isequaln(params.description,base.description)
                    assert(ischar(source.description) || isstring(source.description) && isscalar(source.description), ...
                        'detecdivui:ClassifierDescription','Use Advanced to change legacy package metadata.');
                end
                names = split(strtrim(string(params.classes))); names = names(strlength(names)>0);
                if ~isequal(string(source.classes(:)),names(:))
                    assert(~isempty(names) && numel(unique(names)) == numel(names), ...
                        'detecdivui:ClassifierClasses','Enter unique, nonempty class names.');
                    mapping = [];
                    if ~isempty(source.classes)
                        [mapping,cancelled] = classMappingDialog(obj.Figure,source.classes,cellstr(names));
                        assert(~cancelled,'detecdivui:ClassifierClasses','Class mapping cancelled.');
                    end
                    source.setClasses(cellstr(names),'mapping',mapping, ...
                        'storeMapping',~isempty(mapping),'updateROIData',true);
                end
                if ~isequaln(params.description,base.description)
                    if isstring(source.description), source.description = string(params.description);
                    else, source.description = char(params.description); end
                end
                source.channel = params.channel; source.channelName = params.channelName;
            else
                source.(field) = params;
            end
            obj.parameters(); obj.Status.Text = 'Parameters applied; save classifier to persist';
        end
        function copyPath(obj)
            if ~isempty(obj.Current), clipboard('copy',char(string(obj.Current.path))); end
        end
    end
end
