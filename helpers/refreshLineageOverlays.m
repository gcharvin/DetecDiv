function refreshLineageOverlays(graphicsHandles, roiobj, layoutOptions, displayHandles,currentFrames)

[showGenealogy, showBudPairing] = lineageOverlayToggles(layoutOptions);
if ~showGenealogy && ~showBudPairing
    clearLineageAllTiles(graphicsHandles);
    return;
end

if ~hasAnyVisibleLineageSource(roiobj, layoutOptions)
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
        if isstruct(L) && isfield(L,'image') && ~isempty(L.image) && isgraphics(L.image)
            delete(L.image);
        end
        if isstruct(L) && isfield(L,'map') && isa(L.map,'containers.Map')
            k2 = L.map.keys;
            for u=1:numel(k2)
                h = L.map(k2{u});
                if isfield(h,'line')  && ~isempty(h.line)  && isgraphics(h.line),  delete(h.line);  end
                if isfield(h,'arrow') && ~isempty(h.arrow) && isgraphics(h.arrow), delete(h.arrow); end
            end
        end
        if isstruct(L) && isfield(L, 'vectorGroups')
            purgeLineageVectorGroups(L.vectorGroups);
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
    drawOrUpdateLineageOnAxes(graphicsHandles, t, axOverlay, roi, pix, frm, col, layoutOptions); % <<< frame passée ici
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
    drawOrUpdateLineageOnAxes(graphicsHandles, t, axOverlay, roi, pix, frm, col, layoutOptions); % <<< frame passée ici
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

                drawOrUpdateLineageOnAxes(graphicsHandles, tileIndex, ax, roi, pix, frm, col, layoutOptions);
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

                    drawOrUpdateLineageOnAxes(graphicsHandles, tileIndex, ax, roi, pix, frm, col, layoutOptions);
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
cfg = getLineageDisplayConfig(roi);
if cfg.enabled && strlength(cfg.channelName) > 0
    try
        pix = roi.findChannelID(char(cfg.channelName));
        if ~isempty(pix) && isfinite(pix), return; end
    catch
    end
end
% 1) priorité au canal enregistré dans cell_information.userData

% Le channel de lignage sert seulement à trouver les IDs; il n'a pas besoin
% d'être dans la liste des channels affichés pour que le lien soit dessiné.

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


function drawOrUpdateLineageOnAxes(graphicsHandles, tileIndex, ax, roi, pix, frm, col, layoutOptions)
geoms = getLineageGeometriesForFrame_ROI(roi, pix, frm, col, layoutOptions);

% conteneur de cette tuile
if isKey(graphicsHandles.lineageHandles, tileIndex)
    L = graphicsHandles.lineageHandles(tileIndex);
else
    L = struct('map',containers.Map('KeyType','int32','ValueType','any'), ...
        'vectorGroups',containers.Map('KeyType','char','ValueType','any'), ...
        'ax',ax,'image',[],'geoms',geoms,'renderMode','vector','rasterSize',[]);
end

% axes recréé ?
if ~isempty(L.ax) && ~isequal(L.ax, ax)
    purgeLineageMap(L.map);
    L.map = containers.Map('KeyType','int32','ValueType','any');
    if isfield(L, 'vectorGroups')
        purgeLineageVectorGroups(L.vectorGroups);
    end
    L.vectorGroups = containers.Map('KeyType','char','ValueType','any');
    if isfield(L,'image') && ~isempty(L.image) && isgraphics(L.image)
        delete(L.image);
    end
    L.image = [];
    L.ax  = ax;
end

if ~isfield(L,'image')
    L.image = [];
end
if ~isfield(L, 'vectorGroups') || ~isa(L.vectorGroups, 'containers.Map')
    L.vectorGroups = containers.Map('KeyType','char','ValueType','any');
end
L.geoms = geoms;

% ==== PROTECTION CONTRE L'EFFACEMENT ====
% on gèle les limites et on empêche 'line'/'quiver' d'effacer l'image overlay
oldXLim = get(ax,'XLim');
oldYLim = get(ax,'YLim');
oldXMode = get(ax,'XLimMode');
oldYMode = get(ax,'YLimMode');
oldNP   = get(ax,'NextPlot');

set(ax,'XLimMode','manual','YLimMode','manual','NextPlot','add');

