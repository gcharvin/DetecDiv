function [p2, ok, how] = detecdiv_paths_rebase_datasetpath(oldDatasetPath, newRoot, debug, maxDepth)
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

oldDatasetPath = string(oldDatasetPath);
newRoot = string(newRoot);

if strlength(oldDatasetPath) == 0 || strlength(newRoot) == 0
    return;
end

info = localParseDatasetPath(oldDatasetPath);
datasetName = info.datasetName;
if strlength(datasetName) == 0
    return;
end

% User picked the dataset folder directly.
if isfolder(newRoot)
    if localNormName(localLeafName(newRoot)) == localNormName(datasetName) && ...
            localLooksLikeDatasetFolder(newRoot)
        p2 = newRoot;
        ok = true;
        how = "pickedDataset";
        return;
    end
else
    return;
end

% Deterministic candidates from the selected root.
cands = strings(0,1);
suffixes = localSuffixCandidates(oldDatasetPath);
for i = 1:numel(suffixes)
    cands(end+1,1) = string(fullfile(char(newRoot), char(string(suffixes{i})))); %#ok<AGROW>
end
cands(end+1,1) = string(fullfile(char(newRoot), char(datasetName)));
oldParentLeaf = localParentLeafName(oldDatasetPath);
if strlength(oldParentLeaf) > 0
    cands(end+1,1) = string(fullfile(char(newRoot), char(oldParentLeaf), char(datasetName)));
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
    found = localFindDatasetFolder(newRoot, datasetName, maxDepth);
    if strlength(found) > 0
        p2 = found;
        ok = true;
        how = "scan";
        return;
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

function suffixes = localSuffixCandidates(p0)
p = localParseDatasetPath(p0);
parts = p.parts;
suffixes = {};
for k = 2:min(8, numel(parts))
    tail = cellstr(parts(end-k+1:end));
    suffixes{end+1} = string(fullfile(tail{:})); %#ok<AGROW>
end
end

function leaf = localLeafName(p0)
info = localParseDatasetPath(p0);
leaf = info.datasetName;
end

function leaf = localParentLeafName(p0)
info = localParseDatasetPath(p0);
leaf = info.parentLeaf;
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

function info = localParseDatasetPath(p0)
info = struct( ...
    'parts', strings(0,1), ...
    'datasetName', "", ...
    'parentLeaf', "");

p = strrep(string(p0), '\', '/');
p = regexprep(p, '/+', '/');
parts = split(p, '/');
parts(parts == "") = [];
if isempty(parts)
    return;
end

leaf = parts(end);

% Recover malformed legacy OME-Zarr path like:
%   .../2026_04_09Yam740Yak108_18_004.ome.zarr
% where the separator before the dataset folder was lost.
tok = regexp(char(leaf), '^(\d{4}[_-]\d{2}[_-]\d{2})([^/\\]+\.ome\.zarr)$', 'tokens', 'once', 'ignorecase');
if ~isempty(tok)
    if numel(parts) >= 1
        parts(end) = string(tok{1});
        parts(end+1) = string(tok{2});
        leaf = parts(end);
    end
end

info.parts = parts;
info.datasetName = string(leaf);
if numel(parts) >= 2
    info.parentLeaf = string(parts(end-1));
end
end
