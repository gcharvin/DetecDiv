function [projectMatPath, info] = detecdiv_hub_resolve_project_location(projectDetail, hubSettings)
% detecdiv_hub_resolve_project_location  Resolve a local .mat path for a hub project.
%
% Resolution order:
%   1) Use location.storage_root.path_prefix directly
%   2) Apply hubSettings.storageRootMap.<storage_root.name> if defined

    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    info = struct( ...
        'locationId', [], ...
        'storageRootName', '', ...
        'storageRootPathPrefix', '', ...
        'resolutionMethod', '', ...
        'candidatePaths', {{}});
    projectMatPath = '';

    [metadataCandidate, metadataMethod] = localMetadataCandidate(projectDetail, hubSettings);
    if ~isempty(metadataCandidate)
        info.candidatePaths{end+1} = metadataCandidate; %#ok<AGROW>
        if isfile(metadataCandidate)
            projectMatPath = metadataCandidate;
            info.resolutionMethod = metadataMethod;
            return;
        end
    end

    if ~isstruct(projectDetail) || ~isfield(projectDetail, 'locations') || isempty(projectDetail.locations)
        return;
    end

    locations = localSortLocations(projectDetail.locations);
    for i = 1:numel(locations)
        [candidatePaths, methods] = localLocationCandidates(locations(i), hubSettings);
        for j = 1:numel(candidatePaths)
            info.candidatePaths{end+1} = candidatePaths{j}; %#ok<AGROW>
            if isfile(candidatePaths{j})
                projectMatPath = candidatePaths{j};
                info.locationId = localGetFieldOr(locations(i), 'id', []);
                info.storageRootName = localGetStorageRootField(locations(i), 'name');
                info.storageRootPathPrefix = localGetStorageRootField(locations(i), 'path_prefix');
                info.resolutionMethod = methods{j};
                return;
            end
        end
    end
end

function [candidatePath, method] = localMetadataCandidate(projectDetail, hubSettings)
    candidatePath = '';
    method = '';

    if ~isstruct(projectDetail) || ~isfield(projectDetail, 'metadata_json') || ...
            ~isstruct(projectDetail.metadata_json)
        return;
    end

    metadata = projectDetail.metadata_json;
    if isfield(metadata, 'project_mat_abs') && ~isempty(metadata.project_mat_abs)
        candidatePath = char(string(metadata.project_mat_abs));
        method = 'metadata_json.project_mat_abs';
        return;
    end

    if isfield(metadata, 'project_dir_abs') && ~isempty(metadata.project_dir_abs) && ...
            isfield(metadata, 'project_rel_from_root') && ~isempty(metadata.project_rel_from_root)
        rootName = localMetadataRootName(projectDetail);
        mappedPrefix = localLookupMappedRoot(hubSettings, rootName);
        if ~isempty(mappedPrefix)
            [~, fileName] = fileparts(char(string(metadata.project_dir_abs)));
            candidatePath = fullfile(mappedPrefix, [fileName '.mat']);
            method = ['storageRootMap:' rootName ':metadataProjectDir']; %#ok<AGROW>
        end
    end
end

function locations = localSortLocations(locations)
    if numel(locations) <= 1
        return;
    end

    scores = zeros(1, numel(locations));
    for i = 1:numel(locations)
        scores(i) = 100;
        if isfield(locations(i), 'is_preferred') && localToLogical(locations(i).is_preferred)
            scores(i) = scores(i) - 50;
        end

        hostScope = lower(string(localGetStorageRootField(locations(i), 'host_scope')));
        if hostScope == "client"
            scores(i) = scores(i) - 25;
        elseif hostScope == "all"
            scores(i) = scores(i) - 10;
        end
    end

    [~, order] = sort(scores);
    locations = locations(order);
end

function [candidatePaths, methods] = localLocationCandidates(location, hubSettings)
    candidatePaths = {};
    methods = {};

    prefix = char(string(localGetStorageRootField(location, 'path_prefix')));
    rootName = char(string(localGetStorageRootField(location, 'name')));
    relativePath = localNormalizeRelativePath(localGetFieldOr(location, 'relative_path', ''));
    projectFileName = char(string(localGetFieldOr(location, 'project_file_name', '')));

    directPath = localBuildProjectMatPath(prefix, relativePath, projectFileName);
    if ~isempty(directPath)
        candidatePaths{end+1} = directPath; %#ok<AGROW>
        methods{end+1} = 'direct'; %#ok<AGROW>
    end

    mappedPrefix = localLookupMappedRoot(hubSettings, rootName);
    if ~isempty(mappedPrefix)
        mappedPath = localBuildProjectMatPath(mappedPrefix, relativePath, projectFileName);
        if ~isempty(mappedPath) && ~any(strcmp(candidatePaths, mappedPath))
            candidatePaths{end+1} = mappedPath; %#ok<AGROW>
            methods{end+1} = ['storageRootMap:' rootName]; %#ok<AGROW>
        end
    end
end

function out = localBuildProjectMatPath(prefix, relativePath, projectFileName)
    out = '';
    if isempty(prefix) || isempty(projectFileName)
        return;
    end

    prefix = char(string(prefix));
    relativePath = char(string(relativePath));
    projectFileName = char(string(projectFileName));

    if isempty(relativePath)
        out = fullfile(prefix, projectFileName);
    else
        out = fullfile(prefix, relativePath, projectFileName);
    end

    if ispc
        out = strrep(out, '/', '\');
    else
        out = strrep(out, '\', '/');
    end
end

function relativePath = localNormalizeRelativePath(relativePath)
    relativePath = char(string(relativePath));
    if isempty(relativePath)
        return;
    end

    relativePath = strrep(relativePath, '/', filesep);
    relativePath = strrep(relativePath, '\', filesep);
end

function mappedPrefix = localLookupMappedRoot(hubSettings, rootName)
    mappedPrefix = '';
    if ~isfield(hubSettings, 'storageRootMap') || ~isstruct(hubSettings.storageRootMap)
        return;
    end
    if isempty(rootName)
        return;
    end

    validName = matlab.lang.makeValidName(rootName);
    if isfield(hubSettings.storageRootMap, validName)
        mappedPrefix = char(string(hubSettings.storageRootMap.(validName)));
    end
end

function rootName = localMetadataRootName(projectDetail)
    rootName = '';
    if ~isstruct(projectDetail) || ~isfield(projectDetail, 'locations') || isempty(projectDetail.locations)
        return;
    end
    rootName = char(string(localGetStorageRootField(projectDetail.locations(1), 'name')));
end

function value = localGetStorageRootField(location, fieldName)
    value = '';
    if isfield(location, 'storage_root') && isstruct(location.storage_root) && ...
            isfield(location.storage_root, fieldName)
        value = location.storage_root.(fieldName);
    end
end

function value = localGetFieldOr(in, fieldName, defaultValue)
    if isstruct(in) && isfield(in, fieldName)
        value = in.(fieldName);
    else
        value = defaultValue;
    end
end

function tf = localToLogical(value)
    if islogical(value)
        tf = value;
        return;
    end

    if isnumeric(value)
        tf = value ~= 0;
        return;
    end

    tf = any(strcmpi(char(string(value)), {'true', '1', 'yes'}));
end
