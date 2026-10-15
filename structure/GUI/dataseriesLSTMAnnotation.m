function fig = dataseriesLSTMAnnotation(classif, roiIndex, session, varargin)
%DATASERIESLSTMANNOTATION Trace-based editor; all domain edits use the backend.
p=inputParser;p.addParameter('Visible','on');p.parse(varargin{:});
if nargin<2||isempty(roiIndex),roiIndex=1;end
if nargin<3||isempty(session),session=classif.annotationSession(roiIndex);end
fig=uifigure('Name',['Numeric LSTM annotation — ' classif.strid], ...
    'Position',[150 100 1100 780],'Visible',p.Results.Visible,'Tag','NumericLSTMAnnotation');
grid=uigridlayout(fig,[5 1]);grid.RowHeight={36,'1x',140,44,30};
top=uigridlayout(grid,[1 6]);top.ColumnWidth={35,150,50,100,50,'1x'};
uilabel(top,'Text','ROI');roiChoice=uidropdown(top,'Items',cellstr(string(1:numel(classif.roi))), ...
    'Value',num2str(roiIndex),'Tag','RoiSelector');
uilabel(top,'Text','Frame');frame=uispinner(top,'Limits',[1 Inf],'Value',1,'Step',1,'Tag','FrameSelector');
uilabel(top,'Text','Mode');modeLabel=uilabel(top,'Text','');
panel=uipanel(grid);plots=uigridlayout(panel,[1 1]);plots.Scrollable='on';
labelAxes=uiaxes(grid);labelAxes.Layout.Row=3;labelAxes.Tag='NumericStateLabels';
bottom=uigridlayout(grid,[1 10]);bottom.ColumnWidth={40,75,25,75,60,'1x',85,85,85,85};
uilabel(bottom,'Text','From');first=uieditfield(bottom,'numeric','Value',1,'Tag','FromFrame');
uilabel(bottom,'Text','To');last=uieditfield(bottom,'numeric','Value',1,'Tag','ToFrame');
uilabel(bottom,'Text','State');label=uidropdown(bottom,'Items',[cellstr(string(classif.classes(:)')) {'undefined'}],'Tag','StateLabel');
assign=uibutton(bottom,'Text','Assign','Tag','AssignState');
review=uibutton(bottom,'Text','Reviewed');unreview=uibutton(bottom,'Text','Unreview');
validate=uibutton(bottom,'Text','Validate','Tag','ValidateStates');
status=uilabel(grid,'Text','');axesList=gobjects(0);cursor=gobjects(0);
fig.UserData=struct('Classifier',classif,'AssignButton',assign,'Frame',frame,'Label',label);
roiChoice.ValueChangedFcn=@(~,~)changeRoi();frame.ValueChangedFcn=@(~,~)position();
assign.ButtonPushedFcn=@(~,~)apply();review.ButtonPushedFcn=@(~,~)reviewUnit(true);
unreview.ButtonPushedFcn=@(~,~)reviewUnit(false);validate.ButtonPushedFcn=@(~,~)validateRoi();
loadRoi();
    function changeRoi()
        roiIndex=str2double(roiChoice.Value);session=classif.annotationSession(roiIndex);loadRoi();
    end
    function loadRoi()
        try
            r=classif.roi(roiIndex);[X,schema]=lstm_timeseries.features(classif,r);
            n=size(X,2);frame.Limits=[1 max(2,n)];frame.Value=1;
            delete(plots.Children);plots.RowHeight=repmat({150},1,size(X,1));
            axesList=gobjects(size(X,1)+1,1);cursor=gobjects(size(axesList));
            for k=1:size(X,1)
                ax=uiaxes(plots);ax.Layout.Row=k;
                line=plot(ax,1:n,X(k,:));line.PickableParts='none';
                title(ax,sprintf('%s — column %d',schema(k).selector,schema(k).column),'Interpreter','none');
                axesList(k)=ax;cursor(k)=xline(ax,1,'r');ax.ButtonDownFcn=@(src,~)pick(src);
            end
            axesList(end)=labelAxes;
            labelAxes.ButtonDownFcn=@(src,~)pick(src);linkaxes(axesList,'x');
            p=lstm_timeseries.parameters(classif);modeLabel.Text=[p.outputMode ' — ' r.id ' — bounds ' trainingBounds.text(session.frameBounds())];
            renderLabels();position();status.Text='Select a frame, window or video and assign a state. Changes are saved as managed annotations.';
        catch ME,status.Text=ME.message;end
    end
    function pick(ax)
        point=ax.CurrentPoint;frame.Value=max(1,min(frame.Limits(2),round(point(1,1))));position();
    end
    function position()
        r=classif.roi(roiIndex);classifierBinding.numericSeries(r);
        [f,grouped]=lstm_timeseries.annotationFrames(classif,r,round(frame.Value),annotationManager.frameCount(r));
        if isempty(f)
            assign.Enable='off';review.Enable='off';unreview.Enable='off';
            status.Text='Outside a complete annotation unit or training bounds.';return;
        end
        assign.Enable='on';review.Enable='on';unreview.Enable='on';first.Value=f(1);last.Value=f(end);
        state='on';if grouped,state='off';end
        first.Enable=state;last.Enable=state;
        for k=1:numel(cursor),if isgraphics(cursor(k)),cursor(k).Value=frame.Value;end,end
    end
    function apply()
        try
            assert(isfinite(first.Value)&&isfinite(last.Value)&&first.Value>=1&&last.Value>=first.Value, ...
                'lstm_timeseries:AnnotationRange','Select a valid increasing frame range.');
            range=round(first.Value):round(last.Value);
            f=lstm_timeseries.assignLabel(classif,roiIndex,label.Value,round(frame.Value),'Frames',range);
            renderLabels();position();status.Text=sprintf('Saved %s on frames %d:%d.',label.Value,f(1),f(end));
        catch ME,status.Text=ME.message;end
    end
    function reviewUnit(yes)
        try
            r=classif.roi(roiIndex);[f,grouped]=lstm_timeseries.annotationFrames(classif,r,round(frame.Value),annotationManager.frameCount(r));
            if ~grouped,f=round(first.Value):round(last.Value);end
            f=intersect(f,session.trainingFrames(),'stable');
            assert(~isempty(f),'lstm_timeseries:AnnotationRange','No complete annotation unit is selected.');
            if yes,session.markReviewed('Frames',f);else,session.markUnreviewed('Frames',f);end
            status.Text='Review coverage saved.';
        catch ME,status.Text=ME.message;end
    end
    function validateRoi()
        try
            report=session.validate();
            if report.valid,status.Text='Annotation is valid in the selected training bounds.';
            else,status.Text=char(strjoin(string(report.errors),' '));end
        catch ME,status.Text=ME.message;end
    end
    function renderLabels()
        r=classif.roi(roiIndex);classifierBinding.numericSeries(r);
        index=find(strcmp({r.data.groupid},classif.strid),1);n=annotationManager.frameCount(r);
        y=zeros(n,1);if ~isempty(index)&&ismember('id_training',r.data(index).data.Properties.VariableNames),y=r.data(index).data.id_training;end
        line=stairs(labelAxes,1:numel(y),y);line.PickableParts='none';
        labelAxes.YTick=0:numel(classif.classes);labelAxes.YTickLabel=[{'undefined'} cellstr(string(classif.classes(:)'))];
        labelAxes.YLim=[-0.5 numel(classif.classes)+0.5];title(labelAxes,'Reviewed state labels');xlabel(labelAxes,'Absolute ROI frame');
        labelAxes.XLim=[1 max(2,n)];
        cursor(end)=xline(labelAxes,frame.Value,'r');labelAxes.ButtonDownFcn=@(src,~)pick(src);
    end
end
