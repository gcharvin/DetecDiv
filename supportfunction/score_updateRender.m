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

            h = graphicsHandles.imgHandles(tileIndex);
            if ~isequal(get(h, 'CData'), displayImage)
                set(h, 'CData', displayImage);
            end

            h = graphicsHandles.overlayHandles(tileIndex);
            if ~isequal(get(h, 'CData'), indexedOverlay)
                set(h, 'CData', indexedOverlay);
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
                set(graphicsHandles.imgHandles(tileIndex), 'CData', newImg);


                set(graphicsHandles.overlayHandles(tileIndex),'CData', indexedOverlay);
                set(graphicsHandles.overlayHandles(tileIndex), 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
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
                updateMarkers(hLineAll, newframe , layoutOptions);
                updateDataPanels(ax,layoutOptions,newframe,hLineAll);
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

        for i = 1:layoutOptions.Nrow
            for j = 1:layoutOptions.Ncol

                roiIndex = (i-1)*layoutOptions.Ncol + j;
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
                        set(graphicsHandles.imgHandles(tileIndex), 'CData', displayImage);
                    end

                    if isKey(graphicsHandles.imgHandles, tileIndex)
                        set(graphicsHandles.imgHandles(tileIndex), 'CData', displayImage(:,:,:,1));
                        ax=graphicsHandles.imgHandles(tileIndex); ax=ax.Parent;

                        [htext, hvector]=score_displayVectorGraphics(ax, newframe, 1, vContours , layoutOptions);
                        graphicsHandles.vectorHandles(tileIndex)=[htext hvector];
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
                            set(graphicsHandles.imgHandles(tileIndex), 'CData', displayImage(:,:,:,ch));
                            ax=graphicsHandles.imgHandles(tileIndex); ax=ax.Parent;

                            [htext, hvector]=score_displayVectorGraphics(ax, newframe, ch, vContours , layoutOptions);
                            graphicsHandles.vectorHandles(tileIndex)=[htext hvector];
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
                        updateMarkers(hLineAll, newframe , layoutOptions);
                        updateDataPanels(ax,layoutOptions,newframe,hLineAll);

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
end

function updateMarkers(hLineAll, fIdx, layoutOptions)
% Version optimisée : mise à jour des marqueurs avec moins d'accès graphiques

if isa(hLineAll(1), 'matlab.graphics.primitive.Image')  % Mode image/traj => pas de marqueurs
    return
end

% Identifier les marqueurs (style 'o')
markerIdx = arrayfun(@(h) strcmp(h.Marker, 'o'), hLineAll);
hMarkers = hLineAll(markerIdx);

% Préparer X coordonnée des marqueurs
if layoutOptions.timeOffset
    xMarker = (fIdx - layoutOptions.frames(1)) * layoutOptions.framerate;
else
    xMarker = fIdx * layoutOptions.framerate;
end

% Préparer les nouvelles positions (XData, YData)
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

% Appliquer d'un coup (évite les boucles `set` répétées)
set(hMarkers, {'XData'}, newX, {'YData'}, newY);
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

function updateDataPanels(ax, layoutOptions, currentframe, hLineAll)

if isa(hLineAll(1), 'matlab.graphics.primitive.Image')  % Mode trajectoire
    Nframes = size(hLineAll.CData, 2);
    alphaVec = ones(1, Nframes);
    if currentframe <= Nframes
        alphaVec(currentframe:end) = 0.2;  % faible opacité à droite
    end
    alphaImage = repmat(alphaVec, size(hLineAll.CData,1), 1);
    hLineAll.AlphaData = alphaImage;
else  % Mode courbes
    framerate = layoutOptions.framerate;

    % Tracking automatique
    if isfield(layoutOptions, 'track') && layoutOptions.track && ~strcmpi(layoutOptions.mode, 'sequence')
        aMin = (currentframe - layoutOptions.trackWindow) * framerate;
        aMax = (currentframe + layoutOptions.trackWindow) * framerate;
    else
        lims = ax.UserData.xlim;
        if ischar(lims) && strcmp(lims, 'auto')
            % Optimisation : utiliser hLineAll directement au lieu de `findall`
            xdatas = get(hLineAll, {'XData'});
            allX = horzcat(xdatas{:});

            if isempty(allX)
                return
            end

            xmin = min(allX);
            xmax = max(allX);

            % Petit padding
            xmin = xmin - 0.01 * abs(xmin);
            xmax = xmax + 0.01 * abs(xmax);

            aMin = xmin;
            aMax = xmax;
        else
            aMin = lims(1);
            aMax = lims(2);
        end
    end

    % Ne mettre à jour que si nécessaire
    if ~isequal(ax.XLim, [aMin, aMax])
        xlim(ax, [aMin, aMax]);
    end
end
end


% function updateDataPanels(ax,layoutOptions,currentframe,hLineAll)
% 
% 
% if strcmp(class(hLineAll(1)),'matlab.graphics.primitive.Image') % traj mode
% 
%     Nframes=size(hLineAll.CData,2);
%     alphaVec = ones(1, Nframes);           % tout transparent par défaut
% 
% if currentframe <= Nframes
%     alphaVec(currentframe:end) = 0.2;      % 20% d’opacité à droite
% end
% 
% alphaImage = repmat(alphaVec, size(hLineAll.CData,1), 1);
% set(hLineAll,'AlphaData',alphaImage);
% 
% else % plot mode 
% 
% framerate=layoutOptions.framerate;
% 
% track=false;
% if layoutOptions.track
%     if layoutOptions.mode~="Sequence"
%         track=true;
%     end
% end
% 
% if track
%     amin=(currentframe-layoutOptions.trackWindow)*framerate;
%     amax=(currentframe+layoutOptions.trackWindow)*framerate;
%    % ax.UserData.xlim=[amin amax];
% else % no tracking mode
%     lims=ax.UserData.xlim;
% 
%     if ischar(lims) & lims=="auto"
% 
%         lines = findall(ax, 'Type', 'line');  % Trouve tous les objets 'line' dans l'axe
% 
%         if isempty(lines)
%             warning('Aucune courbe trouvée dans cet axe.');
%             xmin = NaN;
%             xmax = NaN;
%             return;
%         end
% 
%         allX = [];
% 
%         for k = 1:length(lines)
%             xdata = get(lines(k), 'XData');
%             allX = [allX, xdata]; %#ok<AGROW> % Concatène tous les X
%         end
% 
%         xmin = min(allX);
%         xmax = max(allX);
% 
%         if xmin>0
%             xmin=0.95*xmin-0.01;
%         else
%             xmin=1.05*xmin-0.01;
%         end
% 
%         if xmax>0
%             xmax=0.95*xmax-0.01;
%         else
%             xmax=1.05*xmax+0.01;
%         end
% 
% 
%     else
% 
%         xmin=ax.UserData.xlim(1);
%         xmax=ax.UserData.xlim(2);
%     end
% 
%     amin=xmin;
%     amax=xmax;
% 
% end
% 
% xlim(ax,  [amin amax]);
% 
% end
% end