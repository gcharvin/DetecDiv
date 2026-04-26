function ref = localProjectRef(project, hub)
% localProjectRef  Shared helper for hub wrappers.

    if nargin < 2 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end
    if isa(project, 'shallow')
        ref = detecdiv_hub_project_ref(project, hub);
    elseif isstruct(project)
        ref = project;
        if ~isfield(ref, 'project_id') && isfield(ref, 'id')
            ref.project_id = char(string(ref.id));
        end
        if ~isfield(ref, 'project_mat_path')
            ref.project_mat_path = '';
        end
    else
        ref = struct('project_id', char(string(project)), 'project_mat_path', '');
    end
end
