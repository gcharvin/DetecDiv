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

   
    callArgs = [callArgs {'Extend', true}, {'ForceChannelNames', false}];
    callArgs = [callArgs extraSaveArgs(:)']; %#ok<AGROW>

    
    try
        shallowObj.extractAllROICrops(callArgs{:})
    catch ME
        warning('createTrackedCellROIs:ExtractionFailed', ...
            'extractAllROICrops failed: %s', ME.message);
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

    [rows, cols, framesCount] = size(labelStack);

    % garder uniquement les IDs présents à la 1re frame
    if framesCount < 1
        warning('createTrackedCellROIs:EmptyLabelStack', ...
            'Label stack is empty for ROI %s (FOV %s).', roiObj.id, fovObj.id);
        createdNow = 0; return;
    end
    firstFrameIds = unique(labelStack(:,:,1));
    firstFrameIds(~isfinite(firstFrameIds) | firstFrameIds <= 0) = [];
    uniqueIds = firstFrameIds;
    if isempty(uniqueIds)
        warning('createTrackedCellROIs:NoFirstFrameCells', ...
            'No tracked objects present at the first frame for ROI %s (FOV %s).', ...
            roiObj.id, fovObj.id);
        createdNow = 0; return;
    end

    % snapshot display/channelid parent
    if ~isempty(roiObj.display), refDisplay = roiObj.display; else, refDisplay = struct(); end
    if isprop(roiObj,'channelid') && ~isempty(roiObj.channelid), refChannelID = roiObj.channelid; else, refChannelID = []; end
    parentVal = double(roiObj.value);

    createdNow = 0;

    for idIdx = 1:numel(uniqueIds)
        cellId = uniqueIds(idIdx);

        % 1) présence & bbox par frame (repère ROI parente)
        presence    = false(framesCount,1);
        frameBounds = nan(framesCount,4);
        minRow = inf; minCol = inf; maxRow = 0; maxCol = 0;

        for frame = 1:framesCount
            pix = (labelStack(:,:,frame) == cellId);
            if ~any(pix(:)), continue; end
            presence(frame) = true;

            [rIdx, cIdx] = find(pix);
            lminR = min(rIdx); lmaxR = max(rIdx);
            lminC = min(cIdx); lmaxC = max(cIdx);

            pminR = max(1, floor(lminR - marginPixels));
            pmaxR = min(rows, ceil(lmaxR + marginPixels));
            pminC = max(1, floor(lminC - marginPixels));
            pmaxC = min(cols, ceil(lmaxC + marginPixels));

            frameBounds(frame,:) = [pminC, pminR, pmaxC - pminC + 1, pmaxR - pminR + 1];

            minRow = min(minRow, pminR); maxRow = max(maxRow, pmaxR);
            minCol = min(minCol, pminC); maxCol = max(maxCol, pmaxC);
        end
        if ~any(presence), continue; end
        frameBounds(~presence,:) = NaN;

        % 2) bbox union → globale FOV
        minRow = max(1, minRow); minCol = max(1, minCol);
        maxRow = min(rows, maxRow); maxCol = min(cols, maxCol);
        height = maxRow - minRow + 1; width = maxCol - minCol + 1;
        if height <= 0 || width <= 0, continue; end

        newValue = [ parentVal(1) + (minCol - 1), parentVal(2) + (minRow - 1), width, height ];
        newValue = max(newValue, 1); newValue = round(newValue);

        frameOffsets = nan(framesCount,2);
        frameOffsets(presence,1) = frameBounds(presence,1) - minCol;
        frameOffsets(presence,2) = frameBounds(presence,2) - minRow;

        frameBoundsRelative = frameBounds;
        frameBoundsGlobal   = frameBoundsRelative;
        frameBoundsGlobal(presence,1) = frameBoundsRelative(presence,1) + parentVal(1) - 1;
        frameBoundsGlobal(presence,2) = frameBoundsRelative(presence,2) + parentVal(2) - 1;

        frameList = find(presence)';

        % 3) créer ROI fille
        newId = sprintf('%s_cell%03d', roiObj.id, round(cellId));
        existingIds = string({fovObj.roi.id});
        duplicateIdx = find(existingIds == string(newId));
        if ~isempty(duplicateIdx)
            duplicateIdx = unique(duplicateIdx,'stable');
            try, fovObj.removeROI(duplicateIdx); end %#ok<TRYNC>
        end

        parentHandle    = roiObj;
        parentValueOrig = roiObj.value;

        fovObj.addROI(newValue, fovObj.id);
        newIdx = numel(fovObj.roi);
        newROI = fovObj.roi(newIdx);
        newROI.id     = newId;
        newROI.value  = newValue;
        newROI.parent = fovObj;
        if isempty(newROI.path), newROI.path = fovOutputPath; end

        % héritage display/channelid
        if ~isempty(refDisplay), newROI.display = refDisplay; else, newROI.display = roiObj.display; end
        if ~isempty(refChannelID)
            newROI.channelid = refChannelID;
        elseif isprop(roiObj,'channelid') && ~isempty(roiObj.channelid)
            newROI.channelid = roiObj.channelid;
        end

        % frame d'affichage
        ff = frameList(1);
        if ~isempty(ff)
            newROI.display.frame = ff;
        elseif ~(isfield(newROI.display,'frame') && ~isempty(newROI.display.frame))
            newROI.display.frame = 1;
        end

        % restauration éventuelle parent
        fovObj.roi(newIdx) = newROI;
        if parentROIIndex <= numel(fovObj.roi) && fovObj.roi(parentROIIndex) ~= parentHandle
            warning('createTrackedCellROIs:ParentROIReplaced', ...
                'Parent ROI %s in FOV %s was replaced; restoring handle.', roiObj.id, fovObj.id);
            fovObj.roi(parentROIIndex) = parentHandle;
        end
        if ~isequal(roiObj.value, parentValueOrig), roiObj.value = parentValueOrig; end

        % 4) dataseries minimal
        ds = dataseries;
        ds.class    = "other";
        ds.type     = "temporal";
        ds.groupid  = 'cell_presence';
        ds.parentid = newROI.id;
        ds.data = table(logical(presence), 'VariableNames', {'present'});

        % normaliser bbox: w,h fixes = max ; ROI.value = N×4 (frames présentes)
        Praw = double(frameBoundsGlobal(presence,:)); % N×4
        wmax = max(round(Praw(:,3)));
        hmax = max(round(Praw(:,4)));
        cx = Praw(:,1) + Praw(:,3)/2; cy = Praw(:,2) + Praw(:,4)/2;
        xmin_adj = round(cx - wmax/2); ymin_adj = round(cy - hmax/2);
        Pnorm = [xmin_adj, ymin_adj, repmat(wmax,size(Praw,1),1), repmat(hmax,size(Praw,1),1)];
        newROI.value = Pnorm; fovObj.roi(newIdx) = newROI;

        ud = struct();
        ud.fixed_wh = [wmax, hmax];
        ud.frames   = frameList;
        ds.userData = ud;

        newROI.data = ds; fovObj.roi(newIdx) = newROI;

        % 5) canal virtuel = même nom que le canal de labels
     
              % 5) Canal virtuel persisté (labels) — écriture HDF5 + display safe
        Tfull    = framesCount;
        virtName = char(channelName);                   % renomme si besoin

        % volume masque [hmax x wmax x 1 x Tfull] en uint8
        volFull = zeros(hmax, wmax, 1, Tfull, 'uint8');
        for mIdx = 1:numel(frameList)
            fId = frameList(mIdx);
            absX = double(Pnorm(mIdx,1)); absY = double(Pnorm(mIdx,2));
            relX = round(absX - parentVal(1) + 1);
            relY = round(absY - parentVal(2) + 1);
            wTake = min(wmax, cols); hTake = min(hmax, rows);
            relX = max(1, min(cols - wTake + 1, relX));
            relY = max(1, min(rows - hTake + 1, relY));
            cR = relX:(relX + wTake - 1);
            rR = relY:(relY + hTake - 1);
            slice = labelStack(rR, cR, fId);
            volFull(1:hTake, 1:wTake, 1, fId) = uint8(slice == cellId);
        end

        % Écrit le dataset HDF5 /<virtName>, met à jour image (si dims ok), et réconcilie display
        newROI.appendVirtualChannel(virtName, volFull, true);
        fovObj.roi(newIdx) = newROI;

        createdCount = createdCount + 1;
        created(createdCount).fov                = fovId;
        created(createdCount).parentROI          = roiObj.id;
        created(createdCount).parentROIIndex     = parentROIIndex;
        created(createdCount).cellID             = double(cellId);
        created(createdCount).roiIndex           = newIdx;
        created(createdCount).roiID              = newROI.id;
        created(createdCount).frames             = frameList;
        created(createdCount).bbox               = uint16([minCol, minRow, width, height]);
        created(createdCount).channel            = virtName;
        created(createdCount).frameBoundingBoxes = frameBoundsGlobal;
        created(createdCount).frameOffsets       = frameOffsets;

        processedFOV(end+1) = fovId; %#ok<AGROW>
        createdNow = createdNow + 1;
    end
