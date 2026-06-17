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
signal = localExtractSignal(signalDs, paramout.fluorescenceVariable, paramout.cellIndex);

if isempty(labels) && isempty(signal)
    dataout = buildFallbackOutput(roiobj, paramout);
    return;
end

n = max(numel(labels), size(signal, 1));
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

baselineFull = localComputeBaseline(signal, paramout.baselineMethod, paramout.baselineWindow, paramout.baselineEndpoints);
labels = labels(frameIdx);
signal = signal(frameIdx, :);
baseline = baselineFull(frameIdx, :);
time = (double(frameIdx(:)) - double(frameIdx(1))) .* double(paramout.framePeriod);
detrended = signal - baseline;

traceTbl = localBuildTraceTable(frameIdx, time, labels, signal, baseline, detrended);

cycles = localBuildCycles(frameIdx, labels, paramout);
metaTbl = localBuildCycleMetadata(cycles, labels, signal, detrended, time);
normTbl = localBuildNormalizedCycles(cycles, signal, detrended, paramout);

dataout = roiobj.data;
dataout = localUpsertSeries(dataout, buildSeries(traceTbl, paramout.traceOutputName, roiobj.id, ...
    localTraceGroups(width(traceTbl)), localTracePlotFlags(width(traceTbl)), localTraceRoles(traceTbl), "temporal"));
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
paramout.labelColumn = localLegacyText(paramout, 'labelColumn', 'labels');
paramout.fluorescenceVariable = localFluorescenceVariableParam(paramout);
paramout.cellIndex = max(1, round(localNumericScalar(localLegacyValue(paramout, 'cellIndex', 1), 1)));
paramout.baselineMethod = lower(char(string(paramout.baselineMethod)));
paramout.baselineEndpoints = lower(char(string(paramout.baselineEndpoints)));
paramout.traceOutputName = char(string(paramout.traceOutputName));
paramout.normalizedCyclesOutputName = char(string(paramout.normalizedCyclesOutputName));
paramout.cycleMetadataOutputName = char(string(paramout.cycleMetadataOutputName));
paramout.workbookName = char(string(paramout.workbookName));
paramout.outputDir = char(string(paramout.outputDir));
paramout.writeArtifacts = logical(paramout.writeArtifacts);
paramout.allowExtrapolation = logical(paramout.allowExtrapolation);
paramout.framePeriod = localNumericScalar(paramout.framePeriod, 1);
paramout.baselineWindow = max(1, round(localNumericScalar(paramout.baselineWindow, 50)));
paramout.minCycleLength = max(1, round(localNumericScalar(paramout.minCycleLength, 1)));
paramout.normFrames = max(2, round(localNumericScalar(paramout.normFrames, 100)));
paramout.frameStart = localOptionalFrame(paramout.frameStart);
paramout.frameEnd = localOptionalFrame(paramout.frameEnd);
end

function value = localFluorescenceVariableParam(paramout)
value = localLegacyText(paramout, 'fluorescenceVariable', '');
if isempty(strtrim(value))
    value = localLegacyText(paramout, 'fluorescenceColumn', '');
end
value = localVariableNameFromBindingLabel(value);
end

function value = localVariableNameFromBindingLabel(value)
value = strtrim(char(string(value)));
if isempty(value) || strcmpi(value, 'auto')
    value = '';
    return;
end
parts = regexp(value, '\s*/\s*', 'split');
if numel(parts) >= 2
    value = strtrim(parts{end});
end
end

function value = localLegacyText(s, fieldName, fallback)
value = fallback;
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = char(string(s.(fieldName)));
end
end

function value = localLegacyValue(s, fieldName, fallback)
value = fallback;
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
end
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

function tbl = localBuildTraceTable(frameIdx, time, labels, signal, baseline, detrended)
nFrames = numel(frameIdx);
nValues = size(signal, 2);
if nValues <= 1
    tbl = table(frameIdx(:), time(:), categorical(string(labels(:))), signal(:), baseline(:), detrended(:), ...
        'VariableNames', {'frame','time','label','signal','baseline','detrended'});
    return;
end

