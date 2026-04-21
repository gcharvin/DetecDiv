function im = readImage(obj, frame, channel)
% readImage  -> retourne l'image du canal `channel` à l'instant `frame`
%
% Gère :
%   - mode fichiers classiques : srclist{ch}(f).name existe sur disque
%   - mode multi-TIFF          : images empilées dans tiffSource{ch}, accès par pageMap{ch}(f)

im = [];
fprintf('[readImage] request FOV=%s frame=%d channel=%d\n', localFovLabel(obj), frame, channel);

% --------- sécurité indices ---------
if channel > numel(obj.channel) || channel < 1
    disp('This channel does not exist; quitting !');
    return;
end


nChan = numel(obj.channel);


% --------- ensure raw path is accessible (just-in-time relink) ---------
try
    [obj, ok] = detecdiv_paths_ensure_fov_ready(obj, channel, false, false);
    if ~ok
        fprintf('[readImage] rawdata unavailable for FOV=%s channel=%d\n', localFovLabel(obj), channel);
        return;
    end
catch ME
    warning('Rawdata relink check failed: %s', ME.message);
end


% --------- gestion interval (sous-échantillonnage canal) ---------
frameEff = frame;
if ~isempty(obj.interval)
    baseInt = obj.interval(1);
    if isempty(baseInt) || baseInt == 0
        baseInt = 1;
    end
    if channel <= numel(obj.interval)
        scale = obj.interval(channel) / baseInt;
        if isempty(scale) || scale <= 0
            scale = 1;
        end
        frameEff = uint16(ceil(frame / scale));
    end
end

% clamp dans les frames dispo de ce canal
if channel <= numel(obj.frames)
    maxF = obj.frames(channel);
else
    maxF = obj.frames(1);
end
frameEff = max(1, min(frameEff, maxF));

% récupérer métadonnées du frame
if channel > numel(obj.srclist) || isempty(obj.srclist{channel})
    disp('Channel has no srclist entry; quitting !');
    return;
end
chanList = obj.srclist{channel};
if frameEff > numel(chanList)
    disp('Frame exceeds available images for this channel; quitting !');
    return;
end
    thisEntry = chanList(frameEff);  % struct with .name, .folder, etc.

% --------- mode NDTiff ---------
if isprop(obj,'isNDTiff') && obj.isNDTiff
    dsPath = obj.ndtiffPath;
    if isempty(dsPath) && ~isempty(obj.srcpath)
        dsPath = obj.srcpath{1};
    end
    if ~isfolder(dsPath)
        warning('NDTiff dataset folder not found: %s', dsPath);
        return;
    end

    try
        fprintf('[readImage] mode=NDTiff source=%s\n', string(dsPath));
        % cache dataset objects per path
        persistent ndtiffCache
        if isempty(ndtiffCache)
            ndtiffCache = containers.Map('KeyType','char','ValueType','any');
        end
        key = char(dsPath);
        if ndtiffCache.isKey(key)
            dataset = ndtiffCache(key);
        else
            dataset = javaObject('org.micromanager.ndtiffstorage.NDTiffStorage', key);
            ndtiffCache(key) = dataset;
        end

        % axes (0-based)
        if ~isempty(obj.ndtiffChannels) && channel <= numel(obj.ndtiffChannels)
            chIdx = obj.ndtiffChannels(channel);
        else
            chIdx = channel - 1;
        end
        if isprop(obj,'ndtiffTimes') && ~isempty(obj.ndtiffTimes)
            if numel(obj.ndtiffTimes) >= frameEff
                tIdx = double(obj.ndtiffTimes(frameEff));
            else
                tIdx = double(obj.ndtiffTimes(end));
            end
        else
            tIdx = double(frameEff) - 1;
        end
            zIdx = 0;
            if isprop(obj,'ndtiffZ') && ~isempty(obj.ndtiffZ)
                if numel(obj.ndtiffZ) >= channel
                    zIdx = double(obj.ndtiffZ(channel));
                else
                    zIdx = double(obj.ndtiffZ(1));
                end
            end
        pIdx = 0;
        if isprop(obj,'ndtiffPosition') && ~isempty(obj.ndtiffPosition)
            pIdx = double(obj.ndtiffPosition);
        end

        axes = java.util.HashMap();
        axes.put("channel", chIdx);
        axes.put("time", tIdx);
        axes.put("z", zIdx);
        axes.put("position", pIdx);

        taggedImg = dataset.getImage(axes);
        if isempty(taggedImg)
            warning('NDTiff image missing at pos=%d ch=%d z=%d t=%d (%s)', ...
                pIdx, chIdx, zIdx, tIdx, dsPath);
            return;
        end
        try
            pixels = taggedImg.pix;
        catch
            try
                pixels = taggedImg.getPix();
            catch
                warning('NDTiff image returned unexpected type (%s) at pos=%d ch=%d z=%d t=%d (%s)', ...
                    class(taggedImg), pIdx, chIdx, zIdx, tIdx, dsPath);
                return;
            end
        end
        imgBounds = dataset.getImageBounds();
        xsize = imgBounds(3);
        ysize = imgBounds(4);
        im = reshape(pixels, [xsize, ysize])';
        if isa(im,'int16')
            im = uint16(im);
        end
       
    catch ME
        warning('Failed to read NDTiff image: %s', ME.message);
        return;
    end

    % appliquer rotation si besoin
    if ~isempty(obj.orientation) && obj.orientation ~= 0
        im = imrotate(im, obj.orientation);
    end
    localLogLoadedImage(obj, channel, frameEff, im, "NDTiff", string(dsPath));
    return;
