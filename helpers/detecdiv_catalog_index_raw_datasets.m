function report = detecdiv_catalog_index_raw_datasets(rawRoots, dbFile, varargin)
% detecdiv_catalog_index_raw_datasets  Scan roots and index raw datasets locally.
%
% Usage
%   report = detecdiv_catalog_index_raw_datasets(rawRoot)
%   report = detecdiv_catalog_index_raw_datasets(rawRoot, dbFile)
%   report = detecdiv_catalog_index_raw_datasets(rawRoot, dbFile, 'MaxDepth', 5)

    if nargin < 1 || isempty(rawRoots)
        error('detecdiv_catalog_index_raw_datasets:MissingRoot', ...
            'At least one raw dataset root folder is required.');
    end
    if nargin < 2 || isempty(dbFile)
        dbFile = [];
    end

    ip = inputParser;
    ip.addParameter('Verbose', true, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('MaxDepth', 5, @(x)isnumeric(x) && isscalar(x));
    ip.addParameter('OwnerUserKey', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('Visibility', 'private', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;
    opts.Verbose = logical(opts.Verbose);
    opts.MaxDepth = max(0, round(double(opts.MaxDepth)));

    roots = localNormalizeRoots(rawRoots);
    [conn, dbFile] = detecdiv_catalog_init(dbFile);
    cleanupObj = onCleanup(@() close(conn)); %#ok<NASGU>
    conn.AutoCommit = 'off';
    exec(conn, 'BEGIN TRANSACTION');

    report = struct();
    report.dbFile = dbFile;
    report.roots = struct('path', {}, 'candidateCount', {}, 'indexedCount', {}, 'errorCount', {});
    report.datasets = struct('datasetPath', {}, 'status', {}, 'rawDatasetId', {}, 'message', {});
    report.startedAt = char(datetime('now'));
    report.finishedAt = '';

    try
        for iRoot = 1:numel(roots)
            rootPath = roots{iRoot};
            if opts.Verbose
                fprintf('[catalog] scanning raw root: %s\n', rootPath);
            end

            candidates = localFindRawDatasetCandidates(rootPath, opts.MaxDepth);
            rootReport = struct('path', rootPath, 'candidateCount', numel(candidates), ...
                'indexedCount', 0, 'errorCount', 0);

            for i = 1:numel(candidates)
                datasetDir = candidates{i};
                try
                    [rawDatasetId, info] = detecdiv_catalog_upsert_raw_dataset_record( ...
                        conn, rootPath, datasetDir, ...
                        'OwnerUserKey', opts.OwnerUserKey, ...
                        'Visibility', opts.Visibility);
                    rootReport.indexedCount = rootReport.indexedCount + 1;
                    report.datasets(end+1) = struct( ... %#ok<AGROW>
                        'datasetPath', info.datasetDir, ...
                        'status', info.status, ...
                        'rawDatasetId', rawDatasetId, ...
                        'message', info.datasetKind);
                    if opts.Verbose
                        fprintf('[catalog] indexed raw dataset: %s [%s]\n', info.datasetDir, info.datasetKind);
                    end
                catch ME
                    rootReport.errorCount = rootReport.errorCount + 1;
                    report.datasets(end+1) = struct( ... %#ok<AGROW>
                        'datasetPath', datasetDir, ...
                        'status', 'error', ...
                        'rawDatasetId', NaN, ...
                        'message', ME.message);
                    if opts.Verbose
                        fprintf(2, '[catalog] failed raw dataset: %s\n', datasetDir);
                        fprintf(2, '          %s\n', ME.message);
                    end
                end
            end

            report.roots(end+1) = rootReport; %#ok<AGROW>
        end
        commit(conn);
    catch ME
        try
            rollback(conn);
        catch
        end
        rethrow(ME);
    end

    report.finishedAt = char(datetime('now'));
end

function roots = localNormalizeRoots(rawRoots)
    if isstring(rawRoots)
        rawRoots = cellstr(rawRoots(:));
    elseif ischar(rawRoots)
        rawRoots = {rawRoots};
    elseif ~iscell(rawRoots)
        error('detecdiv_catalog_index_raw_datasets:InvalidRootType', ...
            'rawRoots must be a char, string, or cellstr.');
    end

    roots = cell(1, numel(rawRoots));
    for i = 1:numel(rawRoots)
        rootPath = localCanonicalPath(rawRoots{i});
        if ~isfolder(rootPath)
            error('detecdiv_catalog_index_raw_datasets:RootNotFound', ...
                'Raw root folder not found: %s', rootPath);
        end
        roots{i} = rootPath;
    end
end

function candidates = localFindRawDatasetCandidates(rootPath, maxDepth)
    candidates = {};
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    inferred = localInferDatasetCandidate(rootPath);
    if ~isempty(inferred) && strcmp(localCanonicalPath(inferred), localCanonicalPath(rootPath))
        localPush(inferred);
        return;
    end

    localWalk(rootPath, 0);

    function localWalk(currentPath, depth)
        if depth > maxDepth
            return;
        end
        if localIsRawDatasetCandidate(currentPath)
            localPush(currentPath);
            return;
        end

        d = dir(currentPath);
        d = d([d.isdir]);
        d = d(~ismember({d.name}, {'.', '..'}));
        for j = 1:numel(d)
            child = fullfile(d(j).folder, d(j).name);
            if localIsPositionLikeName(d(j).name) && localHasMicromanagerMarkerFiles(currentPath)
                continue;
            end
            localWalk(child, depth + 1);
        end
    end

    function localPush(pathIn)
        key = lower(localCanonicalPath(pathIn));
        if isKey(seen, key)
            return;
        end
        seen(key) = true;
        candidates{end+1} = localCanonicalPath(pathIn); %#ok<AGROW>
    end
end

function inferred = localInferDatasetCandidate(pathIn)
    inferred = '';
    if localIsRawDatasetCandidate(pathIn)
        inferred = pathIn;
    end
end

function tf = localIsRawDatasetCandidate(pathIn)
    tf = false;
    if ~isfolder(pathIn)
        return;
    end
    leaf = lower(localPathLeaf(pathIn));
    if endsWith(leaf, {'.ome.zarr', '.zarr'})
        tf = localHasZarrRootMetadata(pathIn);
        return;
    end
    if isfile(fullfile(pathIn, 'zarr.json')) || isfile(fullfile(pathIn, 'NDTiff.index'))
        tf = true;
        return;
    end
    if localIsLegacyMatlabTimelapseDataset(pathIn)
        tf = true;
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

function tf = localHasZarrRootMetadata(pathIn)
    tf = isfile(fullfile(pathIn, 'zarr.json')) || ...
        (isfile(fullfile(pathIn, '.zattrs')) && isfile(fullfile(pathIn, '.zgroup')));
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

function tf = localHasPositionDirs(pathIn)
    tf = false;
    d = dir(pathIn);
    d = d([d.isdir]);
    d = d(~ismember({d.name}, {'.', '..'}));
    for i = 1:numel(d)
        if localIsPositionLikeName(d(i).name)
            tf = true;
            return;
        end
    end
end

function tf = localHasMultipleGenericPositionDirs(pathIn)
    tf = false;
    d = dir(pathIn);
    d = d([d.isdir]);
    d = d(~ismember({d.name}, {'.', '..'}));
    count = 0;
    for i = 1:numel(d)
        childFiles = localDirectChildFilesLower(fullfile(d(i).folder, d(i).name));
        if any(endsWith(childFiles, {'.tif', '.tiff'})) || ...
                any(ismember(childFiles, {'metadata.txt', 'acquisitionmetadata.txt'}))
            count = count + 1;
        end
        if count >= 2
            tf = true;
            return;
        end
    end
end

function tf = localHasMicromanagerMarkerFiles(pathIn)
    files = localDirectChildFilesLower(pathIn);
    tf = any(ismember(files, {'metadata.txt', 'acquisitionmetadata.txt', 'displaysettings.txt', 'displaysettings.json'}));
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

function leaf = localPathLeaf(pathIn)
    [~, name, ext] = fileparts(pathIn);
    leaf = [name ext];
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
