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

    % list indexed channels
    indexedChannels = [];
        for i = 1:numel(selectedROI.display.channel)
            pix = selectedROI.findChannelID(selectedROI.display.channel{i});
            if numel(pix) ~= 3  % non-RGB
                if sum(selectedROI.display.intensity(i, :)) == 0
                    indexedChannels = [indexedChannels, i];
                end
            end
        end



    % Récupérer la taille de l'image brute
    [imgHeight, imgWidth, ~, ~] = size(selectedROI.image);

    if app.OverlayCheckBox.Value
        %% Mode overlay : (code existant)
        compositeImage = zeros(imgHeight, imgWidth, 3);  % image composite
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
                compositeImage = compositeImage + intensity * rgbChannelImage;
            else
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
        if strcmp(mode, 'slow')
            h = imshow(compositeImage, 'Parent', app.UIImageAxes);
            h.Tag = 'CompositeImage';
            app.UIImageAxes.UserData.CDataHandle = h;
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
        end
        % Réinitialiser les limites de l'axe si le zoom est à 100%
        if app.ZoomSlider.Value == 100
            set(app.UIImageAxes, 'XLim', [1, imgWidth], 'YLim', [1, imgHeight]);
            app.OriginalXLim = [1, imgWidth];
            app.OriginalYLim = [1, imgHeight];
        end

        % Pour les canaux indexés, on superpose le masque sur l'image composite.
        % On reconstruit la liste des canaux indexés (non-RGB)
        

        % Pour chaque canal indexé, superposer le masque
        for j = 1:length(indexedChannels)
            chIndex = indexedChannels(j);
            pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
            % Extraire l'image brute du canal pour le frame courant
            channelImage = double(selectedROI.image(:, :, pix, currentFrame));
             %figure, imshow(channelImage,[]);
            channelImage(channelImage==1)=0;
            % Créer le masque : on considère tous les pixels > 0
            mask = channelImage > 0;
            % Créer une image de la même taille remplie de la couleur du canal
           
% Récupérer la couleur associée à ce canal (valeurs dans [0, 1])
uniformColor = selectedROI.display.rgb(chIndex, :);

% Créer une image de couleur uniforme qui ne sera visible que là où mask est vrai
% Pour cela, multiplier la couleur uniforme par le masque (converti en double)
colorMask = repmat(reshape(uniformColor, [1, 1, 3]), imgHeight, imgWidth) .* repmat(double(mask), [1, 1, 3]);

 % figure, imshow(colorMask,[]);
            % Définir l'alpha : app.Transparency pour les pixels du masque, 0 sinon
            alphaMask = app.Transparency.Value * double(mask);
            % Superposer le masque sur l'axe (imagesc ajoute un objet sur l'axe sans effacer)
            hMask = imagesc(app.UIImageAxes, colorMask);
            set(hMask, 'AlphaData', alphaMask, 'AlphaDataMapping', 'none');
            % Exclure cet objet de la légende
            set(hMask, 'HandleVisibility', 'off');
        end

    else
        %% Mode non-overlay : afficher les canaux empilés verticalement et superposer les masques
        channelImages = {};
        displayedChannelIndices = [];  % pour mémoriser l'ordre des canaux affichés
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

            % Superposer les masques pour les canaux indexés (non-RGB)
            % Pour chaque affiché, on détermine son ordre (1...N)
            for j = 1:length(displayedChannelIndices)
                chIndex = displayedChannelIndices(j);
                % Vérifier si ce canal est non-RGB (indexed)
                pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
                if numel(pix) == 3
                    continue;  % Ne pas traiter les canaux RGB ici
                end
                % Extraire l'image brute du canal
                channelImage = double(selectedROI.image(:, :, chIndex, currentFrame));
                mask = channelImage > 0;  % masque binaire
                % La zone du j‑ème canal dans l'image empilée est :
                yOffset = (j-1)*imgHeight; 
                % Créer un masque de la même taille que l'image empilée
                fullMask = false(numel(channelImages)*imgHeight, imgWidth);
                fullMask(yOffset+1:yOffset+imgHeight, :) = mask;
                % Créer une image de couleur constante pour ce canal
                maskColor = selectedROI.display.rgb(chIndex, :);
                colorMask = repmat(reshape(maskColor, [1 1 3]), numel(channelImages)*imgHeight, imgWidth);
                % Définir l'alpha (transparence)
                alphaMask = app.Transparency.Value * double(fullMask);
                hMask = imagesc(app.UIImageAxes, colorMask);
                set(hMask, 'AlphaData', alphaMask, 'AlphaDataMapping', 'none');
                set(hMask, 'HandleVisibility', 'off');
            end

        else
            cla(app.UIImageAxes);
        end
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
