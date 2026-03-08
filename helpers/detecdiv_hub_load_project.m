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

    [shallowObj, msg] = shallowLoad(projectMatPath);

    if isstruct(projectDetail) && isfield(projectDetail, 'id') && ~isempty(projectDetail.id)
        hubSettings.lastProjectId = char(string(projectDetail.id));
        detecdiv_hub_settings_set(hubSettings);
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
end
