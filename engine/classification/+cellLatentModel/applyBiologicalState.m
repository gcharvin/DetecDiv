function [model,report] = applyBiologicalState(model,familyId,result,param)
%CELLLATENTMODEL.APPLYBIOLOGICALSTATE Expose confident states on cell objects.
%
% Rich probabilities remain in the biological-state sidecar. The canonical
% schema-v1 object model receives only one editable/displayable state_id per
% cell instance; uncertain frames deliberately remain state_id 0.

report = struct('enabled',false,'axis','none','records',0, ...
    'active',0,'inactive',0,'uncertain',0,'unmatched',0);
if ~logical(param.materializeCellStates) || ...
        strcmp(param.primaryStateAxis,'none')
    return;
end
if ~strcmp(param.primaryStateAxis,'budding')
    error('cellLatentModel:UnsupportedStateAxis', ...
        'Unsupported primary state axis "%s".',param.primaryStateAxis);
end
if ~isstruct(result) || ~isfield(result,'biological_state') || ...
        ~isstruct(result.biological_state) || ...
        ~isfield(result.biological_state,'records')
    error('cellLatentModel:MissingBiologicalState', ...
        'Cannot materialize states without biological_state.records.');
end

records = result.biological_state.records;
model = cellModel.normalize(model);
[model,inactiveId] = ensureState(model,'budding: inactive',[74 144 226]);
[model,activeId] = ensureState(model,'budding: active',[255 179 0]);
familyRows = model.instances.family_id == uint32(familyId);
model.instances.state_id(familyRows) = uint16(0);

report.enabled = true;
report.axis = 'budding';
report.records = numel(records);
report.inactive_state_id = double(inactiveId);
report.active_state_id = double(activeId);
report.negative_threshold = double(param.stateNegativeThreshold);
report.positive_threshold = double(param.statePositiveThreshold);
for i = 1:numel(records)
    record = records(i);
    if ~isfield(record,'track_id') || ~isfield(record,'frame') || ...
            ~isfield(record,'active_bud_probability')
        report.unmatched = report.unmatched + 1;
        continue;
    end
    rows = find(familyRows & ...
        model.instances.track_id == uint64(record.track_id) & ...
        model.instances.frame == uint32(record.frame));
    if numel(rows) ~= 1
        report.unmatched = report.unmatched + 1;
        continue;
    end
    probability = double(record.active_bud_probability);
    if ~isscalar(probability) || ~isfinite(probability) || ...
            probability < 0 || probability > 1
        report.unmatched = report.unmatched + 1;
    elseif probability >= param.statePositiveThreshold
        model.instances.state_id(rows) = activeId;
        report.active = report.active + 1;
    elseif probability <= param.stateNegativeThreshold
        model.instances.state_id(rows) = inactiveId;
        report.inactive = report.inactive + 1;
    else
        report.uncertain = report.uncertain + 1;
    end
end
model = cellModel.normalize(model);
cellModel.validate(model,'Throw',true);
end

function [model,stateId] = ensureState(model,name,color)
hit = find(strcmp(model.states.name,name),1,'first');
if isempty(hit)
    stateId = max([model.states.state_id; uint16(0)]) + uint16(1);
    row = numel(model.states.state_id) + 1;
    model.states.state_id(row,1) = stateId;
    model.states.name{row,1} = name;
    model.states.color_rgb(row,:) = uint8(color);
else
    stateId = model.states.state_id(hit);
end
end
