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
    %parsedData
    
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
    
    % Supprimer les patchs ROI (mais pas l'imrect custom)
    oldPatches = findobj(ax, 'Tag', 'ROIpatch');
    if ~isempty(oldPatches)
        delete(oldPatches);
    end

    % Sélection du mode ROI dans parsedData.roitype (stocké globalement dans parsedData)
    if isfield(parsedData, 'roitype')
        modeROI = lower(parsedData.roitype);
        switch modeROI
            case 'custom'
                % Mode custom : on utilise drawrectangle pour créer ou mettre à jour le rectangle interactif.

                if isfield(posData, 'roibb') && ~isempty(posData.roibb)
                    if size(posData.roibb, 1) > 1
                        % Plusieurs ROI détectées : les dessiner en magenta.
                        for k = 1:size(posData.roibb, 1)
                            r = posData.roibb(k,:);
                            patch('Parent', ax, 'XData', [r(1), r(1)+r(3), r(1)+r(3), r(1)], ...
                                  'YData', [r(2), r(2), r(2)+r(4), r(2)+r(4)], ...
                                  'FaceColor', 'none', 'EdgeColor', 'g', 'LineWidth', 2, 'Tag', 'ROIpatch');
                        end
                    end
                end

                if ~(isprop(app, 'hCustomROI') && ~isempty(app.hCustomROI) && isvalid(app.hCustomROI))
                    if isfield(parsedData, 'roibb') && ~isempty(parsedData.roibb)
                        defaultPos = parsedData.roibb;
                    else
                        % Par défaut, centrer un rectangle de 100x100.
                        x0 = round((cols - 100)/2);
                        y0 = round((rows - 100)/2);
                        defaultPos = [x0, y0, 60, 60];
                        parsedData.roibb = defaultPos;
                       % parsedData.roipattern = imcrop(img, defaultPos);
                        app.customROIPositionChanged(defaultPos);
                       
                    end
                    % Créer le rectangle interactif avec drawrectangle
                  
                    app.hCustomROI = drawrectangle(ax, 'Position', defaultPos, 'Color', 'b');
                    % Ajouter un listener pour mettre à jour la position custom
                    addlistener(app.hCustomROI, 'ROIMoved', @(src,evt) customROIPositionChanged(app, src.Position));
                else
                    % Si le rectangle existe déjà, on peut le mettre à jour (par exemple, le repositionner si parsedData.roibb a changé)
                    % Ici, on laisse l'utilisateur interagir directement.
                end

            case 'full'
                % Supprimer le rectangle custom s'il existe

                if isprop(app, 'hCustomROI') && ~isempty(app.hCustomROI) && isvalid(app.hCustomROI)
                    delete(app.hCustomROI);
                    app.hCustomROI = [];
                end
      
                % Dessiner un patch rouge couvrant toute l'image
                patch('Parent', ax, 'XData', [1, cols, cols, 1], 'YData', [1, 1, rows, rows], ...
                      'FaceColor', 'none', 'EdgeColor', 'g', 'LineWidth', 2, 'Tag', 'ROIpatch')
                parsedData.roibb = [1, 1, cols, rows];
          
            case 'divide'
                % Supprimer le rectangle custom s'il existe
                if isprop(app, 'hCustomROI') && ~isempty(app.hCustomROI) && isvalid(app.hCustomROI)
                    delete(app.hCustomROI);
                    app.hCustomROI = [];
                end
                % Dessiner un quadrillage de patchs verts
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
app.parsedData=parsedData;
end
