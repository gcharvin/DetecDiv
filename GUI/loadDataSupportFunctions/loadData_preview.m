function hImage = loadData_preview(app, parsedData, posIndex, channelIndex, sliderFrame, ax, hImage, forceUpdate)
    if nargin < 8
        forceUpdate = false;
    end

    persistent lastParams
    if isempty(lastParams)
        lastParams = [NaN, NaN, NaN];
    end
% forceUpdate
%     % Si forceUpdate est false et que les indices n'ont pas changé, on redessine uniquement les ROI.
%     if ~forceUpdate && posIndex == lastParams(1) && channelIndex == lastParams(2) && sliderFrame == lastParams(3)
%         %drawROIs(app, parsedData, [], ax);
%         drawROIs(app, parsedData, ax, [], posIndex);
%         'okforce'
%         return;
%     end
    lastParams = [posIndex, channelIndex, sliderFrame];

    
    if ~isfield(parsedData,'positions') || numel(parsedData.positions)==0
        disp('No position to display; quitting...');
        return; 
    end

    % --- [Code existant de lecture et affichage de l'image] ---
    if posIndex > numel(parsedData.positions)
        error('posIndex (%d) excède le nombre de positions (%d).', posIndex, numel(parsedData.positions));
    end
    posData = parsedData.positions(posIndex);
    if channelIndex > numel(posData.channelsDir)
        error('channelIndex (%d) excède le nombre de canaux (%d) pour la position %d.', ...
              channelIndex, numel(posData.channelsDir), posIndex);
    end
    channelFiles = posData.channelsDir{channelIndex};
    if isfield(posData, 'channelFrequencies') && numel(posData.channelFrequencies) >= channelIndex
        freq = posData.channelFrequencies(channelIndex);
    else
        freq = 1;
    end
    effectiveFrame = round(sliderFrame / freq);
    effectiveFrame = max(1, min(effectiveFrame, numel(channelFiles)));
    fileDetail = channelFiles(effectiveFrame);
    filePath = fullfile(fileDetail.folder, fileDetail.name);
    try
        str = ['Reading frame: ' num2str(sliderFrame) '  position: ' posData.userName '  channel: ' posData.userChanName{channelIndex}];
        str = regexprep(str, '\n', ' ');
        title(ax, str, 'Interpreter', 'none');
        pause(0.1);
        img = imread(filePath);
    catch ME
        warning('Erreur lors de la lecture du fichier %s: %s', filePath, ME.message);
        title(ax, 'Reading image failed...');
        img = [];
    end
    if ~isempty(img)
        if size(img,3)==1
            lims = stretchlim(img, [0.01 0.99]);
            img = imadjust(img, lims, []);
        elseif size(img,3)==3
            for c = 1:3
                lims = stretchlim(img(:,:,c), [0.01 0.99]);
                img(:,:,c) = imadjust(img(:,:,c), lims, []);
            end
        end
    end
    if isempty(hImage) || ~ishandle(hImage)
        hImage = imshow(img, 'Parent', ax, 'InitialMagnification', 'fit');
    else
        set(hImage, 'CData', img);
    end
    title(ax, ' ');
    drawROIs(app, parsedData, ax, img, posIndex);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function drawROIs(app, parsedData, ax, img, posIndex)
    % Récupérer les données de la position
    posData = parsedData.positions(posIndex);
    % Si aucune image n'est passée, tenter de récupérer celle affichée.
    if nargin < 4 || isempty(img)
        hImg = findobj(ax, 'Type', 'Image');
        if isempty(hImg)
            return;
        end
        img = get(hImg, 'CData');
    end
    if isempty(img)
        return;
    end
    [rows, cols, ~] = size(img);
    
    % Supprimer les patchs ROI existants (mais pas l'imrect custom)
    oldPatches = findobj(ax, 'Tag', 'ROIpatch');
    if ~isempty(oldPatches)
        delete(oldPatches);
    end

    % Détermination du mode ROI (custom, full ou divide) à partir de parsedData.roitype
    if isfield(parsedData, 'roitype')
        modeROI = lower(parsedData.roitype);
        switch modeROI
            case 'custom'
                % Mode custom : dessiner les ROI détectées (en vert) si plusieurs existent
                if isfield(posData, 'roibb') && ~isempty(posData.roibb)
                    if size(posData.roibb, 1) > 1
                        for k = 1:size(posData.roibb, 1)
                            r = posData.roibb(k,:);
                            patch('Parent', ax, 'XData', [r(1), r(1)+r(3), r(1)+r(3), r(1)], ...
                                  'YData', [r(2), r(2), r(2)+r(4), r(2)+r(4)], ...
                                  'FaceColor', 'none', 'EdgeColor', 'g', 'LineWidth', 2, 'Tag', 'ROIpatch');
                        end
                    end
                end

                % Création du rectangle interactif custom s'il n'existe pas déjà
                if ~(isprop(app, 'hCustomROI') && ~isempty(app.hCustomROI) && isvalid(app.hCustomROI))
                    if isfield(parsedData, 'roibb') && ~isempty(parsedData.roibb)
                        defaultPos = parsedData.roibb;
                    else
                        x0 = round((cols - 100)/2);
                        y0 = round((rows - 100)/2);
                        defaultPos = [x0, y0, 60, 60];
                        parsedData.roibb = defaultPos;
                        app.customROIPositionChanged(defaultPos);
                    end
                    app.hCustomROI = drawrectangle(ax, 'Position', defaultPos, 'Color', 'b');
                    addlistener(app.hCustomROI, 'ROIMoved', @(src,evt) customROIPositionChanged(app, src.Position));
                end

            case 'full'
                % Mode full : supprimer le rectangle custom s'il existe et dessiner un patch vert couvrant toute l'image
                if isprop(app, 'hCustomROI') && ~isempty(app.hCustomROI) && isvalid(app.hCustomROI)
                    delete(app.hCustomROI);
                    app.hCustomROI = [];
                end
                patch('Parent', ax, 'XData', [1, cols, cols, 1], 'YData', [1, 1, rows, rows], ...
                      'FaceColor', 'none', 'EdgeColor', 'g', 'LineWidth', 2, 'Tag', 'ROIpatch');
                parsedData.roibb = [1, 1, cols, rows];
          
            case 'divide'
                % Mode divide : supprimer le rectangle custom s'il existe et dessiner un quadrillage
                if isprop(app, 'hCustomROI') && ~isempty(app.hCustomROI) && isvalid(app.hCustomROI)
                    delete(app.hCustomROI);
                    app.hCustomROI = [];
                end
                nDiv = app.ROIDivide.Value;
                if nDiv < 1, nDiv = 1; end
                widthRect = cols / nDiv;
                heightRect = rows / nDiv;
                boundingBoxes = zeros(nDiv*nDiv, 4);
                count = 1;
                for iRect = 0:nDiv-1
                    for jRect = 0:nDiv-1
                        x0 = round(1 + iRect * widthRect);
                        y0 = round(1 + jRect * heightRect);
                        w = round(widthRect);
                        h = round(heightRect);
                        patch('Parent', ax, 'XData', [x0, x0+w, x0+w, x0], 'YData', [y0, y0, y0+h, y0+h], ...
                              'FaceColor', 'none', 'EdgeColor', 'g', 'LineWidth', 1.5, 'Tag', 'ROIpatch');
                        boundingBoxes(count,:) = [x0, y0, w, h];
                        count = count + 1;
                    end
                end
                parsedData.roibb = boundingBoxes;
        end
    end

    % Ajout d'une superposition des ROI stockées dans app.shallowObj (affichées en rouge)
    if ~isempty(app.shallowObj) && isa(app.shallowObj, 'shallow')
        % Vérifier que l'objet shallowObj possède un champ fov et que pour cette position, roi est défini
        if isprop(app.shallowObj, 'fov') && numel(app.shallowObj.fov) >= posIndex
            fovData = app.shallowObj.fov(posIndex);
            if  isprop(fovData, 'roi') && any(arrayfun(@(x) isprop(x, 'value'), fovData.roi)) && ~isempty(fovData.roi(1).value)
                roiBox = fovData.roi.value; % Bounding box sous forme [x y width height]
                % Afficher cette bounding box en rouge par-dessus les ROI existantes
                patch('Parent', ax, 'XData', [roiBox(1), roiBox(1)+roiBox(3), roiBox(1)+roiBox(3), roiBox(1)], ...
                      'YData', [roiBox(2), roiBox(2), roiBox(2)+roiBox(4), roiBox(2)+roiBox(4)], ...
                      'FaceColor', 'none', 'EdgeColor', 'r', 'LineWidth', 2, 'Tag', 'ROIpatch');
            end
        end
    end

    % Mise à jour de parsedData (si nécessaire)
    app.parsedData = parsedData;
end
