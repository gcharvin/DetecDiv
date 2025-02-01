function score_display(app, mode)
% Vérifier si une ROI est sélectionnée

if isempty(app.content.ROIList)
    return;
end

% Trouver la ROI actuellement sélectionnée
selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
if isempty(selectedROIIndex)
    return;
end

% Récupérer la ROI sélectionnée
selectedROI = app.content.ROIList{selectedROIIndex};

% Vérifier si l'image est chargée, sinon la charger
if isempty(selectedROI.image)
    selectedROI.image.load();
end

% Récupérer le frame sélectionné
currentFrame = selectedROI.display.frame; %round(app.FrameSlider.Value);
numFrames = size(selectedROI.image, 4);
if currentFrame < 1 || currentFrame > numFrames
    return;
end

% Récupérer la liste des canaux affichés dans la table
tableData = app.UIChannelTable.Data;
if isempty(tableData)
    cla(app.UIImageAxes);
    return;
end

% Extraire les noms des canaux visibles dans la table
visibleChannelNames = tableData(:, 2);
visibleChannels = cellfun(@(name) find(strcmp(selectedROI.display.channel, name), 1), visibleChannelNames, 'UniformOutput', false);
visibleChannels = cell2mat(visibleChannels); % Convertir en array

% Vérifier que l'on a bien des canaux visibles à afficher
if isempty(visibleChannels)
    cla(app.UIImageAxes);
    return;
end

% Récupérer la taille de l'image
[imgHeight, imgWidth, ~, ~] = size(selectedROI.image);

% Préparation de l'image composite en uint16 (échelle 0–65535)
compositeImage = zeros(imgHeight, imgWidth, 3);
compositeImageUint16 = uint16(round(compositeImage * 65535));

for i = 1:numel(visibleChannels)
    chIndex = visibleChannels(i);
    if ~selectedROI.display.selectedchannel(chIndex)
        continue;
    end

    % Extraire et normaliser le canal
    channelImage = double(selectedROI.image(:, :, chIndex, currentFrame));
    minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
    maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
    channelImage = (channelImage - minLevel) / (maxLevel - minLevel);
    channelImage = max(0, min(1, channelImage));

    intensity = selectedROI.display.intensity(chIndex);
    rgbColor = selectedROI.display.rgb(chIndex, :);

    % Pour chaque canal RGB, calculer la contribution et l'ajouter avec imadd
    for c = 1:3
        % Calculer la contribution pour le canal c
        channelContribution = intensity * rgbColor(c) * channelImage;
        % Convertir la contribution en uint16 (échelle 0–65535)
        channelContributionUint16 = uint16(round(channelContribution * 65535));
        % Addition saturée avec imadd
        compositeImageUint16(:, :, c) = imadd(compositeImageUint16(:, :, c), channelContributionUint16);
    end
end

% Reconversion en double dans [0,1] pour l'affichage
compositeImage = double(compositeImageUint16) / 65535;


% Mode LENT : utiliser `imshow`
if strcmp(mode, 'slow')
    imshow(compositeImage, 'Parent', app.UIImageAxes);
else
    % Mode REFRESH : Met à jour uniquement les pixels (sans imshow)
    if isfield(app.UIImageAxes.UserData, 'CDataHandle')
        set(app.UIImageAxes.UserData.CDataHandle, 'CData', compositeImage);
    else
        % Si première fois, utiliser `imshow` et stocker le handle
        h = imshow(compositeImage, 'Parent', app.UIImageAxes);
        app.UIImageAxes.UserData.CDataHandle = h;
    end
end

updateHistogram(app,mode);
end

function updateHistogram(app, mode)
% Vérifier si une ROI est sélectionnée
if isempty(app.content.ROIList)
    return;
end

% Récupérer la ROI sélectionnée
selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
if isempty(selectedROIIndex)
    return;
end
selectedROI = app.content.ROIList{selectedROIIndex};

