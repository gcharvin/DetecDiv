function out = classify(roiObj, classif, ctx) %#ok<INUSD>
%CLASSIFY Capture the channels made addressable by classi.classifyData.

names = {};
try
    raw = ctx.sel.channels;
    if ischar(raw) || isstring(raw)
        names = cellstr(string(raw));
    elseif iscell(raw)
        names = cellfun(@(value) char(string(value)), raw, ...
            'UniformOutput', false);
    end
catch
end

indices = cell(size(names));
values = cell(size(names));
for i = 1:numel(names)
    indices{i} = roiObj.findChannelID(names{i}, 'exact');
    if ~isempty(indices{i})
        values{i} = squeeze(roiObj.image(1, 1, indices{i}(1), :)).';
    else
        values{i} = [];
    end
end
setappdata(0, 'DetecDivClassifyDataProbe', struct( ...
    'selectedChannels', {names}, ...
    'indices', {indices}, ...
    'values', {values}, ...
    'imageSize', size(roiObj.image)));

out = struct('status', "OK", 'patch', []);
end
