function score_display(app, mode)

% Vérifier qu'une ROI est sélectionnée
if isempty(app.content.ROIList)
    return;
end

% Récupérer la ROI actuellement sélectionnée via la table des ROIs
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

% Récupérer la liste des canaux affichés dans la table UIChannelTable
tableData = app.UIChannelTable.Data;
if isempty(tableData)
    cla(app.UIImageAxes);
    return;
end
visibleChannelNames = tableData(:, 2);
visibleChannels = cellfun(@(name) find(strcmp(selectedROI.display.channel, name), 1), visibleChannelNames, 'UniformOutput', false);
visibleChannels = cell2mat(visibleChannels);
if isempty(visibleChannels)
    cla(app.UIImageAxes);
    return;
end

% Liste des canaux indexés (non-RGB) : on parcourt tous les canaux et on ajoute
% ceux pour lesquels findChannelID ne renvoie pas 3 indices.
indexedChannels = [];
numChannels = numel(selectedROI.display.channel);
for i = 1:numChannels
    pix = selectedROI.findChannelID(selectedROI.display.channel{i});
    if numel(pix) ~= 3  % non-RGB
        % Vous pouvez décider ici d'inclure ou non selon l'intensité
        if sum(selectedROI.display.intensity(i, :)) == 0
            indexedChannels = [indexedChannels, i];
        end
    end
end

% Récupérer la taille de l'image brute
[imgHeight, imgWidth, ~, ~] = size(selectedROI.image);

if app.OverlayCheckBox.Value

    %% Mode overlay : construire l'image composite dans app.UIImageAxes
    compositeImage = zeros(imgHeight, imgWidth, 3);
    for i = 1:numel(visibleChannels)
        chIndex = visibleChannels(i);
        if ~selectedROI.display.selectedchannel(chIndex)
            continue;
        end
        pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
        if numel(pix) == 3
            % Canal RGB
            channelImageR = double(selectedROI.image(:, :, pix(1), currentFrame));
            channelImageG = double(selectedROI.image(:, :, pix(2), currentFrame));
            channelImageB = double(selectedROI.image(:, :, pix(3), currentFrame));
            rgbChannelImage = cat(3, channelImageR, channelImageG, channelImageB);
            minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
            maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
            rgbChannelImage = (rgbChannelImage - minLevel) / (maxLevel - minLevel);
            rgbChannelImage = max(0, min(1, rgbChannelImage));
            intensity = selectedROI.display.intensity(chIndex);
            compositeImage = compositeImage + intensity * rgbChannelImage;
        else
            % Canal non-RGB (monochrome)
            channelImage = double(selectedROI.image(:, :, chIndex, currentFrame));
            minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
            maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
            channelImage = (channelImage - minLevel) / (maxLevel - minLevel);
            channelImage = max(0, min(1, channelImage));
            intensity = selectedROI.display.intensity(chIndex);
            rgbColor = selectedROI.display.rgb(chIndex, :);
            for c = 1:3
                compositeImage(:, :, c) = compositeImage(:, :, c) + intensity * rgbColor(c) * channelImage;
            end
        end
    end
    compositeImage = max(0, min(1, compositeImage));


    % construire l'image qui affiche les masques par dessus l'image
    % composite

    % On suppose que 'indexedChannels' a été calculé précédemment.
    % Vider l'axe overlay pour éviter l'accumulation

    %cla(app.UIOverlayAxes);

    % Initialiser des matrices pour l'overlay et l'alpha (pour tous les canaux indexés)
    indexedOverlay = zeros(imgHeight, imgWidth, 3);
    alphaOverlay = zeros(imgHeight, imgWidth);

    % Parcourir chacun des canaux indexés à afficher
    for j = 1:numel(indexedChannels)
        chIndex = indexedChannels(j);
        if ~selectedROI.display.selectedchannel(chIndex)
            continue;
        end

        % Pour un canal indexé (non-RGB), extraire l'image brute pour le frame courant.
        % On suppose ici que le canal est monochrome.
        pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
        if iscell(pix)
            channelImage = double(selectedROI.image(:, :, pix{1}, currentFrame));
        else
            channelImage = double(selectedROI.image(:, :, pix, currentFrame));
        end

        % Créer le masque binaire : considérer comme actif tous les pixels > 1 (vous pouvez ajuster le seuil)
        mask = channelImage > 1;

        % Récupérer la couleur uniforme associée à ce canal (définie dans selectedROI.display.rgb)
        uniformColor = selectedROI.display.rgb(chIndex, :);  % valeurs dans [0 1]

        % Pour les pixels où mask est vrai, on affecte la couleur uniformColor ;
        % si plusieurs canaux se chevauchent, le dernier traité écrase les précédents.
        for k = 1:3
            channelOverlay = indexedOverlay(:, :, k);
            channelOverlay(mask) = uniformColor(k);
            indexedOverlay(:, :, k) = channelOverlay;
        end

        % Définir l'opacité pour ces pixels : pour les pixels où mask est vrai, l'opacité sera app.Transparency.Value
        alphaOverlay(mask) = app.Transparency.Value;
    end


    if strcmp(mode, 'slow')
        h = imshow(compositeImage, 'Parent', app.UIImageAxes);
        h.Tag = 'CompositeImage';
        app.UIImageAxes.UserData.CDataHandle = h;

        hOverlay = imshow(indexedOverlay, 'Parent', app.UIOverlayAxes);
        hOverlay.Tag = 'IndexedOverlay';
        set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
        app.UIOverlayAxes.UserData.CDataHandle = hOverlay;

    else
        if isfield(app.UIImageAxes.UserData, 'CDataHandle') && isvalid(app.UIImageAxes.UserData.CDataHandle)
            try
                set(app.UIImageAxes.UserData.CDataHandle, 'CData', compositeImage);
            catch ME
                warning('Erreur lors de la mise à jour du CData : %s. Recréation de l''image.', ME.message);
                h = imshow(compositeImage, 'Parent', app.UIImageAxes);
                h.Tag = 'CompositeImage';
                app.UIImageAxes.UserData.CDataHandle = h;
            end
        else
            h = imshow(compositeImage, 'Parent', app.UIImageAxes);
            h.Tag = 'CompositeImage';
            app.UIImageAxes.UserData.CDataHandle = h;
        end
        if isfield(app.UIOverlayAxes.UserData, 'CDataHandle') && isvalid(app.UIOverlayAxes.UserData.CDataHandle)
            try
                set(app.UIOverlayAxes.UserData.CDataHandle, 'CData', indexedOverlay, 'AlphaData', alphaOverlay);
            catch ME
                warning('Erreur lors de la mise à jour de l''overlay : %s. Recréation de l''overlay.', ME.message);
                hOverlay = imshow(indexedOverlay, 'Parent', app.UIOverlayAxes);
                hOverlay.Tag = 'IndexedOverlay';
                set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
                app.UIOverlayAxes.UserData.CDataHandle = hOverlay;
            end
        else
            hOverlay = imshow(indexedOverlay, 'Parent', app.UIOverlayAxes);
            hOverlay.Tag = 'IndexedOverlay';
            set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
            app.UIOverlayAxes.UserData.CDataHandle = hOverlay;
        end
    end

    if app.ZoomSlider.Value == 100
        set(app.UIImageAxes, 'XLim', [1, imgWidth], 'YLim', [1, imgHeight]);
        app.OriginalXLim = [1, imgWidth];
        app.OriginalYLim = [1, imgHeight];
    end

