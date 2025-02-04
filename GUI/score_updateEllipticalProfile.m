function score_updateEllipticalProfile(app, ellipseObj)
    % --- Récupérer la ROI et le frame courant ---
    selectedROIIndex = find(cell2mat(app.UIChannelTable.Data(:,1)), 1);
    if isempty(selectedROIIndex)
        return;
    end
    selectedROI = app.content.ROIList{selectedROIIndex};
    currentFrame = selectedROI.display.frame;
    
    % --- Créer le masque à partir de l'ellipse ---
    % On crée une image "dummy" de même taille que l'image brute pour obtenir le masque
    [imgHeight, imgWidth, ~, ~] = size(selectedROI.image);
    dummyImg = ones(imgHeight, imgWidth);
    mask = createMask(ellipseObj, dummyImg);
    
    % --- Déterminer la liste des canaux "affichables" ---
    % On inclut les canaux RGB (détectés via findChannelID renvoyant 3 indices)
    % ou les canaux non RGB dont l'intensité n'est pas nulle.
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
    
    % --- Filtrer les canaux affichés en fonction des cases cochées dans la table ---
    if isempty(app.UIChannelTable.Data)
        cla(app.UIProfileAxes);
        return;
    end
    checkboxValues = cell2mat(app.UIChannelTable.Data(:,1));
    displayedChannels = colorChannels(checkboxValues);
    if isempty(displayedChannels)
        cla(app.UIProfileAxes);
        return;
    end
    
    % --- Préparer le tracé dans app.UIProfileAxes ---
    cla(app.UIProfileAxes);
    hold(app.UIProfileAxes, 'on');
    
    % Définir les bins pour l'histogramme (échelle linéaire, car les images brutes vont de 0 à 65535)
    numBins = 200;
    binEdges = linspace(0, 65535, numBins+1);
    binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
    
    % Variables pour la légende et pour ajuster xlim
    channelNames = cell(1, length(displayedChannels));
    allCounts = zeros(1, length(binCenters)); % pour accumuler les comptages (pour ajuster xlim)
    
    % Pour chaque canal affiché, extraire les pixels dans la région délimitée par l'ellipse
    for k = 1:length(displayedChannels)
        channelIdx = displayedChannels(k);
        baseName = selectedROI.display.channel{channelIdx};
        
        % Extraire les pixels selon le type de canal
        if numel(selectedROI.findChannelID(selectedROI.display.channel{channelIdx})) == 3
            % Canal RGB : extraire les trois composantes et les convertir en niveaux de gris
            pix = selectedROI.findChannelID(selectedROI.display.channel{channelIdx});
            rawR = double(selectedROI.image(:, :, pix(1), currentFrame));
            rawG = double(selectedROI.image(:, :, pix(2), currentFrame));
            rawB = double(selectedROI.image(:, :, pix(3), currentFrame));
            % Conversion en niveaux de gris avec coefficients standards
            grayImage = 0.2989 * rawR + 0.5870 * rawG + 0.1140 * rawB;
            pixelValues = grayImage(mask);
        else
            % Canal monochrome
            rawImg = double(selectedROI.image(:, :, channelIdx, currentFrame));
            pixelValues = rawImg(mask);
        end
        
        % Calculer l'histogramme des pixels dans la région
        [counts, ~] = histcounts(pixelValues, binEdges);
        histogramCounts = counts;
        allCounts = allCounts + histogramCounts;
        
        % Calculer la médiane des pixels dans la région pour ce canal
        medVal = median(pixelValues);
        
        % Préparer le nom pour la légende : nom du canal et médiane
        channelNames{k} = sprintf('%s (Med=%.0f)', baseName, medVal);
        
        % Déterminer la couleur d'affichage pour ce canal
        rgbColor = selectedROI.display.rgb(channelIdx, :);
        if all(rgbColor >= 0.99)
            plotColor = [0, 0, 0];
        else
            plotColor = rgbColor;
        end
        
        % Tracer la courbe d'histogramme dans app.UIProfileAxes
        plot(app.UIProfileAxes, binCenters, histogramCounts, 'Color', plotColor, 'LineWidth', 2);
    end
    
    hold(app.UIProfileAxes, 'off');
    xlabel(app.UIProfileAxes, 'Pixel Intensity');
    ylabel(app.UIProfileAxes, 'Pixel Count');
    legend(app.UIProfileAxes, channelNames, 'Interpreter', 'none');
    
    % Ajuster xlim pour qu'il colle le mieux aux données de l'histogramme
    nonZeroIdx = find(allCounts > 0);
    if ~isempty(nonZeroIdx)
        newXMin = binCenters(min(nonZeroIdx));
        newXMax = binCenters(max(nonZeroIdx));
        % Ajouter une petite marge (par exemple 5 %)
        margin = 0.05 * (newXMax - newXMin);
        xlim(app.UIProfileAxes, [newXMin - margin, newXMax + margin]);
    else
        xlim(app.UIProfileAxes, [0, 65535]);
    end
end
