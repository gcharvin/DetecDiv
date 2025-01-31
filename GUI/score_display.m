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
    compositeImage = zeros(imgHeight, imgWidth, 3); % Image en RGB

    % Appliquer les niveaux et intensités pour chaque canal affiché
    for i = 1:numel(visibleChannels)
        chIndex = visibleChannels(i);

        % Vérifier que le canal est sélectionné pour l'affichage
        if ~selectedROI.display.selectedchannel(chIndex)
            continue; % Sauter les canaux non sélectionnés
        end

        % Extraire l'image du canal pour le frame actuel
        channelImage = double(selectedROI.image(:, :, chIndex, currentFrame));

        % Appliquer les niveaux d'affichage
        minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
        maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
        channelImage = (channelImage - minLevel) / (maxLevel - minLevel);
        channelImage = max(0, min(1, channelImage)); % Clamping [0,1]

        % Appliquer la couleur et l'intensité du canal
        intensity = selectedROI.display.intensity(chIndex);
        rgbColor = selectedROI.display.rgb(chIndex, :);

        % Ajouter le canal à l'image composite
        for c = 1:3
            compositeImage(:, :, c) = compositeImage(:, :, c) + intensity * rgbColor(c) * channelImage;
        end
    end

    % Normalisation finale de l'image composite
    compositeImage = max(0, min(1, compositeImage)); % Éviter les valeurs hors [0,1]

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

    % Trouver la ROI actuellement sélectionnée
    selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
    if isempty(selectedROIIndex)
        return;
    end

    % Récupérer la ROI sélectionnée
    selectedROI = app.content.ROIList{selectedROIIndex};

    % Récupérer l’index de la frame actuelle
    frameIndex = selectedROI.display.frame; %round(app.FrameSlider.Value);
    if frameIndex > size(selectedROI.image, 4)
        frameIndex = size(selectedROI.image, 4);
    end

    % Sélectionner uniquement les canaux affichés
    displayedChannels = find(cell2mat(app.UIChannelTable.Data(:, 1))); 
    if isempty(displayedChannels)
        cla(app.UIDisplayAxes); % Effacer l'histogramme si aucun canal affiché
        return;
    end

    % Récupérer les objets déjà dessinés
    existingLines = findobj(app.UIDisplayAxes, 'Type', 'Line', '-not', 'LineStyle', '--');
    existingLimits = findobj(app.UIDisplayAxes, 'Type', 'Line', 'LineStyle', '--');

    % Mode `slow` : recalcul complet de l'histogramme
    if strcmp(mode, 'slow')
        cla(app.UIDisplayAxes);
        existingLines = [];
        existingLimits = [];
        hold(app.UIDisplayAxes, 'on');

        % Nombre de bins pour l'histogramme (logarithmique)
        numBins = 200;
        edges = logspace(0, log10(65535), numBins); % Échelle log pour X

        % Variables pour ajuster les axes
        allPixelValues = [];
        histogramData = cell(1, length(displayedChannels));

        for i = 1:length(displayedChannels)
            channelIdx = displayedChannels(i);
            imgChannel = double(selectedROI.image(:, :, channelIdx, frameIndex));

            % Normalisation avec niveaux Low et High
            lowLevel = selectedROI.display.displaylim(1, channelIdx);
            highLevel = selectedROI.display.displaylim(2, channelIdx);
            imgChannel = (imgChannel - lowLevel * 65535) / ((highLevel - lowLevel) * 65535);
            imgChannel = min(max(imgChannel, 0), 1) * 65535; % Clamping entre [0, 65535]

            % Calcul de l'histogramme
            [counts, ~] = histcounts(imgChannel, edges);
            counts(counts == 0) = NaN; % Évite les valeurs infinies
            histogramData{i} = counts;

            % Sauvegarde des valeurs pour ajuster `xlim`
            allPixelValues = [allPixelValues; imgChannel(:)];

            % Récupérer la couleur du canal
            rgbColor = selectedROI.display.rgb(channelIdx, :);

            % Affichage du graphe
            plot(app.UIDisplayAxes, edges(1:end-1), counts, 'Color', rgbColor, 'LineWidth', 1.5);
        end

        % Sauvegarder les données dans `app` pour le mode `refresh`
        app.HistogramEdges = edges;
        app.HistogramData = histogramData;
        app.HistogramChannels = displayedChannels;

        % Ajuster `xlim` pour se caler sur les vraies valeurs des pixels
        minPixelValue = max(min(allPixelValues), 1); % Éviter 0
        maxPixelValue = min(max(allPixelValues), 65535);
        set(app.UIDisplayAxes, 'XScale', 'log', 'YScale', 'log');
        xlim(app.UIDisplayAxes, [minPixelValue, maxPixelValue]);
        ylim(app.UIDisplayAxes, [1, max(cellfun(@(x) max(x, [], 'all'), histogramData)) * 1.2]);

        % Labels et titre
        xlabel(app.UIDisplayAxes, 'Pixel Intensity');
        ylabel(app.UIDisplayAxes, 'Pixel Count');
        title(app.UIDisplayAxes, 'Histogram');

    else
        % **Mode Refresh : mise à jour uniquement des niveaux et des courbes**
        if isempty(existingLines) || isempty(app.HistogramEdges)
            updateHistogram(app, 'slow'); % Si les données manquent, refaire un calcul complet
            return;
        end

        % Mettre à jour les YData des histogrammes sans recalculer
        for i = 1:length(displayedChannels)
            if length(existingLines) < i
                continue;
            end
            existingLines(i).YData = app.HistogramData{i};
        end
    end

    % **Mise à jour des lignes des limites Low et High**
    for i = 1:length(displayedChannels)
        channelIdx = displayedChannels(i);
        lowLevel = selectedROI.display.displaylim(1, channelIdx) * 65535;
        highLevel = selectedROI.display.displaylim(2, channelIdx) * 65535;
        rgbColor = selectedROI.display.rgb(channelIdx, :);

        if length(existingLimits) < 2*i
            % Si les lignes n'existent pas, on les crée
            xline(app.UIDisplayAxes, lowLevel, '--', 'Color', rgbColor, 'LineWidth', 1);
            xline(app.UIDisplayAxes, highLevel, '--', 'Color', rgbColor, 'LineWidth', 1);
        else
            % Sinon, on met juste à jour leur position
            existingLimits(2*i - 1).Value = lowLevel;
            existingLimits(2*i).Value = highLevel;
        end
    end

    hold(app.UIDisplayAxes, 'off');
end

