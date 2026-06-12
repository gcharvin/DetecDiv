function [paramout, dataout, imageout] = core(param, roiobj, frames)
% singleCellOscillations.core  Detrend fluorescence and extract cycles.

imageout = [];

if nargin < 3
    frames = [];
end

if nargin == 0
    paramout = singleCellOscillations.setparam(struct());
    dataout = [];
    return;
end

paramout = normalizeParams(param);
dataout = [];

if isempty(roiobj)
    return;
end

if isempty(roiobj.data)
    roiobj.load('data');
end

if isempty(roiobj.data)
    warning('singleCellOscillations:NoData', 'ROI %s has no dataseries.', safeRoiId(roiobj));
    dataout = buildFallbackOutput(roiobj, paramout);
    return;
end

classDs = localPickDataSeries(roiobj.data, paramout.classification_data);
if isempty(classDs)
    warning('singleCellOscillations:MissingClassification', ...
        'ROI %s is missing classification dataseries "%s".', safeRoiId(roiobj), localSelectionText(paramout.classification_data));
    dataout = buildFallbackOutput(roiobj, paramout);
    return;
end

signalDs = localPickDataSeries(roiobj.data, paramout.fluorescence_data);

labels = localExtractLabels(classDs, paramout.labelColumn);
signal = localExtractSignal(signalDs, paramout.fluorescenceColumn, paramout.cellValueReducer);

if isempty(labels) && isempty(signal)
    dataout = buildFallbackOutput(roiobj, paramout);
    return;
end

n = max(numel(labels), numel(signal));
if n == 0
    n = 1;
end

labels = localPadLabels(labels, n);
signal = localPadSignal(signal, n);

frameIdx = localResolveFrameIndices(frames, paramout.frameStart, paramout.frameEnd, n);
frameIdx = frameIdx(frameIdx >= 1 & frameIdx <= n);
if isempty(frameIdx)
    frameIdx = 1:n;
end

labels = labels(frameIdx);
signal = signal(frameIdx);
time = (double(frameIdx(:)) - double(frameIdx(1))) .* double(paramout.framePeriod);
baseline = localComputeBaseline(signal, paramout.baselineMethod, paramout.baselineWindow, paramout.baselineEndpoints);
detrended = signal - baseline;

traceTbl = table(frameIdx(:), time(:), categorical(string(labels(:))), signal(:), baseline(:), detrended(:), ...
    'VariableNames', {'frame','time','label','signal','baseline','detrended'});

cycles = localBuildCycles(frameIdx, labels, paramout);
metaTbl = localBuildCycleMetadata(cycles, labels, signal, detrended, time);
normTbl = localBuildNormalizedCycles(cycles, signal, detrended, paramout);

dataout = roiobj.data;
dataout = localUpsertSeries(dataout, buildSeries(traceTbl, paramout.traceOutputName, roiobj.id, ...
    {'frame','time','label','signal','signal','signal'}, {false,false,true,true,true,true}, {'frame','time','label','signal','signal','signal'}, "temporal"));
dataout = localUpsertSeries(dataout, buildSeries(normTbl, paramout.normalizedCyclesOutputName, roiobj.id, ...
    repmat({'cycle'}, 1, width(normTbl)), localPlotFlags(width(normTbl)), repmat({'cycle'}, 1, width(normTbl)), "generation"));
dataout = localUpsertSeries(dataout, buildSeries(metaTbl, paramout.cycleMetadataOutputName, roiobj.id, ...
    repmat({'cycle'}, 1, width(metaTbl)), localPlotFlags(width(metaTbl)), repmat({'cycle'}, 1, width(metaTbl)), "generation"));

maybeWriteArtifacts(paramout, traceTbl, normTbl, metaTbl, safeRoiId(roiobj));
end

function paramout = normalizeParams(param)
paramout = param;
if ~isstruct(paramout)
    paramout = struct();
end

defaults = singleCellOscillations.setparam(struct());
fn = fieldnames(defaults);
for i = 1:numel(fn)
    if ~isfield(paramout, fn{i}) || isempty(paramout.(fn{i}))
        paramout.(fn{i}) = defaults.(fn{i});
    end
end

if ischar(paramout.classification_data)
    paramout.classification_data = {paramout.classification_data};
end
if ischar(paramout.fluorescence_data)
    paramout.fluorescence_data = {paramout.fluorescence_data};