end

% --------- mode OME-Zarr ---------
if localShouldUseOMEZarr(obj, thisEntry, channel)
    try
        fprintf('[readImage] mode=OME-Zarr dataset=%s entry=%s\n', ...
            string(localGetSourcePath(obj, channel)), string(localGetEntryName(thisEntry)));
        im = localReadOMEZarrPlane(obj, frameEff, channel);
    catch ME
        warning('Failed to read OME-Zarr image: %s', ME.message);
        im = [];
        return;
    end

    if ~isempty(obj.orientation) && obj.orientation ~= 0
        im = imrotate(im, obj.orientation);
    end
    localLogLoadedImage(obj, channel, frameEff, im, "OME-Zarr", string(localGetSourcePath(obj, channel)));
    return;
end

% --------- mode multi-TIFF ---------
if obj.isMultiTiff
    % on s'attend à :
    %   obj.tiffSource{ch} = chemin du gros TIFF réel ;
    %   obj.pageMap{ch}(f) = index de page à lire
    %
    % fallback gentle si pour une raison x pageMap est vide mais on sait qu'on a nChan canaux:
    %   page = (frameEff-1)*nChan + channel

    if channel <= numel(obj.tiffSource) && ~isempty(obj.tiffSource{channel})
        bigTiffPath = obj.tiffSource{channel};
    else
        % par sécurité on réutilise le premier
        bigTiffPath = obj.tiffSource{1};
    end

    if channel <= numel(obj.pageMap) && numel(obj.pageMap{channel}) >= frameEff ...
            && ~isempty(obj.pageMap{channel})
        pageToRead = obj.pageMap{channel}(frameEff);
    else
        pageToRead = (double(frameEff)-1)*double(nChan) + double(channel);
    end

    if ~exist(bigTiffPath, 'file')
        warning('Multi-TIFF source not found on disk: %s', bigTiffPath);
        return;
    end

    try
        fprintf('[readImage] mode=Multi-TIFF source=%s page=%d\n', string(bigTiffPath), pageToRead);
        im = imread(bigTiffPath, pageToRead);
    catch ME
        warning('Failed to read multi-TIFF page %d from %s: %s', ...
            pageToRead, bigTiffPath, ME.message);
        return;
    end

