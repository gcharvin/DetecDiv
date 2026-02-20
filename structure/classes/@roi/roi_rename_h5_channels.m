function roi_rename_h5_channels(rr, renameCh)
% renameCh: containers.Map('src'->'dst') where src/dst are LOGICAL channel names
% This does NOT rewrite frames; it moves links (/old -> /new) and updates channel_name attribute.

if isempty(renameCh) || ~isa(renameCh,'containers.Map') || renameCh.Count == 0
    return;
end

if ~isprop(rr,'path') || isempty(rr.path) || ~isfolder(rr.path)
    error('roi_rename_h5_channels:InvalidPath','ROI path invalid for ROI %s', rr.id);
end

h5File = fullfile(rr.path, ['im_' rr.id '.h5']);
if ~isfile(h5File)
    % pas d'image => rien à renommer côté HDF5
    return;
end

fid = H5F.open(h5File, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
c = onCleanup(@() H5F.close(fid));

keys = renameCh.keys;
for i = 1:numel(keys)
    src = strtrim(char(keys{i}));
    dst = strtrim(char(renameCh(src)));

    if isempty(src) || isempty(dst) || strcmp(src,dst)
        continue;
    end

    oldPath = ['/' sanitizeDatasetName(src)];
    newPath = ['/' sanitizeDatasetName(dst)];

    oldExists = (H5L.exists(fid, oldPath, 'H5P_DEFAULT') > 0);
    newExists = (H5L.exists(fid, newPath, 'H5P_DEFAULT') > 0);

    if ~oldExists
        % dataset absent -> rien à faire
        continue;
    end
    if newExists
        error('roi_rename_h5_channels:Collision', ...
            'Cannot rename %s -> %s (destination already exists) in %s', oldPath, newPath, h5File);
    end

    % 1) rename link (atomic inside file)
    H5L.move(fid, oldPath, fid, newPath, 'H5P_DEFAULT', 'H5P_DEFAULT');

    % 2) update attribute "channel_name" to dst (logical name, not sanitized)
    try
        h5writeatt(h5File, newPath, 'channel_name', dst);
    catch
        % pas bloquant, mais utile
        warning('roi_rename_h5_channels:AttrFail', ...
            'Renamed %s->%s but failed to update channel_name attribute.', oldPath, newPath);
    end
end
end