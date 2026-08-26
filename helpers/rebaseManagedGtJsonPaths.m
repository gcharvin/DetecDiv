function report = rebaseManagedGtJsonPaths(root, oldPrefix, newPrefix)
%REBASEMANAGEDGTJSONPATHS Rebase textual paths after final directory rename.
%
% Only UTF-8 JSON sidecars are touched. MAT/HDF5 payload paths are rebound
% by the normal DetecDiv loaders and must never be edited as raw bytes.

root = char(string(root));
oldPrefix = char(string(oldPrefix));
newPrefix = char(string(newPrefix));
if ~isfolder(root)
    error('rebaseManagedGtJsonPaths:MissingRoot', ...
        'Managed GT root does not exist: %s', root);
end
if isempty(oldPrefix) || isempty(newPrefix) || strcmp(oldPrefix, newPrefix)
    error('rebaseManagedGtJsonPaths:InvalidPrefixes', ...
        'Distinct non-empty old and new path prefixes are required.');
end

listing = dir(fullfile(root, '**', '*.json'));
changed = strings(0, 1);
for i = 1:numel(listing)
    path = fullfile(listing(i).folder, listing(i).name);
    original = fileread(path);
    updated = strrep(original, oldPrefix, newPrefix);
    % JSON encoders escape Windows separators. Cover that representation
    % explicitly while keeping ordinary forward-slash paths portable.
    updated = strrep(updated, strrep(oldPrefix, '\', '\\'), ...
        strrep(newPrefix, '\', '\\'));
    if strcmp(original, updated), continue; end
    writeTextAtomic(path, updated);
    changed(end+1, 1) = string(path); %#ok<AGROW>
end
report = struct('root', root, 'old_prefix', oldPrefix, ...
    'new_prefix', newPrefix, 'changed_count', numel(changed), ...
    'changed_files', {cellstr(changed)});
end

function writeTextAtomic(path, value)
temporary = [path '.tmp.' char(java.util.UUID.randomUUID)];
cleanup = onCleanup(@() deleteIfPresent(temporary));
fid = fopen(temporary, 'w', 'n', 'UTF-8');
if fid < 0
    error('rebaseManagedGtJsonPaths:WriteFailed', ...
        'Cannot open JSON sidecar: %s', temporary);
end
fileCleanup = onCleanup(@() fcloseIfOpen(fid));
fwrite(fid, value, 'char');
fclose(fid);
delete(fileCleanup);
movefile(temporary, path, 'f');
delete(cleanup);
end

function fcloseIfOpen(fid)
try fclose(fid); catch, end
end

function deleteIfPresent(path)
try if isfile(path), delete(path); end, catch, end
end
