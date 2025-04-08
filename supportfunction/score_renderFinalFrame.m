function graphicsHandles = score_renderFinalFrame(displayHandles, roiobj, layoutOptions)
% renderFinalFrame Affiche le rendu initial dans le master tiledlayout et
% retourne la structure graphicsHandles contenant les handles graphiques.
%
% Chaque objet de roiobj possède :
%   - image : matrice 4D [imgX, imgY, Nchannel, Nframes]
%   - data  : matrice [Ndataseries, Nframes] (peut être vide)
%
% Modes :
%   - 'sequence' : Affichage de toutes les ROI dans une grille avec le layout
%                  traditionnel (frames en colonnes). À la fin, export PDF.
%
%   - 'display'  : Affichage d'une seule ROI en mode display. Pour overlay=true,
%                  les canaux sont combinés (affichage composite) ; sinon, chaque
%                  canal est affiché dans une tuile. La figure reste visible et
%                  un axe overlay transparent est ajouté (pour stacking).
%
%   - 'movie'    : Affichage de plusieurs ROI dans une grille (layout identique à
%                  "display" pour chaque ROI). Une boucle parcourt les frames et
%                  capture le rendu avec print pour générer un fichier MP4.
%
% Le master tiledlayout a été créé avec 'TileSpacing','none' et 'Padding','none'.

masterTL = displayHandles.masterTiledLayout;
% Initialisation des containers pour stocker les handles
graphicsHandles.imgHandles     = containers.Map('KeyType','double','ValueType','any');
graphicsHandles.lineHandles    = containers.Map('KeyType','double','ValueType','any');
graphicsHandles.overlayHandles = containers.Map('KeyType','double','ValueType','any');
graphicsHandles.vectorHandles = containers.Map('KeyType','double','ValueType','any');

% find number of image rows and columns
% Définir le nombre de lignes d’images par ROI et le nombre de canaux

scalingFactor=layoutOptions.scalingFactor;
textColor=layoutOptions.textColor;
channel=layoutOptions.channel;
fontsize=layoutOptions.fontSize;

