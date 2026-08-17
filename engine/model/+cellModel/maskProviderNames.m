function [names, excluded] = maskProviderNames(roiobj)
%CELLMODEL.MASKPROVIDERNAMES Return indexed single-plane mask channels.
% An indexed display flag alone is not sufficient: RGB/composite logical
% channels can carry stale legacy flags, but they cannot provide instance
% labels because one logical channel maps to several image planes.

names = {};
excluded = {};
try
    allNames = cellstr(string(roiobj.display.channel(:).'));
    indexed = logical(roiobj.display.indexed(:).');
    if numel(indexed) < numel(allNames)
        indexed(end+1:numel(allNames)) = false;
    end
catch
    return;
end

for i = find(indexed(1:numel(allNames)))
    name = allNames{i};
    if isempty(name), continue; end
    if isSinglePlane(roiobj, name)
        names{end+1} = name; %#ok<AGROW>
    else
        excluded{end+1} = name; %#ok<AGROW>
    end
end
names = unique(names, 'stable');
excluded = unique(excluded, 'stable');
end

function tf = isSinglePlane(roiobj, name)
tf = true;
known = false;
try
    pix = roiobj.findChannelID(name, 'exact');
    if ~isempty(pix)
        known = true;
        tf = isscalar(pix);
    end
catch
end
if known, return; end

% Classifier snapshots may contain unloaded ROI handles. Consult the
% lightweight HDF5 attribute before trusting stale display metadata.
try
    filename = fullfile(char(string(roiobj.path)), ...
        ['im_' char(string(roiobj.id)) '.h5']);
    if ~isfile(filename), return; end
    info = h5info(filename);
    hit = find(strcmp({info.Datasets.Name}, name), 1, 'first');
    if isempty(hit), return; end
    datasetPath = ['/' info.Datasets(hit).Name];
    subchannels = double(h5readatt(filename, datasetPath, 'num_subchannels'));
    tf = isscalar(subchannels) && subchannels == 1;
catch
end
end
