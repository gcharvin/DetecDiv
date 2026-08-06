function catalog = catalog(classif, varargin)
%CLASSIFIERBINDING.CATALOG Inventory typed resources across classifier ROIs.

% The catalog is intentionally independent from classifierGUI.  Pipeline
% frontends build choices from graph/runtime resources; classifierGUI builds
% the same kind of binding choices from the imported training ROIs.

p = inputParser;
p.addParameter('RoiIndices', [], @isnumeric);
p.parse(varargin{:});

rois = classifierRois(classif);
indices = normalizeIndices(p.Results.RoiIndices, numel(rois));
if isempty(indices)
    indices = 1:numel(rois);
end
indices = indices(arrayfun(@(i) hasRoiId(rois(i)), indices));

catalog = struct( ...
    'roiCount', numel(indices), ...
    'channels', repmat(channelDef(), 0, 1), ...
    'families', repmat(familyDef(), 0, 1));
for i = indices
    roiObj = rois(i);
    catalog.channels = mergeChannels(catalog.channels, roiObj);
    catalog.families = mergeFamilies(catalog.families, roiObj);
end
catalog.channels = sortRows(catalog.channels);
catalog.families = sortRows(catalog.families);
end

function rois = classifierRois(classif)
rois = roi.empty;
try
    rois = classif.roi;
catch
end
if numel(rois) == 1 && ~hasRoiId(rois(1))
    rois = roi.empty;
end
end

function tf = hasRoiId(roiObj)
tf = false;
try, tf = strlength(string(roiObj.id)) > 0; catch, end
end

