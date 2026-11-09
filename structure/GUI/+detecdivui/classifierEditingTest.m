function classifierEditingTest(preview)
%CLASSIFIEREDITINGTEST Typed contracts, read-only review and canonical GT.
if nargin<1, preview=''; end
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
c=classi(folder,'Editor',1); c.classifierPkg='cellposesam';
c.category={'Pixel'}; c.classes={'cell'}; c.channelName={'Phase'};
c.trainingParam=struct('n_epochs',uint16(10),'learning_rate',.01,'verbose',false, ...
    'mode',{{'fast','accurate','fast'}},'diameter',NaN);
c.executionParam=struct('outputType','segmentation','diameter',NaN);
r=roi('Training ROI',[1 1 12 16]); r.path=c.path;
r.image=repmat(reshape(uint16(100:102),1,1,1,3),16,12,2,1);
r.channelid=[1 2]; r.display.channel={'Phase','Fluorescence'};
r.save(); c.roi=r; c.trainingset=1;
v=detecdiv_ui([],'Visible','off','DiscoverWorkspace',false,'LayoutFile','', ...
    'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanup=onCleanup(@()delete(v)); v.Classifiers.add(c);
assert(strcmp(v.Classifiers.Mode,'Review') && ~v.annotationEditingAllowed());
assert(~v.Classifiers.initializeGT(c,1,'Blank GT'));
spec=annotationManager.specForClassifier(c); gt=spec.components(1).groundTruth.channel;
assert(isempty(r.findChannelID(gt))); % Browsing and Review never initialize GT.
v.openContourTool(); assert(isempty(v.Masks)||~v.Masks.Active);
v.Classifiers.setMode('Edit'); assert(v.annotationEditingAllowed());
scope=findall(v.widgetFigure('Classifier'),'Tag','classifier-parameter-scope');
scope.Value='Training Parameters'; scope.ValueChangedFcn(scope,[]);
e=v.Classifiers.editParameters(); e.Figure.Visible='off';
assert(isa(e.Controls.n_epochs,'matlab.ui.control.NumericEditField'));
assert(isa(e.Controls.mode,'matlab.ui.control.DropDown'));
assert(strcmp(e.Controls.diameter.Value,'auto'));
assert(strcmp(e.Controls.verbose.Visible,'off'));
advanced=findall(e.Figure,'Tag','classifier-show-advanced');
advanced.Value=true; advanced.ValueChangedFcn(advanced,[]);
assert(strcmp(e.Controls.verbose.Visible,'on'));
e.Controls.n_epochs.Value=20; e.Controls.mode.Value='accurate';
assert(c.trainingParam.n_epochs==10 && e.apply());
assert(isa(c.trainingParam.n_epochs,'uint16') && c.trainingParam.n_epochs==20);
assert(strcmp(c.trainingParam.mode{end},'accurate') && isnan(c.trainingParam.diameter));
scope.Value='Training Bindings'; scope.ValueChangedFcn(scope,[]);
before=c.trainingParam; e=v.Classifiers.editParameters(); e.Figure.Visible='off';
assert(isa(e.Controls.inputChannelName,'matlab.ui.control.DropDown'));
assert(strcmp(e.Controls.groundTruthChannelName.Editable,'off'));
e.Controls.inputChannelName.Value='Fluorescence'; assert(e.apply());
assert(isequal(c.channelName,{'Fluorescence'}) && isequal(c.dataset.channels,{'Fluorescence'}));
assert(isequaln(before,c.trainingParam));
scope.Value='Inference Parameters'; scope.ValueChangedFcn(scope,[]);
e=v.Classifiers.editParameters(); e.Figure.Visible='off';
assert(~isfield(e.Controls,'inputChannelName') && ~isfield(e.Controls,'groundTruthChannelName'));
e.Controls.outputType.Value='both'; e.Controls.diameter.Value='30';
assert(e.apply() && strcmp(c.executionParam.outputType,'both') && c.executionParam.diameter==30);
assert(isnan(c.trainingParam.diameter)); % Independent inference value.
e=v.Classifiers.editParameters(); e.Figure.Visible='off';
assert(strcmp(e.Controls.diameter.Value,'30'));
e.Controls.diameter.Value='auto'; pending=e.requestCurrent(); assert(isnan(pending.diameter));
e.Controls.min_size.Value=15; c.executionParam.diameter=31;
assert(~e.apply() && ~isfield(c.executionParam,'min_size')); delete(e);
scope.Value='Inference Bindings'; scope.ValueChangedFcn(scope,[]);
e=v.Classifiers.editParameters(); e.Figure.Visible='off';
assert(isfield(e.Controls,'inputChannelName') && ~isfield(e.Controls,'groundTruthChannelName'));
assert(isempty(fieldnames(e.requestCurrent()))); delete(e);

assert(v.Classifiers.initializeGT(c,1,'Blank GT'));
pix=r.findChannelID(gt); assert(isscalar(pix) && all(r.image(:,:,pix,:)==0,'all'));
assert(strcmp(v.activeLayer(),gt));
session=c.annotationSession(1); summary=session.summary();
assert(strcmp(summary.status,'draft') && summary.coverage.reviewed==0);
assert(v.Masks.Active); draft=v.Masks.current();
draft.edit(1,'paint',[5 6],1,1,false); v.contourChanged();
v.Classifiers.setMode('Review'); % A pending scientific draft must be resolved.
assert(strcmp(v.Classifiers.Mode,'Edit'));
cancel=findall(groot,'Tag','mask-close-cancel'); assert(isscalar(cancel));
cancel.ButtonPushedFcn(cancel,[]); draft.discard();
v.Classifiers.setMode('Review'); assert(~v.Masks.Active);
try
    v.Masks.assertEditable(draft,false); error('Test:Unprotected','Review allowed editing.');
catch err
    assert(strcmp(err.identifier,'detecdivui:ClassifierReview'));
end
assert(~v.Classifiers.initializeGT(c,1,'Blank GT'));
v.Classifiers.setMode('Edit'); v.openContourTool(); draft=v.Masks.current();
draft.edit(1,'paint',[5 6],1,1,false); v.Masks.action('save');
before=r.image; summary=session.summary(); revision=summary.revision;
assert(~v.Classifiers.initializeGT(c,1,'Blank GT')); % Reopen, never overwrite.
assert(isequal(r.image,before) && session.summary().revision==revision);
v.Classifiers.setMode('Review'); v.openObjects();
assert(~v.Masks.Active && ~isempty(v.Objects.ObjectsRows));
v.Objects.selectObject(1); assert(~isempty(findall(v.roiAxes(),'Tag','review-selection')));
assert(strcmp(findall(v.widgetFigure('Objects'),'Tag','objects-contours').Enable,'off'));
if ~isempty(preview)
    v.Classifiers.setMode('Edit'); v.Host.focusWidget('Classifier');
    scope.Value='Inference Parameters'; scope.ValueChangedFcn(scope,[]);
    e=v.Classifiers.editParameters(); drawnow; pause(.3); exportapp(e.Figure,preview); delete(e);
end
fprintf('Classifier editing test passed: typed training/inference, bindings, Review/Edit, staged edits and GT preservation.\n');
end
