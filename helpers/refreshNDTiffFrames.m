function report = refreshNDTiffFrames(shallowObj, varargin)
% refreshNDTiffFrames
% Refresh NDTiff frame counts for existing FOVs (append-safe).
%
% Usage:
%   refreshNDTiffFrames(project)
%   refreshNDTiffFrames(project, 'FOVIndex', [1 3])
%
% Behavior:
%   - Detects complete timepoints only (all ch*z present)
%   - Does NOT advance if the newest timepoint is incomplete
%   - Prints console messages
%   - Warns if no ROIs are defined for a FOV

report = struct('checked',0,'updated',0,'skipped',0);

if nargin < 1 || isempty(shallowObj) || ~isprop(shallowObj,'fov')
    disp('refreshNDTiffFrames: invalid project (no fov).');
    return;
end

FOVIndex = [];
for i = 1:2:numel(varargin)
    key = lower(string(varargin{i}));
    if key == "fovindex"
        FOVIndex = varargin{i+1};
    end
end

allFOV = 1:numel(shallowObj.fov);
if isempty(FOVIndex)
    FOVIndex = allFOV;
else
    FOVIndex = intersect(allFOV, FOVIndex(:)');
end

if isempty(FOVIndex)
    disp('refreshNDTiffFrames: no valid FOV index.');
    return;
end

% --- ensure NDTiff mode present ---
hasNDTiff = false;
for i = FOVIndex
    f = shallowObj.fov(i);
    if isprop(f,'isNDTiff') && f.isNDTiff
        hasNDTiff = true;
        break;
    end
end
if ~hasNDTiff
    disp('refreshNDTiffFrames: no NDTiff FOV detected, aborting.');
    return;
end

fprintf('refreshNDTiffFrames: checking FOVs %s\n', mat2str(FOVIndex));

updatedList = [];
for k = 1:numel(FOVIndex)
    iF = FOVIndex(k);
    f = shallowObj.fov(iF);

    if ~isprop(f,'isNDTiff') || ~f.isNDTiff
        continue;
    end

    report.checked = report.checked + 1;

    if ~isprop(f,'roi') || isempty(f.roi)
        fprintf('  WARNING: FOV %d has no ROI defined.\n', iF);
    end

    if ~isprop(f,'ndtiffPath') || isempty(f.ndtiffPath) || ~isfolder(f.ndtiffPath)
        fprintf('  FOV %d: NDTiff path missing or invalid.\n', iF);
        report.skipped = report.skipped + 1;
        continue;
    end

    % expected channel/z pairs (0-based) from current FOV
    dispCh = f.ndtiffChannels;
    if isempty(dispCh)
        dispCh = 0;
    end
    dispZ = f.ndtiffZ;
    if isempty(dispZ)
        dispZ = 0;
    end
    if numel(dispZ) == 1 && numel(dispCh) > 1
        dispZ = repmat(dispZ, 1, numel(dispCh));
    elseif numel(dispZ) < numel(dispCh)
        dispZ(end+1:numel(dispCh)) = dispZ(end);
    end
    expectedPairs = [double(dispCh(:)) double(dispZ(:))];

    % Read dataset axes
    try
        dataset = javaObject('org.micromanager.ndtiffstorage.NDTiffStorage', f.ndtiffPath);
    catch ME
        fprintf('  FOV %d: cannot open NDTiff (%s)\n', iF, ME.message);
        report.skipped = report.skipped + 1;
        continue;
    end

    [nComplete, maxTSeen] = localCountCompleteTimepoints(dataset, f.ndtiffPosition, expectedPairs);

    % Determine current frames
    if isprop(f,'frames') && ~isempty(f.frames)
        curFrames = max(double(f.frames(:)));
    else
        curFrames = 0;
    end

    if nComplete <= curFrames
        if maxTSeen + 1 > curFrames
            fprintf('  FOV %d: new frames detected but last timepoint incomplete → no append.\n', iF);
        else
            fprintf('  FOV %d: pas de nouvelle frame détectée (T=%d).\n', iF, curFrames);
        end
        report.skipped = report.skipped + 1;
        continue;
    end

    % Update FOV (frames + srclist virtual)
    nDisp = numel(dispCh);
    f.frames = repmat(nComplete, 1, nDisp);

    % rebuild srclist with virtual names
    for c = 1:nDisp
        entries = repmat(struct('name','', 'folder', f.ndtiffPath), 1, nComplete);
        chIdx = double(dispCh(c));
        zIdx  = double(dispZ(c));
        for t = 1:nComplete
            entries(t).name = sprintf('ndtiff_ch%03d_z%03d_t%09d.tif', chIdx, zIdx, t-1);
            entries(t).folder = f.ndtiffPath;
        end
        f.srclist{c} = entries;
        if iscell(f.srcpath) && numel(f.srcpath) >= c
            f.srcpath{c} = f.ndtiffPath;
        end
    end

    shallowObj.fov(iF) = f;
    report.updated = report.updated + 1;
    updatedList(end+1) = iF; %#ok<AGROW>
    fprintf('  FOV %d: new complete frames appended (%d → %d).\n', iF, curFrames, nComplete);
end

fprintf('refreshNDTiffFrames: %d checked, %d updated, %d skipped.\n', ...
    report.checked, report.updated, report.skipped);

% --- Call extractAllROICrops in append mode for updated FOVs ---
if ~isempty(updatedList)
    fprintf('refreshNDTiffFrames: calling extractAllROICrops (Extend=true) on FOVs %s\n', mat2str(updatedList));
    try
        extractAllROICrops(shallowObj, 'FOVIndex', updatedList, 'Extend', true, 'PadExtraChannels', true);
    catch ME
        warning('refreshNDTiffFrames: extractAllROICrops failed: %s', ME.message);
    end
else
    fprintf('refreshNDTiffFrames: no updated FOVs, extractAllROICrops not called.\n');
end
end


function [nComplete, maxTSeen] = localCountCompleteTimepoints(dataset, posIdx, expectedPairs)
nComplete = 0;
maxTSeen = -1;

try
    axesSet = dataset.getAxesSet();
    axesArray = axesSet.toArray();
catch
    return;
end

keyPos = javaObject('java.lang.String','position');
keyCh  = javaObject('java.lang.String','channel');
keyT   = javaObject('java.lang.String','time');
keyZ   = javaObject('java.lang.String','z');

% map expected pairs to IDs
pairMap = containers.Map('KeyType','char','ValueType','int32');
for i = 1:size(expectedPairs,1)
    k = sprintf('%d_%d', expectedPairs(i,1), expectedPairs(i,2));
    if ~pairMap.isKey(k)
        pairMap(k) = int32(i);
    end
end

tList = [];
pairList = [];

% detect if position axis exists at all
hasPosAxis = false;
try
    if ~isempty(axesArray)
        axes1 = axesArray(1);
        hasPosAxis = axes1.containsKey(keyPos);
    end
catch
end

n = length(axesArray);
for i = 1:n
    axes1 = axesArray(i);

    if hasPosAxis
        if ~axes1.containsKey(keyPos)
            continue;
        end
        p = double(axes1.get(keyPos));
        if p ~= double(posIdx)
            continue;
        end
    end

    if axes1.containsKey(keyT)
        t = double(axes1.get(keyT));
    else
        t = 0;
    end
    if axes1.containsKey(keyCh)
        ch = double(axes1.get(keyCh));
    else
        ch = 0;
    end
    if axes1.containsKey(keyZ)
        z = double(axes1.get(keyZ));
    else
        z = 0;
    end

    if t > maxTSeen
        maxTSeen = t;
    end

    key = sprintf('%d_%d', ch, z);
    if pairMap.isKey(key)
        tList(end+1) = t; %#ok<AGROW>
        pairList(end+1) = pairMap(key); %#ok<AGROW>
    end
end

if isempty(tList)
    nComplete = 0;
    return;
end

uniqT = unique(tList);
nPairs = pairMap.Count;
completeTimes = [];
for i = 1:numel(uniqT)
    t = uniqT(i);
    pairsForT = unique(pairList(tList==t));
    if numel(pairsForT) == nPairs
        completeTimes(end+1) = t; %#ok<AGROW>
    end
end

if isempty(completeTimes)
    nComplete = 0;
    return;
end

completeTimes = sort(completeTimes);
% longest contiguous prefix from t=0
nContig = 0;
for i = 1:numel(completeTimes)
    if completeTimes(i) == (i-1)
        nContig = nContig + 1;
    else
        break;
    end
end
nComplete = nContig;
end
