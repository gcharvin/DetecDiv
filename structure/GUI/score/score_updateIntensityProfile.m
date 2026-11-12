function score_updateIntensityProfile(app, pos)
    % Récupérer la ROI actuellement sélectionnée depuis la table des ROIs
    selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
    if isempty(selectedROIIndex)
        return;
    end
    selectedROI = app.content.ROIList{selectedROIIndex};
    currentFrame = selectedROI.display.frame;
    
    % Récupérer la liste des canaux "affichables"
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

    % Récupérer les cases cochées depuis la table (colonne 1) pour déterminer les channels affichés
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

    % Préparer le tracé : effacer et activer hold sur l'axe des profils
    cla(app.UIProfileAxes);
    hold(app.UIProfileAxes, 'on');
    
    % Extraire les coordonnées de la ligne à partir de pos
    % pos est une matrice 2x2 : [x1 y1; x2 y2]
    xCoords = [pos(1,1), pos(2,1)];
    yCoords = [pos(1,2), pos(2,2)];
    
    % Pour chaque canal affiché, extraire et tracer son profil d'intensité
    profiles = cell(1, length(displayedChannels));
    channelNames = cell(1, length(displayedChannels));
    for k = 1:length(displayedChannels)
        channelIdx = displayedChannels(k);
        % Récupérer le nom de ce canal
        baseName = selectedROI.display.channel{channelIdx};
        
        % Extraire le profil d'intensité en fonction du type de canal
        pix = selectedROI.findChannelID(selectedROI.display.channel{channelIdx});
        sample = score_measureIntensity(selectedROI.image(:,:,pix,currentFrame), ...
            'Line',[xCoords(:) yCoords(:)],selectedROI,channelIdx);
        profile = sample.values;
        profile = squeeze(profile);  % éliminer les dimensions unitaires
        profiles{k} = profile;
        
        % Calculer les valeurs min et max du profil
        minVal = min(profile(:));
        maxVal = max(profile(:));
        
        % Construire le nom du canal avec les valeurs min et max pour la légende
        if strcmp(score_channelDisplayUnit(selectedROI, channelIdx), 'raw')
            channelNames{k} = sprintf('%s (min=%.0f, max=%.0f)', baseName, minVal, maxVal);
        else
            channelNames{k} = sprintf('%s (min=%.3g, max=%.3g %s)', baseName, minVal, maxVal, score_channelDisplayUnit(selectedROI, channelIdx));
        end
        
        % Déterminer la couleur d'affichage à partir de selectedROI.display.rgb
        rgbColor = selectedROI.display.rgb(channelIdx, :);
        if all(rgbColor >= 0.99)
            plotColor = [0, 0, 0];
        else
            plotColor = rgbColor;
        end
        
        % Tracer le profil dans app.UIProfileAxes
        plot(app.UIProfileAxes, profile, 'Color', plotColor, 'LineWidth', 2);
    end
    
    % Calculer la longueur de la ligne (distance euclidienne entre les deux points)
    lineLength = sqrt((pos(2,1) - pos(1,1))^2 + (pos(2,2) - pos(1,2))^2);
    % En général, improfile retourne round(lineLength) points
    nPoints = round(lineLength);
    % Ajuster xlim pour que l'axe s'adapte à la longueur de la ligne
    xlim(app.UIProfileAxes, [1, nPoints]);
    
    xlabel(app.UIProfileAxes, 'Pixel Position along Line');
    ylabel(app.UIProfileAxes, 'Pixel Value');
    legend(app.UIProfileAxes, channelNames, 'Interpreter', 'none');
    
    hold(app.UIProfileAxes, 'off');
end
