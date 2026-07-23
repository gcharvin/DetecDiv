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
requestedFrameIdx = fr;
actualFrame = requestedFrameIdx;
if isfield(param, 'frames') && ~isempty(param.frames)
    boundedFrameIdx = max(1, min(numel(param.frames), requestedFrameIdx));
    actualFrame = param.frames(boundedFrameIdx);
end
if isfield(param, 'colorMode'), colorMode = param.colorMode; else, colorMode = repmat({'rgb'}, 1, numel(channel)); end
if isfield(param, 'colormapName'), colormapName = param.colormapName; else, colormapName = repmat({''}, 1, numel(channel)); end

if isfield(param,'weights'), weights = param.weights; else, weights = []; end
if ~isfield(param,'mode') || isempty(param.mode), param.mode = "display"; end
mode = lower(string(param.mode));  % "display", "sequence", "movie"

% -------------------------------------------------------------------------
% 0) REORDONNER LES CANAUX : non indexés d'abord, indexés ensuite
% -------------------------------------------------------------------------
nCh = numel(channel);
colorMode = localPadCell(colorMode, nCh, 'rgb');
colormapName = localPadCell(colormapName, nCh, '');
if numel(rgb) < nCh
    rgb(end+1:nCh) = repmat({[1 1 1]}, 1, nCh - numel(rgb));
end
if ~isempty(weights) && numel(weights) < nCh
    weights(end+1:nCh) = 1;
end
isIndexedReq = false(1, nCh);
for k = 1:nCh
    isIndexedReq(k) = iscell(levels{k});
end
order = [find(~isIndexedReq), find(isIndexedReq)];

if ~isequal(order, 1:nCh)
    channel = channel(order);
    levels  = levels(order);
    rgb     = rgb(order);
    colorMode = colorMode(order);
    colormapName = colormapName(order);
    if ~isempty(weights)
        weights = weights(order);
    end
end

% garder param cohérent (si réutilisé ailleurs)
param.channel = channel;
param.levels  = levels;
param.RGB     = rgb;
param.colorMode = colorMode;
param.colormapName = colormapName;
param.weights = weights;

