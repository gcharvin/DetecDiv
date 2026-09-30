function mappedFovIndices = addData(obj,inputarg,pathCtx)

if nargin < 3 || ~isstruct(pathCtx)
    pathCtx = struct();
end
mappedFovIndices = [];

tmppath = pwd;

if nargin==1
    disp('Input data directory:');
    pathe = uigetdir(tmppath,'Select directory with data:');
    if pathe==0
        disp('Quit!');
        return;
    end
    newdata = parseInputData(pathe);
else
    if ischar(inputarg) || isstring(inputarg)
        pathe   = char(string(inputarg));
        newdata = parseInputData(pathe);
    else
        newdata = inputarg;
    end
end

if isempty(newdata) || ~isfield(newdata,'pos') || isempty(newdata.pos)
    disp('No parsed position to add.');
    return;
end
mappedFovIndices = zeros(1,numel(newdata.pos));

% Existing FOV signatures to avoid duplicate import from same source.
existingKeys = buildExistingKeyMap(obj,pathCtx);

% gestion de l'indice FOV a creer
nfov = numel(obj.fov);
if nfov==1 && isempty(obj.fov(1).id) && isempty(obj.fov(1).srcpath)
    cc = 1;
else
    cc = nfov+1;
end

nAdded = 0;
nSkipped = 0;

for i = 1:numel(newdata.pos)
    posStruct = newdata.pos(i);
    posKey = buildIncomingPosKey(posStruct,pathCtx);

    if ~isempty(posKey) && isKey(existingKeys, posKey)
        mappedFovIndices(i) = existingKeys(posKey);
        nSkipped = nSkipped + 1;
        continue;
    end

    obj.fov(cc) = fov; % nouveau FOV

    % Preparer mtInfo si multi-TIFF
    mtInfo = struct();
    if isfield(posStruct,'isMultiTiff') && posStruct.isMultiTiff
        mtInfo.isMultiTiff = true;
        mtInfo.tiffSource  = posStruct.tiffSource; % cell{ch}
        mtInfo.pageMap     = posStruct.pageMap;    % cell{ch}, mapping frame->page
    end
    if isfield(posStruct,'isOMEZarr') && posStruct.isOMEZarr
        mtInfo.isOMEZarr = true;
    end
    if isfield(posStruct,'isStackSeries') && posStruct.isStackSeries
        mtInfo.isStackSeries = true;
        mtInfo.stackPageMap = posStruct.stackPageMap;
    end

    % Appeler setpathlist avec ou sans mtInfo
    if ~isempty(fieldnames(mtInfo))
        obj.fov(cc).setpathlist( ...
            posStruct.pathlist, ...
            cc, ...
            posStruct.filelist, ...
            posStruct.name, ...
            mtInfo);
    else
        obj.fov(cc).setpathlist( ...
            posStruct.pathlist, ...
            cc, ...
            posStruct.filelist, ...
            posStruct.name);
    end

    % NDTiff info
    if isfield(posStruct,'isNDTiff') && posStruct.isNDTiff
        obj.fov(cc).isNDTiff       = true;
        obj.fov(cc).ndtiffPath     = posStruct.ndtiffPath;
        obj.fov(cc).ndtiffPosition = posStruct.ndtiffPosition;
        obj.fov(cc).ndtiffChannels = posStruct.ndtiffChannels;
        if isfield(posStruct,'ndtiffZ')
            obj.fov(cc).ndtiffZ = posStruct.ndtiffZ;
        else
            obj.fov(cc).ndtiffZ = 0;
        end
    end

    % OME-Zarr info
    if isfield(posStruct,'isOMEZarr') && posStruct.isOMEZarr
        obj.fov(cc).isOMEZarr = true;
        obj.fov(cc).omeZarrPath = posStruct.omeZarrPath;
        obj.fov(cc).omeZarrSeries = posStruct.omeZarrSeries;
        obj.fov(cc).omeZarrArrayPath = posStruct.omeZarrArrayPath;
        obj.fov(cc).omeZarrShape = posStruct.omeZarrShape;
        obj.fov(cc).omeZarrChunkShape = posStruct.omeZarrChunkShape;
        obj.fov(cc).omeZarrDtype = posStruct.omeZarrDtype;
        obj.fov(cc).omeZarrDimensionNames = posStruct.omeZarrDimensionNames;
        obj.fov(cc).omeZarrChannelIndices = posStruct.omeZarrChannelIndices;
        if isfield(posStruct,'omeZarrZIndices')
            obj.fov(cc).omeZarrZIndices = posStruct.omeZarrZIndices;
        end
    end

    % copier les autres infos
    if isfield(posStruct,'contours')
        obj.fov(cc).contours = posStruct.contours;
    else
        obj.fov(cc).contours = [];
    end

    obj.fov(cc).display.binning    = posStruct.binning;
    obj.fov(cc).display.intensity  = ones(1, size(posStruct.binning,2));
    obj.fov(cc).channel            = posStruct.channelname;
    obj.fov(cc).frames             = posStruct.frames;
    obj.fov(cc).interval           = posStruct.interval;
    obj.fov(cc).parent             = obj;
    if isfield(posStruct,'metadataText') && ~isempty(posStruct.metadataText)
        obj.fov(cc).comments = posStruct.metadataText;
    end

    if ~isempty(posKey)
        existingKeys(posKey) = cc;
    end
    mappedFovIndices(i) = cc;

    cc = cc+1;
    nAdded = nAdded + 1;
