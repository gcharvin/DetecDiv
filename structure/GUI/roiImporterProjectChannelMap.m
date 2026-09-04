function projected = roiImporterProjectChannelMap(sourceMap, available)
%ROIIMPORTERPROJECTCHANNELMAP Apply one edited mapping to another source.
% Rows are matched by source-channel name. Channels absent from the edited
% mapping default to Import=false so an unconfigured selected FOV cannot
% silently reintroduce every available channel.

available = roiImporterChannelNames(available);
projected = repmat(struct('import',false, 'sourceName','', ...
    'type','unknown', 'destName','', 'ioChannel','-'), ...
    1, numel(available));
for channelIndex = 1:numel(available)
    name = available{channelIndex};
    projected(channelIndex).sourceName = name;
    projected(channelIndex).destName = name;
    hit = [];
    if isstruct(sourceMap) && ~isempty(sourceMap) && ...
            isfield(sourceMap, 'sourceName')
        hit = find(strcmpi({sourceMap.sourceName}, name), 1);
    end
    if isempty(hit), continue; end
    projected(channelIndex) = sourceMap(hit);
    projected(channelIndex).sourceName = name;
    if isempty(projected(channelIndex).destName) || ...
            strcmpi(projected(channelIndex).destName, ...
            sourceMap(hit).sourceName)
        projected(channelIndex).destName = name;
    end
end
end
