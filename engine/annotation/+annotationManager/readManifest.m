function [manifest, storeIndex] = readManifest(roiObj)
%ANNOTATIONMANAGER.READMANIFEST Read ROI-local annotation lifecycle metadata.

manifest = emptyManifest();
storeIndex = [];
if isempty(roiObj), return; end

ensureDataLoaded(roiObj);
data = roiObj.data;
if isempty(data), return; end
for i = 1:numel(data)
    try
        if strcmp(char(string(data(i).groupid)), manifestGroupId())
            storeIndex = i;
            ud = data(i).userData;
            if isstruct(ud) && isfield(ud, 'annotationManifest')
                manifest = normalizeManifest(ud.annotationManifest);
            end
            return;
        end
    catch
    end
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
    manifest.schema_version = uint16(value.schema_version);
end
if isfield(value, 'entries') && isstruct(value.entries)
    manifest.entries = value.entries;
end
end

function manifest = emptyManifest()
manifest = struct('schema_version', uint16(1), 'entries', emptyEntries());
end

function entries = emptyEntries()
entry = annotationManager.newEntry([], 0);
entries = repmat(entry, 0, 1);
end

function value = manifestGroupId()
value = 'detecdiv_annotation_manifest';
end