end

if nAdded > 0
    disp([num2str(nAdded) ' FOV(s) were added to the current project!']);
else
    disp('No new FOV was added to the current project.');
end

if nSkipped > 0
    disp([num2str(nSkipped) ' FOV(s) were skipped because they were already loaded.']);
end

end

function mapObj = buildExistingKeyMap(obj,pathCtx)
mapObj = containers.Map('KeyType','char','ValueType','double');
if isempty(obj.fov)
    return;
end

for i = 1:numel(obj.fov)
    try
        key = buildFovKey(obj.fov(i),pathCtx);
        if ~isempty(key) && ~isKey(mapObj,key)
            mapObj(key) = i;
        end
    catch
    end
end
end

function key = buildFovKey(f,pathCtx)
key = '';

chanSig = signatureList(f.channel);

if isprop(f,'isNDTiff') && f.isNDTiff
    src = normPath(getMaybe(f,'ndtiffPath',''),pathCtx);
    pos = num2str(getMaybe(f,'ndtiffPosition',-1));
    zst = num2str(getMaybe(f,'ndtiffZ',0));
    % Name can vary across imports (e.g. legacy long ids vs PosX), so avoid
    % using it in dedup signatures.
    key = lower(sprintf('ndtiff|%s|%s|%s|%s', src, pos, zst, chanSig));
    return;
end

if isprop(f,'isMultiTiff') && f.isMultiTiff
    src = firstNonEmptyCell(f.tiffSource);
    if isempty(src)
        src = firstNonEmptyCell(f.srcpath);
    end
    src = normPath(src,pathCtx);
    key = lower(sprintf('multitiff|%s|%s|%s', src, chanSig, pageMapSignature(f.pageMap)));
    return;
end

if isprop(f,'isStackSeries') && f.isStackSeries
    src = firstNonEmptyCell(f.srcpath);
    key = lower(sprintf('stackseries|%s|%s|%s|%s', normPath(src,pathCtx), ...
        baseNameFromFov(f), chanSig, pageMapSignature(f.stackPageMap)));
    return;
end

if isprop(f,'isOMEZarr') && f.isOMEZarr
    src = normPath(getMaybe(f,'omeZarrPath',''),pathCtx);
    seriesName = char(string(getMaybe(f,'omeZarrSeries','')));
    arrayPath = char(string(getMaybe(f,'omeZarrArrayPath','0')));
    key = lower(sprintf('omezarr|%s|%s|%s|%s', src, seriesName, arrayPath, chanSig));
    return;
end

src = firstNonEmptyCell(f.srcpath);
key = lower(sprintf('files|%s|%s|%s', normPath(src,pathCtx), baseNameFromFov(f), chanSig));
end

function key = buildIncomingPosKey(pos,pathCtx)
key = '';
chanSig = signatureList(getField(pos,'channelname',{}));

