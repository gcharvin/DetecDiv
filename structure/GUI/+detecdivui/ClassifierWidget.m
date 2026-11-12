classdef ClassifierWidget < handle
    % Classifier library, dataset browser and staged parameter editing.
    properties (SetAccess = private)
        Classifiers = {}
        Current = []
        Progress
        Mode = 'Review'
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
        ModeField
        ModeSource = []
        InitializeGT
        ReviewActions = gobjects(0)
        ReviewDialog = []
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
            dataset = uigridlayout(root,[4 1]); dataset.Padding = [0 0 0 0]; dataset.RowHeight = {28,28,'1x',28};
            obj.Selector = uidropdown(dataset,'Items',{'—'},'ItemsData',0,'Enable','off', ...
                'Tag','classifier-selector','Tooltip','Open classifiers','ValueChangedFcn',@(~,~)obj.selected());
            mode = uigridlayout(dataset,[1 2]); mode.Padding = [0 0 0 0]; mode.ColumnWidth = {'1x',130};
            obj.ModeField = uidropdown(mode,'Items',{'Review','Edit'},'Value','Review', ...
                'Tag','classifier-mode','Tooltip','Review data or enable dataset, parameter and annotation editing', ...
                'ValueChangedFcn',@(~,~)obj.setMode(obj.ModeField.Value));
            obj.InitializeGT = uibutton(mode,'Text','Initialize GT...','Tag','classifier-initialize-gt', ...
                'Tooltip','Open existing ground truth or initialize missing ground truth for the selected ROI', ...
                'ButtonPushedFcn',@(~,~)obj.initializeGT());
            obj.ROIs = uitable(dataset,'Data',cell(0,6),'RowName',{}, ...
                'ColumnName',{'ROI','ID','Set','Frame bounds','Status','Coverage'}, ...
                'ColumnWidth',{36,'auto',78,88,80,80}, ...
                'ColumnFormat',{'numeric','char',{'Training','Test','Validation'},'char','char','char'}, ...
                'ColumnEditable',[false false true true false false],'Tag','classifier-rois');
            review = uigridlayout(dataset,[1 2]); review.Padding = [0 0 0 0];
            obj.ReviewActions(1) = uibutton(review,'Text','Review GT...','Tag','classifier-review', ...
                'Tooltip','Inspect components and review coverage for the selected ROI', ...
                'ButtonPushedFcn',@(~,~)obj.reviewGroundTruth('open'));
            obj.ReviewActions(2) = uibutton(review,'Text','Validate GT','Tag','classifier-validate-gt', ...
                'Tooltip','Validate saved ground truth and review coverage; successful validation sets Ready', ...
                'ButtonPushedFcn',@(~,~)obj.reviewGroundTruth('validate'));
            obj.Name = uilabel(root,'Text','Classifier','FontWeight','bold','Interpreter','none');
            row = uigridlayout(root,[1 2]); row.Padding = [0 0 0 0]; row.ColumnWidth = {'1x',48};
            obj.Path = uitextarea(row,'Editable','off','Value',{'—'},'Tag','classifier-path');
            uibutton(row,'Text','Copy','Tooltip','Copy the classifier folder', ...
                'ButtonPushedFcn',@(~,~)obj.copyPath());
            controls = uigridlayout(root,[1 2]); controls.Padding = [0 0 0 0]; controls.ColumnWidth = {'1x',68};
            obj.Scope = uidropdown(controls,'Items',{'Properties','Training Parameters','Training Bindings', ...
                'Inference Parameters','Inference Bindings'}, ...
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
            obj.Viewer.noteSessionContent();
            obj.Viewer.publishWorkspaceObject(classifier);
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
            if ~isequal(obj.ModeSource,obj.Current)
                obj.ModeSource = obj.Current; obj.Mode = 'Review'; obj.ModeField.Value = obj.Mode;
                if ~isempty(obj.Editor) && isvalid(obj.Editor), delete(obj.Editor); end
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
            obj.assertEdit(obj.Current);
            if ~isempty(obj.Editor) && isvalid(obj.Editor), delete(obj.Editor); end
            source = obj.Current;
            assert(isempty(obj.Advanced) || ~isvalid(obj.Advanced), ...
                'detecdivui:ClassifierEditor','Close Advanced before editing parameters here.');
            if strcmp(obj.Scope.Value,'Properties')
                [base,field,keys] = obj.values();
                node = struct('id',char(string(source.strid)),'params',base);
                editor = detecdivui.StaticParameterDialog(node,keys, ...
                    @(~,values)obj.apply(source,field,base,values));
            else
                activity = obj.Progress.begin('Loading parameter resources...'); %#ok<NASGU>
                view = obj.parameterView(true);
                editor = detecdivui.ClassifierParameterDialog(char(string(source.strid)),view, ...
                    @(view,changes)obj.applyConfiguration(source,view,changes));
            end
            if strcmp(obj.Scope.Value,'Properties'), editor.Figure.Name = ['Classifier Properties - ' char(string(source.strid))]; end
            editor.Figure.Tag = 'classifier-parameter-dialog'; obj.Editor = editor;
        end
        function yes = canEdit(obj,classifier)
            yes = ~isempty(classifier) && isequal(classifier,obj.Current) && strcmp(obj.Mode,'Edit') && ...
                (isempty(obj.Advanced) || ~isvalid(obj.Advanced));
        end
        function yes = annotationContextMatches(obj,c,index,source,editing)
            yes = isvalid(c) && isequal(c,obj.Current) && index == obj.SelectedROI && ...
                index > 0 && index <= numel(c.roi) && isequal(c.roi(index),source) && ...
                isequal(obj.Viewer.Session.Classifier,c) && obj.Viewer.Session.Zone == index;
            if editing, yes = yes && obj.canEdit(c); end
        end
        function dialog = reviewGroundTruth(obj,action)
            if nargin < 2, action = 'open'; end
            dialog = [];
            try
                c = obj.Current; index = obj.SelectedROI;
                if isempty(c) || index < 1 || index > numel(c.roi), return; end
                if strcmp(action,'validate'), obj.assertEdit(c); end
                if isempty(obj.ReviewDialog) || ~isvalid(obj.ReviewDialog) || ~obj.ReviewDialog.matches(c,index)
                    if ~isempty(obj.ReviewDialog) && isvalid(obj.ReviewDialog), delete(obj.ReviewDialog); end
                    obj.ReviewDialog = detecdivui.ClassifierReviewDialog(obj,obj.Viewer,c,index);
                end
                dialog = obj.ReviewDialog;
                if strcmp(action,'open'), dialog.show();
                else, dialog.perform(action); end
            catch err, obj.annotationStatus(err.message);
            end
        end
        function annotationChanged(obj,source)
            if ~isempty(obj.Current)
                index = find(arrayfun(@(r)isequal(r,source),obj.Current.roi),1);
                if ~isempty(index), obj.scanAnnotations(index); obj.datasetRows(); end
            end
            if ~isempty(obj.ReviewDialog) && isvalid(obj.ReviewDialog) && isequal(obj.ReviewDialog.Source,source)
                obj.ReviewDialog.refresh();
            end
        end
        function onImageFrame(obj)
            if ~isempty(obj.ReviewDialog) && isvalid(obj.ReviewDialog), obj.ReviewDialog.onFrame(); end
        end
        function setFrameBounds(obj,c,index,source,value)
            try
                obj.assertEdit(c);
                assert(index > 0 && index <= numel(c.roi) && isequal(c.roi(index),source), ...
                    'detecdivui:ClassifierContext','The dataset changed. Select the ROI again.');
                [~,info] = trainingBounds.resolve(c,index);
                assert(~strcmp(info.source,'global'),'detecdivui:ClassifierBounds', ...
                    'Global frame bounds are active. Change their mode in Advanced first.');
                callback = detecdivui.Callback(obj,'setFrameBounds',c,index,source,value);
                if ~obj.Viewer.resolveClassifierEdits(c,callback), obj.datasetRows(); return; end
                session = c.annotationSession(index); session.setFrameBounds(value);
                obj.Viewer.annotationMetadataSaved(source); obj.annotationChanged(source); obj.datasetRows();
                obj.annotationStatus('Frame bounds updated; save classifier to persist');
            catch err
                obj.datasetRows(); obj.annotationStatus(err.message);
            end
        end
        function annotationStatus(obj,message)
            obj.Status.Text = message; obj.Status.Tooltip = message;
        end
        function setMode(obj,mode)
            assert(ismember(mode,{'Review','Edit'}),'detecdivui:ClassifierMode','Choose Review or Edit.');
            if ~isempty(obj.Advanced) && isvalid(obj.Advanced)
                obj.ModeField.Value = obj.Mode; obj.Status.Text = 'Close Advanced before changing mode'; return;
            end
            if strcmp(mode,'Review') && strcmp(obj.Mode,'Edit') && ~isempty(obj.Current)
                obj.ModeField.Value = obj.Mode;
                if ~obj.Viewer.resolveClassifierEdits(obj.Current,detecdivui.Callback(obj,'setMode','Review')), return; end
            end
            obj.Mode = mode; obj.ModeField.Value = mode;
            if ~isempty(obj.Editor) && isvalid(obj.Editor), delete(obj.Editor); end
            obj.datasetRows(); obj.parameters(); obj.Viewer.refreshClassifierAccess();
        end
        function initialized = initializeGT(obj,source,index,method,recipe,target)
            initialized = false;
            if nargin < 2, source = obj.Current; end
            if isempty(source), return; end
            if nargin < 3, index = obj.SelectedROI; end
            if nargin < 4, method = ''; end
            if nargin < 5, recipe = struct(); end
            if nargin < 6
                if index < 1 || index > numel(source.roi), return; end
                target = source.roi(index);
            end
            try
                obj.assertEdit(source);
                assert(index >= 1 && index <= numel(source.roi) && isequal(target,source.roi(index)), ...
                    'detecdivui:ClassifierContext','The dataset changed. Select the ROI again.');
                assert(obj.SelectedROI == index,'detecdivui:ClassifierContext','Select this ROI again before initializing its ground truth.');
                callback = detecdivui.Callback(obj,'initializeGT',source,index,method,recipe,target);
                if ~obj.Viewer.resolveClassifierEdits(source,callback), return; end
                session = source.annotationSession(index);
                summary = session.summary();
                exists = [summary.components.groundTruthExists];
                required = [summary.components.required];
                assert(~isempty(exists),'detecdivui:ClassifierGT','No annotation contract is available for this classifier.');
                if all(exists(required)) && any(exists)
                    obj.openGroundTruth(source,index,session.Spec);
                    obj.annotationChanged(target);
                    obj.Status.Text = 'Existing ground truth opened'; return;
                end
                assert(~any(exists),'detecdivui:ClassifierGT', ...
                    'Ground truth is incomplete. Use Advanced to repair it without replacing existing annotations.');
                if isempty(method)
                    method = uiconfirm(obj.Figure,'Initialize ground truth for the selected ROI?', ...
                        'Ground Truth','Options',{'Blank GT','From Existing...','Cancel'}, ...
                        'DefaultOption',1,'CancelOption',3);
                end
                if strcmp(method,'Cancel'), return; end
                if strcmp(method,'From Existing...') && isempty(fieldnames(recipe))
                    catalog = session.initializationCatalog();
                    [recipe,accepted] = annotationInitializationDialog(obj.Figure,catalog);
                    if ~accepted, return; end
                end
                obj.assertEdit(source);
                assert(isequal(target,source.roi(index)),'detecdivui:ClassifierContext','The dataset changed.');
                activity = obj.Progress.begin('Initializing ground truth...'); %#ok<NASGU>
                if strcmp(method,'Blank GT')
                    session.startBlank('Overwrite',false,'Save',true);
                elseif strcmp(method,'From Existing...')
                    session.initialize(recipe,'Overwrite',false,'Save',true);
                else
                    error('detecdivui:ClassifierGT','Unknown initialization method.');
                end
                initialized = true;
                obj.openGroundTruth(source,index,session.Spec);
                obj.annotationChanged(target); obj.parameters();
                obj.Status.Text = 'Ground truth initialized as Draft; save classifier to persist its bindings';
            catch err
                obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
        function save(obj,source)
            if isempty(obj.Current), return; end
            try
                obj.assertEdit(obj.Current);
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
                obj.Viewer.rememberClassifier(fullfile(folder,[name '_classification.mat']),obj.Current);
            catch err
                obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
        function openAdvanced(obj)
            if isempty(obj.Current), return; end
            try
                assert(strcmp(obj.Mode,'Edit'),'detecdivui:ClassifierReview','Switch to Edit to open Advanced.');
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
            if ~isempty(obj.ReviewDialog) && isvalid(obj.ReviewDialog), delete(obj.ReviewDialog); end
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
            editable = obj.canEdit(c);
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
                obj.assertEdit(c);
                assert(isempty(obj.Advanced) || ~isvalid(obj.Advanced), ...
                    'detecdivui:ClassifierEditor','Close Advanced before editing this dataset.');
                index = indices(row);
                if column == 3
                    c.setRoiSet(index,event.NewData);
                elseif column == 4
                    obj.setFrameBounds(c,index,c.roi(index),event.NewData); return;
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
            editable = obj.canEdit(obj.Current);
            for item = reshape(obj.Actions,1,[]), item.Enable = matlab.lang.OnOffSwitchState(editable); end
            obj.ModeField.Enable = matlab.lang.OnOffSwitchState(available);
            obj.InitializeGT.Enable = matlab.lang.OnOffSwitchState(editable && obj.SelectedROI > 0);
            obj.ReviewActions(1).Enable = matlab.lang.OnOffSwitchState(available && obj.SelectedROI > 0);
            obj.ReviewActions(2).Enable = obj.InitializeGT.Enable;
            if ~isempty(obj.ReviewDialog) && isvalid(obj.ReviewDialog), obj.ReviewDialog.refreshAccess(); end
            if ~available
                obj.Parameters.Data = cell(0,2); return;
            end
            c = obj.Current; obj.Name.Text = char(string(c.strid));
            obj.Path.Value = {char(string(c.path))};
            if strcmp(obj.Scope.Value,'Properties')
                [params,~,keys] = obj.values(); rows = cell(numel(keys),2);
                for k = 1:numel(keys)
                    rows(k,:) = {keys{k},detecdivui.PipelineBindings.valueText(params.(keys{k}))};
                end
                rows = [{'Package',char(string(c.classifierPkg)); ...
                    'Category',char(strjoin(string(c.category),', ')); ...
                    'Training function',char(string(c.trainingFun)); ...
                    'Inference function',char(string(c.classifyFun)); ...
                    'Output type',char(string(c.outputType))}; rows];
            else
                view = obj.parameterView(false); records = view.records; rows = cell(numel(records),2);
                for k = 1:numel(records)
                    rows(k,:) = {records(k).label,detecdivui.PipelineBindings.valueText(records(k).value)};
                end
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
                    params = struct('description',string(description),'classes',strjoin(string(c.classes),' '));
            end
            if ~isstruct(params) || ~isscalar(params), params = struct(); end
            keys = fieldnames(params);
        end
        function apply(obj,source,field,base,params)
            obj.assertEdit(source);
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
            else
                source.(field) = params;
            end
            obj.parameters(); obj.Status.Text = 'Parameters applied; save classifier to persist';
        end
        function copyPath(obj)
            if ~isempty(obj.Current), clipboard('copy',char(string(obj.Current.path))); end
        end
        function assertEdit(obj,source)
            assert(obj.canEdit(source),'detecdivui:ClassifierReview', ...
                'Switch this classifier to Edit and close Advanced before making changes.');
        end
        function view = parameterView(obj,withCatalog)
            stage = 'Inference'; if startsWith(obj.Scope.Value,'Training'), stage = 'Training'; end
            view = detecdivui.ClassifierParameters.describe(obj.Current,stage,endsWith(obj.Scope.Value,'Bindings'),withCatalog);
        end
        function applyConfiguration(obj,source,view,changes)
            obj.assertEdit(source);
            detecdivui.ClassifierParameters.apply(source,view,changes);
            obj.parameters(); obj.Status.Text = 'Parameters applied; save classifier to persist';
        end
        function openGroundTruth(obj,source,index,spec)
            obj.Viewer.showClassifierROI(source,index); obj.Viewer.loadCurrentImage();
            for component = reshape(spec.components,1,[])
                gt = component.groundTruth; name = '';
                if isfield(gt,'channel'), name = gt.channel; end
                if isempty(name) && isfield(gt,'maskProvider'), name = gt.maskProvider; end
                if ~isempty(name) && obj.Viewer.selectDisplayLayer(name)
                    if ismember(component.storage,{'channel','cell_model_family'}), obj.Viewer.openContourTool(); end
                    break;
                end
            end
        end
    end
end
