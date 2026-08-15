function [manifest, storeIndex] = readManifest(roiObj)
%ANNOTATIONMANAGER.READMANIFEST Read ROI-local annotation lifecycle metadata.

manifest = emptyManifest();
storeIndex = [];
if isempty(roiObj), return; end

ensureDataLoaded(roiObj);
data = roiObj.data;
if isempty(data), return; end
[manifest, storeIndex, found] = manifestFromData(data);
if found, return; end

% A classifier snapshot may retain other ROI dataseries while its annotation
% manifest was written later by Score to data_<roi>.mat. In that case the
% non-empty in-memory cache previously prevented any disk refresh and the ROI
% incorrectly appeared as Missing. Read only the manifest dataseries from the
% authoritative ROI data file and merge it into the live cache, preserving
% any unrelated unsaved dataseries already in memory.
[diskManifest, diskSeries, foundOnDisk] = manifestFromDisk(roiObj);
if foundOnDisk
    manifest = diskManifest;
    try
        data(end+1) = diskSeries;
        roiObj.data = data;
        storeIndex = numel(data);
    catch
        % The summary remains correct even if an unusual legacy dataseries
        % array cannot accept the cache entry; a later call can reread disk.
        storeIndex = [];
    end
end
end

function [manifest, storeIndex, found] = manifestFromData(data)
manifest = emptyManifest();
storeIndex = [];
found = false;
for i = 1:numel(data)
    try
        if ~strcmp(char(string(data(i).groupid)), manifestGroupId()), continue; end
        storeIndex = i;
        found = true;
        ud = data(i).userData;
        if isstruct(ud) && isfield(ud, 'annotationManifest')
            manifest = normalizeManifest(ud.annotationManifest);
        end
        return;
    catch
    end
end
end

function [manifest, series, found] = manifestFromDisk(roiObj)
manifest = emptyManifest();
series = dataseries.empty;
found = false;
try
    dataFile = fullfile(char(string(roiObj.path)), ...
        ['data_' char(string(roiObj.id)) '.mat']);
    if ~isfile(dataFile), return; end
    stored = load(dataFile, 'data');
    if ~isfield(stored, 'data') || isempty(stored.data), return; end
    [manifest, index, found] = manifestFromData(stored.data);
    if found
        series = stored.data(index);
    end
catch
    manifest = emptyManifest();
    series = dataseries.empty;
    found = false;
end
end

function ensureDataLoaded(roiObj)
hasRealData = false;
try
    data = roiObj.data;
    hasRealData = ~isempty(data) && any(arrayfun(@(x) ...
        ~isempty(char(string(x.groupid))), data));
catch
end
if hasRealData, return; end
try
    dataFile = fullfile(char(string(roiObj.path)), ...
        ['data_' char(string(roiObj.id)) '.mat']);
    if isfile(dataFile)
        roiObj.load('Data', 'Silent');
    end
catch
end
end

function manifest = normalizeManifest(value)
manifest = emptyManifest();
if ~isstruct(value), return; end
if isfield(value, 'schema_version') && ~isempty(value.schema_version)
    manifest.schema_version = max(uint16(2), uint16(value.schema_version));
end
if isfield(value, 'entries') && isstruct(value.entries)
    manifest.entries = normalizeEntries(value.entries);
end
end

function manifest = emptyManifest()
manifest = struct('schema_version', uint16(2), 'entries', emptyEntries());
end

function entries = normalizeEntries(source)
template = annotationManager.newEntry([], 0);
entries = repmat(template, numel(source), 1);
names = fieldnames(template);
for i = 1:numel(source)
    for j = 1:numel(names)
        if isfield(source, names{j})
            entries(i).(names{j}) = source(i).(names{j});
        end
    end
end
end

function entries = emptyEntries()
entry = annotationManager.newEntry([], 0);
entries = repmat(entry, 0, 1);
end

function value = manifestGroupId()
value = 'detecdiv_annotation_manifest';
end
