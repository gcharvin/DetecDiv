classdef AnnotationLayersDialog < handle
    % Review a concrete layer plan before creating any scientific data.
    properties (SetAccess=private)
        Figure
        Draft
    end
    properties (Access=private)
        Viewer
        Source
        Status
        Progress
        Create
        Busy=false
    end
    methods
        function obj=AnnotationLayersDialog(viewer,draft)
            obj.Viewer=viewer; obj.Draft=draft; obj.Source=draft.Source;
            obj.Figure=uifigure('Name','Dedicated Mask Layers','Position',[260 190 740 340], ...
                'Visible','off','Tag','annotation-layers-dialog','CloseRequestFcn',@(~,~)obj.close());
            root=uigridlayout(obj.Figure,[4 1]); root.RowHeight={24,'1x',28,22};
            uilabel(root,'Text',obj.Source.id,'Interpreter','none','FontWeight','bold');
            changes=draft.Plan.changes; rows=cell(numel(changes),3);
            for k=1:numel(changes), rows(k,:)={changes(k).result,changes(k).source,changes(k).layer}; end
            uitable(root,'Data',rows,'RowName',{},'ColumnName',{'Tracking result','Copy masks from','New layer'}, ...
                'ColumnEditable',false(1,3),'ColumnWidth',{'auto','auto','auto'},'Tag','annotation-layer-plan');
            buttons=uigridlayout(root,[1 2]); buttons.Padding=[0 0 0 0];
            uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.close());
            obj.Create=uibutton(buttons,'Text','Create Layers','Tag','annotation-layers-create','ButtonPushedFcn',@(~,~)obj.apply());
            obj.Status=uilabel(root,'Text','','Interpreter','none','Tag','annotation-layers-status');
            obj.Progress=detecdivui.Progress(root,obj.Status,'annotation-layers-progress');
            obj.Figure.WindowStyle='modal'; obj.Figure.Visible='on';
        end
        function applied=apply(obj)
            applied=false; if obj.Busy, return; end
            obj.Busy=true; cleanup=onCleanup(@()obj.finish());
            try
                assert(obj.Viewer.annotationEditingAllowed(obj.Source),'detecdivui:ClassifierReview','Switch this classifier to Edit first.');
                c=obj.Viewer.contourContext();
                assert(isequal(c.roi,obj.Source),'detecdivui:AnnotationContext','Return to this ROI before creating its mask layers.');
                assert(isempty(obj.Viewer.Masks)||~obj.Viewer.Masks.dirty(obj.Source), ...
                    'detecdivui:AnnotationDraft','Save or discard pending annotations before creating mask layers.');
                activity=obj.Progress.begin('Creating dedicated mask layers...'); %#ok<NASGU>
                obj.Draft.save(); obj.Viewer.annotationMetadataSaved(obj.Source); obj.Viewer.annotationSaved(obj.Source);
                original=find(strcmp({obj.Viewer.DisplayModel.Layers.name},obj.Draft.Plan.source),1);
                if ~isempty(original), obj.Viewer.DisplayModel.setVisible(original,false); end
                obj.Viewer.selectDisplayLayer(obj.Draft.Plan.changes(1).layer);
                obj.Viewer.openAnnotations(); applied=true; obj.Figure.Visible='off';
            catch err
                obj.Status.Text=err.message; obj.Status.Tooltip=err.message;
                if obj.Draft.SaveFailed, obj.Create.Text='Retry'; end
            end
        end
        function close(obj)
            if obj.Busy, return; end
            if obj.Draft.SaveFailed
                obj.Status.Text='The save is incomplete. Retry before closing this operation.'; return;
            end
            delete(obj);
        end
        function delete(obj)
            obj.Draft.recover();
            if isgraphics(obj.Figure), delete(obj.Figure); end
        end
    end
    methods (Access=private)
        function finish(obj)
            if isvalid(obj), obj.Busy=false; end
        end
    end
end
