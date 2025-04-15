function score_paintOverlay(src, event, app)
% Récupérer le type de clic et les modificateurs
seltype = src.SelectionType;

% Récupérer la ROI actuellement sélectionnée via la table des ROIs
if isempty(app.content.ROIList)
    return;
end
selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
if isempty(selectedROIIndex)
    return;
end
roi = app.content.ROIList{selectedROIIndex};

% --- Modification : reconstruction du nom complet du canal ---
selectedRow = app.UIAnnotationTable.Selection;
if ~isempty(selectedRow)
    % Récupérer la partie "Annotation" (colonne 2) et "Class" (colonne 3)
    annotationPart = app.UIAnnotationTable.Data{selectedRow(1), 2};
    classPart = app.UIAnnotationTable.Data{selectedRow(1), 3};
    fullChannelName = [annotationPart, '_', classPart];
    % Chercher l'indice du canal correspondant dans roi.display.channel
    channelIdx = find(strcmp(roi.display.channel, fullChannelName), 1);
else
    disp('No channel is selected; quitting!');
    return;
end

% Récupérer l'indice du channel dans l'image
pix = roi.findChannelID(roi.display.channel{channelIdx});

% Récupérer le masque courant (dans le canal d'annotation)
currentMask = roi.image(:, :, pix, roi.display.frame);
%allframesMask=roi.image(:, :, pix, :);

axes=app.graphicsHandles.overlayHandles(1).Parent;

%axes=app.OverlayAxes;

% Récupérer le point initial dans l'axe overlay
cp = get(axes, 'CurrentPoint');
xinit = round(cp(1,1));
yinit = round(cp(1,2));

hOverlayImg = app.graphicsHandles.overlayHandles(1); %axes.UserData.CDataHandle;

% Si un double-clic est détecté, on affiche l'objet sélectionné
if strcmp(seltype, 'open')
    displaySelectedObject(app);
    return;
end


% Déterminer la taille du pinceau (bsize) en fonction du type de clic
if strcmp(seltype, 'normal')
    bsize = 1;
elseif strcmp(seltype, 'alt')
    bsize = 2;
elseif strcmp(seltype, 'extend')
    bsize = 3;
else
    bsize = 1;
end

% Changer le curseur pendant la peinture
src.Pointer = 'cross';


% Attacher les callbacks de mouvement et de relâche
src.WindowButtonMotionFcn = @wbmcb;
src.WindowButtonUpFcn = @wbucb;

% --- Callback imbriquée pour suivre le mouvement (peinture en continu) ---
    function wbmcb(~, ~)
        cpMotion = get(axes, 'CurrentPoint');
        x = round(cpMotion(1,1));
        y = round(cpMotion(1,2));

        currentBsize = bsize;
        modtype = src.CurrentModifier;
        if strcmp(modtype, 'shift') 
             currentBsize = 3;
        elseif strcmp(modtype, 'control') 
             currentBsize = 1;
        end

        % Déterminer la taille du pinceau (en pixels)
        switch currentBsize
            case 1
                brushRadius = 1;
            case 2
                brushRadius = 2;
            case 3
                brushRadius = 6;
            otherwise
                brushRadius = 10;
        end

        % Créer le masque circulaire (pinceau)
        brushMask = createDiskBrush(brushRadius);
        [maskH, maskW] = size(brushMask);
        halfH = floor(maskH/2);
        halfW = floor(maskW/2);

        % Déterminer la région de l'image à mettre à jour
    %    [imgH, imgW, ~] = size(get(axes.UserData.CDataHandle, 'CData'));
       [imgH, imgW, ~] = size(get(hOverlayImg, 'CData'));
        xRange = max(1, x-halfW) : min(imgW, x+halfW);
        yRange = max(1, y-halfH) : min(imgH, y+halfH);

        % Ajuster le masque si le pinceau dépasse des bords
        cropXStart = 1 + max(0, halfW+1 - x);
        cropXEnd   = maskW - max(0, x+halfW - imgW);
        cropYStart = 1 + max(0, halfH+1 - y);
        cropYEnd   = maskH - max(0, y+halfH - imgH);
        croppedBrush = brushMask(cropYStart:cropYEnd, cropXStart:cropXEnd);

        % Vérifier la valeur au point initial cliqué
        if yinit>size(currentMask,1) || xinit>size(currentMask,2)
            disp('painting on the wrong display window')
            return
        end

        if currentMask(yinit, xinit) == 0
            uniqueVals = unique(currentMask);
            uniqueVals(uniqueVals == 0) = [];  % exclure le fond
            if isempty(uniqueVals)
                newAnnotation = 1;
            else
                newAnnotation = max(uniqueVals) + 1;
            end
            paintValue = newAnnotation;
        else
            paintValue = currentMask(yinit, xinit);
        end

        % Détermination de la couleur à utiliser à partir du colormap "lines"
            %  uni = unique(totim(:));
            % uni(uni==0) = [];
            % nuni = max(numel(uni),numel(indices));
            % levmap = eval([levels{ch}{2} '(' num2str(nuni) ')']);

     %   uniqueVals = unique(allframesMask);
        uniqueVals = unique(currentMask);

        uniqueVals(uniqueVals == 0) = [];
        if ~ismember(paintValue, uniqueVals)
            uniqueVals = sort([uniqueVals; paintValue]);
        end
        uniqueVals=1:max(uniqueVals);
        idx = find(uniqueVals == paintValue, 1);
        cmap = lines(max(numel(uniqueVals), idx));
        paintColor = cmap(idx, :);


        % uniqueVals = unique(currentMask);
        % uniqueVals(uniqueVals == 0) = [];
        % if ~ismember(paintValue, uniqueVals)
        %     uniqueVals = sort([uniqueVals; paintValue]);
        % end
        % idx = find(uniqueVals == paintValue, 1);
        % cmap = lines(max(numel(uniqueVals), idx));
        % paintColor = cmap(idx, :);

        if strcmp(modtype, 'shift') | strcmp(modtype, 'control') % effacer la peinture
            paintColor = [0 0 0];
            paintValue = 0;
        end

        for c = 1:3
            hOverlayImg.CData(yRange, xRange, c) = ...
                hOverlayImg.CData(yRange, xRange, c) .* double(~croppedBrush) + double(croppedBrush) * paintColor(c);
        end

        hOverlayImg.AlphaData(yRange, xRange) = hOverlayImg.AlphaData(yRange, xRange) .* double(~croppedBrush) + double(croppedBrush) * app.Transparency.Value;

        roi.image(yRange, xRange, pix, roi.display.frame) = uint16(~croppedBrush) .* roi.image(yRange, xRange, pix, roi.display.frame) + uint16(croppedBrush) * paintValue;

        drawnow;
    end

% --- Callback imbriquée pour la fin du clic (relâchement) ---
    function wbucb(~, ~)
        src.Pointer = 'arrow';
        src.WindowButtonMotionFcn = '';
        src.WindowButtonUpFcn = '';
        drawnow;
    end

% --- Fonction imbriquée pour créer un masque circulaire (pinceau) ---
    function brush = createDiskBrush(radius)
        sz = 2 * radius + 1;
        [X, Y] = meshgrid(1:sz, 1:sz);
        center = radius + 1;
        brush = (sqrt((X - center).^2 + (Y - center).^2) <= radius);
    end

    function displaySelectedObject(app)
        if isempty(app.content.ROIList)
            app.SelectedobjectindexEditField.Value = 'No ROI';
            return;
        end

        x = xinit;
        y = yinit;

        [maskH, maskW] = size(currentMask);
        if x < 1 || x > maskW || y < 1 || y > maskH
            disp('Out of bounds');
            app.SelectedobjectindexEditField.Value = 0;
            return;
        end

        objLabel = currentMask(y, x);
        if objLabel == 0
            app.SelectedobjectindexEditField.Value = 0;
            return;
        end

        app.SelectedobjectindexEditField.Value = double(objLabel);
        app.SelectedObjectLabel = objLabel;

        bwObj = (currentMask == objLabel);
        stats = regionprops(bwObj, 'BoundingBox');

        if isempty(stats)
            return;
        end

        bb = stats(1).BoundingBox;

        [L nlab]=bwlabel(roi.image(:,:, pix, roi.display.frame)==objLabel);
        colo=hOverlayImg.CData(yinit, xinit, :);

        for j=1:nlab
            bwtemp=L==j;
            if bwtemp(yinit,xinit)==1 % found the connected to which the init pixel belongs

                        croppedBrush=imfill( bwtemp, 'holes');
                        %figure, imshow(bwtemp2,[]);
                        yRange=1:size(bwtemp,1);
                        xRange=1:size(bwtemp,2);

                        for c = 1:3
                            hOverlayImg.CData(yRange, xRange, c) = ...
                                hOverlayImg.CData(yRange, xRange, c) .* double(~croppedBrush) + double(croppedBrush) * colo(c);
                        end

                        hOverlayImg.AlphaData(yRange, xRange) = hOverlayImg.AlphaData(yRange, xRange) .* double(~croppedBrush) + double(croppedBrush) * app.Transparency.Value;

                        roi.image(yRange, xRange, pix, roi.display.frame) = uint16(~croppedBrush) .* roi.image(yRange, xRange, pix, roi.display.frame) + uint16(croppedBrush) * objLabel;

                        drawnow
                        break
            end
        end

            if isprop(app, 'SelectedObjectRectangle') && ~isempty(app.SelectedObjectRectangle) && isgraphics(app.SelectedObjectRectangle)
                delete(app.SelectedObjectRectangle);
            end

            app.SelectedObjectRectangle = rectangle(axes, 'Position', bb, ...
                'EdgeColor', 'w', 'LineWidth', 2, 'LineStyle', '--');

            drawnow;
        end
end