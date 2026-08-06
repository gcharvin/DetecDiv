function stored = applyValue(classif, binding, selected)
%CLASSIFIERBINDING.APPLYVALUE Persist a typed selection compatibly.

if ~logical(binding.editable) || strcmpi(binding.storage, 'annotation')
    error('classifierBinding:ReadOnlyBinding', ...
        'Binding "%s" is derived from the annotation contract.', binding.param);
end

values = textList(selected);
sentinels = {'<none>','<unconfigured>','<missing>','<auto>'};
selectedAuto = any(strcmp(values, '<auto>'));
values = values(~ismember(values, sentinels));
if strcmpi(binding.cardinality, 'one')
    if isempty(values)
        if selectedAuto && ~isempty(binding.autoValue)
            stored = binding.autoValue;
        else
            stored = '';
        end
    else
        stored = values{end};
    end
else
    stored = values;
end

switch lower(strtrim(char(string(binding.storage))))
    case 'trainingparam'
        classif.trainingParam.(binding.param) = stored;

    case 'classifierinputchannels'
        if ischar(stored), channelList = {stored}; else, channelList = stored; end
        classif.channelName = channelList;
        try
            dataset = classif.dataset;
            if ~isstruct(dataset), dataset = struct(); end
            dataset.channels = channelList;
            classif.dataset = dataset;
        catch
        end
end
end

function values = textList(raw)
if isempty(raw)
    values = {};
elseif ischar(raw)
    values = {raw};
elseif isstring(raw)
    values = cellstr(raw(:).');
elseif iscell(raw)
    values = {};
    for i = 1:numel(raw)
        nested = textList(raw{i});
        values = [values nested]; %#ok<AGROW>
    end
else
    values = {char(string(raw))};
end
values = values(~cellfun(@(x)isempty(strtrim(x)), values));
values = unique(values, 'stable');
end
