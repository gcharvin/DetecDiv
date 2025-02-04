function score_updateHistogram(app, mode)
    
% Vérifier qu'une ROI est sélectionnée
    if isempty(app.content.ROIList)
        return;
    end

    % Récupérer la ROI sélectionnée
    selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
    if isempty(selectedROIIndex)
        return;
    end
    selectedROI = app.content.ROIList{selectedROIIndex};

    % Récupérer le frame courant
    frameIndex = selectedROI.display.frame;
    if frameIndex > size(selectedROI.image, 4)
        frameIndex = size(selectedROI.image, 4);
    end

    % Recalculer la liste des canaux affichables à partir de la table des channels
    numTotalChannels = numel(selectedROI.display.channel);
    colorChannels = [];
    for i = 1:numTotalChannels
        pix = selectedROI.findChannelID(selectedROI.display.channel{i});
        if numel(pix) == 3
            colorChannels = [colorChannels, i];
        else
            if sum(selectedROI.display.intensity(i, :)) == 0
                continue;
            end
            colorChannels = [colorChannels, i];
        end
    end

    % Récupérer les cases cochées depuis la table
    if isempty(app.UIChannelTable.Data)
        cla(app.UIDisplayAxes);
        return;
    end
    checkboxValues = cell2mat(app.UIChannelTable.Data(:, 1));
    displayedChannels = colorChannels(checkboxValues);


   % --- Mise à jour en mode refresh ---
    if strcmp(mode, 'refresh')
        if isempty(app.HistogramEdges) || isempty(app.HistogramLines) || (length(app.HistogramLines) ~= length(displayedChannels))
   
            score_updateHistogram(app, 'slow');
            return;
        end
        for k = 1:length(app.HistogramLines)
            if ~isvalid(app.HistogramLines(k))
          
                score_updateHistogram(app, 'slow');
                return;
            end
            set(app.HistogramLines(k), 'YData', app.HistogramData{k});
            channelIdx = app.HistogramChannels(k);
            rgbColor = selectedROI.display.rgb(channelIdx, :);
            if all(rgbColor >= 0.99)
                rgbColorPlot = [0, 0, 0];
            else
                rgbColorPlot = rgbColor;
            end
            set(app.HistogramLines(k), 'Color', rgbColorPlot);
        end
        
        if ~isempty(app.HistogramLimits) && (numel(app.HistogramLimits) == 2 * length(app.HistogramChannels))
            for k = 1:length(app.HistogramChannels)
                channelIdx = app.HistogramChannels(k);
                lowVal = selectedROI.display.displaylim(1, channelIdx) * 65535;
                highVal = selectedROI.display.displaylim(2, channelIdx) * 65535;
                if ~isvalid(app.HistogramLimits(2*k-1)) || ~isvalid(app.HistogramLimits(2*k))
                   
                    score_updateHistogram(app, 'slow');
                    return;
                end
                set(app.HistogramLimits(2*k-1), 'Value', lowVal);
                set(app.HistogramLimits(2*k),   'Value', highVal);
                if all(selectedROI.display.rgb(channelIdx, :) >= 0.99)
                    rgbColorPlot = [0, 0, 0];
                else
                    rgbColorPlot = selectedROI.display.rgb(channelIdx, :);
                end
                set(app.HistogramLimits(2*k-1), 'Color', rgbColorPlot);
                set(app.HistogramLimits(2*k),   'Color', rgbColorPlot);
            end
        else
        
            score_updateHistogram(app, 'slow');
            return;
        end
        return;
    end


    
    if isempty(displayedChannels)
        cla(app.UIDisplayAxes);
        return;
    end

    % Effacer l'axe et activer le hold pour accumuler tous les tracés
    cla(app.UIDisplayAxes);
    hold(app.UIDisplayAxes, 'on');

    % Définir le nombre de bins et les bords pour l'histogramme (échelle logarithmique)
    numBins = 200;
    edges = logspace(0, log10(65535), numBins);
    histogramData = cell(1, length(displayedChannels));
    hLines = gobjects(1, length(displayedChannels));
    allPixelValues = [];

    % Pour stocker les valeurs médianes et le nom de chaque canal affiché
    medianValues = cell(1, length(displayedChannels));
    channelNames = cell(1, length(displayedChannels));

    
    for k = 1:length(displayedChannels)
        channelIdx = displayedChannels(k);
        % Vérifier si le canal est RGB
        pix = selectedROI.findChannelID(selectedROI.display.channel{channelIdx});
        if numel(pix) == 3
            % Pour un canal RGB, extraire les 3 composantes et calculer une image en niveaux de gris
            rawR = double(selectedROI.image(:, :, pix(1), frameIndex));
            rawG = double(selectedROI.image(:, :, pix(2), frameIndex));
            rawB = double(selectedROI.image(:, :, pix(3), frameIndex));
            % Conversion en niveaux de gris (pondération standard)
            imgChannel = 0.2989 * rawR + 0.5870 * rawG + 0.1140 * rawB;
        else
            imgChannel = double(selectedROI.image(:, :, channelIdx, frameIndex));
        end
        
        % Calcul de l'histogramme sur les valeurs brutes (sans normalisation)
        [counts, ~] = histcounts(imgChannel, edges);
        counts(counts == 0) = NaN;  % pour éviter des zéros sur une échelle logarithmique
        histogramData{k} = counts;
        allPixelValues = [allPixelValues; imgChannel(:)];
        
        channelNames{k} = selectedROI.display.channel{channelIdx};
         % Calculer la médiane des pixels pour ce canal
        medianValues{k} = median(imgChannel(:));
        
        % Définir la couleur d'affichage (forcer le noir si la couleur est blanche)
        rgbColor = selectedROI.display.rgb(channelIdx, :);
        if all(rgbColor >= 0.99)
            rgbColorPlot = [0, 0, 0];
        else
            rgbColorPlot = rgbColor;
        end
        
        % Tracer la courbe d'histogramme sans effacer les précédentes
        hLines(k) = plot(app.UIDisplayAxes, edges(1:end-1), counts, 'Color', rgbColorPlot, 'LineWidth', 1.5);
    end

    % Ajuster les axes
    minPixelValue = max(min(allPixelValues), 1);
    maxPixelValue = min(max(allPixelValues), 65535);
    set(app.UIDisplayAxes, 'XScale', 'log', 'YScale', 'log');
    xlim(app.UIDisplayAxes, [0.8*minPixelValue, 1.2*maxPixelValue]);
    ylim(app.UIDisplayAxes, [1, max(cellfun(@(x) max(x(:)), histogramData)) * 1.2]);
    
    xlabel(app.UIDisplayAxes, 'Pixel Intensity');
    ylabel(app.UIDisplayAxes, 'Pixel Count');
   % title(app.UIDisplayAxes, 'Histogram');

   % Concaténer les médianes dans le titre
    titleStr = 'Med:';
    for k = 1:length(displayedChannels)
        titleStr = [titleStr sprintf('%s : %.0f; ', channelNames{k}, medianValues{k})];
    end
    titleStr = [titleStr ')'];
    title(app.UIDisplayAxes, titleStr);
    
    % Création ou mise à jour des lignes verticales pour les limites (Low/High)
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
    
    % Stocker les données et handles pour le mode refresh
    app.HistogramEdges = edges;
    app.HistogramData = histogramData;
    app.HistogramChannels = displayedChannels;
    app.HistogramLines = hLines;
    
    % Désactiver le hold
    hold(app.UIDisplayAxes, 'off');
    
end