end
if isempty(paramout.classification_data), paramout.classification_data = {'div_1'}; end
if isempty(paramout.fluorescence_data), paramout.fluorescence_data = {'channel_quantification'}; end
paramout.classification_data = localSelectionCell(paramout.classification_data);
paramout.fluorescence_data = localSelectionCell(paramout.fluorescence_data);
paramout.labelColumn = char(string(paramout.labelColumn));
paramout.fluorescenceColumn = char(string(paramout.fluorescenceColumn));
paramout.cellValueReducer = lower(char(string(paramout.cellValueReducer)));
paramout.baselineMethod = lower(char(string(paramout.baselineMethod)));
paramout.baselineEndpoints = lower(char(string(paramout.baselineEndpoints)));
paramout.cycleBoundaryMode = lower(char(string(paramout.cycleBoundaryMode)));
paramout.transitionFrom = char(string(paramout.transitionFrom));
paramout.transitionTo = char(string(paramout.transitionTo));
paramout.interpolationMethod = char(string(paramout.interpolationMethod));
paramout.traceOutputName = char(string(paramout.traceOutputName));
paramout.normalizedCyclesOutputName = char(string(paramout.normalizedCyclesOutputName));
paramout.cycleMetadataOutputName = char(string(paramout.cycleMetadataOutputName));
paramout.workbookName = char(string(paramout.workbookName));
paramout.outputDir = char(string(paramout.outputDir));
paramout.runId = char(string(paramout.runId));
paramout.verbose = logical(paramout.verbose);
paramout.writeArtifacts = logical(paramout.writeArtifacts);
paramout.allowExtrapolation = logical(paramout.allowExtrapolation);
paramout.framePeriod = localNumericScalar(paramout.framePeriod, 1);
paramout.baselineWindow = max(1, round(localNumericScalar(paramout.baselineWindow, 50)));
paramout.minCycleLength = max(1, round(localNumericScalar(paramout.minCycleLength, 1)));
paramout.maxCycleLength = max(paramout.minCycleLength, round(localNumericScalar(paramout.maxCycleLength, 200)));
paramout.normFrames = max(2, round(localNumericScalar(paramout.normFrames, 100)));
paramout.frameStart = localOptionalFrame(paramout.frameStart);
paramout.frameEnd = localOptionalFrame(paramout.frameEnd);
end

function series = buildSeries(tbl, groupid, parentid, groups, plotFlags, roleNames, typeName)
series = dataseries(tbl, tbl.Properties.VariableNames, ...
    'groupid', groupid, ...
    'parentid', parentid, ...
    'plot', plotFlags, ...
    'groups', groups);
series.class = "processing";
series.type = string(typeName);
series.description = struct('roleNames', {{roleNames}});
if ~isempty(series.userData) && ~isstruct(series.userData)
    series.userData = struct();
end
if ~isstruct(series.userData)
    series.userData = struct();
end
series.userData.processor = 'singleCellOscillations';
series.userData.groupid = groupid;
series.userData.roleNames = roleNames;
end

function plotFlags = localPlotFlags(n)
plotFlags = repmat({false}, 1, n);
if n >= 4
    plotFlags{4} = true;
    if n >= 5, plotFlags{5} = true; end
    if n >= 6, plotFlags{6} = true; end
elseif n >= 1
    plotFlags{end} = true;
end
end

function out = localSelectionCell(value)
if ischar(value) || isstring(value)
    out = {char(string(value))};
elseif iscell(value)
    out = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
else
    out = {char(string(value))};
end
if isempty(out)
    out = {''};
end
end

function labels = localPadLabels(labels, n)
if isempty(labels)
    labels = repmat("unavailable", n, 1);
    return;
end
labels = string(labels(:));
if numel(labels) < n
    labels(end+1:n, 1) = labels(end);
elseif numel(labels) > n
    labels = labels(1:n);
end
end

function signal = localPadSignal(signal, n)
if isempty(signal)
    signal = nan(n, 1);
    return;
end
signal = double(signal(:));
if numel(signal) < n
    signal(end+1:n, 1) = signal(end);
elseif numel(signal) > n
    signal = signal(1:n);
end
end

function s = localSelectionText(sel)
if iscell(sel) && ~isempty(sel)
    s = char(string(sel{end}));
else
    s = char(string(sel));
end
end

function out = localPickDataSeries(allData, selector)
out = [];
if isempty(allData)
    return;
end

if ischar(selector) || isstring(selector)
    selector = {char(string(selector))};
end
if ~iscell(selector)
    selector = {char(string(selector))};
end