else
    % --------- mode fichiers classiques ---------
    foldert = '';
    fileName = '';
    if isfield(thisEntry,'name') && ~isempty(thisEntry.name)
        fileName = thisEntry.name;
    end
    if isfield(thisEntry,'folder')
        foldert = thisEntry.folder;
    end
    if isempty(foldert)
        % fallback: if name contains a path, extract its folder
        if ~isempty(fileName)
            [fp, ~, ~] = fileparts(fileName);
            if ~isempty(fp)
                foldert = fp;
            end
        end
    end
    if isempty(foldert)
        if iscell(obj.srcpath) && channel <= numel(obj.srcpath) && ~isempty(obj.srcpath{channel})
            foldert = obj.srcpath{channel};
        end
    end
    if ~isfolder(foldert)
        disp('folder does not exist ! Quitting....');
        return;
    end

    % Some legacy projects store an absolute path directly in srclist.name.
    % In that case, do not prepend folder again.
    imstr = fileName;
    if isempty(imstr)
        disp('Image entry has no filename ! Quitting....');
        return;
    end
    if exist(imstr,'file') ~= 2
        [fp, ~, ~] = fileparts(imstr);
        if isempty(fp)
            imstr = fullfile(foldert, imstr);
        end
    end

    if ~exist(imstr,'file')
        disp('folder exists, but file does not ! Quitting....');
        return;
    end

    try
        fprintf('[readImage] mode=File source=%s\n', string(imstr));
        im = imread(imstr);
    catch ME
        warning('Could not read image file %s: %s', imstr, ME.message);
        return;
    end
end

% appliquer rotation si besoin
if ~isempty(obj.orientation) && obj.orientation ~= 0
    im = imrotate(im, obj.orientation);
end
localLogLoadedImage(obj, channel, frameEff, im, "File", string(localGetSourcePath(obj, channel)));
end

function localLogLoadedImage(obj, channel, frameEff, im, modeName, sourcePath)
if isempty(im)
    fprintf('[readImage] loaded empty image FOV=%s channel=%d frame=%d mode=%s source=%s\n', ...
        localFovLabel(obj), channel, frameEff, string(modeName), string(sourcePath));
    return;
end
fprintf('[readImage] loaded FOV=%s channel=%d frame=%d mode=%s size=%s class=%s source=%s\n', ...
    localFovLabel(obj), channel, frameEff, string(modeName), mat2str(size(im)), class(im), string(sourcePath));
end

function s = localGetSourcePath(obj, channel)
s = "";
try
    if isprop(obj,'isNDTiff') && obj.isNDTiff && isprop(obj,'ndtiffPath') && ~isempty(obj.ndtiffPath)
        s = string(obj.ndtiffPath);
        return;
    end
    if isprop(obj,'isOMEZarr') && obj.isOMEZarr && isprop(obj,'omeZarrPath') && ~isempty(obj.omeZarrPath)
        s = string(obj.omeZarrPath);
        return;
    end
    if isprop(obj,'isMultiTiff') && obj.isMultiTiff && channel <= numel(obj.tiffSource) && ~isempty(obj.tiffSource{channel})
        s = string(obj.tiffSource{channel});
        return;
    end
    if iscell(obj.srcpath) && channel <= numel(obj.srcpath) && ~isempty(obj.srcpath{channel})
        s = string(obj.srcpath{channel});
    end
catch
end
end

function s = localGetEntryName(entry)
s = "";
try
    if isfield(entry,'name') && ~isempty(entry.name)
        s = string(entry.name);
    end
catch
end
end

function label = localFovLabel(obj)
label = '';
try
    if isprop(obj,'id') && ~isempty(obj.id)
        label = char(string(obj.id));
    end
catch
end
if isempty(label)
    label = '<unnamed>';
end
end

function im = localReadOMEZarrPlane(obj, frameEff, channel)
obj = localPopulateLegacyOMEZarrInfo(obj, channel);
zarrPath = obj.omeZarrPath;
if isempty(zarrPath) && ~isempty(obj.srcpath)
    zarrPath = obj.srcpath{1};
end
if ~isfolder(zarrPath)
    warning('OME-Zarr dataset folder not found: %s', zarrPath);
    im = [];
    return;
end

seriesName = obj.omeZarrSeries;
if isempty(seriesName)
    seriesName = '0';
end
arrayPath = obj.omeZarrArrayPath;
if isempty(arrayPath)
    if exist(fullfile(zarrPath, seriesName, '.zarray'), 'file') == 2
        arrayPath = '';
    else
        arrayPath = '0';
    end
