function updateRender(graphicsHandles, roiobj, layoutOptions, displayHandles,newframe)
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

mode = lower(layoutOptions.mode);
switch mode
    case 'display'
        % Mode DISPLAY : mise à jour de la ROI affichée (roiobj(1)).
        roiData = roiobj(1);

        layoutOptions.frames=newframe;

        displayImage=score_makeComposite(roiobj(1),1,layoutOptions);

        MasterCols = displayHandles.MasterCols;


        if layoutOptions.overlay
            tileIndex = 1;
            %    aa= graphicsHandles.imgHandles(tileIndex);
            set(graphicsHandles.imgHandles(tileIndex), 'CData', displayImage);
        else
            for ch = 1:layoutOptions.Nchannel
                local_row = 1;
                local_col = (ch-1)*layoutOptions.Nbrick + 1;
                tileIndex = (local_row-1)*MasterCols + local_col;
                newImg = displayImage(:,:,:,ch);
                %  aa= graphicsHandles.imgHandles(tileIndex);
                set(graphicsHandles.imgHandles(tileIndex), 'CData', newImg);
            end
        end
        % Mise à jour des dataseries
        if layoutOptions.Ndataseries > 0 && ~isempty(roiData.data)
            for ds = 1:layoutOptions.Ndataseries
                local_row = layoutOptions.Nbrick + ds;
                local_col = 1;
                tileIndex = (local_row-1)*MasterCols + local_col;
                %   set(graphicsHandles.lineHandles(tileIndex), 'YData', roiData.data(ds, :));
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
                        set(graphicsHandles.imgHandles(tileIndex), 'CData', displayImage(:,:,:,ch));
                        ax=graphicsHandles.imgHandles(tileIndex); ax=ax.Parent;

                        [htext, hvector]=displayVectorGraphics(ax, newframe, 1, vContours , layoutOptions);
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

                            [htext, hvector]=displayVectorGraphics(ax, newframe, ch, vContours , layoutOptions);
                            graphicsHandles.vectorHandles(tileIndex)=[htext hvector];
                        end

                    end
                end

                % Mise à jour des dataseries (supposées inchangées d'une frame à l'autre)
                if layoutOptions.Ndataseries > 0 && ~isempty(roiData.data)
                    if layoutOptions.overlay
                        base_row = layoutOptions.Nbrick;
                    else
                        base_row = layoutOptions.Nchannel * layoutOptions.Nbrick;
                    end
                    local_row = base_row + 1;
                    local_col = 1;
                    if layoutOptions.overlay
                        ROI_col_offset = (j-1) * layoutOptions.Nbrick;
                    else
                        ROI_col_offset = (j-1) * (layoutOptions.Nchannel * layoutOptions.Nbrick);
                    end
                    global_row = ROI_row_offset + local_row;
                    global_col = ROI_col_offset + local_col;
                    tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                    if isKey(graphicsHandles.lineHandles, tileIndex)
                        %      set(graphicsHandles.lineHandles(tileIndex), 'YData', roiData.data(1, :));
                    end
                end
            end
        end

    case 'sequence'
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

function [htext, hvector]= displayVectorGraphics(ax, f, ch, vContours , param)
% Affiche les textes et contours vectoriels sur l'image.
frames = param.frames;
scalingFactor = param.scalingFactor;
fontsize = param.fontSize;
hideStamp = param.hideStamp;
timeoffset = param.timeOffset;
framerate = param.framerate;
textColor = param.textColor;
hold(ax, 'on');

htext=[];
hvector=[];

if ch == 1 && ~hideStamp
    if timeoffset
        ts = [num2str((frames(f)-frames(1))*framerate) 'min'];
    else
        ts = [num2str(frames(f)*framerate) 'min'];
    end
    htext=text(ax, 0.01, 0.99, ts, 'FontName', 'Arial', 'FontSize', floor(sqrt(scalingFactor)*fontsize), ...
        'Color',textColor, 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');
end

vc = vContours;
cc=1;
for k = 1:length(vc)
    if ~isempty(vc(k).x) && all(isfinite(vc(k).x)) && all(isfinite(vc(k).y)) && all(vc(k).LineWidth(:) > 0)
        faceColor = double(vc(k).FaceColor); if any(faceColor > 1), faceColor = faceColor/255; end
        faceAlpha = double(vc(k).FaceAlpha);
        patchArgs = {'XData', vc(k).x, 'YData', vc(k).y, 'FaceColor', faceColor, 'FaceAlpha', faceAlpha};
        if ~(ischar(vc(k).EdgeColor) && strcmp(vc(k).EdgeColor, 'none')) && ~isempty(vc(k).LineWidth)
            edgeColor = double(vc(k).EdgeColor); if any(edgeColor > 1), edgeColor = edgeColor/255; end
            patchArgs = [patchArgs, {'EdgeColor', edgeColor, 'LineWidth', double(vc(k).LineWidth)}];
        else
            patchArgs = [patchArgs, {'LineStyle', 'none'}];
        end

        hvector(cc)=patch(ax, patchArgs{:});
        cc=cc+1;
    end
end
hold(ax, 'off');
end


