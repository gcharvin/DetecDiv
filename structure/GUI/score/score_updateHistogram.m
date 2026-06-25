function score_updateHistogram(app, mode)
    % Vérifier qu'une ROI est sélectionnée
    if isempty(app.content.ROIList)
        return;
    end

    % Récupérer la ROI sélectionnée
    %selectedROIIndex = find(cell2mat(app.UIChannelTable.Data(:, 1)), 1);
    selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
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

    % Récupérer les cases cochées depuis la table (colonne 1)
    if isempty(app.UIChannelTable.Data)
        cla(app.UIDisplayAxes);
        return;
    end
    checkboxValues = cell2mat(app.UIChannelTable.Data(:, 1));
    checkboxValues = logical(checkboxValues(:)');
    nMask = min(numel(colorChannels), numel(checkboxValues));
    if nMask == 0
        cla(app.UIDisplayAxes);
        return;
    end
    checkboxValues = checkboxValues(1:nMask);
    colorChannels = colorChannels(1:nMask);
    selectedIdx = find(checkboxValues);
    selectedIdx = selectedIdx(selectedIdx >= 1 & selectedIdx <= numel(colorChannels));
    displayedChannels = colorChannels(selectedIdx);
    
    if isempty(displayedChannels)
        cla(app.UIDisplayAxes);
        return;
    end

    % --- Mode refresh : mise à jour rapide si possible ---
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
                subIdx = find(selectedROI.channelid == channelIdx, 1, 'first');
                if isempty(subIdx)
                    subIdx = channelIdx;
                end
                encodedLimits = 65535 * [selectedROI.display.displaylim(1, subIdx) selectedROI.display.displaylim(2, subIdx)];
                displayLimits = score_decodeChannelValues(selectedROI, channelIdx, encodedLimits);
                lowVal = displayLimits(1);
                highVal = displayLimits(2);
                if ~isvalid(app.HistogramLimits(2*k-1)) || ~isvalid(app.HistogramLimits(2*k))
                    score_updateHistogram(app, 'slow');
                    return;
                end
                set(app.HistogramLimits(2*k-1), 'Value', lowVal);
                set(app.HistogramLimits(2*k), 'Value', highVal);
                if all(selectedROI.display.rgb(channelIdx, :) >= 0.99)
                    rgbColorPlot = [0, 0, 0];
                else
                    rgbColorPlot = selectedROI.display.rgb(channelIdx, :);
                end
                set(app.HistogramLimits(2*k-1), 'Color', rgbColorPlot);
                set(app.HistogramLimits(2*k), 'Color', rgbColorPlot);
            end
        else
            score_updateHistogram(app, 'slow');
            return;
        end
        return;
    end

    % --- Mode slow : recalcul complet ---
    cla(app.UIDisplayAxes);
    hold(app.UIDisplayAxes, 'on');

    numBins = 200;
    histogramData = cell(1, length(displayedChannels));
    histogramEdges = cell(1, length(displayedChannels));
    hLines = gobjects(1, length(displayedChannels));
    allPixelValues = [];
    medianValues = cell(1, length(displayedChannels));
    channelNames = cell(1, length(displayedChannels));

    for k = 1:length(displayedChannels)
        channelIdx = displayedChannels(k);
        % Vérifier si le canal est RGB ou monochrome
        pix = selectedROI.findChannelID(selectedROI.display.channel{channelIdx});
        if numel(pix) == 3
            % Pour un canal RGB, extraire les 3 composantes et calculer une image en niveaux de gris
            rawR = double(selectedROI.image(:, :, pix(1), frameIndex));
            rawG = double(selectedROI.image(:, :, pix(2), frameIndex));
            rawB = double(selectedROI.image(:, :, pix(3), frameIndex));
            imgChannel = 0.2989 * rawR + 0.5870 * rawG + 0.1140 * rawB;
        else
            if isempty(pix)
                continue;
            end
            imgChannel = double(selectedROI.image(:, :, pix(1), frameIndex));
        end
        
        imgChannel = score_decodeChannelValues(selectedROI, channelIdx, imgChannel);
        vals = imgChannel(:);
        vals = vals(isfinite(vals));
        if isempty(vals)
            continue;
        end
        minValForEdges = min(vals);
        maxValForEdges = max(vals);
        if maxValForEdges <= minValForEdges
            maxValForEdges = minValForEdges + eps(max(1, abs(minValForEdges)));
        end
        if minValForEdges > 0
            edges = logspace(log10(max(minValForEdges, realmin)), log10(maxValForEdges), numBins);
        else
            edges = linspace(minValForEdges, maxValForEdges, numBins);
        end
        [counts, ~] = histcounts(vals, edges);
        counts(counts == 0) = NaN;  % éviter des zéros sur une échelle logarithmique
        histogramData{k} = counts;
        histogramEdges{k} = edges;
        allPixelValues = [allPixelValues; vals(:)];
        
        % Calculer la médiane des pixels pour ce canal
        medianVal = median(vals(:));
        medianValues{k} = medianVal;
        
        % Préparer le nom du canal pour la légende, avec la médiane
        if strcmp(score_channelDisplayUnit(selectedROI, channelIdx), 'raw')
            channelNames{k} = sprintf('%s (Med=%.0f)', selectedROI.display.channel{channelIdx}, medianVal);
        else
            channelNames{k} = sprintf('%s (Med=%.3g %s)', selectedROI.display.channel{channelIdx}, medianVal, score_channelDisplayUnit(selectedROI, channelIdx));
        end
        
        % Définir la couleur d'affichage (forcer le noir si la couleur est blanche)
        rgbColor = selectedROI.display.rgb(channelIdx, :);
        if all(rgbColor >= 0.99)
            rgbColorPlot = [0, 0, 0];
        else
            rgbColorPlot = rgbColor;
        end
        
        % Tracer la courbe d'histogramme
        hLines(k) = plot(app.UIDisplayAxes, edges(1:end-1), counts, 'Color', rgbColorPlot, 'LineWidth', 1.5);
    end

    if isempty(allPixelValues)
        cla(app.UIDisplayAxes);
        return;
    end

    % Ajuster les axes
    minPixelValue = min(allPixelValues);
    maxPixelValue = max(max(allPixelValues), minPixelValue+eps(max(1,abs(minPixelValue))));
    if minPixelValue > 0
        set(app.UIDisplayAxes, 'XScale', 'log', 'YScale', 'log');
        minPixelValue = max(minPixelValue, realmin);
    else
        set(app.UIDisplayAxes, 'XScale', 'linear', 'YScale', 'log');
    end
    xlim(app.UIDisplayAxes, [0.8 * minPixelValue, 1.2 * maxPixelValue]);
    ylim(app.UIDisplayAxes, [1, max(1.1,max(cellfun(@(x) max(x(:)), histogramData)) * 1.2)]);
    
    xlabel(app.UIDisplayAxes, 'Pixel Value');
    ylabel(app.UIDisplayAxes, 'Pixel Count');
    
    % Au lieu d'utiliser le titre pour afficher la médiane, on les place dans la légende
    title(app.UIDisplayAxes, channelNames, 'Interpreter', 'none'); % no legend !
    legend off;
   % lgd=legend;
  %  delete(lgd);

    % Tracer les lignes verticales pour les limites (Low/High)
   % Création ou mise à jour des lignes verticales pour les limites (Low/High)
numLimits = 2 * length(displayedChannels);
hLimits = gobjects(numLimits, 1);
for k = 1:length(displayedChannels)
    channelIdx = displayedChannels(k);
    subIdx = find(selectedROI.channelid == channelIdx, 1, 'first');
    if isempty(subIdx)
        subIdx = channelIdx;
    end
    encodedLimits = 65535 * [selectedROI.display.displaylim(1, subIdx) selectedROI.display.displaylim(2, subIdx)];
    displayLimits = score_decodeChannelValues(selectedROI, channelIdx, encodedLimits);
    lowVal = displayLimits(1);
    highVal = displayLimits(2);
    rgbColor = selectedROI.display.rgb(channelIdx, :);
    if all(rgbColor >= 0.99)
        rgbColorPlot = [0, 0, 0];
    else
        rgbColorPlot = rgbColor;
    end
    hLimits(2*k-1) = xline(app.UIDisplayAxes, lowVal, '--', 'Color', rgbColorPlot, 'LineWidth', 1);
    hLimits(2*k)   = xline(app.UIDisplayAxes, highVal, '--', 'Color', rgbColorPlot, 'LineWidth', 1);
    % Exclure les lignes verticales de la légende
    hLimits(2*k-1).Annotation.LegendInformation.IconDisplayStyle = 'off';
    hLimits(2*k).Annotation.LegendInformation.IconDisplayStyle = 'off';
end
app.HistogramLimits = hLimits;

    
    % Stocker les données et handles pour le mode refresh
    app.HistogramEdges = histogramEdges;
    app.HistogramData = histogramData;
    app.HistogramChannels = displayedChannels;
    app.HistogramLines = hLines;
    
    hold(app.UIDisplayAxes, 'off');
end
