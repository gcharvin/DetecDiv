function score_display(app, mode)


%  tmp=app.EllipseIntensityProfileObj

checkOrCreateImageFigure(app);

  

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

% Vérifier que l'image est chargée, sinon la charger)
if isempty(selectedROI.image)
    selectedROI.load();
end

% Récupérer le frame sélectionné
currentFrame = selectedROI.display.frame;

app.FrameLabel.Text=['Frame : ' num2str(currentFrame)];
app.updateAssignValueControls();

numFrames = size(selectedROI.image, 4);
if currentFrame < 1 || currentFrame > numFrames
    return;
end

% Récupérer la liste des canaux affichés dans la table UIChannelTable
tableData = app.UIChannelTable.Data;
if isempty(tableData)
    cla(app.ImageAxes);
    return;
end
    visibleChannelNames = tableData(:, 2);
    % Correction : filtrer les cellules vides lors de la recherche du channel
    tempChannels = cellfun(@(name) find(strcmp(selectedROI.display.channel, name), 1), visibleChannelNames, 'UniformOutput', false);
    tempChannels = tempChannels(~cellfun(@isempty, tempChannels));
    if isempty(tempChannels)
        cla(app.ImageAxes);
        return;
    end
    visibleChannels = cell2mat(tempChannels);

% Liste des canaux indexés (non-RGB)
indexedChannels = [];
numChannels = numel(selectedROI.display.channel);
for i = 1:numChannels
    pix = selectedROI.findChannelID(selectedROI.display.channel{i});
    if numel(pix) ~= 3  % non-RGB
        if selectedROI.display.indexed(i)==true %sum(selectedROI.display.intensity(i, :)) == 0
            indexedChannels = [indexedChannels, i];
        end
    end
end

% Récupérer la taille de l'image brute
[imgHeight, imgWidth, ~, ~] = size(selectedROI.image);
app.ImageFigure.Name = ['Frame ' num2str(selectedROI.display.frame)];

if isprop(app, 'SelectedObjectRectangle') && ~isempty(app.SelectedObjectRectangle) && isgraphics(app.SelectedObjectRectangle)
    delete(app.SelectedObjectRectangle);
end

