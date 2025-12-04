
function [displayImage, vContours, indexedOverlay, alphaOverlay] = score_makeComposite(roitmp, fr, param)
% SCORE_MAKECOMPOSITE
% - Construit l'image de fond (displayImage)
% - Construit éventuellement :
%       * vContours (vectoriel)    pour 'Sequence' / 'Movie'
%       * indexedOverlay/alphaOverlay (raster) pour 'Display'
%
% Entrées :
%   roitmp : objet ROI avec champs .image (H x W x C x F) et .display
%   fr    : index de frame (dans param.frames)
%   param : struct avec champs (min nécessaire) :
%       .channel        : noms ou ids de canaux à afficher (1..Ndisplay)
%       .overlay        : bool, composite (=true) ou multi-canaux (=false)
%       .levels         : cell, par canal : 
%                            - [min max] ou [-1 -1] (intensité)
%                            - {idxString, ...}      (canal indexé)
%       .RGB            : cell 1xNdisplay, chaque = [r g b]
%       .weights        : (optionnel) poids pour composite overlay
%       .paintChannel   : index du canal indexé courant (pour paint)
%       .defaultClass   : bool pour le comportement indices = -1
%       .mode           : "Display" | "Sequence" | "Movie"
%
% Sorties :
%   displayImage : 
%       - overlay=false : [H W 3 Ndisplay] uint8
%       - overlay=true  : [H W 3] uint8 (composite)
%   vContours    : struct array de patchs (x, y, FaceColor, EdgeColor, ...)
%   indexedOverlay : [H W 3] double (0..1) pour l'overlay raster
%   alphaOverlay   : [H W] double (0..1) alpha pour l'overlay raster

channel      = param.channel;
overlay      = param.overlay;
levels       = param.levels;
rgb          = param.RGB;
weights      = param.weights;
paintChannel = param.paintChannel;
defaultClass = param.defaultClass;
mode         = string(param.mode);  % "Display", "Sequence", "Movie"

% -------------------------------------------------------------------------
% 0) REORDONNER LES CANAUX : non indexés d'abord, indexés ensuite
% -------------------------------------------------------------------------
nCh = numel(channel);
isIndexed = false(1, nCh);
for k = 1:nCh
    isIndexed(k) = iscell(levels{k});
end
order = [find(~isIndexed), find(isIndexed)];

if ~isequal(order, 1:nCh)
    % canal peut être numeric ou cell, les deux marchent
    channel = channel(order);
    levels  = levels(order);
    rgb     = rgb(order);
    if ~isempty(weights)
        weights = weights(order);
    end
end

% Mettre à jour param pour qu'il reste cohérent si besoin ailleurs
param.channel = channel;
param.levels  = levels;
param.RGB     = rgb;
param.weights = weights;

% -------------------------------------------------------------------------
% 1) Prétraitement global (crop, resize, flip, frames)
% -------------------------------------------------------------------------
imtmp = preProcessROI(roitmp, param);     % [H W C F]
[H, W, ~, ~] = size(imtmp);

% Allocation des sorties
if ~overlay
    % multi-canaux : une image RGB par canal
    displayImage = zeros(H, W, 3, numel(channel), 'uint8');
    comp = [];  % inutilisé
else
    % composite : une seule image RGB
    displayImage = zeros(H, W, 3, 'uint8');
    comp = displayImage;
end

indexedOverlay = zeros(H, W, 3);   % double (0..1)
alphaOverlay   = zeros(H, W);      % double (0..1)

vContours = [];

