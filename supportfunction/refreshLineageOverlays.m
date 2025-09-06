function refreshLineageOverlays(graphicsHandles, roiobj, layoutOptions, displayHandles,currentFrames)

if ~isempty(roiobj)
    [~, chName] = getStoredLineageChannel(roiobj(1));
    if ~isempty(chName) && (~isfield(layoutOptions,'channel') || isempty(layoutOptions.channel) ...
            || ~any(strcmp(layoutOptions.channel, char(chName))))
        clearLineageAllTiles(graphicsHandles);
        if isfield(layoutOptions,'debug') && layoutOptions.debug
            warning('Lineage: channel "%s" non présent dans layoutOptions.channel -> overlay désactivé.', char(chName));
        end
        return;
    end
end

% --- toggle global (sans app)
show = true;
if isfield(layoutOptions,'ShowLineageOverlay')
    show = logical(layoutOptions.ShowLineageOverlay);
end
if ~show
    clearLineageAllTiles(graphicsHandles);
    return;
end

if nargin >= 5 && ~isempty(currentFrames)
    framesToDraw = currentFrames(:).';
else
    framesToDraw = layoutOptions.frames;
end
if isempty(framesToDraw), framesToDraw = 1; end



% --- s'assurer que lineageHandles existe
if ~isfield(graphicsHandles,'lineageHandles') || ~isa(graphicsHandles.lineageHandles,'containers.Map')
    graphicsHandles.lineageHandles = containers.Map('KeyType','double','ValueType','any');
end


mode = lower(layoutOptions.mode);
switch mode
    case 'display'
        if isempty(roiobj), return; end
        roi = roiobj(1);
        initOrRefreshLineageForDisplay(graphicsHandles, roi, layoutOptions,framesToDraw);
 

    case 'movie'

        % pour chaque ROI (i,j), maj de la tuile correspondante
        for i = 1:layoutOptions.Nrow
            for j = 1:layoutOptions.Ncol
                roiIndex = (i-1)*layoutOptions.Ncol + j;
                if roiIndex>numel(roiobj), continue; end
                roi = roiobj(roiIndex);
                initOrRefreshLineageForMovieTile(graphicsHandles, roi, layoutOptions, displayHandles, i, j,framesToDraw);
            end
        end

  case 'sequence'
   
    initOrRefreshLineageForSequence(graphicsHandles, roiobj(1), layoutOptions, displayHandles, framesToDraw);




    otherwise
        % 'sequence' : rien à faire
        clearLineageAllTiles(graphicsHandles);
end
end

% ==================== sous-fonctions locales ====================

function clearLineageAllTiles(graphicsHandles)
if isfield(graphicsHandles,'lineageHandles') && isa(graphicsHandles.lineageHandles,'containers.Map')
    ks = graphicsHandles.lineageHandles.keys;
    for t=1:numel(ks)
        L = graphicsHandles.lineageHandles(ks{t});
        if isstruct(L) && isfield(L,'map') && isa(L.map,'containers.Map')
            k2 = L.map.keys;
            for u=1:numel(k2)
                h = L.map(k2{u});
                if isfield(h,'line')  && isgraphics(h.line),  delete(h.line);  end
                if isfield(h,'arrow') && isgraphics(h.arrow), delete(h.arrow); end
            end
        end
    end
    remove(graphicsHandles.lineageHandles, ks);
end
end

function initOrRefreshLineageForDisplay(graphicsHandles, roi, layoutOptions,frm)
tileIdxList = resolveDisplayTileIndices(layoutOptions);
if isempty(tileIdxList), return; end

pix = resolvePixWithoutApp(roi, layoutOptions);
if isempty(pix), return; end

col = resolveLineageColor(roi, layoutOptions);   % <<< NOUVEAU

% Frame courante = layoutOptions.frames (déjà mis à jour par score_updateRender)
%frm = layoutOptions.frames;