end

% -------- helpers locaux --------

function D = buildSingleChannelDisplay(name, isIndexed, dispLim)
if nargin<3 || isempty(dispLim), dispLim = [0;1]; end
if nargin<2 || isempty(isIndexed), isIndexed = false; end
D = struct();
D.intensity       = [1 1 1];
D.frame           = 1;
D.selectedchannel = 1;
D.binning         = 1;
D.rgb             = [1 1 1];
D.channel         = {char(name)};
D.stretchlim      = [];
D.displaylim      = dispLim;
D.indexed         = logical(isIndexed);
D.alpha           = 1;
D.contour         = 0;
D.width           = 0;
D.log             = 0;
end

function D = upsertLogicalChannelInDisplay(D, name, varargin)
% Remplace le canal 'name' s'il existe (mise à jour des champs),
% sinon l'ajoute en fin en étendant proprement toutes les matrices/vecteurs.
p = inputParser;
p.addParameter('Indexed', true, @(x)islogical(x)||isnumeric(x));
p.addParameter('DisplayLim', [0;1], @(x)isnumeric(x)&&isequal(size(x),[2,1]));
p.addParameter('IntensityRow', [1 1 1], @(x)isnumeric(x)&&numel(x)==3);
p.addParameter('RgbRow',       [1 1 1], @(x)isnumeric(x)&&numel(x)==3);
p.addParameter('Alpha', 1, @(x)isnumeric(x)&&isscalar(x));
p.addParameter('Selected', 1, @(x)isnumeric(x)&&isscalar(x));
p.addParameter('Contour', 0, @(x)isnumeric(x)&&isscalar(x));
p.addParameter('Width',   0, @(x)isnumeric(x)&&isscalar(x));
p.addParameter('Log',     0, @(x)isnumeric(x)&&isscalar(x));
p.parse(varargin{:});
opt = p.Results;

