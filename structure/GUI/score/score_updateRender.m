function score_updateRender(graphicsHandles, roiobj, layoutOptions, displayHandles,newframe)
% updateRender Met à jour les objets graphiques existants (images et courbes)
% dans le master tiledlayout à partir d'un nouveau jeu de données (roiobj).
%
% Inputs:
%   graphicsHandles - structure contenant les containers.Map:
%                     .imgHandles (clé = tileIndex, valeur = handle de l'image)
%                     .lineHandles (clé = tileIndex, valeur = handle de la courbe)
%   roiobj          - nouvelle liste d'objets ROI (champs .image et .data)
%   layoutOptions   - options d'affichage (mode, Nbrick, Nchannel, Nframes, Ndataseries, overlay, etc.)
%   displayHandles  - structure issue de createDisplayHandles contenant les dimensions du layout
%
% La fonction met à jour 'CData' pour les images et 'YData' pour les courbes.
masterTL = displayHandles.masterTiledLayout;
mode = lower(layoutOptions.mode);
switch mode
    case 'display'

   
        % Mode DISPLAY : mise à jour de la ROI affichée (roiobj(1)).
        roiData = roiobj(1);

        layoutOptions.frames=newframe;

        % displayImage=score_makeComposite(roiobj(1),1,layoutOptions);
        [displayImage, vContours, indexedOverlay, alphaOverlay]=score_makeComposite(roiobj(1),1,layoutOptions);

        MasterCols = displayHandles.MasterCols;

        if layoutOptions.overlay
            tileIndex = 1;
          %  set(graphicsHandles.imgHandles(tileIndex), 'CData', displayImage);

            h = localImageHandle(graphicsHandles.imgHandles(tileIndex));
            if ~isequal(get(h, 'CData'), displayImage)
                set(h, 'CData', displayImage);
            end

            h = graphicsHandles.overlayHandles(tileIndex);
            if ~isequal(get(h, 'CData'), indexedOverlay)
                set(h, 'CData', indexedOverlay);
            end
            if ~isequal(get(h, 'AlphaData'), alphaOverlay)
                set(h, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
            end



            %set(graphicsHandles.overlayHandles(tileIndex),'CData', indexedOverlay);
            %set(graphicsHandles.overlayHandles(tileIndex), 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
        else
            for ch = 1:layoutOptions.Nchannel
                local_row = 1;
                local_col = (ch-1)*layoutOptions.Nbrick + 1;
                tileIndex = (local_row-1)*MasterCols + local_col;
                newImg = displayImage(:,:,:,ch);
                %  aa= graphicsHandles.imgHandles(tileIndex);
                %  tmp=graphicsHandles.imgHandles(tileIndex)
                h = localImageHandle(graphicsHandles.imgHandles(tileIndex));
                set(h, 'CData', newImg);


                set(graphicsHandles.overlayHandles(tileIndex),'CData', indexedOverlay);
                set(graphicsHandles.overlayHandles(tileIndex), 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
                localRefreshScaleBar(graphicsHandles, tileIndex, h.Parent, layoutOptions, ch);
            end
        end

        % Mise à jour des dataseries
        if layoutOptions.Ndataseries > 0 && ~isempty(roiData.data)

            for ds = 1:layoutOptions.Ndataseries
                local_row = layoutOptions.Nbrick + ds;
                local_col = 1;
                tileIndex = (local_row-1)*displayHandles.MasterCols + local_col;

                if layoutOptions.overlay
                    wid=layoutOptions.Nbrick;
                else
                    wid= layoutOptions.Nchannel*layoutOptions.Nbrick;
                end

                ax = nexttile(masterTL, tileIndex, [1, wid]);

                % if layoutOptions.Ndataseries>1 && ds~=layoutOptions.Ndataseries
                %     set(ax,'XTickLabel',[]);
                %     %   'ok'
                % else
                %     set(ax, 'XTickLabelRotation', 0);  % ou 0, selon ton style
                % end
                % 
                % if ~isa(ax.YAxis, 'matlab.graphics.axis.decorator.CategoricalRuler')
                %     ytickformat(ax, '%.1f');
                % end
                % 
                % xtickformat(ax, '%.1f');

                hLineAll= graphicsHandles.lineHandles(tileIndex);
                
                updateDataPanels(ax,ds,layoutOptions,newframe,hLineAll,roiData);

                updateMarkers(hLineAll, newframe, layoutOptions);
                %   title(sprintf('Data:%d', ds));

            end
        end

    case 'movie'
        % Mode MOVIE : mise à jour de chaque ROI de la grille.
        % Pour chaque ROI, on calcule ROI_row_offset et ROI_col_offset en fonction
        % du layout du mode movie, qui a pour dimensions :
        %   ROI_rows = Nbrick + Ndataseries
        %   Si overlay=true, ROI_cols = Nbrick, sinon ROI_cols = Nchannel * Nbrick.

        keysToDelete = graphicsHandles.vectorHandles.keys;
        for k = 1:length(keysToDelete)
            h = graphicsHandles.vectorHandles(keysToDelete{k});
            delete(h);
        end
        remove(graphicsHandles.vectorHandles, keysToDelete);

        nROI = numel(roiobj);

        for i = 1:layoutOptions.Nrow
            for j = 1:layoutOptions.Ncol

                


                roiIndex = (i-1)*layoutOptions.Ncol + j;

                if roiIndex > nROI
    continue;   % ou break; si tu préfères arrêter la ligne
                end
                
                roiData = roiobj(roiIndex);

                [displayImage, vContours]=score_makeComposite(roiData,newframe,layoutOptions);

                ROI_row_offset = (i-1) * (layoutOptions.Nbrick + layoutOptions.Ndataseries);

                if layoutOptions.overlay
                    ROI_col_offset = (j-1) * layoutOptions.Nbrick;
                    % Calcul du tileIndex selon la formule donnée
                    local_row = 1;
                    local_col = 1;
                    global_row = ROI_row_offset + local_row;
                    global_col = ROI_col_offset + local_col;
                    tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                    % compositeImg = max(roiData.image, [], 3);
                    %compositeImg = squeeze(max(roiData.image, [], 3));

                    if isKey(graphicsHandles.imgHandles, tileIndex)
                        h = localImageHandle(graphicsHandles.imgHandles(tileIndex));
                        set(h, 'CData', displayImage);
                    end

                    if isKey(graphicsHandles.imgHandles, tileIndex)
                        h = localImageHandle(graphicsHandles.imgHandles(tileIndex));
                        set(h, 'CData', displayImage(:,:,:,1));
                        ax=h.Parent;

                        [htext, hvector]=score_displayVectorGraphics(ax, newframe, 1, vContours , layoutOptions);
                        graphicsHandles.vectorHandles(tileIndex)=[htext hvector];
                        score_drawMovieEventText(ax, layoutOptions, localMovieFrameValue(layoutOptions, newframe));
                    end

                else
                    ROI_col_offset = (j-1) * (layoutOptions.Nchannel * layoutOptions.Nbrick);
                    for ch = 1:layoutOptions.Nchannel
                        local_row = 1;
                        local_col = (ch-1)*layoutOptions.Nbrick + 1;
                        global_row = ROI_row_offset + local_row;
                        global_col = ROI_col_offset + local_col;
                        tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;

                        if isKey(graphicsHandles.imgHandles, tileIndex)
                            h = localImageHandle(graphicsHandles.imgHandles(tileIndex));
                            set(h, 'CData', displayImage(:,:,:,ch));
                            ax=h.Parent;
                            localRefreshScaleBar(graphicsHandles, tileIndex, ax, layoutOptions, ch);

                            [htext, hvector]=score_displayVectorGraphics(ax, newframe, ch, vContours , layoutOptions);
                            graphicsHandles.vectorHandles(tileIndex)=[htext hvector];
                            if ch == 1
                                score_drawMovieEventText(ax, layoutOptions, localMovieFrameValue(layoutOptions, newframe));
                            end
                        end

                    end
                end

               

                if layoutOptions.Ndataseries > 0 && ~isempty(roiData.data)
                    for ds = 1:layoutOptions.Ndataseries
                        local_row = layoutOptions.Nbrick + ds;
                        local_col = 1;
                        global_row = ROI_row_offset + local_row;
                        global_col = ROI_col_offset + local_col;
                        tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;

                        if layoutOptions.overlay
                            wid=layoutOptions.Nbrick;
                        else
                            wid= layoutOptions.Nchannel*layoutOptions.Nbrick;
                        end

                        ax = nexttile(masterTL, tileIndex, [1, wid]);

                        % if layoutOptions.Ndataseries>1 && ds~=layoutOptions.Ndataseries
                        % %     set(ax,'XTickLabel',[]);
                        % %     %   'ok'
                        % % else
                        % %     set(ax, 'XTickLabelRotation', 0);  % ou 0, selon ton style
                        % % end
                        % % 
                        % % if ~isa(ax.YAxis, 'matlab.graphics.axis.decorator.CategoricalRuler')
                        % %     ytickformat(ax, '%.1f');
                        % % end
                        % % 
                        % % xtickformat(ax, '%.1f');

                        hLineAll= graphicsHandles.lineHandles(tileIndex);
                        
                        updateDataPanels(ax,ds, layoutOptions,newframe,hLineAll,roiData);
                       % newframe
                        fra=newframe+layoutOptions.frames(1)-1;
                        updateMarkers(hLineAll, fra , layoutOptions);

                        %   title(sprintf('Data:%d', ds));

                    end
                end
            end
        end

    case 'sequence'  % this mode is not relevant , because there is no update of rendering to be made
        % Mode SEQUENCE : mise à jour de chaque ROI dans le layout séquence.
        ROI_cols = displayHandles.ROI_cols;
        for i = 1:layoutOptions.Nrow
            for j = 1:layoutOptions.Ncol
                roiIndex = (i-1)*layoutOptions.Ncol + j;
                roiData = roiobj(roiIndex);
                ROI_row_offset = (i-1) * displayHandles.ROI_rows;
                ROI_col_offset = (j-1) * displayHandles.ROI_cols;
                if layoutOptions.overlay
                    for frame = 1:layoutOptions.Nframes
                        local_row = 1;
                        local_col = (frame-1)*layoutOptions.Nbrick + 1;
                        global_row = ROI_row_offset + local_row;
                        global_col = ROI_col_offset + local_col;
                        tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                        %   compositeImg = max(roiData.image(:,:,:,frame), [], 3);
                        if isKey(graphicsHandles.imgHandles, tileIndex)
                            %    set(graphicsHandles.imgHandles(tileIndex), 'CData', compositeImg);
                        end
                    end
                else
                    for ch = 1:layoutOptions.Nchannel
                        for frame = 1:layoutOptions.Nframes
                            local_row = (ch-1)*layoutOptions.Nbrick + 1;
                            local_col = (frame-1)*layoutOptions.Nbrick + 1;
                            global_row = ROI_row_offset + local_row;
                            global_col = ROI_col_offset + local_col;
                            tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                            newImg = roiData.image(:,:,ch,frame);
                            if isKey(graphicsHandles.imgHandles, tileIndex)
                                %         set(graphicsHandles.imgHandles(tileIndex), 'CData', newImg);
                            end
                        end
                    end
                end
                if layoutOptions.Ndataseries > 0 && ~isempty(roiData.data)
                    if layoutOptions.overlay
                        base_row = layoutOptions.Nbrick;
                    else
                        base_row = layoutOptions.Nchannel * layoutOptions.Nbrick;
                    end
                    for ds = 1:layoutOptions.Ndataseries
                        local_row = base_row + ds;
                        local_col = 1;
                        global_row = ROI_row_offset + local_row;
                        global_col = ROI_col_offset + local_col;
                        tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                        if isKey(graphicsHandles.lineHandles, tileIndex)
                            %     set(graphicsHandles.lineHandles(tileIndex), 'YData', roiData.data(ds, :));
                        end
                    end
                end
            end
        end
end

% --- lineage overlay (refresh à chaque frame)
try
    switch mode
    case 'display'
            fr=newframe;

    case 'movie'
   % layoutOptions
           fr=layoutOptions.frames(newframe);
    end
 
     refreshLineageOverlays(graphicsHandles, roiobj, layoutOptions, displayHandles, fr)
catch ME
   % warning('Lineage refresh failed: %s', ME.message);
end

if strcmp(mode, 'display')
    score_syncOverlayAxes(graphicsHandles);
end

end

function [xlims, doClip] = localMovieXLimits(layoutOptions)
xlims = [];
doClip = false;
try
    if ~isfield(layoutOptions, 'mode') || ~strcmpi(string(layoutOptions.mode), "movie") || ...
            ~isfield(layoutOptions, 'frames') || isempty(layoutOptions.frames) || ...
            ~isfield(layoutOptions, 'framerate') || isempty(layoutOptions.framerate)
        return;
    end
    frames = double(layoutOptions.frames(:)');
    framerate = double(layoutOptions.framerate);
    if ~isfinite(framerate) || framerate <= 0 || isempty(frames)
        return;
    end
    if isfield(layoutOptions, 'timeOffset') && layoutOptions.timeOffset
        xlims = [0, (max(frames) - min(frames)) * framerate];
    else
        xlims = [min(frames), max(frames)] * framerate;
    end
    if xlims(2) <= xlims(1)
        xlims(2) = xlims(1) + framerate;
    end
    doClip = all(isfinite(xlims));
catch
    xlims = [];
    doClip = false;
end
end

function h = localImageHandle(hIn)
h = hIn;
if numel(h) > 1
    isImg = arrayfun(@(x) isgraphics(x) && isa(x, 'matlab.graphics.primitive.Image'), h);
    h = h(find(isImg, 1, 'first'));
end
if isempty(h) || ~isgraphics(h) || ~isa(h, 'matlab.graphics.primitive.Image')
    error('score_updateRender:InvalidImageHandle', ...
        'Stored image handle is not a matlab.graphics.primitive.Image.');
end
end

function localRefreshScaleBar(graphicsHandles, tileIndex, ax, layoutOptions, ch)
if isempty(graphicsHandles) || ~isfield(graphicsHandles, 'scaleBarHandles') || ...
        isempty(graphicsHandles.scaleBarHandles) || isempty(ax) || ~isgraphics(ax)
    return;
end

if isfield(graphicsHandles, 'overlayHandles') && ~isempty(graphicsHandles.overlayHandles) && ...
        isKey(graphicsHandles.overlayHandles, tileIndex)
    overlayHandle = graphicsHandles.overlayHandles(tileIndex);
    if ~isempty(overlayHandle) && isgraphics(overlayHandle)
        ax = overlayHandle(1).Parent;
    end
end

if isKey(graphicsHandles.scaleBarHandles, tileIndex)
    oldHandles = graphicsHandles.scaleBarHandles(tileIndex);
    if ~isempty(oldHandles)
        delete(oldHandles(isgraphics(oldHandles)));
    end
    remove(graphicsHandles.scaleBarHandles, tileIndex);
end

newHandles = score_drawChannelScaleBar(ax, layoutOptions, ch);
if ~isempty(newHandles)
    graphicsHandles.scaleBarHandles(tileIndex) = newHandles;
end
end

function frameValue = localMovieFrameValue(layoutOptions, newframe)
frameValue = newframe;
try
    if isfield(layoutOptions, 'frames') && ~isempty(layoutOptions.frames) && ...
            newframe >= 1 && newframe <= numel(layoutOptions.frames)
        frameValue = layoutOptions.frames(newframe);
    end
catch
    frameValue = newframe;
end
end

function updateMarkers(hLineAll, fIdx, layoutOptions)
% Version robuste de mise à jour des marqueurs

if isempty(hLineAll) || isa(hLineAll(1), 'matlab.graphics.primitive.Image')  % Mode image/traj => pas de marqueurs
    return
end

% Identifier les marqueurs (style 'o')
markerIdx = arrayfun(@(h) isgraphics(h) && strcmp(h.Marker, 'o'), hLineAll);
hMarkers = hLineAll(markerIdx);

if isempty(hMarkers)
    return
end

% Préparer X coordonnée des marqueurs
if layoutOptions.timeOffset
    xMarker = (fIdx - layoutOptions.frames(1)) * layoutOptions.framerate;
else
    xMarker = fIdx * layoutOptions.framerate;
end

% Préparer les nouvelles positions
newX = repmat({xMarker}, 1, numel(hMarkers));
newY = cell(1, numel(hMarkers));

for j = 1:numel(hMarkers)
    linkedLine = hMarkers(j).UserData.LinkedLine;
    if isempty(linkedLine) || ~isgraphics(linkedLine)
        newY{j} = NaN;
    else
        yLine = linkedLine.YData;
        if fIdx <= numel(yLine)
            newY{j} = yLine(fIdx);
        else
            newY{j} = NaN;
        end
    end
end

% Vérification de cohérence
if numel(hMarkers) == numel(newX) && numel(newX) == numel(newY)
    set(hMarkers, {'XData'}, newX(:), {'YData'}, newY(:));
else
    % En cas d'erreur, fallback en mode boucle
    for j = 1:numel(hMarkers)
        set(hMarkers(j), 'XData', newX{j}, 'YData', newY{j});
    end
end
end


% function updateMarkers(hLineAll, fIdx, layoutOptions)
% % Met à jour la position des marqueurs en fonction de fIdx
% % en utilisant les données contenues dans les hLine (plus besoin de roiobj)
% 
% 
% if strcmp(class(hLineAll(1)),'matlab.graphics.primitive.Image') % don't update if traj mode is selected 
%     return
% end
% 
% % Identifier les marqueurs par leur style
% isMarker = arrayfun(@(h) strcmp(get(h, 'Marker'), 'o'), hLineAll);
% hMarkers = hLineAll(isMarker);
% 
% % Calculer nouvelle position X
% if layoutOptions.timeOffset
%     xMarker = (fIdx - layoutOptions.frames(1)) * layoutOptions.framerate;
% else
%     xMarker = fIdx * layoutOptions.framerate;
% end
% 
% % Mettre à jour chaque marqueur
% for j = 1:length(hMarkers)
%     linkedLine = hMarkers(j).UserData.LinkedLine;
% 
%     if isempty(linkedLine) || ~isgraphics(linkedLine)
%         warning('Marqueur #%d n''est pas lié à une ligne valide.', j);
%         continue;
%     end
% 
%     yLine = get(linkedLine, 'YData');
% 
%     if fIdx > length(yLine)
%         % warning('fIdx dépasse les données de la courbe liée au marqueur #%d.', j);
%         continue;
%     end
% 
%     yMarker = yLine(fIdx);
%     set(hMarkers(j), 'XData', xMarker, 'YData', yMarker);
% end
% 
% end

function updateDataPanels(ax, groupIdx, layoutOptions, currentframe, hLineAll, roiData)

dataIndices = layoutOptions.plotidx{groupIdx};
data = roiData.data(layoutOptions.dataidx{groupIdx});

% Extraction robuste (numeric + categorical) + infos ticks/labels
[ydata, ~, yTickInfo] = score_extractYData(data.data, dataIndices);

% X axis
xdata = (1:size(ydata,1)) * layoutOptions.framerate;

if layoutOptions.timeOffset
    xdata = xdata - layoutOptions.frames(1) * layoutOptions.framerate;
    keep = xdata >= 0;
    xdata = xdata(keep);
    ydata = ydata(keep, :);

    % frame relatif dans les données tronquées
    currentframe_rel = currentframe - layoutOptions.frames(1) + 1;
else
    currentframe_rel = currentframe;
end

[movieXLim, clipToMovie] = localMovieXLimits(layoutOptions);
if clipToMovie
    keepMovie = xdata >= movieXLim(1) & xdata <= movieXLim(2);
    if any(keepMovie)
        xdata = xdata(keepMovie);
        ydata = ydata(keepMovie, :);
    end
end

% ------------------------------------------------------------
% 1) Mettre à jour uniquement les "vraies" lignes (pas les markers)
% ------------------------------------------------------------
lineIdx = find(arrayfun(@(h) isgraphics(h) && isa(h, 'matlab.graphics.chart.primitive.Line'), hLineAll));
nLines = min(numel(lineIdx), size(ydata,2));

for i = 1:nLines
    h = hLineAll(lineIdx(i));
    set(h, 'XData', xdata, 'YData', ydata(:, i));
end

% ------------------------------------------------------------
% 2) Mettre à jour les marqueurs (leurs positions), si présents
% ------------------------------------------------------------
markerIdx = find(arrayfun(@(h) isgraphics(h) && isa(h, 'matlab.graphics.chart.primitive.Line') && ...
    ~isempty(h.Marker) && h.Marker ~= "none", hLineAll));

if ~isempty(markerIdx) && ~isempty(layoutOptions.frames)
    cc = 1;
    for k = 1:length(layoutOptions.frames)
        fIdx = layoutOptions.frames(k);

        if layoutOptions.timeOffset
            xMarker = (fIdx - layoutOptions.frames(1)) * layoutOptions.framerate;
            fRel = fIdx - layoutOptions.frames(1) + 1;
        else
            xMarker = fIdx * layoutOptions.framerate;
            fRel = fIdx;
        end

        markerIdxInData = [];
        if clipToMovie
            [~, markerIdxInData] = min(abs(xdata - xMarker));
            if isempty(markerIdxInData) || abs(xdata(markerIdxInData) - xMarker) > max(eps, 0.5 * layoutOptions.framerate)
                markerIdxInData = [];
            end
        elseif fRel >= 1 && fRel <= size(ydata,1)
            markerIdxInData = fRel;
        end

        if ~isempty(markerIdxInData)
            for j = 1:nLines
                if cc <= numel(markerIdx)
                    hm = hLineAll(markerIdx(cc));
                    set(hm, 'XData', xMarker, 'YData', ydata(markerIdxInData, j), ...
                        'MarkerSize', max(4, floor(0.6 * layoutOptions.fontSize)));
                    cc = cc + 1;
                end
            end
        end
    end
end

% ------------------------------------------------------------
% 3) Si c'est un panel categorical, forcer Y ticks/labels stables
%    (on prend la 1ère colonne comme référence)
% ------------------------------------------------------------
if ~isempty(yTickInfo) && ~isempty(yTickInfo.isLabel) && any(yTickInfo.isLabel)
    % Si plusieurs colonnes, on utilise la première qui a un mapping
    ref = find(yTickInfo.isLabel, 1, 'first');
    if ~isempty(ref) && ~isempty(yTickInfo.ticks) && ~isempty(yTickInfo.labels)
        yticks(ax, yTickInfo.ticks);
        yticklabels(ax, yTickInfo.labels);
        ylim(ax, [min(yTickInfo.ticks)-0.5, max(yTickInfo.ticks)+0.5]);
        set(ax, 'YTickMode', 'manual', 'YTickLabelMode', 'manual');
    end
end

% ------------------------------------------------------------
% 4) Opacité mode trajectoire / ou tracking XLim
% ------------------------------------------------------------
if isgraphics(hLineAll(1)) && isa(hLineAll(1), 'matlab.graphics.primitive.Image')
    % Mode trajectoire
    Nframes = size(hLineAll(1).CData, 2);
    alphaVec = ones(1, Nframes);

    if clipToMovie && ~isempty(xdata)
        if layoutOptions.timeOffset
            currentX = (currentframe - layoutOptions.frames(1)) * layoutOptions.framerate;
        else
            currentX = currentframe * layoutOptions.framerate;
        end
        [~, currentframe_rel] = min(abs(xdata - currentX));
    end

    if currentframe_rel <= Nframes
        alphaVec(currentframe_rel:end) = 0.2;
    end

    alphaImage = repmat(alphaVec, size(hLineAll(1).CData,1), 1);
    hLineAll(1).AlphaData = alphaImage;

else
    % Mode courbes: tracking XLim
    framerate = layoutOptions.framerate;

    if clipToMovie
        aMin = movieXLim(1);
        aMax = movieXLim(2);
    elseif isfield(layoutOptions, 'track') && layoutOptions.track && ~strcmpi(layoutOptions.mode, 'sequence')
        aMin = (currentframe_rel - layoutOptions.trackWindow) * framerate;
        aMax = (currentframe_rel + layoutOptions.trackWindow) * framerate;
    else
        lims = ax.UserData.xlim;
        if ischar(lims) && strcmp(lims, 'auto')
            xdatas = get(hLineAll(lineIdx(1:nLines)), {'XData'});
            allX = horzcat(xdatas{:});
            if isempty(allX), return; end
            xmin = min(allX); xmax = max(allX);
            xmin = xmin - 0.01 * abs(xmin);
            xmax = xmax + 0.01 * abs(xmax);
            aMin = xmin; aMax = xmax;
        else
            aMin = lims(1); aMax = lims(2);
        end
    end

    if ~isequal(ax.XLim, [aMin, aMax])
        xlim(ax, [aMin, aMax]);
    end
end

end