for i = numel(selector):-1:1
    key = char(string(selector{i}));
    if isempty(key)
        continue;
    end
    idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(char(string(x.groupid)), key), allData), 1, 'first');
    if ~isempty(idx)
        out = allData(idx);
        return;
    end
end
end

function labels = localExtractLabels(ds, columnName)
labels = [];
if isempty(ds) || isempty(ds.data)
    return;
end

tbl = ds.data;
if ~istable(tbl) || isempty(tbl.Properties.VariableNames)
    return;
end

if isempty(columnName) || ~ismember(columnName, tbl.Properties.VariableNames)
    candidates = {'labels','label','state','class','prediction'};
    hit = candidates(ismember(candidates, tbl.Properties.VariableNames));
    if isempty(hit)
        return;
    end
    columnName = hit{1};
end

labels = tbl.(columnName);
if iscategorical(labels)
    labels = string(labels);
elseif iscell(labels)
    labels = string(labels);
elseif isnumeric(labels)
    labels = string(labels);
elseif isstring(labels)
    labels = labels;
else
    try
        labels = string(labels);
    catch
        labels = [];
    end
end
labels = labels(:);
end

function signal = localExtractSignal(ds, columnName, reducerName)
signal = [];
if isempty(ds) || isempty(ds.data)
    return;
end

tbl = ds.data;
if ~istable(tbl) || isempty(tbl.Properties.VariableNames)
    return;
end

if isempty(columnName) || ~ismember(columnName, tbl.Properties.VariableNames)
    numericVars = false(1, width(tbl));
    for i = 1:width(tbl)
        col = tbl.(tbl.Properties.VariableNames{i});
        numericVars(i) = isnumeric(col) || islogical(col);
    end
    idx = find(numericVars, 1, 'first');
    if isempty(idx)
        return;
    end
    columnName = tbl.Properties.VariableNames{idx};
end

signal = localFlattenSignal(tbl.(columnName), reducerName);
signal = double(signal(:));
end

