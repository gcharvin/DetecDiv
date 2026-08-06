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
graphicsHandles.dataAxes       = containers.Map('KeyType','double','ValueType','any');
graphicsHandles.overlayHandles = containers.Map('KeyType','double','ValueType','any');
graphicsHandles.vectorHandles = containers.Map('KeyType','double','ValueType','any');
graphicsHandles.textHandles = containers.Map('KeyType','double','ValueType','any');
graphicsHandles.scaleBarHandles = containers.Map('KeyType','double','ValueType','any');
graphicsHandles.axesLink = [];


graphicsHandles.lineageHandles = containers.Map('KeyType','double','ValueType','any');
% find number of image rows and columns
% Définir le nombre de lignes d’images par ROI et le nombre de canaux

scalingFactor=layoutOptions.scalingFactor;
textColor=layoutOptions.textColor;
channel=layoutOptions.channel;
fontsize=layoutOptions.fontSize;
outputname=layoutOptions.name;

axarray=[];

switch lower(displayHandles.mode)
    case 'sequence'
        % --- Mode SEQUENCE ---
        ROI_cols = displayHandles.ROI_cols; % ROI_cols = Nframes * Nbrick (sequence)

        for i = 1:layoutOptions.Nrow
            for j = 1:layoutOptions.Ncol

                roiIndex = (i-1)*layoutOptions.Ncol + j;

                if roiIndex>numel(roiobj)
                    continue
                end

                roiData = roiobj(roiIndex);

                 ROI_row_offset = (i-1) * displayHandles.ROI_rows;
                 ROI_col_offset = (j-1) * displayHandles.ROI_cols;

                if layoutOptions.overlay
                    % Combine les canaux pour chaque frame.
                    for frame = 1:numel(layoutOptions.frames)
                        curframe=layoutOptions.frames(frame);



                        [displayImage, vContours]=score_makeComposite(roiData,frame,layoutOptions);


                        local_row = 1;  % Une seule rangée pour le composite
                        local_col = (frame-1)*layoutOptions.Nbrick + 1;
                        global_row = ROI_row_offset + local_row;
                        global_col = ROI_col_offset + local_col;
                        tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                        ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);

                        hImg = imshow(displayImage, []);
                        score_drawMovieEventText(ax, layoutOptions, curframe);

                        [htext, hvector]=score_displayVectorGraphics(ax, frame, 1, vContours , layoutOptions);

                        drawSeparationLines(ax,layoutOptions)

                        graphicsHandles.vectorHandles(tileIndex)=[htext hvector];

                        %   title(sprintf('ROI(%d) F:%d', roiIndex, frame));
                        graphicsHandles.imgHandles(tileIndex) = hImg;

                        if frame==1 && layoutOptions.ROITitle
                                title(ax,roiData.id,'Color',textColor,'Interpreter','none','FontSize', floor(sqrt(scalingFactor)*fontsize));
                        end
                    end
                else
                    % Chaque canal séparé : layout classique.
                    for frame = 1:numel(layoutOptions.frames)
                        [displayImage, vContours]=score_makeComposite(roiData,frame,layoutOptions);
                        for ch = 1:layoutOptions.Nchannel

                            curframe=layoutOptions.frames(frame);

                            local_row = (ch-1)*layoutOptions.Nbrick + 1;
                            local_col = (frame-1)*layoutOptions.Nbrick + 1;
                            global_row = ROI_row_offset + local_row;
                            global_col = ROI_col_offset + local_col;
                            tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                            ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);

                            %  img = roiData.image(:,:,ch,frame);
                            hImg = imshow(displayImage(:,:,:,ch), []);
                            if ch == 1
                                score_drawMovieEventText(ax, layoutOptions, curframe);
                            end
                            [htext, hvector]=score_displayVectorGraphics(ax, frame, ch, vContours , layoutOptions);
                            if frame == numel(layoutOptions.frames)
                                hScale = score_drawChannelScaleBar(ax, layoutOptions, ch);
                                if ~isempty(hScale)
                                    graphicsHandles.scaleBarHandles(tileIndex) = hScale;
                                end
                            end
                            drawSeparationLines(ax,layoutOptions);
                            graphicsHandles.vectorHandles(tileIndex)=[htext hvector];
                            %  title(sprintf('ROI(%d) Ch:%d F:%d', roiIndex, ch, frame));
                            graphicsHandles.imgHandles(tileIndex) = hImg;
                            if frame == 1
                                ylabel(ax, score_wrapDisplayLabel(localChannelLabel_(layoutOptions, ch)), 'FontName', 'Arial', ...
                                    'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', textColor,'Interpreter','none');
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
                        graphicsHandles.dataAxes(tileIndex) = ax;
                    end
                end
                if layoutOptions.debug
                    fprintf('DEBUG: ROI %d rendered.\n', roiIndex);
                end
            end
        end

        try
        fseq = layoutOptions.frames;
          refreshLineageOverlays(graphicsHandles, roiobj, layoutOptions, displayHandles,fseq);
        catch ME
          %  warning('Lineage init failed: %s', ME.message);
        end


        
        % Export en PDF
        % on décompose en dossier, nom et extension
