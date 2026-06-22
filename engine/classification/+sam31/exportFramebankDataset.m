function out = exportFramebankDataset(classif, trainrois, valrois, varargin)
% sam31.exportFramebankDataset  Export SAM3.1-ready JSON annotations + HDF5 framebank.
%
% This exporter avoids the CTC small-file pivot. It writes one HDF5 framebank
% for formatted images and instance masks, plus COCO-style image annotations
% and MoMA-video annotations with persistent track IDs and parentage.

p = inputParser;
p.addParameter('foldername', 'trainingdataset', @(s)ischar(s) || isstring(s));
p.addParameter('framebankName', '', @(s)ischar(s) || isstring(s));
p.addParameter('writePreview', true, @(x)islogical(x) && isscalar(x));
p.addParameter('previewMaxFrames', 12, @(x)isnumeric(x) && isscalar(x) && x > 0);
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

frameMeta = struct('split', {}, 'splitCode', {}, 'roiId', {}, 'roiName', {}, ...
    'frameIdx0', {}, 'framebankIndex', {}, 'image', {}, 'mask', {}, 'imageId', {}, 'videoId', {});
videoRecords = struct('split', {}, 'videoId', {}, 'name', {}, 'roiId', {}, ...
    'roiName', {}, 'width', {}, 'height', {}, 'length', {}, 'frameIndices', {});
trackRecords = struct('split', {}, 'videoId', {}, 'id', {}, 'category_id', {}, ...
    'start_frame', {}, 'end_frame', {}, 'parent_id', {});
annotationsBySplit = struct('train', [], 'val', []);

imageId = struct('train', 1, 'val', 1);
annId = struct('train', 1, 'val', 1);
videoId = struct('train', 1, 'val', 1);
globalFrameIndex0 = 0;
H0 = [];
W0 = [];

for s = 1:size(splits, 1)
    splitName = splits{s, 1};
    rois = splits{s, 2};
    splitCode = splits{s, 3};
    fprintf('[SAM31 framebank] Processing split: %s (%d ROIs)\n', splitName, numel(rois));

    for rr = 1:numel(rois)
        roi_id = rois(rr);
        roiObj = cltmp(roi_id);
        roiObj.load;
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
        T = size(im, 4);
        if isempty(H0)
            H0 = H;
            W0 = W;
        elseif H ~= H0 || W ~= W0
            error('sam31:FramebankSizeMismatch', ...
                ['SAM31 HDF5 framebank currently requires equal ROI sizes. ' ...
                'First ROI was [%d %d], ROI %s is [%d %d].'], H0, W0, roiObj.id, H, W);
        end

        currentVideoId = videoId.(splitName);
        videoId.(splitName) = videoId.(splitName) + 1;
        videoName = sprintf('%02d', currentVideoId);
        motherOf = getMotherMapFromROI(roiObj);
        [trackMasks, trackTable] = buildTrackMasks(roiObj, classif, motherOf);

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

        for jj = 1:T
            frameIdx0 = jj - 1;
            rgb = rawToRgb8(im(:, :, pix(1), jj));
            mask = trackMasks(:, :, jj);
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
                'framebankIndex', int32(fbIndex0), ...
                'image', rgb, ...
                'mask', mask, ...
                'imageId', int32(currentImageId), ...
                'videoId', int32(currentVideoId));

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
                annotationsBySplit.(splitName) = appendStruct(annotationsBySplit.(splitName), ann);
                annId.(splitName) = annId.(splitName) + 1;
            end
        end
        clear cleanup;
    end
end

N = numel(frameMeta);
if N == 0
    error('sam31:NoFramesExported', 'No frames were exported to the SAM31 framebank.');
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
for k = 1:N
    h5write(framebankPath, '/images', frameMeta(k).image, [1 1 1 k], [H0 W0 3 1]);
    h5write(framebankPath, '/masks', frameMeta(k).mask, [1 1 k], [H0 W0 1]);
    splitVec(k) = frameMeta(k).splitCode;
    roiVec(k) = frameMeta(k).roiId;
    frameVec(k) = frameMeta(k).frameIdx0;
    videoVec(k) = frameMeta(k).videoId;