for t = tileIdxList
    axOverlay = [];
    if isKey(graphicsHandles.overlayHandles, t)
        hOverlayImg = graphicsHandles.overlayHandles(t);
        if isgraphics(hOverlayImg), axOverlay = ancestor(hOverlayImg,'axes'); end
    end
    if isempty(axOverlay) && isKey(graphicsHandles.imgHandles, t)
        hImg = graphicsHandles.imgHandles(t);
        if isgraphics(hImg), axOverlay = ancestor(hImg,'axes'); end
    end
    if isempty(axOverlay) || ~isgraphics(axOverlay), continue; end
    drawOrUpdateLineageOnAxes(graphicsHandles, t, axOverlay, roi, pix, frm,col); % <<< frame passée ici
end
end

function initOrRefreshLineageForMovieTile(graphicsHandles, roi, layoutOptions, displayHandles, i, j,frm)
tileIdxList = resolveMovieTileIndices(layoutOptions, displayHandles, i, j);
if isempty(tileIdxList), return; end

pix = resolvePixWithoutApp(roi, layoutOptions);
if isempty(pix), return; end

col = resolveLineageColor(roi, layoutOptions);   % <<< NOUVEAU

%frm = layoutOptions.frames  % frame courante du movie

for t = tileIdxList
    axOverlay = [];
    if isKey(graphicsHandles.overlayHandles, t)
        hOverlayImg = graphicsHandles.overlayHandles(t);
        if isgraphics(hOverlayImg), axOverlay = ancestor(hOverlayImg,'axes'); end
    end
    if isempty(axOverlay) && isKey(graphicsHandles.imgHandles, t)
        hImg = graphicsHandles.imgHandles(t);
        if isgraphics(hImg), axOverlay = ancestor(hImg,'axes'); end
    end
    if isempty(axOverlay) || ~isgraphics(axOverlay), continue; end
    drawOrUpdateLineageOnAxes(graphicsHandles, t, axOverlay, roi, pix, frm,col); % <<< frame passée ici
end
end


function initOrRefreshLineageForSequence(graphicsHandles, roiobj, layoutOptions, displayHandles, framesSeq)

ROI_rows = displayHandles.ROI_rows;
ROI_cols = displayHandles.ROI_cols;

for i = 1:layoutOptions.Nrow
    for j = 1:layoutOptions.Ncol
        roiIndex = (i-1)*layoutOptions.Ncol + j;
        if roiIndex>numel(roiobj), continue; end
        roi = roiobj(roiIndex);

        col = resolveLineageColor(roi, layoutOptions);
        pix = resolvePixWithoutApp(roi, layoutOptions);
        if isempty(pix), continue; end

        ROI_row_offset = (i-1) * ROI_rows;
        ROI_col_offset = (j-1) * ROI_cols;

        if layoutOptions.overlay
            for fIdx = 1:numel(framesSeq)
                frm = framesSeq(fIdx);
                local_row = 1;
                local_col = (fIdx-1)*layoutOptions.Nbrick + 1;
                global_row = ROI_row_offset + local_row;
                global_col = ROI_col_offset + local_col;
                tileIndex  = (global_row-1)*displayHandles.MasterCols + global_col;

                ax = getTileAxesFromHandles(graphicsHandles, tileIndex);
                if isempty(ax) || ~isgraphics(ax), continue; end

                drawOrUpdateLineageOnAxes(graphicsHandles, tileIndex, ax, roi, pix, frm, col);
            end
        else
            for ch = 1:layoutOptions.Nchannel
                for fIdx = 1:numel(framesSeq)
                    frm = framesSeq(fIdx);
                    local_row = (ch-1)*layoutOptions.Nbrick + 1;
                    local_col = (fIdx-1)*layoutOptions.Nbrick + 1;
                    global_row = ROI_row_offset + local_row;
                    global_col = ROI_col_offset + local_col;
                    tileIndex  = (global_row-1)*displayHandles.MasterCols + global_col;

                    ax = getTileAxesFromHandles(graphicsHandles, tileIndex);
                    if isempty(ax) || ~isgraphics(ax), continue; end

                    drawOrUpdateLineageOnAxes(graphicsHandles, tileIndex, ax, roi, pix, frm, col);
                end
            end
        end
    end