end

shape = obj.omeZarrShape;
chunks = obj.omeZarrChunkShape;
dimNames = obj.omeZarrDimensionNames;
if isempty(dimNames)
    dimNames = {'t','c','y','x'};
end
tDim = find(strcmpi(dimNames, 't'), 1, 'first');
cDim = find(strcmpi(dimNames, 'c'), 1, 'first');
zDim = find(strcmpi(dimNames, 'z'), 1, 'first');
yDim = find(strcmpi(dimNames, 'y'), 1, 'first');
xDim = find(strcmpi(dimNames, 'x'), 1, 'first');
if isempty(tDim), tDim = 1; end
if isempty(cDim), cDim = 2; end
if isempty(yDim), yDim = 3; end
if isempty(xDim), xDim = 4; end

if isempty(shape) || numel(shape) < max([tDim cDim yDim xDim])
    arrayJson = jsondecode(fileread(fullfile(zarrPath, seriesName, arrayPath, 'zarr.json')));
    shape = double(arrayJson.shape(:))';
    chunks = double(arrayJson.chunk_grid.configuration.chunk_shape(:))';
end

if isempty(chunks) || chunks(yDim) ~= shape(yDim) || chunks(xDim) ~= shape(xDim)
    error('Only one full Y/X chunk per image is supported for OME-Zarr lazy reads.');
end

sourceChannel = channel - 1;
if ~isempty(obj.omeZarrChannelIndices) && channel <= numel(obj.omeZarrChannelIndices)
    sourceChannel = obj.omeZarrChannelIndices(channel);
end
sourceZ = 0;
if isprop(obj,'omeZarrZIndices') && ~isempty(obj.omeZarrZIndices) && channel <= numel(obj.omeZarrZIndices)
    sourceZ = obj.omeZarrZIndices(channel);
end

coord = zeros(1, numel(shape));
coord(tDim) = double(frameEff) - 1;
coord(cDim) = double(sourceChannel);
if ~isempty(zDim)
    coord(zDim) = double(sourceZ);
end

if exist(fullfile(zarrPath, seriesName, arrayPath, '.zarray'), 'file') == 2
    im = localReadOMEZarrPlanePython(zarrPath, seriesName, arrayPath, coord, shape, dimNames, char(string(obj.omeZarrDtype)));
    return;
end

chunkPath = fullfile(zarrPath, seriesName, arrayPath, 'c');
for i = 1:numel(coord)
    chunkPath = fullfile(chunkPath, num2str(coord(i)));
end

if exist(chunkPath, 'file') ~= 2
    warning('OME-Zarr chunk not found: %s', chunkPath);
    im = [];
    return;
end

dtype = char(string(obj.omeZarrDtype));
if isempty(dtype)
    dtype = 'uint16';
end

switch lower(dtype)
    case {'uint16','<u2','|u2','>u2'}
        precision = 'uint16=>uint16';
        bytesPerPixel = 2;
    case {'uint8','<u1','|u1','>u1'}
        precision = 'uint8=>uint8';
        bytesPerPixel = 1;
    case {'int16','<i2','|i2','>i2'}
        precision = 'int16=>int16';
        bytesPerPixel = 2;
    otherwise
        error('Unsupported OME-Zarr data_type: %s', dtype);
end

fid = fopen(chunkPath, 'r', 'ieee-le');
if fid < 0
    error('Cannot open OME-Zarr chunk: %s', chunkPath);
end
cleaner = onCleanup(@() fclose(fid));
nPix = shape(yDim) * shape(xDim);
raw = fread(fid, nPix, precision);
if numel(raw) ~= nPix
    info = dir(chunkPath);
    error('OME-Zarr chunk has %d bytes, expected %d bytes.', info.bytes, nPix * bytesPerPixel);
end

im = reshape(raw, [shape(xDim), shape(yDim)])';
end

function im = localReadOMEZarrPlanePython(zarrPath, seriesName, arrayPath, coord, shape, dimNames, dtype)
yDim = find(strcmpi(dimNames, 'y'), 1, 'first');
xDim = find(strcmpi(dimNames, 'x'), 1, 'first');
if isempty(yDim), yDim = numel(shape)-1; end
if isempty(xDim), xDim = numel(shape); end

