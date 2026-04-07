function tf = localLooksLikeOmeZarrRoot(pathdir, list)
% localLooksLikeOmeZarrRoot  Heuristic for OME-Zarr store roots.
%
% Accepts stores that are not necessarily named *.ome.zarr. Supports both
% Zarr v3 stores with zarr.json and Zarr v2 stores with .zattrs/.zgroup.

tf = false;
if nargin < 2 || isempty(list)
    list = dir(pathdir);
end

zjson = fullfile(pathdir, 'zarr.json');
try
    if exist(zjson, 'file') == 2
        txt = fileread(zjson);
        if contains(txt, '"ome"', 'IgnoreCase', true) && ...
                (contains(txt, '"series"', 'IgnoreCase', true) || ...
                 contains(txt, '"multiscales"', 'IgnoreCase', true) || ...
                 contains(txt, '"bioformats2raw.layout"', 'IgnoreCase', true))
            tf = true;
            return;
        end
    end
catch
end

zattrs = fullfile(pathdir, '.zattrs');
zgroup = fullfile(pathdir, '.zgroup');
try
    if exist(zattrs, 'file') == 2 && exist(zgroup, 'file') == 2
        txt = fileread(zattrs);
        if contains(txt, '"multiscales"', 'IgnoreCase', true) || ...
                contains(txt, '"omero"', 'IgnoreCase', true) || ...
                contains(txt, '"_ARRAY_DIMENSIONS"', 'IgnoreCase', true)
            tf = true;
            return;
        end
    end
catch
end

subdirs = list([list.isdir]);
subdirs = subdirs(~ismember({subdirs.name}, {'.','..'}));
for i = 1:numel(subdirs)
    child = fullfile(subdirs(i).folder, subdirs(i).name);
    if exist(fullfile(child, 'zarr.json'), 'file') == 2 || ...
            exist(fullfile(child, '.zarray'), 'file') == 2
        tf = true;
        return;
    end
end
end
