function score_setSelectedSignalGroundTruth(app)
%SCORE_SETSELECTEDSIGNALGROUNDTRUTH Persist the control value for one object.
context=score_latentSignalContext(app);
if ~context.enabled||context.objectId==0
    error('score:NoSignalObjectSelected','Select an object before assigning its signal target.');
end
if strcmp(context.task,'classification')
    classIndex=double(app.SelectedCellStateDropDown.Value);
    if classIndex<1||classIndex>numel(context.definition.classes)
        error('score:UndefinedSignalClass','Choose a defined signal class.');
    end
    value=string(context.definition.classes{classIndex});
else
    value=double(app.MasklabelEditField.Value);
end
cellLatentModel.signal.setGroundTruth(context.roi,context.definition, ...
    'ObjectIds',context.objectId,'Values',value,'Save',false);
app.notifyAnnotationChanged(context.componentId,context.frame,'Save',false);
score_updateSelectedSignalFields(app);
end
