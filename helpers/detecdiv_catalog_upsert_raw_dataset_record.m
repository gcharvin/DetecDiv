function [rawDatasetId, info] = detecdiv_catalog_upsert_raw_dataset_record(conn, rootPath, datasetDir, varargin)
% detecdiv_catalog_upsert_raw_dataset_record  Upsert one local raw dataset row.

    ip = inputParser;
    ip.addParameter('OwnerUserKey', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('Visibility', 'private', @(x)ischar(x) || isstring(x));
    ip.addParameter('ScanTime', '', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    datasetDir = localInferDatasetDir(datasetDir);
    if isempty(datasetDir) || ~isfolder(datasetDir)
        error('detecdiv_catalog_upsert_raw_dataset_record:DatasetNotFound', ...
            'Raw dataset folder not found: %s', char(string(datasetDir)));
    end
    rootPath = localCanonicalPath(rootPath);
    if isempty(rootPath)
        rootPath = fileparts(datasetDir);
        if isempty(rootPath)
            rootPath = datasetDir;
        end
    end

    scanTime = char(string(opts.ScanTime));
    if isempty(scanTime)
        scanTime = localNowText();
    end

    info = localInspectRawDataset(datasetDir, rootPath, scanTime, opts);
    rootId = localUpsertRoot(conn, rootPath, 'raw_root');
    rawDatasetId = localUpsertRawDataset(conn, info);
    localUpsertRawDatasetLocation(conn, rawDatasetId, rootId, info);
    localReplaceRawDatasetPositions(conn, rawDatasetId, info.positions, scanTime);
    localRefreshProjectCount(conn, rawDatasetId);
end

function info = localInspectRawDataset(datasetDir, rootPath, scanTime, opts)
    [~, leaf] = fileparts(datasetDir);
    dataFormat = localDetectRawDatasetFormat(datasetDir);
    positions = localDiscoverPositions(datasetDir);

    info = struct();
    info.datasetDir = datasetDir;
    info.rootPath = rootPath;
    info.relativePath = localRelativeToRoot(rootPath, datasetDir);
    info.externalKey = ['raw_' localSlugify(leaf) '_' localSha1Short(datasetDir, 10)];
    info.name = leaf;
    info.status = 'indexed';
    info.completenessStatus = 'complete';
    info.datasetKind = dataFormat;
    info.microscopeName = '';
    info.visibility = char(string(opts.Visibility));
    info.ownerUserKey = char(string(opts.OwnerUserKey));
    info.projectCount = 0;
    info.positionCount = numel(positions);
    info.totalBytes = localSafeDirSize(datasetDir);
    info.storageUri = datasetDir;
    info.archiveUri = '';
    info.localPathHint = datasetDir;
    info.positions = positions;
    info.lastSeenAt = scanTime;
    info.lastScanAt = scanTime;
    info.createdAt = localFolderDateText(datasetDir);
    info.updatedAt = scanTime;

    metadata = struct();
    metadata.source_label = 'local_raw_dataset_index';
    metadata.relative_path = info.relativePath;
    metadata.data_format = dataFormat;
    metadata.position_count = info.positionCount;
    metadata.local_path = datasetDir;
    info.metadataJson = localToJson(metadata);
end

function rawDatasetId = localUpsertRawDataset(conn, info)
    rawDatasetId = localFetchScalar(conn, sprintf( ...
        'SELECT id FROM catalog_raw_datasets WHERE external_key = %s', localSqlQuote(info.externalKey)));

    if isempty(rawDatasetId)
        exec(conn, sprintf(['INSERT INTO catalog_raw_datasets(' ...
            'external_key, name, status, completeness_status, dataset_kind, microscope_name, visibility, ' ...
            'owner_user_key, project_count, position_count, total_bytes, storage_uri, archive_uri, ' ...
            'local_path_hint, metadata_json, last_seen_at, last_scan_at, created_at, updated_at) VALUES (' ...
            '%s, %s, %s, %s, %s, %s, %s, %s, %d, %d, %d, %s, %s, %s, %s, %s, %s, %s, %s)'], ...
            localSqlQuote(info.externalKey), localSqlQuote(info.name), localSqlQuote(info.status), ...
            localSqlQuote(info.completenessStatus), localSqlQuote(info.datasetKind), localSqlQuote(info.microscopeName), ...
            localSqlQuote(info.visibility), localSqlQuote(info.ownerUserKey), round(info.projectCount), ...
            round(info.positionCount), round(info.totalBytes), localSqlQuote(info.storageUri), ...
            localSqlQuote(info.archiveUri), localSqlQuote(info.localPathHint), localSqlQuote(info.metadataJson), ...
            localSqlQuote(info.lastSeenAt), localSqlQuote(info.lastScanAt), localSqlQuote(info.createdAt), ...
            localSqlQuote(info.updatedAt)));
        rawDatasetId = localFetchScalar(conn, 'SELECT last_insert_rowid()');
    else
        exec(conn, sprintf(['UPDATE catalog_raw_datasets SET ' ...
            'name = %s, status = %s, completeness_status = %s, dataset_kind = %s, microscope_name = %s, ' ...
            'visibility = %s, owner_user_key = %s, position_count = %d, total_bytes = %d, ' ...
            'storage_uri = %s, archive_uri = %s, local_path_hint = %s, metadata_json = %s, ' ...
            'last_seen_at = %s, last_scan_at = %s, created_at = COALESCE(created_at, %s), updated_at = %s ' ...
            'WHERE id = %d'], ...
            localSqlQuote(info.name), localSqlQuote(info.status), localSqlQuote(info.completenessStatus), ...
            localSqlQuote(info.datasetKind), localSqlQuote(info.microscopeName), localSqlQuote(info.visibility), ...
            localSqlQuote(info.ownerUserKey), round(info.positionCount), round(info.totalBytes), ...
            localSqlQuote(info.storageUri), localSqlQuote(info.archiveUri), localSqlQuote(info.localPathHint), ...
            localSqlQuote(info.metadataJson), localSqlQuote(info.lastSeenAt), localSqlQuote(info.lastScanAt), ...
            localSqlQuote(info.createdAt), localSqlQuote(info.updatedAt), double(rawDatasetId)));
    end
end

function localUpsertRawDatasetLocation(conn, rawDatasetId, rootId, info)
    locationId = localFetchScalar(conn, sprintf( ...
        'SELECT id FROM catalog_raw_dataset_locations WHERE abs_path = %s', localSqlQuote(info.datasetDir)));
    nowText = info.lastScanAt;
    if isempty(locationId)
        exec(conn, sprintf(['INSERT INTO catalog_raw_dataset_locations(' ...
            'raw_dataset_id, root_id, relative_path, abs_path, access_mode, is_preferred, exists_flag, created_at, updated_at) ' ...
            'VALUES (%d, %d, %s, %s, %s, %d, %d, %s, %s)'], ...
            double(rawDatasetId), double(rootId), localSqlQuote(info.relativePath), localSqlQuote(info.datasetDir), ...
            localSqlQuote('read'), 1, double(isfolder(info.datasetDir)), localSqlQuote(nowText), localSqlQuote(nowText)));
    else
        exec(conn, sprintf(['UPDATE catalog_raw_dataset_locations SET raw_dataset_id = %d, root_id = %d, ' ...
            'relative_path = %s, access_mode = %s, is_preferred = 1, exists_flag = %d, updated_at = %s WHERE id = %d'], ...
            double(rawDatasetId), double(rootId), localSqlQuote(info.relativePath), localSqlQuote('read'), ...
            double(isfolder(info.datasetDir)), localSqlQuote(nowText), double(locationId)));
    end
end

function localReplaceRawDatasetPositions(conn, rawDatasetId, positions, scanTime)
    exec(conn, sprintf('DELETE FROM catalog_raw_dataset_positions WHERE raw_dataset_id = %d', double(rawDatasetId)));
    for i = 1:numel(positions)
        row = positions(i);
        exec(conn, sprintf(['INSERT INTO catalog_raw_dataset_positions(' ...
            'raw_dataset_id, position_key, display_name, position_index, status, metadata_json, created_at, updated_at) ' ...
            'VALUES (%d, %s, %s, %d, %s, %s, %s, %s)'], ...
            double(rawDatasetId), localSqlQuote(row.positionKey), localSqlQuote(row.displayName), ...
            round(row.positionIndex), localSqlQuote('indexed'), localSqlQuote(row.metadataJson), ...
            localSqlQuote(scanTime), localSqlQuote(scanTime)));
    end
end

function localRefreshProjectCount(conn, rawDatasetId)
    projectCount = localFetchScalar(conn, sprintf( ...
        'SELECT COUNT(*) FROM catalog_project_raw_links WHERE raw_dataset_id = %d', double(rawDatasetId)));
    if isempty(projectCount)
        projectCount = 0;
    end
    exec(conn, sprintf('UPDATE catalog_raw_datasets SET project_count = %d WHERE id = %d', ...
        round(projectCount), double(rawDatasetId)));
end

function rootId = localUpsertRoot(conn, rootPath, rootType)
    nowText = localNowText();
    [~, label] = fileparts(rootPath);
    if isempty(label)
        label = rootPath;
    end

    rootId = localFetchScalar(conn, sprintf( ...
        'SELECT id FROM catalog_roots WHERE abs_path = %s', localSqlQuote(rootPath)));

    if isempty(rootId)
        exec(conn, sprintf(['INSERT INTO catalog_roots(label, root_type, abs_path, created_at, updated_at) ' ...
            'VALUES (%s, %s, %s, %s, %s)'], ...
            localSqlQuote(label), localSqlQuote(rootType), localSqlQuote(rootPath), ...
            localSqlQuote(nowText), localSqlQuote(nowText)));
        rootId = localFetchScalar(conn, 'SELECT last_insert_rowid()');
    else
        exec(conn, sprintf('UPDATE catalog_roots SET root_type = %s, updated_at = %s WHERE id = %d', ...
            localSqlQuote(rootType), localSqlQuote(nowText), double(rootId)));
    end
end

function datasetDir = localInferDatasetDir(pathIn)
    datasetDir = localCanonicalPath(pathIn);
    if isempty(datasetDir) || ~exist(datasetDir, 'file')
        return;
    end

    if isfile(datasetDir)
        datasetDir = fileparts(datasetDir);
    end

    candidates = [{datasetDir} localParentDirs(datasetDir)];
    for i = 1:numel(candidates)
        cand = candidates{i};
        if localIsLegacyMatlabTimelapseDataset(cand) || localLooksLikeDatasetFolder(cand)
            datasetDir = cand;
            return;
        end
    end

    [~, leaf, ext] = fileparts(datasetDir);
    if endsWith(lower([leaf ext]), {'.zarr', '.ome.zarr'})
        return;
    end

    if localIsPositionLikeName(localPathLeaf(datasetDir))
        parentDir = fileparts(datasetDir);
        if isfolder(parentDir)
            datasetDir = parentDir;
        end
    end
end

function dataFormat = localDetectRawDatasetFormat(datasetDir)
    leaf = lower(localPathLeaf(datasetDir));
    if endsWith(leaf, '.ome.zarr')
        dataFormat = 'ome_zarr';
        return;
    end
    if endsWith(leaf, '.zarr')
        dataFormat = 'zarr';
        return;
    end
    if isfile(fullfile(datasetDir, 'zarr.json'))
        dataFormat = 'ome_zarr';
        return;
    end
    if isfile(fullfile(datasetDir, '.zattrs')) && isfile(fullfile(datasetDir, '.zgroup'))
        dataFormat = 'zarr';
        return;
    end
    if isfile(fullfile(datasetDir, 'NDTiff.index'))
        dataFormat = 'ndtiff';
        return;
    end
    if localIsLegacyMatlabTimelapseDataset(datasetDir)
        dataFormat = 'legacy_matlab_jpg_timelapse';
        return;
    end

    files = localDirectChildFilesLower(datasetDir);
    if any(endsWith(files, '.nd2'))
        dataFormat = 'nd2';
    elseif any(endsWith(files, '.czi'))
        dataFormat = 'czi';
    elseif any(endsWith(files, '.lif'))
        dataFormat = 'lif';
    elseif any(endsWith(files, '.ims'))
        dataFormat = 'ims';
    elseif any(ismember(files, {'metadata.txt', 'acquisitionmetadata.txt', 'displaysettings.txt', 'displaysettings.json'}))
        dataFormat = 'micromanager_tiff_dir';
    else
        tiffs = files(endsWith(files, {'.tif', '.tiff'}));
        if any(endsWith(tiffs, {'.ome.tif', '.ome.tiff'}))
            dataFormat = 'ome_tiff';
        elseif numel(tiffs) == 1
            dataFormat = 'single_tiff';
        elseif numel(tiffs) > 1
            dataFormat = 'tiff_sequence';
        elseif localHasPositionDirs(datasetDir)
            dataFormat = 'tiff_sequence';
        else
            dataFormat = 'unknown';
        end
    end
end

function positions = localDiscoverPositions(datasetDir)
    positions = struct('positionKey', {}, 'displayName', {}, 'positionIndex', {}, 'metadataJson', {});
    dirs = dir(datasetDir);
    dirs = dirs([dirs.isdir]);
    dirs = dirs(~ismember({dirs.name}, {'.', '..'}));

    for i = 1:numel(dirs)
        name = dirs(i).name;
        childPath = fullfile(dirs(i).folder, dirs(i).name);
        if localIsPositionLikeName(name) || localLooksLikeMicromanagerPositionDir(childPath)
            positions(end+1) = localPositionStruct(name, numel(positions)); %#ok<AGROW>
        end
    end

    if isempty(positions) && strcmp(localDetectRawDatasetFormat(datasetDir), 'ndtiff')
        positions(end+1) = localPositionStruct('position_1', 0);
    end
end

function row = localPositionStruct(name, index0)
    meta = struct('relative_path', name, 'source', 'local_directory_heuristic');
    row = struct( ...
        'positionKey', localSlugify(name), ...
        'displayName', name, ...
        'positionIndex', index0, ...
        'metadataJson', localToJson(meta));
end

function tf = localLooksLikeDatasetFolder(pathIn)
    tf = false;
    if ~isfolder(pathIn)
        return;
    end
    leaf = lower(localPathLeaf(pathIn));
    if endsWith(leaf, {'.ome.zarr', '.zarr'})
        tf = localHasZarrRootMetadata(pathIn);
        return;
    end
    tf = localHasZarrRootMetadata(pathIn) || isfile(fullfile(pathIn, 'NDTiff.index')) || ...
        localLooksLikeRawDatasetDir(pathIn);
end

function tf = localLooksLikeRawDatasetDir(pathIn)
    tf = false;
    if ~isfolder(pathIn)
        return;
    end
    files = localDirectChildFilesLower(pathIn);
    if any(endsWith(files, {'.nd2', '.czi', '.lif', '.ims'}))
        tf = true;
        return;
    end
    if any(ismember(files, {'metadata.txt', 'acquisitionmetadata.txt', 'displaysettings.txt', 'displaysettings.json'}))
        tf = localHasPositionDirs(pathIn) || localHasMultipleGenericPositionDirs(pathIn);
        return;
    end
    tiffs = files(endsWith(files, {'.tif', '.tiff'}));
    tf = ~isempty(tiffs);
end

function tf = localIsLegacyMatlabTimelapseDataset(pathIn)
    tf = false;
    files = localDirectChildFilesLower(pathIn);
    if ~any(endsWith(files, '.id'))
        return;
    end
    d = dir(pathIn);
    d = d([d.isdir]);
    d = d(~ismember({d.name}, {'.', '..'}));
    for i = 1:numel(d)
        childFiles = localDirectChildFilesLower(fullfile(d(i).folder, d(i).name));
        if any(endsWith(childFiles, {'.jpg', '.jpeg'}))
            tf = true;
            return;
        end
    end
end

function tf = localHasZarrRootMetadata(pathIn)
    tf = isfile(fullfile(pathIn, 'zarr.json')) || ...
        (isfile(fullfile(pathIn, '.zattrs')) && isfile(fullfile(pathIn, '.zgroup')));
end

function tf = localHasPositionDirs(pathIn)
    tf = false;
    dirs = dir(pathIn);
    dirs = dirs([dirs.isdir]);
    dirs = dirs(~ismember({dirs.name}, {'.', '..'}));
    for i = 1:numel(dirs)
        if localIsPositionLikeName(dirs(i).name)
            tf = true;
            return;
        end
    end
end

function tf = localHasMultipleGenericPositionDirs(pathIn)
    tf = false;
    dirs = dir(pathIn);
    dirs = dirs([dirs.isdir]);
    dirs = dirs(~ismember({dirs.name}, {'.', '..'}));
    count = 0;
    for i = 1:numel(dirs)
        childPath = fullfile(dirs(i).folder, dirs(i).name);
        if localLooksLikeMicromanagerPositionDir(childPath)
            count = count + 1;
            if count >= 2
                tf = true;
                return;
            end
        end
    end
end

function tf = localLooksLikeMicromanagerPositionDir(pathIn)
    files = localDirectChildFilesLower(pathIn);
    tf = any(ismember(files, {'metadata.txt', 'acquisitionmetadata.txt', 'displaysettings.txt', 'displaysettings.json'})) || ...
        any(endsWith(files, {'.tif', '.tiff'}));
end

function tf = localIsPositionLikeName(name)
    name = lower(strtrim(char(string(name))));
    tf = startsWith(name, 'pos') || startsWith(name, 'position') || startsWith(name, 'xy');
end

function files = localDirectChildFilesLower(pathIn)
    files = strings(0, 1);
    if ~isfolder(pathIn)
        return;
    end
    d = dir(pathIn);
    d = d(~[d.isdir]);
    files = lower(string({d.name}));
    files = files(:);
end

function sizeBytes = localSafeDirSize(pathIn)
    sizeBytes = 0;
    try
        d = dir(fullfile(pathIn, '**', '*'));
        d = d(~[d.isdir]);
        if ~isempty(d)
            sizeBytes = sum(double([d.bytes]));
        end
    catch
        sizeBytes = 0;
    end
end

function txt = localFolderDateText(pathIn)
    txt = localNowText();
    try
        d = dir(pathIn);
        if ~isempty(d)
            txt = localDateToText(d(1).datenum);
        end
    catch
    end
end

function dirs = localParentDirs(pathIn)
    dirs = {};
    current = pathIn;
    for i = 1:5
        parent = fileparts(current);
        if isempty(parent) || strcmp(parent, current)
            return;
        end
        dirs{end+1} = parent; %#ok<AGROW>
        current = parent;
    end
end

function leaf = localPathLeaf(pathIn)
    [~, name, ext] = fileparts(pathIn);
    leaf = [name ext];
end

function out = localSlugify(in)
    out = lower(regexprep(char(string(in)), '[^a-zA-Z0-9]+', '_'));
    out = regexprep(out, '^_+|_+$', '');
    if isempty(out)
        out = 'dataset';
    end
end

function out = localSha1Short(in, n)
    md = java.security.MessageDigest.getInstance('SHA-1');
    bytes = uint8(char(string(in)));
    hash = typecast(md.digest(bytes), 'uint8');
    hex = lower(reshape(dec2hex(hash, 2).', 1, []));
    out = hex(1:min(n, numel(hex)));
end

function out = localRelativeToRoot(rootPath, pathIn)
    rootPath = char(string(rootPath));
    pathIn = char(string(pathIn));
    out = pathIn;
    if startsWith(lower(pathIn), lower(rootPath))
        out = pathIn(numel(rootPath)+1:end);
        out = regexprep(out, '^[\\/]+', '');
        if isempty(out)
            out = '.';
        end
    end
end

function out = localCanonicalPath(pathIn)
    out = char(string(pathIn));
    if isempty(out)
        return;
    end
    if ispc
        out = strrep(out, '/', '\');
    else
        out = strrep(out, '\', '/');
    end
    try
        out = char(java.io.File(out).getCanonicalPath());
    catch
    end
end

function value = localFetchScalar(conn, sql)
    data = fetch(conn, sql);
    if isempty(data)
        value = [];
        return;
    end
    if istable(data)
        value = data{1, 1};
    elseif iscell(data)
        value = data{1, 1};
    else
        value = data(1);
    end
end

function txt = localSqlQuote(value)
    if nargin < 1 || isempty(value)
        txt = 'NULL';
        return;
    end
    txt = char(string(value));
    txt = strrep(txt, '''', '''''');
    txt = ['''' txt ''''];
end

function txt = localNowText()
    txt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function txt = localDateToText(datenumValue)
    try
        txt = char(datetime(datenumValue, 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    catch
        txt = '';
    end
end

function txt = localToJson(value)
    try
        txt = jsonencode(value);
    catch
        txt = '{}';
    end
end
