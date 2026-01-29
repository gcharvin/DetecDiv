function output = buildndtiff(ndtiffDirs, outputin, progress)
% buildndtiff
% Build positions list from one or more NDTiff datasets.

output = outputin;

if ischar(ndtiffDirs)
    ndtiffDirs = {ndtiffDirs};
end
if isempty(ndtiffDirs)
    output.comments = [output.comments 'No NDTiff dataset found.' char(10)];
    return;
end

cc = 1;
for d = 1:numel(ndtiffDirs)
    dsPath = ndtiffDirs{d};
    if ~isfolder(dsPath)
        continue;
    end
    if exist(fullfile(dsPath,'NDTiff.index'),'file')~=2
        continue;
    end

    info = ['Processing NDTiff dataset: ' dsPath];
    disp(info);
    if numel(progress)
        progress.Message = info;
        progress.Value = min(1, 0.33 + 0.33*(d-1)/max(1,numel(ndtiffDirs)));
    end

    % Open dataset (Java)
    [okIdx, reason] = localWaitForNDTiffIndex(dsPath, 5);
    if ~okIdx
        msg = sprintf('NDTiff index locked or not ready (%s). Acquisition may be running: %s', reason, dsPath);
        warning('%s', msg);
        output.comments = [output.comments msg char(10)];
        continue;
    end
    try
        dataset = javaObject('org.micromanager.ndtiffstorage.NDTiffStorage', dsPath);
    catch ME
        warning('Could not open NDTiff dataset: %s (%s)', dsPath, ME.message);
        continue;
    end

    % Extract axes values (per-image)
    axesTable = localGetAxesTable(dataset);
    posVals = axesTable.pos;
    chVals  = axesTable.ch;
    tVals   = axesTable.t;
    zVals   = axesTable.z;

    % Summary metadata (text + channel names)
    summaryText = '';
    chNamesFromMM = {};
    try
        smd = dataset.getSummaryMetadata();
        try
            summaryText = char(smd.toString(2)); % pretty JSON if supported
        catch
            summaryText = char(smd.toString());
        end
        chNamesFromMM = localGetChannelNamesFromSummary(smd, summaryText);
        if isempty(chNamesFromMM) && ~isempty(summaryText)
            try
                S = jsondecode(summaryText);
                if isfield(S,'ChNames') && ~isempty(S.ChNames)
                    chNamesFromMM = cellstr(string(S.ChNames));
                end
            catch
            end
        end
    catch
        % keep defaults
    end

    if isempty(posVals), posVals = 0; end
    if isempty(chVals),  chVals  = 0; end
    if isempty(tVals),   tVals   = 0; end
    if isempty(zVals),   zVals   = 0; end

    posVals = unique(double(posVals(:))');
    chVals  = unique(double(chVals(:))');
    tVals   = unique(double(tVals(:))');
    zVals   = unique(double(zVals(:))');

    nPos = numel(posVals);
    nCh  = numel(chVals);

    % Normalize channel names
    chNamesBase = chNamesFromMM;
    if isempty(chNamesBase) && ~isempty(summaryText)
        try
            S = jsondecode(summaryText);
            if isfield(S,'ChNames') && ~isempty(S.ChNames)
                chNamesBase = cellstr(string(S.ChNames));
            end
        catch
        end
    end
    if isempty(chNamesBase) || numel(chNamesBase) ~= nCh
        chNamesBase = arrayfun(@(i)sprintf('ch%d', i), 1:nCh, 'UniformOutput', false);
    else
        chNamesBase = chNamesBase(:).';
    end

    [~, dsName] = fileparts(dsPath);

    for p = 1:nPos
        posMask = axesTable.pos == posVals(p);
        tValsPos = unique(double(axesTable.t(posMask))');
        if isempty(tValsPos), tValsPos = 0; end
        tValsPos = sort(tValsPos);

        % Build per-position channel x z list (only existing combos)
        dispChNames = {};
        dispChMap = [];
        dispZMap = [];
        virtList = {};
        ccDisp = 1;

        for c = 1:nCh
            chVal = chVals(c);
            zValsPos = unique(double(axesTable.z(posMask & axesTable.ch == chVal))');
            if isempty(zValsPos)
                continue;
            end
            zValsPos = sort(zValsPos);
            for zi = 1:numel(zValsPos)
                entries = repmat(struct('name','', 'folder', dsPath), 1, numel(tValsPos));
                for f = 1:numel(tValsPos)
                    entries(f).name = sprintf('ndtiff_ch%03d_z%03d_t%09d.tif', chVal, zValsPos(zi), tValsPos(f));
                    entries(f).folder = dsPath;
                end
                virtList{ccDisp} = entries; %#ok<AGROW>
                dispChNames{ccDisp} = sprintf('%s_z%d', chNamesBase{c}, zValsPos(zi)+1); %#ok<AGROW>
                dispChMap(ccDisp) = chVal; %#ok<AGROW>
                dispZMap(ccDisp)  = zValsPos(zi); %#ok<AGROW>
                ccDisp = ccDisp + 1;
            end
        end

        nDispCh = numel(dispChNames);
        if nDispCh == 0
            continue;
        end

        pathList = repmat({dsPath}, 1, nDispCh);

        if cc ~= 1
            output.pos(cc) = output.pos(1);
        end

        % Defaults
        output.pos(cc).frames = numel(tValsPos);
        output.pos(cc).channels = nDispCh;
        output.pos(cc).filelist = virtList;
        output.pos(cc).pathlist = pathList;
        output.pos(cc).unfilteredpathlist = pathList;
        output.pos(cc).unfilteredfilelist = virtList;
        output.pos(cc).binning = ones(1, nDispCh);
        output.pos(cc).interval = ones(1, nDispCh);
        output.pos(cc).channelfilter = {''};
        output.pos(cc).stackfilter = {''};
        output.pos(cc).positionfilter2 = {};
        output.pos(cc).channelfilter2 = {};
        output.pos(cc).stackfilter2 = {};

        % Name
        output.pos(cc).name = sprintf('%s_pos%d', dsName, posVals(p)+1);

        % Channel names
        output.pos(cc).channelname = dispChNames;

        % NDTiff metadata
        output.pos(cc).isNDTiff = true;
        output.pos(cc).ndtiffPath = dsPath;
        output.pos(cc).ndtiffPosition = posVals(p);
        output.pos(cc).ndtiffChannels = dispChMap;
        output.pos(cc).ndtiffTimes = tValsPos;
        output.pos(cc).ndtiffZ = dispZMap;
        output.pos(cc).metadataText = summaryText;

        cc = cc + 1;
    end
end

output.comments = [output.comments num2str(cc-1) ' NDTiff position(s) detected' char(10)];
end


function axesTable = localGetAxesTable(dataset)
axesTable.pos = [];
axesTable.ch  = [];
axesTable.t   = [];
axesTable.z   = [];

try
    axesSet = dataset.getAxesSet();
    axesArray = axesSet.toArray();
catch
    return;
end

n = length(axesArray);
keyPos = javaObject('java.lang.String','position');
keyCh  = javaObject('java.lang.String','channel');
keyT   = javaObject('java.lang.String','time');
keyZ   = javaObject('java.lang.String','z');
posVals = zeros(1, n);
chVals = zeros(1, n);
tVals = zeros(1, n);
zVals = zeros(1, n);
for i = 1:n
    axes1 = axesArray(i);

    if axes1.containsKey(keyPos)
        posVals(i) = double(axes1.get(keyPos));
    else
        posVals(i) = 0;
    end

    if axes1.containsKey(keyCh)
        chVals(i) = double(axes1.get(keyCh));
    else
        chVals(i) = 0;
    end

    if axes1.containsKey(keyT)
        tVals(i) = double(axes1.get(keyT));
    else
        tVals(i) = 0;
    end

    if axes1.containsKey(keyZ)
        zVals(i) = double(axes1.get(keyZ));
    else
        zVals(i) = 0;
    end
end
axesTable.pos = posVals;
axesTable.ch  = chVals;
axesTable.t   = tVals;
axesTable.z   = zVals;
end

function [ok, reason] = localWaitForNDTiffIndex(dsPath, maxWaitSec)
% Wait for NDTiff.index to exist and be stable (size not changing + readable)
ok = false;
reason = 'unknown';
idx = fullfile(dsPath, 'NDTiff.index');
if exist(idx, 'file') ~= 2
    reason = 'NDTiff.index missing';
    return;
end

prevBytes = -1;
stableCount = 0;
everLocked = false;
tick = 0.2;
maxIter = max(1, round(maxWaitSec / tick));

for i = 1:maxIter
    if exist(idx, 'file') ~= 2
        reason = 'NDTiff.index missing';
        return;
    end
    d = dir(idx);
    if isempty(d)
        reason = 'NDTiff.index not accessible';
        return;
    end

    % check if readable
    fid = fopen(idx, 'r');
    if fid > 0
        fclose(fid);
        canRead = true;
    else
        canRead = false;
        everLocked = true;
    end

    if d.bytes == prevBytes && canRead
        stableCount = stableCount + 1;
    else
        stableCount = 0;
    end

    if stableCount >= 3
        ok = true;
        reason = '';
        return;
    end

    prevBytes = d.bytes;
    pause(tick);
end

if ~ok
    if everLocked
        reason = 'NDTiff.index locked (file in use)';
    else
        reason = 'NDTiff.index changing';
    end
end
end

function chNames = localGetChannelNamesFromSummary(smd, summaryText)
% Try to extract channel names from Micro-Manager summary metadata
chNames = {};
if isempty(smd), return; end

% First: parse summary JSON text if available (most reliable)
if nargin >= 2 && ~isempty(summaryText)
    try
        S = jsondecode(summaryText);
        if isfield(S,'ChNames') && ~isempty(S.ChNames)
            chNames = cellstr(string(S.ChNames));
            return;
        end
        if isfield(S,'MdaSettings')
            try
                ms = jsondecode(S.MdaSettings);
                if isfield(ms,'channels') && ~isempty(ms.channels)
                    cfg = {ms.channels.config};
                    chNames = cellfun(@(s)char(string(s)), cfg, 'UniformOutput', false);
                    return;
                end
            catch
            end
        end
    catch
        % Try regex if jsondecode fails
        try
            tok = regexp(summaryText, '"ChNames"\\s*:\\s*\\[([^\\]]*)\\]', 'tokens', 'once');
            if ~isempty(tok)
                names = regexp(tok{1}, '\"(.*?)\"', 'tokens');
                names = cellfun(@(x)x{1}, names, 'UniformOutput', false);
                if ~isempty(names)
                    chNames = names;
                    return;
                end
            end
        catch
        end
    end
end

try
    keyChNames = javaObject('java.lang.String','ChNames');
    if smd.has(keyChNames)
        arr = smd.get(keyChNames);
        chNames = localJsonArrayToCell(arr);
        chNames = cellfun(@(s)char(string(s)), chNames, 'UniformOutput', false);
        return;
    end
catch
end

% Fallback: try "Channels" array with name fields
try
    keyChannels = javaObject('java.lang.String','Channels');
    if smd.has(keyChannels)
        arr = smd.get(keyChannels);
        if isa(arr,'mmcorej.org.json.JSONArray') || isa(arr,'org.json.JSONArray')
            n = arr.length();
            tmp = cell(1,n);
            keyName = javaObject('java.lang.String','Name');
            for i = 0:n-1
                obj = arr.get(i);
                if (isa(obj,'mmcorej.org.json.JSONObject') || isa(obj,'org.json.JSONObject')) && obj.has(keyName)
                    tmp{i+1} = char(obj.get(keyName).toString());
                else
                    tmp{i+1} = sprintf('ch%d', i+1);
                end
            end
            chNames = tmp;
            return;
        end
    end
catch
end
end

function out = localJsonArrayToCell(arr)
out = {};
if isempty(arr), return; end
try
    n = arr.length();
    out = cell(1,n);
    for i = 0:n-1
        v = arr.get(i);
        if isa(v,'mmcorej.org.json.JSONObject') || isa(v,'org.json.JSONObject')
            out{i+1} = char(v.toString());
        elseif isa(v,'mmcorej.org.json.JSONArray') || isa(v,'org.json.JSONArray')
            out{i+1} = localJsonArrayToCell(v);
        else
            out{i+1} = char(string(v));
        end
    end
catch
    out = {};
end
end
