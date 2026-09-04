function context = score_latentSignalContext(app)
%SCORE_LATENTSIGNALCONTEXT Resolve the selected custom-signal object.
context=struct('enabled',false,'task','','definition',struct(), ...
    'componentId','','roi',[],'frame',NaN,'familyId',uint32(0), ...
    'objectId',uint64(0),'trackId',uint64(0),'maskLabel',uint32(0), ...
    'value',[],'hasTarget',false);
try
    session=app.AnnotationSession;
    if isempty(session)||~isvalid(session), return; end
    if ~strcmpi(char(string(session.Spec.package)),'cellLatentSignal'), return; end
    components=session.Spec.components;
    hit=find(ismember({components.kind}, ...
        {'object_classification','object_regression'}),1,'first');
    if isempty(hit), return; end
    component=components(hit);
    definition=component.groundTruth.signalDefinition;
    context.enabled=true;
    context.task=char(extractAfter(string(component.kind),'object_'));
    context.definition=definition;
    context.componentId=component.id;
    context.roi=session.Roi;
    context.frame=double(context.roi.display.frame);
    label=double(app.SelectedObjectLabelCell);
    if ~isscalar(label)||~isfinite(label)||label<=0, return; end
    [model,~]=context.roi.loadCellModel('MigrateLegacy',true);
    [~,familyId]=cellModel.familyIndex(model,definition.family);
    if isempty(familyId), return; end
    row=find(model.instances.family_id==familyId & ...
        model.instances.frame==uint32(context.frame) & ...
        model.instances.mask_label==uint32(label),1,'first');
    if isempty(row), return; end
    context.familyId=familyId;
    context.objectId=model.instances.object_id(row);
    context.trackId=model.instances.track_id(row);
    context.maskLabel=model.instances.mask_label(row);
    idx=find(arrayfun(@(x)strcmp(char(string(x.groupid)), ...
        definition.ground_truth_group),context.roi.data),1);
    if isempty(idx), return; end
    tbl=context.roi.data(idx).data;
    targetRow=find(tbl.ObjectId==context.objectId,1,'first');
    if isempty(targetRow), return; end
    value=tbl.(definition.value_field)(targetRow);
    context.value=value;
    if strcmp(context.task,'classification')
        context.hasTarget=~isundefined(value)&&string(value)~="undefined";
    else
        context.hasTarget=isfinite(double(value));
    end
catch
end
end
