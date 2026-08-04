function manifest = detecdiv_build_run_mutation_manifest(runObj, pipeObj, report, ctx)
% detecdiv_build_run_mutation_manifest  Describe ROI stores changed by a run.
%
% The manifest is deliberately small. It is persisted in run.json and can
% also travel in local/Hub completion events so the client only reloads the
% ROI outputs written by completed nodes.

    if nargin < 1, runObj = []; end
    if nargin < 2, pipeObj = []; end %#ok<NASGU>
    if nargin < 3 || ~isstruct(report), report = struct(); end
    if nargin < 4 || ~isstruct(ctx), ctx = struct(); end

    manifest = localEmptyManifest();
    manifest.committedAt = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
    manifest.runId = localRunId(runObj, ctx);
    manifest.status = localRunStatus(runObj);
    [manifest.scope, manifest.classifierPath, manifest.projectPath] = localScope(runObj, ctx);

    completed = localCompletedOutputs(report);
    rois = localContextRois(ctx);
    manifest.roiIds = localRoiIds(rois);
    manifest.outputs = completed;
    manifest.rois = repmat(localEmptyRoiChange(), 0, 1);

    for i = 1:numel(rois)
        change = localEmptyRoiChange();
        change.id = localRoiId(rois(i));
        change.path = localRoiPath(rois(i));
        if isempty(change.id)
            continue;
        end
        change.h5File = fullfile(change.path, ['im_' change.id '.h5']);
        change.dataFile = fullfile(change.path, ['data_' change.id '.mat']);
        h5Names = localH5DatasetNames(change.h5File);
        for j = 1:numel(completed)
            logicalName = completed(j).logicalName;
            change.channels = [change.channels localMatchingNames(h5Names, logicalName)]; %#ok<AGROW>
            change.dataSeries = [change.dataSeries ...
                localMatchingDataSeriesNames(rois(i), logicalName)]; %#ok<AGROW>
        end
        change.channels = unique(change.channels, 'stable');
        change.dataSeries = unique(change.dataSeries, 'stable');
        change.reloadData = ~isempty(change.dataSeries);
        manifest.rois(end+1,1) = change; %#ok<AGROW>
    end

    for j = 1:numel(manifest.outputs)
        channels = {};
        dataSeries = {};
        for i = 1:numel(manifest.rois)
            channels = [channels localMatchingNames(manifest.rois(i).channels, manifest.outputs(j).logicalName)]; %#ok<AGROW>
            if i <= numel(rois)
                dataSeries = [dataSeries ...
                    localMatchingDataSeriesNames(rois(i), ...
                    manifest.outputs(j).logicalName)]; %#ok<AGROW>
            end
        end
        manifest.outputs(j).channels = unique(channels, 'stable');
        manifest.outputs(j).dataSeries = unique(dataSeries, 'stable');
    end
end

function manifest = localEmptyManifest()
    manifest = struct( ...
        'protocol', 'detecdiv.roi-mutations.v1', ...
        'committedAt', '', ...
        'runId', '', ...
        'status', '', ...
        'scope', '', ...
        'classifierPath', '', ...
        'projectPath', '', ...
        'roiIds', {{}}, ...
        'outputs', repmat(localEmptyOutput(), 0, 1), ...
        'rois', repmat(localEmptyRoiChange(), 0, 1));
end

function out = localEmptyOutput()
    out = struct('nodeId', '', 'nodeType', '', 'logicalName', '', ...
        'channels', {{}}, 'dataSeries', {{}});
end

function out = localEmptyRoiChange()
    out = struct('id', '', 'path', '', 'h5File', '', 'dataFile', '', ...
        'channels', {{}}, 'dataSeries', {{}}, 'reloadData', false);
end

function outputs = localCompletedOutputs(report)
    outputs = repmat(localEmptyOutput(), 0, 1);
    if ~isfield(report, 'nodeRuns') || ~isstruct(report.nodeRuns)
        return;
    end
    rows = report.nodeRuns;
    for i = 1:numel(rows)
        status = lower(localText(rows(i), 'status'));
        logicalName = localText(rows(i), 'outputName');
        if ~strcmp(status, 'done') || isempty(strtrim(logicalName))
            continue;
        end
        row = localEmptyOutput();
        row.nodeId = localText(rows(i), 'nodeId');
        row.nodeType = localText(rows(i), 'nodeType');
        row.logicalName = logicalName;
        outputs(end+1,1) = row; %#ok<AGROW>
    end
    if isempty(outputs)
        return;
    end
    keys = strcat(string({outputs.nodeId}), "|", string({outputs.logicalName}));
    [~, keep] = unique(keys, 'stable');
    outputs = outputs(sort(keep));
end

function rois = localContextRois(ctx)
    rois = [];
    candidates = {'roiList', 'rois'};
    for i = 1:numel(candidates)
        name = candidates{i};
        if isfield(ctx, name) && ~isempty(ctx.(name)) && isa(ctx.(name), 'roi')
            rois = ctx.(name);
            return;
        end
    end
