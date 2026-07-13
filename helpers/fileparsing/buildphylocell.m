function output = buildphylocell(phyloproj, outputin, progress, includeContours)
% buildphylocell  Parse a legacy phyloCell timeLapse project.
%
% includeContours keeps the historical behavior of embedding phyloCell
% segmentation objects into fov.contours. Pipeline imports should pass false
% and let a downstream processor convert segmentation files on demand.

if nargin < 4 || isempty(includeContours)
    includeContours = true;
end

output = outputin;
projectFile = fullfile(phyloproj.folder, phyloproj.name);
S = load(projectFile, 'timeLapse');

if isfield(S, 'timeLapse')
    timeLapse = S.timeLapse;
    disp('File corresponds to a valid  timeLapse phyloCell project');
else
    disp('This is not a valid file ! Quitting....');
    output.comments = 'No image files available!';
    return;
end

if isfield(timeLapse, 'position') && isfield(timeLapse.position, 'list')
    disp(['There are ' num2str(numel(timeLapse.position.list)) ' positions available in this timeLapse project']);
    npos = 1:numel(timeLapse.position.list);
else
    disp('There are no positions available in this timeLapse project; Quitting...')
    output.comments = 'No image files available!';
    return;
end

cc = 1;
for i = npos
    info = ['Processing position: ' num2str(i) '/' num2str(numel(npos))];
    disp(info);
    if numel(progress)
        progress.Message = info;
        progress.Value = min(1, 0.67 + 0.33 * (i-1) / max(1, numel(npos)));
    end
    detecdiv_check_cancel(progress, info);

    strpos = legacyPositionDir(phyloproj.folder, timeLapse, i);
    if exist(strpos, 'dir') ~= 7
        disp(['Skipping missing phyloCell position folder: ' strpos]);
        continue;
    end

    [pathname, filename, channelname, binning, interval] = legacyChannelFiles(phyloproj.folder, timeLapse, i);
    validChannels = cellfun(@(p) exist(p, 'dir') == 7, pathname);
    if ~any(validChannels)
        disp(['Skipping phyloCell position with no readable channel folder: ' strpos]);
        continue;
    end

    pathname = pathname(validChannels);
    filename = filename(validChannels);
    channelname = channelname(validChannels);
    binning = binning(validChannels);
    interval = interval(validChannels);

    frameCounts = cellfun(@numel, filename);
    frames = min(frameCounts(frameCounts > 0));
    if isempty(frames)
        disp(['Skipping phyloCell position with no image frames: ' strpos]);
        continue;
    end

    segFile = findPreferredSegmentationFile(strpos);
    legacy = struct();
    legacy.format = 'phyloCell';
    legacy.projectFile = projectFile;
    legacy.projectRoot = phyloproj.folder;
    legacy.projectName = phyloproj.name;
    legacy.prefix = getFieldOrDefault(timeLapse, 'filename', stripProjectSuffix(phyloproj.name));
    legacy.positionIndex = i;
    legacy.positionName = ['pos' num2str(i)];
    legacy.positionDir = strpos;
    legacy.segmentationFile = segFile;
    legacy.includeContours = logical(includeContours);

    output.pos(cc).channels = numel(pathname);
    output.pos(cc).frames = frames;
    output.pos(cc).filelist = filename;
    output.pos(cc).pathlist = pathname;
    output.pos(cc).unfilteredpathlist = pathname;
    output.pos(cc).unfilteredfilelist = filename;
    output.pos(cc).binning = binning;
    output.pos(cc).interval = interval;
    output.pos(cc).name = ['pos' num2str(i)];
    output.pos(cc).channelfilter = {'ch'};
    output.pos(cc).stackfilter = {''};
    output.pos(cc).channelname = channelname;
    output.pos(cc).contours = struct('phyloCell', legacy);

    if includeContours && ~isempty(segFile)
        output.pos(cc).contours = loadLegacyContours(output.pos(cc).contours, segFile, progress);
    end

    cc = cc + 1;
end
end

function strpos = legacyPositionDir(rootDir, timeLapse, idx)
strpos = '';
try
    if isfield(timeLapse, 'pathList') && isfield(timeLapse.pathList, 'position') && ...
            numel(timeLapse.pathList.position) >= idx && ~isempty(timeLapse.pathList.position{idx})
        strpos = fullfile(rootDir, timeLapse.pathList.position{idx});
    end
catch
    strpos = '';
end
if isempty(strpos)
    prefix = char(string(getFieldOrDefault(timeLapse, 'filename', '')));
    strpos = fullfile(rootDir, [prefix '-pos' num2str(idx)]);
