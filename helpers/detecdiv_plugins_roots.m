function roots = detecdiv_plugins_roots()
%DETECDIV_PLUGINS_ROOTS Return configured external plugin roots.

roots = {};
try
    userprefs = detecdiv_prefs_load();
    if isfield(userprefs, 'plugins') && isstruct(userprefs.plugins) && ...
            isfield(userprefs.plugins, 'roots') && ~isempty(userprefs.plugins.roots)
        roots = cellstr(string(userprefs.plugins.roots));
    end
catch
end

defaultRoot = detecdiv_plugins_default_root();
if isfolder(defaultRoot)
    roots{end+1} = defaultRoot; %#ok<AGROW>
end

roots = localUniqueExistingRoots(roots);
end

function roots = localUniqueExistingRoots(roots)
out = {};
seen = {};
for i = 1:numel(roots)
    rootDir = char(string(roots{i}));
    if isempty(rootDir) || ~isfolder(rootDir)
        continue;
    end
    try
        rootDir = char(java.io.File(rootDir).getCanonicalPath());
    catch
    end
    key = lower(rootDir);
    if any(strcmp(seen, key))
        continue;
    end
    seen{end+1} = key; %#ok<AGROW>
    out{end+1} = rootDir; %#ok<AGROW>
end
roots = out;
end

