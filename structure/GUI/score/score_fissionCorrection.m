function handled = score_fissionCorrection(app, action, label)
%SCORE_FISSIONCORRECTION Guided, in-memory parent -> two daughters editor.
% State is owned by the image figure, so existing Score instances can use it.
if nargin<3,label=[];end
handled=false;
fig=app.ImageFigure;
if ~isgraphics(fig),return;end
key='ScoreBinaryFissionSelection';undoKey='ScoreBinaryFissionUndo';
state=[];if isappdata(fig,key),state=getappdata(fig,key);end
if strcmp(action,'active'),handled=~isempty(state);return;end
if strcmp(action,'cancel')
    handled=~isempty(state);clearState(fig,key);return;
end
[r,channel]=score_selectedObjectChannel(app);
if isempty(r),return;end
[m,status]=score_getCellModel(r);
if ~strcmp(status,'ok'),error('score:MissingCellModel','No editable cell model.');end
[provider,~,~,family]=score_resolveMaskProvider(r,channel);
if strcmp(action,'undo')
    if ~isappdata(fig,undoKey),error('score:NoFissionUndo','No fission correction to undo.');end
    last=getappdata(fig,undoKey);
    if ~isequal(r,last.roi)||~sameModel(m,last.after)
        error('score:FissionUndoChanged','Other edits occurred after this fission. Undo is unavailable to preserve them.');
    end
    r.cellModel=last.before;rmappdata(fig,undoKey);
    changed(app,last.report.frames);
    score_display(app,'refresh');return;
end
if strcmp(action,'start')
    if isempty(family)||~strcmp(cellModel.divisionMode(m,family),'binary_fission')
        error('score:NotBinaryFission','Select a binary-fission family.');
    end
    % In managed sessions only the explicit GT family/provider is writable.
    if ~isempty(app.AnnotationSession)&&isvalid(app.AnnotationSession)
        context=app.AnnotationSession.uiContext();preset=context.displayPreset;
        if ~any(strcmp(preset.editableChannels,provider))||~any(strcmp(preset.objectFamilies, ...
                m.families.name{find(m.families.family_id==family,1)}))
            error('score:FissionPredictionReadOnly','Select the editable GT channel, rather than a prediction.');
        end
    end
    parent=cellModel.findInstance(m,family,r.display.frame,app.SelectedObjectLabelCell);
    if isempty(parent)||parent.track_id==0,error('score:NoFissionParent','Double-click the parent on its last pre-division frame first.');end
    if r.display.frame>=size(r.image,4),error('score:NoFissionNextFrame','The last frame has no following daughter frame.');end
    clearState(fig,key);
    state=struct('roi',r,'channel',channel,'provider',provider,'family',family, ...
        'parentFrame',double(r.display.frame),'parentLabel',double(parent.mask_label), ...
        'parentTrack',parent.track_id,'daughters',[],'before',m,'banner',[]);
    setappdata(fig,key,state);
    r.display.frame=state.parentFrame+1;
    app.FrameSlider.Value=r.display.frame;app.FrameEditField.Value=r.display.frame;
    if isprop(app,'FrameEditField_2'),app.FrameEditField_2.Value=r.display.frame;end
    score_display(app,'refresh');
    prompt(fig,key,state);handled=true;return;
end
if ~strcmp(action,'pick')||isempty(state),return;end
handled=true;
if ~isequal(r,state.roi)||~strcmp(channel,state.channel)||~isequal(family,state.family)
    clearState(fig,key);
    error('score:FissionContextChanged','ROI or annotation channel changed: fission selection cancelled.');
end
if r.display.frame~=state.parentFrame+1
    error('score:FissionWrongFrame','Select both daughters on frame %u, or press Escape to cancel.',state.parentFrame+1);
end
if isempty(label)||label<=0,return;end
if ismember(label,state.daughters),return;end
if ~isequaln(m,state.before)
    clearState(fig,key);error('score:FissionModelChanged','The cell model changed during selection: restart the fission correction.');
end
state.daughters(end+1)=double(label);
if numel(state.daughters)<2,prompt(fig,key,state);return;end
% The pure backend returns only after both identity changes and both links
% validate. Failure never installs a partially edited model in the ROI.
[after,report]=cellModel.correctBinaryFission(m,state.family,state.parentFrame,state.parentLabel,state.daughters);
r.cellModel=after;
setappdata(fig,undoKey,struct('roi',r,'before',m,'after',after,'report',report));
clearState(fig,key);
changed(app,report.frames);
if ismethod(app,'syncLineageDisplayAfterEdit'),app.syncLineageDisplayAfterEdit();end
score_updateSelectedObjectFields(app);score_display(app,'refresh');
app.CellModelStatusLabel.Text=sprintf('Fission %u -> %u + %u at frame %u (unsaved)', ...
    report.parent_track_id,report.daughter_track_ids,report.event_frame);
end

function changed(app,frames)
% Selecting the event is not a human review of every propagated future ID.
r=score_selectedObjectChannel(app);frame=r.display.frame;
app.notifyAnnotationChanged('tracking',frame,'Save',false);
app.notifyAnnotationChanged('parentage',frame,'Save',false);
if ~isempty(app.AnnotationSession)&&isvalid(app.AnnotationSession)
    propagated=setdiff(frames,frame);
    if ~isempty(propagated)
        app.AnnotationSession.markUnreviewed('Components',{'tracking'}, ...
            'Frames',propagated,'Save',false);
    end
end
end
function prompt(fig,key,state)
text=sprintf('Fission: parent Track %u, frame %u. Click daughter %u/2 on frame %u. Esc or right-click: cancel.', ...
    state.parentTrack,state.parentFrame,numel(state.daughters)+1,state.parentFrame+1);
if isempty(state.banner)||~isgraphics(state.banner)
    state.banner=annotation(fig,'textbox',[.03 .91 .94 .08],'String',text, ...
        'BackgroundColor',[1 1 .75],'Color',[0 0 0],'EdgeColor',[.5 .4 0], ...
        'FitBoxToText','off','Interpreter','none','HitTest','off');
else,state.banner.String=text;end
fig.Name=text;fig.Pointer='crosshair';setappdata(fig,key,state);
end
function clearState(fig,key)
if isappdata(fig,key)
    state=getappdata(fig,key);
    if ~isempty(state)&&~isempty(state.banner)&&isgraphics(state.banner),delete(state.banner);end
    rmappdata(fig,key);
end
fig.Pointer='arrow';
end
function tf=sameModel(a,b)
% Explicit saving changes the timestamp, but must not disable this undo.
if isfield(a.provenance,'updated_at'),a.provenance=rmfield(a.provenance,'updated_at');end
if isfield(b.provenance,'updated_at'),b.provenance=rmfield(b.provenance,'updated_at');end
tf=isequaln(a,b);
end
