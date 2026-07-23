function key = activateLineageSourceForChannel(roiobj, channelName, pix, varargin)
% Activate the lineage source matching an annotation channel.
% The active source is where paint-mode parentage edits are written.

p = inputParser;
p.addParameter('sourceHint', '', @(x) ischar(x) || isstring(x));
p.addParameter('exclusive', false, @(x) islogical(x) && isscalar(x));
p.addParameter('WriteLegacyAlias', true, @(x) islogical(x) && isscalar(x));
p.addParameter('CreateIfMissing', true, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

channelName = string(channelName);
sourceHint = string(p.Results.sourceHint);
if strlength(sourceHint) == 0
    sourceHint = channelName;
end

idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roiobj.data), 1, 'first');
if isempty(idx) && p.Results.CreateIfMissing
    ensureCellInformationDataseries(roiobj);
    idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roiobj.data), 1, 'first');
end
if isempty(idx)
    key = "";
    return;
end

ds = roiobj.data(idx);
ds = ensureLineageUserData(ds);

key = resolveSourceKey(ds, channelName, sourceHint);
if strlength(key) == 0
    if ~p.Results.CreateIfMissing
        return;
    end
    key = matlab.lang.makeValidName(channelName);
    if strlength(key) == 0
        key = matlab.lang.makeValidName("lineage_" + sourceHint);
    end
    if strlength(key) > 0 && isfield(ds.userData.lineageSources, char(key))
        fields = fieldnames(ds.userData.lineageSources);
        key = string(matlab.lang.makeUniqueStrings(char(key), fields));
    end
end
key = char(key);

if p.Results.exclusive
    fields = fieldnames(ds.userData.lineageSources);
    for i = 1:numel(fields)
        src = ds.userData.lineageSources.(fields{i});
        src.show = false;
        ds.userData.lineageSources.(fields{i}) = src;
    end
end

if isfield(ds.userData.lineageSources, key)
    src = ds.userData.lineageSources.(key);
else
    src = struct();
end

if ~isfield(src,'motherOf') || ~isa(src.motherOf,'containers.Map')
    src.motherOf = containers.Map('KeyType','int32','ValueType','double');
end
src.channelName = char(channelName);
src.channelPix = double(pix);
src.outputName = char(sourceHint);
src.sourceClassifierStrid = char(sourceHint);
src.displayName = char(sourceHint);
src.show = true;
src.version = 1;
if ~isfield(src,'mode') || isempty(src.mode)
    src.mode = 'score_channel_lineage';
end

ds.userData.lineageSources.(key) = src;
ds.userData.activeLineageSource = key;
ds.userData.activeLineageChannelName = char(channelName);
ds.userData.lineageChannelName = channelName;
ds.userData.lineageChannelPix = double(pix);

% Compatibility alias for older code paths. Pure display activation can opt
% out so selecting a channel does not silently redefine canonical lineage.
if p.Results.WriteLegacyAlias
    ds.userData.motherOf = src.motherOf;
    ds.userData.motherOfSourceKey = key;
end
end

function ds = ensureLineageUserData(ds)
if ~isprop(ds,'userData') || isempty(ds.userData) || ~isstruct(ds.userData)
    ds.userData = struct();
end
if ~isfield(ds.userData,'motherOf') || ~isa(ds.userData.motherOf,'containers.Map')
    ds.userData.motherOf = containers.Map('KeyType','int32','ValueType','double');
end
if ~isfield(ds.userData,'lineageSources') || ~isstruct(ds.userData.lineageSources)
    ds.userData.lineageSources = struct();
end
if ~isfield(ds.userData,'activeLineageSource') || isempty(ds.userData.activeLineageSource)
    ds.userData.activeLineageSource = 'manual';
end
end

function key = resolveSourceKey(ds, channelName, sourceHint)
key = "";
fields = fieldnames(ds.userData.lineageSources);

for i = 1:numel(fields)
    src = ds.userData.lineageSources.(fields{i});
    if isfield(src,'channelName') && strcmp(string(src.channelName), channelName)
        key = string(fields{i});
        return;
    end
end

hintKey = matlab.lang.makeValidName(sourceHint);
if strlength(hintKey) > 0 && isfield(ds.userData.lineageSources, char(hintKey))
    src = ds.userData.lineageSources.(char(hintKey));
    if ~isfield(src, 'channelName') || isempty(src.channelName) || strcmp(string(src.channelName), channelName)
        key = hintKey;
        return;
    end
end

for i = 1:numel(fields)
    src = ds.userData.lineageSources.(fields{i});
    if matchesSourceHint(src, sourceHint) && ...
            (~isfield(src, 'channelName') || isempty(src.channelName) || strcmp(string(src.channelName), channelName))
        key = string(fields{i});
        return;
    end
end

end

function tf = matchesSourceHint(src, sourceHint)
tf = false;
names = ["outputName", "sourceClassifierStrid", "displayName"];
for i = 1:numel(names)
    nm = char(names(i));
    if isfield(src, nm) && strcmp(string(src.(nm)), sourceHint)
        tf = true;
        return;
    end
end
end