function signal = localFlattenSignal(value, reducerName)
if isnumeric(value) || islogical(value)
    if isvector(value)
        signal = double(value(:));
    elseif size(value, 1) >= size(value, 2)
        signal = localReduceMatrix(double(value), reducerName);
    else
        signal = localReduceMatrix(double(value).', reducerName);
    end
elseif iscell(value)
    signal = cellfun(@(x) localReduceScalarLike(x, reducerName), value(:));
else
    try
        signal = double(value(:));
    catch
        signal = [];
    end
end
end

function out = localReduceMatrix(mat, reducerName)
if isempty(mat)
    out = [];
    return;
end
if size(mat, 2) == 1
    out = mat(:);
    return;
end
switch lower(reducerName)
    case {'median','med'}
        out = median(mat, 2, 'omitnan');
    case {'first'}
        out = mat(:,1);
    case {'max'}
        out = max(mat, [], 2, 'omitnan');
    case {'min'}
        out = min(mat, [], 2, 'omitnan');
    otherwise
        out = mean(mat, 2, 'omitnan');
end
end

function out = localReduceScalarLike(value, reducerName)
if isempty(value)
    out = NaN;
    return;
end
if isnumeric(value) || islogical(value)
    vec = double(value(:));
    if isempty(vec)
        out = NaN;
        return;
    end
    switch lower(reducerName)
        case {'median','med'}
            out = median(vec, 'omitnan');
        case {'first'}
            out = vec(1);
        case {'max'}
            out = max(vec, [], 'omitnan');
        case {'min'}
            out = min(vec, [], 'omitnan');
        otherwise
            out = mean(vec, 'omitnan');
    end
else
    try
        out = localReduceScalarLike(double(value), reducerName);
    catch
        out = NaN;
    end
end
end

function out = localResolveFrameIndices(frames, frameStart, frameEnd, n)
if nargin < 4 || isempty(n) || n < 1
    n = 1;
end
if isempty(frames) || (isnumeric(frames) && all(frames == -1))
    startIdx = 1;
    endIdx = n;
    if ~isempty(frameStart) && isfinite(frameStart), startIdx = max(1, round(frameStart)); end
    if ~isempty(frameEnd) && isfinite(frameEnd), endIdx = min(n, round(frameEnd)); end
    if endIdx < startIdx
        out = 1:n;
    else
        out = startIdx:endIdx;
    end
    return;
end

if islogical(frames)
    frames = find(frames);
elseif iscell(frames)
    frames = double(cell2mat(frames(:)));
elseif ~isnumeric(frames)
    try
        frames = double(frames(:));
    catch
        frames = [];
    end
end
frames = double(frames(:).');
frames = frames(isfinite(frames));
frames = unique(round(frames), 'stable');
out = frames;
end

function baseline = localComputeBaseline(signal, methodName, window, endpoints)
signal = double(signal(:));
if isempty(signal)
    baseline = [];
    return;
end
switch lower(methodName)
    case {'none','off','identity'}
        baseline = zeros(size(signal));
    case {'moving_median','median'}
        baseline = movmedian(signal, window, 'Endpoints', localEndpoints(endpoints));
    otherwise
        baseline = movmean(signal, window, 'Endpoints', localEndpoints(endpoints));
end
if numel(baseline) ~= numel(signal)
    baseline = zeros(size(signal));
end
baseline(isnan(baseline)) = 0;
end

function endpoint = localEndpoints(endpoints)
switch lower(char(string(endpoints)))
    case {'fill','legacy_discard'}
        endpoint = 'fill';
    otherwise
        endpoint = 'shrink';
end
end

function cycles = localBuildCycles(frameIdx, labels, param)
labels = string(labels(:));
if numel(labels) <= 1
    cycles = struct('startPos',1,'endPos',numel(labels),'startFrame',frameIdx(1),'endFrame',frameIdx(end),'startLabel',"",'endLabel',"");
    return;
end

boundaryPos = [];
if strcmpi(param.cycleBoundaryMode, 'label_transition')
    fromLab = lower(string(param.transitionFrom));
    toLab = lower(string(param.transitionTo));
    isBoundary = lower(labels(1:end-1)) == fromLab & lower(labels(2:end)) == toLab;
    boundaryPos = find(isBoundary);
end

if isempty(boundaryPos)
    cycles = struct('startPos',1,'endPos',numel(labels),'startFrame',frameIdx(1),'endFrame',frameIdx(end),'startLabel',labels(1),'endLabel',labels(end));
    return;
end

startPos = [1; boundaryPos(:) + 1];
endPos = [boundaryPos(:); numel(labels)];
keep = endPos - startPos + 1 >= max(1, round(param.minCycleLength));
startPos = startPos(keep);
endPos = endPos(keep);
if isempty(startPos)
    cycles = struct('startPos',1,'endPos',numel(labels),'startFrame',frameIdx(1),'endFrame',frameIdx(end),'startLabel',labels(1),'endLabel',labels(end));
    return;
end

cycles = repmat(struct('startPos',[],'endPos',[],'startFrame',[],'endFrame',[],'startLabel',"",'endLabel',""), 1, numel(startPos));
for i = 1:numel(startPos)
    cycles(i).startPos = startPos(i);
    cycles(i).endPos = endPos(i);
    cycles(i).startFrame = frameIdx(startPos(i));
    cycles(i).endFrame = frameIdx(endPos(i));
    cycles(i).startLabel = labels(startPos(i));
    cycles(i).endLabel = labels(endPos(i));
end
end

function metaTbl = localBuildCycleMetadata(cycles, labels, signal, detrended, time)
if isempty(cycles)
    metaTbl = table();
    return;
end

n = numel(cycles);
cycleIndex = (1:n).';
startFrame = zeros(n,1);
endFrame = zeros(n,1);
startTime = zeros(n,1);
endTime = zeros(n,1);
lengthFrames = zeros(n,1);
startLabel = strings(n,1);
endLabel = strings(n,1);
meanSignal = zeros(n,1);
meanDetrended = zeros(n,1);
minDetrended = zeros(n,1);
maxDetrended = zeros(n,1);

for i = 1:n
    idx = cycles(i).startPos:cycles(i).endPos;
    startFrame(i) = cycles(i).startFrame;
    endFrame(i) = cycles(i).endFrame;
    startTime(i) = time(idx(1));
    endTime(i) = time(idx(end));
    lengthFrames(i) = numel(idx);
    startLabel(i) = string(cycles(i).startLabel);
    endLabel(i) = string(cycles(i).endLabel);
    meanSignal(i) = mean(signal(idx), 'omitnan');
    meanDetrended(i) = mean(detrended(idx), 'omitnan');
    minDetrended(i) = min(detrended(idx), [], 'omitnan');
    maxDetrended(i) = max(detrended(idx), [], 'omitnan');
end

metaTbl = table(cycleIndex, startFrame, endFrame, startTime, endTime, lengthFrames, startLabel, endLabel, ...
    meanSignal, meanDetrended, minDetrended, maxDetrended);
end

function normTbl = localBuildNormalizedCycles(cycles, signal, detrended, param)
if isempty(cycles)
    normTbl = table();
    return;
end

nCycles = numel(cycles);
nPoints = param.normFrames;
sampleNames = arrayfun(@(k) sprintf('sample_%03d', k), 1:nPoints, 'UniformOutput', false);
normMatrix = nan(nCycles, nPoints);
cycleIndex = (1:nCycles).';
startFrame = zeros(nCycles,1);
endFrame = zeros(nCycles,1);
startLabel = strings(nCycles,1);
endLabel = strings(nCycles,1);

for i = 1:nCycles
    idx = cycles(i).startPos:cycles(i).endPos;
    seg = detrended(idx);
    if isempty(seg)
        continue;
    end
    x = linspace(1, numel(seg), numel(seg));
    xi = linspace(1, numel(seg), nPoints);
    try
        if param.allowExtrapolation
            normMatrix(i,:) = interp1(x, seg, xi, param.interpolationMethod, 'extrap');
        else
            normMatrix(i,:) = interp1(x, seg, xi, param.interpolationMethod, NaN);
        end
    catch
        normMatrix(i,:) = interp1(x, seg, xi, 'linear', 'extrap');
    end
    startFrame(i) = cycles(i).startFrame;
    endFrame(i) = cycles(i).endFrame;
    startLabel(i) = string(cycles(i).startLabel);
    endLabel(i) = string(cycles(i).endLabel);
end

normTbl = array2table(normMatrix, 'VariableNames', sampleNames);
normTbl.cycleIndex = cycleIndex;
normTbl.startFrame = startFrame;
normTbl.endFrame = endFrame;
normTbl.startLabel = startLabel;
normTbl.endLabel = endLabel;
normTbl = movevars(normTbl, {'cycleIndex','startFrame','endFrame','startLabel','endLabel'}, 'Before', 1);
end

function dataout = localUpsertSeries(dataout, series)
if isempty(series) || isempty(series.groupid)
    return;
end
if isempty(dataout) || (numel(dataout) == 1 && isempty(dataout.data))
    dataout = series;
    return;
end
idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(char(string(x.groupid)), char(string(series.groupid))), dataout), 1, 'first');
if isempty(idx)
    dataout(end+1) = series; %#ok<AGROW>