switch lower(displayHandles.mode)
    case 'sequence'
        % --- Mode SEQUENCE ---
        ROI_cols = displayHandles.ROI_cols; % ROI_cols = Nframes * Nbrick (sequence)
        for i = 1:layoutOptions.Nrow
            for j = 1:layoutOptions.Ncol
                roiIndex = (i-1)*layoutOptions.Ncol + j;
                roiData = roiobj(roiIndex);

                ROI_row_offset = (i-1) * displayHandles.ROI_rows;
                ROI_col_offset = (j-1) * displayHandles.ROI_cols;
                if layoutOptions.overlay
                    % Combine les canaux pour chaque frame.
                    for frame = 1:numel(layoutOptions.frames)
                       % curframe=layoutOptions.frames(frame);

                        [displayImage, vContours]=score_makeComposite(roiData,frame,layoutOptions);

                        local_row = 1;  % Une seule rangée pour le composite
                        local_col = (frame-1)*layoutOptions.Nbrick + 1;
                        global_row = ROI_row_offset + local_row;
                        global_col = ROI_col_offset + local_col;
                        tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                        ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);
                        
                        imshow(displayImage, []);

                      %  displayVectorGraphics(ax, frame, 1, vContours , layoutOptions);
                          [htext, hvector]=score_displayVectorGraphics(ax, frame, 1, vContours , layoutOptions);
                           graphicsHandles.vectorHandles(tileIndex)=[htext hvector];

                     %   title(sprintf('ROI(%d) F:%d', roiIndex, frame));
                        graphicsHandles.imgHandles(tileIndex) = ax.Children;
                    end
                else
                    % Chaque canal séparé : layout classique.
                        for frame = 1:numel(layoutOptions.frames)
                             for ch = 1:layoutOptions.Nchannel

                             curframe=layoutOptions.frames(frame);

                              [displayImage, vContours]=score_makeComposite(roiData,frame,layoutOptions);

                            local_row = (ch-1)*layoutOptions.Nbrick + 1;
                            local_col = (frame-1)*layoutOptions.Nbrick + 1;
                            global_row = ROI_row_offset + local_row;
                            global_col = ROI_col_offset + local_col;
                            tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                            ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);

                          %  img = roiData.image(:,:,ch,frame);
                            imshow(displayImage(:,:,:,ch), []);
                             [htext, hvector]=score_displayVectorGraphics(ax, frame, ch, vContours , layoutOptions);
                            graphicsHandles.vectorHandles(tileIndex)=[htext hvector];
                          %  title(sprintf('ROI(%d) Ch:%d F:%d', roiIndex, ch, frame));
                            graphicsHandles.imgHandles(tileIndex) = ax.Children;
                               if frame == 1
                            ylabel(ax, layoutOptions.channel{ch}, 'FontName', 'Arial', ...
                                'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', textColor);
                               end

                        end
                    end
                end

                % Dataseries pour cette ROI.
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
                        ax = nexttile(masterTL, tileIndex, [1, displayHandles.ROI_cols]);
                       hLine= score_displayDataPanel(ax, ds, layoutOptions, roiData);
   
                       % title(sprintf('ROI(%d) Data:%d', roiIndex, ds));
                        graphicsHandles.lineHandles(tileIndex) = hLine;
                    end
                end
                if layoutOptions.debug
                    fprintf('DEBUG: ROI %d rendered.\n', roiIndex);
                end
            end
        end
        % Export en PDF
        outputPath = fullfile(pwd, 'output_sequence.pdf');
        exportgraphics(masterTL, outputPath, 'ContentType', 'vector');
        fprintf('Sequence saved as PDF: %s\n', outputPath);

    case 'display'
        % --- Mode DISPLAY ---
        % Ici, on affiche une seule ROI avec layout display.

        roiData=roiobj(1);
       % displayImage=score_makeComposite(roiData,1,layoutOptions);
        [displayImage, vContours, indexedOverlay, alphaOverlay]=score_makeComposite(roiData,1,layoutOptions);

       % figure, imshow(alphaOverlay,[]);

        if layoutOptions.overlay
            % Si overlay true, on combine les canaux.
            tileIndex = 1;
            % Pour display overlay, le master layout a :
            % Lignes = Nbrick + Ndataseries, Colonnes = Nbrick.
            ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);
            %compositeImg = max(roiData.image, [], 3);
            imshow(displayImage, []);
          %  title('Overlay Composite');
            graphicsHandles.imgHandles(tileIndex) = ax.Children;
            % Ajout d'un axe overlay transparent.
            pos = get(ax, 'Position');
            axOverlay = axes('Position', pos, 'Color', 'none', 'XTick', [], 'YTick', []);
            set(axOverlay, 'HitTest', 'off');
            uistack(axOverlay, 'top');

             hOverlay=imshow(indexedOverlay, 'Parent', axOverlay, 'InitialMagnification', 'fit');
             hOverlay.Tag = 'IndexedOverlay';
             set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
