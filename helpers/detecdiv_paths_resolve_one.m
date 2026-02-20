function [p2, ok, method] = detecdiv_paths_resolve_one(userprefs, p0)
% Resolve a legacy absolute rawdata path using user preferences.
% Returns:
%   p2     : resolved candidate path (string)
%   ok     : true if folder exists
%   method : resolution method label

p2 = ""; ok = false; method = "none";
if nargin < 2 || isempty(p0), return; end
p0 = string(p0);
if strlength(p0)==0, return; end

% Already OK?
if isfolder(p0)
    p2 = p0; ok = true; method = "as-is";
    return;
end

if isempty(userprefs) || ~isfield(userprefs,'paths') || ~isstruct(userprefs.paths)
    return;
end

% ---- helpers
suffixes = localSuffixCandidates(p0);

% ---- 1) rootMap + "relative suffix" inference (best case)
roots = userprefs.paths.rootMap;
if isstruct(roots)
    [suffixRel, hasSuffix] = localInferRelativeSuffix(p0);
    if hasSuffix
        rnames = fieldnames(roots);
        for r = 1:numel(rnames)
            base = string(roots.(rnames{r}));
            if strlength(base)==0, continue; end
            if ~isfolder(base), continue; end
            cand = fullfile(base, suffixRel);
            if isfolder(cand)
                p2 = string(cand); ok = true; method = "rootMap+relativeSuffix";
                return;
            end
        end
    end
end

% ---- 2) rootMap + suffixes
if isstruct(roots)
    rnames = fieldnames(roots);
    for r = 1:numel(rnames)
        base = string(roots.(rnames{r}));
        if strlength(base)==0 || ~isfolder(base), continue; end
        for s = 1:numel(suffixes)
            cand = fullfile(base, suffixes{s});
            if isfolder(cand)
                p2 = string(cand); ok = true; method = "rootMap+suffix";
                return;
            end
        end
    end
end

% ---- 3) history + suffixes
H = string(userprefs.paths.rawPathHistory);
for h = 1:numel(H)
    base = H(h);
    if strlength(base)==0 || ~isfolder(base), continue; end
    for s = 1:numel(suffixes)
        cand = fullfile(base, suffixes{s});
        if isfolder(cand)
            p2 = string(cand); ok = true; method = "history+suffix";
            return;
        end
    end
end

% ---- 4) optional scanRoots (last resort)
if isfield(userprefs.paths,'scanRoots') && ~isempty(userprefs.paths.scanRoots)
    scanRoots = string(userprefs.paths.scanRoots);
    if isfield(userprefs.paths,'maxScanDepth'), maxDepth = userprefs.paths.maxScanDepth;
    else, maxDepth = 4; end

    leaf = localLeafName(p0);
    for sr = 1:numel(scanRoots)
        base = scanRoots(sr);
        if ~isfolder(base), continue; end
        found = localFindFolder(base, leaf, maxDepth);
        if strlength(found)>0 && isfolder(found)
            p2 = found; ok = true; method = "scanRoots";
            return;
        end
    end
end

end

% ---------------- local helpers ----------------

function suffixes = localSuffixCandidates(p0)
p = strrep(string(p0),'\','/');
parts = split(p,'/'); parts(parts=="") = [];
suffixes = {};
for k = 2:min(8,numel(parts))
    suffixes{end+1} = fullfile(parts(end-k+1:end)); %#ok<AGROW>
end
end

function [suffixRel, ok] = localInferRelativeSuffix(p0)
% Extract stable relative suffix for known patterns:
%   .../SynologyDrive/Data/<REL>
%   //10.20.11.250/data/<REL>
%   //server/share/<REL>
ok = false; suffixRel = "";

p = strrep(string(p0),'\','/');

ix = regexpi(p, '/synologydrive/data/');
if ~isempty(ix)
    start = ix(1) + strlength("/synologydrive/data/");
    suffixRel = extractAfter(p, start-1);
    suffixRel = strrep(suffixRel,'/','\');
    ok = true; return;
end

ix = regexpi(p, '//10\.20\.11\.250/data/');
if ~isempty(ix)
    start = ix(1) + strlength("//10.20.11.250/data/");
    suffixRel = extractAfter(p, start-1);
    suffixRel = strrep(suffixRel,'/','\');
    ok = true; return;
end

if startsWith(p,"//")
    parts = split(p,"/"); parts(parts=="") = [];
    if numel(parts) >= 3
        suffixRel = join(parts(3:end), filesep);
        suffixRel = string(suffixRel);
        ok = true; return;
    end
end
end

function leaf = localLeafName(p0)
[~, leaf] = fileparts(string(p0));
end

function out = localFindFolder(root, leaf, maxDepth)
out = "";
if maxDepth<=0, return; end
try, d = dir(root); catch, return; end

for i=1:numel(d)
    if ~d(i).isdir, continue; end
    nm = string(d(i).name);
    if nm=="." || nm=="..", continue; end
    if nm == leaf
        out = string(fullfile(root,nm));
        return;
    end
end

for i=1:numel(d)
    if ~d(i).isdir, continue; end
    nm = string(d(i).name);
    if nm=="." || nm=="..", continue; end
    out = localFindFolder(fullfile(root,nm), leaf, maxDepth-1);
    if strlength(out)>0, return; end
end
end
