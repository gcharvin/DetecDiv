function refreshLineageOverlays(graphicsHandles, roiobj, layoutOptions, displayHandles,currentFrames)

if ~hasAnyVisibleLineageSource(roiobj)
    clearLineageAllTiles(graphicsHandles);
    return;
end

if ~isempty(roiobj)
    chNames = getVisibleLineageChannelNames(roiobj(1));
    if ~isempty(chNames) && isfield(layoutOptions,'channel') && ~isempty(layoutOptions.channel) ...
            && ~any(ismember(cellstr(chNames), cellstr(string(layoutOptions.channel))))
        clearLineageAllTiles(graphicsHandles);
        if isfield(layoutOptions,'debug') && layoutOptions.debug
            warning('Lineage: no visible lineage channel is present in layoutOptions.channel -> overlay disabled.');
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
   
    initOrRefreshLineageForSequence(graphicsHandles, roiobj, layoutOptions, displayHandles, framesToDraw);




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
                if isfield(h,'line')  && ~isempty(h.line)  && isgraphics(h.line),  delete(h.line);  end
                if isfield(h,'arrow') && ~isempty(h.arrow) && isgraphics(h.arrow), delete(h.arrow); end
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
geoms = getLineageGeometriesForFrame_ROI(roi, pix, frm, col);

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

for i=1:numel(geoms)
    d = int32(geoms(i).mapKey);
    m = double(geoms(i).motherID);
    xd = geoms(i).xd;
    yd = geoms(i).yd;
    xm = geoms(i).xm;
    ym = geoms(i).ym;
    lineColor = geoms(i).color;

    alive(end+1) = d; %#ok<AGROW>

    if isKey(L.map, d)
        h = L.map(d);
        if isgraphics(h.line)
            set(h.line, 'XData',[xm xd], 'YData',[ym yd], 'Visible','on', 'Color',lineColor, 'LineWidth',1.5);
        end
        if isgraphics(h.arrow)
            set(h.arrow,'XData',xm,'YData',ym,'UData',(xd-xm)*0.9,'VData',(yd-ym)*0.9, ...
                'Visible','on','Color',lineColor,'LineWidth',1.0,'MaxHeadSize',0.5,'AutoScale','off');
        end

        try
    if isgraphics(h.line),  uistack(h.line,  'top'); end
    if isgraphics(h.arrow), uistack(h.arrow, 'top'); end
catch
end

        h.motherID = m;
        h.daughterID = geoms(i).daughterID;
        h.sourceKey = geoms(i).sourceKey;
        L.map(d) = h;
    else
        hLine  = line(ax, [xm xd], [ym yd], 'Color', lineColor, 'LineWidth', 1.5, ...
                      'HitTest','off','PickableParts','none');
        hArrow = quiver(ax, xm, ym, (xd-xm)*0.9, (yd-ym)*0.9, 0, ...
                        'LineWidth',1.0,'MaxHeadSize',0.5,'Color',lineColor, ...
                        'HitTest','off','PickableParts','none','AutoScale','off');
        L.map(d) = struct('line',hLine,'arrow',hArrow,'motherID',m, ...
            'daughterID',geoms(i).daughterID,'sourceKey',geoms(i).sourceKey);

        try
    uistack(hLine,  'top');
    uistack(hArrow, 'top');
catch
        end






        
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
    if isfield(h,'line')  && ~isempty(h.line)  && isgraphics(h.line),  delete(h.line);  end
    if isfield(h,'arrow') && ~isempty(h.arrow) && isgraphics(h.arrow), delete(h.arrow); end
end
end

function geoms = getLineageGeometriesForFrame_ROI(roi, fallbackPix, frm, fallbackColor)
geoms = struct('mapKey',{},'daughterID',{},'motherID',{},'xd',{},'yd',{},'xm',{},'ym',{},'color',{},'sourceKey',{});
idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data),1,'first');
if isempty(idx), return; end
ds = roi.data(idx);
if ~isprop(ds,'userData') || ~isstruct(ds.userData), return; end