end
end



function tileIdxList = resolveDisplayTileIndices(layoutOptions)
% display/overlay=true  => tuile 1
% display/overlay=false => tuiles 1, 1+Nbrick, 1+2*Nbrick, ...
if ~strcmpi(layoutOptions.mode,'display'), tileIdxList = []; return; end
if layoutOptions.overlay
    tileIdxList = 1;
else
    tileIdxList = arrayfun(@(ch) (ch-1)*layoutOptions.Nbrick + 1, 1:layoutOptions.Nchannel);
end
end

function tileIdxList = resolveMovieTileIndices(layoutOptions, displayHandles, i, j)
ROI_row_offset = (i-1) * (layoutOptions.Nbrick + layoutOptions.Ndataseries);
if layoutOptions.overlay
    ROI_col_offset = (j-1) * layoutOptions.Nbrick;
    global_row = ROI_row_offset + 1;
    global_col = ROI_col_offset + 1;
    tileIdxList = (global_row-1)*displayHandles.MasterCols + global_col;
else
    ROI_col_offset = (j-1) * (layoutOptions.Nchannel * layoutOptions.Nbrick);
    tileIdxList = zeros(1, layoutOptions.Nchannel);
    for ch=1:layoutOptions.Nchannel
        global_row = ROI_row_offset + 1;
        global_col = ROI_col_offset + (ch-1)*layoutOptions.Nbrick + 1;
        tileIdxList(ch) = (global_row-1)*displayHandles.MasterCols + global_col;
    end
end
end

function pix = resolvePixWithoutApp(roi, layoutOptions)
% 1) priorité au canal enregistré dans cell_information.userData

% 0) si un channel de lignage est stocké mais n'est PAS dans la liste à afficher -> on ne trace pas
[pixStored0, nameStored0] = getStoredLineageChannel(roi);
if ~isempty(nameStored0) && isfield(layoutOptions,'channel') && ~isempty(layoutOptions.channel)
    try
        % nameStored0 peut être string => cast en char pour strcmp
        if ~any(strcmp(layoutOptions.channel, char(nameStored0)))
            pix = [];    % pas de correspondance => retour prématuré
            return;
        end
    catch
        pix = [];
        return;
    end
end

[pixStored, nameStored] = getStoredLineageChannel(roi);

% Si on a un nom stocké et qu'il est toujours présent -> on résout son pix
if ~isempty(nameStored)
    try
        pix = roi.findChannelID(char(nameStored));
        if ~isempty(pix) && isfinite(pix), return; end
    catch
        % tombe sur le fallback
    end
end

% Sinon, si on a un pix stocké encore cohérent (borne simple)
if ~isempty(pixStored) && isfinite(pixStored) && pixStored>=1 && pixStored<=size(roi.image,3)
    pix = pixStored; 
    return;
end

% 2) fallback: premier canal affiché côté ROI
pix = [];
try
    if isprop(roi,'display') && isfield(roi.display,'channel') && ~isempty(roi.display.channel)
        pix = roi.findChannelID(roi.display.channel{1});
        if ~isempty(pix), return; end
    end
catch
end

% 3) fallback ultime: layoutOptions.channel{1}
try
    if isfield(layoutOptions,'channel') && ~isempty(layoutOptions.channel)
        pix = roi.findChannelID(layoutOptions.channel{1});
    end
catch
    pix = [];
end
end


function drawOrUpdateLineageOnAxes(graphicsHandles, tileIndex, ax, roi, pix, frm,col)
M = roi.image(:,:,pix,frm);
if isempty(M), return; end

pairs = getLineagePairsForFrame_ROI(roi, M);  % Nx2 [daughter,mother]

% conteneur de cette tuile
if isKey(graphicsHandles.lineageHandles, tileIndex)
    L = graphicsHandles.lineageHandles(tileIndex);
else
    L = struct('map',containers.Map('KeyType','int32','ValueType','any'),'ax',ax);
end

% axes recréé ?
if ~isempty(L.ax) && ~isequal(L.ax, ax)
    purgeLineageMap(L.map);
    L.map = containers.Map('KeyType','int32','ValueType','any');
    L.ax  = ax;