% -------------------------------------------------------------------------
% 1) Prétraitement global (crop, resize, flip, frames)
% -------------------------------------------------------------------------
[imtmp, fr] = preProcessROI(roitmp, param, fr);   % [H W C 1], fr is local after preprocessing
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

    if isIndexed
        bgRGBu8 = [];
    else
    logdisplay = localChannelFlag(param, 'log', ch, false);

    % ------------------------------------------------------------------
    % 2b) IMAGE DE FOND pour ce canal
    % ------------------------------------------------------------------
    bg = normalizeIntensityImageForDisplay(imraw);

    if logdisplay
        bg = log1p(bg);
        bg = bg / log1p(65535);

        if ~iscell(levCh) && ~isequal(levCh, [-1 -1])
            lmin = log1p(double(levCh(1))) / log1p(65535);
            lmax = log1p(double(levCh(2))) / log1p(65535);
            if lmin >= lmax, lmin = lmax - 1e-3; end
            bg = adjustIntensityImage(bg, [lmin lmax]);
        end
    else
        if ~iscell(levCh) && ~isequal(levCh, [-1 -1])
            lo = levCh(1); hi = levCh(2);
            if lo >= hi, lo = hi - 1; end
            bg16 = uint16(max(0, min(65535, bg)));
            bg16 = adjustIntensityImage(bg16, [lo/65535 hi/65535]);
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

        bgRGB = localColorizeGray(gray, rgb{ch}, colorMode, colormapName, ch);

    elseif ndims(bg) == 3
        if size(bg,3) == 3
            bgRGB = bg;
        else
            gray = mean(bg,3);
            bgRGB = localColorizeGray(gray, rgb{ch}, colorMode, colormapName, ch);
        end
    else
        error('score_makeComposite: imraw dimension inattendue (%dD).', ndims(bg));
    end

    bgRGBu8 = uint8(bgRGB * 255);
    end

    % ---- stockage ----
    if ~isIndexed
        if overlay
            if isempty(weights)
                comp = imlincomb(1, comp, 1, bgRGBu8);
            else
                comp = imlincomb(1, comp, weights(ch), bgRGBu8);
            end
        else
            displayImage(:, :, :, ch) = bgRGBu8;
        end
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
    L = double(imraw);

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

    objectCfg = localObjectDisplayConfig(param, thisName);
    if ~isempty(objectCfg)
        providerName = char(string(objectCfg.maskProvider));
        try
            [resolvedProvider, ~, ~] = ...
                score_resolveMaskProvider(roitmp, thisName);
            if ~isempty(resolvedProvider), providerName = resolvedProvider; end
        catch
        end
        if ~any(strcmp(providerName, {'','<family default>'})) && ...
                ~strcmpi(providerName, thisName)
            try
                providerPix = roitmp.findChannelID(providerName);
                if ~isempty(providerPix) && providerPix(1) <= size(imtmp, 3)
                    L = double(imtmp(:,:,providerPix(1),fr));
                end
            catch
                % Keep the displayed channel as the safe provider fallback.
            end
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

    % indices par défaut
    presentLabels = unique(L(:));
    presentLabels = presentLabels(isfinite(presentLabels) & presentLabels > 0);
    presentLabels = presentLabels(:).';

    if isempty(indices) || (numel(indices)==1 && indices==-1)
        maxLabel = max([presentLabels 0]);
        if shouldHideIndexedBackgroundClass(defaultClass, currentIndx, paintChannel, thisName)
            if maxLabel <= 1
                indices = presentLabels;
            else
                indices = presentLabels(presentLabels ~= 1);
            end
        else
            indices = presentLabels;
        end
    else
        indices = intersect(double(indices(:).'), presentLabels, 'stable');
    end

    % ce canal est-il le canal "paint" ?
    if ischar(paintChannel) || isstring(paintChannel)
        isPaintThis = (strlength(string(paintChannel)) > 0) && strcmpi(thisName, string(paintChannel));
    else
        isPaintThis = any(paintChannel ~= 0) && ~isempty(currentIndx) && any(paintChannel == currentIndx);
    end

    % Color strategy is independent from editability. The legacy paint
    % channel remains a compatibility fallback for old callers.
    renderMode = 'normal';
    if isPaintThis
        renderMode = 'edit';
    elseif ~isempty(objectCfg)
        renderMode = lower(char(string(objectCfg.mode)));
    end

    colorStrategy = 'single';
    criterion = 'Channel color';
    if ~isempty(objectCfg)
        criterion = char(string(objectCfg.criterion));
    end
    if strcmp(renderMode, 'edit')
        colorStrategy = 'label';
    elseif strcmp(renderMode, 'multicolor')
        if strcmpi(criterion, 'Frame instance')
            colorStrategy = 'label';
        else
            colorStrategy = 'mapped';
        end
    elseif strcmp(renderMode, 'semantic')
        if strcmpi(criterion, 'Frame instance')
            colorStrategy = 'label';
        elseif any(strcmpi(criterion, {'Track','New bud','Cell state'}))
            colorStrategy = 'mapped';
        end
    end
    useLabelColors = strcmp(colorStrategy, 'label');

    if useLabelColors
        levmap = zeros(numel(indices), 3);
        for ii = 1:numel(indices)
            levmap(ii,:) = label2color(indices(ii));
        end
    else
        baseColor = localChannelColor(roitmp, dispIdx);
        if ~isempty(objectCfg) && strcmp(renderMode, 'semantic') && ...
                any(strcmpi(objectCfg.criterion, {'Family','New bud','Cell state'}))
            baseColor = localModelFamilyColor( ...
                roitmp, objectCfg, thisName, objectCfg.familyColor);
        end
        levmap = repmat(baseColor, [numel(indices), 1]);
        if strcmp(colorStrategy, 'mapped')
            [modelColors, modelHandled] = localModelLabelColors( ...
                roitmp, objectCfg, thisName, actualFrame, indices, baseColor, criterion);
            if modelHandled
                levmap = modelColors;
            elseif strcmpi(criterion, 'Track')
                for ii = 1:numel(indices)
                    levmap(ii,:) = label2color(indices(ii));
                end
            elseif strcmpi(criterion, 'New bud')
                newBudIds = localNewBudIds(roitmp, objectCfg, thisName, actualFrame);
                for ii = 1:numel(indices)
                    if any(double(newBudIds) == double(indices(ii)))
                        levmap(ii,:) = objectCfg.semanticColor;
                    end
                end
            end
        end
    end

    % paramètres overlay
    wid       = localScalarNumber(levCh{5}, 1);
    weiVal    = localScalarNumber(levCh{3}, 1);
    fillAlpha = min(1, max(0, weiVal));

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
            if isempty(indices)
                continue;
            end
            if useLabelColors
                [indexedOverlay, alphaOverlay] = compositeLabelColorOverlay( ...
                    indexedOverlay, alphaOverlay, L, indices, fillAlpha);
            elseif strcmp(colorStrategy, 'mapped')
                [indexedOverlay, alphaOverlay] = compositePerLabelColorOverlay( ...
                    indexedOverlay, alphaOverlay, L, indices, levmap, fillAlpha);
            else
                mask = ismember(L, indices);
                if any(mask(:))
                    [indexedOverlay, alphaOverlay] = compositeOverlayLayer( ...
                        indexedOverlay, alphaOverlay, mask, levmap(1,:), fillAlpha);
                end
            end
    end

end % for ch

% Finalisation du composite si nécessaire
if overlay
    displayImage = comp;
end

end % score_makeComposite

% -------------------------------------------------------------------------
% Helpers
% -------------------------------------------------------------------------
function img = normalizeIntensityImageForDisplay(img)
img = double(img);

if ndims(img) <= 2
    return;
end

if size(img, 3) == 1
    img = img(:, :, 1);
elseif size(img, 3) ~= 3
    img = max(img, [], 3);
end
end

function [rgbOut, alphaOut] = compositeOverlayLayer(rgbIn, alphaIn, mask, color, alpha)
% Composite one semi-transparent annotation layer onto an accumulated RGBA.
% This preserves overlapping annotation channels instead of letting the
% last channel overwrite the color/alpha of previous channels.

rgbOut = rgbIn;
alphaOut = alphaIn;

alpha = min(1, max(0, double(alpha)));
if alpha <= 0 || ~any(mask(:))
    return;
end

color = double(color(:)');
if numel(color) ~= 3
    color = [1 1 1];
end
color = min(1, max(0, color));

oldAlpha = alphaOut(mask);
newAlpha = alpha + oldAlpha .* (1 - alpha);
safeAlpha = max(newAlpha, eps);

for c = 1:3
    plane = rgbOut(:,:,c);
    oldColor = plane(mask);
    plane(mask) = (color(c) .* alpha + oldColor .* oldAlpha .* (1 - alpha)) ./ safeAlpha;
    rgbOut(:,:,c) = plane;
end

alphaOut(mask) = newAlpha;
end

function [rgbOut, alphaOut] = compositeLabelColorOverlay(rgbIn, alphaIn, L, indices, alpha)
% Vectorized equivalent of applying label2color(id) to every selected label.
rgbOut = rgbIn;
alphaOut = alphaIn;

alpha = min(1, max(0, double(alpha)));
if alpha <= 0 || isempty(indices)
    return;
end

mask = ismember(L, indices);
if ~any(mask(:))
    return;
end

pal = getPalette(16);
labelValues = round(double(L(mask)));
labelValues(~isfinite(labelValues) | labelValues < 1) = 1;
colorIdx = 1 + mod(labelValues - 1, size(pal,1));

oldAlpha = alphaOut(mask);
newAlpha = alpha + oldAlpha .* (1 - alpha);
safeAlpha = max(newAlpha, eps);

for c = 1:3
    plane = rgbOut(:,:,c);
    oldColor = plane(mask);
    newColor = pal(colorIdx, c);
    plane(mask) = (newColor .* alpha + oldColor .* oldAlpha .* (1 - alpha)) ./ safeAlpha;
    rgbOut(:,:,c) = plane;
end

alphaOut(mask) = newAlpha;
end

function [rgbOut, alphaOut] = compositePerLabelColorOverlay(rgbIn, alphaIn, L, indices, colors, alpha)
rgbOut = rgbIn;
alphaOut = alphaIn;
for i = 1:numel(indices)
    mask = (L == indices(i));
    if any(mask(:))
        [rgbOut, alphaOut] = compositeOverlayLayer( ...
            rgbOut, alphaOut, mask, colors(i,:), alpha);
    end
end
end

function img = adjustIntensityImage(img, lims)
if ndims(img) <= 2 || size(img, 3) == 1
    img = imadjust(img(:, :, 1), lims);
    return;
end

if size(img, 3) ~= 3
    img = imadjust(max(img, [], 3), lims);
    return;
end

for k = 1:3
    img(:, :, k) = imadjust(img(:, :, k), lims);
end
end

function value = localChannelFlag(param, fieldName, ch, defaultValue)
value = defaultValue;
if ~isfield(param, fieldName) || isempty(param.(fieldName))
    return;
end

flags = param.(fieldName);
try
    if isscalar(flags)
        value = logical(flags);
    elseif ch >= 1 && ch <= numel(flags)
        value = logical(flags(ch));
    end
catch
    value = defaultValue;
end
end

function value = localScalarNumber(raw, defaultValue)
value = defaultValue;
try
    if ischar(raw) || isstring(raw)
        parsed = str2double(raw);
    else
        parsed = double(raw);
    end
    if ~isempty(parsed)
        parsed = parsed(1);
    end
    if isfinite(parsed)
        value = parsed;
    end
catch
    value = defaultValue;
end
end

function values = localPadCell(values, n, defaultValue)
if isempty(values)
    values = repmat({defaultValue}, 1, n);
elseif isstring(values)
    values = cellstr(values(:).');
elseif ischar(values)
    values = {values};
elseif ~iscell(values)
    values = repmat({defaultValue}, 1, n);
end
if numel(values) < n
    values(end+1:n) = {defaultValue};
elseif numel(values) > n
    values = values(1:n);
end
end

function bgRGB = localColorizeGray(gray, rgb, colorMode, colormapName, ch)
mode = 'rgb';
if ch <= numel(colorMode) && ~isempty(colorMode{ch})
    mode = lower(strtrim(char(string(colorMode{ch}))));
end

if strcmp(mode, 'colormap')
    cmapName = 'parula';
    if ch <= numel(colormapName) && strlength(string(colormapName{ch})) > 0
        cmapName = char(string(colormapName{ch}));
    end
    cmap = score_colormapFromName(cmapName, 256);
    idx = 1 + floor(min(max(gray, 0), 1) * (size(cmap, 1) - 1));
    idx = min(max(idx, 1), size(cmap, 1));
    bgRGB = ind2rgb(idx, cmap);
else
    thisRGB = min(max(double(rgb), 0), 1);
    bgRGB = cat(3, gray*thisRGB(1), gray*thisRGB(2), gray*thisRGB(3));
end
end

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

function tf = shouldHideIndexedBackgroundClass(defaultClass, currentIndx, paintChannel, channelName)
tf = false;
try
    isPaintThis = false;
    if ischar(paintChannel) || isstring(paintChannel)
        isPaintThis = strlength(string(paintChannel)) > 0 && strcmpi(string(channelName), string(paintChannel));
    else
        isPaintThis = any(paintChannel ~= 0) && ~isempty(currentIndx) && any(paintChannel == currentIndx);
    end
    if isPaintThis
        return;
    end

    % Let the UI checkbox decide whether label 1 is background. Classifier
    % result channels may legitimately use object id 1 for a real cell.
    tf = logical(defaultClass);
catch
    tf = logical(defaultClass);
end
end

function cfg = localObjectDisplayConfig(param, channelName)
cfg = [];
try
    if ~isfield(param, 'objectDisplay') || isempty(param.objectDisplay) || ...
            ~isstruct(param.objectDisplay)
        return;
    end
    names = string({param.objectDisplay.channelName});
    hit = find(strcmpi(names, string(channelName)), 1, 'first');
    if ~isempty(hit)
        cfg = param.objectDisplay(hit);
    end
catch
    cfg = [];
end
end

function color = localChannelColor(roiobj, dispIdx)
color = [1 1 1];
try
    if isprop(roiobj,'display') && isstruct(roiobj.display) && ...
            isfield(roiobj.display,'rgb') && dispIdx >= 1 && ...
            dispIdx <= size(roiobj.display.rgb,1)
        color = double(roiobj.display.rgb(dispIdx,:));
    end
catch
end
color = max(0, min(1, color(:).'));
end

function color = localModelFamilyColor(roiobj, cfg, channelName, fallback)
color = fallback;
try
    [model, status] = score_getCellModel(roiobj);
    if ~strcmp(status, 'ok'), return; end
    [familyIndex, ~] = score_resolveCellModelFamily(model, cfg, channelName);
    if ~isempty(familyIndex)
        color = double(model.families.color_rgb(familyIndex,:)) ./ 255;
    end
catch
end
color = max(0, min(1, double(color(:).')));
end

function ids = localNewBudIds(roiobj, cfg, channelName, frame)
ids = [];
try
    idx = find(arrayfun(@(x) isprop(x,'groupid') && ...
        strcmp(char(string(x.groupid)), 'cell_information'), roiobj.data), 1, 'first');
    if isempty(idx) || ~isstruct(roiobj.data(idx).userData)
        return;
    end
    ud = roiobj.data(idx).userData;
    if ~isfield(ud, 'lineageSources') || ~isstruct(ud.lineageSources)
        return;
    end
    sourceKey = char(string(cfg.lineageSource));
    if any(strcmp(sourceKey, {'<family default>','<none>',''}))
        sourceKey = '';
        fields = fieldnames(ud.lineageSources);
        for i = 1:numel(fields)
            candidate = ud.lineageSources.(fields{i});
            if isfield(candidate, 'channelName') && ...
                    strcmp(string(candidate.channelName), string(channelName))
                sourceKey = fields{i};
                break;
            end
        end
        if isempty(sourceKey) && isfield(ud, 'activeLineageSource')
            sourceKey = char(string(ud.activeLineageSource));
        end
    end
    if isempty(sourceKey) || ~isfield(ud.lineageSources, sourceKey)
        return;
    end
    source = ud.lineageSources.(sourceKey);
    if ~isfield(source, 'events') || isempty(source.events)
        return;
    end
    for i = 1:numel(source.events)
        event = source.events(i);
        if isfield(event, 'startFrame') && isfield(event, 'childId') && ...
                double(event.startFrame) == double(frame)
            ids(end+1) = double(event.childId); %#ok<AGROW>
        end
    end
    ids = unique(ids);
catch
    ids = [];
end
end

function [colors, handled] = localModelLabelColors( ...
        roiobj, cfg, channelName, frame, labels, baseColor, criterion)
colors = repmat(baseColor, numel(labels), 1);
handled = false;
try
    [model, status] = score_getCellModel(roiobj);
    if ~strcmp(status, 'ok')
        return;
    end
    [familyIndex, familyId] = score_resolveCellModelFamily( ...
        model, cfg, channelName);
    if isempty(familyIndex)
        return;
    end

    rows = find(model.instances.family_id == familyId & ...
        model.instances.frame == uint32(frame));
    frameLabels = double(model.instances.mask_label(rows));
    handled = true;
    if strcmpi(criterion, 'Track')
        for i = 1:numel(labels)
            hit = find(frameLabels == double(labels(i)), 1, 'first');
            if isempty(hit), continue; end
            trackId = model.instances.track_id(rows(hit));
            if trackId > 0
                colors(i,:) = label2color(double(trackId));
            else
                colors(i,:) = label2color(labels(i));
            end
        end
    elseif strcmpi(criterion, 'Cell state')
        for i = 1:numel(labels)
            hit = find(frameLabels == double(labels(i)), 1, 'first');
            if isempty(hit), continue; end
            stateId = model.instances.state_id(rows(hit));
            stateRow = find(model.states.state_id == stateId, 1, 'first');
            if ~isempty(stateRow)
                colors(i,:) = double(model.states.color_rgb(stateRow,:)) ./ 255;
            end
        end
    elseif strcmpi(criterion, 'New bud')
        relationRows = find(model.relations.family_id == familyId & ...
            model.relations.event_frame == uint32(frame));
        childTracks = model.relations.child_track_id(relationRows);
        for i = 1:numel(labels)
            hit = find(frameLabels == double(labels(i)), 1, 'first');
            if isempty(hit), continue; end
            if any(childTracks == model.instances.track_id(rows(hit)))
                colors(i,:) = cfg.semanticColor;
            end
        end
    else
        handled = false;
    end
catch
    handled = false;
end
end





function [imtmp, localFrameIdx]=preProcessROI(roitmp,param,requestedFrameIdx)

channel=param.channel;
frames=param.frames;
crop=param.crop;
scalingFactor=param.scalingFactor;
imageSize=param.imageSize;
flip=param.flip;
localFrameIdx = 1;

if isempty(roitmp.image)
    score_loadChannelsForDisplay(roitmp, channel);
elseif ~isempty(roitmp.channelid)
    if size(roitmp.image,3) ~= numel(roitmp.channelid) || max(roitmp.channelid) > size(roitmp.image,3)
        score_loadChannelsForDisplay(roitmp, channel);
    end
end

%disp(['ROI ' roitmp.id ' is loaded']);

% preprocess only the requested displayed frame; levels/histograms are
% computed upstream and do not require copying the full stack here.
if isempty(frames)
    frames = 1:size(roitmp.image, 4);
end
requestedFrameIdx = max(1, min(numel(frames), requestedFrameIdx));
frameToRender = frames(requestedFrameIdx);
frameToRender = max(1, min(size(roitmp.image, 4), frameToRender));

imtmp = roitmp.image(:,:,:,frameToRender);
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



