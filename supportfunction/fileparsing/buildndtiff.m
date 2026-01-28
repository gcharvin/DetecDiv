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
    try
        dataset = javaObject('org.micromanager.ndtiffstorage.NDTiffStorage', dsPath);
    catch ME
        warning('Could not open NDTiff dataset: %s (%s)', dsPath, ME.message);
        continue;
    end

    % Extract axes values
    [posVals, chVals, tVals, zVals] = localGetAxesValues(dataset);

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
    nT   = numel(tVals);

    % Build virtual filelist per channel (for compatibility)
    virtList = cell(1, nCh);
    for c = 1:nCh
        entries = repmat(struct('name','', 'folder', dsPath), 1, nT);
        for f = 1:nT
            entries(f).name = sprintf('ndtiff_ch%03d_t%09d.tif', chVals(c), tVals(f));
            entries(f).folder = dsPath;
        end
        virtList{c} = entries;
    end
    pathList = repmat({dsPath}, 1, nCh);

    [~, dsName] = fileparts(dsPath);

    for p = 1:nPos
        if cc ~= 1
            output.pos(cc) = output.pos(1);
        end

        % Defaults
        output.pos(cc).frames = nT;
        output.pos(cc).channels = nCh;
        output.pos(cc).filelist = virtList;
        output.pos(cc).pathlist = pathList;
        output.pos(cc).unfilteredpathlist = pathList;
        output.pos(cc).unfilteredfilelist = virtList;
        output.pos(cc).binning = ones(1, nCh);
        output.pos(cc).interval = ones(1, nCh);
        output.pos(cc).channelfilter = {''};
        output.pos(cc).stackfilter = {''};
        output.pos(cc).positionfilter2 = {};
        output.pos(cc).channelfilter2 = {};
        output.pos(cc).stackfilter2 = {};

        % Name
        output.pos(cc).name = sprintf('%s_pos%d', dsName, posVals(p)+1);

        % Channel names
        output.pos(cc).channelname = cell(1, nCh);
        for k = 1:nCh
            output.pos(cc).channelname{k} = ['ch' num2str(k)];
        end

        % NDTiff metadata
        output.pos(cc).isNDTiff = true;
        output.pos(cc).ndtiffPath = dsPath;
        output.pos(cc).ndtiffPosition = posVals(p);
        output.pos(cc).ndtiffChannels = chVals;
        output.pos(cc).ndtiffTimes = tVals;
        output.pos(cc).ndtiffZ = zVals(1);

        cc = cc + 1;
    end
end

output.comments = [output.comments num2str(cc-1) ' NDTiff position(s) detected' char(10)];
end


function [posVals, chVals, tVals, zVals] = localGetAxesValues(dataset)
posVals = [];
chVals  = [];
tVals   = [];
zVals   = [];

try
    axesSet = dataset.getAxesSet();
    axesArray = axesSet.toArray();
catch
    return;
end

n = length(axesArray);
for i = 1:n
    axes1 = axesArray(i);

    if axes1.containsKey('position')
        posVals(end+1) = double(axes1.get('position')); %#ok<AGROW>
    else
        posVals(end+1) = 0; %#ok<AGROW>
    end

    if axes1.containsKey('channel')
        chVals(end+1) = double(axes1.get('channel')); %#ok<AGROW>
    else
        chVals(end+1) = 0; %#ok<AGROW>
    end

    if axes1.containsKey('time')
        tVals(end+1) = double(axes1.get('time')); %#ok<AGROW>
    else
        tVals(end+1) = 0; %#ok<AGROW>
    end

    if axes1.containsKey('z')
        zVals(end+1) = double(axes1.get('z')); %#ok<AGROW>
    else
        zVals(end+1) = 0; %#ok<AGROW>
    end
end
end
