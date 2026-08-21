function values = readChannel(roiObj, channel)
%ANNOTATIONMANAGER.READCHANNEL Read the current ROI channel snapshot.
% Prefer a channel that is genuinely loaded in the ROI cache so validation
% observes unsaved Score edits. Read the materialized HDF5 dataset only when
% that channel is not present in memory.

channel = char(string(channel));
[indices, cacheStatus] = annotationManager.loadedChannelIndices(roiObj, channel);
if cacheStatus == "loaded"
    values = roiObj.image(:,:,indices,:);
    return;
elseif cacheStatus == "invalid_cache"
    error('annotationManager:InvalidChannelCache', ...
        ['ROI "%s" has an inconsistent image/channel mapping. Reload the ' ...
         'ROI before validating GT.'], char(string(roiObj.id)));
end

[values, found] = readH5Channel(roiObj, channel);
if found, return; end

% Preserve support for legacy MAT-backed ROIs. HDF5 channels are read
% directly above and therefore do not replace the active in-memory cache.
if isempty(roiObj.image)
    try
        roiObj.load('Silent');
    catch
    end
    if ~isempty(roiObj.image)
        [indices, cacheStatus] = annotationManager.loadedChannelIndices( ...
            roiObj, channel);
        if cacheStatus == "loaded"
            values = roiObj.image(:,:,indices,:);
            return;
        elseif cacheStatus == "invalid_cache"
            error('annotationManager:InvalidChannelCache', ...
                ['ROI "%s" has an inconsistent image/channel mapping. ' ...
                 'Reload the ROI before validating GT.'], ...
                char(string(roiObj.id)));
        end
    end
end

error('annotationManager:MissingChannel', ...
    'Channel "%s" could not be read from the ROI cache or its image store.', ...
    channel);
end

function [values, found] = readH5Channel(roiObj, channel)
values = [];
found = false;
try
    h5File = fullfile(char(string(roiObj.path)), ...
        ['im_' char(string(roiObj.id)) '.h5']);
    if ~isfile(h5File), return; end
    info = h5info(h5File);
    for i = 1:numel(info.Datasets)
        datasetPath = ['/' info.Datasets(i).Name];
        logicalName = info.Datasets(i).Name;
        try
            logicalName = h5readatt(h5File, datasetPath, 'channel_name');
        catch
        end
        if strcmpi(char(string(logicalName)), channel)
            values = h5read(h5File, datasetPath);
            found = true;
            return;
        end
    end
catch
    values = [];
    found = false;
end
end
