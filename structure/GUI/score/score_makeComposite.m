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
%       .paintChannel   : index du canal indexé courant (pour paint) OU nom
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

% ------------------- unpack param (robuste) -------------------
channel      = param.channel;
overlay      = param.overlay;
levels       = param.levels;
rgb          = param.RGB;
paintChannel = param.paintChannel;
defaultClass = param.defaultClass;

if isfield(param,'weights'), weights = param.weights; else, weights = []; end
if ~isfield(param,'mode') || isempty(param.mode), param.mode = "display"; end
mode = lower(string(param.mode));  % "display", "sequence", "movie"

% -------------------------------------------------------------------------
% 0) REORDONNER LES CANAUX : non indexés d'abord, indexés ensuite
% -------------------------------------------------------------------------
nCh = numel(channel);
isIndexedReq = false(1, nCh);
for k = 1:nCh
    isIndexedReq(k) = iscell(levels{k});
end
order = [find(~isIndexedReq), find(isIndexedReq)];

if ~isequal(order, 1:nCh)
    channel = channel(order);
    levels  = levels(order);
    rgb     = rgb(order);
    if ~isempty(weights)
        weights = weights(order);
    end
end

% garder param cohérent (si réutilisé ailleurs)
param.channel = channel;
param.levels  = levels;
param.RGB     = rgb;
param.weights = weights;

% -------------------------------------------------------------------------
% 1) Prétraitement global (crop, resize, flip, frames)
% -------------------------------------------------------------------------
imtmp = preProcessROI(roitmp, param);   % [H W C F] sur frames=param.frames
[H, W, ~, ~] = size(imtmp);

% Allocation des sorties
if ~overlay
    displayImage = zeros(H, W, 3, numel(channel), 'uint8');  % une image RGB par canal
    comp = [];
else
    displayImage = zeros(H, W, 3, 'uint8');                  % composite
    comp = displayImage;
end

indexedOverlay = zeros(H, W, 3);   % double (0..1)
alphaOverlay   = zeros(H, W);      % double (0..1)
vContours = [];