[folder, name, ~] = fileparts(outputname);
% on reconstruit le chemin avec la nouvelle extension
newPath = fullfile(folder, [name '.pdf']);

    %    outputPath = fullfile(pwd,newPath);
        drawnow;
        exportgraphics(displayHandles.Figure, newPath, 'ContentType', 'vector');
        fprintf('Sequence saved as PDF: %s\n', newPath);

    case 'display'
    
        % --- Mode DISPLAY ---
        % Ici, on affiche une seule ROI avec layout display.

        roiData=roiobj(1);
        % displayImage=score_makeComposite(roiData,1,layoutOptions);
        [displayImage, vContours, indexedOverlay, alphaOverlay]=score_makeComposite(roiData,1,layoutOptions);

        
        %   figure, imshow(displayImage,[]);
        % figure, imshow(alphaOverlay,[]);

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
                graphicsHandles.dataAxes(tileIndex) = ax;
            end
        end

        if layoutOptions.overlay
            % Si overlay true, on combine les canaux.
            tileIndex = 1;
            % Pour display overlay, le master layout a :
            % Lignes = Nbrick + Ndataseries, Colonnes = Nbrick.
            ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);
            set(ax, 'HitTest', 'off');
            axarray=[axarray ax];
            %compositeImg = max(roiData.image, [], 3);
            hImg = imshow(displayImage, []);
            %  title('Overlay Composite');
            graphicsHandles.imgHandles(tileIndex) = hImg;
            % Ajout d'un axe overlay transparent.
            pos = get(ax, 'Position');
            axOverlay = axes('Position', pos, 'Color', 'none', 'XTick', [], 'YTick', []);
            set(axOverlay, 'HitTest', 'off');
            uistack(axOverlay, 'top');

            axOverlay.XLim=ax.XLim;
            axOverlay.YLim=ax.YLim;

            % axOverlay, ax

            hOverlay=imshow(indexedOverlay, 'Parent', axOverlay, 'InitialMagnification', 'fit');
            hOverlay.Tag = 'IndexedOverlay';
            set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
            %             axImg.UserData.OverlayHandle = hOverlay;
            %  axOverlay.UserData.CDataHandle=
            graphicsHandles.overlayHandles(tileIndex) = hOverlay;
            hScale = localDrawChannelScaleBars(axOverlay, layoutOptions);
            if ~isempty(hScale)
                graphicsHandles.scaleBarHandles(tileIndex) = hScale;
            end
            axarray=[axarray axOverlay];
        else
            % Si overlay false, chaque canal est affiché.
            for ch = 1:layoutOptions.Nchannel
                local_row = 1;
                local_col = (ch-1)*layoutOptions.Nbrick + 1;
                tileIndex = (local_row-1)*displayHandles.MasterCols + local_col;
                ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);
                set(ax, 'HitTest', 'off');

                axarray=[axarray ax];
                img = displayImage(:,:,:,ch);
                hImg = imshow(img, []);
                %    title(sprintf('Ch:%d', ch));
                graphicsHandles.imgHandles(tileIndex) = hImg;
                % Ajout d'un axe overlay transparent sur chaque tuile.
                pos = get(ax, 'Position');
                axOverlay = axes('Position', pos, 'Color', 'none', 'XTick', [], 'YTick', []);
                set(axOverlay, 'HitTest', 'off');

                %ax.YTickLabel = repmat({''}, size(ax.YTick));  % masque les ticks
                %ax.XTickLabel = repmat({''}, size(ax.XTick));


                uistack(axOverlay, 'top');

                hOverlay=imshow(indexedOverlay, 'Parent', axOverlay, 'InitialMagnification', 'fit');
                hOverlay.Tag = 'IndexedOverlay';
                set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
                axOverlay.XLim = ax.XLim;
                axOverlay.YLim = ax.YLim;
                hScale = score_drawChannelScaleBar(axOverlay, layoutOptions, ch);
                if ~isempty(hScale)
                    graphicsHandles.scaleBarHandles(tileIndex) = hScale;
                end

                graphicsHandles.overlayHandles(tileIndex) = hOverlay;
                axarray=[axarray axOverlay];
            end

        end
        
                        % --- lineage overlay (init après création des overlays)
        try
        fseq = layoutOptions.frames;
          refreshLineageOverlays(graphicsHandles, roiobj, layoutOptions, displayHandles,fseq);
        catch ME
          %  warning('Lineage init failed: %s', ME.message);
        end

        if numel(axarray) > 1
            % linkaxes performs expensive axis-mode bookkeeping (several
            % seconds for a tiled image plus transparent overlay). Keeping
            % the returned linkprop alive provides the required pan/zoom
            % synchronization without that startup penalty.
            graphicsHandles.axesLink = linkprop(axarray, {'XLim','YLim'});
        end
        score_syncOverlayAxes(graphicsHandles);



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

                    if roiIndex>numel(roiobj)
                    continue
                    end

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


                    hImg = imshow(displayImage, []);