frameCol = repmat(frameIdx(:), nValues, 1);
timeCol = repmat(time(:), nValues, 1);
labelCol = repmat(categorical(string(labels(:))), nValues, 1);
valueIndex = repelem((1:nValues).', nFrames, 1);
tbl = table(frameCol, timeCol, labelCol, valueIndex, signal(:), baseline(:), detrended(:), ...
    'VariableNames', {'frame','time','label','valueIndex','signal','baseline','detrended'});
end

function groups = localTraceGroups(n)
base = {'frame','time','label','id','signal','signal','signal'};
groups = base(1:min(n, numel(base)));
if numel(groups) < n
    groups(end+1:n) = {'signal'};
end
end

function roles = localTraceRoles(tbl)
roles = tbl.Properties.VariableNames;
for i = 1:numel(roles)
    if any(strcmp(roles{i}, {'signal','baseline','detrended'}))
        roles{i} = 'signal';
    elseif strcmp(roles{i}, 'valueIndex')
        roles{i} = 'id';
    end
end
end

function flags = localTracePlotFlags(n)
flags = repmat({false}, 1, n);
if n >= 6
    flags{n-2} = true;
    flags{n-1} = true;
    flags{n} = true;
elseif n >= 1
    flags{end} = true;
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
signal = double(signal);
if isvector(signal)
    signal = signal(:);
end
if size(signal, 1) < n
    lastRow = signal(end, :);
    signal(end+1:n, :) = repmat(lastRow, n - size(signal, 1), 1);
elseif size(signal, 1) > n
    signal = signal(1:n, :);
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

function signal = localExtractSignal(ds, variableName, cellIndex)
signal = [];
if isempty(ds) || isempty(ds.data)
    return;
end

tbl = ds.data;
if ~istable(tbl) || isempty(tbl.Properties.VariableNames)
    return;
end

variableName = char(string(variableName));
if isempty(variableName) || ~ismember(variableName, tbl.Properties.VariableNames)
    numericVars = false(1, width(tbl));
    for i = 1:width(tbl)
        col = tbl.(tbl.Properties.VariableNames{i});
        numericVars(i) = isnumeric(col) || islogical(col);
    end
    idx = find(numericVars, 1, 'first');
    if isempty(idx)
        return;
    end
    variableName = tbl.Properties.VariableNames{idx};
end

signal = localSelectSignalIndex(tbl.(variableName), cellIndex);
signal = double(signal);
if isvector(signal)
    signal = signal(:);
end
end

function signal = localSelectSignalIndex(value, cellIndex)
cellIndex = max(1, round(localNumericScalar(cellIndex, 1)));
if isnumeric(value) || islogical(value)
    if isvector(value)
        signal = double(value(:));
    elseif size(value, 1) >= size(value, 2)
        mat = double(value);
        signal = mat(:, min(cellIndex, size(mat, 2)));
    else
        mat = double(value).';
        signal = mat(:, min(cellIndex, size(mat, 2)));
    end
elseif iscell(value)
    signal = cellfun(@(x) localSelectScalarLike(x, cellIndex), value(:));
else
    try
        signal = double(value(:));
    catch
        signal = [];
    end
end
end

function out = localSelectScalarLike(value, cellIndex)
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
    out = vec(min(cellIndex, numel(vec)));
else
    try
        out = localSelectScalarLike(double(value), cellIndex);
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
signal = double(signal);
if isvector(signal)
    signal = signal(:);
end
if isempty(signal)
    baseline = [];
    return;
end
discardMode = any(strcmpi(char(string(endpoints)), {'discard','antoine'}));
switch lower(methodName)
    case {'none','off','identity'}
        baseline = zeros(size(signal));
    case {'moving_median','median'}
        baseline = movmedian(signal, window, 'Endpoints', localEndpoints(endpoints));
    otherwise
        baseline = movmean(signal, window, 'Endpoints', localEndpoints(endpoints));
end
if discardMode
    padded = nan(size(signal));
    startIdx = max(1, ceil(double(window) / 2));
    stopIdx = min(size(signal, 1), startIdx + size(baseline, 1) - 1);
    if stopIdx >= startIdx
        padded(startIdx:stopIdx, :) = baseline(1:(stopIdx - startIdx + 1), :);
    end
    baseline = padded;
elseif ~isequal(size(baseline), size(signal))
    baseline = zeros(size(signal));
end
end

function endpoint = localEndpoints(endpoints)
switch lower(char(string(endpoints)))
    case {'fill'}
        endpoint = 'fill';
    case {'discard','antoine','legacy_discard'}
        endpoint = 'discard';
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

previousLabels = lower(labels(1:end-1));
nextLabels = lower(labels(2:end));
isBoundary = ismember(previousLabels, ["large","unbud","unbudded"]) & nextLabels == "small";
boundaryPos = find(isBoundary);

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
nValues = size(signal, 2);
nRows = n * nValues;
cycleIndex = zeros(nRows,1);
valueIndex = zeros(nRows,1);
startFrame = zeros(nRows,1);
endFrame = zeros(nRows,1);
startTime = zeros(nRows,1);
endTime = zeros(nRows,1);
lengthFrames = zeros(nRows,1);
startLabel = strings(nRows,1);
endLabel = strings(nRows,1);
meanSignal = zeros(nRows,1);
meanDetrended = zeros(nRows,1);
minDetrended = zeros(nRows,1);
maxDetrended = zeros(nRows,1);

row = 0;
for i = 1:n
    idx = cycles(i).startPos:cycles(i).endPos;
    for v = 1:nValues
        row = row + 1;
        cycleIndex(row) = i;
        valueIndex(row) = v;
        startFrame(row) = cycles(i).startFrame;
        endFrame(row) = cycles(i).endFrame;
        startTime(row) = time(idx(1));
        endTime(row) = time(idx(end));
        lengthFrames(row) = numel(idx);
        startLabel(row) = string(cycles(i).startLabel);
        endLabel(row) = string(cycles(i).endLabel);
        meanSignal(row) = mean(signal(idx, v), 'omitnan');
        meanDetrended(row) = mean(detrended(idx, v), 'omitnan');
        minDetrended(row) = min(detrended(idx, v), [], 'omitnan');
        maxDetrended(row) = max(detrended(idx, v), [], 'omitnan');
    end
end

metaTbl = table(cycleIndex, valueIndex, startFrame, endFrame, startTime, endTime, lengthFrames, startLabel, endLabel, ...
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
nValues = size(detrended, 2);
nRows = nCycles * nValues;
normMatrix = nan(nRows, nPoints);
cycleIndex = zeros(nRows,1);
valueIndex = zeros(nRows,1);
startFrame = zeros(nRows,1);
endFrame = zeros(nRows,1);
startLabel = strings(nRows,1);
endLabel = strings(nRows,1);

row = 0;
for i = 1:nCycles
    idx = cycles(i).startPos:cycles(i).endPos;
    for v = 1:nValues
        row = row + 1;
        seg = detrended(idx, v);
        if ~isempty(seg)
            x = linspace(1, numel(seg), numel(seg));
            xi = linspace(1, numel(seg), nPoints);
            try
                if param.allowExtrapolation
                    normMatrix(row,:) = interp1(x, seg, xi, 'linear', 'extrap');
                else
                    normMatrix(row,:) = interp1(x, seg, xi, 'linear', NaN);
                end
            catch
                normMatrix(row,:) = interp1(x, seg, xi, 'linear', 'extrap');
            end
        end
        cycleIndex(row) = i;
        valueIndex(row) = v;
        startFrame(row) = cycles(i).startFrame;
        endFrame(row) = cycles(i).endFrame;
        startLabel(row) = string(cycles(i).startLabel);
        endLabel(row) = string(cycles(i).endLabel);
    end
end

normTbl = array2table(normMatrix, 'VariableNames', sampleNames);
normTbl.cycleIndex = cycleIndex;
normTbl.valueIndex = valueIndex;
normTbl.startFrame = startFrame;
normTbl.endFrame = endFrame;
normTbl.startLabel = startLabel;
normTbl.endLabel = endLabel;
normTbl = movevars(normTbl, {'cycleIndex','valueIndex','startFrame','endFrame','startLabel','endLabel'}, 'Before', 1);
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
