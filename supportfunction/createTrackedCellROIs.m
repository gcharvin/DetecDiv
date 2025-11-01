function created = createTrackedCellROIs(shallowObj, varargin)
%CREATETRACKEDCELLROIS Generate ROI objects for each tracked cell label.
%   CREATED = CREATETRACKEDCELLROIS(PROJECT) searches every ROI in the
%   shallow project PROJECT for a lineage/label channel and, when found,
%   creates one ROI per tracked object (cell). The newly created ROIs are
%   appended to the corresponding FOV and populated with a temporal
%   dataseries describing the frames where the object is present together
%   with per-frame bounding boxes that follow the tracked contour. Raw image
%   crops are then extracted by calling PROJECT.saveCroppedImages.
%
%   CREATED = CREATETRACKEDCELLROIS(PROJECT, 'FOV', FOVIDS, ...)
%   restricts the operation to the FOV indices listed in FOVIDS. By
%   default, all FOVs are processed.
%
%   Additional name/value parameters:
%       'ROI'       : Either a numeric vector applied to every selected
%                     FOV, or a cell array (same length as 'FOV') that
%                     lists ROI indices per FOV. Default = all ROIs.
%       'Channel'   : Overrides the channel to use for labels. Accepts a
%                     channel name (char/string), a channel index (as in
%                     ROI.display.channel) or a direct slice index in the
%                     ROI image. Default = lineage channel stored in the
%                     ROI, or the first indexed channel.
%       'Margin'    : Scalar padding (pixels) added around the detected
%                     bounding boxes. Default = 0.
%       'Extract'   : Logical flag indicating whether saveCroppedImages
%                     should be called after ROI creation (default = true).
%       'ExtractFrames' : Frame indices (numeric vector or cell array per
%                     FOV) forwarded to saveCroppedImages via its 'frames'
%                     parameter. Default = [].
%       'ExtractChannels' : Channel indices (numeric vector or cell array
%                     per FOV) forwarded to saveCroppedImages via its
%                     'channel' parameter. Default = [].
%       'SaveArgs'  : Cell array of additional arguments forwarded to
%                     saveCroppedImages. Passing a 'fov' argument here is
%                     not allowed. When using 'ExtractFrames' or
%                     'ExtractChannels', do not repeat the corresponding
%                     parameters inside 'SaveArgs'.
%
%   The function returns an array of structs describing the created ROIs
%   with fields: fov, parentROI, parentROIIndex, cellID, roiIndex, roiID,
%   frames, bbox and channel.
%
%   Example:
%       info = createTrackedCellROIs(project, 'FOV', 2, 'ROI', 5, ...
%                        'Margin', 4, 'Extract', true);
%
%   See also ensureCellInformationDataseries, saveCroppedImages.
%
%   Author: DetecDiv contributors
%
arguments
    shallowObj (1,1) shallow
end

arguments (Repeating)
    varargin
end

p = inputParser;
p.addParameter('FOV', [], @(x) isempty(x) || (isnumeric(x) && all(x>=1)));
p.addParameter('ROI', [], @(x) isempty(x) || isnumeric(x) || iscell(x));
p.addParameter('Channel', [], @(x) isempty(x) || ischar(x) || isstring(x) || isnumeric(x));
p.addParameter('Margin', 0, @(x) isnumeric(x) && isscalar(x) && x>=0);
p.addParameter('Extract', true, @(x) islogical(x) || isnumeric(x));
p.addParameter('ExtractFrames', [], @(x) isempty(x) || isnumeric(x) || iscell(x));
p.addParameter('ExtractChannels', [], @(x) isempty(x) || isnumeric(x) || iscell(x));
p.addParameter('SaveArgs', {}, @(x) iscell(x));
p.parse(varargin{:});

fovSelection = p.Results.FOV;
roiSelection = p.Results.ROI;
channelOption = p.Results.Channel;
marginPixels = double(p.Results.Margin);
doExtract = logical(p.Results.Extract);
extractFrames = p.Results.ExtractFrames;
extractChannels = p.Results.ExtractChannels;
extraSaveArgs = p.Results.SaveArgs;