end

% ==== PROTECTION CONTRE L'EFFACEMENT ====
% on gèle les limites et on empêche 'line'/'quiver' d'effacer l'image overlay
oldXLim = get(ax,'XLim');
oldYLim = get(ax,'YLim');
oldXMode = get(ax,'XLimMode');
oldYMode = get(ax,'YLimMode');
oldNP   = get(ax,'NextPlot');

set(ax,'XLimMode','manual','YLimMode','manual','NextPlot','add');

alive = int32([]);

for i=1:size(pairs,1)
    d = int32(pairs(i,1));
    m = double(pairs(i,2));
    [xd, yd] = fastCentroidSingle(M, double(d));
    [xm, ym] = fastCentroidSingle(M, double(m));
    if isnan(xd) || isnan(yd) || isnan(xm) || isnan(ym), continue; end

    alive(end+1) = d; %#ok<AGROW>
   % col = [1 1 1]; % ou label2color(m)

    if isKey(L.map, d)
        h = L.map(d);
        if isgraphics(h.line)
            set(h.line, 'XData',[xm xd], 'YData',[ym yd], 'Visible','on', 'Color',col, 'LineWidth',1.5);
        end
        if isgraphics(h.arrow)
            set(h.arrow,'XData',xm,'YData',ym,'UData',(xd-xm)*0.9,'VData',(yd-ym)*0.9, ...
                'Visible','on','Color',col,'LineWidth',1.0,'MaxHeadSize',0.5,'AutoScale','off');
        end
        h.motherID = m;
        L.map(d) = h;
    else
        hLine  = line(ax, [xm xd], [ym yd], 'Color', col, 'LineWidth', 1.5, ...
                      'HitTest','off','PickableParts','none');
        hArrow = quiver(ax, xm, ym, (xd-xm)*0.9, (yd-ym)*0.9, 0, ...
                        'LineWidth',1.0,'MaxHeadSize',0.5,'Color',col, ...
                        'HitTest','off','PickableParts','none','AutoScale','off');
        L.map(d) = struct('line',hLine,'arrow',hArrow,'motherID',m);
    end
end

% masquer ce qui n'est plus présent
ks = L.map.keys;
for i=1:numel(ks)
    d = int32(ks{i});
    if ~ismember(d, alive)
        h = L.map(d);
        if isgraphics(h.line),  set(h.line, 'Visible','off'); end
        if isgraphics(h.arrow), set(h.arrow,'Visible','off'); end
    end
end

% ==== RESTAURE L'ÉTAT DE L'AXES ====
set(ax,'XLim',oldXLim,'YLim',oldYLim,'XLimMode',oldXMode,'YLimMode',oldYMode,'NextPlot',oldNP);

graphicsHandles.lineageHandles(tileIndex) = L;
end


function purgeLineageMap(map)
if ~isa(map,'containers.Map'), return; end
ks = map.keys;
for i=1:numel(ks)
    h = map(ks{i});
    if isfield(h,'line')  && isgraphics(h.line),  delete(h.line);  end
    if isfield(h,'arrow') && isgraphics(h.arrow), delete(h.arrow); end
end
end

function pairs = getLineagePairsForFrame_ROI(roi, maskFrame)
pairs = [];
idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data),1,'first');
if isempty(idx), return; end
ds = roi.data(idx);
if ~isprop(ds,'userData') || ~isstruct(ds.userData) || ~isfield(ds.userData,'motherOf'), return; end
Mmap = ds.userData.motherOf;
if ~isa(Mmap,'containers.Map') || Mmap.Count==0, return; end

