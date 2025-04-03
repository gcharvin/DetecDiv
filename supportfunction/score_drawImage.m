function hFig = score_drawImage(roiOverlay, roiobj, param, layout)
% Affichage des images et panels de données en mode tiledlayout.
%
% roiOverlay   : structure contenant pour chaque ROI une image 4D, des contours vectoriels, etc.
% dataidx      : index de sélection des données (non utilisé ici directement)
% param        : structure des paramètres (overlayMode, background, titleStr, textColor, scalingFactor, etc.)
% layout       : structure contenant les paramètres de mise en page (nCols, nRows, globalCols, globalRows, tileH, tileW, frames, ngroup, nonIndexedNames, etc.)

overlayMode = param.overlayMode;roi
tileH = layout.tileH;
tileW = layout.tileW;
background = param.background;
titleStr = param.titleStr;
textColor = param.textColor;
scalingFactor = param.scalingFactor;
fontsize = param.fontsize;
name = param.name;
frames = layout.frames;
numROI = numel(roiOverlay);
nCols = layout.nCols;
nRows = layout.nRows;

% Définir le nombre de lignes d’images par ROI
if overlayMode
    imageRows = 1;
else
    nChannel = numel(layout.nonIndexedNames);
    imageRows = nChannel;
end
dataRows = layout.ngroup;  % nombre de panels de données par ROI

globalCols = layout.globalCols;
globalRows = layout.globalRows;

% Dimensions de la figure
margin = 5;
extraMargin = 50;
figWidth = globalCols * tileW + (globalCols+1)*margin;
figHeight = globalRows * tileH + (globalRows+1)*margin + extraMargin;

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
    r = ceil(roiIdx / nCols);
    c_roi = mod(roiIdx-1, nCols) + 1;
    
    % -- Partie images --
    for imgRow = 1:imageRows
        for f = 1:numel(frames)
            % Calcul de la ligne globale pour la tuile d'image
            globalImageRow = (r-1) * (imageRows + dataRows) + imgRow;
            colIndex = (c_roi - 1)*numel(frames) + f;
            globalTileIndex = (globalImageRow - 1)*globalCols + colIndex;
            ax = nexttile(tGlobal, globalTileIndex);
            
            if overlayMode
                imshow(roiOverlay(roiIdx).baseImage(:,:,:,f), 'Parent', ax);
                set(ax, 'Color', background);
                % Affichage des graphismes vectoriels (texte, contours, etc.)
                displayVectorGraphics(ax, f, 1, roiOverlay(roiIdx), layout, param);
            else
                % Mode non‑overlay : chaque ligne correspond à un canal
                imgFull = roiOverlay(roiIdx).baseImage;  % [M*nChannel x N x 3 x numFrames]
                M_total = size(imgFull,1);
                nChannel = imageRows;  % ici imageRows vaut le nombre de canaux
                M = M_total / nChannel;
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
                    ylabel(ax, layout.nonIndexedNames{imgRow}, 'FontName', 'Arial', ...
                        'FontSize', floor(sqrt(scalingFactor)*fontsize), 'Color', textColor);
                end
            end
        end
    end
    
   % -- Partie panels de données --
for g = 1:dataRows
    % Calcul de la ligne globale pour le panel de données de la ROI
    globalDataRow = (r-1) * (imageRows + dataRows) + imageRows + g;
    % La colonne de départ correspond à celle du bloc de la ROI dans la grille
    colIndexStart = (c_roi - 1) * numel(frames) + 1;
    % Calcul de l'indice de la tuile de départ dans la grille globale
    tileIndex = (globalDataRow - 1) * globalCols + colIndexStart;
    % Appel de nexttile avec tileIndex (entier) et span couvrant toutes les frames

    ax = nexttile(tGlobal, tileIndex, [1 numel(frames)]);
   
    % Affichage du panel de données (à adapter selon vos besoins)
    displayDataPanel(ax, g, layout.frames, layout, param, roiobj(roiIdx));
end
end

drawLineWidth = 2*scalingFactor;
nFrames=numel(frames);
globalPos = tGlobal.OuterPosition;
convertPos = @(p) [ globalPos(1) + p(1)*globalPos(3), ...
                    globalPos(2) + p(2)*globalPos(4), ...
                    p(3)*globalPos(3), p(4)*globalPos(4) ];

% Boucle uniquement sur les lignes d'images (pas sur les panels de données)
for r = 1:nRows
    for i = 1:imageRows  % i correspond à la ligne d'image dans le bloc ROI
         globalRow = (r-1)*(imageRows+dataRows) + i;
         for c = 1:nCols
              for f = 1:(nFrames-1) % On trace la ligne verticale pour chaque frame sauf la dernière
                   % Calcul de l'indice de la tuile dans la partie image
                   tileIndex = (globalRow - 1)*globalCols + ((c-1)*nFrames + f);
                   ax = nexttile(tGlobal, tileIndex);
                   pRel = get(ax, 'Position');
                   pFig = convertPos(pRel);
                   % Ligne verticale à droite de la tuile
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
exportgraphics(hFig, fil, 'ContentType', 'vector','BackgroundColor',background);
%close(hFig);  % On ferme la copie pour ne pas perturber l'affichage initial

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
    str{i} = varname{i};
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
ylabel(ax, layout.plotidxgroup{groupIdx}, ...
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

xlim(ax, framerate * [min(layout.frames), max(layout.frames)]);

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
