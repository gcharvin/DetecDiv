function adjustROISize(obj, val, varargin)
%ADJUSTROISIZE change the ROI array (bbox) and, if possible, recadre / bin l'image
%
% val must be : [ x y width height ]  (ou [x y], pour déplacer l'origine)
%
% Optionnel :
%   adjustROISize(obj, val, binning)
%       -> binning : facteur de downsampling spatial (>0)
%
% Nouveauté (patch) :
%   adjustROISize(obj, val, binning, 'localCrop', true)
%       -> interprète val=[x y w h] comme des coordonnées LOCALES (dans obj.image),
%          recadre obj.image et met à jour obj.value (coordonnées absolues FOV)
%
% Cas particuliers :
%   - numel(val)==4, val(1)==0 => change width/height en gardant le centre
%   - numel(val)==2           => change seulement l'origine

    % ------------------------------------------------------------
    % Parse varargin :
    %   - 1er argument numérique optionnel = binning
    %   - paires clé/valeur : 'localCrop', true/false
    % ------------------------------------------------------------
    binning   = [];
    localCrop = false;

    if ~isempty(varargin)
        % binning si premier arg numérique scalaire
        if isnumeric(varargin{1}) && isscalar(varargin{1})
            binning = varargin{1};
            varargin = varargin(2:end);
        end

        % paires key/value
        if ~isempty(varargin)
            for k = 1:2:numel(varargin)
                if k+1 > numel(varargin), break; end
                key = varargin{k};
                if ischar(key) || (isstring(key) && isscalar(key))
                    switch lower(string(key))
                        case "localcrop"
                            localCrop = logical(varargin{k+1});
                    end
                end
            end
        end
    end

    % On garde une copie de l'ancienne bbox si besoin
    oldValue = obj.value; %#ok<NASGU>

    % ------------------------------------------------------------
    % 0) MODE localCrop : val=[xRel yRel w h] dans le repère obj.image
    %    -> recadre obj.image et met à jour obj.value (FOV)
    % ------------------------------------------------------------
    if localCrop
        if ~isnumeric(val) || numel(val) ~= 4
            warning('adjustROISize:InvalidValLocalCrop', ...
                'With localCrop=true, val must have 4 numeric elements [x y w h].');
            return;
        end

        xRel = round(val(1));
        yRel = round(val(2));
        wNew = max(1, round(val(3)));
        hNew = max(1, round(val(4)));

        % charge image si nécessaire
        if isempty(obj.image)
            try
                obj.load;
            catch ME
                warning('adjustROISize:LoadFailed', ...
                    'Failed to load ROI image for localCrop (ROI "%s"): %s', obj.id, ME.message);
            end
        end

        if isempty(obj.image)
            warning('adjustROISize:NoImageForLocalCrop', ...
                'localCrop requested but obj.image is empty (ROI "%s").', obj.id);
            return;
        end

        im = obj.image;
        [hImg, wImg, nC, nT] = size(im);

        % clamp top-left dans l'image
        xRel = max(1, min(xRel, wImg));
        yRel = max(1, min(yRel, hImg));

        % clamp bottom-right
        x2 = min(wImg, xRel + wNew - 1);
        y2 = min(hImg, yRel + hNew - 1);

        % recadre image (toujours indices entiers)
        imCropped = im(yRel:y2, xRel:x2, :, :);
        obj.image = imCropped;

        % mise à jour bbox FOV :
        % obj.value(1:2) est l'origine absolue FOV du patch actuel.
        if isempty(obj.value) || numel(obj.value) < 4
            % fallback cohérent
            obj.value = [1 1 size(imCropped,2) size(imCropped,1)];
        else
            obj.value(1) = obj.value(1) + (xRel - 1);
            obj.value(2) = obj.value(2) + (yRel - 1);
            obj.value(3) = size(imCropped,2);
            obj.value(4) = size(imCropped,1);
        end

        % sécurité entiers
        obj.value(1) = max(1, round(obj.value(1)));
        obj.value(2) = max(1, round(obj.value(2)));
        obj.value(3) = max(1, round(obj.value(3)));
        obj.value(4) = max(1, round(obj.value(4)));

        % appliquer binning si demandé (sur l'image recadrée)
        if ~isempty(binning) && ~isempty(obj.image)
            applyBinningInternal(obj, binning);
        end

        return; % localCrop gère tout
    end

    % ------------------------------------------------------------
    % 1) Comportement historique : update obj.value
    % ------------------------------------------------------------
    centerMode = false;

    switch numel(val)
        case 4
            if val(1) == 0  % change width/height but keep centering
                centerMode = true;
                tmp = obj.value;

                if isempty(tmp) || numel(tmp) < 4
                    tmp = [1 1 val(3) val(4)];
                    if isempty(obj.value) || numel(obj.value) < 4
                        obj.value = tmp;
                    end
                end

                % maj w/h
                obj.value(3:4) = val(3:4);

                % décale x/y pour conserver centre (attention demi-pixels)
                obj.value(1) = obj.value(1) - (val(3) - tmp(3)) / 2;
                obj.value(2) = obj.value(2) - (val(4) - tmp(4)) / 2;

            else
                % bbox absolu FOV
                obj.value = val;
            end

        case 2
            % change position origin (FOV)
            if isempty(obj.value) || numel(obj.value) < 4
                obj.value = [val(1) val(2) 1 1];
            else
                obj.value(1:2) = val;
            end

        otherwise
            warning('adjustROISize:InvalidVal', 'val must have 2 or 4 elements.');
            return;
    end

    % Sécurité : x/y/w/h entiers, w/h>=1, x/y>=1
    if numel(obj.value) >= 4
        obj.value(3) = max(1, round(obj.value(3)));
        obj.value(4) = max(1, round(obj.value(4)));
    end
    if numel(obj.value) >= 2
        obj.value(1) = max(1, round(obj.value(1)));
        obj.value(2) = max(1, round(obj.value(2)));
    end

    % ------------------------------------------------------------
    % 2) Crop effectif de obj.image en mode "centré" uniquement
    % ------------------------------------------------------------
    if centerMode
        if isempty(obj.image)
            try
                obj.load;
            catch ME
                warning('adjustROISize:LoadFailed', ...
                    'Failed to load ROI image in centerMode (ROI "%s"): %s', obj.id, ME.message);
            end
        end

        if ~isempty(obj.image)
            im = obj.image;
            [hImg, wImg, ~, ~] = size(im);

            wNew = obj.value(3);
            hNew = obj.value(4);

            wCrop = min(wNew, wImg);
            hCrop = min(hNew, hImg);

            x = floor((wImg - wCrop)/2) + 1;
            y = floor((hImg - hCrop)/2) + 1;

            x2 = min(x + wCrop - 1, wImg);
            y2 = min(y + hCrop - 1, hImg);

            if x2 >= x && y2 >= y
                obj.image = im(y:y2, x:x2, :, :);
            end
        end
    end

    % ------------------------------------------------------------
    % 3) Binning effectif de obj.image + MÀJ display.binning
    % ------------------------------------------------------------
    if ~isempty(binning)
        if isempty(obj.image)
            try
                obj.load;
            catch ME
                warning('adjustROISize:LoadFailed', ...
                    'Failed to load ROI image for binning (ROI "%s"): %s', obj.id, ME.message);
            end
        end

        if ~isempty(obj.image)
            applyBinningInternal(obj, binning);
        end
    end