% Récupérer l’index de la frame actuelle
frameIndex = selectedROI.display.frame;
if frameIndex > size(selectedROI.image, 4)
    frameIndex = size(selectedROI.image, 4);
end

% Recalculer la liste des canaux affichables (mêmes critères que dans displayROIChannels)
numTotalChannels = numel(selectedROI.display.channel);
colorChannels = [];
for i = 1:numTotalChannels
    if sum(selectedROI.display.intensity(i, :)) == 0  % canal à ignorer
        continue;
    end
    colorChannels = [colorChannels, i];
end

% Vérifier que le tableau n'est pas vide
if isempty(app.UIChannelTable.Data)
    cla(app.UIDisplayAxes);
    return;
end

% Récupérer les cases cochées depuis le tableau
% Attention : le tableau contient une ligne par canal de colorChannels.
checkboxValues = cell2mat(app.UIChannelTable.Data(:, 1));  % vecteur logique de taille length(colorChannels)

% Calculer les indices réels des canaux affichés
displayedChannels = colorChannels(checkboxValues);

% Si aucun canal n'est sélectionné, effacer l'histogramme et sortir
if isempty(displayedChannels)
    cla(app.UIDisplayAxes);
    return;
end

% --- Mode slow : recalcul complet de l'histogramme ---
if strcmp(mode, 'slow')
    cla(app.UIDisplayAxes);
    hold(app.UIDisplayAxes, 'on');

    numBins = 200;
    edges = logspace(0, log10(65535), numBins);
    histogramData = cell(1, length(displayedChannels));
    hLines = gobjects(1, length(displayedChannels));  % Handles des courbes d'histogramme

    allPixelValues = [];
    for k = 1:length(displayedChannels)
        channelIdx = displayedChannels(k);
        imgChannel = double(selectedROI.image(:, :, channelIdx, frameIndex));
        [counts, ~] = histcounts(imgChannel, edges);

        % Normaliser avec les limites d'affichage du canal
        lowLevel = selectedROI.display.displaylim(1, channelIdx);
        highLevel = selectedROI.display.displaylim(2, channelIdx);
        imgChannel = (imgChannel - lowLevel * 65535) / ((highLevel - lowLevel) * 65535);
        imgChannel = min(max(imgChannel, 0), 1) * 65535;

        % Calcul de l'histogramme
        
        counts(counts == 0) = NaN;  % pour éviter d'avoir des zéros sur une échelle logarithmique
        histogramData{k} = counts;

        % Sauvegarde pour ajuster l'axe X
        allPixelValues = [allPixelValues; imgChannel(:)];

        % Récupérer la couleur du canal et appliquer le test :
        rgbColor = selectedROI.display.rgb(channelIdx, :);
        if all(rgbColor >= 0.99)  % si le canal est blanc, on utilise le noir pour l'histogramme
            rgbColorPlot = [0, 0, 0];
        else
            rgbColorPlot = rgbColor;
        end

        % Tracer la courbe de l'histogramme
        hLines(k) = plot(app.UIDisplayAxes, edges(1:end-1), counts, 'Color', rgbColorPlot, 'LineWidth', 1.5);
    end

    % Stocker les données et handles pour un rafraîchissement ultérieur
    app.HistogramEdges = edges;
    app.HistogramData = histogramData;
    app.HistogramChannels = displayedChannels;
    app.HistogramLines = hLines;

    % Ajustement des axes
    minPixelValue = max(min(allPixelValues), 1);
    maxPixelValue = min(max(allPixelValues), 65535);
    set(app.UIDisplayAxes, 'XScale', 'log', 'YScale', 'log');
    xlim(app.UIDisplayAxes, [minPixelValue, maxPixelValue]);
    ylim(app.UIDisplayAxes, [1, max(cellfun(@(x) max(x(:)), histogramData)) * 1.2]);

    xlabel(app.UIDisplayAxes, 'Pixel Intensity');
    ylabel(app.UIDisplayAxes, 'Pixel Count');
    title(app.UIDisplayAxes, 'Histogram');

    % Création des lignes verticales pour les limites (Low et High)
    numLimits = 2 * length(displayedChannels);
    hLimits = gobjects(numLimits, 1);
    for k = 1:length(displayedChannels)
        channelIdx = displayedChannels(k);
        lowVal = selectedROI.display.displaylim(1, channelIdx) * 65535;
        highVal = selectedROI.display.displaylim(2, channelIdx) * 65535;
        rgbColor = selectedROI.display.rgb(channelIdx, :);
        if all(rgbColor >= 0.99)
            rgbColorPlot = [0, 0, 0];
        else
            rgbColorPlot = rgbColor;
        end
        hLimits(2*k-1) = xline(app.UIDisplayAxes, lowVal, '--', 'Color', rgbColorPlot, 'LineWidth', 1);
        hLimits(2*k)   = xline(app.UIDisplayAxes, highVal, '--', 'Color', rgbColorPlot, 'LineWidth', 1);
    end
    app.HistogramLimits = hLimits;

    hold(app.UIDisplayAxes, 'off');

