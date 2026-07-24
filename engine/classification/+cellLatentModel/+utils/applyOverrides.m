function out = applyOverrides(defaults,overrides)
%CELLLATENTMODEL.UTILS.APPLYOVERRIDES Overlay known or new struct fields.
out = defaults;
if ~isstruct(overrides), return; end
names = fieldnames(overrides);
for i = 1:numel(names)
    if strcmp(names{i},'tip'), continue; end
    out.(names{i}) = overrides.(names{i});
end
end
