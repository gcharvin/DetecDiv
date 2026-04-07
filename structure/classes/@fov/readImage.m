function im = readImage(obj, frame, channel)
% readImage  -> retourne l'image du canal `channel` à l'instant `frame`
%
% Gère :
%   - mode fichiers classiques : srclist{ch}(f).name existe sur disque
%   - mode multi-TIFF          : images empilées dans tiffSource{ch}, accès par pageMap{ch}(f)

im = [];

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
    return;
end

% --------- mode OME-Zarr ---------
if isprop(obj,'isOMEZarr') && obj.isOMEZarr
    try
        im = localReadOMEZarrPlane(obj, frameEff, channel);
    catch ME
        warning('Failed to read OME-Zarr image: %s', ME.message);
        im = [];
        return;
    end

    if ~isempty(obj.orientation) && obj.orientation ~= 0
        im = imrotate(im, obj.orientation);
    end
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
        im = imread(bigTiffPath, pageToRead);
    catch ME
        warning('Failed to read multi-TIFF page %d from %s: %s', ...
            pageToRead, bigTiffPath, ME.message);
        return;
    end

else
    % --------- mode fichiers classiques ---------
        foldert = '';
        if isfield(thisEntry,'folder')
            foldert = thisEntry.folder;
        end
        if isempty(foldert)
            % fallback: if name contains a path, extract its folder
            if isfield(thisEntry,'name') && ~isempty(thisEntry.name)
                [fp, ~, ~] = fileparts(thisEntry.name);
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

    imstr = fullfile(foldert, thisEntry.name);

    if ~exist(imstr,'file')
        disp('folder exists, but file does not ! Quitting....');
        return;
    end

    try
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
end

function im = localReadOMEZarrPlane(obj, frameEff, channel)
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
