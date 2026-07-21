function report = exportCtcDataset(classif, trainRois, valRois, varargin)
% trackastra.exportCtcDataset  Write raw images, tracked GT masks and lineage.
%
% Each ROI becomes one independent CTC sequence. Ground-truth labels must
% already be temporally stable tracklet IDs. Parent IDs are read from the
% cell_information lineage source bound to that GT channel when available.

ip = inputParser;
ip.addParameter('FolderName','trainingdataset',@(x)ischar(x)||isstring(x));
ip.addParameter('Frames',[],@(x)isempty(x)||isnumeric(x)||islogical(x)||ischar(x)||isstring(x)||iscell(x)||isstruct(x));
ip.parse(varargin{:});

tp = classif.trainingParam;
imageName = scalarText(getField(tp,'imageChannelName',''));
gtName = scalarText(getField(tp,'groundTruthChannelName',''));
if isempty(imageName)
    selectedChannels = classifierInputChannels(classif);
    if ~isempty(selectedChannels)
        imageName = selectedChannels{1};
    end
end
if isempty(gtName)
    gtName = trackastra.annotationChannelName(classif);
end
if isempty(imageName)
    error('trackastra:MissingTrainingImageChannel', ...
        ['trainingParam.imageChannelName must identify the raw/intensity channel. ' ...
         'Alternatively, select the raw channel first in the classifier input list.']);
end
if isempty(gtName)
    error('trackastra:MissingGroundTruthChannel', ...
        ['trainingParam.groundTruthChannelName must identify an indexed channel ' ...
         'whose labels are stable tracklet IDs. No classifier annotation channel could be inferred.']);
end
if strcmp(imageName, gtName)
    error('trackastra:AmbiguousTrainingChannels', ...
        'The raw image channel and tracked ground-truth channel both resolve to "%s".', imageName);
end

% Persist resolved bindings so the training-parameter table and subsequent
% runs expose the exact channels used by the exporter.
classif.trainingParam.imageChannelName = imageName;
classif.trainingParam.groundTruthChannelName = gtName;
fprintf('[Trackastra format] image=%s trackedGT=%s\n', imageName, gtName);

datasetRoot = fullfile(classif.path, char(string(ip.Results.FolderName)));
if exist(datasetRoot,'dir') ~= 7, mkdir(datasetRoot); end
manifestRows = struct('split',{},'sequence',{},'roiId',{},'imageChannel',{}, ...
    'groundTruthChannel',{},'frames',{},'tracklets',{});
frameCount = 0;
trainSequences = {};
validationSequences = {};
sequenceCounter = 0;