%             axImg.UserData.OverlayHandle = hOverlay;
          %  axOverlay.UserData.CDataHandle=
            graphicsHandles.overlayHandles(tileIndex) = axOverlay.Children;
        
        else
            % Si overlay false, chaque canal est affiché.
            for ch = 1:layoutOptions.Nchannel
                local_row = 1;
                local_col = (ch-1)*layoutOptions.Nbrick + 1;
                tileIndex = (local_row-1)*displayHandles.MasterCols + local_col;
                ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);
                img = displayImage(:,:,:,ch);
                imshow(img, []);
            %    title(sprintf('Ch:%d', ch));
                graphicsHandles.imgHandles(tileIndex) = ax.Children;
                % Ajout d'un axe overlay transparent sur chaque tuile.
                pos = get(ax, 'Position');
                axOverlay = axes('Position', pos, 'Color', 'none', 'XTick', [], 'YTick', []);
                set(axOverlay, 'HitTest', 'off');
                uistack(axOverlay, 'top');

                hOverlay=imshow(indexedOverlay, 'Parent', axOverlay, 'InitialMagnification', 'fit');
                hOverlay.Tag = 'IndexedOverlay';
                set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');

                graphicsHandles.overlayHandles(tileIndex) = axOverlay.Children;
            end

        end
        % Dataseries en dessous
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
                     if layoutOptions.Ndataseries>1 && ds~=layoutOptions.Ndataseries
                       set(ax,'XTickLabel',[]);
                     %   'ok'
                      else
                    set(ax, 'XTickLabelRotation', 0);  % ou 0, selon ton style
                      end
                           if ~isa(ax.YAxis, 'matlab.graphics.axis.decorator.CategoricalRuler')
                            ytickformat(ax, '%.1f');
                      end

                        xtickformat(ax, '%.1f');

                hLine= score_displayDataPanel(ax, ds, layoutOptions, roiData);
                %  hLine = plot(roiData.data(ds, :));
                %   title(sprintf('Data:%d', ds));
                  graphicsHandles.lineHandles(tileIndex) = hLine;
            end
        end

    case 'movie'
        % --- Mode MOVIE ---
        % En mode movie, plusieurs ROI sont affichées en grille.
        % Pour chaque ROI, le layout interne est identique à celui de display.
        % MasterRows = Nrow*(Nbrick+Ndataseries), MasterCols = Ncol*(
        %   - Si overlay true : Nbrick
        %   - Sinon : Nchannel*Nbrick )
        for i = 1:layoutOptions.Nrow
            for j = 1:layoutOptions.Ncol
                roiIndex = (i-1)*layoutOptions.Ncol + j;
                roiData = roiobj(roiIndex);
                ROI_row_offset = (i-1) * (layoutOptions.Nbrick + layoutOptions.Ndataseries);
                if layoutOptions.overlay
                    ROI_col_offset = (j-1) * layoutOptions.Nbrick;
                else
                    ROI_col_offset = (j-1) * (layoutOptions.Nchannel * layoutOptions.Nbrick);
                end
                if layoutOptions.overlay
                    % Affichage composite pour chaque ROI.
                    local_row = 1;
                    local_col =   1;
                    global_row = ROI_row_offset + local_row;
                    global_col = ROI_col_offset + local_col;
                    tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;

                    ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);
                   % compositeImg = max(roiData.image, [], 3);

                    [displayImage, vContours]=score_makeComposite(roiData,1,layoutOptions);


                    imshow(displayImage, []);
                  
                     [htext, hvector]=score_displayVectorGraphics(ax, 1, 1, vContours , layoutOptions);

                     graphicsHandles.vectorHandles(tileIndex)=[htext hvector];

                    %title(sprintf('ROI(%d) Overlay', roiIndex));
        

                      imageHandles = ax.Children(strcmp(get(ax.Children, 'Type'), 'image'));
                    graphicsHandles.imgHandles(tileIndex) =  imageHandles;
                else
                    % Affichage de chaque canal séparément.
                    for ch = 1:layoutOptions.Nchannel
                        local_row = 1;
                        local_col = (ch-1)*layoutOptions.Nbrick + 1;
                        global_row = ROI_row_offset + local_row;
                        global_col = ROI_col_offset + local_col;
                        tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                        ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);
                        [displayImage, vContours]=score_makeComposite(roiData,1,layoutOptions);
                      %  img = roiData.image(:,:,ch,1);
                        imshow(displayImage(:,:,:,ch), []);
                      %  title(sprintf('ROI(%d) Ch:%d', roiIndex, ch));
                   
                         [htext, hvector]=score_displayVectorGraphics(ax, 1, ch, vContours , layoutOptions);
                         
                        graphicsHandles.vectorHandles(tileIndex)=[htext hvector];
                        
                     imageHandles = ax.Children(strcmp(get(ax.Children, 'Type'), 'image'));
                    graphicsHandles.imgHandles(tileIndex) =  imageHandles;
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
                        xtickformat(ax, '%.1f');
                        ytickformat(ax, '%.1f');

                           if layoutOptions.Ndataseries>1 && ds~=layoutOptions.Ndataseries
                       set(ax,'XTickLabel',[]);
                     %   'ok'
                      else
                    set(ax, 'XTickLabelRotation', 0);  % ou 0, selon ton style
                      end

                        hLine= score_displayDataPanel(ax, ds, layoutOptions, roiData);
                %  hLine = plot(roiData.data(ds, :));
                %   title(sprintf('Data:%d', ds));
                       graphicsHandles.lineHandles(tileIndex) = hLine;

                     %   hLine = plot(roiData.data(ds, :));
                     %   title(sprintf('Data:%d', ds));
                     %   graphicsHandles.lineHandles(tileIndex) = hLine;
                    end
                end
                if layoutOptions.debug
                    fprintf('DEBUG: ROI %d rendered in movie mode.\n', roiIndex);
                end
            end
        end
        
        % Vidéo setup avec VideoWriter.
        outputMoviePath = fullfile(pwd, 'output_movie.mp4');
        v = VideoWriter(outputMoviePath, 'MPEG-4');
        v.FrameRate = 10;  % Ajustez le FrameRate selon vos besoins.
        open(v);
        fig = get(masterTL, 'Parent');
        set(fig, 'Visible', 'off','InvertHardcopy', 'off');

        for frame = 1:numel(layoutOptions.frames)
            score_updateRender(graphicsHandles, roiobj, layoutOptions, displayHandles,frame)
            rgbImage = print(fig, '-RGBImage');
            disp(['Rendering frame ' num2str(frame) ' / ' num2str(numel(layoutOptions.frames))])
            writeVideo(v, im2frame(rgbImage));
        end

        close(v);
        fprintf('Movie saved as MP4: %s\n', outputMoviePath);
