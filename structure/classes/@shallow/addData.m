function addData(obj,inputarg)

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

% Existing FOV signatures to avoid duplicate import from same source.
existingKeys = buildExistingKeyMap(obj);

% gestion de l'indice FOV a creer
nfov = numel(obj.fov);
if nfov==1 && numel(obj.fov.srclist)==0
    cc = 1;
else
    cc = nfov+1;
end

nAdded = 0;
nSkipped = 0;

for i = 1:numel(newdata.pos)
    posStruct = newdata.pos(i);
    posKey = buildIncomingPosKey(posStruct);

    if ~isempty(posKey) && isKey(existingKeys, posKey)
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
        existingKeys(posKey) = true;
    end

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

function mapObj = buildExistingKeyMap(obj)
mapObj = containers.Map('KeyType','char','ValueType','logical');
if isempty(obj.fov)
    return;
end

for i = 1:numel(obj.fov)
    try
        key = buildFovKey(obj.fov(i));
        if ~isempty(key)
            mapObj(key) = true;
        end
    catch
    end
end
end

function key = buildFovKey(f)
key = '';
name = '';
if isprop(f,'id') && ~isempty(f.id)
    name = char(string(f.id));
    name = regexprep(name, '_\d+$', '');
end

chanSig = signatureList(f.channel);

if isprop(f,'isNDTiff') && f.isNDTiff
    src = normPath(getMaybe(f,'ndtiffPath',''));
    pos = num2str(getMaybe(f,'ndtiffPosition',-1));
    zst = num2str(getMaybe(f,'ndtiffZ',0));
    key = lower(sprintf('ndtiff|%s|%s|%s|%s|%s', src, pos, zst, chanSig, name));
    return;
end

if isprop(f,'isMultiTiff') && f.isMultiTiff
    src = firstNonEmptyCell(f.tiffSource);
    if isempty(src)
        src = firstNonEmptyCell(f.srcpath);
    end
    src = normPath(src);
    key = lower(sprintf('multitiff|%s|%s|%s', src, chanSig, name));
    return;
end

src = firstNonEmptyCell(f.srcpath);
sample = firstFileFromFov(f);
key = lower(sprintf('files|%s|%s|%s|%s', normPath(src), normPath(sample), chanSig, name));
end

function key = buildIncomingPosKey(pos)
key = '';
name = char(string(getField(pos,'name','')));
chanSig = signatureList(getField(pos,'channelname',{}));

if isfield(pos,'isNDTiff') && pos.isNDTiff
    src = normPath(getField(pos,'ndtiffPath',''));
    p = num2str(getField(pos,'ndtiffPosition',-1));
    z = num2str(getField(pos,'ndtiffZ',0));
    key = lower(sprintf('ndtiff|%s|%s|%s|%s|%s', src, p, z, chanSig, name));
    return;
end

if isfield(pos,'isMultiTiff') && pos.isMultiTiff
    src = firstNonEmptyCell(getField(pos,'tiffSource',{}));
    if isempty(src)
        src = firstNonEmptyCell(getField(pos,'pathlist',{}));
    end
    key = lower(sprintf('multitiff|%s|%s|%s', normPath(src), chanSig, name));
    return;
end

src = firstNonEmptyCell(getField(pos,'pathlist',{}));
sample = firstFileFromParsedPos(pos);
key = lower(sprintf('files|%s|%s|%s|%s', normPath(src), normPath(sample), chanSig, name));
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

function s = firstFileFromFov(f)
s = '';
try
    if ~isempty(f.srclist) && iscell(f.srclist) && ~isempty(f.srclist{1})
        e = f.srclist{1};
        if isstruct(e) && ~isempty(e) && isfield(e,'name')
            s = e(1).name;
            return;
        end
    end
catch
end
end

function s = firstFileFromParsedPos(pos)
s = '';
if ~isfield(pos,'filelist') || isempty(pos.filelist)
    return;
end
fl = pos.filelist;
try
    if iscell(fl)
        x = fl{1};
        if isstruct(x) && ~isempty(x) && isfield(x,'name')
            s = x(1).name;
            return;
        end
    elseif isstruct(fl) && ~isempty(fl) && isfield(fl,'name')
        s = fl(1).name;
        return;
    end
catch
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

function p = normPath(in)
p = '';
if isempty(in)
    return;
end
try
    p = char(string(in));
catch
    return;
end
p = strrep(p,'\\','/');
p = regexprep(p,'/+$','');
end
