function score_updateEllipticalProfile(app, ellipseObj)

     % Vérifier que l'objet ellipse est valide
    if isempty(ellipseObj) || ~isvalid(ellipseObj)
        % Vous pouvez vider l'axe du profil ou simplement sortir de la fonction
        cla(app.UIProfileAxes);
        return;
    end

%% Récupérer la ROI et le frame courant
    % On utilise ici la table des canaux pour les données, mais la ROI est déterminée via UIROITable.
    selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
    if isempty(selectedROIIndex)
        return;
    end
    selectedROI = app.content.ROIList{selectedROIIndex};
    currentFrame = selectedROI.display.frame;
    
    %% Création du masque à partir de l'ellipse
    [imgHeight, imgWidth, ~, ~] = size(selectedROI.image);
    dummyImg = ones(imgHeight, imgWidth);
    mask = createMask(ellipseObj, dummyImg);
    
    %% Déterminer la liste des canaux affichables
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
    
    %% Filtrer selon la sélection dans la table des canaux (UIChannelTable)
    if isempty(app.UIChannelTable.Data)
        cla(app.UIProfileAxes);
        return;
    end
    checkboxValues = cell2mat(app.UIChannelTable.Data(:,1));
    checkboxValues = logical(checkboxValues(:)');
    nMask = min(numel(colorChannels), numel(checkboxValues));
    if nMask == 0
        cla(app.UIProfileAxes);
        return;
    end
    checkboxValues = checkboxValues(1:nMask);
    colorChannels = colorChannels(1:nMask);
    selectedIdx = find(checkboxValues);
    selectedIdx = selectedIdx(selectedIdx >= 1 & selectedIdx <= numel(colorChannels));
    displayedChannels = colorChannels(selectedIdx);
    if isempty(displayedChannels)
        cla(app.UIProfileAxes);
        return;
    end
    
    %% Préparation du tracé dans l'axe de profil
    cla(app.UIProfileAxes);
    hold(app.UIProfileAxes, 'on');
    
    % Variables pour la légende et pour ajuster xlim
    channelNames = cell(1, length(displayedChannels));
    globalMin = inf;
    globalMax = -inf;
    
    %% Pour chaque canal affiché, calculer l'histogramme adapté et tracer avec stairs
    for k = 1:length(displayedChannels)
        channelIdx = displayedChannels(k);
        baseName = selectedROI.display.channel{channelIdx};
        
        % Extraction des pixels dans la région définie par l'ellipse
        pix = selectedROI.findChannelID(selectedROI.display.channel{channelIdx});
        sample = score_measureIntensity(selectedROI.image(:,:,pix,currentFrame), ...
            'Region',mask,selectedROI,channelIdx);
        
        % Vérifier que pixelValues n'est pas vide
        if sample.count == 0
            continue;
        end
        
        % Calcul des bornes pour ce canal
        channelMin = sample.minimum;
        channelMax = sample.maximum;
        globalMin = min(globalMin, channelMin);
        globalMax = max(globalMax, channelMax);
        
        % Histogramme partagé avec la nouvelle interface.
        binCenters = sample.centers;
        counts = sample.counts;
        
        % Calcul de la médiane des pixels pour la légende
        medVal = sample.median;
        stdVal = sample.std;
        if strcmp(score_channelDisplayUnit(selectedROI, channelIdx), 'raw')
            channelNames{k} = sprintf('%s (Med=%.0f; Std=%.0f)', baseName, medVal, stdVal);
        else
            channelNames{k} = sprintf('%s (Med=%.3g; Std=%.3g %s)', baseName, medVal, stdVal, score_channelDisplayUnit(selectedROI, channelIdx));
        end
        
        % Déterminer la couleur d'affichage pour ce canal
        rgbColor = selectedROI.display.rgb(channelIdx, :);
        if all(rgbColor >= 0.99)
            plotColor = [0, 0, 0];
        else
            plotColor = rgbColor;
        end
        
        % Tracer l'histogramme avec stairs
        stairs(app.UIProfileAxes, binCenters, counts, 'Color', plotColor, 'LineWidth', 2);
    end
    
    % Ajuster xlim en fonction de globalMin et globalMax
    if isfinite(globalMin) && isfinite(globalMax) && (globalMax > globalMin)
        margin = 0.05 * (globalMax - globalMin);
        xlim(app.UIProfileAxes, [globalMin - margin, globalMax + margin]);
    else
        xlim(app.UIProfileAxes, [0, 65535]);
    end
    
    xlabel(app.UIProfileAxes, 'Pixel Value');
    ylabel(app.UIProfileAxes, 'Pixel Count');
    legend(app.UIProfileAxes, channelNames, 'Interpreter', 'none');
    
    hold(app.UIProfileAxes, 'off');
end
