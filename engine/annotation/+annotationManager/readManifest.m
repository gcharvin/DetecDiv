function [manifest, storeIndex] = readManifest(roiObj)
%ANNOTATIONMANAGER.READMANIFEST Read ROI-local annotation lifecycle metadata.

manifest = emptyManifest();
storeIndex = [];
if isempty(roiObj), return; end

loadedFromDisk = ensureDataLoaded(roiObj);
data = roiObj.data;
if isempty(data), return; end
[manifest, storeIndex, found] = manifestFromData(data);
if found, return; end
% We just read this authoritative file. A second deserialization cannot find
% a lifecycle series that was absent in the first read (common for legacy GT).
if loadedFromDisk, return; end

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
persistent absentManifests
if isempty(absentManifests)
    absentManifests = containers.Map('KeyType','char','ValueType','any');
end
manifest = emptyManifest();
series = dataseries.empty;
found = false;
try
    dataFile = fullfile(char(string(roiObj.path)), ...
        ['data_' char(string(roiObj.id)) '.mat']);
    stamp = dir(dataFile);
    if isempty(stamp) || stamp(1).isdir, return; end
    signature = [stamp(1).bytes stamp(1).datenum];
    % Most historical ROIs have labels but no lifecycle manifest. Remember
    % that absence without inserting a synthetic manifest in project data.
    % Check the file stamp on each call so a later Score save is discovered.
    if isKey(absentManifests, dataFile) && ...
            isequal(absentManifests(dataFile), signature)
        return;
    end
    stored = load(dataFile, 'data');
    if isfield(stored, 'data') && ~isempty(stored.data)
        [manifest, index, found] = manifestFromData(stored.data);
    end
    if found
        series = stored.data(index);
        if isKey(absentManifests, dataFile), remove(absentManifests, dataFile); end
    else
        if absentManifests.Count >= 4096
            remove(absentManifests, keys(absentManifests));
        end
        absentManifests(dataFile) = signature;
    end
catch
    manifest = emptyManifest();
    series = dataseries.empty;
    found = false;
end
end

function loadedFromDisk = ensureDataLoaded(roiObj)
loadedFromDisk = false;
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
        loadedFromDisk = true;
    end
catch
end
end

function manifest = normalizeManifest(value)
manifest = emptyManifest();
if ~isstruct(value), return; end
if isfield(value, 'schema_version') && ~isempty(value.schema_version)
    manifest.schema_version = max(uint16(3), uint16(value.schema_version));
end
if isfield(value, 'entries') && isstruct(value.entries)
    manifest.entries = normalizeEntries(value.entries);
end
end

function manifest = emptyManifest()
manifest = struct('schema_version', uint16(3), 'entries', emptyEntries());
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
