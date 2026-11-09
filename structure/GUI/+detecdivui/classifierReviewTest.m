function classifierReviewTest(preview)
%CLASSIFIERREVIEWTEST Managed GT scope/readiness in the shared viewer.
if nargin<1, preview=''; end
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
c=classi(folder,'Review',1); c.classifierPkg='cellposesam'; c.category={'Pixel'}; c.classes={'cell'};
c.trainingParam=struct('n_epochs',10); c.executionParam=struct(); c.channelName={'Phase'};
r=roi('Review ROI',[1 1 14 18]); r.path=c.path;
r.image=repmat(uint16(100),18,14,1,4); r.channelid=1; r.display.channel={'Phase'}; r.save();
c.roi=r; c.trainingset=1; trainingBounds.setRoi(c,1,'2:4','FrameCount',4);
v=detecdiv_ui([],'Visible','off','DiscoverWorkspace',false,'LayoutFile','', ...
    'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
cleanup=onCleanup(@()delete(v)); v.Classifiers.add(c);
review=v.Classifiers.reviewGroundTruth(); review.hide();
assert(strcmp(v.Classifiers.Mode,'Review'));
assert(strcmp(findall(review.Figure,'Tag','classifier-review-mark').Enable,'off'));
review.perform('review'); [~,found]=annotationManager.entryForSpec(r,review.Session.Spec); assert(~found);
report=review.perform('findings'); assert(~report.valid && isgraphics(review.Findings));
[~,found]=annotationManager.entryForSpec(r,review.Session.Spec); assert(~found);
closeFindings(review);
v.Classifiers.setMode('Edit'); assert(v.Classifiers.initializeGT(c,1,'Blank GT'));
v.navigateDataFrame(r,2); scope=findall(review.Figure,'Tag','classifier-review-scope');
v.Masks.forgetCleanSource(r); sharedProject=shallow(); sharedProject.fov.roi=r;
draft=v.Masks.draftFor(r,review.Session.Spec.components(1).groundTruth.channel,sharedProject);
draft.edit(2,'paint',[6 7],1,1,false); v.contourChanged();
review.perform('review');
summary=review.Session.summary(); assert(summary.coverage.reviewed==0);
saveButton=findall(groot,'Tag','mask-close-save'); assert(isscalar(saveButton));
saveButton.ButtonPushedFcn(saveButton,[]);
summary=review.Session.summary(); assert(summary.coverage.reviewed==1 && summary.coverage.total==3);
assert(isequal(find(summary.entry.review(1).frames),2));
assert(contains(findall(review.Figure,'Tag','classifier-review-frame').Text,'Reviewed'));
table=findall(v.widgetFigure('Classifier'),'Tag','classifier-rois'); assert(strcmp(table.Data{1,5},'Draft'));
report=review.perform('validate');
assert(report.valid && ~isempty(report.warnings)); % Cellpose allows reviewed subsets.
assert(strcmp(table.Data{1,5},'Ready') && strcmp(table.Data{1,6},'1/3'));
assert(~isgraphics(review.Findings)); % Advisories never reopen findings on success.
assert(contains(findall(v.widgetFigure('Classifier'),'Tag','classifier-status').Text,'Ready'));
v.Classifiers.setFrameBounds(c,1,r,'2:3');
assert(strcmp(table.Data{1,5},'Draft') && review.Session.summary().coverage.total==2);
assert(~strcmp(review.Session.summary().validationStatus,'valid'));
review.perform('validate'); assert(strcmp(table.Data{1,5},'Ready'));
v.Classifiers.setFrameBounds(c,1,r,'2:4'); assert(strcmp(table.Data{1,5},'Draft'));
review.perform('validate'); assert(strcmp(table.Data{1,5},'Ready'));
review.nextUnreviewed(); assert(v.annotationFrame()==3);
scope.Value='through'; scope.ValueChangedFcn(scope,[]); review.perform('review');
assert(review.Session.summary().coverage.reviewed==2);
scope.Value='bounds'; scope.ValueChangedFcn(scope,[]); review.perform('review');
summary=review.Session.summary(); assert(isequal(find(summary.entry.review(1).frames),[2 3 4]));
% A metadata transition rebases clean editors; the next real mask save works.
scope.Value='frame'; scope.ValueChangedFcn(scope,[]);
draft=v.Masks.current(); draft.edit(3,'paint',[8 9],2,1,false); v.Masks.action('save');
assert(~draft.Dirty && ~draft.SaveFailed && strcmp(table.Data{1,5},'Draft'));
summary=review.Session.summary(); assert(summary.coverage.reviewed==2);
review.nextUnreviewed(); assert(v.annotationFrame()==3);
scope.Value='bounds'; review.perform('unreview'); report=review.perform('validate');
assert(~report.valid && strcmp(table.Data{1,5},'Invalid') && isgraphics(review.Findings));
closeFindings(review);
% The existing Score findings dialog is owned locally and navigates Image.
[model,imported]=cellModel.fromLegacy(r,'Channels',{review.Session.Spec.components(1).groundTruth.channel});
assert(imported.validation.ok);
family=model.families.family_id(1); exact=uint64(9007199254740992)+uint64(1);
at=find(model.instances.family_id==family & model.instances.frame==3,1); assert(~isempty(at));
model.instances.track_id(at)=exact; label=double(model.instances.mask_label(at));
model=cellModel.normalize(model); r.saveCellModel(model); v.annotationMetadataSaved(r);
issue=annotationManager.newValidationIssue('code','missing_track_reference', ...
    'summary','Inspect frame 3','message','Inspect frame 3.','focus_frame',uint32(3),'repairable',true, ...
    'family_id',family,'focus_track_id',exact);
report.issues=issue; report.errors=strings(0,1); report.warnings=strings(0,1);
review.showFindings(report); findings=review.Findings;
assert(strcmp(findall(findings,'Text','Repair selected link').Enable,'off'));
go=findall(findings,'Text','Go to selected'); go.ButtonPushedFcn(go,[]);
assert(v.annotationFrame()==3 && isgraphics(findings));
selection=v.selectedAnnotation(); assert(selection.family==family && selection.label==label);
assert(any([v.Objects.ObjectsRows.track]==exact)); closeFindings(review);
v.Classifiers.setMode('Review');
review.goToFinding(issue,struct('frame',3)); assert(~v.Masks.Active);
assert(~isempty(findall(v.roiAxes(),'Tag','review-selection')));
before=review.Session.summary().revision; review.perform('review');
assert(review.Session.summary().revision==before);
review.perform('findings'); assert(review.Session.summary().revision==before); closeFindings(review);
% A delayed operation cannot validate a different classifier/ROI context.
v.Classifiers.setMode('Edit'); v.openContourTool();
draft=v.Masks.current(); draft.edit(4,'paint',[10 11],3,1,false); v.contourChanged();
review.perform('validate'); discard=findall(groot,'Tag','mask-close-discard'); assert(isscalar(discard));
other=classi(folder,'Other',2); v.Classifiers.add(other);
discard.ButtonPushedFcn(discard,[]);
assert(review.Session.summary().revision==before);
assert(contains(findall(review.Figure,'Tag','classifier-review-status').Text,'Open this classifier ROI'));
review.openROI(); assert(isequal(v.Session.Classifier,c) && strcmp(v.Classifiers.Mode,'Review'));
if ~isempty(preview), review.show(); drawnow; pause(.2); exportapp(review.Figure,preview); end
window=review.Figure; delete(v); assert(~isgraphics(window));
fprintf('Classifier review passed: saved coverage, scoped frames, partial Ready, draft resolution, edit/save after validation, findings and stale context protection.\n');
end
function closeFindings(review)
if isgraphics(review.Findings), delete(review.Findings); end
end