end

function ids = localRoiIds(rois)
    ids = {};
    for i = 1:numel(rois)
        id = localRoiId(rois(i));
        if ~isempty(id)
            ids{end+1} = id; %#ok<AGROW>
        end
    end
    ids = unique(ids, 'stable');
end

function id = localRoiId(roiObj)
    id = '';
    try, id = char(string(roiObj.id)); catch, end
end

function pathText = localRoiPath(roiObj)
    pathText = '';
    try, pathText = char(string(roiObj.path)); catch, end
end

function names = localH5DatasetNames(h5File)
    names = {};
    if isempty(h5File) || exist(h5File, 'file') ~= 2
        return;
    end
    try
        info = h5info(h5File);
        for i = 1:numel(info.Datasets)
            datasetName = char(string(info.Datasets(i).Name));
            channelName = datasetName;
            try
                channelName = char(string(h5readatt(h5File, ['/' datasetName], 'channel_name')));
            catch
            end
            names{end+1} = channelName; %#ok<AGROW>
        end
    catch
        names = {};
    end
end

function matches = localMatchingDataSeriesNames(roiObj, logicalName)
    matches = {};
    try
        data = roiObj.data;
        for i = 1:numel(data)
            groupId = '';
            try, groupId = char(string(data(i).groupid)); catch, end
            if isempty(groupId)
                continue;
            end
            if ~isempty(localMatchingNames({groupId}, logicalName)) || ...
                    localDataSeriesHasLogicalSource(data(i), logicalName)
                matches{end+1} = groupId; %#ok<AGROW>
            end
        end
    catch
        matches = {};
    end
    matches = unique(matches, 'stable');
end

function tf = localDataSeriesHasLogicalSource(ds, logicalName)
    tf = false;
    try
        if ~isstruct(ds.userData) || ...
                ~isfield(ds.userData, 'lineageSources') || ...
                ~isstruct(ds.userData.lineageSources)
            return;
        end
        sources = ds.userData.lineageSources;
        sourceKeys = fieldnames(sources);
        logicalText = char(string(logicalName));
        logicalKey = matlab.lang.makeValidName(logicalText);
        for i = 1:numel(sourceKeys)
            source = sources.(sourceKeys{i});
            candidates = sourceKeys(i);
            if isstruct(source)
                if isfield(source, 'outputName')
                    candidates{end+1} = char(string(source.outputName)); %#ok<AGROW>
                end
                if isfield(source, 'displayName')
                    candidates{end+1} = char(string(source.displayName)); %#ok<AGROW>
                end
            end
            if any(strcmpi(candidates, logicalText)) || ...
                    any(strcmpi(candidates, logicalKey))
                tf = true;
                return;
            end
        end
    catch
        tf = false;
    end
end

function matches = localMatchingNames(names, logicalName)
    matches = {};
    if isempty(names) || isempty(logicalName)
        return;
    end
    logicalName = char(string(logicalName));
    probes = {logicalName, ['results_' logicalName], ['prob_' logicalName], ...
        ['results_' logicalName '_cell'], ['prob_' logicalName '_cell']};
    for i = 1:numel(names)
        name = char(string(names{i}));
        if any(strcmpi(name, probes)) || startsWith(lower(name), [lower(logicalName) '_']) || ...
                contains(lower(name), ['_' lower(logicalName) '_'])
            matches{end+1} = name; %#ok<AGROW>
        end
    end
    matches = unique(matches, 'stable');
end

function [scope, classifierPath, projectPath] = localScope(runObj, ctx)
    scope = '';
    classifierPath = '';
    projectPath = '';
    ref = struct();
    try
        if ~isempty(runObj) && isprop(runObj, 'targetRef') && isstruct(runObj.targetRef)
            ref = runObj.targetRef;
        elseif isfield(ctx, 'targetRef') && isstruct(ctx.targetRef)
            ref = ctx.targetRef;
        end
    catch
    end
    scope = lower(localText(ref, 'type'));
    classifierPath = localText(ref, 'classiPath');
    projectPath = localText(ref, 'projectPath');
    if isempty(scope)
        if ~isempty(classifierPath), scope = 'classi'; else, scope = 'shallow'; end
    end
end

function runId = localRunId(runObj, ctx)
    runId = '';
    try
        if ~isempty(runObj) && isprop(runObj, 'runId')
            runId = char(string(runObj.runId));
        end
    catch
    end
    if isempty(runId)
        runId = localText(ctx, 'runId');
    end
end

function status = localRunStatus(runObj)
    status = '';
    try
        if ~isempty(runObj) && isprop(runObj, 'status')
            status = char(string(runObj.status));
        end
    catch
    end
end

function value = localText(S, field)
    value = '';
    try
        if isstruct(S) && isfield(S, field) && ~isempty(S.(field))
            value = char(string(S.(field)));
        end
    catch
        value = '';
    end
end
