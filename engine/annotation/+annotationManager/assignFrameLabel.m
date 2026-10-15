function assignFrameLabel(roiObj, groupId, classes, label, frames)
%ASSIGNFRAMELABEL Keep human class names and numeric training IDs together.
classes = cellstr(string(classes(:).'));
label = string(label);
if ~isscalar(label), error('annotationManager:InvalidLabel', 'Select one class.'); end
isBlank = any(strcmpi(label, ["", "undefined", "unclassified", "<undefined>"]));
id = find(strcmp(classes, label), 1);
if ~isBlank && isempty(id)
    error('annotationManager:UnknownClass', 'Unknown training class "%s".', label);
end
index = find(strcmp({roiObj.data.groupid}, groupId), 1);
if isempty(index)
    error('annotationManager:MissingLabels', 'No training dataseries for %s.', groupId);
end
ds = roiObj.data(index);
tbl = ds.data;
frames = unique(double(frames(:)));
if isempty(frames), return; end
if any(~isfinite(frames) | frames < 1 | frames ~= round(frames) | frames > height(tbl))
    error('annotationManager:InvalidFrames', 'Training frames must belong to the dataseries.');
end
categories = unique([{'undefined'}, classes], 'stable');
if ~ismember('labels_training', tbl.Properties.VariableNames)
    tbl.labels_training = categorical(repmat({'undefined'}, height(tbl), 1), categories);
else
    names = string(tbl.labels_training);
    names(ismissing(names) | strlength(names) == 0) = "undefined";
    tbl.labels_training = categorical(names, categories);
end
if ~ismember('id_training', tbl.Properties.VariableNames)
    tbl.id_training = zeros(height(tbl), 1);
end
if isBlank, label = "undefined"; id = 0; end
tbl.labels_training(frames) = categorical(repmat(label, numel(frames), 1), categories);
tbl.id_training(frames) = id;
ds.data = tbl;
if ~isstruct(ds.userData), ds.userData = struct(); end
ds.userData.classes = classes;
roiObj.data(index) = ds;
end
