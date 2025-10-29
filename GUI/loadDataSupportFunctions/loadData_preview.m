function hImage = loadData_preview(app, parsedData, posIndex, channelIndex, sliderFrame, ax, hImage, forceUpdate)
    % loadData_preview
    % Affiche une frame donnée (sliderFrame) d'une position (posIndex) et
    % d'un canal (channelIndex) dans l'axe ax, avec mise à jour du handle hImage.
    %
    % Cette version gère :
    %   - les FOV déjà présentes dans le projet shallow (lecture via fov.readImage)
    %   - les nouvelles positions multitiff non encore importées
    %   - les nouvelles positions basées sur des fichiers individuels
    %
    % app.shallowObj doit exister si on prévisualise une FOV déjà importée.

    if nargin < 8
        forceUpdate = false;
    end

    % -- On garde un cache de derniers paramètres pour éventuellement éviter du redraw
    persistent lastParams
    if isempty(lastParams)
        lastParams = [NaN, NaN, NaN];
    end
    lastParams = [posIndex, channelIndex, sliderFrame];

    % --- sécurité basique ---
    if ~isfield(parsedData,'positions') || numel(parsedData.positions)==0
        disp('No position to display; quitting...');
        return;
    end
    if posIndex > numel(parsedData.positions)
        error('posIndex (%d) excède le nombre de positions (%d).', ...
              posIndex, numel(parsedData.positions));
    end
    posData = parsedData.positions(posIndex);

    if channelIndex > numel(posData.channelsDir)
        error('channelIndex (%d) excède le nombre de canaux (%d) pour la position %d.', ...
              channelIndex, numel(posData.channelsDir), posIndex);
    end

    %========================
    % 1. Calcul de la frame logique à afficher
    %========================
    if isfield(posData, 'channelFrequencies') && numel(posData.channelFrequencies) >= channelIndex
        freq = posData.channelFrequencies(channelIndex);
    else
        freq = 1;
    end
    effectiveFrame = round(sliderFrame / freq);
    if effectiveFrame < 1
        effectiveFrame = 1;
    end

    %========================
    % 2. Essayer de trouver si cette position correspond à une FOV
    %    déjà dans le projet shallow
    %========================
    fovMatch = [];
    if ~isempty(app.shallowObj) && isa(app.shallowObj,'shallow') && isprop(app.shallowObj,'fov') && ~isempty(app.shallowObj.fov)
        % on suppose: posData.userName == shallowObj.fov(k).id
        if isfield(posData,'userName') && ~isempty(posData.userName)
            for kk = 1:numel(app.shallowObj.fov)
                if isprop(app.shallowObj.fov(kk),'id') && strcmp(app.shallowObj.fov(kk).id, posData.userName)
                    fovMatch = app.shallowObj.fov(kk);
                    break;
                end
            end
        end
    end

    %========================
    % 3. Lecture de l'image
    %========================
    img = [];

    if ~isempty(fovMatch)
        % -------- CAS "position déjà présente dans le projet" --------
        % on s'appuie sur fov.readImage pour gérer automatiquement
        % multitiff, frames, etc.
        try
            % clamp frame à ce que le fov connaît
            totalFramesForChan = 1;
            if numel(fovMatch.frames) >= channelIndex
                totalFramesForChan = fovMatch.frames(channelIndex);
            elseif ~isempty(fovMatch.frames)
                totalFramesForChan = max(fovMatch.frames);
            end
            if effectiveFrame > totalFramesForChan
                effectiveFrame = totalFramesForChan;
            end

            img = fovMatch.readImage(effectiveFrame, channelIndex);

            % titre overlay
            if isfield(posData,'userChanName') && numel(posData.userChanName)>=channelIndex
                chName = posData.userChanName{channelIndex};
            else
                chName = sprintf('Channel%d', channelIndex-1);
            end
            str = sprintf('Reading frame %d (pos %s / chan %s)', ...
                          sliderFrame, posData.userName, chName);
            title(ax, str, 'Interpreter','none');

        catch ME
            warning('Erreur lecture image (FOV project mode): %s', ME.message);
            title(ax, 'Reading image failed...');
            img = [];
        end

    else
        % -------- CAS "nouvelle position pas encore importée dans shallowObj" --------
        % Deux sous-cas possibles :
        %   (A) multitiff unique (pas encore éclaté en fichiers physiques)
        %   (B) vraies images individuelles sur disque

        channelFiles = posData.channelsDir{channelIndex};
        nFiles = numel(channelFiles);

        if nFiles < 1
            warning('No files available for this channel.');
            img = [];
        else
            effectiveFrame = min(effectiveFrame, nFiles);
        end

        try
            % ---- Sous-cas (A) multitiff virtuel ----
            if isfield(posData,'isMultiTiff') && posData.isMultiTiff && ...
               isfield(posData,'multiTiffPath') && ~isempty(posData.multiTiffPath) && ...
               exist(posData.multiTiffPath,'file')

                % nombre total de canaux dans ce multitiff
                if isfield(posData,'numChannels') && ~isempty(posData.numChannels)
                    nChanTotal = posData.numChannels;
                else
                    nChanTotal = numel(posData.channelsDir);
                end

                % index dans la pile TIFF:
                % ordre supposé: t1 ch1,ch2,...,chN; t2 ch1,ch2,... etc.
                pix = (effectiveFrame-1)*nChanTotal + channelIndex;

                img = imread(posData.multiTiffPath,'tif',pix);

                % titre preview
                if isfield(posData,'userChanName') && numel(posData.userChanName)>=channelIndex
                    chName = posData.userChanName{channelIndex};
                else
                    chName = sprintf('Channel%d', channelIndex-1);
                end
                str = sprintf('Reading frame %d (pos %s / chan %s) [multitiff preview]', ...
                              sliderFrame, posData.userName, chName);
                title(ax, str, 'Interpreter','none');

            else
                % ---- Sous-cas (B) fichiers physiques par frame ----
                fileDetail = channelFiles(effectiveFrame);

                % certains structs n'ont pas .folder (selon comment on les a créés)
                if isfield(fileDetail,'folder') && ~isempty(fileDetail.folder)
                    baseFolder = fileDetail.folder;
                elseif isfield(posData,'folder') && ~isempty(posData.folder)
                    baseFolder = posData.folder;
                else
                    baseFolder = '';
                end

                if isfield(fileDetail,'name')
                    thisName = fileDetail.name;
                else
                    thisName = '';
                end

                filePath = fullfile(baseFolder, thisName);

                img = imread(filePath);

                if isfield(posData,'userChanName') && numel(posData.userChanName)>=channelIndex
                    chName = posData.userChanName{channelIndex};
                else
                    chName = sprintf('Channel%d', channelIndex-1);
                end
                str = sprintf('Reading frame %d (pos %s / chan %s)', ...
                              sliderFrame, posData.userName, chName);
                title(ax, str, 'Interpreter','none');
            end

        catch ME
            warning('Erreur lecture image (new position preview): %s', ME.message);
            title(ax, 'Reading image failed...');
            img = [];
        end
    end

    %========================
    % 4. Post-traitement contraste / dynamique
    %========================
    if ~isempty(img)
        if ndims(img)==2
            % grayscale
            lims = stretchlim(img, [0.01 0.99]);
            img = imadjust(img, lims, []);
        elseif ndims(img)==3 && size(img,3)==3
            % RGB
            for c = 1:3
                lims = stretchlim(img(:,:,c), [0.01 0.99]);
                img(:,:,c) = imadjust(img(:,:,c), lims, []);
            end
        end
    end

    %========================
    % 5. Affichage effectif dans l'axe dédié
    %========================
    if isempty(hImage) || ~ishandle(hImage)
        hImage = imshow(img, 'Parent', ax, 'InitialMagnification', 'fit');
    else
        set(hImage, 'CData', img);
    end

    % on efface le titre "temporaire loading"
    title(ax, ' ');

    %========================
    % 6. Dessin des ROIs (bordures vertes / rouges etc.)
    %========================
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

                for i=1:numel(fovData.roi)
                roiBox = fovData.roi(i).value;
                
                % Bounding box sous forme [x y width height]
                % Afficher cette bounding box en rouge par-dessus les ROI existantes
                patch('Parent', ax, 'XData', [roiBox(1), roiBox(1)+roiBox(3), roiBox(1)+roiBox(3), roiBox(1)], ...
                      'YData', [roiBox(2), roiBox(2), roiBox(2)+roiBox(4), roiBox(2)+roiBox(4)], ...
                      'FaceColor', 'none', 'EdgeColor', 'r', 'LineWidth', 4, 'Tag', 'ROIpatch');
                end
            end
        end
    end

    % Mise à jour de parsedData (si nécessaire)
    app.parsedData = parsedData;
end
