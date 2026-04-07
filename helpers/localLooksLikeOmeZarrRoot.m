function tf = localLooksLikeOmeZarrRoot(pathdir, list)
% localLooksLikeOmeZarrRoot  Heuristic for OME-Zarr store roots.
%
% Accepts stores that are not necessarily named *.ome.zarr, as long as they
% contain zarr.json metadata and either OME metadata or child Zarr groups.

tf = false;
if nargin < 2 || isempty(list)
    list = dir(pathdir);
end

zjson = fullfile(pathdir, 'zarr.json');
if exist(zjson, 'file') ~= 2
    return;
end

try
    txt = fileread(zjson);
    if contains(txt, '"ome"', 'IgnoreCase', true) && ...
            (contains(txt, '"series"', 'IgnoreCase', true) || ...
             contains(txt, '"multiscales"', 'IgnoreCase', true) || ...
             contains(txt, '"bioformats2raw.layout"', 'IgnoreCase', true))
        tf = true;
        return;
    end
catch
end

subdirs = list([list.isdir]);
subdirs = subdirs(~ismember({subdirs.name}, {'.','..'}));
for i = 1:numel(subdirs)
    if exist(fullfile(subdirs(i).folder, subdirs(i).name, 'zarr.json'), 'file') == 2
        tf = true;
        return;
    end
end
end
