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

groupId = 'probe';
try
    if isfield(ctx, 'names') && isfield(ctx.names, 'outputName') && ...
            ~isempty(ctx.names.outputName)
        groupId = char(string(ctx.names.outputName));
    end
catch
end
probeData = dataseries(table((1:size(roiObj.image, 4)).', ...
    'VariableNames', {'probe_value'}));
probeData.groupid = groupId;
probeData.parentid = roiObj.id;
out = struct('status', "OK", 'patch', struct('roi', struct( ...
    'dataseries', struct('upsert', {{struct( ...
        'groupid', groupId, 'dataseries', probeData, 'mode', 'replace')}}))));
end