else
    %% Mode non-overlay : afficher les canaux empilés verticalement et superposer les masques sur l'axe overlay
    % ne pas afficher les channels

    channelImages = {};
    displayedChannelIndices = [];
    for i = 1:numel(visibleChannels)
        chIndex = visibleChannels(i);
        if ~selectedROI.display.selectedchannel(chIndex)
            continue;
        end
        pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
        if numel(pix) == 3
            channelImageR = double(selectedROI.image(:, :, pix(1), currentFrame));
            channelImageG = double(selectedROI.image(:, :, pix(2), currentFrame));
            channelImageB = double(selectedROI.image(:, :, pix(3), currentFrame));
            rgbChannelImage = cat(3, channelImageR, channelImageG, channelImageB);
            minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
            maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
            rgbChannelImage = (rgbChannelImage - minLevel) / (maxLevel - minLevel);
            rgbChannelImage = max(0, min(1, rgbChannelImage));
            intensity = selectedROI.display.intensity(chIndex);
            coloredChannel = intensity * rgbChannelImage;
        else
            channelImage = double(selectedROI.image(:, :, chIndex, currentFrame));
            minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
            maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
            normChannel = (channelImage - minLevel) / (maxLevel - minLevel);
            normChannel = max(0, min(1, normChannel));
            intensity = selectedROI.display.intensity(chIndex);
            rgbColor = selectedROI.display.rgb(chIndex, :);
            coloredChannel = zeros(imgHeight, imgWidth, 3);
            for c = 1:3
                coloredChannel(:, :, c) = intensity * rgbColor(c) * normChannel;
            end
        end
        channelImages{end+1} = coloredChannel;
        displayedChannelIndices(end+1) = chIndex;
    end

    if ~isempty(channelImages)
        stackedImage = cat(1, channelImages{:});
        imshow(stackedImage, 'Parent', app.UIImageAxes);
        newYLim = [1, numel(channelImages)*imgHeight];
        if app.ZoomSlider.Value == 100
            set(app.UIImageAxes, 'XLim', [1, imgWidth], 'YLim', newYLim);
            app.OriginalXLim = [1, imgWidth];
            app.OriginalYLim = newYLim;
        end
    else
        cla(app.UIImageAxes);
    end
     cla(app.UIOverlayAxes);
end

% Mise à jour de l'histogramme
score_updateHistogram(app, mode);

% Mise à jour du profil d'intensité (ligne ou ellipse) si activé
if app.LineIntensityprofileButton.Value
    score_updateIntensityProfile(app, getPosition(app.LineIntensityProfileLine));
end
if app.ShapeButton.Value
    score_updateEllipticalProfile(app, app.EllipseIntensityProfileObj);
end
end
