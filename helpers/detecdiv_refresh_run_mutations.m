function report = detecdiv_refresh_run_mutations(manifest, varargin)
% detecdiv_refresh_run_mutations  Reload only ROI outputs committed by a run.
%
% Name-value inputs:
%   Classifier  classi handle whose ROI handles may already be displayed
%   Project     shallow handle
%   RoiList     explicit roi handles
%   RetryCount  H5 visibility attempts (default 1)
%   RetryPause  seconds between attempts (default 0.5)

    opts = localParse(varargin{:});
    report = struct('matchedRois', 0, 'refreshedRois', 0, ...
        'refreshedChannels', 0, 'refreshedDataRois', 0, ...
        'pendingRois', {{}}, 'warnings', {{}});
    if ~isstruct(manifest) || ~isfield(manifest, 'rois') || isempty(manifest.rois)
        return;
    end

    loadedRois = localLoadedRois(opts);
    if isempty(loadedRois)
        return;
    end

    changes = manifest.rois;
    for i = 1:numel(changes)
        roiId = localText(changes(i), 'id');
        idx = localFindRoi(loadedRois, roiId);
        if isempty(idx)
            continue;
        end
        roiObj = loadedRois(idx(1));
        report.matchedRois = report.matchedRois + 1;
        channels = localCellText(changes(i), 'channels');
        reloadData = localLogical(changes(i), 'reloadData', false) || ...
            ~isempty(localCellText(changes(i), 'dataSeries'));

        readyChannels = localWaitForChannels(roiObj, channels, opts);
        dataReady = ~reloadData || localWaitForData(roiObj, opts);
        if numel(readyChannels) < numel(channels) || ~dataReady
            report.pendingRois{end+1} = roiId; %#ok<AGROW>
        end
        try
            if ~isempty(readyChannels)
                roiObj.load('Channel', readyChannels, 'Data', dataReady && reloadData, 'Silent');
                report.refreshedChannels = report.refreshedChannels + numel(readyChannels);
                report.refreshedRois = report.refreshedRois + 1;
                if dataReady && reloadData
                    report.refreshedDataRois = report.refreshedDataRois + 1;
                end
            elseif reloadData && dataReady
                roiObj.load('Data', 'Silent');
                report.refreshedDataRois = report.refreshedDataRois + 1;
                report.refreshedRois = report.refreshedRois + 1;
            end
        catch ME
            report.warnings{end+1} = sprintf('ROI %s refresh failed: %s', roiId, ME.message); %#ok<AGROW>
        end
    end
    report.pendingRois = unique(report.pendingRois, 'stable');
end

function opts = localParse(varargin)
    opts = struct('Classifier', [], 'Project', [], 'RoiList', [], ...
        'RetryCount', 1, 'RetryPause', 0.5);
    i = 1;
    while i + 1 <= numel(varargin)
        key = char(string(varargin{i}));
        if isfield(opts, key)
            opts.(key) = varargin{i+1};
        else
            names = fieldnames(opts);
            match = find(strcmpi(names, key), 1);
            if ~isempty(match), opts.(names{match}) = varargin{i+1}; end
        end
        i = i + 2;
    end
    opts.RetryCount = max(1, round(double(opts.RetryCount)));
    opts.RetryPause = max(0, double(opts.RetryPause));
end

function rois = localLoadedRois(opts)
    rois = [];
    if ~isempty(opts.RoiList) && isa(opts.RoiList, 'roi')
        rois = opts.RoiList;
    end
    try
        if ~isempty(opts.Classifier) && isa(opts.Classifier, 'classi')
            rois = localAppendUniqueHandles(rois, opts.Classifier.roi);
        end
    catch
    end
    try
        if ~isempty(opts.Project) && isa(opts.Project, 'shallow')
            for i = 1:numel(opts.Project.fov)
                rois = localAppendUniqueHandles(rois, opts.Project.fov(i).roi);
            end
        end
    catch
    end
end

function out = localAppendUniqueHandles(out, incoming)
    if isempty(incoming) || ~isa(incoming, 'roi')
        return;
    end
    for i = 1:numel(incoming)
        exists = false;
        for j = 1:numel(out)
            try
                if out(j) == incoming(i), exists = true; break; end
            catch
            end
        end
        if ~exists
            if isempty(out), out = incoming(i); else, out(end+1) = incoming(i); end %#ok<AGROW>
        end
    end
end

function idx = localFindRoi(rois, roiId)
    idx = [];
    if isempty(roiId), return; end
    for i = 1:numel(rois)
        try
            if strcmp(char(string(rois(i).id)), roiId)
                idx(end+1) = i; %#ok<AGROW>
            end
        catch
        end
    end
end

function ready = localWaitForChannels(roiObj, channels, opts)
    ready = {};
    if isempty(channels), return; end
    for attempt = 1:opts.RetryCount
        ready = localVisibleChannels(roiObj, channels);
        if numel(ready) == numel(channels), return; end
        if attempt < opts.RetryCount && opts.RetryPause > 0
            drawnow limitrate;
            pause(opts.RetryPause);
        end
    end
end

function ready = localVisibleChannels(roiObj, channels)
    ready = {};
    roiPath = '';
    roiId = '';
    try, roiPath = char(string(roiObj.path)); catch, end
    try, roiId = char(string(roiObj.id)); catch, end
    h5File = fullfile(roiPath, ['im_' roiId '.h5']);
    if exist(h5File, 'file') ~= 2, return; end
    storedNames = {};
    try
        info = h5info(h5File);
        for i = 1:numel(info.Datasets)
            datasetName = char(string(info.Datasets(i).Name));
            channelName = datasetName;
            try
                channelName = char(string(h5readatt(h5File, ['/' datasetName], 'channel_name')));
            catch
            end
            storedNames{end+1} = channelName; %#ok<AGROW>
        end
    catch
        return;
    end
    for i = 1:numel(channels)
        name = char(string(channels{i}));
        if any(strcmpi(storedNames, name))
            ready{end+1} = name; %#ok<AGROW>
        end
    end
end

function tf = localWaitForData(roiObj, opts)
    tf = false;
    for attempt = 1:opts.RetryCount
        tf = localDataFileVisible(roiObj);
        if tf, return; end
        if attempt < opts.RetryCount && opts.RetryPause > 0
            drawnow limitrate;
            pause(opts.RetryPause);
        end
    end
end

function tf = localDataFileVisible(roiObj)
    tf = false;
    try
        tf = exist(fullfile(char(string(roiObj.path)), ...
            ['data_' char(string(roiObj.id)) '.mat']), 'file') == 2;
    catch
    end
end

function out = localCellText(S, field)
    out = {};
    try
        if ~isstruct(S) || ~isfield(S, field) || isempty(S.(field)), return; end
        value = S.(field);
        if ischar(value) || isstring(value)
            out = cellstr(string(value));
        elseif iscell(value)
            out = cellfun(@(x) char(string(x)), value(:)', 'UniformOutput', false);
        end
    catch
        out = {};
    end
    out = unique(out, 'stable');
end

function value = localText(S, field)
    value = '';
    try
        if isstruct(S) && isfield(S, field) && ~isempty(S.(field))
            value = char(string(S.(field)));
        end
    catch
    end
end

function value = localLogical(S, field, fallback)
    value = fallback;
    try
        if isstruct(S) && isfield(S, field) && ~isempty(S.(field))
            value = logical(S.(field));
        end
    catch
        value = fallback;
    end
end