end
end

function [pathname, filename, channelname, binning, interval] = legacyChannelFiles(rootDir, timeLapse, posIdx)
nChannels = numel(timeLapse.list);
pathname = cell(1, nChannels);
filename = cell(1, nChannels);
channelname = cell(1, nChannels);
binning = ones(1, nChannels);
interval = ones(1, nChannels);

for j = 1:nChannels
    pathj = '';
    try
        if isfield(timeLapse, 'pathList') && isfield(timeLapse.pathList, 'channels') && ...
                size(timeLapse.pathList.channels, 1) >= posIdx && size(timeLapse.pathList.channels, 2) >= j && ...
                ~isempty(timeLapse.pathList.channels{posIdx, j})
            pathj = fullfile(rootDir, timeLapse.pathList.channels{posIdx, j});
        end
    catch
        pathj = '';
    end
    if isempty(pathj)
        prefix = char(string(getFieldOrDefault(timeLapse, 'filename', '')));
        chid = legacyChannelId(timeLapse, j);
        pathj = fullfile(rootDir, [prefix '-pos' num2str(posIdx) '-ch' num2str(j) '-' chid]);
    end

    pathname{j} = pathj;
    list = dir(fullfile(pathj, '*.jpg'));
    list = [list; dir(fullfile(pathj, '*.tif'))]; %#ok<AGROW>
    filename{j} = list;
    channelname{j} = ['ch' num2str(j) '-' legacyChannelId(timeLapse, j)];

    try
        if isfield(timeLapse.list, 'binning') && numel(timeLapse.list) >= j
            binning(j) = timeLapse.list(j).binning;
        end
    catch
        binning(j) = 1;
    end
    try
        if isfield(timeLapse, 'interval')
            interval(j) = timeLapse.interval;
        end
    catch
        interval(j) = 1;
    end
end
end

function id = legacyChannelId(timeLapse, j)
id = ['channel' num2str(j)];
try
    if isfield(timeLapse.list, 'ID') && numel(timeLapse.list) >= j && ~isempty(timeLapse.list(j).ID)
        id = char(string(timeLapse.list(j).ID));
    end
catch
end
end

function contours = loadLegacyContours(contours, segFile, progress)
try
    if numel(progress)
        progress.Message = ['Found segmentation variable : ' segFile];
    end
    S = load(segFile, 'segmentation');
    h = findobj('Name', 'phyloCell_mainGUI');
    delete(h);
    if ~isfield(S, 'segmentation')
        return;
    end
    segmentation = S.segmentation;
    disp(['Found segmentation variable : ' segFile]);
    if isfield(segmentation, 'cells1') && hasPhyloObjects(segmentation.cells1)
        contours.cells1 = segmentation.cells1;
    end
    if isfield(segmentation, 'nucleus') && hasPhyloObjects(segmentation.nucleus)
        contours.nucleus = segmentation.nucleus;
    end
catch ME
    warning('buildphylocell:SegmentationLoadFailed', ...
        'Could not load phyloCell segmentation "%s": %s', segFile, ME.message);
end
end

function tf = hasPhyloObjects(arr)
tf = false;
try
    tf = numel(arr) >= 1 && isobject(arr) && isprop(arr(1), 'n') && arr(1).n ~= 0;
catch
    tf = false;
end
end

function segFile = findPreferredSegmentationFile(positionDir)
segFile = '';
files = dir(fullfile(positionDir, '*.mat'));
if isempty(files)
    return;
end
names = {files.name};
lowerNames = lower(names);
isSeg = contains(lowerNames, 'segmentation') & ~contains(lowerNames, '.bk');
files = files(isSeg);
lowerNames = lower({files.name});
if isempty(files)
    return;
end

priority = zeros(1, numel(files));
for i = 1:numel(files)
    if contains(lowerNames{i}, 'autotrack')
        priority(i) = 3;
    elseif contains(lowerNames{i}, 'batch')
        priority(i) = 2;
    elseif contains(lowerNames{i}, 'segmentation')
        priority(i) = 1;
    end
end
[~, order] = sortrows([-priority(:), -[files.datenum]']);
files = files(order);
segFile = fullfile(files(1).folder, files(1).name);
end

function val = getFieldOrDefault(s, fieldName, defaultVal)
val = defaultVal;
try
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        val = s.(fieldName);
    end
catch
end
end

function prefix = stripProjectSuffix(name)
prefix = char(string(name));
prefix = regexprep(prefix, '-project\.mat$', '', 'ignorecase');
end