% -------------------------------------------------------------------------
% 2) Boucle sur les canaux demandés
% -------------------------------------------------------------------------
for ch = 1:numel(channel)

    % --- trouver l'index du canal réel dans roitmp.image ---
    if iscell(channel)
        currentCha = roitmp.findChannelID(channel{ch});
    else
        pix = find(roitmp.channelid == channel(ch));
        currentCha = pix;
    end

    if isempty(currentCha)
        % canal inexistant : on saute, displayImage reste à 0 pour ce ch
        continue;
    end

    % HxW ou HxWxK (si canal multi-sous-canaux) à la frame fr
    imraw = imtmp(:, :, currentCha, fr);

    % Flag canal indexé (labels) ?
    levCh     = levels{ch};
    isIndexed = iscell(levCh);

    % Flag log-display ?
    logdisplay = false;
    if isprop(roitmp, 'display') && isfield(roitmp.display, 'log') ...
            && numel(roitmp.display.log) >= currentCha ...
            && roitmp.display.log(currentCha)
        logdisplay = true;
    end

    % ------------------------------------------------------------------
    % 2a) IMAGE DE FOND pour ce canal (bgRGB in [0..255]), 
    %     indépendamment du fait qu'il soit indexé ou non.
    % ------------------------------------------------------------------
    bg = double(imraw);

    if logdisplay
        % ---- Cas log comme dans ton code d'origine ----
        bg = log1p(bg);
        bg = bg / log1p(65535);

        % niveaux en log si levCh numérique
        if ~iscell(levCh) && ~isequal(levCh, [-1 -1])
            lmin = log1p(double(levCh(1))) / log1p(65535);
            lmax = log1p(double(levCh(2))) / log1p(65535);
            if lmin >= lmax
                lmin = lmax - 1e-3;
            end
            bg = imadjust(bg, [lmin lmax]);
        end

    else
        % ---- Cas linéaire ----
        if ~iscell(levCh) && ~isequal(levCh, [-1 -1])
            lo = levCh(1);
            hi = levCh(2);
            if lo >= hi
                lo = hi - 1;
            end
            bg16 = uint16(bg);  % imadjust aime bien du 16-bit dans ce contexte
            bg16 = imadjust(bg16, [lo/65535 hi/65535]);
            bg   = double(bg16) / 65535;
        else
            % pas de niveaux définis -> normalisation simple
            maxv = max(bg(:));
            if maxv > 0
                bg = bg ./ maxv;
            end
        end
    end

    % clamp [0..1]
    bg = min(max(bg, 0), 1);

    % ---- convertir en RGB 3 canaux ----
    if ndims(bg) == 2
        gray     = bg;
        thisRGB  = rgb{ch};                   % [r g b]
        bgRGB    = cat(3, gray*thisRGB(1), gray*thisRGB(2), gray*thisRGB(3));
    elseif ndims(bg) == 3
        if size(bg, 3) == 3
            % déjà RGB (rare mais on gère)
            bgRGB = bg;
        else
            % multi-sous-canaux exotique -> moyenne puis colorisation
            gray = mean(bg, 3);
            thisRGB = rgb{ch};
            bgRGB   = cat(3, gray*thisRGB(1), gray*thisRGB(2), gray*thisRGB(3));
        end
    else
        error('score_makeComposite: imraw dimension inattendue (%dD).', ndims(bg));
    end

    bgRGBu8 = uint8(bgRGB * 255);

    % ---- stocker dans displayImage ou composite ----
    if overlay
        % Composite : accumulation dans comp
        if isempty(weights)
            comp = imlincomb(1, comp, 1, bgRGBu8);
        else
            comp = imlincomb(1, comp, weights(ch), bgRGBu8);
        end
    else
        % Multi-canaux : une image par canal
        displayImage(:, :, :, ch) = bgRGBu8;
    end

    % ------------------------------------------------------------------
    % 2b) Si canal indexé -> génération d'overlay (vContours OU raster)
    % ------------------------------------------------------------------
    if isIndexed
        % imraw contient la carte de labels / classes
        L = imadjust(imraw, [0 1]);    % comme ton code d'origine
        L = double(L);

        % indices à utiliser
        indices = str2num(levCh{1}); %#ok<ST2NM>

        % liste des canaux indexés
        listofindexedcha = find(roitmp.display.indexed);
        tmpcha           = roitmp.channelid(currentCha);
        currentIndx      = find(listofindexedcha == tmpcha);

        if (paintChannel ~= currentIndx) && paintChannel ~= 0
            % en mode "paint" on peut ignorer certains canaux
            continue;
        end

        if isempty(indices) || (numel(indices)==1 && indices==-1)
            if defaultClass && (paintChannel ~= currentIndx)
                indices = 2:max(L(:));
            else
                indices = 1:max(L(:));
            end
        end

        if paintChannel == currentIndx
            % couleurs stables par ID
            levmap = zeros(numel(indices), 3);
            for ii = 1:numel(indices)
                levmap(ii,:) = label2color(indices(ii));
            end
        else
            levmap = repmat(roitmp.display.rgb(tmpcha,:), [numel(indices), 1]);
        end

        wid      = levCh{5};
        weiVal   = double(levCh{3});
        fillAlpha = min(1, weiVal);

        switch mode
            case ["Sequence","Movie"]
                % --- Version vectorielle : vContours ---
                for iii = 1:numel(indices)
                    bw = (L == indices(iii));
                    B  = bwboundaries(bw);
                    for kB = 1:length(B)
                        b = B{kB};
                        patchStruct = struct();
                        patchStruct.x = b(:,2);
                        patchStruct.y = b(:,1);
                        patchStruct.FaceColor = levmap(iii,:);
                        patchStruct.FaceAlpha = fillAlpha;
                        if roitmp.display.contour(tmpcha) == 1
                            patchStruct.EdgeColor = levmap(iii,:);
                            patchStruct.LineWidth = wid;
                        else
                            patchStruct.EdgeColor = 'none';
                            patchStruct.LineWidth = [];
                        end
                        vContours = [vContours, patchStruct];
                    end
                end

            case "Display"
                % --- Version raster : indexedOverlay + alphaOverlay ---
                for iVal = 1:numel(indices)
                    mask = (L == indices(iVal));

                    if ~any(mask(:)), continue; end

                    for c = 1:3
                        channelOverlay = indexedOverlay(:, :, c);
                        channelOverlay(mask) = levmap(iVal, c);
                        indexedOverlay(:, :, c) = channelOverlay;
                    end

                    alphaOverlay(mask) = fillAlpha;
                end
        end
    end