if useRasterLineage(layoutOptions)
    L.renderMode = 'raster';
    purgeLineageMap(L.map);
    L.map = containers.Map('KeyType','int32','ValueType','any');
    purgeLineageVectorGroups(L.vectorGroups);
    L.vectorGroups = containers.Map('KeyType','char','ValueType','any');

    imgSize = size(roi.image);
    if numel(imgSize) < 3
        imgSize(3) = 1;
    end
    if numel(imgSize) < 4
        imgSize(4) = 1;
    end
    if isempty(pix) || isempty(frm)
        if ~isempty(L.image) && isgraphics(L.image), set(L.image,'Visible','off'); end
        set(ax,'XLim',oldXLim,'YLim',oldYLim,'XLimMode',oldXMode,'YLimMode',oldYMode,'NextPlot',oldNP);
        graphicsHandles.lineageHandles(tileIndex) = L;
        return;
    end
    pix = double(pix(1));
    frm = double(frm(1));
    if pix < 1 || pix > imgSize(3) || frm < 1 || frm > imgSize(4)
        if ~isempty(L.image) && isgraphics(L.image), set(L.image,'Visible','off'); end
        set(ax,'XLim',oldXLim,'YLim',oldYLim,'XLimMode',oldXMode,'YLimMode',oldYMode,'NextPlot',oldNP);
        graphicsHandles.lineageHandles(tileIndex) = L;
        return;
    end

    H = imgSize(1);
    W = imgSize(2);
    [xRange, yRange] = lineageRasterWindow(ax, H, W, layoutOptions);
    rasterH = numel(yRange);
    rasterW = numel(xRange);
    L.rasterSize = [rasterH rasterW];
    L.rasterOrigin = [xRange(1) yRange(1)];
    [rgbLine, alphaLine] = rasterizeLineageGeoms(geoms, rasterH, rasterW, L.rasterOrigin);
    if any(alphaLine(:) > 0)
        if isempty(L.image) || ~isgraphics(L.image)
            L.image = image(ax, [xRange(1) xRange(end)], [yRange(1) yRange(end)], rgbLine, ...
                'AlphaData', alphaLine, ...
                'AlphaDataMapping', 'none', ...
                'HitTest', 'off', ...
                'PickableParts', 'none', ...
                'Visible', 'on');
        else
            set(L.image, 'XData', [xRange(1) xRange(end)], 'YData', [yRange(1) yRange(end)], ...
                'CData', rgbLine, 'AlphaData', alphaLine, 'Visible', 'on');
        end
        try
            uistack(L.image, 'top');
        catch
        end
    elseif ~isempty(L.image) && isgraphics(L.image)
        set(L.image, 'Visible', 'off');
    end

    set(ax,'XLim',oldXLim,'YLim',oldYLim,'XLimMode',oldXMode,'YLimMode',oldYMode,'NextPlot',oldNP);
    graphicsHandles.lineageHandles(tileIndex) = L;
    return;
end

if ~isempty(L.image) && isgraphics(L.image)
    delete(L.image);
end
L.image = [];
L.renderMode = 'vector';
L.rasterSize = [];

usePerObjectVector = isstruct(layoutOptions) && ...
    isfield(layoutOptions, 'LineagePerObjectVector') && ...
    logical(layoutOptions.LineagePerObjectVector);
if usePerObjectVector
    purgeLineageVectorGroups(L.vectorGroups);
    L.vectorGroups = containers.Map('KeyType','char','ValueType','any');
else
    purgeLineageMap(L.map);
    L.map = containers.Map('KeyType','int32','ValueType','any');
    L.vectorGroups = updateVectorLineageGroups(L.vectorGroups, ax, geoms);
    set(ax,'XLim',oldXLim,'YLim',oldYLim,'XLimMode',oldXMode, ...
        'YLimMode',oldYMode,'NextPlot',oldNP);
    graphicsHandles.lineageHandles(tileIndex) = L;
    return;
end

alive = int32([]);

for i=1:numel(geoms)
    d = int32(geoms(i).mapKey);
    m = double(geoms(i).motherID);
    xd = geoms(i).xd;
    yd = geoms(i).yd;
    xm = geoms(i).xm;
    ym = geoms(i).ym;
    lineColor = geoms(i).color;
    lineWidth = geoms(i).lineWidth;
    lineStyle = geoms(i).lineStyle;

    alive(end+1) = d; %#ok<AGROW>

    if isKey(L.map, d)
        h = L.map(d);
        if isgraphics(h.line)
            set(h.line, 'XData',[xm xd], 'YData',[ym yd], 'Visible','on', ...
                'Color',lineColor, 'LineWidth',lineWidth, 'LineStyle',lineStyle);
        end
        if isgraphics(h.arrow)
            set(h.arrow,'XData',xm,'YData',ym,'UData',(xd-xm)*0.9,'VData',(yd-ym)*0.9, ...
                'Visible','on','Color',lineColor,'LineWidth',lineWidth,'MaxHeadSize',0.5,'AutoScale','off');
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
        hLine  = line(ax, [xm xd], [ym yd], 'Color', lineColor, ...
                      'LineWidth', lineWidth, 'LineStyle', lineStyle, ...
                      'HitTest','off','PickableParts','none');
        hArrow = quiver(ax, xm, ym, (xd-xm)*0.9, (yd-ym)*0.9, 0, ...
                        'LineWidth',lineWidth,'MaxHeadSize',0.5,'Color',lineColor, ...
                        'HitTest','off','PickableParts','none','AutoScale','off');
        L.map(d) = struct('line',hLine,'arrow',hArrow,'motherID',m, ...
            'daughterID',geoms(i).daughterID,'sourceKey',geoms(i).sourceKey, ...
            'mode',geoms(i).mode);

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