sources = getVisibleLineageSources(ds);
if isempty(sources)
    return;
end

for s = 1:numel(sources)
    pix = fallbackPix;
    if strlength(sources(s).channelName) > 0
        pixForSource = resolvePixForChannelName(roi, sources(s).channelName);
        if ~isempty(pixForSource)
            pix = pixForSource;
        end
    end
    if isempty(pix) || pix < 1 || pix > size(roi.image,3) || frm < 1 || frm > size(roi.image,4)
        continue;
    end
    M = roi.image(:,:,pix,frm);
    if isempty(M), continue; end

    present = unique(M(:));
    present(present==0) = [];
    present = int32(present(:)');

    keysD = sources(s).motherOf.keys;
    for k = 1:numel(keysD)
        daughterID = int32(keysD{k});
        if ~ismember(daughterID, present)
            continue;
        end
        motherID = double(sources(s).motherOf(daughterID));
        if ~isfinite(motherID) || motherID <= 0 || ~ismember(int32(motherID), present)
            continue;
        end
        [xd, yd] = fastCentroidSingle(M, double(daughterID));
        [xm, ym] = fastCentroidSingle(M, double(motherID));
        if isnan(xd) || isnan(yd) || isnan(xm) || isnan(ym)
            continue;
        end
        geoms(end+1) = struct( ... %#ok<AGROW>
            'mapKey', lineageMapKey(s, daughterID), ...
            'daughterID', daughterID, ...
            'motherID', motherID, ...
            'xd', xd, 'yd', yd, 'xm', xm, 'ym', ym, ...
            'color', fallbackColor, ...
            'sourceKey', char(sources(s).key));
    end
end
end

function pix = resolvePixForChannelName(roi, channelName)
pix = [];
try
    if isprop(roi,'display') && isfield(roi.display,'channel') && ~isempty(roi.display.channel)
        idx = find(strcmp(cellstr(string(roi.display.channel)), char(channelName)), 1, 'first');
        if ~isempty(idx)
            pix = roi.findChannelID(roi.display.channel{idx});
            if isempty(pix) && idx <= size(roi.image,3)
                pix = idx;
            end
        end
    end
catch
    pix = [];
end
end

function mapKey = lineageMapKey(sourceIndex, daughterID)
mapKey = int32(sourceIndex * 1000000 + double(daughterID));
end

function sources = getVisibleLineageSources(ds)
sources = struct('key',{},'motherOf',{},'channelName',{});
if isfield(ds.userData,'lineageSources') && isstruct(ds.userData.lineageSources) && ...
        ~isempty(fieldnames(ds.userData.lineageSources))
    sourceKeys = fieldnames(ds.userData.lineageSources);
    for i = 1:numel(sourceKeys)
        src = ds.userData.lineageSources.(sourceKeys{i});
        show = false;
        try
            if isfield(src, 'show')
                show = logical(src.show);
            end
        catch
            show = false;
        end
        if ~show || ~isfield(src, 'motherOf') || ~isa(src.motherOf, 'containers.Map') || src.motherOf.Count == 0
            continue;
        end
        channelName = "";
        if isfield(src,'channelName') && ~isempty(src.channelName)
            channelName = string(src.channelName);
        end
        sources(end+1) = struct('key',string(sourceKeys{i}), ...
            'motherOf',src.motherOf, ...
            'channelName',channelName); %#ok<AGROW>
    end
    return;
end

if isfield(ds.userData,'motherOf') && isa(ds.userData.motherOf,'containers.Map') && ds.userData.motherOf.Count > 0
    channelName = "";
    if isfield(ds.userData,'lineageChannelName') && ~isempty(ds.userData.lineageChannelName)
        channelName = string(ds.userData.lineageChannelName);
    end
    sources = struct('key',"legacy",'motherOf',ds.userData.motherOf,'channelName',channelName);
end
end

function pairs = getLineagePairsForFrame_ROI(roi, maskFrame)
pairs = [];
idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data),1,'first');
if isempty(idx), return; end
ds = roi.data(idx);
if ~isprop(ds,'userData') || ~isstruct(ds.userData), return; end

