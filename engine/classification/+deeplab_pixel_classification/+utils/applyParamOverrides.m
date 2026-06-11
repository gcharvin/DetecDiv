function tp = applyParamOverrides(tp, params)
% deeplab_pixel_classification.utils.applyParamOverrides
% Case-insensitive override of trainingParam fields.

if isempty(tp) || ~isstruct(tp) || ~isstruct(params)
    return;
end

fields = fieldnames(params);
targetFields = fieldnames(tp);
for i = 1:numel(fields)
    key = fields{i};
    hit = find(strcmpi(targetFields, key), 1, 'first');
    if ~isempty(hit)
        tp.(targetFields{hit}) = params.(key);
    end
end
end
