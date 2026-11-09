function [selected,legacy]=reviewedFrames(classif,index,spec,component,requested)
%REVIEWEDFRAMES Evaluation may use disjoint frames, even for tracking models.
r=classif.roi(index);
selected=trainingBounds.frames(classif,index,annotationManager.frameCount(r),requested);
[entry,found]=annotationManager.entryForSpec(r,spec);legacy=~found;
if ~found,return;end
if strcmp(entry.status,'approved')
    state=annotationManager.inspect(r,spec,'VerifyHash',true,'ReviewFrames',selected);
    assert(~state.staleApproval,'classifierStats:StaleGroundTruth', ...
        'ROI %s GT changed after approval. Review and validate its current annotations.',r.id);
end
k=find(strcmp({entry.review.component_id},component.id),1);
if isempty(k),selected=[];return;end
review=entry.review(k);
if strcmp(component.coverageUnit,'roi')
    if ~review.complete,selected=[];end
else
    selected=intersect(selected,find(logical(review.frames)),'stable');
end
end
