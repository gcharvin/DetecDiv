function plugins = detecdiv_plugins_addpath()
%DETECDIV_PLUGINS_ADDPATH Add registered plugin package roots to MATLAB path.

plugins = detecdiv_plugins_list();
roots = detecdiv_plugins_roots();
for i = 1:numel(plugins)
    roots{end+1} = plugins(i).root; %#ok<AGROW>
end
roots = unique(roots, 'stable');

pathChanged = false;
for i = 1:numel(roots)
    if isfolder(roots{i}) && ~contains(path, roots{i})
        addpath(roots{i});
        pathChanged = true;
    end
end
if pathChanged
    rehash;
end
end
