function removed = removeStoredRoiChannel(roiObject, channelName)
%REMOVESTOREDROICHANNEL Remove a logical ROI channel from memory and HDF5.
%
% roi.removeChannel updates the in-memory image/display contract. A normal
% ROI save deliberately preserves HDF5 datasets that are not represented in
% memory, so an intentional persistent deletion must also remove the HDF5
% link before saving the cleaned ROI.

if ~isa(roiObject, 'roi') || ~isscalar(roiObject)
    error('removeStoredRoiChannel:InvalidRoi', ...
        'roiObject must be a scalar roi instance.');
end
if ~(ischar(channelName) || (isstring(channelName) && isscalar(channelName)))
    error('removeStoredRoiChannel:InvalidChannel', ...
        'channelName must be scalar text.');
end
channelName = char(string(channelName));

if isempty(roiObject.image)
    roiObject.load('Silent');
end
before = logicalChannelNames(roiObject);
if ~any(strcmp(before, channelName))
    error('removeStoredRoiChannel:ChannelNotFound', ...
        'Channel "%s" is not present in ROI %s.', channelName, roiObject.id);
end

roiObject.removeChannel(channelName);
after = logicalChannelNames(roiObject);
if any(strcmp(after, channelName))
    error('removeStoredRoiChannel:MemoryRemovalFailed', ...
        'Channel "%s" remains in ROI %s after removeChannel.', ...
        channelName, roiObject.id);
end

h5File = fullfile(roiObject.path, ['im_' roiObject.id '.h5']);
if isfile(h5File)
    datasetPath = ['/' sanitizeDatasetName(channelName)];
    fid = H5F.open(h5File, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
    cleanup = onCleanup(@() H5F.close(fid));
    if H5L.exists(fid, datasetPath, 'H5P_DEFAULT') > 0
        H5L.delete(fid, datasetPath, 'H5P_DEFAULT');
    end
    clear cleanup;
end

if ~roiObject.save([], false)
    error('removeStoredRoiChannel:SaveFailed', ...
        'Could not save ROI %s after removing channel "%s".', ...
        roiObject.id, channelName);
end

if isfile(h5File)
    fid = H5F.open(h5File, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    cleanup = onCleanup(@() H5F.close(fid));
    if H5L.exists(fid, ['/' sanitizeDatasetName(channelName)], ...
            'H5P_DEFAULT') > 0
        error('removeStoredRoiChannel:StoredDatasetRemains', ...
            'Dataset for channel "%s" remains in ROI %s.', ...
            channelName, roiObject.id);
    end
end
removed = true;
end

function names = logicalChannelNames(roiObject)
names = {};
if isfield(roiObject.display, 'channel')
    names = roiObject.display.channel;
end
if ischar(names)
    names = {names};
elseif isstring(names)
    names = cellstr(names);
elseif ~iscell(names)
    names = cellstr(string(names));
end
end