titleStr = score_wrapDisplayLabel(localBuildMovieRoiTitle_(layoutOptions, roiData), 28);
if strlength(titleStr) > 0
    text(ax, 0.99, 0.99, titleStr, ...
        'Units','normalized', ...
        'HorizontalAlignment','right', ...
        'VerticalAlignment','top', ...
        'Color', textColor, ...
        'FontSize', floor(sqrt(scalingFactor)*fontsize), ...
        'Interpreter','none', ...
        'Clipping','on');
end
score_drawMovieEventText(ax, layoutOptions, layoutOptions.frames(1));

hScale = localDrawChannelScaleBars(ax, layoutOptions);
if ~isempty(hScale)
    graphicsHandles.scaleBarHandles(tileIndex) = hScale;
end




                    [htext, hvector]=score_displayVectorGraphics(ax, 1, 1, vContours , layoutOptions);

                    graphicsHandles.vectorHandles(tileIndex)=[htext hvector];

                    %title(sprintf('ROI(%d) Overlay', roiIndex));


                    graphicsHandles.imgHandles(tileIndex) = hImg;
                else
                    % Affichage de chaque canal séparément.
                    [displayImage, vContours]=score_makeComposite(roiData,1,layoutOptions);
                    for ch = 1:layoutOptions.Nchannel
                        local_row = 1;
                        local_col = (ch-1)*layoutOptions.Nbrick + 1;
                        global_row = ROI_row_offset + local_row;
                        global_col = ROI_col_offset + local_col;
                        tileIndex = (global_row-1)*displayHandles.MasterCols + global_col;
                        ax = nexttile(masterTL, tileIndex, [layoutOptions.Nbrick, layoutOptions.Nbrick]);
                        %  img = roiData.image(:,:,ch,1);
                        hImg = imshow(displayImage(:,:,:,ch), []);
                        hScale = score_drawChannelScaleBar(ax, layoutOptions, ch);
                        if ~isempty(hScale)
                            graphicsHandles.scaleBarHandles(tileIndex) = hScale;
                        end

if ch == 1
    titleStr = score_wrapDisplayLabel(localBuildMovieRoiTitle_(layoutOptions, roiData), 28);
    if strlength(titleStr) > 0
        text(ax, 0.99, 0.99, titleStr, ...
            'Units','normalized', ...
            'HorizontalAlignment','right', ...
            'VerticalAlignment','top', ...
            'Color', textColor, ...
            'FontSize', floor(sqrt(scalingFactor)*fontsize), ...
            'Interpreter','none', ...
            'Clipping','on');
    end
    score_drawMovieEventText(ax, layoutOptions, layoutOptions.frames(1));
