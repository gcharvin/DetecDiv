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

    % Extraire les noms des canaux visibles depuis la table
    visibleChannelNames = tableData(:, 2);
    visibleChannels = cellfun(@(name) find(strcmp(selectedROI.display.channel, name), 1), visibleChannelNames, 'UniformOutput', false);
    visibleChannels = cell2mat(visibleChannels);

    if isempty(visibleChannels)
        cla(app.UIImageAxes);
        return;
    end

    % Récupérer la taille de l'image (hauteur et largeur)
    [imgHeight, imgWidth, ~, ~] = size(selectedROI.image);

    % Si le mode Overlay est activé, on affiche l'image composite
    if app.OverlayCheckBox.Value
        compositeImage = zeros(imgHeight, imgWidth, 3);  % image RGB composite
        for i = 1:numel(visibleChannels)
            chIndex = visibleChannels(i);
            % Ne traiter que les canaux sélectionnés pour l'affichage
            if ~selectedROI.display.selectedchannel(chIndex)
                continue;
            end
            
            % Déterminer si ce canal est RGB (3 indices) ou non
            pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
            if numel(pix) == 3
                % --- Canal RGB ---
                % Extraire les trois composantes du canal (valeurs brutes)
                channelImageR = double(selectedROI.image(:, :, pix(1), currentFrame));
                channelImageG = double(selectedROI.image(:, :, pix(2), currentFrame));
                channelImageB = double(selectedROI.image(:, :, pix(3), currentFrame));
                rgbChannelImage = cat(3, channelImageR, channelImageG, channelImageB);
                
                % Normaliser selon les limites d'affichage
                minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
                maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
                rgbChannelImage = (rgbChannelImage - minLevel) / (maxLevel - minLevel);
                rgbChannelImage = max(0, min(1, rgbChannelImage));
                
                % Appliquer l'intensité (pour un canal RGB, la couleur est déjà définie)
                intensity = selectedROI.display.intensity(chIndex);
                compositeImage = compositeImage + intensity * rgbChannelImage;
            else
                % --- Canal non-RGB (monochrome) ---
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
        
        compositeImage = max(0, min(1, compositeImage));  % Clamp final
        
        % Affichage selon le mode (slow/refresh)
        if strcmp(mode, 'slow')
            imshow(compositeImage, 'Parent', app.UIImageAxes);
        else
            if isfield(app.UIImageAxes.UserData, 'CDataHandle') && isvalid(app.UIImageAxes.UserData.CDataHandle)
                try
                    set(app.UIImageAxes.UserData.CDataHandle, 'CData', compositeImage);
                catch ME
                    warning('Erreur lors de la mise à jour du CData : %s. Recréation de l''image.', ME.message);
                    h = imshow(compositeImage, 'Parent', app.UIImageAxes);
                    app.UIImageAxes.UserData.CDataHandle = h;
                end
            else
                h = imshow(compositeImage, 'Parent', app.UIImageAxes);
                app.UIImageAxes.UserData.CDataHandle = h;
            end
        end
        
    else
        % Mode non-overlay : afficher les canaux les uns en dessous des autres.
        channelImages = {};
        for i = 1:numel(visibleChannels)
            chIndex = visibleChannels(i);
            if ~selectedROI.display.selectedchannel(chIndex)
                continue;
            end
            
            pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
            if numel(pix)==3
                % Canal RGB : extraire et recombiner les trois composantes
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
                % Canal monochrome
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
            channelImages{end+1} = coloredChannel;  %#ok<AGROW>
        end
        
        if ~isempty(channelImages)
            stackedImage = cat(1, channelImages{:});
            imshow(stackedImage, 'Parent', app.UIImageAxes);
        else
            cla(app.UIImageAxes);
        end
    end

    % Mise à jour de l'histogramme
    score_updateHistogram(app, mode);
end
