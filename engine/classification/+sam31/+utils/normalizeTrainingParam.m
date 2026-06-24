function tp = normalizeTrainingParam(tp)
% sam31.utils.normalizeTrainingParam
% Compact legacy SAM31 trainingParam structs to the current user-facing set.

defaults = sam31.utils.defaultTrainingParam();
if nargin < 1 || isempty(tp) || ~isstruct(tp)
    tp = defaults;
    return;
end

out = defaults;
keys = fieldnames(defaults);
keys(strcmp(keys, 'tip')) = [];
for i = 1:numel(keys)
    key = keys{i};
    if isfield(tp, key) && ~isempty(tp.(key))
        out.(key) = copyVisibleValue(defaults.(key), tp.(key), key);
    end
end

tp = out;
end

function value = copyVisibleValue(defaultValue, sourceValue, key)
value = sourceValue;
if iscell(defaultValue) && ~isempty(defaultValue) && all(cellfun(@ischar, defaultValue))
    selected = sourceValue;
    if iscell(sourceValue) && ~isempty(sourceValue)
        selected = sourceValue{end};
    end
    selected = normalizeEnumSelection(key, selected);
    value = defaultValue;
    value{end} = char(string(selected));
end
end

function selected = normalizeEnumSelection(key, selected)
txt = lower(strtrim(char(string(selected))));
switch lower(key)
    case 'resolution'
        if any(strcmp(txt, {'280','1008'}))
            selected = txt;
        else
            selected = '280';
        end
    case 'trainmodules'
        txt = strrep(txt, '_', ' ');
        txt = strrep(txt, '-', ' ');
        txt = regexprep(txt, '\s+', ' ');
        if contains(txt, 'all')
            selected = 'all';
        elseif contains(txt, 'semantic')
            selected = 'semantic segmentation';
        elseif contains(txt, 'instance') && (contains(txt, 'video') || contains(txt, 'memory'))
            selected = 'instance + video memory';
        elseif contains(txt, 'video') || contains(txt, 'memory')
            selected = 'video memory';
        elseif contains(txt, 'instance')
            selected = 'instance segmentation';
        else
            selected = 'instance + video memory';
        end
end
end