if mod(numel(extraSaveArgs), 2) ~= 0
    error('createTrackedCellROIs:InvalidSaveArgs', ...
        '''SaveArgs'' must contain name/value pairs.');
end

extraArgNames = lower(string(extraSaveArgs(1:2:end)));

if any(extraArgNames == "fov")
    error('createTrackedCellROIs:InvalidSaveArgs', ...
        'Do not provide a ''fov'' argument inside ''SaveArgs''; use the ''FOV'' parameter instead.');
end

if any(extraArgNames == "roi")
    error('createTrackedCellROIs:InvalidSaveArgs', ...
        'Do not provide a ''roi'' argument inside ''SaveArgs''; tracked ROI extraction manages the ROI list automatically.');
end

if ~isempty(extractFrames) && any(extraArgNames == "frames")
    error('createTrackedCellROIs:ConflictingSaveArgs', ...
        'Do not provide ''frames'' inside ''SaveArgs'' when using ''ExtractFrames''.');
end

if ~isempty(extractChannels) && any(extraArgNames == "channel")
    error('createTrackedCellROIs:ConflictingSaveArgs', ...
        'Do not provide ''channel'' inside ''SaveArgs'' when using ''ExtractChannels''.');
end

if isempty(fovSelection)
    fovSelection = 1:numel(shallowObj.fov);
else
    fovSelection = unique(fovSelection(:)');
end

created = struct('fov', {}, 'parentROI', {}, 'parentROIIndex', {}, 'cellID', {}, 'roiIndex', {}, ...
    'roiID', {}, 'frames', {}, 'bbox', {}, 'channel', {}, 'frameBoundingBoxes', {}, 'frameOffsets', {});
createdCount = 0;

processedFOV = [];
channelsByFOV = cell(1, numel(shallowObj.fov));
channelNamesByFOV = cell(1, numel(shallowObj.fov));

for idxF = 1:numel(fovSelection)
    fovId = fovSelection(idxF);
    if fovId < 1 || fovId > numel(shallowObj.fov)
        warning('createTrackedCellROIs:InvalidFOV', ...
            'Skipping invalid FOV index %d.', fovId);
        continue;
    end

    fovObj = shallowObj.fov(fovId);
    removedTracked = clearTrackedCellROIs(fovObj);
    if ~isempty(removedTracked)
        fprintf('Removed %d tracked cell ROI(s) from FOV %s before regeneration.\n', numel(removedTracked), fovObj.id);
    end
    roiIndices = resolveROISelection(fovObj, roiSelection, idxF);
    if isempty(roiIndices)
        warning('createTrackedCellROIs:NoROI', ...
            'No ROI to process for FOV %s (index %d).', fovObj.id, fovId);
        continue;
    end

    fovOutputPath = fullfile(shallowObj.io.path, shallowObj.io.file, fovObj.id);
    if ~exist(fovOutputPath, 'dir')
        mkdir(fovOutputPath);
    end

    totalCreatedForROI = 0;
    for idxR = 1:numel(roiIndices)
        roiId = roiIndices(idxR);
        if roiId < 1 || roiId > numel(fovObj.roi)
            warning('createTrackedCellROIs:InvalidROI', ...
                'Skipping invalid ROI index %d in FOV %s.', roiId, fovObj.id);
            continue;
        end

        roiObj = fovObj.roi(roiId);
        if contains(roiObj.id, '_cell')
            % already a tracked ROI, skip to avoid regenerating children of children
            continue;
        end
        if isempty(roiObj.path)
            roiObj.path = fovOutputPath;
            fovObj.roi(roiId) = roiObj;
        end

        if isempty(channelsByFOV{fovId})
            cha = determineExtractionChannels(fovObj, roiObj);
            channelNames = cell(1, numel(cha));
            for cIdx = 1:numel(cha)
                chanIdx = cha(cIdx);
                if chanIdx >= 1 && chanIdx <= numel(fovObj.channel) && ~isempty(fovObj.channel{chanIdx})
                    channelNames{cIdx} = char(fovObj.channel{chanIdx});
                else
                    channelNames{cIdx} = sprintf('Channel_%d', chanIdx);
                end
            end
            channelsByFOV{fovId} = cha;
            channelNamesByFOV{fovId} = channelNames;
        end

        try
            roiObj.load; %#ok<TRYNC>
        catch
            warning('createTrackedCellROIs:LoadFailed', ...
                'Could not load ROI %s (FOV %s).', roiObj.id, fovObj.id);
            continue;
        end

        if isempty(roiObj.image)
            warning('createTrackedCellROIs:NoImage', ...
                'ROI %s (FOV %s) has no image data; skipping.', roiObj.id, fovObj.id);
            continue;
        end

        if isempty(roiObj.data)
            roiObj.load('data');
        end
        ensureCellInformationDataseries(roiObj);

        [labelStack, pixIdx, channelName] = extractLabelStack(roiObj, channelOption);
        if isempty(labelStack)
            warning('createTrackedCellROIs:NoLabels', ...
                'No valid label channel found for ROI %s (FOV %s).', roiObj.id, fovObj.id);
            continue;
        end

        [created, createdCount, processedFOV, createdNow] = ...
            processTrackedObjects(created, createdCount, processedFOV, ...
            fovObj, roiObj, labelStack, pixIdx, channelName, marginPixels, fovId, roiId, fovOutputPath);
        totalCreatedForROI = totalCreatedForROI + createdNow;
        fprintf('FOV %s / ROI %s: detected %d tracked cell(s).\n', fovObj.id, roiObj.id, createdNow);
    end
    fprintf('FOV %s: total tracked ROIs created so far %d.\n', fovObj.id, totalCreatedForROI);

end

if doExtract && ~isempty(processedFOV)
    uniqueFOV = unique(processedFOV, 'stable');
    callArgs = [{'fov', uniqueFOV}];
    roiSelection = cell(1, numel(uniqueFOV));
    frameSelection = cell(1, numel(uniqueFOV));

    if ~isempty(created)
        createdFov = [created.fov];
        for idx = 1:numel(uniqueFOV)
            fovId = uniqueFOV(idx);
            mask = createdFov == fovId;
            if any(mask)
                createdSubset = created(mask);
                roiSelection{idx} = unique(double([createdSubset.roiIndex]));

                frameEnds = [];
                for kk = 1:numel(createdSubset)
                    frameVec = createdSubset(kk).frames;
                    if ~isempty(frameVec)
                        frameEnds(end+1) = max(frameVec); %#ok<AGROW>
                    end
                end
                if ~isempty(frameEnds)
                    maxFrame = max(frameEnds);
                    frameSelection{idx} = 1:maxFrame;
                end
            else
                roiSelection{idx} = [];
                frameSelection{idx} = [];
            end
        end
    end

    if any(~cellfun(@isempty, roiSelection))
        if numel(uniqueFOV) == 1
            callArgs = [callArgs {'roi', roiSelection{1}}];
        else
            callArgs = [callArgs {'roi', roiSelection}];
        end
    end
    
    if isempty(extractFrames)
        framesAvailable = ~cellfun(@isempty, frameSelection);
        if all(framesAvailable)
            if numel(uniqueFOV) == 1
                callArgs = [callArgs {'frames', frameSelection{1}}];
            else
                callArgs = [callArgs {'frames', frameSelection}];
            end
        end
    else
        callArgs = [callArgs {'frames', extractFrames}]; %#ok<AGROW>
    end

    if isempty(extractChannels)
        channelSelection = cell(1, numel(uniqueFOV));
        channelNamesLog = cell(1, numel(uniqueFOV));
        for idx = 1:numel(uniqueFOV)
            fovId = uniqueFOV(idx);
            channelSelection{idx} = channelsByFOV{fovId};
            channelNamesLog{idx} = channelNamesByFOV{fovId};
        end
        if numel(uniqueFOV) == 1
            callArgs = [callArgs {'channel', channelSelection{1}}];
        else
            callArgs = [callArgs {'channel', channelSelection}];
        end
        for idx = 1:numel(uniqueFOV)
            fovId = uniqueFOV(idx);
            logNames = channelNamesLog{idx};
            fovName = shallowObj.fov(fovId).id;
            if isempty(logNames)
                fprintf('FOV %s: no channel metadata available to forward.\n', fovName);
            else
                fprintf('FOV %s: forwarding channels -> %s\n', fovName, strjoin(logNames, ', '));
            end
        end
    else
        callArgs = [callArgs {'channel', extractChannels}]; %#ok<AGROW>
    end

    callArgs = [callArgs extraSaveArgs(:)']; %#ok<AGROW>

    try
        shallowObj.saveCroppedImages(callArgs{:});
    catch ME
        warning('createTrackedCellROIs:ExtractionFailed', ...
            'saveCroppedImages failed: %s', ME.message);
    end
end

end

function removedIdx = clearTrackedCellROIs(fovObj)
removedIdx = [];
if isempty(fovObj.roi)
    return;
end

toRemove = [];
for idx = 2:numel(fovObj.roi)
    roiObj = fovObj.roi(idx);
    if isTrackedCellROIObject(roiObj) || contains(roiObj.id, '_cell')
        toRemove(end+1) = idx; %#ok<AGROW>
    end
end

if isempty(toRemove)
    return;
end

toRemove = unique(toRemove, 'stable');

for k = 1:numel(toRemove)
    roiIndex = toRemove(k);
    try
        fovObj.roi(roiIndex).clear;
    catch
        % ignore failures while clearing cached data
    end
end

fovObj.removeROI(toRemove);
removedIdx = toRemove;
end

function tf = isTrackedCellROIObject(roiObj)
tf = false;
if isempty(roiObj)
    return;
end

if isprop(roiObj, 'id') && contains(roiObj.id, '_cell')
    tf = true;
    return;
end

try
    if isempty(roiObj.data)
        roiObj.load('data');
    end
catch
    return;
end

if isempty(roiObj.data)
    return;
end

tf = any(arrayfun(@(ds) isprop(ds, 'groupid') && strcmp(ds.groupid, 'cell_presence'), roiObj.data));
end


function roiIndices = resolveROISelection(fovObj, roiSelection, position)
if isempty(roiSelection)
    roiIndices = 1:numel(fovObj.roi);
    return;
end

if isnumeric(roiSelection)
    vals = roiSelection(:)';
    mask = vals >= 1 & vals <= numel(fovObj.roi);
    roiIndices = unique(vals(mask), 'stable');
    return;
end

if iscell(roiSelection)
    if position > numel(roiSelection)
        roiIndices = [];
        return;
    end
    current = roiSelection{position};
    if isempty(current)
        roiIndices = 1:numel(fovObj.roi);
    else
        vals = current(:)';
        mask = vals >= 1 & vals <= numel(fovObj.roi);
        roiIndices = unique(vals(mask), 'stable');
    end
    return;
end

roiIndices = [];
end

function [labelStack, pixIdx, channelName] = extractLabelStack(roiObj, channelOption)
labelStack = [];
pixIdx = [];
channelName = '';

pixCandidates = resolveChannelIndices(roiObj, channelOption);
if isempty(pixCandidates)
    return;
end

pixIdx = pixCandidates(1);
if numel(pixCandidates) > 1
    warning('createTrackedCellROIs:MultipleChannels', ...
        'Multiple channel slices match the label criteria for ROI %s. Using slice %d.', ...
        roiObj.id, pixIdx);
end

labelStack = double(squeeze(roiObj.image(:,:,pixIdx,:)));
if ndims(labelStack) == 2
    labelStack = reshape(labelStack, size(labelStack,1), size(labelStack,2), 1);
end

channelIdx = [];
if pixIdx <= numel(roiObj.channelid)
    channelIdx = roiObj.channelid(pixIdx);
end

if ~isempty(channelIdx) && channelIdx <= numel(roiObj.display.channel)
    channelName = roiObj.display.channel{channelIdx};
else
    channelName = sprintf('Slice_%d', pixIdx);
end

end

function pixCandidates = resolveChannelIndices(roiObj, channelOption)
    pixCandidates = [];

if ~isempty(channelOption)
    if ischar(channelOption) || isstring(channelOption)
        pixCandidates = roiObj.findChannelID(char(channelOption));
    elseif isnumeric(channelOption)
        vals = channelOption(:)';
        for v = vals
            if v >= 1 && v <= size(roiObj.image,3)
                pixCandidates(end+1) = v; %#ok<AGROW>
            elseif v >= 1 && v <= numel(roiObj.display.channel)
                tmp = find(roiObj.channelid == v);
                pixCandidates = [pixCandidates tmp(:)']; %#ok<AGROW>
            end
        end
    end
end

if ~isempty(pixCandidates)
    pixCandidates = unique(pixCandidates, 'stable');
    return;
end

pixCandidates = findLineageChannelFromData(roiObj);
if ~isempty(pixCandidates)
    pixCandidates = unique(pixCandidates, 'stable');
    return;
end

if isfield(roiObj.display, 'indexed') && ~isempty(roiObj.display.indexed)
    idx = find(logical(roiObj.display.indexed), 1, 'first');
    if ~isempty(idx)
        pixCandidates = find(roiObj.channelid == idx);
    end
end

end

function pixCandidates = findLineageChannelFromData(roiObj)
pixCandidates = [];

dsIdx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roiObj.data), 1, 'first');
if isempty(dsIdx)
    return;
end

ds = roiObj.data(dsIdx);
if ~isprop(ds,'userData') || isempty(ds.userData) || ~isstruct(ds.userData)
    return;
end

if isfield(ds.userData,'lineageChannelPix') && ~isempty(ds.userData.lineageChannelPix)
    pixCandidates = double(ds.userData.lineageChannelPix);
end

if isempty(pixCandidates) && isfield(ds.userData,'lineageChannelName') && ~isempty(ds.userData.lineageChannelName)
    try
        pixCandidates = roiObj.findChannelID(char(ds.userData.lineageChannelName));
    catch
        pixCandidates = [];
    end
end

if isempty(pixCandidates)
    return;
end

pixCandidates = pixCandidates(pixCandidates >= 1 & pixCandidates <= size(roiObj.image,3));

end

function channelSelection = determineExtractionChannels(fovObj, roiObj)
channelSelection = [];
if isprop(roiObj, 'channelid') && ~isempty(roiObj.channelid)
    channelSelection = unique(double(roiObj.channelid(:)'), 'stable');
    channelSelection = channelSelection(channelSelection >= 1 & channelSelection <= numel(fovObj.channel));
end
if isempty(channelSelection)
    channelSelection = 1:numel(fovObj.channel);
end
if isempty(channelSelection)
    try
        channelSelection = 1:size(roiObj.image, 3);
    catch
        channelSelection = [];
    end
end
channelSelection = channelSelection(:)';
end

function [created, createdCount, processedFOV, createdNow] = processTrackedObjects( ...
        created, createdCount, processedFOV, ...
        fovObj, roiObj, labelStack, pixIdx, channelName, marginPixels, ...
        fovId, parentROIIndex, fovOutputPath)

    % Dimensions du stack de labels
    [rows, cols, framesCount] = size(labelStack);

    % Liste des IDs d'objets suivis (cellules)
    uniqueIds = unique(labelStack(:));
    uniqueIds(~isfinite(uniqueIds) | uniqueIds <= 0) = [];

    if isempty(uniqueIds)
        warning('createTrackedCellROIs:EmptyLabels', ...
            'Label channel for ROI %s (FOV %s) contains no tracked objects.', ...
            roiObj.id, fovObj.id);
        createdNow = 0;
        return;
    end

    % ---------------------------------------------------------------------
    % FIGER L'APPARENCE DE RÉFÉRENCE
    % On prend un snapshot du display et du channelid de la ROI parente
    % AVANT de créer des nouvelles ROIs, pour éviter que l'ordre des ROIs
    % dans fovObj et les réinsertions ne nous fassent perdre ces réglages.
    % ---------------------------------------------------------------------
    if ~isempty(roiObj.display)
        refDisplay = roiObj.display;      % struct => copie par valeur, safe
    else
        refDisplay = struct();
    end

    if isprop(roiObj, 'channelid') && ~isempty(roiObj.channelid)
        refChannelID = roiObj.channelid;  % typiquement mapping canal -> nom
    else
        refChannelID = [];
    end

    % Valeur d'origine de la ROI parente dans les coords globales du FOV
    parentVal = double(roiObj.value);

    createdNow = 0;

    % ---------------------------------------------------------------------
    % BOUCLE SUR CHAQUE CELLULE TRACKÉE
    % ---------------------------------------------------------------------
    for idIdx = 1:numel(uniqueIds)
        cellId = uniqueIds(idIdx);

        % ---- 1. Détection de présence frame par frame et bounding boxes locales
        presence = false(framesCount,1);
        frameBounds = nan(framesCount, 4);   % [x y w h] relatif à la ROI parente

        minRow = inf;
        minCol = inf;
        maxRow = 0;
        maxCol = 0;

        for frame = 1:framesCount
            maskFrame = labelStack(:,:,frame);
            pix = (maskFrame == cellId);
            if ~any(pix(:))
                continue;
            end

            presence(frame) = true;

            [rIdx, cIdx] = find(pix);
            localMinRow = min(rIdx);
            localMaxRow = max(rIdx);
            localMinCol = min(cIdx);
            localMaxCol = max(cIdx);

            paddedMinRow = max(1, floor(localMinRow - marginPixels));
            paddedMaxRow = min(rows, ceil(localMaxRow + marginPixels));
            paddedMinCol = max(1, floor(localMinCol - marginPixels));
            paddedMaxCol = min(cols, ceil(localMaxCol + marginPixels));

            frameBounds(frame, :) = [paddedMinCol, paddedMinRow, ...
                                     paddedMaxCol - paddedMinCol + 1, ...
                                     paddedMaxRow - paddedMinRow + 1];

            minRow = min(minRow, paddedMinRow);
            maxRow = max(maxRow, paddedMaxRow);
            minCol = min(minCol, paddedMinCol);
            maxCol = max(maxCol, paddedMaxCol);
        end

        if ~any(presence)
            continue;
        end

        % Nettoyer les frames sans présence
        frameBounds(~presence, :) = NaN;

        % ---- 2. BBox union (toutes frames) en coordonnées ROI parente
        minRow = max(1, minRow);
        minCol = max(1, minCol);
        maxRow = min(rows, maxRow);
        maxCol = min(cols, maxCol);

        height = maxRow - minRow + 1;
        width  = maxCol - minCol + 1;

        if height <= 0 || width <= 0
            continue;
        end

        % BBox union en coordonnées FOV globales
        newValue = [ parentVal(1) + (minCol - 1), ...
                     parentVal(2) + (minRow - 1), ...
                     width, height ];

        newValue = max(newValue, 1);
        newValue = round(newValue);

        % Offsets frame par frame dans la bbox union
        frameOffsets = nan(framesCount, 2); % [dx dy] pixel offset
        frameOffsets(presence, 1) = frameBounds(presence, 1) - minCol;
        frameOffsets(presence, 2) = frameBounds(presence, 2) - minRow;

        % BBox par frame : relative et globale
        frameBoundsRelative = frameBounds;
        frameBoundsGlobal = frameBoundsRelative;
        frameBoundsGlobal(presence, 1) = frameBoundsRelative(presence, 1) + parentVal(1) - 1;
        frameBoundsGlobal(presence, 2) = frameBoundsRelative(presence, 2) + parentVal(2) - 1;

        % Union relative (dans coords ROI parente) et globale (coords FOV)
        unionRelative = [minCol, minRow, width, height];
        unionGlobal   = [newValue(1), newValue(2), width, height];

        % ---- 3. Masque union empilé (pour debug / export)
        frameList  = find(presence)';        % frames où la cellule est présente
        maskCount  = numel(frameList);
        maskUnion  = zeros(height, width, maskCount, 'like', labelStack);

        if maskCount > 0
            unionRows = minRow:maxRow;
            unionCols = minCol:maxCol;
            for mIdx = 1:maskCount
                frameId     = frameList(mIdx);
                unionSlice  = labelStack(unionRows, unionCols, frameId);
                maskSlice   = zeros(size(unionSlice), 'like', unionSlice);
                maskSlice(unionSlice == cellId) = unionSlice(unionSlice == cellId);
                maskUnion(:, :, mIdx) = maskSlice;
            end
        end

        % ---- 4. Création d'un ID unique pour la nouvelle ROI
        newIdBase = sprintf('%s_cell%03d', roiObj.id, round(cellId));
        existingIds = string({fovObj.roi.id});
        duplicateIdx = find(existingIds == string(newIdBase));

        if ~isempty(duplicateIdx)
            % On supprime d'éventuelles anciennes ROIs avec le même ID
            duplicateIdx = unique(duplicateIdx, 'stable');
            try
                fovObj.removeROI(duplicateIdx);
            catch
                % On ignore si remove échoue, ce n'est pas bloquant
            end
        end

        newId = newIdBase;

        % Sauvegarde d'un handle de la ROI parente pour restauration
        parentHandle = roiObj;
        parentValueOrig = roiObj.value;

        % ---- 5. Ajouter la nouvelle ROI dans le FOV
        fovObj.addROI(newValue, fovObj.id);
        newIdx = numel(fovObj.roi);
        newROI = fovObj.roi(newIdx);

        newROI.id     = newId;
        newROI.value  = newValue;
        newROI.parent = fovObj;

        if isempty(newROI.path)
            newROI.path = fovOutputPath;
        end

        % ---- 6. HÉRITAGE VISUEL CONTRÔLÉ
        % On applique le refDisplay figé (copie par valeur) et le refChannelID.
        % C'est ici qu'on transmet l'intensity, selectedchannel, rgb,
        % displaylim, stretchlim, etc. de la ROI parente d'origine.
        if ~isempty(refDisplay)
            newROI.display = refDisplay;
        else
            newROI.display = roiObj.display; % fallback
        end

        if ~isempty(refChannelID)
            newROI.channelid = refChannelID;
        elseif isprop(roiObj, 'channelid') && ~isempty(roiObj.channelid)
            newROI.channelid = roiObj.channelid;
        end

        % Adapter juste la frame d'affichage pour la fille :
        firstFrame = find(presence, 1, 'first');
        if ~isempty(firstFrame)
            newROI.display.frame = firstFrame;
        else
            % fallback au frame courant du parent
            if isfield(newROI.display,'frame') && ~isempty(newROI.display.frame)
                % keep as is
            else
                newROI.display.frame = 1;
            end
        end

        % Pousser la ROI modifiée dans fovObj
        fovObj.roi(newIdx) = newROI;

        % ---- 7. Restauration éventuelle de la ROI parente
        % Dans certains cas addROI peut décaler les handles, donc on remet
        % le handle d'origine si MATLAB a "relogé" la parent ROI.
        if parentROIIndex <= numel(fovObj.roi) && fovObj.roi(parentROIIndex) ~= parentHandle
            warning('createTrackedCellROIs:ParentROIReplaced', ...
                ['Parent ROI %s in FOV %s was replaced while creating tracked cell ROIs. ' ...
                 'Restoring the original parent ROI handle.'], roiObj.id, fovObj.id);
            fovObj.roi(parentROIIndex) = parentHandle;
        end

        % Et on restaure sa bbox si elle a bougé
        if ~isequal(roiObj.value, parentValueOrig)
            roiObj.value = parentValueOrig;
        end

        % ---- 8. Ajouter la dataseries "cell_presence" à la nouvelle ROI
        ds = dataseries;
        ds.class    = "other";
        ds.type     = "temporal";
        ds.groupid  = 'cell_presence';
        ds.parentid = newROI.id;

        presentTable = table(logical(presence), 'VariableNames', {'present'});
        ds.data = presentTable;

        ds.userData = struct( ...
            'cellID',                    double(cellId), ...
            'sourceROI',                 roiObj.id, ...
            'frames',                    frameList, ...
            'labelChannelIndex',         pixIdx, ...
            'labelChannelName',          channelName, ...
            'boundingBoxesRelative',     frameBoundsRelative, ...
            'boundingBoxesGlobal',       frameBoundsGlobal, ...
            'boundingBoxUnionRelative',  unionRelative, ...
            'boundingBoxUnionGlobal',    unionGlobal, ...
            'boundingBoxOffsets',        frameOffsets, ...
            'labelMaskUnion',            maskUnion, ...
            'labelMaskFrames',           frameList ...
        );

        % Champs spécifiques à ton écosystème d'affichage / plotting
        ds.plotGroup = {[] [] [] [] [] {'present'}};
        ds.groupProperties = {'present','Plot','auto','auto'};

        newROI.data = ds;

        % ---- 9. Logging création
        msg = sprintf('Created tracked cell ROI from %s (cell %d, channel %s).', ...
            roiObj.id, round(cellId), channelName);
        newROI.log(msg, 'Creation');

        % ---- 10. Renseigner la structure "created" de sortie
        createdCount = createdCount + 1;

        created(createdCount).fov                = fovId;
        created(createdCount).parentROI          = roiObj.id;
        created(createdCount).parentROIIndex     = parentROIIndex;
        created(createdCount).cellID             = double(cellId);
        created(createdCount).roiIndex           = newIdx;
        created(createdCount).roiID              = newId;
        created(createdCount).frames             = frameList;
        created(createdCount).bbox               = uint16([minCol, minRow, width, height]);
        created(createdCount).channel            = channelName;
        created(createdCount).frameBoundingBoxes = frameBoundsGlobal;
        created(createdCount).frameOffsets       = frameOffsets;

        % Marquer ce FOV comme traité
        processedFOV(end+1) = fovId; %#ok<AGROW>
        createdNow = createdNow + 1;
    end
end


