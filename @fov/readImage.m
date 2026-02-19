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