end


% % --- Lignes de séparation verticales ---
% % Pour les images, la boucle dépend du mode : en Sequence on a numel(frames) colonnes, en Display nChannel colonnes.
%
% if overlayMode
%     imageRows = 1;
%     nChannel = 1;
% else
%    switch lower(displayHandles.mode)
%        case "sequence"
%             imageRows = layoutOptions.Nchannel;
%              nDiv = numel(frames);
%         case "display"
%             nChannel = nlayoutOptions.Nchannel;
%             imageRows = 1;
%             nDiv = nChannel;
%         case "movie"
%              imageRows = 1;
%               nChannel = nlayoutOptions.Nchannel;
%             % À compléter si besoin
%                   nDiv = nChannel;
%     end
% end
%
% drawLineWidth = 2; %* scalingFactor;
% globalPos = masterTL.OuterPosition;
% convertPos = @(p) [ globalPos(1) + p(1)*globalPos(3), ...
%                     globalPos(2) + p(2)*globalPos(4), ...
%                     p(3)*globalPos(3), p(4)*globalPos(4) ];
% % Boucle uniquement sur les lignes d'images (hors panels de données)
% for r = 1:nRows_ROI
%     for i = 1:imageRows
%          globalRow = (r-1) * (imageRows + dataRows) + i;
%          for c = 1:nCols_ROI
%               for f = 1:(nDiv-1)
%                    tileIndex = (globalRow - 1)*globalCols + ((c-1)*nDiv + f);
%                    ax = nexttile(tGlobal, tileIndex);
%                    pRel = get(ax, 'Position');
%                    pFig = convertPos(pRel);
%                    xLine = pFig(1) + pFig(3) - 0.005;
%                    yBot = pFig(2);
%                    yTop = pFig(2) + pFig(4);
%                    annotation(hFig, 'line', [xLine xLine], [yBot-0.01 yTop+0.01], ...
%                               'Color', background, 'LineWidth', drawLineWidth);
%               end
%          end
%     end
% end


end