function purgeLineageVectorGroups(groups)
if ~isa(groups, 'containers.Map'), return; end
keys = groups.keys;
for i = 1:numel(keys)
    handles = groups(keys{i});
    if isfield(handles, 'line') && isgraphics(handles.line), delete(handles.line); end
    if isfield(handles, 'arrow') && isgraphics(handles.arrow), delete(handles.arrow); end
end
end

function groups = updateVectorLineageGroups(groups, ax, geoms)
% One line/quiver pair per relation made 100 links take seconds to refresh.
% Equal-style links are now grouped into only two vector graphics objects.
if ~isa(groups, 'containers.Map')
    groups = containers.Map('KeyType','char','ValueType','any');
end
styleKeys = cell(1, numel(geoms));
for i = 1:numel(geoms)
    color = double(geoms(i).color(:).');
    styleKeys{i} = sprintf('%s|%.6f,%.6f,%.6f|%.3f|%s', ...
        char(geoms(i).mode), color(1), color(2), color(3), ...
        double(geoms(i).lineWidth), char(geoms(i).lineStyle));
end
activeKeys = unique(styleKeys, 'stable');
for i = 1:numel(activeKeys)
    key = activeKeys{i};
    indices = find(strcmp(styleKeys, key));
    selected = geoms(indices);
    xm = [selected.xm];
    ym = [selected.ym];
    xd = [selected.xd];
    yd = [selected.yd];
    xData = reshape([xm; xd; nan(size(xm))], [], 1);
    yData = reshape([ym; yd; nan(size(ym))], [], 1);
    color = double(selected(1).color(:).');
    lineWidth = vectorLineWidthPoints(selected(1).lineWidth);
    lineStyle = selected(1).lineStyle;
    if isKey(groups, key)
        handles = groups(key);
    else
        handles = struct('line', [], 'arrow', []);
    end
    if isempty(handles.line) || ~isgraphics(handles.line)
        handles.line = line(ax, xData, yData, 'Color', color, ...
            'LineWidth', lineWidth, 'LineStyle', lineStyle, ...
            'HitTest','off','PickableParts','none');
    else
        set(handles.line, 'XData', xData, 'YData', yData, ...
            'Color', color, 'LineWidth', lineWidth, ...
            'LineStyle', lineStyle, 'Visible', 'on');
    end
    if isempty(handles.arrow) || ~isgraphics(handles.arrow)
        handles.arrow = quiver(ax, xm, ym, (xd-xm)*0.9, (yd-ym)*0.9, 0, ...
            'LineWidth',lineWidth,'MaxHeadSize',0.5,'Color',color, ...
            'HitTest','off','PickableParts','none','AutoScale','off');
    else
        set(handles.arrow, 'XData', xm, 'YData', ym, ...
            'UData', (xd-xm)*0.9, 'VData', (yd-ym)*0.9, ...
            'Color', color, 'LineWidth', lineWidth, ...
            'MaxHeadSize', 0.5, 'AutoScale', 'off', 'Visible', 'on');
    end
    groups(key) = handles;
    try
        uistack(handles.line, 'top');
        uistack(handles.arrow, 'top');
    catch
    end
end

staleKeys = setdiff(groups.keys, activeKeys);
for i = 1:numel(staleKeys)
    handles = groups(staleKeys{i});
    if isfield(handles, 'line') && isgraphics(handles.line), delete(handles.line); end
    if isfield(handles, 'arrow') && isgraphics(handles.arrow), delete(handles.arrow); end
    remove(groups, staleKeys{i});
end
end

function widthPoints = vectorLineWidthPoints(widthPx)
% MATLAB vector LineWidth is expressed in points, whereas the UI is in px.
dpi = 96;
try
    dpi = double(get(groot, 'ScreenPixelsPerInch'));
catch
end
if ~isfinite(dpi) || dpi <= 0, dpi = 96; end
widthPoints = max(0.5, double(widthPx) * 72 / dpi);
end

function tf = useRasterLineage(layoutOptions)
tf = false;
if isstruct(layoutOptions) && isfield(layoutOptions, 'LineageRenderMode')
    mode = lower(string(layoutOptions.LineageRenderMode));
    tf = mode == "raster";
end
end

function [xRange, yRange] = lineageRasterWindow(ax, H, W, layoutOptions)
xRange = 1:W;
yRange = 1:H;
useViewport = false;
try
    useViewport = isstruct(layoutOptions) && isfield(layoutOptions, 'LineageUseViewport') && ...
        logical(layoutOptions.LineageUseViewport);
catch
    useViewport = false;
end
if ~useViewport || isempty(ax) || ~isgraphics(ax)
    return;
end
try
    xl = get(ax, 'XLim');
    yl = get(ax, 'YLim');
    x1 = max(1, floor(min(xl)));
    x2 = min(W, ceil(max(xl)));
    y1 = max(1, floor(min(yl)));
    y2 = min(H, ceil(max(yl)));
    if x2 < x1 || y2 < y1
        return;
    end

    visibleArea = double(x2 - x1 + 1) * double(y2 - y1 + 1);
    fullArea = double(W) * double(H);
    if visibleArea >= 0.85 * fullArea
        return;
    end
    xRange = x1:x2;
    yRange = y1:y2;
catch
    xRange = 1:W;
    yRange = 1:H;
end
end

function [rgbLine, alphaLine] = rasterizeLineageGeoms(geoms, H, W, origin)
if nargin < 4 || isempty(origin)
    origin = [1 1];
end
rgbLine = zeros(H, W, 3, 'uint8');
alphaLine = zeros(H, W, 'single');
for i = 1:numel(geoms)
    [rows, cols] = linePixels(geoms(i).xm, geoms(i).ym, geoms(i).xd, geoms(i).yd, H, W, geoms(i).lineStyle, origin);
    if isempty(rows)
        continue;
    end
    [rows, cols] = thickenPixels(rows, cols, geoms(i).lineWidth, H, W);
    idx = sub2ind([H W], rows, cols);
    color = uint8(max(0, min(1, double(geoms(i).color(:).'))) * 255);
    for c = 1:3
        plane = rgbLine(:,:,c);
        plane(idx) = color(c);
        rgbLine(:,:,c) = plane;
    end
    alphaLine(idx) = max(alphaLine(idx), single(0.95));
end
end

function [rows, cols] = linePixels(x1, y1, x2, y2, H, W, lineStyle, origin)
if nargin < 8 || isempty(origin)
    origin = [1 1];
end
if any(~isfinite([x1 y1 x2 y2]))
    rows = [];
    cols = [];
    return;
end
n = max(2, ceil(max(abs([x2 - x1, y2 - y1]))) + 1);
cols = round(linspace(x1, x2, n));
rows = round(linspace(y1, y2, n));
cols = cols - double(origin(1)) + 1;
rows = rows - double(origin(2)) + 1;

if strcmp(char(lineStyle), '--')
    keep = mod(floor(((1:numel(rows)) - 1) / 8), 2) == 0;
    rows = rows(keep);
    cols = cols(keep);
end

valid = rows >= 1 & rows <= H & cols >= 1 & cols <= W;
rows = rows(valid);
cols = cols(valid);
if isempty(rows)
    return;
end
pairs = unique([rows(:), cols(:)], 'rows', 'stable');
rows = pairs(:,1);
cols = pairs(:,2);
end

function [rowsOut, colsOut] = thickenPixels(rows, cols, widthPx, H, W)
% Keep the user-facing value literal: 1 means a single image pixel.  The
% older radius conversion made a nominal width of 1 occupy three pixels.
widthPx = max(1, round(double(widthPx)));
if widthPx == 1
    rowsOut = rows(:);
    colsOut = cols(:);
    return;
end
negativeExtent = floor((widthPx - 1) / 2);
positiveExtent = widthPx - negativeExtent - 1;
[dc, dr] = meshgrid(-negativeExtent:positiveExtent, ...
    -negativeExtent:positiveExtent);
rowsOut = rows(:) + dr(:).';
colsOut = cols(:) + dc(:).';
rowsOut = rowsOut(:);
colsOut = colsOut(:);
valid = rowsOut >= 1 & rowsOut <= H & colsOut >= 1 & colsOut <= W;
rowsOut = rowsOut(valid);
colsOut = colsOut(valid);
pairs = unique([rowsOut, colsOut], 'rows', 'stable');
rowsOut = pairs(:,1);
colsOut = pairs(:,2);
end

function geoms = getLineageGeometriesForFrame_ROI(roi, fallbackPix, frm, fallbackColor, layoutOptions)
geoms = struct('mapKey',{},'daughterID',{},'motherID',{},'xd',{},'yd',{},'xm',{},'ym',{}, ...
    'color',{},'sourceKey',{},'mode',{},'lineWidth',{},'lineStyle',{});
[geoms, modelConfigured] = getCellModelLineageGeometries( ...
    roi, fallbackPix, frm, fallbackColor, layoutOptions, geoms);
if modelConfigured
    return;
end
idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data),1,'first');
if isempty(idx), return; end
ds = roi.data(idx);
if ~isprop(ds,'userData') || ~isstruct(ds.userData), return; end

sources = getVisibleLineageSources(roi, ds, layoutOptions);
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

    centroids = computeLabelCentroidMap(M);
    if centroids.Count == 0
        continue;
    end

    linkWidthPx = resolveLineageLinkWidth(layoutOptions);
    if sources(s).showBudPairing
        geoms = appendBudEventGeoms(geoms, sources(s), s, centroids, frm, ...
            resolveBudLinkColor(layoutOptions), linkWidthPx);
    end
    if sources(s).showGenealogy
        geoms = appendMotherMapGeoms(geoms, sources(s), s, centroids, ...
            resolveGenealogyLinkColor(layoutOptions, fallbackColor), linkWidthPx);
    end
end
end

function [geoms, configured] = getCellModelLineageGeometries( ...
        roi, fallbackPix, frm, fallbackColor, layoutOptions, geoms)
configured = false;
cfg = getLineageDisplayConfig(roi);
if ~startsWith(string(cfg.sourceKey), "cell_model:")
    return;
end
configured = true;
cfg = applyLineageOverlayToggles(cfg, layoutOptions);
if ~cfg.enabled
    return;
end

try
    [model, status] = score_getCellModel(roi);
    if ~strcmp(status, 'ok')
        return;
    end
    familyId = uint32(cfg.modelFamilyId);
    if familyId == 0
        token = extractAfter(string(cfg.sourceKey), "cell_model:");
        familyId = uint32(str2double(token));
    end
    [familyIndex, familyId] = cellModel.familyIndex(model, familyId);
    if isempty(familyIndex)
        return;
    end

    pix = fallbackPix;
    if strlength(cfg.channelName) > 0
        resolved = resolvePixForChannelName(roi, cfg.channelName);
        if ~isempty(resolved), pix = resolved; end
    end
    frm = double(frm(1));
    if isempty(pix) || pix < 1 || pix > size(roi.image,3) || ...
            frm < 1 || frm > size(roi.image,4)
        return;
    end
    centroids = computeLabelCentroidMap(roi.image(:,:,pix,frm));
    if centroids.Count == 0
        return;
    end

    instanceRows = find(model.instances.family_id == familyId & ...
        model.instances.frame == uint32(frm));
    relationRows = find(model.relations.family_id == familyId);
    source = struct('key', char(cfg.sourceKey));
    budColor = resolveBudLinkColor(layoutOptions);
    genealogyColor = resolveGenealogyLinkColor(layoutOptions, fallbackColor);
    linkWidthPx = resolveLineageLinkWidth(layoutOptions);
    for k = relationRows(:).'
        childTrack = model.relations.child_track_id(k);
        parentTrack = model.relations.parent_track_id(k);
        childRow = instanceRows(find(model.instances.track_id(instanceRows) == childTrack, 1, 'first'));
        parentRow = instanceRows(find(model.instances.track_id(instanceRows) == parentTrack, 1, 'first'));
        if isempty(childRow) || isempty(parentRow)
            continue;
        end
        childLabel = int32(model.instances.mask_label(childRow));
        parentLabel = double(model.instances.mask_label(parentRow));
        if cfg.showBudPairing
            eventFrame = double(model.relations.event_frame(k));
            if frm >= eventFrame - cfg.budWindowBefore && ...
                    frm <= eventFrame + cfg.budWindowAfter
                geoms = appendPairGeom(geoms, source, 1, centroids, ...
                    childLabel, parentLabel, "bud", budColor, linkWidthPx, '-');
            end
        end
        if cfg.showGenealogy
            geoms = appendPairGeom(geoms, source, 1, centroids, ...
                childLabel, parentLabel, "genealogy", genealogyColor, linkWidthPx, '-');
        end
    end
catch
    % A corrupt optional object model must not break image display.
end
end

function geoms = appendBudEventGeoms(geoms, source, sourceIndex, centroids, frm, color, linkWidthPx)
if ~isfield(source, 'events') || isempty(source.events)
    return;
end
events = source.events;
for k = 1:numel(events)
    if ~isfield(events(k), 'startFrame')
        continue;
    end
    startFrame = double(events(k).startFrame);
    if frm < startFrame - source.budWindowBefore || frm > startFrame + source.budWindowAfter
        continue;
    end
    if ~isfield(events(k), 'childId') || ~isfield(events(k), 'motherId')
        continue;
    end
    geoms = appendPairGeom(geoms, source, sourceIndex, centroids, ...
        int32(events(k).childId), double(events(k).motherId), ...
        "bud", color, linkWidthPx, '-');
end
end

function geoms = appendMotherMapGeoms(geoms, source, sourceIndex, centroids, fallbackColor, linkWidthPx)
keysD = source.motherOf.keys;
for k = 1:numel(keysD)
    daughterID = int32(keysD{k});
    motherID = double(source.motherOf(daughterID));
    geoms = appendPairGeom(geoms, source, sourceIndex, centroids, ...
        daughterID, motherID, "genealogy", fallbackColor, linkWidthPx, '-');
end
end

function geoms = appendPairGeom(geoms, source, sourceIndex, centroids, daughterID, motherID, mode, color, lineWidth, lineStyle)
if ~isKey(centroids, daughterID)
    return;
end
motherKey = int32(round(motherID));
if ~isfinite(motherID) || motherID <= 0 || ~isKey(centroids, motherKey)
    return;
end
daughterCentroid = centroids(daughterID);
motherCentroid = centroids(motherKey);
xd = daughterCentroid(1);
yd = daughterCentroid(2);
xm = motherCentroid(1);
ym = motherCentroid(2);
if any(~isfinite([xd yd xm ym]))
    return;
end
geoms(end+1) = struct( ... %#ok<AGROW>
    'mapKey', lineageMapKey(sourceIndex, daughterID, mode), ...
    'daughterID', daughterID, ...
    'motherID', motherID, ...
    'xd', xd, 'yd', yd, 'xm', xm, 'ym', ym, ...
    'color', color, ...
    'sourceKey', char(source.key), ...
    'mode', char(mode), ...
        'lineWidth', double(lineWidth), ...
        'lineStyle', char(lineStyle));
end

function centroids = computeLabelCentroidMap(M)
centroids = containers.Map('KeyType', 'int32', 'ValueType', 'any');
try
    nz = M > 0;
    if ~any(nz(:))
        return;
    end
    [rows, cols] = find(nz);
    labels = int32(M(nz));
    [ids, ~, groupIdx] = unique(labels);
    counts = accumarray(groupIdx, 1);
    xsum = accumarray(groupIdx, double(cols));
    ysum = accumarray(groupIdx, double(rows));
    for i = 1:numel(ids)
        centroids(ids(i)) = [xsum(i) ./ counts(i), ysum(i) ./ counts(i)];
    end
catch
    centroids = containers.Map('KeyType', 'int32', 'ValueType', 'any');
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

function mapKey = lineageMapKey(sourceIndex, daughterID, mode)
modeOffset = 0;
if strcmp(string(mode), "bud")
    modeOffset = 500000;
end
mapKey = int32(sourceIndex * 1000000 + modeOffset + double(daughterID));
end

function sources = getVisibleLineageSources(roi, ds, layoutOptions)
sources = struct('key',{},'motherOf',{},'channelName',{},'events',{}, ...
    'showBudPairing',{},'showGenealogy',{},'budWindowBefore',{},'budWindowAfter',{});
if nargin < 3
    layoutOptions = struct();
end
cfg = getLineageDisplayConfig(roi);
if ~cfg.enabled
    cfg = getLineageDisplayConfigFromUserData(ds);
end
cfg = applyLineageOverlayToggles(cfg, layoutOptions);
if ~cfg.enabled
    return;
end

[key, src] = resolveDisplayLineageSource(ds, cfg);
if strlength(key) == 0 || isempty(src) || ~isfield(src, 'motherOf') || ...
        ~isa(src.motherOf, 'containers.Map') || src.motherOf.Count == 0
    return;
end

channelName = cfg.channelName;
if strlength(channelName) == 0 && isfield(src, 'channelName') && ~isempty(src.channelName)
    channelName = string(src.channelName);
end
events = struct([]);
if isfield(src, 'events')
    events = src.events;
end

sources = struct('key', string(key), ...
    'motherOf', src.motherOf, ...
    'channelName', channelName, ...
    'events', events, ...
    'showBudPairing', logical(cfg.showBudPairing), ...
    'showGenealogy', logical(cfg.showGenealogy), ...
    'budWindowBefore', double(cfg.budWindowBefore), ...
    'budWindowAfter', double(cfg.budWindowAfter));
end

function pairs = getLineagePairsForFrame_ROI(roi, maskFrame)
pairs = [];
idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data),1,'first');
if isempty(idx), return; end
ds = roi.data(idx);
if ~isprop(ds,'userData') || ~isstruct(ds.userData), return; end

present = unique(maskFrame(:)); present(present==0) = [];
present = int32(present(:)');

maps = getVisibleLineageMaps(roi, ds);
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

function maps = getVisibleLineageMaps(roi, ds, layoutOptions)
maps = {};
if ~isprop(ds,'userData') || ~isstruct(ds.userData)
    return;
end
if nargin < 3
    layoutOptions = struct();
end
sources = getVisibleLineageSources(roi, ds, layoutOptions);
for i = 1:numel(sources)
    maps{end+1} = sources(i).motherOf; %#ok<AGROW>
end
end

function cfg = getLineageDisplayConfig(roi)
cfg = struct('enabled', false, 'channelName', "", 'channelPix', [], ...
    'sourceKey', "", 'showBudPairing', false, 'showGenealogy', false, ...
    'budWindowBefore', 0, 'budWindowAfter', 6, 'modelFamilyId', 0, ...
    'explicit', false);
try
    if ~isprop(roi, 'display') || ~isstruct(roi.display) || ...
            ~isfield(roi.display, 'lineage') || isempty(roi.display.lineage)
        return;
    end
    cfg.explicit = true;
    in = roi.display.lineage;
    if isfield(in, 'enabled'), cfg.enabled = logical(in.enabled); end
    if isfield(in, 'channelName'), cfg.channelName = string(in.channelName); end
    if isfield(in, 'channelPix'), cfg.channelPix = double(in.channelPix); end
    if isfield(in, 'sourceKey'), cfg.sourceKey = string(in.sourceKey); end
    if isfield(in, 'showBudPairing'), cfg.showBudPairing = logical(in.showBudPairing); end
    if isfield(in, 'showGenealogy'), cfg.showGenealogy = logical(in.showGenealogy); end
    if isfield(in, 'budWindowBefore'), cfg.budWindowBefore = max(0, double(in.budWindowBefore)); end
    if isfield(in, 'budWindowAfter'), cfg.budWindowAfter = max(0, double(in.budWindowAfter)); end
    if isfield(in, 'modelFamilyId'), cfg.modelFamilyId = double(in.modelFamilyId); end
    cfg.enabled = cfg.enabled && (cfg.showBudPairing || cfg.showGenealogy) && strlength(cfg.channelName) > 0;
catch
    cfg.enabled = false;
end
end

function cfg = getLineageDisplayConfigFromUserData(ds)
cfg = struct('enabled', false, 'channelName', "", 'channelPix', [], ...
    'sourceKey', "", 'showBudPairing', false, 'showGenealogy', false, ...
    'budWindowBefore', 0, 'budWindowAfter', 6);

try
    if ~isprop(ds, 'userData') || ~isstruct(ds.userData)
        return;
    end
    ud = ds.userData;
    key = "";
    src = [];

    if isfield(ud, 'activeLineageSource') && ~isempty(ud.activeLineageSource)
        candidate = string(ud.activeLineageSource);
        if isfield(ud, 'lineageSources') && isstruct(ud.lineageSources) && ...
                isfield(ud.lineageSources, char(candidate))
            key = candidate;
            src = ud.lineageSources.(char(key));
        end
    end

    if isempty(src) && isfield(ud, 'motherOfSourceKey') && ~isempty(ud.motherOfSourceKey)
        candidate = string(ud.motherOfSourceKey);
        if isfield(ud, 'lineageSources') && isstruct(ud.lineageSources) && ...
                isfield(ud.lineageSources, char(candidate))
            key = candidate;
            src = ud.lineageSources.(char(key));
        end
    end

    if isempty(src) && isfield(ud, 'lineageSources') && isstruct(ud.lineageSources)
        fields = fieldnames(ud.lineageSources);
        for i = 1:numel(fields)
            candidate = ud.lineageSources.(fields{i});
            show = true;
            if isfield(candidate, 'show')
                show = logical(candidate.show);
            end
            if show && isfield(candidate, 'motherOf') && isa(candidate.motherOf, 'containers.Map') && ...
                    candidate.motherOf.Count > 0
                key = string(fields{i});
                src = candidate;
                break;
            end
        end
    end

    if ~isempty(src)
        show = true;
        if isfield(src, 'show')
            show = logical(src.show);
        end
        if ~show || ~isfield(src, 'motherOf') || ~isa(src.motherOf, 'containers.Map') || src.motherOf.Count == 0
            return;
        end
        cfg.sourceKey = key;
        if isfield(src, 'channelName') && ~isempty(src.channelName)
            cfg.channelName = string(src.channelName);
        end
        if isfield(src, 'channelPix') && ~isempty(src.channelPix)
            cfg.channelPix = double(src.channelPix);
        end
        cfg.showGenealogy = true;
        cfg.showBudPairing = isfield(src, 'events') && ~isempty(src.events);
    elseif isfield(ud, 'motherOf') && isa(ud.motherOf, 'containers.Map') && ud.motherOf.Count > 0
        cfg.sourceKey = "legacy";
        cfg.showGenealogy = true;
        cfg.showBudPairing = isfield(ud, 'events') && ~isempty(ud.events);
    else
        return;
    end

    if strlength(cfg.channelName) == 0 && isfield(ud, 'lineageChannelName') && ~isempty(ud.lineageChannelName)
        cfg.channelName = string(ud.lineageChannelName);
    end
    if isempty(cfg.channelPix) && isfield(ud, 'lineageChannelPix') && ~isempty(ud.lineageChannelPix)
        cfg.channelPix = double(ud.lineageChannelPix);
    end
    cfg.enabled = strlength(cfg.channelName) > 0 && (cfg.showBudPairing || cfg.showGenealogy);
catch
    cfg.enabled = false;
end
end

function [key, src] = resolveDisplayLineageSource(ds, cfg)
key = "";
src = [];
if ~isprop(ds, 'userData') || ~isstruct(ds.userData)
    return;
end
if isfield(ds.userData, 'lineageSources') && isstruct(ds.userData.lineageSources)
    fields = fieldnames(ds.userData.lineageSources);
    if strlength(cfg.sourceKey) > 0 && isfield(ds.userData.lineageSources, char(cfg.sourceKey))
        key = cfg.sourceKey;
        src = ds.userData.lineageSources.(char(key));
        return;
    end
    for i = 1:numel(fields)
        candidate = ds.userData.lineageSources.(fields{i});
        if isfield(candidate, 'channelName') && strcmp(string(candidate.channelName), cfg.channelName)
            key = string(fields{i});
            src = candidate;
            return;
        end
    end
end
if isfield(ds.userData, 'motherOf') && isa(ds.userData.motherOf, 'containers.Map') && ...
        ds.userData.motherOf.Count > 0 && legacyLineageMatchesChannel(ds.userData, cfg.channelName)
    key = "legacy";
    src = struct('motherOf', ds.userData.motherOf, 'channelName', char(cfg.channelName));
    if isfield(ds.userData, 'events')
        src.events = ds.userData.events;
    end
end
end

function tf = legacyLineageMatchesChannel(userData, channelName)
tf = false;
if strlength(channelName) == 0
    return;
end
fields = ["motherOfSourceChannelName", "lineageChannelName", "activeLineageChannelName"];
for i = 1:numel(fields)
    nm = char(fields(i));
    if isfield(userData, nm) && ~isempty(userData.(nm)) && strcmp(string(userData.(nm)), channelName)
        tf = true;
        return;
    end
end
hasExplicitSource = isfield(userData, 'lineageSources') && isstruct(userData.lineageSources) && ...
    ~isempty(fieldnames(userData.lineageSources));
tf = ~hasExplicitSource;
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
cfg = getLineageDisplayConfig(roi);
if cfg.enabled && strlength(cfg.channelName) > 0
    name = string(cfg.channelName);
    pix = double(cfg.channelPix);
    return;
end
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


function tf = hasAnyVisibleLineageSource(roiobj, layoutOptions)
tf = false;
if nargin < 2
    layoutOptions = struct();
end
for r = 1:numel(roiobj)
    try
        cfg = getLineageDisplayConfig(roiobj(r));
        if startsWith(string(cfg.sourceKey), "cell_model:")
            cfg = applyLineageOverlayToggles(cfg, layoutOptions);
            if cfg.enabled
                [model, status] = score_getCellModel(roiobj(r));
                if strcmp(status, 'ok') && ...
                        any(model.relations.family_id == uint32(cfg.modelFamilyId))
                    tf = true;
                    return;
                end
            end
            continue;
        end
        idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roiobj(r).data),1,'first');
        if isempty(idx), continue; end
        if ~isempty(getVisibleLineageMaps(roiobj(r), roiobj(r).data(idx), layoutOptions))
            tf = true;
            return;
        end
    catch
    end
end
end

function names = getVisibleLineageChannelNames(roi)
names = strings(1,0);
cfg = getLineageDisplayConfig(roi);
if cfg.enabled && strlength(cfg.channelName) > 0
    names = string(cfg.channelName);
    return;
end
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

function cfg = applyLineageOverlayToggles(cfg, layoutOptions)
[showGenealogy, showBudPairing] = lineageOverlayToggles(layoutOptions);
cfg.showGenealogy = logical(cfg.showGenealogy) && showGenealogy;
cfg.showBudPairing = logical(cfg.showBudPairing) && showBudPairing;
cfg.enabled = logical(cfg.enabled) && (cfg.showGenealogy || cfg.showBudPairing) && strlength(string(cfg.channelName)) > 0;
end

function [showGenealogy, showBudPairing] = lineageOverlayToggles(layoutOptions)
showGenealogy = true;
showBudPairing = true;
try
    if isstruct(layoutOptions) && isfield(layoutOptions, 'ShowLineageOverlay')
        showGenealogy = logical(layoutOptions.ShowLineageOverlay);
    end
    if isstruct(layoutOptions) && isfield(layoutOptions, 'ShowBudPairingOverlay')
        showBudPairing = logical(layoutOptions.ShowBudPairingOverlay);
    end
catch
    showGenealogy = true;
    showBudPairing = true;
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
if isempty(idx)
    col = [0.05 0.75 1.0];
    return;
end
base = [1 1 1]; % fallback si introuvable
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

function color = resolveBudLinkColor(layoutOptions)
color = [1.0 0.82 0.05];
try
    if isstruct(layoutOptions) && isfield(layoutOptions, 'BudLinkColor') && ...
            isnumeric(layoutOptions.BudLinkColor) && numel(layoutOptions.BudLinkColor) == 3
        color = double(layoutOptions.BudLinkColor(:).');
    end
catch
end
color = max(0, min(1, color));
end

function color = resolveGenealogyLinkColor(layoutOptions, fallback)
color = fallback;
try
    if isstruct(layoutOptions) && isfield(layoutOptions, 'GenealogyLinkColor') && ...
            isnumeric(layoutOptions.GenealogyLinkColor) && numel(layoutOptions.GenealogyLinkColor) == 3
        color = double(layoutOptions.GenealogyLinkColor(:).');
    end
catch
end
color = max(0, min(1, color));
end

function widthPx = resolveLineageLinkWidth(layoutOptions)
widthPx = 1;
try
    if isstruct(layoutOptions) && isfield(layoutOptions, 'LineageLinkWidthPx') && ...
            isnumeric(layoutOptions.LineageLinkWidthPx) && ...
            isscalar(layoutOptions.LineageLinkWidthPx) && ...
            isfinite(layoutOptions.LineageLinkWidthPx)
        widthPx = double(layoutOptions.LineageLinkWidthPx);
    end
catch
end
widthPx = max(1, min(20, round(widthPx)));
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