arrayDir = fullfile(zarrPath, seriesName, arrayPath);
tmpFile = [tempname '.raw'];
cleaner = onCleanup(@() localDeleteIfExists(tmpFile));

code = [ ...
    "import zarr, numpy as np" newline ...
    "arr = zarr.open(path, mode='r')" newline ...
    "idx = [int(v) for v in coord]" newline ...
    "idx[y_dim] = slice(None)" newline ...
    "idx[x_dim] = slice(None)" newline ...
    "plane = np.ascontiguousarray(arr[tuple(idx)])" newline ...
    "with open(out_path, 'wb') as fh:" newline ...
    "    fh.write(plane.tobytes(order='C'))" ...
    ];

try
    pyrun(code, path=arrayDir, coord=int64(coord), y_dim=int64(yDim-1), x_dim=int64(xDim-1), out_path=tmpFile);
catch
    localReadOMEZarrPlaneSystemPython(arrayDir, tmpFile, coord, yDim-1, xDim-1);
end

fid = fopen(tmpFile, 'r', 'ieee-le');
if fid < 0
    error('Cannot open temporary OME-Zarr plane: %s', tmpFile);
end
nPix = shape(yDim) * shape(xDim);

switch lower(char(string(dtype)))
    case {'uint16','<u2','|u2','>u2'}
        precision = 'uint16=>uint16';
    case {'uint8','<u1','|u1','>u1'}
        precision = 'uint8=>uint8';
    case {'int16','<i2','|i2','>i2'}
        precision = 'int16=>int16';
    otherwise
        error('Unsupported OME-Zarr dtype: %s', char(string(dtype)));
end

raw = fread(fid, nPix, precision);
fclose(fid);
if numel(raw) ~= nPix
    error('OME-Zarr Python read returned %d pixels, expected %d.', numel(raw), nPix);
end
im = reshape(raw, [shape(xDim), shape(yDim)])';
end

function localDeleteIfExists(pathStr)
if exist(pathStr, 'file') == 2
    delete(pathStr);
end
end

function localReadOMEZarrPlaneSystemPython(arrayDir, tmpFile, coord, yDim0, xDim0)
scriptPath = which('read_omezarr_plane_to_raw.py');
if isempty(scriptPath)
    buildPath = which('buildomezarr');
    if ~isempty(buildPath)
        scriptPath = fullfile(fileparts(buildPath), 'read_omezarr_plane_to_raw.py');
    end
end
if isempty(scriptPath) || exist(scriptPath, 'file') ~= 2
    error('Cannot find read_omezarr_plane_to_raw.py for compressed OME-Zarr reads.');
end

cfgFile = [tempname '.json'];
cfgCleaner = onCleanup(@() localDeleteIfExists(cfgFile));
cfg = struct();
cfg.array_dir = arrayDir;
cfg.out_path = tmpFile;
cfg.coord = num2cell(double(coord));
cfg.y_dim = double(yDim0);
cfg.x_dim = double(xDim0);
fid = fopen(cfgFile, 'w');
if fid < 0
    error('Cannot create temporary OME-Zarr Python config: %s', cfgFile);
end
fprintf(fid, '%s', jsonencode(cfg));
fclose(fid);

pyexe = localGetPythonExecutable();
if isempty(pyexe)
    cmd = sprintf('python "%s" "%s"', scriptPath, cfgFile);
else
    cmd = sprintf('"%s" "%s" "%s"', pyexe, scriptPath, cfgFile);
end
[status, msg] = system(cmd);
if status ~= 0
    error('System Python OME-Zarr read failed: %s', strtrim(msg));
end
end

function pyexe = localGetPythonExecutable()
pyexe = '';
try
    pe = pyenv;
    candidates = {char(string(pe.Executable)), char(string(pe.Version))};
    for i = 1:numel(candidates)
        cand = candidates{i};
        if ~isempty(cand) && exist(cand, 'file') == 2
            pyexe = cand;
            return;
        end
    end
