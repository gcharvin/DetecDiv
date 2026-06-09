function [shallowObj, msg, projectDetail, resolutionInfo] = detecdiv_hub_load_project(projectRef, hubSettings)
% detecdiv_hub_load_project  Load a DetecDiv project locally from detecdiv-hub metadata.
%
% Usage
%   projects = detecdiv_hub_list_projects();
%   shallowObj = detecdiv_hub_load_project(projects(1).id);
%
% The resolver first tries the path returned by the hub. If that does not
% exist locally, it tries hubSettings.storageRootMap.<storage_root.name>.

    shallowObj = [];
    msg = '';
    projectDetail = struct();
    resolutionInfo = struct();

    if nargin < 1 || isempty(projectRef)
        error('detecdiv_hub_load_project:MissingProjectReference', ...
            'A project id or project detail struct is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    if isstruct(projectRef)
        projectDetail = projectRef;
    else
        projectDetail = detecdiv_hub_get_project(projectRef, hubSettings);
    end

    [projectMatPath, resolutionInfo] = detecdiv_hub_resolve_project_location(projectDetail, hubSettings);
    if isempty(projectMatPath)
        msg = localBuildMissingPathMessage(projectDetail, resolutionInfo);
        warning('detecdiv_hub_load_project:PathNotResolved', '%s', msg);
        return;
    end

    if isfield(resolutionInfo, 'projectDirPath') && ~isempty(resolutionInfo.projectDirPath)
        [shallowObj, msg] = shallowLoad(projectMatPath, 'ProjectDir', resolutionInfo.projectDirPath);
    else
        [shallowObj, msg] = shallowLoad(projectMatPath);
    end
    if ~isempty(shallowObj) && isa(shallowObj, 'shallow')
        shallowObj = localApplyHubLoadMetadata(shallowObj, projectDetail, projectMatPath, resolutionInfo);
    end

    if isstruct(projectDetail) && isfield(projectDetail, 'id') && ~isempty(projectDetail.id)
        hubSettings.lastProjectId = char(string(projectDetail.id));
        detecdiv_hub_settings_set(hubSettings);
    end
end

function shallowObj = localApplyHubLoadMetadata(shallowObj, projectDetail, projectMatPath, resolutionInfo)
    if ~isprop(shallowObj, 'runProfiles') || ~isstruct(shallowObj.runProfiles)
        shallowObj.runProfiles = struct();
    end
    if ~isfield(shallowObj.runProfiles, 'hub') || ~isstruct(shallowObj.runProfiles.hub)
        shallowObj.runProfiles.hub = struct();
    end
    shallowObj.runProfiles.hub.hubManaged = true;
    shallowObj.runProfiles.hub.hub_project_id = localField(projectDetail, 'id');
    shallowObj.runProfiles.hub.project_id = shallowObj.runProfiles.hub.hub_project_id;
    shallowObj.runProfiles.hub.project_key = localField(projectDetail, 'project_key');
    shallowObj.runProfiles.hub.project_name = localField(projectDetail, 'project_name');
    shallowObj.runProfiles.hub.project_mat_path = char(string(projectMatPath));
    shallowObj.runProfiles.hub.local_project_mat_path = char(string(projectMatPath));
    shallowObj.runProfiles.hub.project_dir_path = char(string(localInfoField(resolutionInfo, 'projectDirPath')));
    shallowObj.runProfiles.hub.local_project_dir_path = shallowObj.runProfiles.hub.project_dir_path;
    shallowObj.runProfiles.hub.storage_is_shared_with_raw_dataset = localMetadataLogical(projectDetail, 'storage_is_shared_with_raw_dataset');
    shallowObj.runProfiles.hub.loaded_from_hub_at = char(datetime('now'));
end

function value = localField(S, fieldName)
    value = '';
    try
        if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
            value = char(string(S.(fieldName)));
        end
    catch
        value = '';
    end
end

function value = localInfoField(S, fieldName)
    value = '';
    try
        if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
            value = S.(fieldName);
        end
    catch
        value = '';
    end
end

function tf = localMetadataLogical(projectDetail, fieldName)
    tf = false;
    try
        if isstruct(projectDetail) && isfield(projectDetail, 'metadata_json') && ...
                isstruct(projectDetail.metadata_json) && isfield(projectDetail.metadata_json, fieldName)
            tf = logical(projectDetail.metadata_json.(fieldName));
        end
    catch
        tf = false;
    end
end

function msg = localBuildMissingPathMessage(projectDetail, resolutionInfo)
    projectLabel = 'unknown project';
    if isstruct(projectDetail)
        if isfield(projectDetail, 'project_name') && ~isempty(projectDetail.project_name)
            projectLabel = char(string(projectDetail.project_name));
        elseif isfield(projectDetail, 'project_key') && ~isempty(projectDetail.project_key)
            projectLabel = char(string(projectDetail.project_key));
        elseif isfield(projectDetail, 'id') && ~isempty(projectDetail.id)
            projectLabel = char(string(projectDetail.id));
        end
    end

    if isfield(resolutionInfo, 'candidatePaths') && ~isempty(resolutionInfo.candidatePaths)
        candidateText = strjoin(resolutionInfo.candidatePaths, ' | ');
    else
        candidateText = 'no candidate path';
    end

    msg = sprintf('Could not resolve a local .mat path for %s. Tried: %s', ...
        projectLabel, candidateText);
    if isfield(resolutionInfo, 'missingProjectFolders') && ~isempty(resolutionInfo.missingProjectFolders)
        msg = sprintf('%s. Found .mat file(s), but missing project folder(s): %s', ...
            msg, strjoin(resolutionInfo.missingProjectFolders, ' | '));
    end
end