present = unique(maskFrame(:)); present(present==0) = [];
present = int32(present(:)');

maps = getVisibleLineageMaps(ds);
for s = 1:numel(maps)
    Mmap = maps{s};
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
end

function maps = getVisibleLineageMaps(ds)
maps = {};
if ~isprop(ds,'userData') || ~isstruct(ds.userData)
    return;
end

if isfield(ds.userData,'lineageSources') && isstruct(ds.userData.lineageSources) && ...
        ~isempty(fieldnames(ds.userData.lineageSources))
    sourceKeys = fieldnames(ds.userData.lineageSources);
    for i = 1:numel(sourceKeys)
        src = ds.userData.lineageSources.(sourceKeys{i});
        show = false;
        try
            if isfield(src, 'show')
                show = logical(src.show);
            end
        catch
            show = false;
        end
        if ~show || ~isfield(src, 'motherOf') || ~isa(src.motherOf, 'containers.Map') || src.motherOf.Count == 0
            continue;
        end
        maps{end+1} = src.motherOf; %#ok<AGROW>
    end
    return;
end

if isfield(ds.userData,'motherOf') && isa(ds.userData.motherOf,'containers.Map') && ds.userData.motherOf.Count > 0
    maps = {ds.userData.motherOf};
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

visibleNames = getVisibleLineageChannelNames(roi);
if ~isempty(visibleNames)
    name = string(visibleNames(1));
    return;
end

if isfield(ds.userData,'lineageSources') && isstruct(ds.userData.lineageSources) && ...
        ~isempty(fieldnames(ds.userData.lineageSources))
    return;
end

if isfield(ds.userData,'lineageChannelName') && ~isempty(ds.userData.lineageChannelName)
    name = string(ds.userData.lineageChannelName);
end
if isfield(ds.userData,'lineageChannelPix') && ~isempty(ds.userData.lineageChannelPix)
    pix = double(ds.userData.lineageChannelPix);
end
end


function tf = hasAnyVisibleLineageSource(roiobj)
tf = false;
for r = 1:numel(roiobj)
    try
        idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roiobj(r).data),1,'first');
        if isempty(idx), continue; end
        if ~isempty(getVisibleLineageMaps(roiobj(r).data(idx)))
            tf = true;
            return;
        end
    catch
    end
end
end

function names = getVisibleLineageChannelNames(roi)
names = strings(1,0);
idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data),1,'first');
if isempty(idx), return; end
ds = roi.data(idx);
if ~isprop(ds,'userData') || ~isstruct(ds.userData)
    return;
end

if isfield(ds.userData,'lineageSources') && isstruct(ds.userData.lineageSources) && ...
        ~isempty(fieldnames(ds.userData.lineageSources))
    sourceKeys = fieldnames(ds.userData.lineageSources);
    for i = 1:numel(sourceKeys)
        src = ds.userData.lineageSources.(sourceKeys{i});
        show = false;
        try
            if isfield(src, 'show')
                show = logical(src.show);
            end
        catch
            show = false;
        end
        if ~show || ~isfield(src, 'motherOf') || ~isa(src.motherOf, 'containers.Map') || src.motherOf.Count == 0
            continue;
        end
        if isfield(src, 'channelName') && ~isempty(src.channelName)
            names(end+1) = string(src.channelName); %#ok<AGROW>
        end
    end
    names = unique(names, 'stable');
    return;
end

if isfield(ds.userData,'lineageChannelName') && ~isempty(ds.userData.lineageChannelName)
    names = string(ds.userData.lineageChannelName);
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