function indices = normalizeIndices(indices, count)
indices = unique(round(double(indices(:).')), 'stable');
indices = indices(isfinite(indices) & indices >= 1 & indices <= count);
end

function rows = mergeChannels(rows, roiObj)
channels = storedChannels(roiObj);
for i = 1:numel(channels)
    name = channels(i).name;
    isIndexed = channels(i).indexed;
    row = find(strcmpi({rows.name}, name), 1);
    if isempty(row)
        item = channelDef();
        item.name = name;
        item.roiCount = 1;
        item.indexedRoiCount = double(isIndexed);
        item.imageRoiCount = double(~isIndexed);
        rows(end+1,1) = item; %#ok<AGROW>
    else
        rows(row).roiCount = rows(row).roiCount + 1;
        rows(row).indexedRoiCount = rows(row).indexedRoiCount + double(isIndexed);
        rows(row).imageRoiCount = rows(row).imageRoiCount + double(~isIndexed);
    end
end
end

function channels = storedChannels(roiObj)
channels = struct('name', {}, 'indexed', {}, 'maskCompatible', {});
try
    names = cellstr(string(roiObj.display.channel(:).'));
    indexed = logical(roiObj.display.indexed(:).');
    if numel(indexed) < numel(names), indexed(end+1:numel(names)) = false; end
    for i = 1:numel(names)
        if isempty(names{i}), continue; end
        isIndexed = indexed(i);
        maskCompatible = true;
        try
            pix = roiObj.findChannelID(names{i}, 'exact');
            maskCompatible = numel(pix) <= 1;
            if ~maskCompatible, isIndexed = false; end
        catch
        end
        channels = mergeStoredChannel(channels, names{i}, isIndexed, maskCompatible); %#ok<AGROW>
    end
catch
end

% Classifier MAT files can hold stale ROI display metadata after a pipeline
% or annotation run. Read only the lightweight HDF5 header so bindings show
% channels that are actually persisted, without loading image stacks.
try
    filename = fullfile(char(string(roiObj.path)), ...
        ['im_' char(string(roiObj.id)) '.h5']);
    if isfile(filename)
        info = h5info(filename);
        for i = 1:numel(info.Datasets)
            datasetPath = ['/' info.Datasets(i).Name];
            name = info.Datasets(i).Name;
            try, name = char(string(h5readatt(filename, datasetPath, 'channel_name'))); catch, end
            isIndexed = false;
            try, isIndexed = logical(h5readatt(filename, datasetPath, 'display_indexed')); catch, end
            subchannels = 1;
            try, subchannels = double(h5readatt(filename, datasetPath, 'num_subchannels')); catch, end
            if subchannels > 1, isIndexed = false; end
            channels = mergeStoredChannel(channels, name, isIndexed, subchannels <= 1); %#ok<AGROW>
        end
    end
catch
end

% A cellular-object family is the authoritative declaration that a channel
% is an indexed mask provider.
families = storedFamilies(roiObj);
for i = 1:numel(families)
    if ~isfield(families, 'mask_provider'), continue; end
    provider = char(string(families(i).mask_provider));
    if isempty(provider), continue; end
    channels = mergeStoredChannel(channels, provider, true, true); %#ok<AGROW>
end
end

function channels = mergeStoredChannel(channels, name, indexed, maskCompatible)
name = char(string(name));
if isempty(name), return; end
idx = find(strcmpi({channels.name}, name), 1);
if isempty(idx)
    channels(end+1) = struct('name', name, 'indexed', logical(indexed), ...
        'maskCompatible', logical(maskCompatible));
else
    channels(idx).maskCompatible = channels(idx).maskCompatible && logical(maskCompatible);
    channels(idx).indexed = channels(idx).indexed || ...
        (logical(indexed) && channels(idx).maskCompatible);
    if ~channels(idx).maskCompatible
        channels(idx).indexed = false;
    end
end
end

function rows = mergeFamilies(rows, roiObj)
families = storedFamilies(roiObj);
for i = 1:numel(families)
    name = char(string(families(i).name));
    if isempty(name), continue; end
    provider = '';
    if isfield(families, 'mask_provider')
        provider = char(string(families(i).mask_provider));
    end
    lineageSource = '';
    if isfield(families, 'lineage_source')
        lineageSource = char(string(families(i).lineage_source));
    end
    row = find(strcmpi({rows.name}, name), 1);
    if isempty(row)
        item = familyDef();
        item.name = name;
        item.maskProvider = provider;
        item.lineageSource = lineageSource;
        item.roiCount = 1;
        rows(end+1,1) = item; %#ok<AGROW>
    else
        rows(row).roiCount = rows(row).roiCount + 1;
        if isempty(rows(row).maskProvider)
            rows(row).maskProvider = provider;
        elseif ~isempty(provider) && ~strcmpi(rows(row).maskProvider, provider)
            rows(row).providerConflict = true;
        end
        if isempty(rows(row).lineageSource)
            rows(row).lineageSource = lineageSource;
        end
    end
end
end

function families = storedFamilies(roiObj)
families = struct('name', {}, 'mask_provider', {}, 'lineage_source', {});
try
    info = roiObj.cellModelInfo;
    if isstruct(info) && isfield(info, 'loaded') && info.loaded && ...
            isstruct(roiObj.cellModel) && isfield(roiObj.cellModel, 'families')
        modelFamilies = roiObj.cellModel.families;
        for i = 1:numel(modelFamilies.family_id)
            families(end+1) = struct( ...
                'name', modelFamilies.name{i}, ...
                'mask_provider', modelFamilies.mask_provider{i}, ...
                'lineage_source', modelFamilies.lineage_source{i}); %#ok<AGROW>
        end
        return;
    end
catch
end
try
    filename = cellModel.pathForROI(roiObj);
    if isempty(filename) || ~isfile(filename), return; end
    metadata = cellModel.readMetadata(filename);
    if isfield(metadata, 'families') && isstruct(metadata.families)
        families = metadata.families;
    end
catch
end
end

function rows = sortRows(rows)
if isempty(rows), return; end
[~, order] = sort(lower(string({rows.name})));
rows = rows(order);
end

function def = channelDef()
def = struct('name', '', 'roiCount', 0, ...
    'indexedRoiCount', 0, 'imageRoiCount', 0);
end

function def = familyDef()
def = struct('name', '', 'maskProvider', '', ...
    'lineageSource', '', 'roiCount', 0, 'providerConflict', false);
end