end

                        %  title(sprintf('ROI(%d) Ch:%d', roiIndex, ch));
                        title(ax, score_wrapDisplayLabel(localChannelLabel_(layoutOptions, ch), 24), ...
                            'FontName', 'Arial', ...
                            'FontSize', floor(sqrt(scalingFactor)*fontsize), ...
                            'Color', textColor, ...
                            'Interpreter','none', ...
                            'FontWeight', 'normal');

                        [htext, hvector]=score_displayVectorGraphics(ax, 1, ch, vContours , layoutOptions);

                        graphicsHandles.vectorHandles(tileIndex)=[htext hvector];

                        graphicsHandles.imgHandles(tileIndex) = hImg;
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
                        localAddMovieImageDataGap(ax, layoutOptions, ds);
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
                        graphicsHandles.dataAxes(tileIndex) = ax;

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

[folder, name, ~] = fileparts(outputname);

% 1) Profil demandé par l'appli (optionnel)
if isfield(layoutOptions, 'movieProfile') && ~isempty(layoutOptions.movieProfile)
    requestedProfile = layoutOptions.movieProfile;  % ex: 'MPEG-4', 'Motion JPEG AVI', ...
else
    requestedProfile = 'MPEG-4';  % préférence: MP4 si dispo (Windows)
end

% 2) Profils disponibles sur cette installation
profiles = VideoWriter.getProfiles;
validProfiles = {profiles.Name};

% 3) Si le profil demandé n'est pas dispo, on choisit un fallback
if ~ismember(requestedProfile, validProfiles)
    % Ordre de préférence selon ce qui est généralement utile
    preferenceList = {'MPEG-4', 'Motion JPEG AVI', 'Uncompressed AVI', ...
                      'Archival', 'Motion JPEG 2000', 'Grayscale AVI', 'Indexed AVI'};
    fallbackProfile = '';

    for k = 1:numel(preferenceList)
        if ismember(preferenceList{k}, validProfiles)
            fallbackProfile = preferenceList{k};
            break;
        end
    end

    if isempty(fallbackProfile)
        % Au cas très improbable où rien ne match (devrait pas arriver)
        fallbackProfile = validProfiles{1};
    end

    warning('Requested movie profile "%s" not available. Using "%s" instead.', ...
        requestedProfile, fallbackProfile);
    requestedProfile = fallbackProfile;
end

% 4) Choix de l'extension en fonction du profil
switch requestedProfile
    case 'MPEG-4'
        fileExt = '.mp4';
    case {'Motion JPEG 2000','Archival'}
        % Ceux-là sont souvent stockés en .mj2, mais .avi peut aussi marcher
        fileExt = '.mj2';  % à adapter si tu préfères .avi
    otherwise
        % Motion JPEG AVI, Uncompressed AVI, Grayscale AVI, Indexed AVI, ...
        fileExt = '.avi';
end

newPath = fullfile(folder, [name fileExt]);

% 5) Création du VideoWriter avec un profil valide
v = VideoWriter(newPath, requestedProfile);
v.FrameRate = 10;  % Ajuste selon tes besoins

open(v);
fig = get(masterTL, 'Parent');
set(fig, 'Visible', 'off', 'InvertHardcopy', 'off');


        % for frame = 1:numel(layoutOptions.frames)
        %     score_updateRender(graphicsHandles, roiobj, layoutOptions, displayHandles,frame)
        %     rgbImage = print(fig, '-RGBImage');
        %     disp(['Rendering frame ' num2str(frame) ' / ' num2str(numel(layoutOptions.frames))])
        %     writeVideo(v, im2frame(rgbImage));
        % end

        targetHW = [];  % [H W] fixé à la première frame

for frame = 1:numel(layoutOptions.frames)
    score_updateRender(graphicsHandles, roiobj, layoutOptions, displayHandles, frame);
    drawnow;  % important pour stabiliser le rendu avant capture

    rgb = print(fig, '-RGBImage');   % uint8 HxWx3

    % --- fixer taille de référence à la 1ère frame ---
    if isempty(targetHW)
        targetHW = size(rgb, [1 2]);
        % force dimensions paires pour H.264
        targetHW = targetHW - mod(targetHW, 2);
    end

    Ht = targetHW(1); Wt = targetHW(2);
    H  = size(rgb,1);  W  = size(rgb,2);

    % --- pad ou crop pour obtenir exactement Ht x Wt ---
    if H < Ht || W < Wt
        tmp = zeros(Ht, Wt, 3, 'uint8');
        tmp(1:min(H,Ht), 1:min(W,Wt), :) = rgb(1:min(H,Ht), 1:min(W,Wt), :);
        rgb = tmp;
    else
        rgb = rgb(1:Ht, 1:Wt, :);
    end

    fprintf('Rendering frame %d / %d\n', frame, numel(layoutOptions.frames));
    writeVideo(v, rgb);  % <-- direct, pas im2frame
