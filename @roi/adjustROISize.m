function adjustROISize(obj, val, varargin)
% change the ROI array (bbox) and, si possible, recadre / bin l'image
%
% val must be : [ x y width height ]  (ou [x y], pour déplacer l'origine)
% Optionnel :
%   adjustROISize(obj, val, binning)
%       -> binning : facteur de downsampling spatial (>0)
%
% Cas particuliers :
%   - numel(val)==4, val(1)==0 => change width/height en gardant le centre
%   - numel(val)==2           => change seulement l'origine

    % ---- argument optionnel : binning ----
    binning = [];
    if ~isempty(varargin)
        binning = varargin{1};
    end

    % On garde une copie de l'ancienne bbox si besoin
    oldValue = obj.value;

    % Flag : redimensionnement "centré" (cas [0 0 w h])
    centerMode = false;

    % ---- MàJ de obj.value exactement comme avant ----
    switch numel(val)
        case 4
            if val(1)==0 % change width and height but keep centering
                centerMode = true;
                tmp = obj.value;

                % si obj.value est vide, on initialise
                if isempty(tmp) || numel(tmp)<4
                    tmp = [1 1 val(3) val(4)];
                end

                obj.value(3:4) = val(3:4);

                obj.value(1) = obj.value(1) - (val(3) - tmp(3))/2;
                obj.value(2) = obj.value(2) - (val(4) - tmp(4))/2;

            else
                obj.value = val;
            end
        case 2
            % change position origin
            if isempty(obj.value) || numel(obj.value)<4
                obj.value = [val(1) val(2) 1 1];
            else
                obj.value(1:2) = val;
            end
        otherwise
            warning('adjustROISize:InvalidVal',...
                'val must have 2 or 4 elements.');
            return;
    end

    % Sécurité : width/height >= 1
    if numel(obj.value) >= 4
        obj.value(3) = max(1, round(obj.value(3)));
        obj.value(4) = max(1, round(obj.value(4)));
    end

    % ---------------------------------------------------------------------
    % 1) CROP EFFECTIF DE obj.image (si chargée) EN MODE "CENTRÉ"
    % ---------------------------------------------------------------------
    % Attention :
    %  - On n'essaie de recadrer que dans le cas centerMode (val(1)==0),
    %    ce qui correspond bien au cas "harmoniser la taille en gardant
    %    le centre de la cellule à peu près au même endroit".
    %  - Pour les autres cas (déplacement absolu de l'origine), il faudrait
    %    recharger l'image depuis la FOV complète pour être parfaitement
    %    cohérent. Ici on laisse obj.image telle quelle.
    %
    if centerMode && ~isempty(obj.image)
        im = obj.image;
        [hImg, wImg, nC, nT] = size(im);

        wNew = obj.value(3);
        hNew = obj.value(4);

        % Si on demande plus grand que ce qu'on a, on se limite à l'image
        wCrop = min(wNew, wImg);
        hCrop = min(hNew, hImg);

        % coordonnées du crop centré dans l'image actuelle (en pixels ROI)
        x = floor((wImg - wCrop)/2) + 1;
        y = floor((hImg - hCrop)/2) + 1;

        x2 = min(x + wCrop - 1, wImg);
        y2 = min(y + hCrop - 1, hImg);

        if x2 > x && y2 > y
            im = im(y:y2, x:x2, :, :);
            obj.image = im;
        end
        % NB: obj.value reste en coordonnées "globales" (FOV) ;
        % ici on modifie uniquement le contenu de l'image déjà extraite.
    end

    % ---------------------------------------------------------------------
    % 2) BINNING EFFECTIF DE obj.image + MÀJ display.binning
    % ---------------------------------------------------------------------
    if ~isempty(binning) && ~isempty(obj.image)
        if binning <= 0
            warning('adjustROISize:InvalidBinning',...
                'binning must be > 0. Ignoring.');
        else
            im = obj.image;
            [hImg, wImg, nC, nT] = size(im);

            if binning ~= 1
                scale = 1 / binning;

                newIm = zeros(max(1,round(hImg*scale)), ...
                              max(1,round(wImg*scale)), ...
                              nC, nT, ...
                              'like', im);

                for c = 1:nC
                    for t = 1:nT
                        newIm(:,:,c,t) = imresize(im(:,:,c,t), scale);
                    end
                end

                obj.image = newIm;
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
    end

end
