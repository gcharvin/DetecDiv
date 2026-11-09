function selector = featureSelector(value)
%FEATURESELECTOR Canonical logical binding; separators are never file paths.
selector = strtrim(char(string(value)));
% Older Windows job snapshots mistakenly rewrote this logical separator.
% Accept their encoding so reopening a failed run does not retain the damage.
selector = strrep(selector, '\', '/');
parts = regexp(selector, '\s*/\s*', 'split');
if numel(parts) == 2
    selector = strjoin(cellfun(@strtrim, parts, 'UniformOutput', false), ' / ');
end
end
