function groups = detecdiv_hub_list_project_groups_for_project(projectId, hubSettings)
% detecdiv_hub_list_project_groups_for_project  Find current-user groups containing a project.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_list_project_groups_for_project:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    allGroups = detecdiv_hub_list_project_groups(hubSettings);
    if isempty(allGroups)
        groups = struct([]);
        return;
    end

    if isstruct(allGroups)
        allGroups = num2cell(allGroups);
    end

    groups = repmat(struct( ...
        'id', '', ...
        'group_key', '', ...
        'display_name', '', ...
        'description', ''), 0, 1);
    keepIdx = 0;
    wantedProjectId = char(string(projectId));
    for i = 1:numel(allGroups)
        groupDetail = detecdiv_hub_get_project_group(allGroups{i}.id, hubSettings);
        if ~isfield(groupDetail, 'projects') || isempty(groupDetail.projects)
            continue;
        end
        projects = groupDetail.projects;
        if isstruct(projects)
            projectIds = string({projects.id});
        else
            projectIds = strings(0, 1);
        end
        if any(strcmp(projectIds, string(wantedProjectId)))
            keepIdx = keepIdx + 1;
            groups(keepIdx, 1) = struct( ... %#ok<AGROW>
                'id', localStructValue(allGroups{i}, 'id'), ...
                'group_key', localStructValue(allGroups{i}, 'group_key'), ...
                'display_name', localStructValue(allGroups{i}, 'display_name'), ...
                'description', localStructValue(allGroups{i}, 'description'));
        end
    end
end

function value = localStructValue(in, fieldName)
    value = '';
    if isstruct(in) && isfield(in, fieldName) && ~isempty(in.(fieldName))
        value = char(string(in.(fieldName)));
    end
end
