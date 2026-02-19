function [p2, ok] = detecdiv_paths_rebase_file(oldFilePath, newRoot, debug, maxDepth)
% Fast rebase for Multi-TIFF source files.
% Strategy:
%   1) Try deterministic candidates (no recursive scan).
%   2) Optional bounded recursive search only if maxDepth > 0.

p2 = "";
ok = false;

if nargin < 3, debug = false; end
if nargin < 4 || isempty(maxDepth), maxDepth = 0; end

oldFilePath = string(oldFilePath);
newRoot = string(newRoot);

if strlength(oldFilePath) == 0 || strlength(newRoot) == 0
    return;
end

[~, fname, ext] = fileparts(oldFilePath);
target = strtrim(fname + ext);
targetNorm = localNormName(target);

% Case 1: user passed a file directly.
if isfile(newRoot)
    [~, f2, e2] = fileparts(newRoot);
    if localNormName(f2 + e2) == targetNorm
        p2 = newRoot;
        ok = true;
    end
    return;
end

if ~isfolder(newRoot)
    return;
end

% Case 2: deterministic candidates (fast).
cands = strings(0,1);
cands(end+1,1) = fullfile(newRoot, target);

oldDir = fileparts(oldFilePath);
[~, oldLeaf] = fileparts(oldDir);
if strlength(oldLeaf) > 0
    cands(end+1,1) = fullfile(newRoot, oldLeaf, target);
end

suffix = localSuffixAfterRawData(oldFilePath);
if strlength(suffix) > 0
    cands(end+1,1) = fullfile(newRoot, suffix);
end

cands = unique(cands, 'stable');
for i = 1:numel(cands)
    if isfile(cands(i))
        p2 = cands(i);
        ok = true;
        return;
    end
end

% Case 3: fuzzy match in selected folder and one likely subfolder (still fast).
found = localFindFuzzyInFolder(newRoot, targetNorm);
if strlength(found) == 0 && strlength(oldLeaf) > 0
    sub = fullfile(newRoot, oldLeaf);
    if isfolder(sub)
        found = localFindFuzzyInFolder(sub, targetNorm);
    end
end
if strlength(found) > 0
    p2 = found;
    ok = true;
    return;
end

% Case 4: optional bounded recursive search (disabled by default).
if maxDepth > 0
    found = localFindFile(newRoot, targetNorm, maxDepth);
    if strlength(found) > 0 && isfile(found)
        p2 = found;
        ok = true;
        return;
    end
end

if debug
    fprintf('[paths] rebase_file failed for target: %s under root: %s\n', target, newRoot);
end
end

function out = localSuffixAfterRawData(oldFilePath)
out = "";
s = replace(string(oldFilePath), "/", filesep);
token = [filesep 'raw_data' filesep];
ix = strfind(lower(char(s)), lower(token));
if isempty(ix)
    return;
end
k = ix(end) + strlength(token);
if k <= strlength(s)
    out = extractAfter(s, k-1);
end
end

function out = localFindFuzzyInFolder(folderPath, targetNorm)
out = "";
if ~isfolder(folderPath)
    return;
end

try
    d = dir(fullfile(folderPath, '*'));
catch
    return;
end

for i = 1:numel(d)
    if d(i).isdir
        continue;
    end
    if localNormName(string(d(i).name)) == targetNorm
        out = string(fullfile(folderPath, d(i).name));
        return;
    end
end
end

function out = localFindFile(root, targetNorm, maxDepth)
out = "";
if maxDepth <= 0 || ~isfolder(root)
    return;
end

try
    d = dir(root);
catch
    return;
end

for i = 1:numel(d)
    if d(i).isdir
        continue;
    end
    if localNormName(string(d(i).name)) == targetNorm
        out = string(fullfile(root, d(i).name));
        return;
    end
end

sub = d([d.isdir]);
for i = 1:numel(sub)
    nm = string(sub(i).name);
    if nm == "." || nm == ".."
        continue;
    end
    out = localFindFile(fullfile(root, nm), targetNorm, maxDepth-1);
    if strlength(out) > 0
        return;
    end
end
end

function n = localNormName(s)
n = lower(strtrim(string(s)));
n = regexprep(n, '\s+', '');
end