else
    dataout(idx) = series;
end
end

function out = buildFallbackOutput(roiobj, paramout)
tbl = table((1:1).', string("unavailable"), NaN, NaN, NaN, ...
    'VariableNames', {'frame','label','signal','baseline','detrended'});
out = buildSeries(tbl, paramout.traceOutputName, safeRoiId(roiobj), ...
    {'frame','label','signal','signal','signal'}, {false,true,true,true,true}, {'frame','label','signal','signal','signal'}, "temporal");
end

function maybeWriteArtifacts(paramout, traceTbl, normTbl, metaTbl, roiId)
if ~paramout.writeArtifacts
    return;
end

if isempty(paramout.outputDir)
    return;
end

try
    if ~exist(paramout.outputDir, 'dir')
        mkdir(paramout.outputDir);
    end
    outFile = fullfile(paramout.outputDir, paramout.workbookName);
    if isempty(outFile)
        return;
    end
    writetable(traceTbl, outFile, 'Sheet', 'trace');
    if ~isempty(normTbl)
        writetable(normTbl, outFile, 'Sheet', 'normalized_cycles', 'WriteMode', 'overwritesheet');
    end
    if ~isempty(metaTbl)
        writetable(metaTbl, outFile, 'Sheet', 'cycle_metadata', 'WriteMode', 'overwritesheet');
    end
    fprintf('[singleCellOscillations] artifacts written for ROI %s -> %s\n', roiId, outFile);
catch ME
    warning('singleCellOscillations:ArtifactWriteFailed', ...
        'Could not write artifacts for ROI %s: %s', roiId, ME.message);
end
end

function txt = safeRoiId(roiobj)
txt = '<unknown>';
try
    txt = char(string(roiobj.id));
catch
end
end

function val = localNumericScalar(value, fallback)
val = fallback;
try
    if ~isempty(value)
        val = double(value);
        if ~isscalar(val) || ~isfinite(val)
            val = fallback;
        end
    end
catch
    val = fallback;
end
end

function val = localOptionalFrame(value)
val = [];
try
    if ~isempty(value) && isfinite(value)
        val = round(double(value));
    end
catch
    val = [];
end
end