else
    % --- Mode refresh : mise à jour sans recalcul complet ---
    % On vérifie que les données et handles existent et que leur nombre correspond
    if isempty(app.HistogramEdges) || isempty(app.HistogramLines) || (length(app.HistogramLines) ~= length(displayedChannels))
        updateHistogram(app, 'slow');
        return;
    end

    % Mise à jour des courbes de l'histogramme (YData et couleur)
    for k = 1:length(app.HistogramLines)
        % Vérifier que le handle est toujours valide
        if ~isvalid(app.HistogramLines(k))
            updateHistogram(app, 'slow');
            return;
        end
        
        % Mise à jour des données de l'histogramme
        set(app.HistogramLines(k), 'YData', app.HistogramData{k});
        
        % Récupérer l'indice réel du canal correspondant
        channelIdx = app.HistogramChannels(k);
        % Récupérer la couleur du canal depuis la ROI
        rgbColor = selectedROI.display.rgb(channelIdx, :);
        % Si la couleur est blanche (ou presque), utiliser le noir pour l'affichage
        if all(rgbColor >= 0.99)
            rgbColorPlot = [0, 0, 0];
        else
            rgbColorPlot = rgbColor;
        end
        % Mise à jour de la couleur de la courbe
        set(app.HistogramLines(k), 'Color', rgbColorPlot);
    end

    % Mise à jour des positions et couleurs des lignes verticales (limites Low et High)
    if ~isempty(app.HistogramLimits) && numel(app.HistogramLimits) == 2 * length(app.HistogramChannels)
        for k = 1:length(app.HistogramChannels)
            channelIdx = app.HistogramChannels(k);
            lowVal = selectedROI.display.displaylim(1, channelIdx) * 65535;
            highVal = selectedROI.display.displaylim(2, channelIdx) * 65535;
            
            % Vérifier que les handles des xlines sont valides
            if ~isvalid(app.HistogramLimits(2*k-1)) || ~isvalid(app.HistogramLimits(2*k))
                updateHistogram(app, 'slow');
                return;
            end
            % Mise à jour des positions
            set(app.HistogramLimits(2*k-1), 'Value', lowVal);
            set(app.HistogramLimits(2*k),   'Value', highVal);
            
            % Mise à jour de leur couleur, en appliquant le même test
            if all(selectedROI.display.rgb(channelIdx, :) >= 0.99)
                rgbColorPlot = [0, 0, 0];
            else
                rgbColorPlot = selectedROI.display.rgb(channelIdx, :);
            end
            set(app.HistogramLimits(2*k-1), 'Color', rgbColorPlot);
            set(app.HistogramLimits(2*k),   'Color', rgbColorPlot);
        end
    else
        updateHistogram(app, 'slow');
        return;
    end
end
end
