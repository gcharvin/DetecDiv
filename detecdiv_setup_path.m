function addedPaths = detecdiv_setup_path(repoRoot, varargin)
% detecdiv_setup_path  Configure a clean MATLAB path for a DetecDiv tree.
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
    ip.parse(varargin{:});
    opts = ip.Results;
    opts.ResetPath = logical(opts.ResetPath);
    opts.Verbose = logical(opts.Verbose);
    opts.IncludeRoot = logical(opts.IncludeRoot);

    repoRoot = localCanonicalPath(repoRoot);
    if ~isfolder(repoRoot)
        error('detecdiv_setup_path:RootNotFound', 'Repo root not found: %s', repoRoot);
    end

    if opts.ResetPath
        restoredefaultpath();
        rehash toolboxcache;
    end

    baseDirs = {};
    if opts.IncludeRoot
        baseDirs{end+1} = repoRoot; %#ok<AGROW>
    end

    for rel = {'engine', 'helpers', 'structure'}
        absDir = fullfile(repoRoot, rel{1});
        if isfolder(absDir)
            baseDirs{end+1} = absDir; %#ok<AGROW>
        end
    end

    addedPaths = {};
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    for i = 1:numel(baseDirs)
        allPaths = strsplit(genpath(baseDirs{i}), pathsep);
        for j = 1:numel(allPaths)
            p = localCanonicalPath(allPaths{j});
            if isempty(p) || ~isfolder(p)
                continue;
            end
            if localShouldExclude(p, repoRoot)
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

    if ~isempty(addedPaths)
        addpath(strjoin(addedPaths, pathsep));
    end

    if opts.Verbose
        fprintf('[path] DetecDiv root: %s\n', repoRoot);
        fprintf('[path] Added %d folder(s).\n', numel(addedPaths));
    end
end

function tf = localShouldExclude(pathStr, repoRoot)
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