% -------------------------------------------------------------------------
% 2) Boucle sur les canaux demandés
% -------------------------------------------------------------------------
for ch = 1:numel(channel)

    % --- index(es) du canal réel dans roitmp.image ---
    if iscell(channel)
        currentCha = roitmp.findChannelID(channel{ch});  % peut être vecteur
    else
        currentCha = find(roitmp.channelid == channel(ch)); %#ok<FNDSB>
    end

    if isempty(currentCha)
        continue;
    end

    % HxW (ou HxWxK) à la frame fr
    imraw = imtmp(:, :, currentCha, fr);

    levCh     = levels{ch};
    isIndexed = iscell(levCh);

    % ---------------------------------------------------------------------
    % 2a) Flag log-display (ROBUSTE)
    %  - accepte roitmp.display.log scalaire OU vecteur
    %  - IMPORTANT : indexation sur l'espace "image channel index" (currentCha)
    % ---------------------------------------------------------------------
    logdisplay = false;
    if isprop(roitmp,'display') && isstruct(roitmp.display) && isfield(roitmp.display,'log') ...
            && ~isempty(currentCha)

        lf = roitmp.display.log;
        chaIdx = currentCha(1); % index image (dimension 3)

        if ~isempty(lf)
            if isscalar(lf)
                logdisplay = logical(lf);
            else
                if chaIdx >= 1 && chaIdx <= numel(lf)
                    logdisplay = logical(lf(chaIdx));
                else
                    logdisplay = false;
                end
            end
        end
    end

    % ------------------------------------------------------------------
    % 2b) IMAGE DE FOND pour ce canal
    % ------------------------------------------------------------------
    bg = double(imraw);

    if logdisplay
        bg = log1p(bg);
        bg = bg / log1p(65535);

        if ~iscell(levCh) && ~isequal(levCh, [-1 -1])
            lmin = log1p(double(levCh(1))) / log1p(65535);
            lmax = log1p(double(levCh(2))) / log1p(65535);
            if lmin >= lmax, lmin = lmax - 1e-3; end
            bg = imadjust(bg, [lmin lmax]);
        end
    else
        if ~iscell(levCh) && ~isequal(levCh, [-1 -1])
            lo = levCh(1); hi = levCh(2);
            if lo >= hi, lo = hi - 1; end
            bg16 = uint16(bg);
            bg16 = imadjust(bg16, [lo/65535 hi/65535]);
            bg   = double(bg16) / 65535;
        else
            maxv = max(bg(:));
            if maxv > 0
                bg = bg ./ maxv;
            end
        end
    end

    bg = min(max(bg, 0), 1);

    % ---- conversion en RGB ----
    if ndims(bg) == 2
        gray = bg;

        if logdisplay
            n = 256;
            cmap = parula2green(n);
            idx = 1 + floor(gray*(n-1));
            idx = min(max(idx,1), n);
            bgRGB = ind2rgb(uint16(idx), cmap);
        else
            thisRGB = rgb{ch};
            bgRGB = cat(3, gray*thisRGB(1), gray*thisRGB(2), gray*thisRGB(3));
        end

    elseif ndims(bg) == 3
        if size(bg,3) == 3
            bgRGB = bg;
        else
            gray = mean(bg,3);
            if logdisplay
                n = 256;
                cmap = parula2green(n);
                idx = 1 + floor(gray*(n-1));
                idx = min(max(idx,1), n);
                bgRGB = ind2rgb(uint16(idx), cmap);
            else
                thisRGB = rgb{ch};
                bgRGB = cat(3, gray*thisRGB(1), gray*thisRGB(2), gray*thisRGB(3));
            end
        end
    else
        error('score_makeComposite: imraw dimension inattendue (%dD).', ndims(bg));
    end

    bgRGBu8 = uint8(bgRGB * 255);

    % ---- stockage ----
    if overlay
        if isempty(weights)
            comp = imlincomb(1, comp, 1, bgRGBu8);
        else
            comp = imlincomb(1, comp, weights(ch), bgRGBu8);
        end
    else
        displayImage(:, :, :, ch) = bgRGBu8;
    end

    % ------------------------------------------------------------------
    % 2c) Overlay si canal indexé
    % ------------------------------------------------------------------
    if ~isIndexed
        continue;
    end

    % imraw contient la carte de labels/classes
    % ensure indexed channels are 2D (avoid mask size mismatch)
    if isIndexed && ndims(imraw) > 2
        imraw = imraw(:,:,1);
    end
    L = imadjust(imraw, [0 1]);
    L = double(L);

    indices = str2num(levCh{1}); %#ok<ST2NM>

    % --- mapping sûr vers l'espace "display.*" ---
    % tmpcha : ID "canal" (peut être 10, 12, etc.)
    tmpcha = roitmp.channelid(currentCha(1));

    % dispIdx : index valide pour roitmp.display.* (souvent 1..Ndisplay)
    dispIdx = getDisplayIndex(roitmp, tmpcha, channel, ch);

    % Nom du canal (pour paintChannel par nom)
    thisName = "";
    if isprop(roitmp,'display') && isstruct(roitmp.display) && isfield(roitmp.display,'channel')
        if dispIdx >= 1 && dispIdx <= numel(roitmp.display.channel)
            thisName = string(roitmp.display.channel{dispIdx});
        end
    end

    % liste des canaux indexés (dans l'espace display)
    currentIndx = [];
    if isprop(roitmp,'display') && isstruct(roitmp.display) && isfield(roitmp.display,'indexed') ...
            && ~isempty(roitmp.display.indexed)
        listofindexedcha = find(roitmp.display.indexed); % indices display
        currentIndx = find(listofindexedcha == dispIdx, 1, 'first');
    else
        listofindexedcha = [];
    end

    % Filtre paintChannel
    if ischar(paintChannel) || isstring(paintChannel)
        if strlength(string(paintChannel)) > 0 && ~strcmpi(thisName, string(paintChannel))
            continue;
        end
    else
        if paintChannel ~= 0
            if isempty(currentIndx) || paintChannel ~= currentIndx
                continue;
            end
        end
    end

    % indices par défaut
    if isempty(indices) || (numel(indices)==1 && indices==-1)
        if defaultClass && ~isempty(currentIndx) && ~(paintChannel == currentIndx)
            indices = 2:max(L(:));
        else
            indices = 1:max(L(:));
        end
    end

    % ce canal est-il le canal "paint" ?
    if ischar(paintChannel) || isstring(paintChannel)
        isPaintThis = (strlength(string(paintChannel)) > 0) && strcmpi(thisName, string(paintChannel));
    else
        isPaintThis = (paintChannel ~= 0) && ~isempty(currentIndx) && (paintChannel == currentIndx);
    end

    % couleurs
    if isPaintThis
        levmap = zeros(numel(indices), 3);
        for ii = 1:numel(indices)
            levmap(ii,:) = label2color(indices(ii));
        end
    else
        % fallback si pas de rgb ou index hors limites
        if isprop(roitmp,'display') && isstruct(roitmp.display) && isfield(roitmp.display,'rgb') ...
                && dispIdx >= 1 && dispIdx <= size(roitmp.display.rgb,1)
            levmap = repmat(roitmp.display.rgb(dispIdx,:), [numel(indices), 1]);
        else
            levmap = repmat([1 1 1], [numel(indices), 1]);
        end
    end

    % paramètres overlay
    wid       = levCh{5};
    weiVal    = double(levCh{3});
    fillAlpha = min(1, weiVal);

    switch mode
        case {"sequence","movie"}
            % --- version vectorielle : vContours ---
            for iii = 1:numel(indices)
                bw = (L == indices(iii));
                B  = bwboundaries(bw);
                for kB = 1:numel(B)
                    b = B{kB};
                    patchStruct = struct();
                    patchStruct.x = b(:,2);
                    patchStruct.y = b(:,1);
                    patchStruct.FaceColor = levmap(iii,:);
                    patchStruct.FaceAlpha = fillAlpha;

                    doContour = false;
                    if isprop(roitmp,'display') && isstruct(roitmp.display) && isfield(roitmp.display,'contour') ...
                            && dispIdx >= 1 && dispIdx <= numel(roitmp.display.contour)
                        doContour = (roitmp.display.contour(dispIdx) == 1);
                    end

                    if doContour
                        patchStruct.EdgeColor = levmap(iii,:);
                        patchStruct.LineWidth = wid;
                    else
                        patchStruct.EdgeColor = 'none';
                        patchStruct.LineWidth = [];
                    end

                    vContours = [vContours, patchStruct]; %#ok<AGROW>
                end
            end

        case "display"
            % --- version raster : indexedOverlay + alphaOverlay ---
            for iVal = 1:numel(indices)
                mask = (L == indices(iVal));
                if ~any(mask(:)), continue; end

                for c = 1:3
                    tmp = indexedOverlay(:,:,c);
                    tmp(mask) = levmap(iVal,c);
                    indexedOverlay(:,:,c) = tmp;
                end
                alphaOverlay(mask) = fillAlpha;
            end
    end

end % for ch

% Finalisation du composite si nécessaire
if overlay
    displayImage = comp;
end

end % score_makeComposite

% -------------------------------------------------------------------------
% Helper: map tmpcha (ID canal) -> dispIdx (index sûr pour roitmp.display.*)
% -------------------------------------------------------------------------
function dispIdx = getDisplayIndex(roitmp, tmpcha, channel, ch)

dispIdx = tmpcha; % cas simple si aligné

nDisp = 0;
if isprop(roitmp,'display') && isstruct(roitmp.display) && isfield(roitmp.display,'channel')
    nDisp = numel(roitmp.display.channel);
end
if nDisp <= 0
    return;
end

% OK si déjà dans les bornes
if dispIdx >= 1 && dispIdx <= nDisp
    return;
end

% Fallback par nom si channel est une liste de noms
if iscell(channel)
    reqName = string(channel{ch});
    hit = find(strcmpi(string(roitmp.display.channel), reqName), 1, 'first');
    if ~isempty(hit)
        dispIdx = hit;
        return;
    end
end

% Dernier fallback: borne (évite crash)
dispIdx = min(max(1, dispIdx), nDisp);

end





function imtmp=preProcessROI(roitmp,param)

channel=param.channel;
frames=param.frames;
crop=param.crop;
scalingFactor=param.scalingFactor;
imageSize=param.imageSize;
flip=param.flip;

if isempty(roitmp.image)
    roitmp.load;
elseif ~isempty(roitmp.channelid)
    if size(roitmp.image,3) ~= numel(roitmp.channelid) || max(roitmp.channelid) > size(roitmp.image,3)
        roitmp.load;
    end
end

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



