function report = classiRestoreDiskRois(classiObj)
%CLASSIRESTOREDISKROIS Add missing disk ROIs without replacing existing handles.
% Explicit recovery only: classiLoad must preserve intentionally saved deletions.
% Images are read one ROI at a time to recover display/channel metadata, then
% released. This function never writes images, annotations or classifier files.
folder = classiObj.path;
if ~isfolder(folder)
    error('classiRestoreDiskRois:MissingFolder', 'Classifier folder unavailable: %s', folder);
end
files = [dir(fullfile(folder, 'im_*.h5')); dir(fullfile(folder, 'im_*.mat'))];
files = files(~[files.isdir]);
ids = regexprep({files.name}, '^im_|\.(h5|mat)$', '');
ids = unique(ids, 'stable'); % HDF5 takes precedence over legacy MAT.
known = {classiObj.roi.id};
report = struct('scanned', numel(ids), 'existing', 0, 'added', {{}}, ...
    'failed', {{}}, 'errors', {{}});
for k = 1:numel(ids)
    id = ids{k};
    if isempty(id), continue; end
    if any(strcmp(known, id))
        report.existing = report.existing + 1;
        continue;
    end
    try
        r = roi(id, []);
        r.path = folder;
        r.load('Silent');
        if isempty(r.image)
            error('classiRestoreDiskRois:EmptyImage', 'No readable image for ROI %s.', id);
        end
        r.image = []; % Preserve recovered annotations and display metadata.
        if isempty(classiObj.roi) || all(cellfun(@isempty, {classiObj.roi.id}))
            classiObj.roi = r;
        else
            classiObj.roi(end+1) = r;
        end
        known{end+1} = id; %#ok<AGROW>
        report.added{end+1} = id;
    catch ME
        report.failed{end+1} = id;
        report.errors{end+1} = ME.message;
        warning('classiRestoreDiskRois:Unreadable', 'ROI %s: %s', id, ME.message);
    end
end
end
