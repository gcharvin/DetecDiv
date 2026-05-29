function [p2, ok, how] = detecdiv_paths_rebase_datasetpath(oldDatasetPath, newRoot, debug, maxDepth, allowDirectDatasetRename)
% Rebase a dataset folder path such as *.ome.zarr under a new root.
% Strategy:
%   1) Accept exact dataset folder selection.
%   2) Try deterministic suffix candidates under the selected root.
%   3) Optionally search by dataset folder name at bounded depth.

p2 = "";
ok = false;
how = "";

if nargin < 3, debug = false; end
if nargin < 4 || isempty(maxDepth), maxDepth = 0; end
if nargin < 5, allowDirectDatasetRename = false; end
allowDirectDatasetRename = logical(allowDirectDatasetRename);

oldDatasetPath = string(oldDatasetPath);
newRoot = string(newRoot);

if strlength(oldDatasetPath) == 0 || strlength(newRoot) == 0
    return;
end

infos = localDatasetInfoCandidates(oldDatasetPath);
if isempty(infos)
    return;
end
datasetNames = unique(string({infos.datasetName}), 'stable');
datasetName = datasetNames(1);

% User picked the dataset folder directly.
if isfolder(newRoot)
    newRootLeaf = localLeafName(newRoot);
    for iInfo = 1:numel(datasetNames)
        if localNormName(newRootLeaf) == localNormName(datasetNames(iInfo)) && ...
                localLooksLikeDatasetFolder(newRoot)
            p2 = newRoot;
            ok = true;
            how = "pickedDataset";
            return;
        end
    end

    if allowDirectDatasetRename && localLooksLikeDatasetFolder(newRoot)
        p2 = newRoot;
        ok = true;
        how = "pickedRenamedDataset";
        return;
    end
else
    return;
end

% Deterministic candidates from the selected root.
cands = strings(0,1);
for j = 1:numel(infos)
    suffixes = localSuffixCandidatesFromInfo(infos(j));
    for i = 1:numel(suffixes)
        cands(end+1,1) = string(fullfile(char(newRoot), char(string(suffixes{i})))); %#ok<AGROW>
    end
    cands(end+1,1) = string(fullfile(char(newRoot), char(infos(j).datasetName)));
    if strlength(infos(j).parentLeaf) > 0
        cands(end+1,1) = string(fullfile(char(newRoot), char(infos(j).parentLeaf), char(infos(j).datasetName)));
    end
end

cands = unique(cands, 'stable');
for i = 1:numel(cands)
    cand = cands(i);
    if isfolder(cand) && localLooksLikeDatasetFolder(cand)
        p2 = cand;
        ok = true;
        how = "suffix";
        return;
    end
end

% Optional bounded recursive search by dataset folder name.
if maxDepth > 0
    for iInfo = 1:numel(datasetNames)
        found = localFindDatasetFolder(newRoot, datasetNames(iInfo), maxDepth);
        if strlength(found) > 0
            p2 = found;
            ok = true;
            how = "scan";
            return;
        end
    end
end

if debug
    fprintf('[paths] rebase_datasetpath failed for dataset: %s under root: %s\n', ...
        datasetName, newRoot);
end
end

function tf = localLooksLikeDatasetFolder(p)
tf = false;
if ~isfolder(p)
    return;
end

if endsWith(p, '.ome.zarr', 'IgnoreCase', true)
    tf = localHasZarrRootMetadata(p);
    return;
end

tf = localHasZarrRootMetadata(p) || exist(fullfile(p, 'NDTiff.index'), 'file') == 2;
end

function tf = localHasZarrRootMetadata(pathStr)
tf = exist(fullfile(pathStr, 'zarr.json'), 'file') == 2 || ...
    (exist(fullfile(pathStr, '.zattrs'), 'file') == 2 && ...
     exist(fullfile(pathStr, '.zgroup'), 'file') == 2);
end

function suffixes = localSuffixCandidatesFromInfo(info)
parts = info.parts;
suffixes = {};
for k = 2:min(8, numel(parts))
    tail = cellstr(parts(end-k+1:end));
    suffixes{end+1} = string(fullfile(tail{:})); %#ok<AGROW>
end
end

function leaf = localLeafName(p0)
infos = localDatasetInfoCandidates(p0);
if isempty(infos)
    leaf = "";
else
    leaf = infos(1).datasetName;
end
end

function leaf = localParentLeafName(p0)
infos = localDatasetInfoCandidates(p0);
if isempty(infos)
    leaf = "";
else
    leaf = infos(1).parentLeaf;
end
end

function out = localFindDatasetFolder(root, datasetName, maxDepth)
out = "";
if maxDepth <= 0 || ~isfolder(root)
    return;
end

try
    d = dir(root);
catch
    return;
end

d = d([d.isdir]);
for i = 1:numel(d)
    nm = string(d(i).name);
    if nm == "." || nm == ".."
        continue;
    end
    cand = string(fullfile(root, nm));
    if localNormName(nm) == localNormName(datasetName) && localLooksLikeDatasetFolder(cand)
        out = cand;
        return;
    end
end

for i = 1:numel(d)
    nm = string(d(i).name);
    if nm == "." || nm == ".."
        continue;
    end
    out = localFindDatasetFolder(fullfile(root, nm), datasetName, maxDepth-1);
    if strlength(out) > 0
        return;
    end
end
end

function n = localNormName(s)
n = lower(strtrim(string(s)));
n = regexprep(n, '\s+', '');
end

function infos = localDatasetInfoCandidates(p0)
infos = repmat(struct( ...
    'parts', strings(0,1), ...
    'datasetName', "", ...
    'parentLeaf', ""), 0, 1);

p = strrep(string(p0), '\', '/');
p = regexprep(p, '/+', '/');
parts = split(p, '/');
parts(parts == "") = [];
if isempty(parts)
    return;
end

leaf = parts(end);
info = struct( ...
    'parts', strings(0,1), ...
    'datasetName', "", ...
    'parentLeaf', "");
info.parts = parts;
info.datasetName = string(leaf);
if numel(parts) >= 2
    info.parentLeaf = string(parts(end-1));
end
infos(end+1) = info; %#ok<AGROW>

% Also support a legacy malformed serialization where a separator before
% the dataset leaf may have been lost.
tok = regexp(char(leaf), '^(\d{4}[_-]\d{2}[_-]\d{2})([^/\\]+\.ome\.zarr)$', 'tokens', 'once', 'ignorecase');
if ~isempty(tok)
    info2 = info;
    info2.parts = parts;
    info2.parts(end) = string(tok{1});
    info2.parts(end+1) = string(tok{2});
    info2.datasetName = string(tok{2});
    info2.parentLeaf = string(tok{1});
    infos(end+1) = info2; %#ok<AGROW>
end
end