catch
end
end

function tf = localShouldUseOMEZarr(obj, thisEntry, channel)
tf = false;
if isprop(obj,'isOMEZarr') && obj.isOMEZarr
    tf = true;
    return;
end

zarrPath = '';
if isprop(obj,'omeZarrPath') && ~isempty(obj.omeZarrPath)
    zarrPath = char(string(obj.omeZarrPath));
elseif iscell(obj.srcpath) && channel <= numel(obj.srcpath) && ~isempty(obj.srcpath{channel})
    zarrPath = char(string(obj.srcpath{channel}));
end

if isempty(zarrPath) || ~isfolder(zarrPath)
    return;
end

hasZarrRoot = exist(fullfile(zarrPath,'zarr.json'), 'file') == 2 || ...
    (exist(fullfile(zarrPath,'.zattrs'), 'file') == 2 && exist(fullfile(zarrPath,'.zgroup'), 'file') == 2);
if ~hasZarrRoot
    return;
end

nameStr = '';
if isfield(thisEntry,'name') && ~isempty(thisEntry.name)
    nameStr = char(string(thisEntry.name));
end
tf = endsWith(zarrPath, '.ome.zarr', 'IgnoreCase', true) || startsWith(nameStr, 'omezarr_', 'IgnoreCase', true);
end

function obj = localPopulateLegacyOMEZarrInfo(obj, channel)
if isprop(obj,'omeZarrPath') && ~isempty(obj.omeZarrPath) && ...
        isprop(obj,'omeZarrShape') && ~isempty(obj.omeZarrShape)
    return;
end

zarrPath = '';
if isprop(obj,'omeZarrPath') && ~isempty(obj.omeZarrPath)
    zarrPath = char(string(obj.omeZarrPath));
elseif iscell(obj.srcpath) && channel <= numel(obj.srcpath) && ~isempty(obj.srcpath{channel})
    zarrPath = char(string(obj.srcpath{channel}));
elseif iscell(obj.srcpath) && ~isempty(obj.srcpath) && ~isempty(obj.srcpath{1})
    zarrPath = char(string(obj.srcpath{1}));
end
if isempty(zarrPath) || ~isfolder(zarrPath)
    return;
end

seriesName = '';
arrayPath = '';
if isprop(obj,'omeZarrSeries') && ~isempty(obj.omeZarrSeries)
    seriesName = char(string(obj.omeZarrSeries));
end
if isprop(obj,'omeZarrArrayPath') && ~isempty(obj.omeZarrArrayPath)
    arrayPath = char(string(obj.omeZarrArrayPath));
end

% Legacy imported projects may only keep a virtual file name like omezarr_1_0.
if (isempty(seriesName) || isempty(arrayPath)) && iscell(obj.srclist) && channel <= numel(obj.srclist) && ~isempty(obj.srclist{channel})
    try
        entry = obj.srclist{channel}(1);
        if isfield(entry,'name') && ~isempty(entry.name)
            tok = regexp(char(string(entry.name)), '^omezarr_(.+)_(.+)$', 'tokens', 'once');
            if ~isempty(tok)
                if isempty(seriesName), seriesName = tok{1}; end
                if isempty(arrayPath), arrayPath = tok{2}; end
            end
        end
    catch
    end
end

% Fallback to first numeric series / first array if metadata is absent.
if isempty(seriesName)
    d = dir(zarrPath);
    d = d([d.isdir]);
    d = d(~ismember({d.name},{'.','..','OME'}));
    seriesCandidates = {d.name};
    if ~isempty(seriesCandidates)
        nums = nan(size(seriesCandidates));
        for i = 1:numel(seriesCandidates)
            nums(i) = str2double(seriesCandidates{i});
        end
        if any(isfinite(nums))
            [~, ix] = min(nums(isfinite(nums)));
            finiteNames = seriesCandidates(isfinite(nums));
            seriesName = finiteNames{ix};
        else
            seriesName = seriesCandidates{1};
        end
    else
        seriesName = '0';
    end