if isfield(pos,'isNDTiff') && pos.isNDTiff
    src = normPath(getField(pos,'ndtiffPath',''),pathCtx);
    p = num2str(getField(pos,'ndtiffPosition',-1));
    z = num2str(getField(pos,'ndtiffZ',0));
    key = lower(sprintf('ndtiff|%s|%s|%s|%s', src, p, z, chanSig));
    return;
end

if isfield(pos,'isMultiTiff') && pos.isMultiTiff
    src = firstNonEmptyCell(getField(pos,'tiffSource',{}));
    if isempty(src)
        src = firstNonEmptyCell(getField(pos,'pathlist',{}));
    end
    key = lower(sprintf('multitiff|%s|%s|%s', normPath(src,pathCtx), chanSig, pageMapSignature(getField(pos,'pageMap',{}))));
    return;
end

if isfield(pos,'isStackSeries') && pos.isStackSeries
    src = firstNonEmptyCell(getField(pos,'pathlist',{}));
    key = lower(sprintf('stackseries|%s|%s|%s|%s', normPath(src,pathCtx), ...
        char(string(getField(pos,'name',''))), chanSig, pageMapSignature(getField(pos,'stackPageMap',{}))));
    return;
end

if isfield(pos,'isOMEZarr') && pos.isOMEZarr
    src = normPath(getField(pos,'omeZarrPath',''),pathCtx);
    seriesName = char(string(getField(pos,'omeZarrSeries','')));
    arrayPath = char(string(getField(pos,'omeZarrArrayPath','0')));
    key = lower(sprintf('omezarr|%s|%s|%s|%s', src, seriesName, arrayPath, chanSig));
    return;
end

src = firstNonEmptyCell(getField(pos,'pathlist',{}));
key = lower(sprintf('files|%s|%s|%s', normPath(src,pathCtx), ...
    char(string(getField(pos,'name',''))), chanSig));
end

function name = baseNameFromFov(f)
name = char(string(f.id));
suffix = ['_' num2str(f.number)];
if endsWith(name,suffix)
    name = name(1:end-numel(suffix));
end
end

function v = getMaybe(obj, name, defaultVal)
v = defaultVal;
try
    if isprop(obj,name)
        val = obj.(name);
        if ~isempty(val)
            v = val;
        end
    end
catch
end
end

function v = getField(S, name, defaultVal)
v = defaultVal;
if isstruct(S) && isfield(S,name)
    val = S.(name);
    if ~isempty(val)
        v = val;
    end
end
end

function s = firstNonEmptyCell(c)
s = '';
if ischar(c) || isstring(c)
    s = char(string(c));
    return;
end
if ~iscell(c) || isempty(c)
    return;
end
for i = 1:numel(c)
    if ischar(c{i}) || isstring(c{i})
        t = char(string(c{i}));
        if ~isempty(t)
            s = t;
            return;
        end
    end
end
end

function s = signatureList(v)
if ischar(v) || isstring(v)
    s = lower(char(string(v)));
    return;
end
if isempty(v)
    s = '';
    return;
end
if iscell(v)
    tmp = cell(1,numel(v));
    for i=1:numel(v)
        try
            tmp{i} = lower(char(string(v{i})));
        catch
            tmp{i} = '';
        end
    end
    s = strjoin(tmp, ',');
else
    try
        s = lower(char(string(v)));
    catch
        s = '';
    end
end
end

function p = normPath(in,pathCtx)
p = '';
if isempty(in)
    return;
end
try
    p = char(string(in));
catch
    return;
end
p = strrep(p,'\','/');
p = regexprep(p,'/+$','');
if ~isempty(p) && exist('detecdiv_paths_map_module_path','file') == 2
    try
        [canonical,mapped] = detecdiv_paths_map_module_path(p,pathCtx,'server');
        if mapped
            p = regexprep(strrep(char(string(canonical)),'\','/'),'/+$','');
        end
    catch
    end
end
end

function s = pageMapSignature(pageMap)
s = '';
if isempty(pageMap) || ~iscell(pageMap)
    return;
end
parts = cell(1, numel(pageMap));
for i = 1:numel(pageMap)
    pm = pageMap{i};
    if isempty(pm)
        parts{i} = '';
        continue;
    end
    try
        parts{i} = sprintf('%d:%d:%d', double(pm(1)), double(pm(end)), numel(pm));
    catch
        parts{i} = '';
    end
end
s = strjoin(parts, ',');
end
