function fig = dataseriesLSTMAnnotation(classif, roiIndex, session, varargin)
%DATASERIESLSTMANNOTATION Trace-based editor; all domain edits use the backend.
p=inputParser;p.addParameter('Visible','on');p.parse(varargin{:});
if nargin<2||isempty(roiIndex),roiIndex=1;end
if nargin<3||isempty(session),session=classif.annotationSession(roiIndex);end
fig=uifigure('Name',['Numeric LSTM annotation — ' classif.strid], ...
    'Position',[150 100 1100 780],'Visible',p.Results.Visible,'Tag','NumericLSTMAnnotation');
grid=uigridlayout(fig,[6 1]);grid.RowHeight={36,26,'1x',140,44,30};
top=uigridlayout(grid,[1 8]);top.ColumnWidth={35,90,50,90,32,32,50,'1x'};
uilabel(top,'Text','ROI');roiChoice=uidropdown(top,'Items',cellstr(string(1:numel(classif.roi))), ...
    'Value',num2str(roiIndex),'Tag','RoiSelector');
uilabel(top,'Text','Frame');frame=uispinner(top,'Limits',[1 Inf],'Value',1,'Step',1,'Tag','FrameSelector');
previous=uibutton(top,'Text','◀','Tag','PreviousAnnotationUnit','Tooltip','Previous annotation interval (left arrow)');
next=uibutton(top,'Text','▶','Tag','NextAnnotationUnit','Tooltip','Next annotation interval (right arrow)');
uilabel(top,'Text','Mode');modeLabel=uilabel(top,'Text','');
[classKeys,~]=detecdiv_prefs_get_shortcuts();classes=cellstr(string(classif.classes(:)'));
legend=cell(1,min(numel(classes),numel(classKeys)));
for shortcutIndex=1:numel(legend)
    legend{shortcutIndex}=sprintf('%s: %s',upper(classKeys{shortcutIndex}),classes{shortcutIndex});
end
hint=uilabel(grid,'Text',[strjoin(legend,'   ') '     ← / →: previous / next annotation unit'],'Tag','AnnotationShortcuts');
hint.Layout.Row=2;
panel=uipanel(grid);body=uigridlayout(panel,[1 2]);body.ColumnWidth={250,'1x'};
choicesPanel=uipanel(body,'Title','Visible dataseries');choiceGrid=uigridlayout(choicesPanel,[1 1]);choiceGrid.Scrollable='on';
plots=uigridlayout(body,[1 1]);plots.Scrollable='on';
labelAxes=uiaxes(grid);labelAxes.Layout.Row=4;labelAxes.Tag='NumericStateLabels';
bottom=uigridlayout(grid,[1 10]);bottom.ColumnWidth={40,75,25,75,60,'1x',85,85,85,85};
uilabel(bottom,'Text','From');first=uieditfield(bottom,'numeric','Value',1,'Tag','FromFrame');
uilabel(bottom,'Text','To');last=uieditfield(bottom,'numeric','Value',1,'Tag','ToFrame');
uilabel(bottom,'Text','State');stateItems=classes;
for shortcutIndex=1:numel(legend)
    stateItems{shortcutIndex}=sprintf('%s — %s',upper(classKeys{shortcutIndex}),classes{shortcutIndex});
end
label=uidropdown(bottom,'Items',[stateItems {'undefined'}],'ItemsData',[classes {'undefined'}], ...
    'Value',classes{1},'Tag','StateLabel');
assign=uibutton(bottom,'Text','Assign','Tag','AssignState');
review=uibutton(bottom,'Text','Reviewed');unreview=uibutton(bottom,'Text','Unreview');
validate=uibutton(bottom,'Text','Validate','Tag','ValidateStates');
status=uilabel(grid,'Text','');axesList=gobjects(0);cursor=gobjects(0);bands=gobjects(0);
traceChecks=gobjects(0);visibleTraces=[];limitListeners={};n=0;activeFrames=[];
fig.UserData=struct('Classifier',classif,'AssignButton',assign,'Frame',frame,'Label',label);
roiChoice.ValueChangedFcn=@(~,~)changeRoi();frame.ValueChangedFcn=@(~,~)position();
assign.ButtonPushedFcn=@(~,~)apply();review.ButtonPushedFcn=@(~,~)reviewUnit(true);
unreview.ButtonPushedFcn=@(~,~)reviewUnit(false);validate.ButtonPushedFcn=@(~,~)validateRoi();
previous.ButtonPushedFcn=@(~,~)navigate(-1);next.ButtonPushedFcn=@(~,~)navigate(1);
fig.WindowKeyPressFcn=@(~,event)keyPress(event);
loadRoi();
    function changeRoi()
        roiIndex=str2double(roiChoice.Value);session=classif.annotationSession(roiIndex);loadRoi();
    end
    function loadRoi()
        try
            r=classif.roi(roiIndex);[X,schema]=lstm_timeseries.features(classif,r);
            n=size(X,2);frame.Limits=[1 max(2,n)];frame.Value=1;
            for listenerIndex=1:numel(limitListeners)
                if isvalid(limitListeners{listenerIndex}),delete(limitListeners{listenerIndex});end
            end
            limitListeners={};delete(plots.Children);delete(choiceGrid.Children);
            plots.RowHeight=repmat({150},1,size(X,1));
            if numel(visibleTraces)~=size(X,1),visibleTraces=true(size(X,1),1);end
            choiceGrid.RowHeight=[{28} repmat({28},1,size(X,1))];
            toggleButtons=uigridlayout(choiceGrid,[1 2]);toggleButtons.Padding=[0 0 0 0];
            uibutton(toggleButtons,'Text','Show all','Tag','ShowAllTraces','ButtonPushedFcn',@(~,~)showAll(true));
            uibutton(toggleButtons,'Text','Hide all','Tag','HideAllTraces','ButtonPushedFcn',@(~,~)showAll(false));
            axesList=gobjects(size(X,1)+1,1);cursor=gobjects(size(axesList));bands=gobjects(size(axesList));
            traceChecks=gobjects(size(X,1),1);
            for k=1:size(X,1)
                ax=uiaxes(plots);ax.Layout.Row=k;
                line=plot(ax,1:n,X(k,:));line.PickableParts='none';
                caption=schema(k).selector;
                if schema(k).column>1,caption=sprintf('%s — component %d',caption,schema(k).column);end
                title(ax,caption,'Interpreter','none');ax.XLim=[1 max(2,n)];
                checkCaption=sprintf('%d. %s',k,schema(k).variable);
                if schema(k).column>1,checkCaption=sprintf('%s [%d]',checkCaption,schema(k).column);end
                traceChecks(k)=uicheckbox(choiceGrid,'Text',checkCaption,'Tooltip',caption, ...
                    'Value',visibleTraces(k),'Tag',sprintf('VisibleTrace%d',k), ...
                    'ValueChangedFcn',@(~,~)changeVisibility());
                traceChecks(k).Layout.Row=k+1;
                axesList(k)=ax;cursor(k)=xline(ax,1,'r');ax.ButtonDownFcn=@(src,~)pick(src);
                bands(k)=newBand(ax);
            end
            axesList(end)=labelAxes;
            labelAxes.ButtonDownFcn=@(src,~)pick(src);linkaxes(axesList,'x');
            p=lstm_timeseries.parameters(classif);modeLabel.Text=[p.outputMode ' — ' r.id ' — bounds ' trainingBounds.text(session.frameBounds())];
            renderLabels();
            for k=1:numel(axesList)
                limitListeners{k}=addlistener(axesList(k),'YLim','PostSet',@(~,~)refreshBands());
            end
            firstFrame=trainingBounds.frames(classif,r,n,[]);
            if ~isempty(firstFrame),frame.Value=firstFrame(1);end
            changeVisibility();position();status.Text='Select an annotation unit and press its class key, or Assign. Changes are saved.';
        catch ME,status.Text=ME.message;end
    end
    function pick(ax)
        point=ax.CurrentPoint;frame.Value=max(1,min(frame.Limits(2),round(point(1,1))));position();
    end
    function keyPress(event)
        modifiers=string(event.Modifier);
        if any(ismember(lower(modifiers),["control","alt","command","meta"])),return;end
        % Let editable numeric controls retain their ordinary typing/cursor keys.
        if isequal(fig.CurrentObject,first)||isequal(fig.CurrentObject,last)||isequal(fig.CurrentObject,frame),return;end
        key=lower(char(string(event.Key)));
        if strcmp(key,'leftarrow'),navigate(-1);return;end
        if strcmp(key,'rightarrow'),navigate(1);return;end
        index=find(strcmpi(classKeys,key),1);
        if isempty(index)||index>numel(classes)||~strcmp(assign.Enable,'on'),return;end
        label.Value=classes{index};apply();
    end
    function navigate(direction)
        if n<1,return;end
        frame.Value=lstm_timeseries.adjacentAnnotationFrame(classif,classif.roi(roiIndex),round(frame.Value),direction,n);
        position();
    end
    function changeVisibility()
        for k=1:numel(traceChecks)
            visibleTraces(k)=traceChecks(k).Value;
            if visibleTraces(k),axesList(k).Visible='on';plots.RowHeight{k}=150;
            else,axesList(k).Visible='off';plots.RowHeight{k}=0;end
            % Axes.Visible hides decorations; its children must also be hidden.
            set(axesList(k).Children,'Visible',axesList(k).Visible);
        end
        refreshBands();
    end
    function showAll(yes)
        for k=1:numel(traceChecks),traceChecks(k).Value=yes;end
        changeVisibility();
    end
    function band=newBand(ax)
        ax.YLim=ax.YLim; % Keep the shading out of automatic data-limit changes.
        hold(ax,'on');band=patch(ax,NaN(1,4),NaN(1,4),[.45 .45 .45], ...
            'FaceAlpha',.16,'EdgeColor','none','HitTest','off','PickableParts','none', ...
            'Tag','CurrentAnnotationInterval');hold(ax,'off');uistack(band,'bottom');
    end
    function refreshBands()
        for k=1:numel(bands)
            if ~isgraphics(bands(k)),continue;end
            if isempty(activeFrames)||~strcmp(axesList(k).Visible,'on'),bands(k).Visible='off';continue;end
            x=[activeFrames(1)-.5 activeFrames(end)+.5];y=axesList(k).YLim;
            bands(k).XData=x([1 2 2 1]);bands(k).YData=y([1 1 2 2]);bands(k).Visible='on';
        end
    end
    function position()
        r=classif.roi(roiIndex);classifierBinding.numericSeries(r);
        [f,grouped]=lstm_timeseries.annotationFrames(classif,r,round(frame.Value),n);
        activeFrames=f;refreshBands();
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
        index=find(strcmp({r.data.groupid},classif.strid),1);
        y=zeros(n,1);if ~isempty(index)&&ismember('id_training',r.data(index).data.Properties.VariableNames),y=r.data(index).data.id_training;end
        line=stairs(labelAxes,1:numel(y),y);line.PickableParts='none';
        labelAxes.YTick=0:numel(classif.classes);labelAxes.YTickLabel=[{'undefined'} cellstr(string(classif.classes(:)'))];
        labelAxes.YLim=[-0.5 numel(classif.classes)+0.5];title(labelAxes,'Reviewed state labels');xlabel(labelAxes,'Absolute ROI frame');
        labelAxes.XLim=[1 max(2,n)];
        labelAxes.Visible='on';
        cursor(end)=xline(labelAxes,frame.Value,'r');labelAxes.ButtonDownFcn=@(src,~)pick(src);
        bands(end)=newBand(labelAxes);
    end
end