end

% =====================================================================
% Helper interne : applique binning + maj display.binning
% =====================================================================
function applyBinningInternal(obj, binning)
    if isempty(binning) || ~isnumeric(binning) || ~isscalar(binning) || binning <= 0
        warning('adjustROISize:InvalidBinning', 'binning must be a scalar > 0. Ignoring.');
        return;
    end

    im = obj.image;
    if isempty(im)
        return;
    end

    [hImg, wImg, nC, nT] = size(im);

    if binning ~= 1
        scale = 1 / binning;

        newH = max(1, round(hImg * scale));
        newW = max(1, round(wImg * scale));

        newIm = zeros(newH, newW, nC, nT, 'like', im);

        for c = 1:nC
            for t = 1:nT
                newIm(:,:,c,t) = imresize(im(:,:,c,t), scale);
            end
        end

        obj.image = newIm;

        % comme l'image change, on met aussi à jour obj.value(3:4) (optionnel mais logique)
        if ~isempty(obj.value) && numel(obj.value) >= 4
            obj.value(3) = size(newIm,2);
            obj.value(4) = size(newIm,1);
        end
    end

    % Mise à jour display.binning
    chNames = {};
    if isfield(obj.display,'channel') && ~isempty(obj.display.channel)
        chNames = obj.display.channel;
        if ischar(chNames)
            chNames = {chNames};
        elseif isstring(chNames)
            chNames = cellstr(chNames);
        end
    end

    nCh = numel(chNames);
    if nCh == 0
        obj.display.binning = binning;
    else
        obj.display.binning = repmat(binning, nCh, 1);
    end
end
