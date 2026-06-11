function userprefs = detecdiv_plugins_register_root(rootDir)
%DETECDIV_PLUGINS_REGISTER_ROOT Remember an external DetecDiv plugin root.

if nargin < 1 || isempty(rootDir)
    rootDir = detecdiv_plugins_default_root();
end

rootDir = char(string(rootDir));
if ~isfolder(rootDir)
    error('detecdiv_plugins_register_root:MissingRoot', ...
        'Plugin root does not exist: %s', rootDir);
end
rootDir = localNormalizePluginRoot(rootDir);

userprefs = detecdiv_prefs_load();
if ~isfield(userprefs, 'plugins') || ~isstruct(userprefs.plugins)
    userprefs.plugins = struct();
end
if ~isfield(userprefs.plugins, 'roots') || isempty(userprefs.plugins.roots)
    roots = {};
else
    roots = cellstr(string(userprefs.plugins.roots));
end

rootDir = char(java.io.File(rootDir).getCanonicalPath());
exists = false;
for i = 1:numel(roots)
    try
        roots{i} = char(java.io.File(roots{i}).getCanonicalPath());
    catch
    end
    if strcmpi(roots{i}, rootDir)
        exists = true;
    end
end
if ~exists
    roots{end+1} = rootDir; %#ok<AGROW>
end

userprefs.plugins.roots = roots;
detecdiv_prefs_save(userprefs);
end

function rootDir = localNormalizePluginRoot(rootDir)
rootDir = char(string(rootDir));

[parentDir, folderName] = fileparts(rootDir);
if startsWith(folderName, '+')
    rootDir = parentDir;
    [parentDir, folderName] = fileparts(rootDir);
end

if any(strcmpi(folderName, {'processor','classifier'}))
    [maybePluginsDir, maybeTypeDir] = fileparts(rootDir);
    if strcmpi(maybeTypeDir, folderName)
        [repoDir, pluginsFolder] = fileparts(maybePluginsDir);
        if strcmpi(pluginsFolder, 'plugins')
            rootDir = repoDir;
        end
    end
end
end
