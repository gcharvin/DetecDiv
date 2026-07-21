function out = applyParamOverrides(base, patch)
% trackastra.utils.applyParamOverrides  Shallow struct override.

out = base;
if nargin < 2 || ~isstruct(patch) || isempty(patch)
    return;
end
keys = fieldnames(patch);
for i = 1:numel(keys)
    if strcmp(keys{i}, 'tip')
        continue;
    end
    out.(keys{i}) = patch.(keys{i});
end
end
