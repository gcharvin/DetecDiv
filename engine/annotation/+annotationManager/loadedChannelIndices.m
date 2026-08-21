function [indices, status] = loadedChannelIndices(roiObj, channel)
%ANNOTATIONMANAGER.LOADEDCHANNELINDICES Resolve a trustworthy live channel.
% status is "loaded", "not_loaded", or "invalid_cache". A cache with an
% image/channelid mismatch must never be validated or persisted as GT.

indices = [];
status = "not_loaded";
try
    if isempty(roiObj.image), return; end
    planeCount = size(roiObj.image, 3);
    mapping = double(roiObj.channelid(:).');
    names = roiObj.display.channel;
    if ischar(names) || isstring(names), names = cellstr(string(names)); end
    if ~iscell(names), names = {}; end

    if numel(mapping) ~= planeCount || isempty(names) || ...
            any(~isfinite(mapping)) || any(mapping ~= round(mapping)) || ...
            any(mapping < 1) || any(mapping > numel(names))
        status = "invalid_cache";
        return;
    end

    indices = roiObj.findChannelID(channel, 'exact');
    if isempty(indices), return; end
    indices = double(indices(:).');
    if any(~isfinite(indices)) || any(indices ~= round(indices)) || ...
            any(indices < 1) || any(indices > planeCount)
        indices = [];
        status = "invalid_cache";
        return;
    end
    status = "loaded";
catch
    indices = [];
    status = "invalid_cache";
end
end