nm = string(name);
if ~isfield(D,'channel') || isempty(D.channel), D.channel = {}; end
ch = string(D.channel);
idx = find(ch==nm, 1, 'first');

if isempty(idx)
    % append
    D = appendAt(D, numel(ch)+1, nm, opt);
else
    % overwrite (garde la position existante)
    D = appendAt(D, idx, nm, opt, true);
end
end

function D = appendAt(D, pos, nm, opt, isOverwrite)
if nargin<5, isOverwrite = false; end
N0 = numel(D.channel);
% assurer tailles actuelles
D.intensity = ensureRows3(D,'intensity',max(N0,0));
D.rgb       = ensureRows3(D,'rgb',      max(N0,0));
D.selectedchannel = ensureRow(D,'selectedchannel',max(N0,0),1);
D.indexed         = ensureRow(D,'indexed',        max(N0,0),0);
D.alpha           = ensureRow(D,'alpha',          max(N0,0),1);
D.contour         = ensureRow(D,'contour',        max(N0,0),0);
D.width           = ensureRow(D,'width',          max(N0,0),0);
D.log             = ensureRow(D,'log',            max(N0,0),0);
if ~isfield(D,'displaylim') || isempty(D.displaylim) || size(D.displaylim,1)~=2
    D.displaylim = repmat([0;1],1,N0);
end
if ~isfield(D,'frame')   || isempty(D.frame),   D.frame = 1; end
if ~isfield(D,'binning') || isempty(D.binning), D.binning = 1; end
if ~isfield(D,'stretchlim'), D.stretchlim = []; end
if ~isfield(D,'channel') || isempty(D.channel), D.channel = {}; end

if ~isOverwrite
    % insertion à la fin (pos = N0+1)
    if pos ~= N0+1, pos = N0+1; end
    D.channel = [D.channel, {char(nm)}];
    % étendre colonnes
    if size(D.displaylim,2) < pos, D.displaylim(:,pos) = [0;1]; end
    D.intensity(pos,:) = opt.IntensityRow;
    D.rgb(pos,:)       = opt.RgbRow;
else
    % overwrite: remplacer seulement les champs de pos
    D.channel{pos}     = char(nm);
end

% set des valeurs upsertées
D.selectedchannel(pos) = opt.Selected;
D.indexed(pos)         = logical(opt.Indexed);
D.alpha(pos)           = opt.Alpha;
D.contour(pos)         = opt.Contour;
D.width(pos)           = opt.Width;
D.log(pos)             = opt.Log;
D.displaylim(:,pos)    = opt.DisplayLim;
end

function A = ensureRows3(D, field, Nmin)
if ~isfield(D,field) || isempty(D.(field)) || size(D.(field),2)~=3
    A = zeros(max(Nmin,0),3); if Nmin>0, A(:) = 1; end
else
    A = D.(field);
    if size(A,1) < Nmin
        A(end+1:Nmin,:) = repmat([1 1 1], Nmin-size(A,1), 1);
    end
end
end

function v = ensureRow(D, field, Nmin, defVal)
if ~isfield(D,field) || isempty(D.(field))
    v = repmat(defVal,1,max(Nmin,0));
else
    v = D.(field)(:).';
    if numel(v) < Nmin
        v(end+1:Nmin) = defVal;
    end
end
end

function d = defaultDisplay(N, C)
d = struct();
d.intensity       = repmat([1 1 1], N, 1);
d.frame           = 1;
d.selectedchannel = ones(1,N);
d.binning         = 1;
d.rgb             = repmat([1 1 1], N, 1);  % N x 3 (par canal logique)
d.channel         = arrayfun(@(k)sprintf('channel_%d',k), 1:N, 'UniformOutput', false);
d.stretchlim      = [];
d.displaylim      = repmat([0;1], 1, C);
d.indexed         = zeros(1,N);
d.alpha           = ones(1,N);
d.contour         = zeros(1,N);
d.width           = ones(1,N);
d.log             = zeros(1,N);
end


