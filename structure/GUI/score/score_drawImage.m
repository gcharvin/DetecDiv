function hFig = score_drawImage(roiOverlay, roiobj, param, layout)
% Affichage des images et panels de données en mode tiledlayout.
%
% roiOverlay   : structure contenant pour chaque ROI une image 4D, des contours vectoriels, etc.
% roiobj       : structure contenant notamment les données associées à chaque ROI.
% param        : structure des paramètres (overlayMode, background, titleStr, textColor, scalingFactor, output, etc.)
% layout       : structure contenant les paramètres de mise en page (nCols, nRows, globalCols, globalRows, tileH, tileW, frames, ngroup, nonIndexedNames, etc.)

overlayMode = param.overlayMode;
tileH = layout.tileH;
tileW = layout.tileW;
background = param.background;
titleStr = param.titleStr;
textColor = param.textColor;
scalingFactor = param.scalingFactor;
fontsize = param.fontsize;
name = 'test.pdf'; % param.name;
frames = layout.frames;
numROI = numel(roiOverlay);
nCols_ROI = layout.nCols;
nRows_ROI = layout.nRows;

% Définir le nombre de lignes d’images par ROI et le nombre de canaux
if overlayMode
    imageRows = 1;
    nChannel = 1;
else
    switch param.output
        case "Sequence"
            nChannel = numel(layout.nonIndexedNames);
            imageRows = nChannel;
        case "Display"
            nChannel = numel(layout.nonIndexedNames);
            imageRows = 1;
        case "Movie"
            % À compléter si besoin
    end
end

dataRows = layout.ngroup;  % nombre de panels de données par ROI

% Pour le mode Display, la grille doit tenir compte des canaux en colonnes
if param.output == "Display"
    globalCols = nCols_ROI * nChannel;             % Chaque ROI occupe nChannel colonnes pour l'image
    globalRows = nRows_ROI * (1 + dataRows);         % Chaque ROI occupe 1 ligne pour l'image + dataRows pour le panel
else
    globalCols = layout.globalCols;
    globalRows = layout.globalRows;
end

% Dimensions de la figure
margin = 5;
extraMargin = 50;
switch param.output
    case "Sequence"
        figWidth = globalCols * tileW + (globalCols+1)*margin;
        figHeight = globalRows * tileH + (globalRows+1)*margin + extraMargin;
    case "Movie"
        % À compléter si besoin
    case "Display"
        figWidth = globalCols * tileW + (globalCols+1)*margin;
        figHeight = globalRows * tileH + (globalRows+1)*margin + extraMargin;
end

hFig = figure('Name', 'Sequences Export (Vectorial)', 'Units', 'pixels', ...
    'Position', [100, 100, figWidth, figHeight]);
set(hFig, 'Color', background);

tGlobal = tiledlayout(hFig, globalRows, globalCols, 'Padding', 'tight', 'TileSpacing', 'none');
if ~isempty(titleStr)
    tGlobal.Title.String = titleStr;
    tGlobal.Title.Color = textColor;
    tGlobal.Title.FontSize = floor(sqrt(scalingFactor)*fontsize);
    tGlobal.Title.FontName = 'Arial';
end

