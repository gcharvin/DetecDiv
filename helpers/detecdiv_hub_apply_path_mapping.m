function [mappedPath, method] = detecdiv_hub_apply_path_mapping(pathIn, hubSettings)
% Resolve a server path or Windows share alias to this client's preferred root.
% Use the same mapping engine as Hub submission, including pathMappings,
% legacy pathPrefixMap entries and verified mapped-drive/UNC equivalences.

    mappedPath = '';
    method = '';
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end
    [candidate, mapped] = detecdiv_paths_map_module_path(pathIn, ...
        struct('hub', hubSettings), 'local');
    if mapped
        mappedPath = candidate;
        method = 'sharedPathMapping';
    end
end
