classdef ClassifierReviewDialog < handle
    % Explicit review/validation over the existing managed-GT session.
    properties (SetAccess=private)
        Figure
        Classifier
        RoiIndex
        Source
        Session
        Summary = struct()
        Findings = []
        Progress
    end
    properties (Access=private)
        Owner
        Viewer
        Scope
        FrameText
        SummaryText
        Components
        Status
        Mutations = gobjects(0)
        Busy = false
        FindingsStale = true
    end
    methods
        function obj=ClassifierReviewDialog(owner,viewer,c,index)
            obj.Owner=owner; obj.Viewer=viewer; obj.Classifier=c; obj.RoiIndex=index; obj.Source=c.roi(index);
            obj.Session=c.annotationSession(index);
            obj.Figure=uifigure('Name',sprintf('Ground Truth - %s / ROI %d',c.strid,index), ...
                'Position',[240 170 690 420],'Visible','off','Tag','classifier-review-dialog', ...
                'CloseRequestFcn',@(~,~)obj.hide());
            root=uigridlayout(obj.Figure,[7 1]); root.Padding=[10 8 10 8];
            root.RowHeight={24,24,'1x',28,28,28,22};
            uilabel(root,'Text',char(string(obj.Source.id)),'FontWeight','bold','Interpreter','none');
            obj.SummaryText=uilabel(root,'Text','','Interpreter','none','Tag','classifier-review-summary');
            obj.Components=uitable(root,'RowName',{},'ColumnName',{'Component','Unit','Reviewed','Ground truth'}, ...
                'ColumnWidth',{'auto',70,90,100},'ColumnEditable',false(1,4),'Tag','classifier-review-components');
            row=uigridlayout(root,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={210,'1x'};
            obj.Scope=uidropdown(row,'Items',{'Current frame','Through current frame','Frame bounds','ROI-level components'}, ...
                'ItemsData',{'frame','through','bounds','roi'},'Value','frame','Tag','classifier-review-scope', ...
                'ValueChangedFcn',@(~,~)obj.onFrame());
            obj.FrameText=uilabel(row,'Text','','Interpreter','none','Tag','classifier-review-frame');
            row=uigridlayout(root,[1 3]); row.Padding=[0 0 0 0];
            obj.Mutations(1)=uibutton(row,'Text','Mark Reviewed','Tag','classifier-review-mark', ...
                'ButtonPushedFcn',@(~,~)obj.perform('review'));
            obj.Mutations(2)=uibutton(row,'Text','Clear Reviewed','Tag','classifier-review-clear', ...
                'ButtonPushedFcn',@(~,~)obj.perform('unreview'));
            uibutton(row,'Text','Next Unreviewed','Tag','classifier-review-next', ...
                'Tooltip','Navigate within the classifier frame bounds without changing review coverage', ...
                'ButtonPushedFcn',@(~,~)obj.nextUnreviewed());
            row=uigridlayout(root,[1 4]); row.Padding=[0 0 0 0];
            obj.Mutations(3)=uibutton(row,'Text','Validate GT','Tag','classifier-review-validate', ...
                'Tooltip','Validate saved ground truth and review coverage; successful validation sets Ready', ...
                'ButtonPushedFcn',@(~,~)obj.perform('validate'));
            uibutton(row,'Text','Findings...','Tag','classifier-review-findings', ...
                'Tooltip','Inspect saved ground truth without changing validation or readiness', ...
                'ButtonPushedFcn',@(~,~)obj.perform('findings'));
            uibutton(row,'Text','Open ROI','Tag','classifier-review-open-roi','ButtonPushedFcn',@(~,~)obj.openROI());
            uibutton(row,'Text','Close','ButtonPushedFcn',@(~,~)obj.hide());
            obj.Status=uilabel(root,'Text','Ready','Interpreter','none','Tag','classifier-review-status');
            obj.Progress=detecdivui.Progress(root,obj.Status,'classifier-review-progress');
            obj.Progress.Route=detecdivui.Callback(obj,'progressOwner');
            try
                obj.refresh();
            catch err
                delete(obj); rethrow(err);
            end
        end
        function yes=matches(obj,c,index)
            yes=isequal(c,obj.Classifier) && index==obj.RoiIndex && index<=numel(c.roi) && isequal(c.roi(index),obj.Source);
        end
        function show(obj)
            obj.refresh(); obj.Figure.Visible='on'; figure(obj.Figure);
        end
        function hide(obj)
            obj.Figure.Visible='off';
        end
        function target=progressOwner(obj)
            target=[];
            if strcmp(obj.Figure.Visible,'off'), target=obj.Owner.Progress; end
        end
        function refresh(obj)
            if ~obj.sourceValid(), obj.refreshAccess(); return; end
            obj.Session.refresh(); obj.Summary=obj.Session.summary(); obj.FindingsStale=true;
            required=obj.Session.Spec.components([obj.Session.Spec.components.required]);
            values={}; labels={};
            if any(strcmp({required.coverageUnit},'frame'))
                values={'frame','through','bounds'}; labels={'Current frame','Through current frame','Frame bounds'};
            end
            if any(strcmp({required.coverageUnit},'roi'))
                values{end+1}='roi'; labels{end+1}='ROI-level components';
            end
            if isempty(values), values={'frame'}; labels={'No required components'}; end
            selected=obj.Scope.Value; obj.Scope.ItemsData=[];
            obj.Scope.Items=labels; obj.Scope.ItemsData=values;
            if ismember(selected,values), obj.Scope.Value=selected; else, obj.Scope.Value=values{1}; end
            components=obj.Summary.coverage.components; rows=cell(numel(components),4);
            for k=1:numel(components)
                at=find(strcmp({obj.Summary.components.id},components(k).id),1); exists=false;
                if ~isempty(at), exists=obj.Summary.components(at).groundTruthExists; end
                state='Missing'; if exists, state='Present'; end
                rows(k,:)={components(k).id,components(k).unit, ...
                    sprintf('%d/%d',components(k).reviewed,components(k).total),state};
            end
            obj.Components.Data=rows; obj.refreshAccess(); obj.onFrame();
        end
        function refreshAccess(obj)
            if ~isgraphics(obj.Figure), return; end
            editable=~obj.Busy && obj.Owner.annotationContextMatches(obj.Classifier,obj.RoiIndex,obj.Source,true);
            for item=reshape(obj.Mutations,1,[]), item.Enable=matlab.lang.OnOffSwitchState(editable); end
            if ~obj.sourceValid()
                obj.SummaryText.Text='Dataset changed; reopen Ground Truth'; return;
            end
            if ~isempty(fieldnames(obj.Summary))
                state=char(string(obj.Summary.status));
                if strcmp(state,'approved')
                    state='Ready';
                elseif strcmp(obj.Summary.validationStatus,'invalid')
                    state='Invalid';
                else
                    state=[upper(state(1)) state(2:end)];
                end
                bounds=trainingBounds.text(trainingBounds.resolve(obj.Classifier,obj.RoiIndex));
                mode='Inactive';
                if obj.Owner.annotationContextMatches(obj.Classifier,obj.RoiIndex,obj.Source,false), mode=obj.Owner.Mode; end
                obj.SummaryText.Text=sprintf('%s | Frame bounds %s | %s',state,bounds,mode);
                if ~isempty(obj.Viewer.Masks) && isvalid(obj.Viewer.Masks) && obj.Viewer.Masks.dirty(obj.Source)
                    obj.SummaryText.Text=[obj.SummaryText.Text ' | Unsaved edits'];
                end
            end
        end
        function onFrame(obj)
            if ~isgraphics(obj.Figure) || ~obj.sourceValid(), return; end
            current=obj.Viewer.annotationFrame();
            label=sprintf('Frame %d',current);
            if ~obj.Owner.annotationContextMatches(obj.Classifier,obj.RoiIndex,obj.Source,false)
                label='Open this ROI to navigate or edit';
            elseif ~isempty(fieldnames(obj.Summary))
                frames=obj.Session.trainingFrames(); selected=obj.selectedFrames(frames,current);
                if strcmp(obj.Scope.Value,'roi'), label='ROI-level components';
                elseif isempty(selected), label=[label ' | Outside frame bounds'];
                elseif numel(selected)>1, label=sprintf('Frames %d:%d',selected(1),selected(end));
                else
                    coverage='Not reviewed'; if obj.frameReviewed(current), coverage='Reviewed'; end
                    label=[label ' | ' coverage];
                end
            end
            obj.FrameText.Text=label; obj.refreshAccess();
        end
        function report=perform(obj,action,selection)
            report=[]; if obj.Busy, return; end
            try
                assert(ismember(action,{'review','unreview','validate','findings'}),'detecdivui:ClassifierReviewAction','Unknown review action.');
                editing=~strcmp(action,'findings');
                message='Open this classifier ROI in Image before inspecting its GT.';
                if editing, message='Open this classifier ROI in Image and switch to Edit before changing its GT.'; end
                assert(obj.Owner.annotationContextMatches(obj.Classifier,obj.RoiIndex,obj.Source,editing), ...
                    'detecdivui:ClassifierContext',message);
                obj.Session.refresh();
                if nargin<3, selection=obj.selection(action); end
                assert(strcmp(selection.annotationId,obj.Session.Spec.id) && ...
                    isequal(selection.trainingFrames,obj.Session.trainingFrames()), ...
                    'detecdivui:ClassifierReviewContext','Annotation settings changed. Repeat the action.');
                callback=detecdivui.Callback(obj,'perform',action,selection);
                if ~obj.Viewer.resolveClassifierEdits(obj.Classifier,callback), return; end
                obj.Busy=true; cleanup=onCleanup(@()obj.finish());
                activity=obj.Progress.begin('Checking ground truth...'); %#ok<NASGU>
                switch action
                    case {'review','unreview'}
                        summary=obj.Session.summary();
                        at=ismember({summary.components.id},selection.components);
                        assert(any(at) && all([summary.components(at).groundTruthExists]), ...
                            'detecdivui:ClassifierMissingGT','Initialize the selected ground-truth components first.');
                        if strcmp(action,'review')
                            obj.Session.markReviewed('Frames',selection.frames,'Components',selection.components);
                        else
                            obj.Session.markUnreviewed('Frames',selection.frames,'Components',selection.components);
                        end
                    case 'validate'
                        report=obj.Session.validate();
                    case 'findings'
                        report=obj.refreshFindings(); obj.showFindings(report);
                end
                if editing
                    obj.Viewer.annotationMetadataSaved(obj.Source);
                    obj.Owner.annotationChanged(obj.Source); obj.refresh();
                    if strcmp(action,'validate')
                        if report.valid
                            obj.status('GT validated and Ready for training');
                        else
                            obj.status('GT validation failed'); obj.Figure.Visible='on'; obj.showFindings(report);
                        end
                    elseif strcmp(action,'review')
                        obj.status('Review coverage saved; validate GT to set Ready');
                    else
                        obj.status('Review coverage cleared');
                    end
                end
            catch err
                if obj.Busy && obj.sourceValid()
                    try
                        obj.Viewer.annotationMetadataSaved(obj.Source); obj.Owner.annotationChanged(obj.Source);
                    catch
                        % Preserve the original backend error and any pending draft.
                    end
                end
                obj.status(err.message);
            end
        end
        function report=refreshFindings(obj)
            assert(obj.sourceValid(),'detecdivui:ClassifierContext','The dataset changed. Reopen Ground Truth.');
            activity=obj.Progress.begin('Auditing saved ground truth...'); %#ok<NASGU>
            obj.Session.refresh(); report=obj.Session.findings(); obj.FindingsStale=false;
        end
        function yes=findingsAreStale(obj)
            yes=obj.FindingsStale;
        end
        function showFindings(obj,report)
            obj.deleteFindings();
            if isempty(annotationManager.validationIssueRows(report))
                obj.status('No validation findings'); return;
            end
            obj.Findings=annotationValidationDialog(obj.Figure,report,'Persistent',true, ...
                'Title',sprintf('GT Findings - %s / ROI %d',obj.Classifier.strid,obj.RoiIndex), ...
                'OnGo',@(issue,row)obj.goToFinding(issue,row), ...
                'OnRefresh',@()obj.refreshFindings(),'OnIsStale',@()obj.findingsAreStale());
        end
        function goToFinding(obj,issue,row)
            if ~obj.openROI(), return; end
            try
                if ~isfinite(row.frame)||row.frame<1, return; end
                obj.Viewer.navigateDataFrame(obj.Source,row.frame);
                if isempty(issue)||~isfield(issue,'family_id')||issue.family_id<1, return; end
                model=obj.Source.cellModel;
                [at,~]=cellModel.familyIndex(model,issue.family_id); if isempty(at), return; end
                provider=model.families.mask_provider{at};
                hit=find(model.instances.family_id==issue.family_id & model.instances.frame==row.frame & ...
                    model.instances.track_id==issue.focus_track_id,1);
                label=0; if ~isempty(hit), label=double(model.instances.mask_label(hit)); end
                obj.Viewer.selectDisplayLayer(provider); obj.Viewer.openObjects();
                obj.Viewer.selectObjectFamily(provider,issue.family_id,label);
            catch err, obj.status(err.message);
            end
        end
        function opened=openROI(obj)
            opened=false;
            try
                assert(obj.sourceValid(),'detecdivui:ClassifierContext','The dataset changed. Reopen Ground Truth.');
                obj.Viewer.showClassifierROI(obj.Classifier,obj.RoiIndex); obj.Viewer.Host.focusWidget('Image');
                opened=true;
            catch err, obj.status(err.message);
            end
        end
        function nextUnreviewed(obj)
            try
                assert(obj.Owner.annotationContextMatches(obj.Classifier,obj.RoiIndex,obj.Source,false), ...
                    'detecdivui:ClassifierContext','Open this ROI in Image first.');
                obj.refresh(); candidates=obj.Session.trainingFrames(); incomplete=false(size(candidates));
                components=obj.Session.Spec.components;
                for component=reshape(components([components.required]),1,[])
                    if ~strcmp(component.coverageUnit,'frame'), continue; end
                    at=find(strcmp({obj.Summary.entry.review.component_id},component.id),1);
                    reviewed=false(size(candidates));
                    if ~isempty(at)
                        mask=obj.Summary.entry.review(at).frames; valid=candidates<=numel(mask);
                        reviewed(valid)=logical(mask(candidates(valid)));
                    end
                    incomplete=incomplete|~reviewed;
                end
                candidates=candidates(incomplete);
                if isempty(candidates), obj.status('No unreviewed frames within frame bounds'); return; end
                after=candidates(candidates>obj.Viewer.annotationFrame());
                frame=candidates(1); if ~isempty(after), frame=after(1); end
                obj.Viewer.navigateDataFrame(obj.Source,frame); obj.onFrame();
            catch err, obj.status(err.message);
            end
        end
        function delete(obj)
            obj.deleteFindings();
            if isgraphics(obj.Figure), delete(obj.Figure); end
        end
    end
    methods (Access=private)
        function yes=frameReviewed(obj,frame)
            yes=true; components=obj.Session.Spec.components;
            ids={components([components.required] & strcmp({components.coverageUnit},'frame')).id};
            for id=reshape(ids,1,[])
                at=find(strcmp({obj.Summary.entry.review.component_id},id{1}),1);
                if isempty(at) || frame>numel(obj.Summary.entry.review(at).frames) || ~obj.Summary.entry.review(at).frames(frame)
                    yes=false; return;
                end
            end
        end
        function selection=selection(obj,action)
            frames=obj.Session.trainingFrames(); current=obj.Viewer.annotationFrame();
            selected=obj.selectedFrames(frames,current); components=obj.Session.Spec.components;
            unit='frame'; if strcmp(obj.Scope.Value,'roi'), unit='roi'; end
            ids={components([components.required] & strcmp({components.coverageUnit},unit)).id};
            if ismember(action,{'review','unreview'})
                assert(~isempty(ids),'detecdivui:ClassifierReviewScope','No required components use this scope.');
                assert(~isempty(selected)||strcmp(unit,'roi'),'detecdivui:ClassifierReviewScope','The current frame is outside the training bounds.');
            end
            selection=struct('frames',selected,'components',{ids},'trainingFrames',frames,'annotationId',obj.Session.Spec.id);
        end
        function frames=selectedFrames(obj,trainingFrames,current)
            switch obj.Scope.Value
                case 'frame', frames=trainingFrames(trainingFrames==current);
                case 'through', frames=trainingFrames(trainingFrames<=current);
                otherwise, frames=trainingFrames;
            end
        end
        function yes=sourceValid(obj)
            yes=isvalid(obj.Classifier) && obj.RoiIndex<=numel(obj.Classifier.roi) && ...
                isequal(obj.Classifier.roi(obj.RoiIndex),obj.Source);
        end
        function finish(obj)
            obj.Busy=false; obj.refreshAccess();
        end
        function status(obj,message)
            obj.Status.Text=message; obj.Status.Tooltip=message;
            obj.Owner.annotationStatus(message);
        end
        function deleteFindings(obj)
            if isgraphics(obj.Findings), delete(obj.Findings); end
            obj.Findings=[];
        end
    end
end