% Parcours de chaque ROI
for roiIdx = 1:numROI
    % Déterminer la position (bloc) de la ROI dans la grille globale
    % On considère ici que les ROIs sont organisées en nRows_ROI x nCols_ROI
    r = ceil(roiIdx / nCols_ROI);
    c_roi = mod(roiIdx-1, nCols_ROI) + 1;
    
    % -- Partie images --
    if overlayMode
        % Mode overlay : chaque ROI a une seule ligne d'images
        for f = 1:numel(frames)
            globalImageRow = (r-1) * (imageRows + dataRows) + 1;
            colIndex = (c_roi - 1)*numel(frames) + f;
            globalTileIndex = (globalImageRow - 1)*globalCols + colIndex;
            ax = nexttile(tGlobal, globalTileIndex);
            imshow(roiOverlay(roiIdx).baseImage(:,:,:,f), 'Parent', ax);
            set(ax, 'Color', background);
            displayVectorGraphics(ax, f, 1, roiOverlay(roiIdx), layout, param);
        end
    else
        switch param.output
            case "Sequence"
                % Mode Sequence : chaque canal sur une ligne
                for imgRow = 1:imageRows
                    for f = 1:numel(frames)
                        globalImageRow = (r-1) * (imageRows + dataRows) + imgRow;
                        colIndex = (c_roi - 1)*numel(frames) + f;
                        globalTileIndex = (globalImageRow - 1)*globalCols + colIndex;
                        ax = nexttile(tGlobal, globalTileIndex);
                        imgFull = roiOverlay(roiIdx).baseImage;  % [M*nChannel x N x 3 x numFrames]
                        M_total = size(imgFull,1);
                        nChannel_seq = imageRows;  % ici imageRows vaut le nombre de canaux
                        M = M_total / nChannel_seq;
                        rowStart = round((imgRow-1)*M) + 1;
                        rowEnd = round(imgRow*M);
                        imgChannel = imgFull(rowStart:rowEnd, :, :, f);
                        if size(imgChannel,3) ~= 3
                            imgChannel = repmat(imgChannel, [1,1,3]);
                        end
                        imshow(imgChannel, 'Parent', ax);
                        set(ax, 'Color', background);
                        displayVectorGraphics(ax, f, imgRow, roiOverlay(roiIdx), layout, param);
                        if f == 1
                            ylabel(ax, score_wrapDisplayLabel(layout.nonIndexedNames{imgRow}), 'FontName', 'Arial', ...
                                'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', textColor);
                        end
                    end
                end
            case "Display"
                % Mode Display : les canaux sont représentés en colonnes
                % On suppose que roiOverlay(roiIdx).baseImage a une taille [M x (N*nChannel) x 3 x numFrames]
                imgFull = roiOverlay(roiIdx).baseImage;
                N_total = size(imgFull, 2);
                M = size(imgFull, 1);
                N = N_total / nChannel;
                % Pour chaque frame, on parcourt chaque canal
                globalImageRow = (r-1) * (1 + dataRows) + 1; % seule ligne d'images pour la ROI
                for f = 1:numel(frames)
                    for ch = 1:nChannel
                        colIndex = (c_roi - 1)*nChannel + ch;
                        globalTileIndex = (globalImageRow - 1)*globalCols + colIndex;
                        ax = nexttile(tGlobal, globalTileIndex);
                        colStart = round((ch-1)*N) + 1;
                        colEnd = round(ch*N);
                        imgChannel = imgFull(:, colStart:colEnd, :, f);
                        if size(imgChannel,3) ~= 3
                            imgChannel = repmat(imgChannel, [1,1,3]);
                        end
                        imshow(imgChannel, 'Parent', ax);
                        set(ax, 'Color', background);
                        % En mode Display, chaque colonne (canal) reçoit ses vector graphics
                        displayVectorGraphics(ax, f, ch, roiOverlay(roiIdx), layout, param);
                        % if f == 1
                        %     ylabel(ax, layout.nonIndexedNames{ch}, 'FontName', 'Arial', ...
                        %         'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', textColor);
                        % end
                    end
                end
            case "Movie"
                % À compléter si besoin
        end
    end
    
    % -- Partie panels de données --
    for g = 1:dataRows
        % Calcul de la ligne globale pour le panel de données de la ROI
        if param.output == "Display"
            % En mode Display, la zone de données occupe une rangée de la ROI
            globalDataRow = (r-1) * (1 + dataRows) + 1 + g;
            colIndexStart = (c_roi - 1)*nChannel + 1;
            tileIndex = (globalDataRow - 1)*globalCols + colIndexStart;
            ax = nexttile(tGlobal, tileIndex, [1, nChannel]);
        else
            globalDataRow = (r-1) * (imageRows + dataRows) + imageRows + g;
            colIndexStart = (c_roi - 1)*numel(frames) + 1;
            tileIndex = (globalDataRow - 1)*globalCols + colIndexStart;
            ax = nexttile(tGlobal, tileIndex, [1, numel(frames)]);
        end
        displayDataPanel(ax, g, layout.frames, layout, param, roiobj(roiIdx));
    end
end

% --- Lignes de séparation verticales ---
% Pour les images, la boucle dépend du mode : en Sequence on a numel(frames) colonnes, en Display nChannel colonnes.
if param.output == "Display"
    nDiv = nChannel;
else
    nDiv = numel(frames);
end

drawLineWidth = 2 * scalingFactor;
globalPos = tGlobal.OuterPosition;
convertPos = @(p) [ globalPos(1) + p(1)*globalPos(3), ...
                    globalPos(2) + p(2)*globalPos(4), ...
                    p(3)*globalPos(3), p(4)*globalPos(4) ];
% Boucle uniquement sur les lignes d'images (hors panels de données)
for r = 1:nRows_ROI
    for i = 1:imageRows
         globalRow = (r-1) * (imageRows + dataRows) + i;
         for c = 1:nCols_ROI
              for f = 1:(nDiv-1)
                   tileIndex = (globalRow - 1)*globalCols + ((c-1)*nDiv + f);
                   ax = nexttile(tGlobal, tileIndex);
                   pRel = get(ax, 'Position');
                   pFig = convertPos(pRel);
                   xLine = pFig(1) + pFig(3) - 0.005;
                   yBot = pFig(2);
                   yTop = pFig(2) + pFig(4);
                   annotation(hFig, 'line', [xLine xLine], [yBot-0.01 yTop+0.01], ...
                              'Color', background, 'LineWidth', drawLineWidth);
              end
         end
    end
end

[pth, fle] = fileparts(name);
fil = fullfile(pth, [fle, '.pdf']);