end


        close(v);
        fprintf('Movie saved as MP4: %s\n', newPath);
end


end

function drawSeparationLines(ax,layoutOptions)

% --- Lignes de séparation verticales ---
% Pour les images, la boucle dépend du mode : en Sequence on a numel(frames) colonnes, en Display nChannel colonnes.

scalingFactor=layoutOptions.scalingFactor;
nbrick=layoutOptions.Nbrick;

% textColor=layoutOptions.textColor;
% channel=layoutOptions.channel;
% fontsize=layoutOptions.fontSize;

background=layoutOptions.background;
% drawLineWidth = 2; %* scalingFactor;
%
% convertPos = @(p) [ globalPos(1) + p(1)*globalPos(3), ...
%                     globalPos(2) + p(2)*globalPos(4), ...
%                     p(3)*globalPos(3), p(4)*globalPos(4) ];
%
%                    pRel = get(ax, 'Position');
%                    pFig = convertPos(pRel);
%                    xLine = pFig(1) + pFig(3) - 0.005;
%                    yBot = pFig(2);
%                    yTop = pFig(2) + pFig(4);
%
%                    annotation(ax.Children, 'line', [xLine xLine], [yBot-0.01 yTop+0.01], ...
%                               'Color', background, 'LineWidth', drawLineWidth);

xlim_ = xlim(ax);
xRight = xlim_(2);  % bord droit

% Récupérer le centre de la plage Y (pour centrer la ligne)
ylim_ = ylim(ax);
yCenter = mean(ylim_);

% Définir les bornes Y de la ligne (hauteur = 2)
%y1 = yCenter - 1
% y2 = yCenter + 1

% Tracer la ligne

wid=2*nbrick*scalingFactor;
line(ax, [xRight xRight], ylim_, ...
    'Color', background, 'LineWidth', wid, 'LineStyle', '-');
end

function hScale = localDrawChannelScaleBars(ax, layoutOptions)
hScale = gobjects(0);
if isempty(ax) || ~isgraphics(ax) || isempty(layoutOptions) || ...
        ~isfield(layoutOptions, 'scale') || isempty(layoutOptions.scale)
    return;
end

nCh = numel(layoutOptions.scale);
if isfield(layoutOptions, 'Nchannel') && ~isempty(layoutOptions.Nchannel)
    nCh = min(nCh, layoutOptions.Nchannel);
end
scaledChannels = find(logical(layoutOptions.scale(1:nCh)));
offsetCount = numel(scaledChannels);
for i = 1:offsetCount
    h = score_drawChannelScaleBar(ax, layoutOptions, scaledChannels(i), i, offsetCount);
    if ~isempty(h)
        hScale = [hScale h]; %#ok<AGROW>
    end
end
end

function localAddMovieImageDataGap(ax, layoutOptions, dataPanelIndex)
try
    if ~isfield(layoutOptions, 'mode') || ~strcmpi(string(layoutOptions.mode), "movie") || ...
            ~isgraphics(ax) || dataPanelIndex ~= 1
        return;
    end
    ax.Units = 'normalized';
    pos = ax.Position;
    gap = min(0.025, max(0.008, 0.12 * pos(4)));
    pos(2) = pos(2) - gap;
    pos(4) = max(0.001, pos(4) - gap);
    ax.Position = pos;
catch
end
end


function str = localBuildMovieRoiTitle_(layoutOptions, roiData)

parts = strings(0);

if isfield(layoutOptions,'title') && ~isempty(layoutOptions.title)
    parts(end+1) = string(layoutOptions.title);
end

if isfield(layoutOptions,'ROITitle') && layoutOptions.ROITitle
    parts(end+1) = string(roiData.id);
end

if isempty(parts)
    str = "";
else
    str = strjoin(parts, " | ");
end
end

function label = localChannelLabel_(layoutOptions, ch)
label = layoutOptions.channel{ch};
try
    if isfield(layoutOptions, 'channelLabel') && numel(layoutOptions.channelLabel) >= ch && ...
            strlength(string(layoutOptions.channelLabel{ch})) > 0
        label = char(string(layoutOptions.channelLabel{ch}));
    end
catch
    label = layoutOptions.channel{ch};
end
end
