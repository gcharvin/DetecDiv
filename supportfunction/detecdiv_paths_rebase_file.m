function [p2, ok] = detecdiv_paths_rebase_file(oldFilePath, newRoot)
p2 = ""; ok = false;
oldFilePath = string(oldFilePath); newRoot = string(newRoot);
if strlength(oldFilePath)==0 || strlength(newRoot)==0, return; end

[~, fname, ext] = fileparts(oldFilePath);
target = fname + ext;

found = localFindFile(newRoot, target, 6);
if strlength(found)>0 && exist(found,'file')
    p2 = found; ok = true;
end
end

function out = localFindFile(root, targetFile, maxDepth)
out = "";
if maxDepth<=0, return; end

try
    d = dir(root);
catch
    return;
end

% check files
for i=1:numel(d)
    if d(i).isdir, continue; end
    if strcmpi(string(d(i).name), string(targetFile))
        out = string(fullfile(root, d(i).name));
        return;
    end
end

% recurse into subdirs
sub = d([d.isdir]);
for i=1:numel(sub)
    nm = string(sub(i).name);
    if nm=="." || nm=="..", continue; end
    out = localFindFile(fullfile(root,nm), targetFile, maxDepth-1);
    if strlength(out)>0, return; end
end
end