end % for ch

% Finalisation du composite si nécessaire
if overlay
    displayImage = comp;
end

end




function imtmp=preProcessROI(roitmp,param)

channel=param.channel;
frames=param.frames;
crop=param.crop;
scalingFactor=param.scalingFactor;
imageSize=param.imageSize;
flip=param.flip;

if isempty(roitmp.image), roitmp.load; end

%disp(['ROI ' roitmp.id ' is loaded']);

% Recalculer les indices de canaux pour cette ROI
currentCha = cell(1, numel(channel));
for j = 1:numel(channel)
    if iscell(channel)
        currentCha{j} = roitmp.findChannelID(channel{j});
    else
        pix = find(roitmp.channelid == channel(j));
        currentCha{j} = pix;
    end
end

% preprocess images

imtmp = roitmp.image(:,:,:,frames);
if ~isempty(crop)
    for c = 1:size(imtmp,3)
        for f = 1:size(imtmp,4)
            imtmptp(:,:,c,f) = imcrop(imtmp(:,:,c,f), crop);
        end
    end
    imtmp = imtmptp;
end

if scalingFactor~=1
    imtmp = imresize(imtmp, scalingFactor, 'nearest');
end

if ~isempty(imageSize)
    imtmp = imresize(imtmp, imageSize);
end

if flip==1
    imtmp = flip(imtmp,1);
end
end


function cmap = parula2green(n)
% Crée une colormap de type parula, mais dont la couleur max est verte

% Génère un colormap progressif de bleu -> rouge -> vert
% Bleu (faible), rouge (milieu), vert (fort)

    if nargin < 1
        n = 256;
    end

    % Points de contrôle : bleu, rouge, vert
    colors = [ ...
        0     0     1   ;  % bleu
        1     0     0   ;  % rouge
        0     1     0 ];   % vert

    % Interpolation sur n points
    x = linspace(0, 1, size(colors, 1));      % 3 points
    xi = linspace(0, 1, n);                   % n points

    cmap = interp1(x, colors, xi, 'linear');
end

function cmap = getPalette(n)
% Palette qualitative de 16 couleurs bien distinctes, sans gris clair.
% Remplacement du gris (0.498,0.498,0.498) par un or vif (1.000,0.835,0.000).

base = [ ...
    0.121 0.466 0.705;  % bleu
    1.000 0.498 0.054;  % orange
    0.172 0.627 0.172;  % vert
    0.839 0.152 0.156;  % rouge
    0.580 0.404 0.741;  % violet
    0.549 0.337 0.294;  % brun
    0.890 0.466 0.760;  % rose
    1.000 0.835 0.000;  % OR vif (remplace le gris)
    0.737 0.741 0.133;  % olive
    0.090 0.745 0.811;  % cyan
    0.650 0.810 0.890;  % bleu clair
    1.000 0.733 0.470;  % orange clair
    0.596 0.874 0.541;  % vert clair
    1.000 0.596 0.588;  % rouge clair
    0.770 0.690 0.835;  % violet clair
    0.900 0.770 0.580]; % beige/tan

if n <= size(base,1)
    cmap = base(1:n,:);
else
    reps = ceil(n/size(base,1));
    cmap = repmat(base, reps, 1);
    cmap = cmap(1:n, :);
end
end


function col = label2color(id)
pal = getPalette(16);
idx = 1 + mod(max(1,round(id))-1, size(pal,1));
col = pal(idx,:);
end

function rgb = mask2rgb_stable(L)
L = double(L);
[H,W] = size(L);
rgb = zeros(H,W,3,'double');
ids = unique(L); ids(ids==0) = [];
for id = ids(:).'
    c = label2color(id);
    m = (L==id);
    rgb(:,:,1) = rgb(:,:,1) + m.*c(1);
    rgb(:,:,2) = rgb(:,:,2) + m.*c(2);
    rgb(:,:,3) = rgb(:,:,3) + m.*c(3);
end
end