end
h5write(framebankPath, '/split', splitVec, [1 1], [N 1]);
h5write(framebankPath, '/roi_id', roiVec, [1 1], [N 1]);
h5write(framebankPath, '/frame_idx', frameVec, [1 1], [N 1]);
h5write(framebankPath, '/video_id', videoVec, [1 1], [N 1]);

for s = 1:size(splits, 1)
    splitName = splits{s, 1};
    splitRoot = fullfile(root, splitName);
    if ~exist(splitRoot, 'dir'), mkdir(splitRoot); end
    writeSplitJsons(splitRoot, splitName, frameMeta, videoRecords, trackRecords, ...
        annotationsBySplit.(splitName), framebankName, H0, W0);
end

if p.Results.writePreview
    writePreviewGrid(root, frameMeta, p.Results.previewMaxFrames);
end

out = struct();
out.framebank = framebankPath;
out.root = root;
out.frames = N;
out.height = H0;
out.width = W0;
out.layout = 'sam31_framebank_json';
fprintf('[SAM31 framebank] Exported %d frames to %s\n', N, framebankPath);
end

function writeSplitJsons(splitRoot, splitName, frameMeta, videoRecords, trackRecords, annotations, framebankName, H, W)
categories = struct('id', int32(1), 'name', 'cell', 'supercategory', 'cell');
frames = frameMeta(strcmp({frameMeta.split}, splitName));
videos = videoRecords(strcmp({videoRecords.split}, splitName));
tracks = trackRecords(strcmp({trackRecords.split}, splitName));

images = emptyStructArray({'id','file_name','framebank_path','framebank_index','width','height','video_id','frame_index','frame_id','roi_id','roi_name'});
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

function [trackMasks, trackTable] = buildTrackMasks(roiObj, classif, motherOf)
im = roiObj.image;
H = size(im, 1);
W = size(im, 2);
T = size(im, 4);
trackMasks = zeros(H, W, T, 'uint16');
trackTable = zeros(0, 4);
globalID = uint32(0);
local2global = containers.Map('KeyType', 'char', 'ValueType', 'uint32');
trackRowOfGID = containers.Map('KeyType', 'uint32', 'ValueType', 'uint32');

for jj = 1:T
    frame0 = uint32(jj - 1);
    trackMask = zeros(H, W, 'uint16');
    for kk = 1:numel(classif.classes)
        chName = [classif.strid '_' classif.classes{kk}];
        cc = roiObj.findChannelID(chName);
        if isempty(cc), continue; end
        lab = uint32(roiObj.image(:, :, cc, jj));
        ids = unique(lab(:));
        ids(ids == 0) = [];
        for id = reshape(uint32(ids), 1, [])
            pixz = lab == id;
            if ~any(pixz(:)), continue; end
            key = makeKey(kk, id);
            if ~isKey(local2global, key)
                parentGid = uint32(0);
                if ~isempty(motherOf) && isKey(motherOf, int32(id))
                    motherId = uint32(motherOf(int32(id)));
                    motherKey = makeKey(kk, motherId);
                    if isKey(local2global, motherKey)
                        parentGid = local2global(motherKey);
                    end
                end
                globalID = globalID + 1;
                gid = globalID;
                local2global(key) = gid;
                trackTable = [trackTable; double([gid, frame0, frame0, parentGid])]; %#ok<AGROW>
                trackRowOfGID(gid) = size(trackTable, 1);
            else
                gid = local2global(key);
                row = trackRowOfGID(gid);
                trackTable(row, 3) = double(frame0);
            end
            trackMask(pixz) = uint16(local2global(key));
        end
    end
    trackMasks(:, :, jj) = trackMask;
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
if isempty(arr)
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

function writePreviewGrid(root, frameMeta, maxFrames)
previewDir = fullfile(root, 'preview');
if ~exist(previewDir, 'dir'), mkdir(previewDir); end
n = min(numel(frameMeta), double(maxFrames));
idx = unique(round(linspace(1, numel(frameMeta), n)));
tiles = cell(1, numel(idx));
for i = 1:numel(idx)
    k = idx(i);
    tiles{i} = overlayMask(frameMeta(k).image, frameMeta(k).mask);
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
