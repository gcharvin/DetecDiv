function report = materializeClassifierRoiFiles(classif)
%MATERIALIZECLASSIFIERROIFILES Make classifier ROI storage self-contained.
%
% classiLoad historically rebases every ROI path to the classifier folder.
% A classifier assembled from project-owned ROI handles must therefore copy
% the durable ROI files into that folder before it can be reopened safely.

if isempty(classif) || ~isa(classif, 'classi')
    error('materializeClassifierRoiFiles:InvalidClassifier', ...
        'A classi object is required.');
end
target = char(string(classif.path));
if isempty(target), error('materializeClassifierRoiFiles:MissingPath', ...
        'Classifier path is empty.'); end
if ~isfolder(target), mkdir(target); end

template = struct('roi_id', '', 'source_path', '', 'target_path', '', ...
    'files', {cell(0,1)}, 'sha256', {cell(0,1)});
items = repmat(template, numel(classif.roi), 1);
for i = 1:numel(classif.roi)
    item = classif.roi(i);
    roiId = char(string(item.id));
    source = char(string(item.path));
    if isempty(roiId) || ~isfolder(source)
        error('materializeClassifierRoiFiles:MissingRoiSource', ...
            'ROI %d has no readable source path.', i);
    end
    names = {['im_' roiId '.h5'], ['im_' roiId '.mat'], ...
        ['data_' roiId '.mat'], ['objects_' roiId '.h5']};
    copied = cell(0,1);
    hashes = cell(0,1);
    for j = 1:numel(names)
        sourceFile = fullfile(source, names{j});
        if ~isfile(sourceFile), continue; end
        targetFile = fullfile(target, names{j});
        copyAtomic(sourceFile, targetFile);
        sourceHash = sha256File(sourceFile);
        targetHash = sha256File(targetFile);
        if ~strcmpi(sourceHash, targetHash)
            error('materializeClassifierRoiFiles:HashMismatch', ...
                'Copied ROI file failed SHA-256 verification: %s', targetFile);
        end
        copied{end+1,1} = names{j}; %#ok<AGROW>
        hashes{end+1,1} = targetHash; %#ok<AGROW>
    end
    if isempty(copied)
        error('materializeClassifierRoiFiles:NoRoiFiles', ...
            'No durable files found for ROI "%s" in %s.', roiId, source);
    end
    items(i).roi_id = roiId;
    items(i).source_path = source;
    items(i).target_path = target;
    items(i).files = copied;
    items(i).sha256 = hashes;
    item.path = target;
    item.parent = classif;
end
report = struct('classifier_id', char(string(classif.strid)), ...
    'target_path', target, 'roi_count', numel(items), 'items', items);
end

function copyAtomic(source, target)
temporary = [target '.tmp.' char(java.util.UUID.randomUUID)];
cleanup = onCleanup(@() deleteIfPresent(temporary));
[ok, message] = copyfile(source, temporary, 'f');
if ~ok, error('materializeClassifierRoiFiles:CopyFailed', '%s', message); end
[ok, message] = movefile(temporary, target, 'f');
if ~ok, error('materializeClassifierRoiFiles:InstallFailed', '%s', message); end
delete(cleanup);
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

function deleteIfPresent(path)
try
    if isfile(path), delete(path); end
catch
end
end
