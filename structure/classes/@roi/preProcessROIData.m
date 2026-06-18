function im = preProcessROIData(obj, ch, fr, dorepmat)
% preProcessROIData  Construit une image (optionnellement RGB) normalisée [0..1]
% à partir des sous-canaux ch (indices de obj.image) et de la frame fr.
%
% - Canaux "grayscale" (display.indexed == 0 pour le canal logique correspondant) :
%       normalisation par stretchlim + imadjust sur 16 bits (comme avant).
% - Canaux "indexés" (display.indexed == 1) :
%       PAS d'imadjust ; normalisation simple en supposant un codage 8 bits
%       dans un uint16 (0..255 typiquement).

    perFrames = 0;          % comportement historique
    satur     = [0.001 0.999];

    if nargin < 4 || isempty(dorepmat)
        dorepmat = 1;
    end

    if isempty(ch)
        im = [];
        return;
    end

    % ---------------------------------------------------------------------
    % Extraction brute des sous-canaux demandés
    % obj.image : [H W Nsub T]
    % ch        : indices de sous-canaux (1..Nsub)
    % ---------------------------------------------------------------------
    tmp = obj.image(:,:,ch,fr);   % tmp : [H W numel(ch)]

    [H,W,nCh] = size(tmp);

    imout = zeros(H, W, nCh);

    % ---------------------------------------------------------------------
    % Préparation des infos display : stretchlim (par sous-canal)
    % et indexed (par canal logique)
    % ---------------------------------------------------------------------
    hasStretch  = isfield(obj.display,'stretchlim') || isprop(obj.display,'stretchlim');
    needCompute = 0;

    hasIndexed = isfield(obj.display,'indexed');
    if hasIndexed
        idxFlag = obj.display.indexed(:);   % vecteur [NchannelsLogiques x 1]
    else
        idxFlag = [];                       % tout traité comme grayscale
    end

    channelid = [];
    if isprop(obj,'channelid')
        channelid = obj.channelid(:);       % [Nsub x 1] map sous-canal -> canal logique
    end

    % ---------------------------------------------------------------------
    % Assurer que stretchlim est disponible pour les sous-canaux GRAYSCALE
    % (pas nécessaire pour les canaux indexés)
    % ---------------------------------------------------------------------
    if perFrames == 0
        if ~hasStretch || size(obj.display.stretchlim,2) ~= numel(obj.channelid)
            needCompute = 1;
        else
            % On ne vérifie les stretch que pour les sous-canaux NON indexés
            for i = 1:nCh
                subIdx = ch(i);  % indice de sous-canal

                if subIdx > size(obj.display.stretchlim,2)
                    needCompute = 1;
                    break;
                end

                % Canal logique associé à ce sous-canal
                isIdx = false;
                if ~isempty(channelid)
                    if subIdx <= numel(channelid)
                        logicalId = channelid(subIdx);  % 1..Nchannels logiques
                        if logicalId >= 1 && logicalId <= numel(idxFlag)
                            isIdx = (idxFlag(logicalId) == 1);
                        end
                    end
                end

                % Si ce sous-canal n'est pas indexé et que son stretchlim est nul,
                % il faut recomputer.
                if ~isIdx && obj.display.stretchlim(2,subIdx) == 0
                    needCompute = 1;
                    break;
                end
            end
        end

        if needCompute
            % disp(['No stretch limits found for ROI ' num2str(obj.id) ', computing them...']);
            obj.computeStretchlim;
        end
    end

    % ---------------------------------------------------------------------
    % Boucle sur les sous-canaux sélectionnés
    % ---------------------------------------------------------------------
    for i = 1:nCh
        plane  = tmp(:,:,i);    % i-ème sous-canal dans tmp
        subIdx = ch(i);         % indice de sous-canal dans obj.image / stretchlim

        % Déterminer le canal logique correspondant et s'il est indexé
        isIdx = false;
        if ~isempty(channelid) && subIdx <= numel(channelid)
            logicalId = channelid(subIdx);  % 1..Nchannels logiques
            if logicalId >= 1 && logicalId <= numel(idxFlag)
                isIdx = (idxFlag(logicalId) == 1);
            end
        end

        if isIdx
            % -------- Canal INDEXÉ 8 bits stocké en uint16 --------
            % On NE fait PAS d'imadjust.
            % On suppose que l'information utile est principalement dans [0..255].
            planeD = double(plane);
            maxVal = max(planeD(:));
            if maxVal <= 0
                planeN = zeros(size(planeD));
            else
                denom  = max(255, maxVal);  % garde les écarts de labels si max<=255
                planeN = planeD / denom;
            end
        else
            % -------- Canal GRAYSCALE 16 bits (ou autre) --------
            if perFrames == 0
                % stretchlim indexé par sous-canal
                strchlm = obj.display.stretchlim(:, subIdx);
            else
                strchlm = stretchlim(plane, satur);
            end

            if numel(strchlm) < 2 || any(~isfinite(strchlm(:))) || strchlm(1) >= strchlm(2)
                strchlm = stretchlim(plane, satur);
            end

            if numel(strchlm) < 2 || any(~isfinite(strchlm(:))) || strchlm(1) >= strchlm(2)
                planeAdj = plane;
            else
                planeAdj = imadjust(plane, strchlm);
            end

            if isempty(planeAdj)
                planeAdj = plane;
            end

            if isa(plane, 'uint16')
                planeN = double(planeAdj) / double(intmax('uint16')); % 65535
            else
                % fallback générique
                maxVal = max(double(planeAdj(:)), [], 'omitnan');
                if isempty(maxVal) || ~isfinite(maxVal)
                    maxVal = 0;
                else
                    maxVal = maxVal(1);
                end
                if maxVal <= 0
                    planeN = zeros(size(planeAdj));
                else
                    planeN = double(planeAdj) ./ maxVal;
                end
            end
        end

        % Clamp [0..1]
        planeN = max(0, min(1, planeN));

        imout(:,:,i) = planeN;
    end

    % ---------------------------------------------------------------------
    % Mapping des nCh sous-canaux normalisés vers une image finale RGB
    % ---------------------------------------------------------------------
    switch nCh
        case 1
           % if dorepmat == 1
                % 1 sous-canal -> R=G=B
                im = repmat(imout, [1 1 3]);
                
          %  else
          %      im = imout;
          %  end

        case 2
            % 2 sous-canaux -> R=1, G=2, B=0
            im = zeros(H, W, 3);
            im(:,:,1) = imout(:,:,1);
            im(:,:,2) = imout(:,:,2);
            im(:,:,3) = 0;

        case 3
            % 3 sous-canaux -> RGB direct
            im = imout;

        otherwise
            % >3 sous-canaux : on garde les 3 premiers, on avertit
            im = imout(:,:,1:3);
            disp('preProcessROIData: This image has more than 3 channels; only the first 3 are used for RGB.');
    end
end
