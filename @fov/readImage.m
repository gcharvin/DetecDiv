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
        foldert = thisEntry.folder;
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