present = unique(maskFrame(:)); present(present==0) = [];
present = int32(present(:)');

keysD = Mmap.keys;
for k=1:numel(keysD)
    d = int32(keysD{k});
    if ismember(d, present)
        m = Mmap(d);
        if isfinite(m) && m>0
            pairs(end+1,:) = [double(d), double(m)]; %#ok<AGROW>
        end
    end
end
end

function [xc,yc] = fastCentroidSingle(maskFrame, id)
pix = (maskFrame == id);
if ~any(pix(:)), xc = NaN; yc = NaN; return; end
s = regionprops(pix,'Centroid');
if isempty(s), xc = NaN; yc = NaN;
else,          xc = s(1).Centroid(1); yc = s(1).Centroid(2);
end
end


function [pix, name] = getStoredLineageChannel(roi)
% Lit le canal stocké; renvoie [] si introuvable/invalide
pix  = [];
name = [];
idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data),1,'first');
if isempty(idx), return; end
ds = roi.data(idx);
if ~isprop(ds,'userData') || ~isstruct(ds.userData), return; end

if isfield(ds.userData,'lineageChannelName') && ~isempty(ds.userData.lineageChannelName)
    name = string(ds.userData.lineageChannelName);
end
if isfield(ds.userData,'lineageChannelPix') && ~isempty(ds.userData.lineageChannelPix)
    pix = double(ds.userData.lineageChannelPix);
end
end

function col = resolveLineageColor(roi, layoutOptions)
% Retourne la couleur complémentaire (1 - baseRGB) du channel utilisé pour le lineage.
% baseRGB est pris dans layoutOptions.RGB{idx} où idx est l'index du channel dans layoutOptions.channel.

% 1) retrouver le nom du channel de lineage
[~, nameStored] = getStoredLineageChannel(roi);  % déjà implémenté chez toi
idx = [];

if ~isempty(nameStored) && isfield(layoutOptions,'channel') && ~isempty(layoutOptions.channel)
    try
        idx = find(strcmp(layoutOptions.channel, char(nameStored)), 1, 'first');
    catch
        idx = [];
    end
end

% 2) lire la couleur de base dans layoutOptions.RGB
base = [1 1 1]; % fallback (blanc) si introuvable
if ~isempty(idx) && isfield(layoutOptions,'RGB') && numel(layoutOptions.RGB) >= idx
    try
        v = layoutOptions.RGB{idx};
        if isnumeric(v) && numel(v)==3
            base = double(v(:)).';  % [r g b]
        end
    catch
        % garder base = blanc
    end
end

% 3) couleur complémentaire
col = 1 - base;

% 4) petits garde-fous visuels (optionnel)
col = max(min(col,1),0);
if mean(col) < 0.15
    col = min(col + 0.15, 1); % évite trop sombre
end
end

function ax = getTileAxesFromHandles(graphicsHandles, tileIndex)
% Tente d'abord l'overlay image ; sinon retombe sur l'axe de l'image.
ax = [];

% 1) overlay
if isfield(graphicsHandles,'overlayHandles') && isa(graphicsHandles.overlayHandles,'containers.Map') ...
   && isKey(graphicsHandles.overlayHandles, tileIndex)
    hOv = graphicsHandles.overlayHandles(tileIndex);
    if ~isempty(hOv) && all(isgraphics(hOv))
        try
            ax = ancestor(hOv(1), 'axes');  % hOv peut être un array, prendre le 1er
        catch
            ax = [];
        end
    end
end

% 2) image (fallback)
if isempty(ax) && isfield(graphicsHandles,'imgHandles') && isa(graphicsHandles.imgHandles,'containers.Map') ...
   && isKey(graphicsHandles.imgHandles, tileIndex)
    hIm = graphicsHandles.imgHandles(tileIndex);
    if ~isempty(hIm) && all(isgraphics(hIm))
        try
            % hIm peut contenir plusieurs objets (image, texte, etc.)
            % On cherche explicitement un objet de type 'image'
            if numel(hIm) > 1
                % Sélectionne le premier handle de type 'image'
                isImg = arrayfun(@(h) strcmp(get(h,'Type'),'image'), hIm);
                if any(isImg)
                    ax = ancestor(hIm(find(isImg,1,'first')), 'axes');
                else
                    % fallback : parent du 1er handle
                    ax = ancestor(hIm(1), 'axes');
                end
            else
                ax = ancestor(hIm, 'axes');
            end
        catch
            ax = [];
        end
    end
end
end



