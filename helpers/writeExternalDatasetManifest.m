function manifest = writeExternalDatasetManifest(root, metadata)
%WRITEEXTERNALDATASETMANIFEST Fingerprint a completed external data tree.
%
% The manifest itself is excluded from the inventory so that its digest
% does not recursively depend on itself. Call only after all data and audit
% files have been written.

root = char(string(root));
if ~isfolder(root)
    error('writeExternalDatasetManifest:MissingRoot', ...
        'External dataset root does not exist: %s', root);
end
if nargin < 2 || ~isstruct(metadata) || ~isscalar(metadata)
    error('writeExternalDatasetManifest:InvalidMetadata', ...
        'Metadata must be a scalar struct.');
end

manifest = metadata;
manifest.schema_version = 'cell_latent_model_external_manifest_v001';
manifest.created_utc = utcTimestamp();
[~, manifest.root_name] = fileparts(root);
manifest.files = inventory(root);
manifest.file_count = numel(manifest.files);
manifest.total_bytes = sum([manifest.files.bytes]);
manifestPath = fullfile(root, 'manifest.json');
writeJsonAtomic(manifestPath, manifest);
end

function items = inventory(root)
listing = dir(fullfile(root, '**', '*'));
listing = listing(~[listing.isdir]);
relative = strings(numel(listing), 1);
for i = 1:numel(listing)
    fullPath = fullfile(listing(i).folder, listing(i).name);
    relative(i) = string(fullPath(numel(root) + 2:end));
end
keep = ~strcmpi(relative, 'manifest.json') & ...
    ~contains(relative, '.tmp.');
listing = listing(keep);
relative = relative(keep);
[relative, order] = sort(replace(relative, '\', '/'));
listing = listing(order);

template = struct('path', '', 'role', '', 'bytes', 0, 'sha256', '');
items = repmat(template, numel(listing), 1);
for i = 1:numel(listing)
    parts = split(relative(i), '/');
    items(i).path = char(relative(i));
    items(i).role = char(parts(1));
    items(i).bytes = listing(i).bytes;
    items(i).sha256 = sha256File(fullfile( ...
        listing(i).folder, listing(i).name));
end
end

function hash = sha256File(path)
digest = java.security.MessageDigest.getInstance('SHA-256');
stream = java.io.FileInputStream(java.io.File(path));
cleanup = onCleanup(@() stream.close());
buffer = zeros(1, 1024 * 1024, 'int8');
while true
    count = stream.read(buffer, 0, numel(buffer));
    if count < 0, break; end
    digest.update(buffer(1:count));
end
delete(cleanup);
raw = typecast(digest.digest(), 'uint8');
hash = lower(reshape(dec2hex(raw, 2).', 1, []));
end

function value = utcTimestamp()
value = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end

function writeJsonAtomic(path, value)
temporary = [path '.tmp.' char(java.util.UUID.randomUUID)];
cleanup = onCleanup(@() deleteIfPresent(temporary));
fid = fopen(temporary, 'w', 'n', 'UTF-8');
if fid < 0
    error('writeExternalDatasetManifest:WriteFailed', ...
        'Cannot open manifest output: %s', temporary);
end
fileCleanup = onCleanup(@() fcloseIfOpen(fid));
fprintf(fid, '%s\n', jsonencode(value, 'PrettyPrint', true));
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