splits = {'train', trainRois; 'val', valRois};
for s = 1:size(splits,1)
    splitName = splits{s,1};
    roiIndices = splits{s,2};
    splitRoot = fullfile(datasetRoot, splitName);
    if exist(splitRoot,'dir') ~= 7, mkdir(splitRoot); end
    for r = 1:numel(roiIndices)
        sequenceCounter = sequenceCounter + 1;
        seqName = sprintf('%02d', sequenceCounter);
        roiIndex = roiIndices(r);
        roiobj = classif.roi(roiIndex);
        if isempty(roiobj.image), roiobj.load; end
        if isempty(roiobj.image)
            error('trackastra:EmptyTrainingROI', 'Training ROI %d has no image data.', roiIndex);
        end
        imageIdx = channelIndex(roiobj, imageName, 'image');
        gtIdx = channelIndex(roiobj, gtName, 'ground truth');
        nFrames = size(roiobj.image,4);
        frameList = normalizeTrainingFrameSelection(ip.Results.Frames, nFrames, ...
            'RoiId', roiIndex, 'RoiPosition', r, 'SplitName', splitName);
        if isempty(frameList)
            error('trackastra:EmptyTrainingFrames', 'ROI %d has no selected training frame.', roiIndex);
        end
        if numel(frameList) > 1 && any(diff(frameList) ~= 1)
            error('trackastra:NonContiguousTrainingFrames', ...
                'Trackastra training frames must be contiguous for ROI %d.', roiIndex);
        end

        seqDir = fullfile(splitRoot, seqName);
        traDir = fullfile(splitRoot, [seqName '_GT'], 'TRA');
        if exist(seqDir,'dir') ~= 7, mkdir(seqDir); end
        if exist(traDir,'dir') ~= 7, mkdir(traDir); end
        tracks = uint32([]);
        for f = 1:numel(frameList)
            sourceFrame = frameList(f);
            frame0 = f-1;
            raw = roiobj.image(:,:,imageIdx,sourceFrame);
            mask = roiobj.image(:,:,gtIdx,sourceFrame);
            validateTrackedMask(mask, gtName, roiIndex, sourceFrame);
            mask = uint32(mask);
            if max(mask(:)) > intmax('uint16')
                error('trackastra:GroundTruthIdOverflow', ...
                    'ROI %d frame %d contains tracklet ID %u above uint16.', roiIndex, sourceFrame, max(mask(:)));
            end
            imwrite(toTiffImage(raw), fullfile(seqDir, sprintf('t%03d.tif',frame0)));
            imwrite(uint16(mask), fullfile(traDir, sprintf('man_track%03d.tif',frame0)));
            tracks = union(tracks, unique(mask(mask>0)), 'stable');
            frameCount = frameCount + 1;
        end

        if isempty(tracks)
            error('trackastra:EmptyGroundTruthSequence', ...
                ['Ground-truth channel "%s" contains no tracked object in ROI %d over the ' ...
                 'selected frames. Annotate stable tracklet IDs before formatting.'], ...
                gtName, roiIndex);
        end

        parentMap = lineageParentMap(roiobj, gtName);
        tableRows = zeros(numel(tracks),4);
        for k = 1:numel(tracks)
            id = tracks(k);
            seenFrames = [];
            for f = 1:numel(frameList)
                mask = uint32(roiobj.image(:,:,gtIdx,frameList(f)));
                if any(mask(:)==id)
                    seenFrames(end+1) = f-1; %#ok<AGROW>
                end
            end
            if numel(seenFrames) > 1 && any(diff(seenFrames) ~= 1)
                error('trackastra:NonContiguousTracklet', ...
                    ['Tracklet ID %u in ROI %d disappears and later reappears. ' ...
                     'Each CTC tracklet ID must occupy one contiguous frame interval.'], ...
                    id, roiIndex);
            end
            firstSeen = seenFrames(1);
            lastSeen = seenFrames(end);
            parent = uint32(0);
            if isa(parentMap,'containers.Map')
                parent = mapParentId(parentMap, id);
            end
            if ~ismember(parent,tracks), parent = uint32(0); end
            tableRows(k,:) = double([id uint32(firstSeen) uint32(lastSeen) parent]);
        end
        writeTrackTable(fullfile(traDir,'man_track.txt'), tableRows);

        roiId = char(string(roiIndex));
        try, roiId = char(string(roiobj.id)); catch, end
        row = struct('split',splitName,'sequence',seqName,'roiId',roiId, ...
            'imageChannel',imageName,'groundTruthChannel',gtName, ...
            'frames',frameList,'tracklets',double(tracks(:)'));
        manifestRows(end+1) = row; %#ok<AGROW>
        if strcmp(splitName,'train')
            trainSequences{end+1} = seqDir; %#ok<AGROW>
        else
            validationSequences{end+1} = seqDir; %#ok<AGROW>
        end
    end
end

manifest = fullfile(datasetRoot,'trackastra_dataset_manifest.json');
writeJson(manifest, struct('format','ctc_trackastra_v1','sequences',manifestRows));
report = struct('datasetRoot',datasetRoot,'trainSequences',{trainSequences}, ...
    'validationSequences',{validationSequences},'manifest',manifest,'frameCount',frameCount);
end

function idx = channelIndex(roiobj, name, role)
idx = roiobj.findChannelID(name);
if iscell(idx), idx = cell2mat(idx); end
if isempty(idx)
    error('trackastra:TrainingChannelNotFound', ...
        'Trackastra training %s channel "%s" was not found.', role, name);
end
idx = idx(1);
end

function validateTrackedMask(mask, name, roiIndex, frame)
values = double(mask(:));
if any(~isfinite(values)) || any(values<0) || any(abs(values-round(values))>1e-6)
    error('trackastra:InvalidGroundTruthMask', ...
        'GT channel "%s" in ROI %d frame %d is not a non-negative integer label mask.', ...
        name, roiIndex, frame);
end
end

function parent = mapParentId(parentMap, id)
parent = uint32(0);
keyType = '';
try, keyType = parentMap.KeyType; catch, end
try
    switch lower(keyType)
        case 'int32'
            key = int32(id);
        case 'uint32'
            key = uint32(id);
        case 'int64'
            key = int64(id);
        case 'uint64'
            key = uint64(id);
        case 'int16'
            key = int16(id);
        case 'uint16'
            key = uint16(id);
        case 'int8'
            key = int8(id);
        case 'uint8'
            key = uint8(id);
        case 'double'
            key = double(id);
        case 'single'
            key = single(id);
        case 'char'
            key = char(string(id));
        otherwise
            return;
    end
    if isKey(parentMap,key)
        value = parentMap(key);
        if ~isempty(value) && isnumeric(value) && isfinite(double(value(1))) && double(value(1)) > 0
            parent = uint32(value(1));
        end
    end
catch
    parent = uint32(0);
end
end

function out = toTiffImage(raw)
if isa(raw,'uint8') || isa(raw,'uint16')
    out = raw;
    return;
end
raw = double(raw);
raw(~isfinite(raw)) = 0;
lo = min(raw(:)); hi = max(raw(:));
if hi <= lo
    out = zeros(size(raw),'uint16');
else
    out = uint16(round(65535*(raw-lo)/(hi-lo)));
end
end

function map = lineageParentMap(roiobj, channelName)
map = [];
try
    if isempty(roiobj.data), roiobj.load('data'); end
    idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roiobj.data),1);
    if isempty(idx), return; end
    ud = roiobj.data(idx).userData;
    if ~isstruct(ud), return; end
    if isfield(ud,'lineageSources') && isstruct(ud.lineageSources)
        sourceFields = fieldnames(ud.lineageSources);
        for i = 1:numel(sourceFields)
            candidate = ud.lineageSources.(sourceFields{i});
            if isfield(candidate,'channelName') && ...
                    strcmp(char(string(candidate.channelName)), channelName) && ...
                    isfield(candidate,'motherOf') && isa(candidate.motherOf,'containers.Map')
                map = candidate.motherOf;
                break;
            end
        end
        key = '';
        if isfield(ud,'activeLineageSource'), key = char(string(ud.activeLineageSource)); end
        if isempty(map) && ~isempty(key) && isfield(ud.lineageSources,key) && ...
                isfield(ud.lineageSources.(key),'motherOf')
            map = ud.lineageSources.(key).motherOf;
        end
    end
    if isempty(map) && isfield(ud,'motherOf'), map = ud.motherOf; end