end
if isempty(arrayPath)
    if exist(fullfile(zarrPath, seriesName, '0', 'zarr.json'), 'file') == 2
        arrayPath = '0';
    elseif exist(fullfile(zarrPath, seriesName, '.zarray'), 'file') == 2
        arrayPath = '';
    else
        arrayPath = '0';
    end
end

if isprop(obj,'isOMEZarr')
    obj.isOMEZarr = true;
end
if isprop(obj,'omeZarrPath')
    obj.omeZarrPath = zarrPath;
end
if isprop(obj,'omeZarrSeries')
    obj.omeZarrSeries = seriesName;
end
if isprop(obj,'omeZarrArrayPath')
    obj.omeZarrArrayPath = arrayPath;
end

arrayJsonPath = fullfile(zarrPath, seriesName, arrayPath, 'zarr.json');
if exist(arrayJsonPath, 'file') == 2
    try
        arrayJson = jsondecode(fileread(arrayJsonPath));
        shapeVal = [];
        if isprop(obj,'omeZarrShape') && isfield(arrayJson,'shape')
            shapeVal = double(arrayJson.shape(:))';
            obj.omeZarrShape = shapeVal;
        end
        if isprop(obj,'omeZarrChunkShape') && isfield(arrayJson,'chunk_grid') && ...
                isfield(arrayJson.chunk_grid,'configuration') && ...
                isfield(arrayJson.chunk_grid.configuration,'chunk_shape')
            obj.omeZarrChunkShape = double(arrayJson.chunk_grid.configuration.chunk_shape(:))';
        end
        if isprop(obj,'omeZarrDtype') && isfield(arrayJson,'data_type')
            obj.omeZarrDtype = char(string(arrayJson.data_type));
        end
        if isprop(obj,'omeZarrDimensionNames') && isfield(arrayJson,'dimension_names') && ~isempty(arrayJson.dimension_names)
            obj.omeZarrDimensionNames = cellstr(string(arrayJson.dimension_names));
        end

        if isprop(obj,'omeZarrDimensionNames') && ~isempty(obj.omeZarrDimensionNames) && ...
                isprop(obj,'omeZarrZIndices') && isempty(obj.omeZarrZIndices) && ...
                ~isempty(shapeVal) && iscell(obj.channel) && ~isempty(obj.channel)
            cDim = find(strcmpi(obj.omeZarrDimensionNames, 'c'), 1, 'first');
            zDim = find(strcmpi(obj.omeZarrDimensionNames, 'z'), 1, 'first');
            if ~isempty(cDim) && ~isempty(zDim) && numel(shapeVal) >= max(cDim, zDim)
                nC = shapeVal(cDim);
                nZ = shapeVal(zDim);
                nProjCh = numel(obj.channel);
                if nProjCh == nC && nZ > 1
                    commonZ = localFindCommonZIndex(fullfile(zarrPath, seriesName, 'zarr.json'), nC);
                    if isempty(commonZ)
                        commonZ = floor((nZ - 1) / 2);
                    end
                    obj.omeZarrChannelIndices = 0:(nProjCh-1);
                    obj.omeZarrZIndices = repmat(commonZ, 1, nProjCh);
                end
            end
        end
    catch
    end
end
end

function zIdx = localFindCommonZIndex(seriesJsonPath, nC)
zIdx = [];
if exist(seriesJsonPath, 'file') ~= 2
    return;
end
try
    seriesJson = jsondecode(fileread(seriesJsonPath));
    fm = seriesJson.attributes.ome_writers.frame_metadata;
    if isempty(fm)
        return;
    end
    pairs = [];
    maxScan = min(numel(fm), 500);
    for i = 1:maxScan
        if ~isfield(fm(i), 'storage_index')
            continue;
        end
        idx = double(fm(i).storage_index(:))';
        if numel(idx) < 3
            continue;
        end
        pairs(end+1,:) = idx(2:3); %#ok<AGROW>
    end
    if isempty(pairs)
        return;
    end
    zVals = unique(pairs(:,2), 'stable');
    for i = 1:numel(zVals)
        z = zVals(i);
        cVals = unique(pairs(pairs(:,2) == z, 1));
        if numel(cVals) >= nC
            zIdx = z;
            return;
        end
    end
catch
end
end
