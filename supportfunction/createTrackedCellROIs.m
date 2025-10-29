function created = createTrackedCellROIs(shallowObj, varargin)
%CREATETRACKEDCELLROIS Generate ROI objects for each tracked cell label.
%   CREATED = CREATETRACKEDCELLROIS(PROJECT) searches every ROI in the
%   shallow project PROJECT for a lineage/label channel and, when found,
%   creates one ROI per tracked object (cell). The newly created ROIs are
%   appended to the corresponding FOV and populated with a temporal
%   dataseries describing the frames where the object is present. Raw image
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
%       'SaveArgs'  : Cell array of additional arguments forwarded to
%                     saveCroppedImages. Passing a 'fov' argument here is
%                     not allowed.
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

p = inputParser;
p.addParameter('FOV', [], @(x) isempty(x) || (isnumeric(x) && all(x>=1)));
p.addParameter('ROI', [], @(x) isempty(x) || isnumeric(x) || iscell(x));
p.addParameter('Channel', [], @(x) isempty(x) || ischar(x) || isstring(x) || isnumeric(x));
p.addParameter('Margin', 0, @(x) isnumeric(x) && isscalar(x) && x>=0);
p.addParameter('Extract', true, @(x) islogical(x) || isnumeric(x));
p.addParameter('SaveArgs', {}, @(x) iscell(x));
p.parse(varargin{:});

fovSelection = p.Results.FOV;
roiSelection = p.Results.ROI;
channelOption = p.Results.Channel;
marginPixels = double(p.Results.Margin);
doExtract = logical(p.Results.Extract);
extraSaveArgs = p.Results.SaveArgs;

if any(strcmpi(extraSaveArgs(1:2:end), 'fov'))
    error('createTrackedCellROIs:InvalidSaveArgs', ...
        'Do not provide a ''fov'' argument inside ''SaveArgs''; use the ''FOV'' parameter instead.');
end

if isempty(fovSelection)
    fovSelection = 1:numel(shallowObj.fov);
else
    fovSelection = unique(fovSelection(:)');
end

created = struct('fov', {}, 'parentROI', {}, 'parentROIIndex', {}, 'cellID', {}, 'roiIndex', {}, ...
    'roiID', {}, 'frames', {}, 'bbox', {}, 'channel', {});
createdCount = 0;

processedFOV = [];

for idxF = 1:numel(fovSelection)
    fovId = fovSelection(idxF);
    if fovId < 1 || fovId > numel(shallowObj.fov)
        warning('createTrackedCellROIs:InvalidFOV', ...
            'Skipping invalid FOV index %d.', fovId);
        continue;
    end

    fovObj = shallowObj.fov(fovId);
    roiIndices = resolveROISelection(fovObj, roiSelection, idxF);
    if isempty(roiIndices)
        warning('createTrackedCellROIs:NoROI', ...
            'No ROI to process for FOV %s (index %d).', fovObj.id, fovId);
        continue;
    end

    for idxR = 1:numel(roiIndices)
        roiId = roiIndices(idxR);
        if roiId < 1 || roiId > numel(fovObj.roi)
            warning('createTrackedCellROIs:InvalidROI', ...
                'Skipping invalid ROI index %d in FOV %s.', roiId, fovObj.id);
            continue;
        end

        roiObj = fovObj.roi(roiId);

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

        [created, createdCount, processedFOV] = ...
            processTrackedObjects(created, createdCount, processedFOV, ...
            fovObj, roiObj, labelStack, pixIdx, channelName, marginPixels, fovId, roiId);
    end
end

if doExtract && ~isempty(processedFOV)
    uniqueFOV = unique(processedFOV, 'stable');
    try
        shallowObj.saveCroppedImages('fov', uniqueFOV, extraSaveArgs{:});
    catch ME
        warning('createTrackedCellROIs:ExtractionFailed', ...
            'saveCroppedImages failed: %s', ME.message);
    end
end

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

function [created, createdCount, processedFOV] = processTrackedObjects(created, createdCount, processedFOV, ...
        fovObj, roiObj, labelStack, pixIdx, channelName, marginPixels, fovId, parentROIIndex)

[rows, cols, framesCount] = size(labelStack);
uniqueIds = unique(labelStack(:));
uniqueIds(~isfinite(uniqueIds) | uniqueIds <= 0) = [];

if isempty(uniqueIds)
    warning('createTrackedCellROIs:EmptyLabels', ...
        'Label channel for ROI %s (FOV %s) contains no tracked objects.', roiObj.id, fovObj.id);
    return;
end

parentVal = double(roiObj.value);

for idIdx = 1:numel(uniqueIds)
    cellId = uniqueIds(idIdx);

    presence = false(framesCount,1);
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
        minRow = min(minRow, min(rIdx));
        maxRow = max(maxRow, max(rIdx));
        minCol = min(minCol, min(cIdx));
        maxCol = max(maxCol, max(cIdx));
    end

    if ~any(presence)
        continue;
    end

    minRow = max(1, floor(minRow - marginPixels));
    minCol = max(1, floor(minCol - marginPixels));
    maxRow = min(rows, ceil(maxRow + marginPixels));
    maxCol = min(cols, ceil(maxCol + marginPixels));

    height = maxRow - minRow + 1;
    width  = maxCol - minCol + 1;

    if height <= 0 || width <= 0
        continue;
    end

    newValue = [parentVal(1) + (minCol - 1), ...
                parentVal(2) + (minRow - 1), ...
                width, height];

    newValue = max(newValue, 1);
    newValue = round(newValue);

    newIdBase = sprintf('%s_cell%03d', roiObj.id, round(cellId));
    existingIds = string({fovObj.roi.id});
    newId = newIdBase;
    suffix = 1;
    while any(existingIds == string(newId))
        suffix = suffix + 1;
        newId = sprintf('%s_%d', newIdBase, suffix);
    end

    fovObj.addROI(newValue, fovObj.id);
    newIdx = numel(fovObj.roi);
    newROI = fovObj.roi(newIdx);
    newROI.id = newId;
    newROI.value = newValue;
    newROI.parent = fovObj;
    newROI.display.frame = find(presence, 1, 'first');

    ds = dataseries;
    ds.class = "other";
    ds.type = "temporal";
    ds.groupid = 'cell_presence';
    ds.parentid = newROI.id;
    presentTable = table(logical(presence), 'VariableNames', {'present'});
    ds.data = presentTable;
    ds.userData = struct('cellID', double(cellId), ...
        'sourceROI', roiObj.id, ...
        'frames', find(presence)', ...
        'labelChannelIndex', pixIdx, ...
        'labelChannelName', channelName);
    ds.plotGroup = {[] [] [] [] [] {'present'}};
    ds.groupProperties = {'present','Plot','auto','auto'};
    newROI.data = ds;

    msg = sprintf('Created tracked cell ROI from %s (cell %d, channel %s).', ...
        roiObj.id, round(cellId), channelName);
    newROI.log(msg, 'Creation');

    createdCount = createdCount + 1;
    created(createdCount).fov = fovId;
    created(createdCount).parentROI = roiObj.id;
    created(createdCount).parentROIIndex = parentROIIndex;
    created(createdCount).cellID = double(cellId);
    created(createdCount).roiIndex = newIdx;
    created(createdCount).roiID = newId;
    created(createdCount).frames = find(presence);
    created(createdCount).bbox = uint16([minCol, minRow, width, height]);
    created(createdCount).channel = channelName;

    processedFOV(end+1) = fovId; %#ok<AGROW>
end

end