catch
    map = [];
end
end

function writeTrackTable(pathValue, rows)
fid = fopen(pathValue,'w');
if fid<0, error('trackastra:TrackTableWriteFailed','Unable to write %s.',pathValue); end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i=1:size(rows,1)
    fprintf(fid,'%u %u %u %u\n',uint32(rows(i,1)),uint32(rows(i,2)),uint32(rows(i,3)),uint32(rows(i,4)));
end
end

function writeJson(pathValue,value)
fid=fopen(pathValue,'w');
if fid<0, error('trackastra:ManifestWriteFailed','Unable to write %s.',pathValue); end
cleaner=onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end

function value = getField(s,name,fallback)
value=fallback;
if isstruct(s)&&isfield(s,name)&&~isempty(s.(name)), value=s.(name); end
end

function channels = classifierInputChannels(classif)
channels = {};
try
    value = classif.channelName;
    if ischar(value)
        channels = {strtrim(value)};
    elseif isstring(value)
        channels = cellstr(value(:)');
    elseif iscell(value)
        channels = cellfun(@(x) strtrim(char(string(x))), value(:)', 'UniformOutput', false);
    end
catch
    channels = {};
end
channels = channels(~cellfun(@isempty, channels));
end

function txt = scalarText(value)
while iscell(value)
    value=value(~cellfun(@isempty,value));
    if isempty(value),txt='';return;end
    value=value{end};
end
txt=strtrim(char(string(value)));
end
