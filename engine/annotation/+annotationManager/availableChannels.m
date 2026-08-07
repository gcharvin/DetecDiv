function names = availableChannels(roiObj)
%ANNOTATIONMANAGER.AVAILABLECHANNELS List ROI channels without loading pixels.

names = {};
try
    raw = roiObj.display.channel;
    if ischar(raw) || isstring(raw)
        names = cellstr(string(raw));
    elseif iscell(raw)
        names = cellfun(@(x) char(string(x)), raw, 'UniformOutput', false);
    end
catch
end

try
    h5File = fullfile(char(string(roiObj.path)), ...
        ['im_' char(string(roiObj.id)) '.h5']);
    if ~isfile(h5File), return; end
    info = h5info(h5File);
    for i = 1:numel(info.Datasets)
        path = ['/' info.Datasets(i).Name];
        value = info.Datasets(i).Name;
        try, value = h5readatt(h5File, path, 'channel_name'); catch, end
        value = char(string(value));
        if ~isempty(value) && ~any(strcmpi(names, value))
            names{end+1} = value; %#ok<AGROW>
        end
    end
catch
end

names = names(~cellfun(@isempty, names));
names = unique(names, 'stable');
end
