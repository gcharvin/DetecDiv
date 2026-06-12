function report = detecdiv_catalog_index_projects(projectRoots, dbFile, varargin)
% detecdiv_catalog_index_projects  Scan project roots and index DetecDiv projects.
%
% Usage
%   report = detecdiv_catalog_index_projects(projectRoot)
%   report = detecdiv_catalog_index_projects(projectRoot, dbFile)
%   report = detecdiv_catalog_index_projects(projectRoot, dbFile, 'Verbose', true)

    if nargin < 1 || isempty(projectRoots)
        error('detecdiv_catalog_index_projects:MissingRoot', ...
            'At least one project root folder is required.');
    end

    if nargin < 2 || isempty(dbFile)
        dbFile = [];
    end

    ip = inputParser;
    ip.addParameter('Verbose', true, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('LoadProjectMetadata', true, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('MarkMissingProjects', true, @(x)islogical(x) || isnumeric(x));
    ip.parse(varargin{:});
    opts = ip.Results;
    opts.Verbose = logical(opts.Verbose);
    opts.LoadProjectMetadata = logical(opts.LoadProjectMetadata);
    opts.MarkMissingProjects = logical(opts.MarkMissingProjects);

    roots = localNormalizeRoots(projectRoots);

    [conn, dbFile] = detecdiv_catalog_init(dbFile);
    cleanupObj = onCleanup(@() close(conn)); %#ok<NASGU>
    conn.AutoCommit = 'off';
    exec(conn, 'BEGIN TRANSACTION');

    report = struct();
    report.dbFile = dbFile;
    report.roots = struct('path', {}, 'rootId', {}, 'candidateCount', {}, 'indexedCount', {}, ...
        'missingCount', {}, 'errorCount', {});
    report.projects = struct('projectMat', {}, 'status', {}, 'projectId', {}, 'message', {});
    report.startedAt = char(datetime('now'));
    report.finishedAt = '';

    try
        for iRoot = 1:numel(roots)
            rootPath = roots{iRoot};
            if opts.Verbose
                fprintf('[catalog] scanning root: %s\n', rootPath);
            end

            rootId = localUpsertRoot(conn, rootPath, 'project_root');
            candidates = localFindProjectCandidates(rootPath);
            seenMap = containers.Map('KeyType', 'char', 'ValueType', 'logical');

            rootReport = struct( ...
                'path', rootPath, ...
                'rootId', rootId, ...
                'candidateCount', numel(candidates), ...
                'indexedCount', 0, ...
                'missingCount', 0, ...
                'errorCount', 0);

            for iProj = 1:numel(candidates)
                proj = candidates(iProj);
                seenMap(lower(proj.projectMatAbs)) = true;

                try
                    projectInfo = localInspectProject(proj, rootPath, opts.LoadProjectMetadata);
                    projectId = localUpsertProject(conn, rootId, projectInfo);
                    localReplaceRawSources(conn, projectId, projectInfo.rawSources);
                    localReplaceRawDatasetLinks(conn, projectId, projectInfo.rawSources, projectInfo.scanTime);
                    localReplacePipelineRuns(conn, projectId, projectInfo.pipelineRuns, projectInfo.scanTime);

                    rootReport.indexedCount = rootReport.indexedCount + 1;
                    report.projects(end+1) = struct( ... %#ok<AGROW>
                        'projectMat', projectInfo.projectMatAbs, ...
                        'status', projectInfo.healthStatus, ...
                        'projectId', projectId, ...
                        'message', projectInfo.healthMessage);

                    if opts.Verbose
                        fprintf('[catalog] indexed: %s [%s]\n', projectInfo.projectMatAbs, projectInfo.healthStatus);
                    end
                catch ME
                    rootReport.errorCount = rootReport.errorCount + 1;
                    report.projects(end+1) = struct( ... %#ok<AGROW>
                        'projectMat', proj.projectMatAbs, ...
                        'status', 'error', ...
                        'projectId', NaN, ...
                        'message', ME.message);

                    if opts.Verbose
                        fprintf(2, '[catalog] failed: %s\n', proj.projectMatAbs);
                        fprintf(2, '          %s\n', ME.message);
                    end
                end
            end

            if opts.MarkMissingProjects
                rootReport.missingCount = localMarkMissingProjects(conn, rootId, seenMap);
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

function roots = localNormalizeRoots(projectRoots)
    if isstring(projectRoots)
        projectRoots = cellstr(projectRoots(:));
    elseif ischar(projectRoots)
        projectRoots = {projectRoots};
    elseif ~iscell(projectRoots)
        error('detecdiv_catalog_index_projects:InvalidRootType', ...
            'projectRoots must be a char, string, or cellstr.');
    end

    roots = cell(1, numel(projectRoots));
    for i = 1:numel(projectRoots)
        rootPath = localCanonicalPath(projectRoots{i});
        if ~isfolder(rootPath)
            error('detecdiv_catalog_index_projects:RootNotFound', ...
                'Root folder not found: %s', rootPath);
        end
        roots{i} = rootPath;
    end
end

function candidates = localFindProjectCandidates(rootPath)
    mats = dir(fullfile(rootPath, '**', '*.mat'));
    candidates = struct('projectName', {}, 'projectMatAbs', {}, 'projectDirAbs', {}, ...
        'projectRelFromRoot', {}, 'projectBytes', {}, 'projectMTime', {});
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    for i = 1:numel(mats)
        if mats(i).isdir
            continue;
        end

        matPath = localCanonicalPath(fullfile(mats(i).folder, mats(i).name));
        [parentDir, baseName, ~] = fileparts(matPath);
        projectDir = localCanonicalPath(fullfile(parentDir, baseName));

        if ~isfolder(projectDir)
            continue;
        end

        key = lower(matPath);
        if isKey(seen, key)
            continue;
        end
        seen(key) = true;

        candidates(end+1) = struct( ... %#ok<AGROW>
            'projectName', baseName, ...
            'projectMatAbs', matPath, ...
            'projectDirAbs', projectDir, ...
            'projectRelFromRoot', localRelativeToRoot(rootPath, projectDir), ...
            'projectBytes', double(mats(i).bytes), ...
            'projectMTime', localDateToText(mats(i).datenum));
    end
end

function projectInfo = localInspectProject(proj, rootPath, loadProjectMetadata)
    projectInfo = proj;
    projectInfo.scanTime = localNowText();
    projectInfo.healthStatus = 'ok';
    projectInfo.healthMessage = '';
    projectInfo.formatTag = 'shallow';
    projectInfo.fovCount = 0;
    projectInfo.roiCount = 0;
    projectInfo.classifierCount = localCountChildDirs(fullfile(proj.projectDirAbs, 'classification'));
    projectInfo.processorCount = localCountChildDirs(fullfile(proj.projectDirAbs, 'processor'));
    projectInfo.pipelineRunCount = 0;
    projectInfo.availableRawCount = 0;
    projectInfo.missingRawCount = 0;
    projectInfo.rawStatus = 'unknown';
    projectInfo.metadataJson = '{}';
    projectInfo.rawSources = struct('rawKind', {}, 'channelIndex', {}, 'rawAbsPath', {}, ...
        'rawRelFromRoot', {}, 'existsFlag', {});
    projectInfo.pipelineRuns = struct('runId', {}, 'runPathAbs', {}, 'pipelineId', {}, ...
        'pipelinePath', {}, 'status', {}, 'createdAt', {}, 'updatedAt', {}, ...
        'summaryJson', {});

    if loadProjectMetadata
        shallowObj = localLoadShallowProject(proj.projectMatAbs);
        projectInfo.fovCount = localCountFov(shallowObj);
        projectInfo.roiCount = localCountRois(shallowObj);
        [projectInfo.rawSources, projectInfo.availableRawCount, projectInfo.missingRawCount] = ...
            localCollectRawSources(shallowObj, rootPath);

        if isempty(projectInfo.rawSources)
            projectInfo.rawStatus = 'unknown';
        elseif projectInfo.missingRawCount > 0
            projectInfo.rawStatus = 'missing';
            projectInfo.healthStatus = 'raw_missing';
            projectInfo.healthMessage = sprintf('%d raw source(s) are missing.', projectInfo.missingRawCount);
        else
            projectInfo.rawStatus = 'available';
        end

        meta = struct();
        meta.tag = localGetField(shallowObj, 'tag', '');
        meta.runProfiles = localHasField(shallowObj, 'runProfiles');
        meta.processingFields = fieldnames(shallowObj.processing);
        projectInfo.metadataJson = localToJson(meta);
    end

    [projectInfo.pipelineRuns, projectInfo.pipelineRunCount] = localReadPipelineRuns(proj.projectDirAbs);
end

function shallowObj = localLoadShallowProject(matPath)
    info = whos('-file', matPath);
    if isempty(info)
        error('detecdiv_catalog_index_projects:EmptyMat', 'MAT file is empty: %s', matPath);
    end

    targetVar = '';
    if any(strcmp({info.name}, 'shallowObj'))
        targetVar = 'shallowObj';
    elseif numel(info) == 1
        targetVar = info(1).name;
    end

    if isempty(targetVar)
        error('detecdiv_catalog_index_projects:UnsupportedMat', ...
            'Could not infer shallow variable in %s', matPath);
    end

    S = load(matPath, targetVar);
    shallowObj = S.(targetVar);
    if ~isa(shallowObj, 'shallow')
        error('detecdiv_catalog_index_projects:NotShallow', ...
            'Variable %s in %s is not a shallow object.', targetVar, matPath);
    end
end

function n = localCountFov(shallowObj)
    n = 0;
    if ~localHasField(shallowObj, 'fov') || isempty(shallowObj.fov)
        return;
    end
    for i = 1:numel(shallowObj.fov)
        if ~localIsEmptyId(shallowObj.fov(i), 'id')
            n = n + 1;
        end
    end
end

function n = localCountRois(shallowObj)
    n = 0;
    if ~localHasField(shallowObj, 'fov') || isempty(shallowObj.fov)
        return;
    end
    for i = 1:numel(shallowObj.fov)
        if ~isprop(shallowObj.fov(i), 'roi') || isempty(shallowObj.fov(i).roi)
            continue;
        end
        for j = 1:numel(shallowObj.fov(i).roi)
            if ~localIsEmptyId(shallowObj.fov(i).roi(j), 'id')
                n = n + 1;
            end
        end
    end
end

function [rawSources, availableCount, missingCount] = localCollectRawSources(shallowObj, rootPath)
    rawSources = struct('rawKind', {}, 'channelIndex', {}, 'rawAbsPath', {}, ...
        'rawRelFromRoot', {}, 'existsFlag', {});
    availableCount = 0;
    missingCount = 0;
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    if ~localHasField(shallowObj, 'fov') || isempty(shallowObj.fov)
        return;
    end

    for i = 1:numel(shallowObj.fov)
        f = shallowObj.fov(i);
        [kinds, channels, paths] = localGetRawPointersFromFov(f);
        for k = 1:numel(paths)
            rawPath = strtrim(char(string(paths{k})));
            if isempty(rawPath)
                continue;
            end

            rawAbs = localCanonicalPath(rawPath);
            dedupeKey = lower(sprintf('%s|%d|%s', kinds{k}, channels(k), rawAbs));
            if isKey(seen, dedupeKey)
                continue;
            end
            seen(dedupeKey) = true;

            existsFlag = localRawPointerExists(kinds{k}, rawAbs);
            if existsFlag
                availableCount = availableCount + 1;
            else
                missingCount = missingCount + 1;
            end

            rawSources(end+1) = struct( ... %#ok<AGROW>
                'rawKind', kinds{k}, ...
                'channelIndex', channels(k), ...
                'rawAbsPath', rawAbs, ...
                'rawRelFromRoot', localRelativeToRoot(rootPath, rawAbs), ...
                'existsFlag', double(existsFlag));
        end
    end
end

function [kinds, channels, paths] = localGetRawPointersFromFov(f)
    kinds = {};
    channels = [];
    paths = {};

    if isprop(f, 'isMultiTiff') && logical(f.isMultiTiff) && isprop(f, 'tiffSource')
        for i = 1:numel(f.tiffSource)
            if isempty(f.tiffSource{i})
                continue;
            end
            kinds{end+1} = 'tiffSource'; %#ok<AGROW>
            channels(end+1) = i; %#ok<AGROW>
            paths{end+1} = f.tiffSource{i}; %#ok<AGROW>
        end
        return;
    end

    if isprop(f, 'isNDTiff') && logical(f.isNDTiff) && isprop(f, 'ndtiffPath') && ~isempty(f.ndtiffPath)
        kinds{end+1} = 'ndtiff'; %#ok<AGROW>
        channels(end+1) = 1; %#ok<AGROW>
        paths{end+1} = f.ndtiffPath; %#ok<AGROW>
        return;
    end

    if isprop(f, 'srcpath') && iscell(f.srcpath)
        for i = 1:numel(f.srcpath)
            if isempty(f.srcpath{i})
                continue;
            end
            kinds{end+1} = 'srcpath'; %#ok<AGROW>
            channels(end+1) = i; %#ok<AGROW>
            paths{end+1} = f.srcpath{i}; %#ok<AGROW>
        end
    end
end

function tf = localRawPointerExists(rawKind, rawPath)
    switch rawKind
        case 'tiffSource'
            tf = isfile(rawPath) || isfolder(rawPath);
        otherwise
            tf = isfolder(rawPath) || isfile(rawPath);
    end
end

function [runs, nRuns] = localReadPipelineRuns(projectDir)
    runs = struct('runId', {}, 'runPathAbs', {}, 'pipelineId', {}, 'pipelinePath', {}, ...
        'status', {}, 'createdAt', {}, 'updatedAt', {}, 'summaryJson', {});
    pipeDir = fullfile(projectDir, 'pipeline');
    if ~isfolder(pipeDir)
        nRuns = 0;
        return;
    end

    subdirs = dir(pipeDir);
    subdirs = subdirs([subdirs.isdir]);
    subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

    for i = 1:numel(subdirs)
        runPath = localCanonicalPath(fullfile(pipeDir, subdirs(i).name));
        jsonPath = fullfile(runPath, 'run.json');
        if ~isfile(jsonPath)
            continue;
        end

        runStruct = jsondecode(fileread(jsonPath));
        runs(end+1) = struct( ... %#ok<AGROW>
            'runId', localGetField(runStruct, 'runId', subdirs(i).name), ...
            'runPathAbs', runPath, ...
            'pipelineId', localGetNestedField(runStruct, {'pipelineRef', 'id'}, ''), ...
            'pipelinePath', localGetNestedField(runStruct, {'pipelineRef', 'path'}, ''), ...
            'status', localGetField(runStruct, 'status', 'unknown'), ...
            'createdAt', localGetField(runStruct, 'createdAt', ''), ...
            'updatedAt', localGetField(runStruct, 'updatedAt', ''), ...
            'summaryJson', localToJson(localGetNestedField(runStruct, {'outputs', 'report', 'summary'}, struct())));
    end

    nRuns = numel(runs);
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
        exec(conn, sprintf(['UPDATE catalog_roots SET label = %s, root_type = %s, updated_at = %s ' ...
            'WHERE id = %d'], ...
            localSqlQuote(label), localSqlQuote(rootType), localSqlQuote(nowText), double(rootId)));
    end
end

function projectId = localUpsertProject(conn, rootId, info)
    projectId = localFetchScalar(conn, sprintf( ...
        'SELECT id FROM catalog_projects WHERE project_mat_abs = %s', localSqlQuote(info.projectMatAbs)));

    if isempty(projectId)
        exec(conn, sprintf(['INSERT INTO catalog_projects(' ...
            'root_id, name, project_mat_abs, project_dir_abs, project_rel_from_root, format_tag, ' ...
            'health_status, health_message, created_at, last_seen_at, last_scan_at, project_mtime, project_bytes, ' ...
            'fov_count, roi_count, classifier_count, processor_count, pipeline_run_count, ' ...
            'available_raw_count, missing_raw_count, raw_status, metadata_json) VALUES (' ...
            '%d, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %d, %d, %d, %d, %d, %d, %d, %d, %s, %s)'], ...
            double(rootId), localSqlQuote(info.projectName), localSqlQuote(info.projectMatAbs), ...
            localSqlQuote(info.projectDirAbs), localSqlQuote(info.projectRelFromRoot), ...
            localSqlQuote(info.formatTag), localSqlQuote(info.healthStatus), localSqlQuote(info.healthMessage), ...
            localSqlQuote(info.scanTime), localSqlQuote(info.scanTime), localSqlQuote(info.scanTime), localSqlQuote(info.projectMTime), ...
            round(info.projectBytes), round(info.fovCount), round(info.roiCount), ...
            round(info.classifierCount), round(info.processorCount), round(info.pipelineRunCount), ...
            round(info.availableRawCount), round(info.missingRawCount), localSqlQuote(info.rawStatus), ...
            localSqlQuote(info.metadataJson)));
        projectId = localFetchScalar(conn, 'SELECT last_insert_rowid()');
    else
        exec(conn, sprintf(['UPDATE catalog_projects SET ' ...
            'root_id = %d, name = %s, project_dir_abs = %s, project_rel_from_root = %s, ' ...
            'format_tag = %s, health_status = %s, health_message = %s, ' ...
            'last_seen_at = %s, last_scan_at = %s, project_mtime = %s, project_bytes = %d, ' ...
            'fov_count = %d, roi_count = %d, classifier_count = %d, processor_count = %d, ' ...
            'pipeline_run_count = %d, available_raw_count = %d, missing_raw_count = %d, ' ...
            'raw_status = %s, metadata_json = %s, created_at = COALESCE(created_at, %s) WHERE id = %d'], ...
            double(rootId), localSqlQuote(info.projectName), localSqlQuote(info.projectDirAbs), ...
            localSqlQuote(info.projectRelFromRoot), localSqlQuote(info.formatTag), ...
            localSqlQuote(info.healthStatus), localSqlQuote(info.healthMessage), ...
            localSqlQuote(info.scanTime), localSqlQuote(info.scanTime), localSqlQuote(info.projectMTime), ...
            round(info.projectBytes), round(info.fovCount), round(info.roiCount), ...
            round(info.classifierCount), round(info.processorCount), round(info.pipelineRunCount), ...
            round(info.availableRawCount), round(info.missingRawCount), localSqlQuote(info.rawStatus), ...
            localSqlQuote(info.metadataJson), localSqlQuote(info.scanTime), double(projectId)));
    end
end

function localReplaceRawSources(conn, projectId, rawSources)
    exec(conn, sprintf('DELETE FROM catalog_project_raw_sources WHERE project_id = %d', double(projectId)));
    for i = 1:numel(rawSources)
        row = rawSources(i);
        exec(conn, sprintf(['INSERT INTO catalog_project_raw_sources(' ...
            'project_id, raw_kind, channel_index, raw_abs_path, raw_rel_from_root, exists_flag) VALUES (' ...
            '%d, %s, %d, %s, %s, %d)'], ...
            double(projectId), localSqlQuote(row.rawKind), round(row.channelIndex), ...
            localSqlQuote(row.rawAbsPath), localSqlQuote(row.rawRelFromRoot), round(row.existsFlag)));
    end
end

function localReplaceRawDatasetLinks(conn, projectId, rawSources, scanTime)
    exec(conn, sprintf('DELETE FROM catalog_project_raw_links WHERE project_id = %d', double(projectId)));
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    linkedIds = [];

    for i = 1:numel(rawSources)
        row = rawSources(i);
        if isempty(row.rawAbsPath) || ~logical(row.existsFlag)
            continue;
        end
        try
            [rawDatasetId, ~] = detecdiv_catalog_upsert_raw_dataset_record( ...
                conn, '', row.rawAbsPath, 'ScanTime', scanTime);
        catch
            continue;
        end
        key = char(string(rawDatasetId));
        if isKey(seen, key)
            continue;
        end
        seen(key) = true;
        linkedIds(end+1) = double(rawDatasetId); %#ok<AGROW>
        exec(conn, sprintf(['INSERT INTO catalog_project_raw_links(project_id, raw_dataset_id, link_type, created_at) ' ...
            'VALUES (%d, %d, %s, %s)'], ...
            double(projectId), double(rawDatasetId), localSqlQuote('source'), localSqlQuote(scanTime)));
    end

    for i = 1:numel(linkedIds)
        projectCount = localFetchScalar(conn, sprintf( ...
            'SELECT COUNT(*) FROM catalog_project_raw_links WHERE raw_dataset_id = %d', linkedIds(i)));
        if isempty(projectCount)
            projectCount = 0;
        end
        exec(conn, sprintf('UPDATE catalog_raw_datasets SET project_count = %d WHERE id = %d', ...
            round(projectCount), linkedIds(i)));
    end
end

function localReplacePipelineRuns(conn, projectId, pipelineRuns, scanTime)
    exec(conn, sprintf('DELETE FROM catalog_pipeline_runs WHERE project_id = %d', double(projectId)));
    for i = 1:numel(pipelineRuns)
        row = pipelineRuns(i);
        exec(conn, sprintf(['INSERT INTO catalog_pipeline_runs(' ...
            'project_id, run_id, run_path_abs, pipeline_id, pipeline_path, status, created_at, updated_at, summary_json, last_seen_at) VALUES (' ...
            '%d, %s, %s, %s, %s, %s, %s, %s, %s, %s)'], ...
            double(projectId), localSqlQuote(row.runId), localSqlQuote(row.runPathAbs), ...
            localSqlQuote(row.pipelineId), localSqlQuote(row.pipelinePath), localSqlQuote(row.status), ...
            localSqlQuote(row.createdAt), localSqlQuote(row.updatedAt), ...
            localSqlQuote(row.summaryJson), localSqlQuote(scanTime)));
    end
end

function missingCount = localMarkMissingProjects(conn, rootId, seenMap)
    data = fetch(conn, sprintf(['SELECT id, project_mat_abs, project_dir_abs FROM catalog_projects ' ...
        'WHERE root_id = %d'], double(rootId)));
    missingCount = 0;
    if isempty(data) || ~istable(data)
        return;
    end

    nowText = localNowText();
    for i = 1:height(data)
        matPath = char(string(data.project_mat_abs(i)));
        dirPath = char(string(data.project_dir_abs(i)));
        if isKey(seenMap, lower(matPath))
            continue;
        end

        if ~isfile(matPath)
            healthStatus = 'missing_project_mat';
            healthMessage = 'Project MAT file was not found during the latest scan.';
        elseif ~isfolder(dirPath)
            healthStatus = 'missing_project_dir';
            healthMessage = 'Project folder was not found during the latest scan.';
        else
            continue;
        end

        exec(conn, sprintf(['UPDATE catalog_projects SET health_status = %s, health_message = %s, last_scan_at = %s ' ...
            'WHERE id = %d'], localSqlQuote(healthStatus), localSqlQuote(healthMessage), ...
            localSqlQuote(nowText), double(data.id(i))));
        missingCount = missingCount + 1;
    end
end

function n = localCountChildDirs(folderPath)
    n = 0;
    if ~isfolder(folderPath)
        return;
    end
    d = dir(folderPath);
    d = d([d.isdir]);
    d = d(~ismember({d.name}, {'.', '..'}));
    n = numel(d);
end

function tf = localIsEmptyId(obj, fieldName)
    tf = true;
    try
        if isprop(obj, fieldName)
            value = obj.(fieldName);
        elseif isstruct(obj) && isfield(obj, fieldName)
            value = obj.(fieldName);
        else
            return;
        end
        tf = isempty(char(string(value)));
    catch
        tf = true;
    end
end

function tf = localHasField(obj, fieldName)
    tf = false;
    try
        tf = isprop(obj, fieldName);
    catch
        tf = false;
    end
end

function value = localGetField(obj, fieldName, defaultValue)
    value = defaultValue;
    try
        if isstruct(obj) && isfield(obj, fieldName)
            candidate = obj.(fieldName);
        elseif isobject(obj) && isprop(obj, fieldName)
            candidate = obj.(fieldName);
        else
            return;
        end
        if ~isempty(candidate)
            value = candidate;
        end
    catch
        value = defaultValue;
    end
end

function value = localGetNestedField(S, fieldPath, defaultValue)
    value = defaultValue;
    current = S;
    for i = 1:numel(fieldPath)
        if ~isstruct(current) || ~isfield(current, fieldPath{i})
            return;
        end
        current = current.(fieldPath{i});
    end
    if ~isempty(current)
        value = current;
    end
end

function scalar = localFetchScalar(conn, sql)
    scalar = [];
    data = fetch(conn, sql);
    if isempty(data)
        return;
    end
    if istable(data)
        if height(data) >= 1 && width(data) >= 1
            scalar = data{1, 1};
        end
    elseif iscell(data)
        scalar = data{1};
    else
        scalar = data(1);
    end
end

function txt = localNowText()
    txt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function txt = localDateToText(dn)
    txt = '';
    try
        txt = char(datetime(dn, 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    catch
    end
end

function txt = localToJson(value)
    if isempty(value)
        txt = '{}';
        return;
    end
    try
        txt = jsonencode(value);
    catch
        txt = '{}';
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

function relPath = localRelativeToRoot(rootPath, targetPath)
    relPath = '';
    rootNorm = localNormalizeForCompare(rootPath);
    targetNorm = localNormalizeForCompare(targetPath);

    if strcmp(targetNorm, rootNorm)
        relPath = '.';
        return;
    end

    prefix = [rootNorm '/'];
    if startsWith(targetNorm, prefix)
        relPath = targetNorm(numel(prefix)+1:end);
    end
end

function out = localNormalizeForCompare(pathIn)
    out = lower(char(string(pathIn)));
    out = strrep(out, '\', '/');
    out = regexprep(out, '/+$', '');
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
