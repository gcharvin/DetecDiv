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
selectedROI = app.content.ROIList{selectedROIIndex};

% Vérifier que l'image est chargée, sinon la charger
if isempty(selectedROI.image)
    selectedROI.image.load();
end

% Récupérer le frame sélectionné
currentFrame = selectedROI.display.frame;
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

% Vérifier qu'on a bien des canaux visibles à afficher
if isempty(visibleChannels)
    cla(app.UIImageAxes);
    return;
end

% Récupérer la taille de l'image
[imgHeight, imgWidth, ~, ~] = size(selectedROI.image);

% Mode Overlay (affichage composite) si OverlayCheckBox est coché
if app.OverlayCheckBox.Value
    compositeImage = zeros(imgHeight, imgWidth, 3);
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
    compositeImage = max(0, min(1, compositeImage));

    % Mode LENT : utiliser imshow
    if strcmp(mode, 'slow')
        imshow(compositeImage, 'Parent', app.UIImageAxes);
    else
        % Mode REFRESH : mettre à jour le CData si possible
        if isfield(app.UIImageAxes.UserData, 'CDataHandle') && isvalid(app.UIImageAxes.UserData.CDataHandle)
            try
                set(app.UIImageAxes.UserData.CDataHandle, 'CData', compositeImage);
            catch ME
                % En cas d'erreur, recréez l'objet image
                warning('Erreur lors de la mise à jour du CData : %s. Recréation de l''image.', ME.message);
                h = imshow(compositeImage, 'Parent', app.UIImageAxes);
                app.UIImageAxes.UserData.CDataHandle = h;
            end
        else
            % Si le handle n'existe pas ou n'est pas valide, créez une nouvelle image
            h = imshow(compositeImage, 'Parent', app.UIImageAxes);
            app.UIImageAxes.UserData.CDataHandle = h;
        end

    end

else
    % Mode non-overlay : afficher les canaux les uns en dessous des autres
    % Pour chaque canal, générer une image RGB (selon la couleur, intensité, etc.)
    channelImages = {};
    for i = 1:numel(visibleChannels)
        chIndex = visibleChannels(i);
        if ~selectedROI.display.selectedchannel(chIndex)
            continue;
        end

        % Extraire l'image brute du canal pour le frame courant
        channelImage = double(selectedROI.image(:, :, chIndex, currentFrame));

        % Appliquer la normalisation avec les niveaux d'affichage
        minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
        maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
        normChannel = (channelImage - minLevel) / (maxLevel - minLevel);
        normChannel = max(0, min(1, normChannel));

        % Appliquer la couleur et l'intensité pour obtenir une image RGB
        intensity = selectedROI.display.intensity(chIndex);
        rgbColor = selectedROI.display.rgb(chIndex, :);
        coloredChannel = zeros(imgHeight, imgWidth, 3);
        for c = 1:3
            coloredChannel(:, :, c) = intensity * rgbColor(c) * normChannel;
        end
        coloredChannel = max(0, min(1, coloredChannel));

        channelImages{end+1} = coloredChannel;  %#ok<AGROW>
    end

    if ~isempty(channelImages)
        % Concaténer verticalement toutes les images des canaux
        stackedImage = cat(1, channelImages{:});
        imshow(stackedImage, 'Parent', app.UIImageAxes);
    else
        cla(app.UIImageAxes);
    end
end

% Mise à jour de l'histogramme (avec le code existant)
score_updateHistogram(app, mode);
end