if app.OverlayCheckBox.Value

    %% Mode overlay : construire l'image composite dans app.ImageAxes
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

            if isfield(selectedROI.display, 'displaylim') && ~isempty(selectedROI.display.displaylim) && size(selectedROI.display.displaylim,2) >= chIndex
                minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
                maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
            else
                % Valeurs par défaut si displaylim n'est pas défini pour ce canal
                minLevel = 0;
                maxLevel = 65535;
            end
            rgbChannelImage = (rgbChannelImage - minLevel) / (maxLevel - minLevel);
            rgbChannelImage = max(0, min(1, rgbChannelImage));
            intensity = selectedROI.display.alpha(chIndex);
            compositeImage = compositeImage + intensity * rgbChannelImage;
        else
            % Canal non-RGB (monochrome)
            channelImage = double(selectedROI.image(:, :, chIndex, currentFrame));
            if isfield(selectedROI.display, 'displaylim') && ~isempty(selectedROI.display.displaylim) && size(selectedROI.display.displaylim,2) >= chIndex
                minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
                maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
            else
                % Valeurs par défaut si displaylim n'est pas défini pour ce canal
                minLevel = 0;
                maxLevel = 65535;
            end
            channelImage = (channelImage - minLevel) / (maxLevel - minLevel);
            channelImage = max(0, min(1, channelImage));
            intensity = selectedROI.display.alpha(chIndex);
            rgbColor = selectedROI.display.rgb(chIndex, :);
            for c = 1:3
                compositeImage(:, :, c) = compositeImage(:, :, c) + intensity * rgbColor(c) * channelImage;
            end
        end
    end
    compositeImage = max(0, min(1, compositeImage));

    indexedOverlay = zeros(imgHeight, imgWidth, 3);
    alphaOverlay = zeros(imgHeight, imgWidth);

  
   noIndexed=0;
   for l = 1:numel(indexedChannels)
           noIndexed=noIndexed+selectedROI.display.selectedchannel(indexedChannels(l)) ;
   end

    if app.PaintButton.Value && noIndexed~=0
        % --- Modification pour la reconstruction du nom complet ---
      
        selectedRow = app.UIAnnotationTable.Selection;
        if isempty(selectedRow) || isempty(selectedRow(1))
            errordlg('No channel selected!');
            return;
        else
            % Récupérer la partie "Annotation" et "Class" depuis la table d'annotations
            annotationPart = app.UIAnnotationTable.Data{selectedRow(1), 2};
            classPart = app.UIAnnotationTable.Data{selectedRow(1), 3};
            fullChannelName = [annotationPart, '_', classPart];
            channelIdx = find(strcmp(selectedROI.display.channel, fullChannelName), 1);
            if isempty(channelIdx)
                errordlg('No channel selected!');
                return;
            end
        end

        % Extraire l'image d'annotation pour ce canal (on suppose qu'elle est monochrome)
        pix = selectedROI.findChannelID(selectedROI.display.channel{channelIdx});
        annotationImage = double(selectedROI.image(:, :, pix, currentFrame));

        [imgH, imgW] = size(annotationImage);

        uniqueVals = unique(annotationImage);
        uniqueVals(uniqueVals == 0) = [];
        numUnique = numel(uniqueVals);
        if numUnique > 0
            cmap = lines(numUnique);
        else
            cmap = [1 0 0];
        end

        annotationColorImage = zeros(imgH, imgW, 3);
        alphamask = zeros(imgH, imgW);
        for iVal = 1:numUnique
            val = uniqueVals(iVal);
            mask = annotationImage == val;
            alphamask = alphamask | mask;
            for c = 1:3
                annotationColorImage(:, :, c) = annotationColorImage(:, :, c) + mask * cmap(iVal, c);
            end
        end
        annotationColorImage = max(0, min(1, annotationColorImage));
        if numel(find(alphamask))
            alphaOverlay(alphamask) = selectedROI.display.alpha(channelIdx);
        end

        indexedOverlay = annotationColorImage;

    else
        % Mode overlay sans peinture : traitement des canaux indexés
        for j = 1:numel(indexedChannels)
            chIndex = indexedChannels(j);
            if ~selectedROI.display.selectedchannel(chIndex)
                continue;
            end

            pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
            if iscell(pix)
                channelImage = double(selectedROI.image(:, :, pix{1}, currentFrame));
            else
                channelImage = double(selectedROI.image(:, :, pix, currentFrame));
            end

            if app.isthedefautcolorCheckBox.Value
            mask = channelImage > 1;
            else
             mask = channelImage >= 1;
            end

            uniformColor = selectedROI.display.rgb(chIndex, :);
            for k = 1:3
                channelOverlay = indexedOverlay(:, :, k);
                channelOverlay(mask) = uniformColor(k);
                indexedOverlay(:, :, k) = channelOverlay;
            end
            alphaOverlay(mask) = selectedROI.display.alpha(chIndex);
        end
    end

    if strcmp(mode, 'slow')
        h = imshow(compositeImage, 'Parent', app.ImageAxes, 'InitialMagnification', 'fit');
        h.Tag = 'CompositeImage';
        app.ImageAxes.UserData.CDataHandle = h;
        hOverlay = imshow(indexedOverlay, 'Parent', app.OverlayAxes);
        hOverlay.Tag = 'IndexedOverlay';
        set(hOverlay, 'HitTest', 'off');
        set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
        app.OverlayAxes.UserData.CDataHandle = hOverlay;
    else
        if isfield(app.ImageAxes.UserData, 'CDataHandle') && isvalid(app.ImageAxes.UserData.CDataHandle)
            try
                set(app.ImageAxes.UserData.CDataHandle, 'CData', compositeImage);
            catch ME
                warning('Erreur lors de la mise à jour du CData : %s. Recréation de l''image.', ME.message);
                h = imshow(compositeImage, 'Parent', app.ImageAxes);
                h.Tag = 'CompositeImage';
                app.ImageAxes.UserData.CDataHandle = h;
            end
        else
            h = imshow(compositeImage, 'Parent', app.ImageAxes);
            h.Tag = 'CompositeImage';
            app.ImageAxes.UserData.CDataHandle = h;
        end
        if isfield(app.OverlayAxes.UserData, 'CDataHandle') && isvalid(app.OverlayAxes.UserData.CDataHandle)
            try
                set(app.OverlayAxes.UserData.CDataHandle, 'CData', indexedOverlay, 'AlphaData', alphaOverlay);
            catch ME
                warning('Erreur lors de la mise à jour de l''overlay : %s. Recréation de l''overlay.', ME.message);
                hOverlay = imshow(indexedOverlay, 'Parent', app.OverlayAxes);
                hOverlay.Tag = 'IndexedOverlay';
                set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
                app.OverlayAxes.UserData.CDataHandle = hOverlay;
                set(hOverlay, 'HitTest', 'off');
            end
        else
            hOverlay = imshow(indexedOverlay, 'Parent', app.OverlayAxes, 'InitialMagnification', 'fit');
            hOverlay.Tag = 'IndexedOverlay';
            set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
            app.OverlayAxes.UserData.CDataHandle = hOverlay;
        end
    end

    if app.ZoomSlider.Value == 100
        set(app.ImageAxes, 'XLim', [1, imgWidth], 'YLim', [1, imgHeight]);
        app.OriginalXLim = [1, imgWidth];
        app.OriginalYLim = [1, imgHeight];
    end

else
 %% Mode non-overlay : afficher les canaux empilés verticalement et appliquer les masques sur chaque panel
channelImages = {};
displayedChannelIndices = [];
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
        intensity = selectedROI.display.alpha(chIndex);
        coloredChannel = intensity * rgbChannelImage;
        % Pour le masque, on utilisera la première composante
        channelForMask = channelImageR;
    else
        % Canal non-RGB
        channelImage = double(selectedROI.image(:, :, chIndex, currentFrame));
        minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
        maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
        normChannel = (channelImage - minLevel) / (maxLevel - minLevel);
        normChannel = max(0, min(1, normChannel));
        intensity = selectedROI.display.alpha(chIndex);
        rgbColor = selectedROI.display.rgb(chIndex, :);
        coloredChannel = zeros(imgHeight, imgWidth, 3);
        for c = 1:3
            coloredChannel(:, :, c) = intensity * rgbColor(c) * normChannel;
        end
        channelForMask = channelImage;
    end

    % Si le canal est indexé, appliquer le masque spécifique en fonction du mode peinture
    if ismember(chIndex, indexedChannels)
        if app.PaintButton.Value
            % Mode peinture : on vérifie si ce canal correspond à celui sélectionné dans l'annotation
            selectedRow = app.UIAnnotationTable.Selection;
            if ~isempty(selectedRow) && ~isempty(selectedRow(1))
                annotationPart = app.UIAnnotationTable.Data{selectedRow(1), 2};
                classPart = app.UIAnnotationTable.Data{selectedRow(1), 3};
                fullChannelName = [annotationPart, '_' classPart];
                if strcmp(selectedROI.display.channel{chIndex}, fullChannelName)
                    % Affichage détaillé : masque avec segmentation et palette (lines)
                    annotationImage = channelForMask;
                    uniqueVals = unique(annotationImage);
                    uniqueVals(uniqueVals == 0) = [];
                    numUnique = numel(uniqueVals);
                    if numUnique > 0
                        cmap = lines(numUnique);
                    else
                        cmap = [1 0 0];
                    end
                    annotationColorImage = zeros(size(coloredChannel));
                    alphamask = false(size(channelForMask));
                    for iVal = 1:numUnique
                        val = uniqueVals(iVal);
                        mask = (annotationImage == val);
                        alphamask = alphamask | mask;
                        for c = 1:3
                            tmp = annotationColorImage(:, :, c);
                            tmp(mask) = cmap(iVal, c);
                            annotationColorImage(:, :, c) = tmp;
                        end
                    end
                    % Intégration du masque détaillé sur le canal courant
                    for c = 1:3
                        tmp = coloredChannel(:, :, c);
                        tmp(alphamask) = annotationColorImage(:, :, c);
                        coloredChannel(:, :, c) = tmp;
                    end
                else
                    % En mode peinture mais canal indexé non sélectionné : affichage uniforme
                    if app.isthedefautcolorCheckBox.Value
                        mask = channelForMask > 1;
                    else
                        mask = channelForMask >= 1;
                    end
                    uniformColor = selectedROI.display.rgb(chIndex, :);
                    for c = 1:3
                        tmp = coloredChannel(:, :, c);
                        tmp(mask) = uniformColor(c);
                        coloredChannel(:, :, c) = tmp;
                    end
                end
            else
                % Si aucune annotation n'est sélectionnée, appliquer le masque uniforme
                if app.isthedefautcolorCheckBox.Value
                    mask = channelForMask > 1;
                else
                    mask = channelForMask >= 1;
                end
                uniformColor = selectedROI.display.rgb(chIndex, :);
                for c = 1:3
                    tmp = coloredChannel(:, :, c);
                    tmp(mask) = uniformColor(c);
                    coloredChannel(:, :, c) = tmp;
                end
            end
        else
            % Mode non-peinture : masque uniforme sur le canal indexé
            if app.isthedefautcolorCheckBox.Value
                mask = channelForMask > 1;
            else
                mask = channelForMask >= 1;
            end
            uniformColor = selectedROI.display.rgb(chIndex, :);
            for c = 1:3
                tmp = coloredChannel(:, :, c);
                tmp(mask) = uniformColor(c);
                coloredChannel(:, :, c) = tmp;
            end
        end
    end

    channelImages{end+1} = coloredChannel;
    displayedChannelIndices(end+1) = chIndex;
end

if ~isempty(channelImages)
    stackedImage = cat(1, channelImages{:});
    imshow(stackedImage, 'Parent', app.ImageAxes);
    newYLim = [1, numel(channelImages)*imgHeight];
    if app.ZoomSlider.Value == 100
        set(app.ImageAxes, 'XLim', [1, imgWidth], 'YLim', newYLim);
        app.OriginalXLim = [1, imgWidth];
        app.OriginalYLim = newYLim;
    end
else
    cla(app.ImageAxes);
end
cla(app.OverlayAxes);
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


selection = app.UIDataTable.Selection;
if isempty(selection)
    return;
end
dsIndex = selection(1);

% Vérifier que la ROI sélectionnée possède la propriété data et qu'elle contient assez d'éléments
if ~isprop(selectedROI, 'data') || numel(selectedROI.data) < dsIndex
    return;
end

% if strcmp(mode, 'slow') % data refresh
% Mettre à jour les plotProperties dans le dataset correspondant
selectedROI.data(dsIndex).plotProperties = app.UISubDataTable.Data;

% Vérifier qu'au moins un item est coché dans la première colonne de UISubDataTable
subData = app.UISubDataTable.Data;
if ~isempty(subData) && any(cell2mat(subData(:,1)))
    try
          selectedTableIndex = find(cell2mat(app.UIDataTable.Data(:,1)));
         %  if numel(selectedTableIndex)
            for i=1:numel(selectedROI.data) %selectedTableIndex'
                h=findobj('Tag',selectedROI.data(i).id);

                if numel(h) % plot is present 
                    if numel(find(selectedTableIndex==i))==0 % table is not checked, delete plot
                        delete(h);
                    end
                end

            if numel(find( selectedTableIndex==i))~=0
                    app.DataFigure(i)= selectedROI.data(i).plot();
            end
            end

    catch ME
        warning('Error when calling plot method: %s', ME.message);
    end
    figure(app.ImageFigure);
end
% end

end
