function mode = divisionMode(model, family)
%CELLMODEL.DIVISIONMODE Explicit per-family topology; legacy is budding.
[~,id] = cellModel.familyIndex(model,family);
mode = 'budding';
if isempty(id) || ~isfield(model,'provenance') || ...
        ~isfield(model.provenance,'family_division_modes'),return;end
rows = model.provenance.family_division_modes;
hit = find(uint32([rows.family_id])==id);
if isempty(hit),return;end
if numel(hit)~=1,error('cellModel:AmbiguousDivisionMode','Duplicate family topology declarations.');end
mode=char(string(rows(hit).mode));
if ~any(strcmp(mode,{'budding','binary_fission'}))
    error('cellModel:InvalidDivisionMode','Unknown family division mode: %s',mode);
end
end
