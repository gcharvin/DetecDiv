function plugins = detecdiv_plugins_list()
%DETECDIV_PLUGINS_LIST Discover external DetecDiv plugin packages.

roots = detecdiv_plugins_roots();
plugins = struct('name', {}, 'type', {}, 'root', {}, 'path', {}, ...
    'entrypoint', {}, 'manifest', {}, 'summary', {});

for r = 1:numel(roots)
    rootDir = roots{r};
    plugins = [plugins, localDiscoverType(rootDir, 'processor')]; %#ok<AGROW>
    plugins = [plugins, localDiscoverType(rootDir, 'classifier')]; %#ok<AGROW>
end
end

function plugins = localDiscoverType(rootDir, typeName)
plugins = struct('name', {}, 'type', {}, 'root', {}, 'path', {}, ...
    'entrypoint', {}, 'manifest', {}, 'summary', {});

parentDir = fullfile(rootDir, 'plugins', typeName);
if ~isfolder(parentDir)
    return;
end

dirs = dir(fullfile(parentDir, '+*'));
dirs = dirs([dirs.isdir]);
[~, idx] = sort({dirs.name});
dirs = dirs(idx);

for i = 1:numel(dirs)
    pkgDir = fullfile(parentDir, dirs(i).name);
    pkg = erase(dirs(i).name, '+');
    entrypoint = '';
    if strcmp(typeName, 'processor') && isfile(fullfile(pkgDir, 'process.m'))
        entrypoint = [pkg '.process'];
    elseif strcmp(typeName, 'classifier') && isfile(fullfile(pkgDir, 'classify.m'))
        entrypoint = [pkg '.classify'];
    end
    if isempty(entrypoint)
        continue;
    end

    manifest = struct();
    summary = ['Plugin ' typeName ' package: ' pkg];
    manifestFile = fullfile(pkgDir, 'plugin.json');
    if isfile(manifestFile)
        try
            manifest = jsondecode(fileread(manifestFile));
            if isfield(manifest, 'summary') && ~isempty(manifest.summary)
                summary = char(string(manifest.summary));
            end
            if isfield(manifest, 'entrypoint') && ~isempty(manifest.entrypoint)
                entrypoint = char(string(manifest.entrypoint));
            end
        catch
        end
    end

    plugins(end+1) = struct( ... %#ok<AGROW>
        'name', char(string(pkg)), ...
        'type', char(string(typeName)), ...
        'root', char(string(parentDir)), ...
        'path', char(string(pkgDir)), ...
        'entrypoint', char(string(entrypoint)), ...
        'manifest', manifest, ...
        'summary', char(string(summary)));
end
end

