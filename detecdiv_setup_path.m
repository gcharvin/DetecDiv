function addedPaths = detecdiv_setup_path(repoRoot, varargin)
% detecdiv_setup_path  Configure MATLAB path for detecdiv-catalog + DetecDiv runtime.
%
% Usage
%   detecdiv_setup_path()
%   detecdiv_setup_path(repoRoot)
%   detecdiv_setup_path(repoRoot, 'ResetPath', true)
%
% This avoids MATLAB "Add with Subfolders" on the whole repo and filters
% heavy or irrelevant folders such as .git, backups, doc, catalog, and caches.

    if nargin < 1 || isempty(repoRoot)
        repoRoot = fileparts(mfilename('fullpath'));
    end

    ip = inputParser;
    ip.addParameter('ResetPath', true, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('Verbose', true, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('IncludeRoot', true, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('DetecDivRoot', '', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;
    opts.ResetPath = logical(opts.ResetPath);
    opts.Verbose = logical(opts.Verbose);
    opts.IncludeRoot = logical(opts.IncludeRoot);

    catalogRoot = localCanonicalPath(repoRoot);
    if ~isfolder(catalogRoot)
        error('detecdiv_setup_path:RootNotFound', 'Catalog root not found: %s', catalogRoot);
    end

    detecdivRoot = localResolveDetecDivRoot(catalogRoot, opts.DetecDivRoot);
    useExternalRuntime = ~isempty(detecdivRoot) && isfolder(detecdivRoot) && ~strcmpi(detecdivRoot, catalogRoot);

    if ~useExternalRuntime
        detecdivRoot = catalogRoot;
    end

    if opts.ResetPath
        restoredefaultpath();
        rehash toolboxcache;
    end

    addedPaths = {};
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    addedPaths = localCollectRuntimePaths(addedPaths, seen, detecdivRoot, opts.IncludeRoot);
    if useExternalRuntime
        addedPaths = localCollectCatalogClientPaths(addedPaths, seen, catalogRoot);
    end

    if ~isempty(addedPaths)
        addpath(strjoin(addedPaths, pathsep));
        if useExternalRuntime
            localPrioritizeCatalogClientPaths(catalogRoot);
        end
    end

    if opts.Verbose
        fprintf('[path] Catalog root : %s\n', catalogRoot);
        fprintf('[path] DetecDiv root: %s\n', detecdivRoot);
        if useExternalRuntime
            fprintf('[path] Runtime mode: external DetecDiv\n');
        else
            fprintf('[path] Runtime mode: embedded catalog fallback\n');
        end
        fprintf('[path] Added %d folder(s).\n', numel(addedPaths));
    end
end

function localPrioritizeCatalogClientPaths(catalogRoot)
    paths = { ...
        catalogRoot, ...
        fullfile(catalogRoot, 'helpers'), ...
        fullfile(catalogRoot, 'catalog_gui')};
    for i = numel(paths):-1:1
        if isfolder(paths{i})
            addpath(paths{i}, '-begin');
        end
    end
end

function addedPaths = localCollectRuntimePaths(addedPaths, seen, runtimeRoot, includeRoot)
    baseDirs = {};
    if includeRoot
        baseDirs{end+1} = runtimeRoot; %#ok<AGROW>
    end

    for rel = {'engine', 'helpers', 'structure'}
        absDir = fullfile(runtimeRoot, rel{1});
        if isfolder(absDir)
            baseDirs{end+1} = absDir; %#ok<AGROW>
        end
    end

    addedPaths = localAppendPathTree(addedPaths, seen, baseDirs, runtimeRoot, false);
end

function addedPaths = localCollectCatalogClientPaths(addedPaths, seen, catalogRoot)
    rootDir = catalogRoot;
    if isfolder(rootDir)
        addedPaths = localAppendExactPath(addedPaths, seen, rootDir);
    end

    helpersDir = fullfile(catalogRoot, 'helpers');
    if isfolder(helpersDir)
        addedPaths = localAppendPathTree(addedPaths, seen, {helpersDir}, catalogRoot, true);
    end

    guiDir = fullfile(catalogRoot, 'catalog_gui');
    if isfolder(guiDir)
        addedPaths = localAppendExactPath(addedPaths, seen, guiDir);
    end
end

function addedPaths = localAppendPathTree(addedPaths, seen, baseDirs, rootPath, catalogClientMode)
    for i = 1:numel(baseDirs)
        allPaths = strsplit(genpath(baseDirs{i}), pathsep);
        for j = 1:numel(allPaths)
            p = localCanonicalPath(allPaths{j});
            if isempty(p) || ~isfolder(p)
                continue;
            end
            if localShouldExclude(p, rootPath, catalogClientMode)
                continue;
            end
            key = lower(p);
            if isKey(seen, key)
                continue;
            end
            seen(key) = true;
            addedPaths{end+1} = p; %#ok<AGROW>
        end
    end
end

function addedPaths = localAppendExactPath(addedPaths, seen, dirPath)
    p = localCanonicalPath(dirPath);
    if isempty(p) || ~isfolder(p)
        return;
    end
    key = lower(p);
    if isKey(seen, key)
        return;
    end
    seen(key) = true;
    addedPaths{end+1} = p; %#ok<AGROW>
end

function tf = localShouldExclude(pathStr, repoRoot, catalogClientMode)
    tf = false;

    rel = localRelativePath(repoRoot, pathStr);
    parts = regexp(rel, '[\\/]+', 'split');
    parts = parts(~cellfun(@isempty, parts));

    excludedNames = { ...
        '.git', '.github', '.vs', '.idea', ...
        'backups', 'doc', 'catalog', '__pycache__' ...
        };

    if any(ismember(lower(parts), lower(excludedNames)))
        tf = true;
        return;
    end

    [~, leaf] = fileparts(pathStr);
    if startsWith(leaf, '.', 'IgnoreCase', false)
        tf = true;
        return;
    end

    if catalogClientMode
        relNorm = lower(strrep(rel, '\', '/'));
        if strcmp(relNorm, 'engine') || startsWith(relNorm, 'engine/') || ...
                strcmp(relNorm, 'structure/classes') || startsWith(relNorm, 'structure/classes/') || ...
                strcmp(relNorm, 'structure/io') || startsWith(relNorm, 'structure/io/') || ...
                strcmp(relNorm, 'structure/processor') || startsWith(relNorm, 'structure/processor/') || ...
                strcmp(relNorm, 'structure/classification') || startsWith(relNorm, 'structure/classification/')
            tf = true;
            return;
        end

        if strcmp(relNorm, 'structure/gui') || startsWith(relNorm, 'structure/gui/')
            tf = true;
            return;
        end
    end
end

function rel = localRelativePath(rootPath, targetPath)
    rootNorm = localNormalizePath(rootPath);
    targetNorm = localNormalizePath(targetPath);

    if strcmp(targetNorm, rootNorm)
        rel = '.';
        return;
    end

    prefix = [rootNorm '/'];
    if startsWith(targetNorm, prefix)
        rel = targetNorm(numel(prefix)+1:end);
    else
        rel = targetNorm;
    end
end

function out = localNormalizePath(pathIn)
    out = lower(char(string(pathIn)));
    out = strrep(out, '\', '/');
    out = regexprep(out, '/+$', '');
end

function out = localCanonicalPath(pathIn)
    out = char(string(pathIn));
    if isempty(out)
        return;
    end

    if ispc
        out = strrep(out, '/', '\');
    else
        out = strrep(out, '\', '/');
    end

    try
        out = char(java.io.File(out).getCanonicalPath());
    catch
    end
end

function detecdivRoot = localResolveDetecDivRoot(catalogRoot, explicitRoot)
    detecdivRoot = '';

    candidates = {};
    if strlength(string(explicitRoot)) > 0
        candidates{end+1} = char(string(explicitRoot)); %#ok<AGROW>
    end

    envRoot = getenv('DETECDIV_ROOT');
    if ~isempty(envRoot)
        candidates{end+1} = envRoot; %#ok<AGROW>
    end

    siblingRoot = fullfile(fileparts(catalogRoot), 'DetecDiv');
    candidates{end+1} = siblingRoot; %#ok<AGROW>

    for i = 1:numel(candidates)
        cand = localCanonicalPath(candidates{i});
        if localLooksLikeDetecDivRuntime(cand)
            detecdivRoot = cand;
            return;
        end
    end
end

function tf = localLooksLikeDetecDivRuntime(rootPath)
    tf = false;
    if isempty(rootPath) || ~isfolder(rootPath)
        return;
    end

    requiredPaths = { ...
        fullfile(rootPath, 'engine'), ...
        fullfile(rootPath, 'helpers'), ...
        fullfile(rootPath, 'structure'), ...
        fullfile(rootPath, 'structure', 'GUI', 'detecdiv_extracted.m'), ...
        fullfile(rootPath, 'structure', 'io', 'runPipeline.m')};

    tf = all(cellfun(@(p) exist(p, 'file') == 2 || exist(p, 'dir') == 7, requiredPaths));
end
