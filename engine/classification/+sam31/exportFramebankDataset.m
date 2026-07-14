function out = exportFramebankDataset(classif, trainrois, valrois, varargin)
% sam31.exportFramebankDataset  Export SAM3.1-ready JSON annotations + HDF5 framebank.
%
% This exporter avoids the CTC small-file pivot. It writes one HDF5 framebank
% for formatted images and instance masks, plus COCO-style image annotations
% and MoMA-video annotations with persistent track IDs and parentage.

p = inputParser;
p.addParameter('foldername', 'trainingdataset', @(s)ischar(s) || isstring(s));
p.addParameter('framebankName', '', @(s)ischar(s) || isstring(s));
p.addParameter('Frames', [], @(x)isempty(x) || isnumeric(x) || islogical(x) || iscell(x) || isstruct(x));
p.addParameter('writePreview', true, @(x)islogical(x) && isscalar(x));
p.addParameter('previewMaxFrames', 12, @(x)isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('skipEmptyMaskFrames', true, @(x)islogical(x) && isscalar(x));
p.parse(varargin{:});

foldername = char(string(p.Results.foldername));
root = fullfile(classif.path, foldername);
if ~exist(root, 'dir'), mkdir(root); end

framebankName = char(string(p.Results.framebankName));
if isempty(framebankName)
    framebankName = [char(string(classif.strid)) '_sam31_framebank.h5'];
end
framebankPath = fullfile(root, framebankName);
if exist(framebankPath, 'file') == 2
    delete(framebankPath);
end

if nargin < 2 || isempty(trainrois), trainrois = []; end
if nargin < 3 || isempty(valrois), valrois = []; end
splits = {'train', trainrois, uint8(1); 'val', valrois, uint8(2)};

channel = classif.channelName;
cltmp = classif.roi;
channelNames = normalizeNameList(channel);
requiredChannels = [channelNames cellfun(@(c)[classif.strid '_' c], classif.classes(:).', 'UniformOutput', false)];
requiredChannels = unique(requiredChannels, 'stable');

frameMeta = struct('split', {}, 'splitCode', {}, 'roiId', {}, 'roiName', {}, ...
    'frameIdx0', {}, 'sourceFrameIdx0', {}, 'framebankIndex', {}, 'imageId', {}, 'videoId', {});
videoRecords = struct('split', {}, 'videoId', {}, 'name', {}, 'roiId', {}, ...
    'roiName', {}, 'width', {}, 'height', {}, 'length', {}, 'frameIndices', {});
trackRecords = struct('split', {}, 'videoId', {}, 'id', {}, 'category_id', {}, ...
    'start_frame', {}, 'end_frame', {}, 'parent_id', {});
annotationsBySplit = struct();
annotationsBySplit.train = {};
annotationsBySplit.val = {};

imageId = struct('train', 1, 'val', 1);
annId = struct('train', 1, 'val', 1);
videoId = struct('train', 1, 'val', 1);
globalFrameIndex0 = 0;

roiSpecs = collectRoiSpecs(cltmp, splits, channelNames{1}, p.Results.Frames, ...
    classif, requiredChannels, logical(p.Results.skipEmptyMaskFrames));
N = sum([roiSpecs.T]);
if N == 0
    error('sam31:NoFramesExported', 'No frames were exported to the SAM31 framebank.');
end
for s = 1:size(splits, 1)
    splitName = splits{s, 1};
    if ~isempty(splits{s, 2}) && ~any(strcmp({roiSpecs.splitName}, splitName) & [roiSpecs.T] > 0)
        error('sam31:EmptySplitAfterMaskFilter', ...
            'SAM31 split "%s" has no frames with GT masks after filtering empty-mask frames.', splitName);
    end
end
skippedEmptyMaskFrames = sum([roiSpecs.skippedEmptyMaskFrames]);
skippedEmptyMaskDetails = {};
for i = 1:numel(roiSpecs)
    skippedEmptyMaskDetails = [skippedEmptyMaskDetails roiSpecs(i).skippedEmptyMaskDetails]; %#ok<AGROW>
end
if skippedEmptyMaskFrames > 0
    fprintf('[SAM31 framebank] Skipped %d frame(s) with no GT mask pixels.\n', skippedEmptyMaskFrames);
    for i = 1:numel(skippedEmptyMaskDetails)
        fprintf('[SAM31 framebank]   skipped: %s\n', skippedEmptyMaskDetails{i});
    end
end
H0 = roiSpecs(1).H;
W0 = roiSpecs(1).W;
exportTic = tic;
lastProgressTic = tic;
progressEveryFrames = max(5, ceil(N / 100));
progressEverySeconds = 5;

fprintf('[SAM31 framebank] Preparing HDF5 framebank: %d frames, %dx%d px, output=%s\n', ...
    N, H0, W0, framebankPath);
if ~isempty(p.Results.Frames)
    fprintf('[SAM31 framebank] Frame selector active: exporting selected frames only.\n');
end

h5create(framebankPath, '/images', [H0, W0, 3, N], 'Datatype', 'uint8');
h5create(framebankPath, '/masks', [H0, W0, N], 'Datatype', 'uint16');
h5create(framebankPath, '/split', [N, 1], 'Datatype', 'uint8');
h5create(framebankPath, '/roi_id', [N, 1], 'Datatype', 'int32');
h5create(framebankPath, '/frame_idx', [N, 1], 'Datatype', 'int32');
h5create(framebankPath, '/video_id', [N, 1], 'Datatype', 'int32');
h5writeatt(framebankPath, '/', 'layout', 'MATLAB [H W C N], h5py sees [N C W H]');
h5writeatt(framebankPath, '/', 'format', 'sam31_detecdiv_framebank_v1');

splitVec = zeros(N, 1, 'uint8');
roiVec = zeros(N, 1, 'int32');
frameVec = zeros(N, 1, 'int32');
videoVec = zeros(N, 1, 'int32');
previewIdx = unique(round(linspace(1, N, min(N, double(p.Results.previewMaxFrames)))));
previewTiles = {};

for s = 1:size(splits, 1)
    splitName = splits{s, 1};
    rois = splits{s, 2};
    splitCode = splits{s, 3};
    fprintf('[SAM31 framebank] Processing split: %s (%d ROIs)\n', splitName, numel(rois));

    for rr = 1:numel(rois)
        roi_id = rois(rr);
        roiObj = cltmp(roi_id);
        fprintf('[SAM31 framebank] Loading ROI %d/%d in %s: #%d (%s)\n', ...
            rr, numel(rois), splitName, roi_id, roiObj.id);
        try
            roiObj.clear;
        catch
            roiObj.image = [];
        end
        try
            roiObj.load('Channel', requiredChannels, 'Data', false, 'Silent');
            roiObj.load('data', 'Silent');
        catch
            roiObj.load;
        end
        cleanup = onCleanup(@() safeClearRoi(roiObj));
        if isempty(roiObj.image)
            warning('sam31:EmptyROI', 'ROI %d (%s) has no image data. Skipping.', roi_id, roiObj.id);
            continue;
        end

        pix = roiObj.findChannelID(channel);
        if iscell(pix), pix = cell2mat(pix); end
        if isempty(pix)
            warning('sam31:MissingInputChannel', 'No channel found for "%s" in ROI %d.', channel, roi_id);
            continue;
        end

        im = roiObj.image;
        H = size(im, 1);
        W = size(im, 2);
        allT = size(im, 4);
        if H ~= H0 || W ~= W0
            error('sam31:FramebankSizeMismatch', ...
                ['SAM31 HDF5 framebank currently requires equal ROI sizes. ' ...
                'First ROI was [%d %d], ROI %s is [%d %d].'], H0, W0, roiObj.id, H, W);
        end
        specIdx = find([roiSpecs.roiId] == int32(roi_id) & strcmp({roiSpecs.splitName}, splitName), 1, 'first');
        if isempty(specIdx)
            sourceFrames = 1:allT;
        else
            sourceFrames = roiSpecs(specIdx).sourceFrames;
        end
        T = numel(sourceFrames);
        fprintf('[SAM31 framebank] ROI loaded: %s | frames=%d | size=%dx%d | channels loaded=%d | elapsed=%.1fs\n', ...
            roiObj.id, T, H, W, size(im, 3), toc(exportTic));
        if T == 0
            fprintf('[SAM31 framebank] ROI %s has no selected frames; skipping.\n', roiObj.id);
            clear cleanup;
            continue;
        end

        currentVideoId = videoId.(splitName);
        videoId.(splitName) = videoId.(splitName) + 1;
        videoName = sprintf('%02d', currentVideoId);
        motherOf = getMotherMapFromROI(roiObj);
        trackTable = zeros(0, 4);
        trackState = initTrackState();

        videoRecords(end+1) = struct( ... %#ok<AGROW>
            'split', splitName, ...
            'videoId', currentVideoId, ...
            'name', videoName, ...
            'roiId', int32(roi_id), ...
            'roiName', char(string(roiObj.id)), ...
            'width', W, ...
            'height', H, ...
            'length', T, ...
            'frameIndices', int32(0:T-1));

        for jj = 1:T
            sourceFrame = sourceFrames(jj);
            frameIdx0 = jj - 1;
            sourceFrameIdx0 = sourceFrame - 1;
            rgb = rawToRgb8(im(:, :, pix(1), sourceFrame));
            [mask, trackTable, trackState] = buildTrackMaskFrame( ...
                roiObj, classif, motherOf, sourceFrame, frameIdx0, trackTable, trackState);
            fbIndex0 = globalFrameIndex0;
            globalFrameIndex0 = globalFrameIndex0 + 1;
            currentImageId = imageId.(splitName);
            imageId.(splitName) = imageId.(splitName) + 1;

            frameMeta(end+1) = struct( ... %#ok<AGROW>
                'split', splitName, ...
                'splitCode', splitCode, ...
                'roiId', int32(roi_id), ...
                'roiName', char(string(roiObj.id)), ...
                'frameIdx0', int32(frameIdx0), ...
                'sourceFrameIdx0', int32(sourceFrameIdx0), ...
                'framebankIndex', int32(fbIndex0), ...
                'imageId', int32(currentImageId), ...
                'videoId', int32(currentVideoId));
            h5write(framebankPath, '/images', rgb, [1 1 1 fbIndex0 + 1], [H0 W0 3 1]);
            h5write(framebankPath, '/masks', mask, [1 1 fbIndex0 + 1], [H0 W0 1]);
            splitVec(fbIndex0 + 1) = splitCode;
            roiVec(fbIndex0 + 1) = int32(roi_id);
            frameVec(fbIndex0 + 1) = int32(frameIdx0);
            videoVec(fbIndex0 + 1) = int32(currentVideoId);
            if p.Results.writePreview && any(previewIdx == fbIndex0 + 1)
                previewTiles{end+1} = overlayMask(rgb, mask); %#ok<AGROW>
            end

            ids = unique(mask(:));
            ids(ids == 0) = [];
            for idv = reshape(ids, 1, [])
                bw = mask == idv;
                if ~any(bw(:)), continue; end
                parentId = parentForTrack(trackTable, double(idv));
                ann = struct();
                ann.id = int32(annId.(splitName));
                ann.image_id = int32(currentImageId);
                ann.video_id = int32(currentVideoId);
                ann.frame_index = int32(frameIdx0);
                ann.source_frame_index = int32(sourceFrameIdx0);
                ann.source_frame_id = int32(sourceFrame);
                ann.framebank_index = int32(fbIndex0);
                ann.track_id = int32(idv);
                ann.object_id = int32(idv);
                ann.parent_id = int32(parentId);
                ann.parent_track_id = int32(parentId);
                ann.category_id = int32(1);
                ann.bbox = bboxFromMask(bw);
                ann.area = double(nnz(bw));
                ann.segmentation = rleFromMask(bw);
                ann.iscrowd = int32(0);
                ann.is_crowd = int32(0);
                ann.source = 'detecdiv_framebank';
                annotationsBySplit.(splitName){end+1} = ann;
                annId.(splitName) = annId.(splitName) + 1;
            end

            if jj == 1 || jj == T || mod(jj, progressEveryFrames) == 0 || toc(lastProgressTic) >= progressEverySeconds
                lastProgressTic = logFrameProgress(splitName, roiObj, rr, numel(rois), ...
                    jj, T, fbIndex0 + 1, N, numel(annotationsBySplit.(splitName)), ...
                    size(trackTable, 1), exportTic);
            end
        end

        for tr = 1:size(trackTable, 1)
            trackRecords(end+1) = struct( ... %#ok<AGROW>
                'split', splitName, ...
                'videoId', currentVideoId, ...
                'id', int32(trackTable(tr, 1)), ...
                'category_id', int32(1), ...
                'start_frame', int32(trackTable(tr, 2)), ...
                'end_frame', int32(trackTable(tr, 3)), ...
                'parent_id', int32(trackTable(tr, 4)));
        end
        fprintf('[SAM31 framebank] Finished ROI %s: frames=%d | tracks=%d | annotations(%s)=%d | elapsed=%.1fs\n', ...
            roiObj.id, T, size(trackTable, 1), splitName, numel(annotationsBySplit.(splitName)), toc(exportTic));
        clear cleanup;
    end
end

fprintf('[SAM31 framebank] Writing frame index vectors to HDF5... elapsed=%.1fs\n', toc(exportTic));
h5write(framebankPath, '/split', splitVec, [1 1], [N 1]);
h5write(framebankPath, '/roi_id', roiVec, [1 1], [N 1]);
h5write(framebankPath, '/frame_idx', frameVec, [1 1], [N 1]);
h5write(framebankPath, '/video_id', videoVec, [1 1], [N 1]);

for s = 1:size(splits, 1)
    splitName = splits{s, 1};
    splitRoot = fullfile(root, splitName);
    if ~exist(splitRoot, 'dir'), mkdir(splitRoot); end
    fprintf('[SAM31 framebank] Writing %s JSON files: frames=%d | videos=%d | tracks=%d | annotations=%d\n', ...
        splitName, sum(strcmp({frameMeta.split}, splitName)), ...
        sum(strcmp({videoRecords.split}, splitName)), ...
        sum(strcmp({trackRecords.split}, splitName)), ...
        numel(annotationsBySplit.(splitName)));
    writeSplitJsons(splitRoot, splitName, frameMeta, videoRecords, trackRecords, ...
        annotationsBySplit.(splitName), framebankName, H0, W0);
end

if p.Results.writePreview
    fprintf('[SAM31 framebank] Writing preview grid: %d tiles\n', numel(previewTiles));
    writePreviewGrid(root, previewTiles);
end

out = struct();
out.framebank = framebankPath;
out.root = root;
out.frames = N;
out.height = H0;
out.width = W0;
out.layout = 'sam31_framebank_json';
out.skippedEmptyMaskFrames = skippedEmptyMaskFrames;
out.skippedEmptyMaskDetails = skippedEmptyMaskDetails;
fprintf('[SAM31 framebank] Exported %d frames to %s\n', N, framebankPath);
end

function lastProgressTic = logFrameProgress(splitName, roiObj, roiNum, roiTotal, frameNum, frameTotal, globalFrame, globalTotal, annCount, trackCount, exportTic)
elapsed = toc(exportTic);
if globalFrame > 0 && elapsed > 0
    fps = globalFrame / elapsed;
    remaining = (globalTotal - globalFrame) / max(fps, eps);
else
    fps = NaN;
    remaining = NaN;
end
fprintf(['[SAM31 framebank] %s ROI %d/%d %s: frame %d/%d | global %d/%d (%.1f%%) ' ...
    '| annotations=%d | tracks=%d | %.2f frame/s | ETA %.1fs\n'], ...
    splitName, roiNum, roiTotal, roiObj.id, frameNum, frameTotal, globalFrame, globalTotal, ...
    100 * double(globalFrame) / double(globalTotal), annCount, trackCount, fps, remaining);
lastProgressTic = tic;
end

function names = normalizeNameList(namesIn)
if ischar(namesIn) || (isstring(namesIn) && isscalar(namesIn))
    names = {char(string(namesIn))};
elseif isstring(namesIn)
    names = cellstr(namesIn(:).');
elseif iscell(namesIn)
    names = cellfun(@(x)char(string(x)), namesIn(:).', 'UniformOutput', false);
else
    names = {char(string(namesIn))};
end
names = names(~cellfun(@isempty, names));
if isempty(names)
    error('sam31:MissingInputChannel', 'No input channel is configured for this classifier.');
end
end

function specs = collectRoiSpecs(cltmp, splits, channelName, framesSpec, classif, requiredChannels, skipEmptyMaskFrames)
specs = struct('splitName', {}, 'roiId', {}, 'H', {}, 'W', {}, 'T', {}, ...
    'sourceFrames', {}, 'skippedEmptyMaskFrames', {}, 'skippedEmptyMaskDetails', {});
H0 = [];
W0 = [];
for s = 1:size(splits, 1)
    splitName = splits{s, 1};
    rois = splits{s, 2};
    for rr = 1:numel(rois)
        roi_id = rois(rr);
        roiObj = cltmp(roi_id);
        [H, W, allT] = readRoiChannelSize(roiObj, channelName);
        sourceFrames = normalizeFrameSelection(framesSpec, allT, roi_id, splitName, rr);
        if isempty(H0)
            H0 = H;
            W0 = W;
        elseif H ~= H0 || W ~= W0
            error('sam31:FramebankSizeMismatch', ...
                ['SAM31 HDF5 framebank currently requires equal ROI sizes. ' ...
                'First ROI was [%d %d], ROI %s is [%d %d].'], ...
                H0, W0, roiObj.id, H, W);
        end
        skippedEmpty = 0;
        skippedDetails = {};
        if skipEmptyMaskFrames && ~isempty(sourceFrames)
            [sourceFrames, skippedEmpty, skippedDetails] = filterFramesWithMasks(roiObj, classif, requiredChannels, sourceFrames, splitName);
        end
        specs(end+1) = struct( ... %#ok<AGROW>
            'splitName', splitName, ...
            'roiId', int32(roi_id), ...
            'H', double(H), ...
            'W', double(W), ...
            'T', double(numel(sourceFrames)), ...
            'sourceFrames', double(sourceFrames(:).'), ...
            'skippedEmptyMaskFrames', double(skippedEmpty), ...
            'skippedEmptyMaskDetails', {skippedDetails});
    end
end
end

function [sourceFrames, skippedEmpty, skippedDetails] = filterFramesWithMasks(roiObj, classif, requiredChannels, sourceFrames, splitName)
originalFrames = sourceFrames;
keep = false(size(sourceFrames));
skippedDetails = {};
try
    roiObj.clear;
catch
    roiObj.image = [];
end
try
    roiObj.load('Channel', requiredChannels, 'Data', false, 'Silent');
catch
    roiObj.load;
end
cleanup = onCleanup(@() safeClearRoi(roiObj));
if isempty(roiObj.image)
    sourceFrames = [];
    skippedEmpty = numel(originalFrames);
    skippedDetails = {formatSkippedFrameDetail(splitName, roiObj, originalFrames)};
    return;
end

maskChannels = [];
for kk = 1:numel(classif.classes)
    chName = [classif.strid '_' classif.classes{kk}];
    cc = roiObj.findChannelID(chName);
    if iscell(cc), cc = cell2mat(cc); end
    maskChannels = [maskChannels reshape(double(cc), 1, [])]; %#ok<AGROW>
end
maskChannels = unique(maskChannels(maskChannels >= 1), 'stable');
if isempty(maskChannels)
    warning('sam31:NoMaskChannelForRoi', ...
        'ROI %s in split %s has no SAM31 GT mask channel; skipping %d frame(s).', ...
        roiObj.id, splitName, numel(originalFrames));
    sourceFrames = [];
    skippedEmpty = numel(originalFrames);
    skippedDetails = {formatSkippedFrameDetail(splitName, roiObj, originalFrames)};
    clear cleanup;
    return;
end

for i = 1:numel(sourceFrames)
    f = sourceFrames(i);
    if f < 1 || f > size(roiObj.image, 4)
        continue;
    end
    frameHasMask = false;
    for c = maskChannels
        if any(roiObj.image(:, :, c, f) ~= 0, 'all')
            frameHasMask = true;
            break;
        end
    end
    keep(i) = frameHasMask;
end
sourceFrames = sourceFrames(keep);
skippedEmpty = nnz(~keep);
if skippedEmpty > 0
    skippedFrames = originalFrames(~keep);
    skippedDetails = {formatSkippedFrameDetail(splitName, roiObj, skippedFrames)};
    warning('sam31:EmptyMaskFramesSkipped', ...
        'ROI %s in split %s: skipped %d/%d frame(s) with no GT mask pixels: %s.', ...
        roiObj.id, splitName, skippedEmpty, numel(originalFrames), frameListText(skippedFrames));
end
clear cleanup;
end

function txt = formatSkippedFrameDetail(splitName, roiObj, frames)
txt = sprintf('%s / ROI %s / frames %s', splitName, char(string(roiObj.id)), frameListText(frames));
end

function txt = frameListText(frames)
frames = unique(round(double(frames(:)')), 'stable');
if isempty(frames)
    txt = '';
elseif numel(frames) <= 20
    txt = strjoin(cellstr(string(frames)), ',');
else
    txt = sprintf('%s,...,%s (%d frames)', ...
        strjoin(cellstr(string(frames(1:10))), ','), ...
        strjoin(cellstr(string(frames(end-4:end))), ','), ...
        numel(frames));
end
end

function frames = normalizeFrameSelection(spec, frameCount, roiId, splitName, roiPosition)
if isempty(spec)
    frames = 1:frameCount;
    return;
end

if isstruct(spec)
    candidates = {sprintf('roi%d', roiId), sprintf('%s_roi%d', splitName, roiId), splitName, 'frames'};
    selected = [];
    for k = 1:numel(candidates)
        if isfield(spec, candidates{k})
            selected = spec.(candidates{k});
            break;
        end
    end
    if isempty(selected)
        frames = 1:frameCount;
    else
        frames = normalizeFrameSelection(selected, frameCount, roiId, splitName, roiPosition);
    end
    return;
end

if iscell(spec)
    if numel(spec) >= roiPosition && ~isempty(spec{roiPosition})
        frames = normalizeFrameSelection(spec{roiPosition}, frameCount, roiId, splitName, roiPosition);
    else
        frames = 1:frameCount;
    end
    return;
end

if (isnumeric(spec) || islogical(spec)) && isscalar(spec) && double(spec) <= 0
    frames = 1:frameCount;
    return;
end

if ischar(spec) || isstring(spec)
    txt = strtrim(char(string(spec)));
    if isempty(txt) || any(strcmpi(txt, {'all', '0', '-1'}))
        frames = 1:frameCount;
        return;
    end
    txt = strrep(txt, ',', ' ');
    frames = str2num(txt); %#ok<ST2NM>
elseif islogical(spec)
    frames = find(spec);
else
    frames = double(spec);
end

frames = unique(round(frames(:).'), 'stable');
frames = frames(isfinite(frames) & frames >= 1 & frames <= frameCount);
end

function [H, W, T] = readRoiChannelSize(roiObj, channelName)
h5File = fullfile(roiObj.path, sprintf('im_%s.h5', roiObj.id));
if exist(h5File, 'file') == 2
    info = h5info(h5File);
    dsets = info.Datasets;
    for i = 1:numel(dsets)
        datasetPath = ['/' dsets(i).Name];
        logicalName = dsets(i).Name;
        try
            logicalName = h5readatt(h5File, datasetPath, 'channel_name');
        catch
        end
        if strcmpi(char(string(logicalName)), channelName) || strcmpi(dsets(i).Name, channelName)
            sz = dsets(i).Dataspace.Size;
            sz = normalizeH5Size(sz);
            H = sz(1);
            W = sz(2);
            T = sz(4);
            return;
        end
    end
end

roiObj.load('Channel', channelName, 'Data', false, 'Silent');
cleanup = onCleanup(@() safeClearRoi(roiObj));
if isempty(roiObj.image)
    error('sam31:EmptyROI', 'ROI %s has no image data.', roiObj.id);
end
H = size(roiObj.image, 1);
W = size(roiObj.image, 2);
T = size(roiObj.image, 4);
clear cleanup;
end

function sz = normalizeH5Size(sz)
sz = double(sz(:).');
switch numel(sz)
    case 2
        sz = [sz 1 1];
    case 3
        sz = [sz 1];
    otherwise
        sz = sz(1:4);
end
end

function writeSplitJsons(splitRoot, splitName, frameMeta, videoRecords, trackRecords, annotations, framebankName, H, W)
categories = struct('id', int32(1), 'name', 'cell', 'supercategory', 'cell');
frames = frameMeta(strcmp({frameMeta.split}, splitName));
videos = videoRecords(strcmp({videoRecords.split}, splitName));
tracks = trackRecords(strcmp({trackRecords.split}, splitName));

images = emptyStructArray({'id','file_name','framebank_path','framebank_index','width','height','video_id','frame_index','frame_id','source_frame_index','source_frame_id','roi_id','roi_name'});
for k = 1:numel(frames)
    images = appendStruct(images, struct( ...
        'id', frames(k).imageId, ...
        'file_name', sprintf('framebank://%d', frames(k).framebankIndex), ...
        'framebank_path', framebankName, ...
        'framebank_index', frames(k).framebankIndex, ...
        'width', int32(W), ...
        'height', int32(H), ...
        'video_id', frames(k).videoId, ...
        'frame_index', frames(k).frameIdx0, ...
        'frame_id', frames(k).frameIdx0, ...
        'source_frame_index', frames(k).sourceFrameIdx0, ...
        'source_frame_id', int32(frames(k).sourceFrameIdx0 + 1), ...
        'roi_id', frames(k).roiId, ...
        'roi_name', frames(k).roiName));
end

videoJson = emptyStructArray({'id','name','width','height','length','file_names','framebank_path','framebank_indices','roi_id','roi_name','neg_category_ids','not_exhaustive_category_ids'});
for k = 1:numel(videos)
    frameIdx = find([frames.videoId] == int32(videos(k).videoId));
    [~, ord] = sort([frames(frameIdx).frameIdx0]);
    frameIdx = frameIdx(ord);
    fbIndices = [frames(frameIdx).framebankIndex];
    fileNames = arrayfun(@(idx)sprintf('framebank://%d', idx), fbIndices, 'UniformOutput', false);
    videoJson = appendStruct(videoJson, struct( ...
        'id', int32(videos(k).videoId), ...
        'name', videos(k).name, ...
        'width', int32(videos(k).width), ...
        'height', int32(videos(k).height), ...
        'length', int32(videos(k).length), ...
        'file_names', {fileNames}, ...
        'framebank_path', framebankName, ...
        'framebank_indices', int32(fbIndices), ...
        'roi_id', videos(k).roiId, ...
        'roi_name', videos(k).roiName, ...
        'neg_category_ids', [], ...
        'not_exhaustive_category_ids', []));
end

trackJson = emptyStructArray({'video_id','id','category_id','start_frame','end_frame','parent_id'});
for k = 1:numel(tracks)
    trackJson = appendStruct(trackJson, struct( ...
        'video_id', int32(tracks(k).videoId), ...
        'id', int32(tracks(k).id), ...
        'category_id', int32(1), ...
        'start_frame', int32(tracks(k).start_frame), ...
        'end_frame', int32(tracks(k).end_frame), ...
        'parent_id', int32(tracks(k).parent_id)));
end

coco = struct('info', struct('description', 'DetecDiv SAM31 framebank image dataset'), ...
    'images', {structArrayToCell(images)}, ...
    'annotations', {structArrayToCell(annotations)}, ...
    'categories', {{categories}});
video = struct('info', struct('description', 'DetecDiv SAM31 framebank video dataset'), ...
    'categories', {{categories}}, ...
    'videos', {structArrayToCell(videoJson)}, ...
    'images', {structArrayToCell(images)}, ...
    'tracks', {structArrayToCell(trackJson)}, ...
    'annotations', {structArrayToCell(annotations)}, ...
    'licenses', {{}});

writeJson(fullfile(splitRoot, '_annotations.coco.json'), coco);
writeJson(fullfile(splitRoot, '_annotations.moma_video.json'), video);
end

function trackState = initTrackState()
trackState = struct();
trackState.globalID = uint32(0);
trackState.local2global = containers.Map('KeyType', 'char', 'ValueType', 'uint32');
trackState.trackRowOfGID = containers.Map('KeyType', 'uint32', 'ValueType', 'uint32');
end

function [trackMask, trackTable, trackState] = buildTrackMaskFrame(roiObj, classif, motherOf, frameIndex, compactFrameIdx0, trackTable, trackState)
im = roiObj.image;
H = size(im, 1);
W = size(im, 2);
frame0 = uint32(compactFrameIdx0);
trackMask = zeros(H, W, 'uint16');

for kk = 1:numel(classif.classes)
    chName = [classif.strid '_' classif.classes{kk}];
    cc = roiObj.findChannelID(chName);
    if isempty(cc), continue; end
    lab = uint32(roiObj.image(:, :, cc, frameIndex));
    ids = unique(lab(:));
    ids(ids == 0) = [];
    for id = reshape(uint32(ids), 1, [])
        pixz = lab == id;
        if ~any(pixz(:)), continue; end
        key = makeKey(kk, id);
        if ~isKey(trackState.local2global, key)
            parentGid = uint32(0);
            if ~isempty(motherOf) && isKey(motherOf, int32(id))
                motherId = uint32(motherOf(int32(id)));
                motherKey = makeKey(kk, motherId);
                if isKey(trackState.local2global, motherKey)
                    parentGid = trackState.local2global(motherKey);
                end
            end
            trackState.globalID = trackState.globalID + 1;
            gid = trackState.globalID;
            trackState.local2global(key) = gid;
            trackTable = [trackTable; double([gid, frame0, frame0, parentGid])]; %#ok<AGROW>
            trackState.trackRowOfGID(gid) = uint32(size(trackTable, 1));
        else
            gid = trackState.local2global(key);
            row = double(trackState.trackRowOfGID(gid));
            trackTable(row, 3) = double(frame0);
        end
        trackMask(pixz) = uint16(trackState.local2global(key));
    end
end
end

function rgb = rawToRgb8(raw)
I = double(raw);
lo = prctile(I(:), 1);
hi = prctile(I(:), 99.8);
if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
    lo = min(I(:));
    hi = max(I(:));
end
if hi <= lo
    ch = zeros(size(raw), 'uint8');
else
    ch = uint8(round(255 * min(max((I - lo) ./ (hi - lo), 0), 1)));
end
rgb = repmat(ch, 1, 1, 3);
end

function rle = rleFromMask(mask)
flat = logical(mask(:));
counts = [];
current = false;
runLen = 0;
for i = 1:numel(flat)
    if flat(i) == current
        runLen = runLen + 1;
    else
        counts(end+1) = runLen; %#ok<AGROW>
        current = flat(i);
        runLen = 1;
    end
end
counts(end+1) = runLen;
rle = struct('size', int32([size(mask, 1), size(mask, 2)]), 'counts', int32(counts));
end

function bbox = bboxFromMask(mask)
[ys, xs] = find(mask);
if isempty(xs)
    bbox = [0 0 0 0];
else
    x0 = min(xs) - 1;
    y0 = min(ys) - 1;
    bbox = double([x0, y0, max(xs) - min(xs) + 1, max(ys) - min(ys) + 1]);
end
end

function parent = parentForTrack(trackTable, trackId)
parent = 0;
if isempty(trackTable), return; end
row = find(trackTable(:, 1) == double(trackId), 1, 'first');
if ~isempty(row), parent = trackTable(row, 4); end
end

function motherOf = getMotherMapFromROI(roi)
motherOf = [];
try
    if ~isprop(roi, 'data') || isempty(roi.data), return; end
    dsIdx = find(arrayfun(@(x) isprop(x, 'groupid') && strcmp(x.groupid, 'cell_information'), roi.data), 1, 'first');
    if isempty(dsIdx), return; end
    ds = roi.data(dsIdx);
    if ~isstruct(ds.userData) || ~isfield(ds.userData, 'motherOf'), return; end
    mo = ds.userData.motherOf;
    if isa(mo, 'containers.Map')
        motherOf = mo;
    end
catch
    motherOf = [];
end
end

function key = makeKey(classIdx, localId)
key = sprintf('%d:%d', double(classIdx), double(localId));
end

function arr = appendStruct(arr, item)
if isempty(arr)
    arr = item;
else
    arr(end+1) = item;
end
end

function arr = emptyStructArray(fields)
arr = cell2struct(cell(size(fields)), fields, 2);
arr = arr([]);
end

function cells = structArrayToCell(arr)
if iscell(arr)
    cells = arr;
elseif isempty(arr)
    cells = {};
else
    cells = num2cell(arr);
end
end

function writeJson(path, data)
fid = fopen(path, 'w');
if fid == -1
    error('sam31:JsonWriteFailed', 'Unable to write %s.', path);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(data), 'char');
end

function writePreviewGrid(root, tiles)
previewDir = fullfile(root, 'preview');
if ~exist(previewDir, 'dir'), mkdir(previewDir); end
if isempty(tiles)
    return;
end
tileH = size(tiles{1}, 1);
tileW = size(tiles{1}, 2);
cols = ceil(sqrt(numel(tiles)));
rows = ceil(numel(tiles) / cols);
canvas = zeros(rows * tileH, cols * tileW, 3, 'uint8');
for i = 1:numel(tiles)
    r = floor((i-1) / cols);
    c = mod(i-1, cols);
    canvas(r*tileH+(1:tileH), c*tileW+(1:tileW), :) = tiles{i};
end
imwrite(canvas, fullfile(previewDir, 'sample_grid.png'));
end

function out = overlayMask(rgb, mask)
out = rgb;
ids = unique(mask(:));
ids(ids == 0) = [];
colors = uint8([255 64 129; 33 150 243; 76 175 80; 255 193 7; 156 39 176; 0 188 212; 255 87 34]);
for i = 1:numel(ids)
    bw = mask == ids(i);
    edge = bw & ~imerode(bw, ones(3));
    col = colors(mod(i-1, size(colors, 1)) + 1, :);
    for c = 1:3
        plane = out(:, :, c);
        plane(edge) = col(c);
        out(:, :, c) = plane;
    end
end
end

function safeClearRoi(roiObj)
try
    roiObj.clear;
catch
end
end