%% --- Exportation ---
exportgraphics(hFig, fil, 'ContentType', 'vector', 'BackgroundColor', background);
% close(hFig);  % Optionnel, pour ne pas perturber l'affichage initial
disp(['Sequence export successfully saved to : ' fil]);

end



function displayDataPanel(ax, groupIdx, frame, layout, param, roiobj)
% Fonction d'affichage d'un panel de données.
% Les données X (frames) sont converties en minutes,
% le titre est affiché en ylabel et un xlabel "Time(min)" est ajouté.
%
% dataIndices : indices des données à afficher (extrait de layout.plotidx{groupIdx})

timeoffset = param.timeOffset;
framerate  = param.framerate;
fontsize=param.fontsize;
scalingFactor=param.scalingFactor; 

dataIndices = layout.plotidx{groupIdx}; % indices des données à afficher
data = roiobj.data(layout.dataidx{groupIdx});
ydata = data.data{:, layout.plotidx{groupIdx}};

% Conversion de l'axe X : on utilise le nombre de points dans ydata et param.framerate
if timeoffset
    % Si timeoffset est activé, on soustrait la première frame de layout.frames
    xdata = ((1:size(ydata,1)) - layout.frames(1)) * framerate;
else
    xdata = (1:size(ydata,1)) * framerate;
end

% Extraction des noms de variables pour la légende
varname = data.data.Properties.VariableNames(dataIndices);
str = cell(1, size(ydata,2));
for i = 1:size(ydata,2)
    str{i} = score_wrapDisplayLabel(varname{i}, 32);
end

% Tracé des données avec conversion de l'axe X en minutes et récupération des handles
p = plot(ax, xdata, ydata, 'LineWidth', 2);
hold(ax, 'on');

% Pour chaque élément dans layout.frames, ajouter un gros rond plein sur chaque courbe
markerSize = 10;  % Taille du marker (ajustable)
for k = 1:length(layout.frames)
    fIdx = layout.frames(k);
    % Vérifier que fIdx est dans les limites de ydata
    if fIdx <= size(ydata,1)
        % Calcul de la position x pour le marker
        if timeoffset
            xMarker = (fIdx - layout.frames(1)) * framerate;
        else
            xMarker = fIdx * framerate;
        end
        % Pour chaque courbe (chaque colonne de ydata)
        for j = 1:length(p)
            yMarker = ydata(fIdx, j);
            % Utilisation de la couleur propre à la courbe p(j)
            plot(ax, xMarker, yMarker, 'o', 'MarkerSize', markerSize, ...
                'MarkerFaceColor', p(j).Color, 'MarkerEdgeColor', p(j).Color);
        end
    end
end

hold(ax, 'off');

% Affichage du titre en ylabel (au lieu d'un titre en haut)
ylabel(ax, score_wrapDisplayLabel(layout.plotidxgroup{groupIdx}), ...
    'FontSize', floor(param.fontsize), ...
    'FontName', 'Arial', 'Color', param.textColor, 'Interpreter', 'none');

% Ajout d'un label pour l'axe X
xlabel(ax, 'Time(min)', 'FontName', 'Arial', ...
    'FontSize', floor(param.fontsize), ...
    'Color', param.textColor);

% Création et configuration de la légende
lgd = legend(ax, str);
set(lgd, 'Color', param.background, ...        % Fond identique à celui de la figure
         'Interpreter', 'none', ...             % Pas d'interprétation en LaTeX
         'TextColor', param.textColor);         % Texte de la légende en param.textColor

% Configuration des axes : affichage uniquement des axes gauche et inférieur
set(ax, 'XColor', param.textColor, 'YColor', param.textColor, 'Box', 'off');
set(ax, 'Color', param.background,'FontSize',floor(sqrt(scalingFactor)*fontsize));

xlim(ax, framerate * [0.9*min(layout.frames), 1.1*max(layout.frames)]);

% Seul le plot tout en bas (dernier panel) affiche les étiquettes des X ticks
if groupIdx < layout.ngroup
    set(ax, 'XTickLabel', []);
end
end

function displayVectorGraphics(ax, f, ch, roiOverlay, layout, param)
% Affiche les textes et contours vectoriels sur l'image.
frames = layout.frames;
scalingFactor = param.scalingFactor;
fontsize = param.fontsize;
hideStamp = param.hideStamp;
timeoffset = param.timeOffset;
framerate = param.framerate;
textColor = param.textColor;
hold(ax, 'on');
if ch == 1 && ~hideStamp
    if timeoffset
        ts = [num2str((frames(f)-frames(1))*framerate) 'min'];
    else
        ts = [num2str(frames(f)*framerate) 'min'];
    end
    text(ax, 0.01, 0.99, ts, 'FontName', 'Arial', 'FontSize', floor(sqrt(scalingFactor)*fontsize), ...
         'Color', textColor, 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
         'VerticalAlignment', 'top', 'Interpreter', 'none');
end
vc = roiOverlay.vectorContours{f};
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
        patch(ax, patchArgs{:});
    end
end
hold(ax, 'off');
end
