function roots = detecdiv_paths_infer_raw_roots(projectMatPath)
% Infer server-side RAWDATA roots from a server-side project MAT path.
%
% Projects often originate from Windows clients with srcpath/tiffSource values
% under a Samba mount, while the batch worker sees the same storage under
% /data. This helper keeps that machine-specific inference in DetecDiv rather
% than in the hub worker.

roots = strings(0,1);

if nargin < 1 || isempty(projectMatPath)
    roots = {};
    return;
end

p = string(projectMatPath);
if strlength(p) == 0
    roots = {};
    return;
end

p = replace(p, "\", "/");
[projectDir, ~, ~] = fileparts(p);
if strlength(projectDir) == 0
    roots = {};
    return;
end

parents = localParents(projectDir);
for i = 1:numel(parents)
    parent = parents(i);
    leaf = lower(localLeaf(parent));
    if any(leaf == ["projects", "analysis", "analyses", "analyse"])
        continue;
    end

    if startsWith(parent, "/data/")
        roots = [roots; localRawVariants(parent)]; %#ok<AGROW>
        break;
    end
end

roots = unique(roots, 'stable');
roots = roots(strlength(roots) > 0);
roots = cellstr(roots);
end

function parents = localParents(pathText)
parents = strings(0,1);
p = string(pathText);

while strlength(p) > 0
    parents(end+1,1) = p; %#ok<AGROW>
    [next, ~, ~] = fileparts(p);
    if next == p || strlength(next) == 0
        break;
    end
    p = next;
end
end

function leaf = localLeaf(pathText)
[~, name, ext] = fileparts(pathText);
leaf = string(name) + string(ext);
end

function roots = localRawVariants(parent)
roots = [
    localJoin(parent, "raw")
    localJoin(parent, "Raw")
    localJoin(parent, "RAWDATA")
    localJoin(parent, "raw_data")
];
end

function out = localJoin(parent, child)
parent = string(parent);
child = string(child);
if startsWith(parent, "/")
    out = parent + "/" + child;
else
    out = fullfile(parent, child);
end
end
