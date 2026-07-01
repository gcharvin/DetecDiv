function [paramout, dataout, imageout] = core(param, roiobj, frames) %#ok<INUSD>
% computeMetrics.core  Compute mask geometry and mask-linked channel metrics.

imageout = [];

if nargin < 3
    frames = [];
end

if nargin == 0
    paramout = computeMetrics.setparam(struct());
    dataout = [];
    return;
end

paramout = normalizeComputeMetricsParams(param);
disp('computeMetrics processing...');

if numel(roiobj.image) == 0
    roiobj.load;
end

requestedFrames = frames;
frames = normalizeFramesSelection(frames, size(roiobj.image, 4));
fprintf('computeMetrics frames: roi=%s requested=%s applied=%s count=%d/%d\n', ...
    roiIdText(roiobj), frameSelectionText(requestedFrames), frameSelectionText(frames), numel(frames), size(roiobj.image, 4));
if isfield(paramout, 'debugFrames') && ~isempty(paramout.debugFrames) && logical(paramout.debugFrames)
    fprintf('[computeMetrics.core] file=%s roi=%s normalizedFrames=%s count=%d imageFrames=%d\n', ...
        which('computeMetrics.core'), roiIdText(roiobj), mat2str(frames), numel(frames), size(roiobj.image, 4));
end

dataout = roiobj.data;
if numel(dataout) == 0
    dataout = dataseries;
end

maskCount = paramout.maskChannelCount;
scoreCount = paramout.scoreChannelCount;

for i = 1:maskCount
    maskName = paramout.(sprintf('mask%d_name', i));
    if ~paramout.(sprintf('mask%d_stat', i)) || strcmp(maskName, 'N/A')
        continue;
    end

    cha = roiobj.findChannelID(maskName);
    if isempty(cha)
        warning('computeMetrics:MissingMaskChannel', ...
            'Mask channel "%s" is unavailable for ROI %s.', maskName, roiIdText(roiobj));
        continue;
    end

    dataout = computeMaskGeometry(dataout, roiobj, paramout, i, cha(1), frames);
end

channelsExtract = {};
channelsName = {};
for i = 1:scoreCount
    channelName = paramout.(sprintf('channel%d_name', i));
    if strcmp(channelName, 'N/A')
        continue;
    end
    cha = roiobj.findChannelID(channelName);
    if isempty(cha)
        warning('computeMetrics:MissingScoreChannel', ...
            'Score channel "%s" is unavailable for ROI %s.', channelName, roiIdText(roiobj));
        continue;
    end
    channelsExtract{end+1} = cha; %#ok<AGROW>
    channelsName{end+1} = channelName; %#ok<AGROW>
end

if isempty(channelsExtract)
    warnOnceLocal('computeMetrics:NoValidScoreChannel', ...
        ['score|' strjoin(cellstr(string(channelsName)), '|')], ...
        'No valid score channel is available for ROI %s; %s will not be created.', roiIdText(roiobj), paramout.outputName);
    return;
end

dataout = computeChannelQuantification(dataout, roiobj, paramout, channelsExtract, channelsName, frames);
if logical(paramout.computeMaskCombinations)
    [imageout, compositeChannelNames] = buildCompositeMaskAnnotationChannels(roiobj, paramout, frames);
    if ~isempty(compositeChannelNames)
        paramout.saveChannels = compositeChannelNames;
    end
end
end

function frames = normalizeFramesSelection(frames, nFrames)
if nargin < 2 || isempty(nFrames) || ~isfinite(nFrames) || nFrames < 1
    nFrames = 1;
end

if isempty(frames) || (isnumeric(frames) && all(frames == -1))
    frames = 1:nFrames;
    return;
end

if islogical(frames)
    frames = find(frames);
elseif iscell(frames)
    try
        frames = double(cell2mat(frames(:)));
    catch
        frames = [];
    end
elseif ~isnumeric(frames)
    try
        frames = double(frames(:));
    catch
        frames = [];
    end
end

frames = double(frames(:).');
frames = frames(isfinite(frames) & frames >= 1 & frames <= nFrames);
frames = unique(round(frames), 'stable');
if isempty(frames)
    frames = 1:nFrames;
end
end

function txt = frameSelectionText(frames)
if isempty(frames)
    txt = 'all';
    return;
end
if isnumeric(frames) || islogical(frames)
    frames = double(frames(:).');
    if isempty(frames)
        txt = 'all';
    elseif numel(frames) <= 12
        txt = mat2str(frames);
    elseif isContiguousFrames(frames)
        txt = sprintf('%g:%g', frames(1), frames(end));
    else
        txt = sprintf('[%g %g ... %g %g] (%d frames)', frames(1), frames(2), frames(end-1), frames(end), numel(frames));
    end
else
    try
        txt = frameSelectionText(double(frames(:).'));
    catch
        txt = char(string(frames));
    end
end
end

function tf = isContiguousFrames(frames)
tf = numel(frames) > 1 && all(diff(frames) == 1);
end

function paramout = normalizeComputeMetricsParams(param)
paramout = param;
if ~isstruct(paramout)
    paramout = struct();
end

paramout.maskChannelCount = countParam(paramout, {'maskChannelCount','maskCount'}, inferIndexedCount(paramout, '^mask(\d+)_name$', 2), 1, 8);
paramout.scoreChannelCount = countParam(paramout, {'scoreChannelCount','channelCount'}, inferIndexedCount(paramout, '^channel(\d+)_name$', 4), 0, 12);

for i = 1:paramout.maskChannelCount
    nameKey = sprintf('mask%d_name', i);
    statKey = sprintf('mask%d_stat', i);
    labelKey = sprintf('mask%d_label', i);
    if ~isfield(paramout, nameKey) || isempty(paramout.(nameKey))
        paramout.(nameKey) = 'N/A';
    end
    paramout.(nameKey) = selectedText(paramout.(nameKey), 'N/A');
    if ~isfield(paramout, statKey) || isempty(paramout.(statKey))
        paramout.(statKey) = true;
    end
    paramout.(statKey) = logical(paramout.(statKey));
    if ~isfield(paramout, labelKey) || isempty(paramout.(labelKey))
        paramout.(labelKey) = defaultMaskLabel(i);
    end
    paramout.(labelKey) = selectedText(paramout.(labelKey), defaultMaskLabel(i));
    backgroundKey = sprintf('mask%d_backgroundLabel', i);
    if ~isfield(paramout, backgroundKey) || isempty(paramout.(backgroundKey))
        paramout.(backgroundKey) = 'auto';
    end
    paramout.(backgroundKey) = normalizeBackgroundLabelParam(paramout.(backgroundKey));
    scoreKey = sprintf('mask%d_scoreLabel', i);
    if ~isfield(paramout, scoreKey) || isempty(paramout.(scoreKey))
        paramout.(scoreKey) = 'all';
    end
    paramout.(scoreKey) = normalizeScoreLabelParam(paramout.(scoreKey));
end

for i = 1:paramout.scoreChannelCount
    key = sprintf('channel%d_name', i);
    if ~isfield(paramout, key) || isempty(paramout.(key))
        paramout.(key) = 'N/A';
    end
    paramout.(key) = selectedText(paramout.(key), 'N/A');
end

if ~isfield(paramout, 'BrightestPixels') || isempty(paramout.BrightestPixels)
    paramout.BrightestPixels = 20;
end
paramout.BrightestPixels = max(1, round(numericScalar(paramout.BrightestPixels, 20)));
if ~isfield(paramout, 'backgroundMethod') || isempty(paramout.backgroundMethod)
    paramout.backgroundMethod = 'mean';
end
paramout.backgroundMethod = normalizeBackgroundMethod(paramout.backgroundMethod);
if ~isfield(paramout, 'backgroundPercentile') || isempty(paramout.backgroundPercentile)
    paramout.backgroundPercentile = 20;
end
paramout.backgroundPercentile = min(100, max(0, numericScalar(paramout.backgroundPercentile, 20)));
if ~isfield(paramout, 'backgroundDilatePx') || isempty(paramout.backgroundDilatePx)
    paramout.backgroundDilatePx = 0;
end
paramout.backgroundDilatePx = max(0, round(numericScalar(paramout.backgroundDilatePx, 0)));
if ~isfield(paramout, 'computeMaskCombinations') || isempty(paramout.computeMaskCombinations)
    paramout.computeMaskCombinations = true;
end
paramout.computeMaskCombinations = logicalScalar(paramout.computeMaskCombinations, true);
if ~isfield(paramout, 'outputName') || isempty(paramout.outputName)
    paramout.outputName = 'channel_quantification';
end
paramout.outputName = selectedText(paramout.outputName, 'channel_quantification');
if isLegacyAutoOutputName(paramout.outputName)
    paramout.outputName = 'channel_quantification';
end
end

function dataout = computeMaskGeometry(dataout, roiobj, paramout, maskIndex, cha, frames)
maskName = paramout.(sprintf('mask%d_name', maskIndex));
maskLabel = paramout.(sprintf('mask%d_label', maskIndex));
backgroundLabel = paramout.(sprintf('mask%d_backgroundLabel', maskIndex));
scoreLabel = paramout.(sprintf('mask%d_scoreLabel', maskIndex));
maskImage = roiobj.image(:,:,cha,frames);
maskLabelSafe = makeSafeVariableName(maskLabel);
groupId = ['mask_quantification_' maskLabelSafe];

roiobj.data = roiobj.data(isvalid(roiobj.data));
pixdata = find(arrayfun(@(x) strcmp(x.groupid, groupId), roiobj.data));
if ~isempty(pixdata)
    cc = pixdata(1);
else
    if numel(dataout) == 1 && isempty(dataout.data)
        cc = 1;
    else
        cc = numel(dataout) + 1;
    end
end

nFrames = size(maskImage, 4);
idxCol = cell(nFrames, 1);
areaCol = cell(nFrames, 1);
minorCol = cell(nFrames, 1);
majorCol = cell(nFrames, 1);
eccCol = cell(nFrames, 1);
volCol = cell(nFrames, 1);
surfCol = cell(nFrames, 1);

for t = 1:nFrames
    frame = maskImage(:,:,1,t);
    labels = maskInstanceLabels(frame, backgroundLabel, maskName, scoreLabel);
    idxCol{t} = labels(:)';
    [areaCol{t}, minorCol{t}, majorCol{t}, eccCol{t}] = geometryForLabels(frame, labels);
    r = minorCol{t};
    h = majorCol{t} - r;
    volCol{t} = 4*pi*r.^3/3 + pi*r.^2.*h;
    surfCol{t} = 4*pi*r.^2 + 2*pi.*r.*h;
end

varNames = { ...
    ['MaskIdx_' maskLabelSafe], ...
    'Area_Cell', ...
    'LenMinAxis_Cell', ...
    'LenMajAxis_Cell', ...
    'Eccentric_Cell', ...
    'Vol_Cell', ...
    'Surf_Cell'};
tbl = table(idxCol, areaCol, minorCol, majorCol, eccCol, volCol, surfCol, 'VariableNames', varNames);
plotgroup = {'id','Area','Length','Length','Number','Volume','Area'};
defplot = {false,false,false,false,false,false,false};

temp = dataseries(tbl, varNames, ...
    'groupid', groupId, 'parentid', roiobj.id, 'plot', defplot, 'groups', plotgroup);
dataout(cc) = temp;
dataout(cc).class = "processing";
if ~isstruct(dataout(cc).userData)
    dataout(cc).userData = struct();
end
dataout(cc).userData.mask_channel = maskName;
dataout(cc).userData.mask_label = maskLabel;
dataout(cc).userData.mask_background_label = backgroundLabel;
dataout(cc).userData.mask_score_label = scoreLabel;
dataout(cc).userData.mask_index_variable = varNames{1};
dataout(cc).plotGroup = {[] [] [] [] [] unique(plotgroup)};
end

function dataout = computeChannelQuantification(dataout, roiobj, paramout, channelsExtract, channelsName, frames)
im = roiobj.image(:,:,:,frames);
nFrames = size(im, 4);
maskCount = paramout.maskChannelCount;
N = paramout.BrightestPixels;
backgroundOpt = backgroundOptionsFromParams(paramout);

varNames = {};
columns = {};
plotgroup = {};
defplot = {};

for m = 1:maskCount
    maskName = paramout.(sprintf('mask%d_name', m));
    if strcmp(maskName, 'N/A')
        continue;
    end
    maskChannel = roiobj.findChannelID(maskName);
    if isempty(maskChannel)
        continue;
    end
    maskChannel = maskChannel(1);
    maskLabel = paramout.(sprintf('mask%d_label', m));
    backgroundLabel = paramout.(sprintf('mask%d_backgroundLabel', m));
    scoreLabel = paramout.(sprintf('mask%d_scoreLabel', m));
    maskLabelSafe = makeSafeVariableName(maskLabel);

    idxCol = cell(nFrames, 1);
    for t = 1:nFrames
        idxCol{t} = maskInstanceLabels(im(:,:,maskChannel,t), backgroundLabel, maskName, scoreLabel);
    end
    varNames{end+1} = ['MaskIdx_' maskLabelSafe]; %#ok<AGROW>
    columns{end+1} = idxCol; %#ok<AGROW>
    plotgroup{end+1} = 'id'; %#ok<AGROW>
    defplot{end+1} = false; %#ok<AGROW>

    metricByChannel = cell(1, numel(channelsExtract));
    for i = 1:numel(channelsExtract)
        metricByChannel{i} = fluorescenceForMask(im, maskChannel, channelsExtract{i}, N, backgroundLabel, maskName, scoreLabel, backgroundOpt);
        channelName = channelsName{i};
        metricSpecs = { ...
            'Mean', 'Mean', false; ...
            'Tot', 'Total', false; ...
            'MeanTop', 'Mean', false; ...
            'TotTop', 'Total', false; ...
            'Mean_Bckg', 'Mean', false; ...
            'MeanNoBckg', 'Mean', true};
        for s = 1:size(metricSpecs, 1)
            prefix = metricSpecs{s, 1};
            groupPrefix = metricSpecs{s, 2};
            shouldPlot = false;
            varNames{end+1} = localMetricVarName(prefix, channelName, maskLabel); %#ok<AGROW>
            columns{end+1} = metricByChannel{i}.(metricFieldName(prefix)); %#ok<AGROW>
            plotgroup{end+1} = [groupPrefix '_' channelName]; %#ok<AGROW>
            defplot{end+1} = shouldPlot; %#ok<AGROW>
        end
    end

    for i = 1:numel(channelsExtract)
        for j = i+1:numel(channelsExtract)
            ratioCol = cell(nFrames, 1);
            for t = 1:nFrames
                denom = metricByChannel{j}.MeanNoBckg{t};
                numer = metricByChannel{i}.MeanNoBckg{t};
                ratioCol{t} = numer ./ denom;
            end
            ratioName = localRatioMetricVarName(channelsName{i}, channelsName{j}, maskLabel);
            varNames{end+1} = ratioName; %#ok<AGROW>
            columns{end+1} = ratioCol; %#ok<AGROW>
            plotgroup{end+1} = ratioName; %#ok<AGROW>
            defplot{end+1} = false; %#ok<AGROW>
        end
    end
end

if logical(paramout.computeMaskCombinations)
    maskSpecs = validQuantificationMasks(roiobj, paramout);
    if numel(maskSpecs) > 1
        [varNames, columns, plotgroup, defplot] = appendCompositeMaskMetrics( ...
            varNames, columns, plotgroup, defplot, im, maskSpecs, channelsExtract, channelsName, N, backgroundOpt);
    end
end

if isempty(varNames)
    maskNames = cell(1, maskCount);
    for m = 1:maskCount
        maskNames{m} = char(string(paramout.(sprintf('mask%d_name', m))));
    end
    warnOnceLocal('computeMetrics:NoValidQuantificationMask', ...
        ['mask|' strjoin(maskNames, '|')], ...
        ['No valid quantification mask is available for ROI %s. ' ...
         'Requested masks: %s. %s will not be created.'], ...
        roiIdText(roiobj), strjoin(maskNames, ', '), paramout.outputName);
    return;
end

tbl = table(columns{:}, 'VariableNames', varNames);
temp = dataseries(tbl, varNames, ...
    'groupid', paramout.outputName, 'parentid', roiobj.id, 'plot', defplot, 'groups', plotgroup);

pixdata = find(arrayfun(@(x) strcmp(x.groupid, paramout.outputName), dataout));
if ~isempty(pixdata)
    cc = pixdata(1);
else
    if numel(dataout) == 1 && isempty(dataout.data)
        cc = 1;
    else
        cc = numel(dataout) + 1;
    end
end

dataout(cc) = temp;
dataout(cc).class = "processing";
if ~isstruct(dataout(cc).userData)
    dataout(cc).userData = struct();
end
dataout(cc).userData.background = backgroundOpt;
dataout(cc).userData.mask_vector_semantics = 'Each table cell contains one value per foreground mask index listed in the corresponding MaskIdx_* cell.';
dataout(cc).userData.composite_mask_semantics = ['For *_AND_* and *_NOT_* variables, each table cell contains one value per ' ...
    'selected foreground mask index listed in the corresponding MaskIdx_* composite variable. Foreground excludes each mask background label ' ...
    '(auto, 0, or 1), and mask*_scoreLabel can restrict the measured label. AND/NOT composites are computed only when every mask in the pair has a numeric score label.'];
dataout(cc).plotGroup = {[] [] [] [] [] unique(plotgroup)};
end

function maskSpecs = validQuantificationMasks(roiobj, paramout)
maskSpecs = struct('index', {}, 'channel', {}, 'name', {}, 'label', {}, 'labelSafe', {}, 'backgroundLabel', {}, 'scoreLabel', {}, 'hasPreciseScoreLabel', {});
for m = 1:paramout.maskChannelCount
    maskName = paramout.(sprintf('mask%d_name', m));
    if strcmp(maskName, 'N/A')
        continue;
    end
    maskChannel = roiobj.findChannelID(maskName);
    if isempty(maskChannel)
        continue;
    end
    maskLabel = paramout.(sprintf('mask%d_label', m));
    backgroundLabel = paramout.(sprintf('mask%d_backgroundLabel', m));
    scoreLabel = paramout.(sprintf('mask%d_scoreLabel', m));
    maskSpecs(end+1) = struct( ... %#ok<AGROW>
        'index', m, ...
        'channel', maskChannel(1), ...
        'name', maskName, ...
        'label', maskLabel, ...
        'labelSafe', makeSafeVariableName(maskLabel), ...
        'backgroundLabel', backgroundLabel, ...
        'scoreLabel', scoreLabel, ...
        'hasPreciseScoreLabel', hasPreciseScoreLabel(scoreLabel));
end
end

function [varNames, columns, plotgroup, defplot] = appendCompositeMaskMetrics( ...
    varNames, columns, plotgroup, defplot, im, maskSpecs, channelsExtract, channelsName, N, backgroundOpt)

nFrames = size(im, 4);
for a = 1:numel(maskSpecs)
    for b = a+1:numel(maskSpecs)
        if ~maskSpecs(a).hasPreciseScoreLabel || ~maskSpecs(b).hasPreciseScoreLabel
            warnOnceLocal('computeMetrics:CompositeRequiresScoreLabel', ...
                sprintf('%s|%s', maskSpecs(a).name, maskSpecs(b).name), ...
                ['Skipping composite mask metrics for %s and %s because computeMaskCombinations requires a numeric ' ...
                 'mask*_scoreLabel on every mask in the pair. Use all/empty/0 only for non-composite per-label measurements.'], ...
                maskSpecs(a).name, maskSpecs(b).name);
            continue;
        end
        relationSpecs = { ...
            maskSpecs(a), maskSpecs(b), 'AND'; ...
            maskSpecs(a), maskSpecs(b), 'NOT'; ...
            maskSpecs(b), maskSpecs(a), 'NOT'};

        for r = 1:size(relationSpecs, 1)
            baseSpec = relationSpecs{r, 1};
            otherSpec = relationSpecs{r, 2};
            relation = relationSpecs{r, 3};
            relationLabel = compositeRelationLabel(baseSpec.label, relation, otherSpec.label);

            idxCol = cell(nFrames, 1);
            for t = 1:nFrames
                labels = maskInstanceLabels(im(:,:,baseSpec.channel,t), baseSpec.backgroundLabel, baseSpec.name, baseSpec.scoreLabel);
                idxCol{t} = labelsWithNonEmptyCompositeRegion( ...
                    im(:,:,baseSpec.channel,t), im(:,:,otherSpec.channel,t), labels, relation, ...
                    otherSpec.backgroundLabel, otherSpec.name, otherSpec.scoreLabel);
            end

            varNames{end+1} = ['MaskIdx_' makeSafeVariableName(relationLabel)]; %#ok<AGROW>
            columns{end+1} = idxCol; %#ok<AGROW>
            plotgroup{end+1} = 'id'; %#ok<AGROW>
            defplot{end+1} = false; %#ok<AGROW>

            metricByChannel = cell(1, numel(channelsExtract));
            for i = 1:numel(channelsExtract)
                metricByChannel{i} = fluorescenceForCompositeMask( ...
                    im, baseSpec.channel, otherSpec.channel, relation, channelsExtract{i}, N, ...
                    baseSpec.backgroundLabel, baseSpec.name, baseSpec.scoreLabel, ...
                    otherSpec.backgroundLabel, otherSpec.name, otherSpec.scoreLabel, backgroundOpt);
                channelName = channelsName{i};
                metricSpecs = { ...
                    'Mean', 'Mean', false; ...
                    'Tot', 'Total', false; ...
                    'MeanTop', 'Mean', false; ...
                    'TotTop', 'Total', false; ...
                    'Mean_Bckg', 'Mean', false; ...
                    'MeanNoBckg', 'Mean', true};
                for s = 1:size(metricSpecs, 1)
                    prefix = metricSpecs{s, 1};
                    groupPrefix = metricSpecs{s, 2};
                    varNames{end+1} = localMetricVarName(prefix, channelName, relationLabel); %#ok<AGROW>
                    columns{end+1} = metricByChannel{i}.(metricFieldName(prefix)); %#ok<AGROW>
                    plotgroup{end+1} = [groupPrefix '_' channelName]; %#ok<AGROW>
                    defplot{end+1} = false; %#ok<AGROW>
                end
            end

            for i = 1:numel(channelsExtract)
                for j = i+1:numel(channelsExtract)
                    ratioCol = cell(nFrames, 1);
                    for t = 1:nFrames
                        denom = metricByChannel{j}.MeanNoBckg{t};
                        numer = metricByChannel{i}.MeanNoBckg{t};
                        ratioCol{t} = numer ./ denom;
                    end
                    ratioName = localRatioMetricVarName(channelsName{i}, channelsName{j}, relationLabel);
                    varNames{end+1} = ratioName; %#ok<AGROW>
                    columns{end+1} = ratioCol; %#ok<AGROW>
                    plotgroup{end+1} = ratioName; %#ok<AGROW>
                    defplot{end+1} = false; %#ok<AGROW>
                end
            end
        end
    end
end
end

function [imageout, channelNames] = buildCompositeMaskAnnotationChannels(roiobj, paramout, frames)
imageout = [];
channelNames = {};
maskSpecs = validQuantificationMasks(roiobj, paramout);
if numel(maskSpecs) < 2
    return;
end

if isempty(roiobj.image)
    roiobj.load;
end
if isempty(roiobj.image)
    return;
end

imageout = roiobj.image;
nFramesTotal = size(imageout, 4);
frames = normalizeFramesSelection(frames, nFramesTotal);
framePosition = frames(:).';

for a = 1:numel(maskSpecs)
    for b = a+1:numel(maskSpecs)
        if ~maskSpecs(a).hasPreciseScoreLabel || ~maskSpecs(b).hasPreciseScoreLabel
            continue;
        end

        baseSpec = maskSpecs(a);
        otherSpec = maskSpecs(b);
        andName = compositeAnnotationChannelName(baseSpec.label, 'AND', otherSpec.label);
        notName = compositeAnnotationChannelName(baseSpec.label, 'not', otherSpec.label);
        andData = zeros(size(imageout, 1), size(imageout, 2), 1, nFramesTotal, 'uint16');
        notData = zeros(size(imageout, 1), size(imageout, 2), 1, nFramesTotal, 'uint16');

        existingAnd = roiobj.findChannelID(andName, 'exact');
        if ~isempty(existingAnd) && existingAnd(1) <= size(imageout, 3)
            andData(:,:,:,1:nFramesTotal) = uint16(imageout(:,:,existingAnd(1),:));
        end
        existingNot = roiobj.findChannelID(notName, 'exact');
        if ~isempty(existingNot) && existingNot(1) <= size(imageout, 3)
            notData(:,:,:,1:nFramesTotal) = uint16(imageout(:,:,existingNot(1),:));
        end

        for t = framePosition
            baseFrame = imageout(:,:,baseSpec.channel,t);
            otherFrame = imageout(:,:,otherSpec.channel,t);
            otherForeground = foregroundMask(otherFrame, otherSpec.backgroundLabel, otherSpec.name, otherSpec.scoreLabel);
            baseLabels = maskInstanceLabels(baseFrame, baseSpec.backgroundLabel, baseSpec.name, baseSpec.scoreLabel);

            andFrame = zeros(size(baseFrame), 'uint16');
            notFrame = zeros(size(baseFrame), 'uint16');
            for iLabel = 1:numel(baseLabels)
                basePix = baseFrame == baseLabels(iLabel);
                andFrame(basePix & otherForeground) = 1;
                notFrame(basePix & ~otherForeground) = 1;
            end
            andData(:,:,1,t) = andFrame;
            notData(:,:,1,t) = notFrame;
        end

        [imageout, roiobj] = upsertCompositeAnnotationChannel(roiobj, imageout, andData, andName);
        [imageout, roiobj] = upsertCompositeAnnotationChannel(roiobj, imageout, notData, notName);
        channelNames = [channelNames, {andName, notName}]; %#ok<AGROW>
    end
end
channelNames = unique(channelNames, 'stable');
end

function [imageout, roiobj] = upsertCompositeAnnotationChannel(roiobj, imageout, data, channelName)
idx = roiobj.findChannelID(channelName, 'exact');
if isempty(idx)
    roiobj.image = imageout;
    roiobj.addChannel(data, channelName, [1 1 1], [0 0 0]);
    imageout = roiobj.image;
else
    imageout(:,:,idx(1),:) = uint16(data);
    roiobj.image = imageout;
    displayIndex = logicalChannelIndex(roiobj, channelName);
    if ~isempty(displayIndex)
        roiobj.display.intensity(displayIndex,:) = [0 0 0];
        roiobj.display.indexed(displayIndex) = 1;
        roiobj.display.contour(displayIndex) = 1;
        roiobj.display.alpha(displayIndex) = 0.35;
        roiobj.display.width(displayIndex) = 1.5;
    end
end
end

function idx = logicalChannelIndex(roiobj, channelName)
idx = [];
try
    names = roiobj.display.channel;
    if ischar(names) || isstring(names)
        names = cellstr(names);
    end
    idx = find(strcmp(names, channelName), 1);
catch
    idx = [];
end
end

function name = compositeAnnotationChannelName(baseLabel, relation, otherLabel)
name = sprintf('mask_%s_%s_%s', channelNameToken(baseLabel), char(string(relation)), channelNameToken(otherLabel));
end

function token = channelNameToken(label)
token = lower(makeSafeVariableName(label));
end

function metrics = fluorescenceForCompositeMask(im, baseMaskChannel, otherMaskChannel, relation, scoreChannels, N, ...
    baseBackgroundLabel, baseMaskName, baseScoreLabel, otherBackgroundLabel, otherMaskName, otherScoreLabel, backgroundOpt)
nFrames = size(im, 4);
fields = {'Mean','Tot','MeanTop','TotTop','Mean_Bckg','MeanNoBckg'};
for f = 1:numel(fields)
    metrics.(fields{f}) = cell(nFrames, 1);
end

for t = 1:nFrames
    baseFrame = im(:,:,baseMaskChannel,t);
    otherFrame = im(:,:,otherMaskChannel,t);
    labels = maskInstanceLabels(baseFrame, baseBackgroundLabel, baseMaskName, baseScoreLabel);
    otherForeground = foregroundMask(otherFrame, otherBackgroundLabel, otherMaskName, otherScoreLabel);
    % Background must not depend on the specific scored label; otherwise
    % non-target cells leak into Mean_Bckg when scoreLabel tracks one cell.
    baseAllForeground = foregroundMask(baseFrame, baseBackgroundLabel, baseMaskName, 'all');
    otherAllForeground = foregroundMask(otherFrame, otherBackgroundLabel, otherMaskName, 'all');
    backgroundMean = backgroundMeanForPixels(im, scoreChannels, t, ...
        baseAllForeground | otherAllForeground, backgroundOpt);

    validLabels = labelsWithNonEmptyCompositeRegion(baseFrame, otherFrame, labels, relation, otherBackgroundLabel, otherMaskName, otherScoreLabel);
    meanVals = NaN(1, numel(validLabels));
    totalVals = NaN(1, numel(validLabels));
    meanTopVals = NaN(1, numel(validLabels));
    totalTopVals = NaN(1, numel(validLabels));
    bckgVals = repmat(backgroundMean, 1, numel(validLabels));
    diffVals = NaN(1, numel(validLabels));

    for i = 1:numel(validLabels)
        pix = compositeRegion(baseFrame == validLabels(i), otherForeground, relation);
        values = pixelValuesForChannels(im, scoreChannels, t, pix);
        values = values(:);
        meanVals(i) = mean(values, 'omitnan');
        totalVals(i) = sum(values, 'omitnan');
        meanTopVals(i) = meanTopNValues(values, N);
        totalTopVals(i) = sumTopNValues(values, N);
        diffVals(i) = meanVals(i) - backgroundMean;
    end

    metrics.Mean{t} = meanVals;
    metrics.Tot{t} = totalVals;
    metrics.MeanTop{t} = meanTopVals;
    metrics.TotTop{t} = totalTopVals;
    metrics.Mean_Bckg{t} = bckgVals;
    metrics.MeanNoBckg{t} = diffVals;
end
end

function labelsOut = labelsWithNonEmptyCompositeRegion(baseFrame, otherFrame, labels, relation, otherBackgroundLabel, otherMaskName, otherScoreLabel)
labelsOut = [];
otherMask = foregroundMask(otherFrame, otherBackgroundLabel, otherMaskName, otherScoreLabel);
for i = 1:numel(labels)
    pix = compositeRegion(baseFrame == labels(i), otherMask, relation);
    if any(pix(:))
        labelsOut(end+1) = labels(i); %#ok<AGROW>
    end
end
end

function pix = compositeRegion(baseMask, otherMask, relation)
switch upper(char(string(relation)))
    case 'AND'
        pix = baseMask & otherMask;
    case 'NOT'
        pix = baseMask & ~otherMask;
    otherwise
        error('computeMetrics:UnknownCompositeMaskRelation', 'Unknown composite mask relation "%s".', char(string(relation)));
end
end

function label = compositeRelationLabel(baseLabel, relation, otherLabel)
switch upper(char(string(relation)))
    case 'AND'
        label = sprintf('%s_AND_%s', char(string(baseLabel)), char(string(otherLabel)));
    case 'NOT'
        label = sprintf('%s_NOT_%s', char(string(baseLabel)), char(string(otherLabel)));
    otherwise
        label = sprintf('%s_%s_%s', char(string(baseLabel)), char(string(relation)), char(string(otherLabel)));
end
end

function warnOnceLocal(id, key, varargin)
persistent warned
if isempty(warned)
    warned = containers.Map('KeyType', 'char', 'ValueType', 'logical');
end
mapKey = [char(string(id)) '|' char(string(key))];
if isKey(warned, mapKey)
    return;
end
warned(mapKey) = true;
warning(id, varargin{:});
end

function metrics = fluorescenceForMask(im, maskChannel, scoreChannels, N, backgroundLabel, maskName, scoreLabel, backgroundOpt)
nFrames = size(im, 4);
fields = {'Mean','Tot','MeanTop','TotTop','Mean_Bckg','MeanNoBckg'};
for f = 1:numel(fields)
    metrics.(fields{f}) = cell(nFrames, 1);
end

for t = 1:nFrames
    maskFrame = im(:,:,maskChannel,t);
    labels = maskInstanceLabels(maskFrame, backgroundLabel, maskName, scoreLabel);
    % Background must exclude every segmented object, not only the scored
    % label, or disappearing neighboring cells create artificial jumps.
    foregroundPix = foregroundMask(maskFrame, backgroundLabel, maskName, 'all');
    backgroundMean = backgroundMeanForPixels(im, scoreChannels, t, foregroundPix, backgroundOpt);

    meanVals = NaN(1, numel(labels));
    totalVals = NaN(1, numel(labels));
    meanTopVals = NaN(1, numel(labels));
    totalTopVals = NaN(1, numel(labels));
    bckgVals = repmat(backgroundMean, 1, numel(labels));
    diffVals = NaN(1, numel(labels));

    for i = 1:numel(labels)
        pix = maskFrame == labels(i);
        values = pixelValuesForChannels(im, scoreChannels, t, pix);
        values = values(:);
        meanVals(i) = mean(values, 'omitnan');
        totalVals(i) = sum(values, 'omitnan');
        meanTopVals(i) = meanTopNValues(values, N);
        totalTopVals(i) = sumTopNValues(values, N);
        diffVals(i) = meanVals(i) - backgroundMean;
    end

    metrics.Mean{t} = meanVals;
    metrics.Tot{t} = totalVals;
    metrics.MeanTop{t} = meanTopVals;
    metrics.TotTop{t} = totalTopVals;
    metrics.Mean_Bckg{t} = bckgVals;
    metrics.MeanNoBckg{t} = diffVals;
end
end

function values = pixelValuesForChannels(im, scoreChannels, t, pix)
values = [];
for c = 1:numel(scoreChannels)
    frame = im(:,:,scoreChannels(c),t);
    values = [values; frame(pix)]; %#ok<AGROW>
end
values = double(values);
end

function opt = backgroundOptionsFromParams(paramout)
opt = struct( ...
    'method', normalizeBackgroundMethod(paramout.backgroundMethod), ...
    'percentile', min(100, max(0, numericScalar(paramout.backgroundPercentile, 20))), ...
    'dilatePx', max(0, round(numericScalar(paramout.backgroundDilatePx, 0))));
end

function method = normalizeBackgroundMethod(value)
method = lower(strtrim(selectedText(value, 'mean')));
switch method
    case {'mean','median','percentile'}
        return;
    otherwise
        method = 'mean';
end
end

function value = backgroundMeanForPixels(im, scoreChannels, t, excludedPix, opt)
if opt.dilatePx > 0
    excludedPix = dilateBinaryMask(excludedPix, opt.dilatePx);
end
backgroundPix = ~excludedPix;
values = pixelValuesForChannels(im, scoreChannels, t, backgroundPix);
values = values(:);
if isempty(values) || all(isnan(values))
    value = NaN;
    return;
end
switch opt.method
    case 'median'
        value = median(values, 'omitnan');
    case 'percentile'
        value = percentileNoNaN(values, opt.percentile);
    otherwise
        value = mean(values, 'omitnan');
end
end

function pix = dilateBinaryMask(pix, radiusPx)
radiusPx = max(0, round(radiusPx));
if radiusPx == 0 || ~any(pix(:))
    return;
end
kernel = true(2 * radiusPx + 1);
pix = conv2(double(pix), double(kernel), 'same') > 0;
end

function value = percentileNoNaN(values, pct)
values = sort(values(~isnan(values)));
if isempty(values)
    value = NaN;
    return;
end
if numel(values) == 1
    value = values(1);
    return;
end
pct = min(100, max(0, pct));
pos = 1 + (numel(values) - 1) * pct / 100;
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    value = values(lo);
else
    value = values(lo) + (pos - lo) * (values(hi) - values(lo));
end
end

function labels = maskInstanceLabels(maskFrame, backgroundLabel, maskName, scoreLabel)
if nargin < 4
    scoreLabel = 'all';
end
labels = unique(maskFrame(:));
labels = labels(~isnan(double(labels)));
backgroundLabels = resolveBackgroundLabels(maskFrame, backgroundLabel, maskName);
if ~isempty(backgroundLabels)
    labels = labels(~ismember(double(labels), double(backgroundLabels(:))));
end
scoreLabel = normalizeScoreLabelParam(scoreLabel);
if hasPreciseScoreLabel(scoreLabel)
    targetLabel = str2double(char(string(scoreLabel)));
    labels = labels(double(labels) == targetLabel);
end
labels = double(labels(:)');
end

function pix = foregroundMask(maskFrame, backgroundLabel, maskName, scoreLabel)
if nargin < 4
    scoreLabel = 'all';
end
labels = maskInstanceLabels(maskFrame, backgroundLabel, maskName, scoreLabel);
if isempty(labels)
    pix = false(size(maskFrame));
else
    pix = ismember(double(maskFrame), labels);
end
end

function backgroundLabels = resolveBackgroundLabels(maskFrame, backgroundLabel, maskName)
backgroundLabel = normalizeBackgroundLabelParam(backgroundLabel);
switch lower(char(string(backgroundLabel)))
    case '0'
        backgroundLabels = 0;
    case '1'
        backgroundLabels = 1;
    otherwise
        vals = unique(double(maskFrame(:)));
        vals = vals(isfinite(vals));
        if any(vals == 0)
            backgroundLabels = 0;
        elseif any(vals == 1) && looksLikePixelClassifierMask(maskName, maskFrame)
            backgroundLabels = 1;
        else
            backgroundLabels = [];
        end
end
end

function value = normalizeBackgroundLabelParam(value)
value = selectedText(value, 'auto');
value = lower(strtrim(char(string(value))));
switch value
    case {'0','zero'}
        value = '0';
    case {'1','one'}
        value = '1';
    case {'auto',''}
        value = 'auto';
    otherwise
        numericValue = str2double(value);
        if isfinite(numericValue) && ismember(numericValue, [0 1])
            value = char(string(round(numericValue)));
        else
            value = 'auto';
        end
end
end

function value = normalizeScoreLabelParam(value)
value = selectedText(value, 'all');
value = lower(strtrim(char(string(value))));
switch value
    case {'','0','all','any','each'}
        value = 'all';
    otherwise
        numericValue = str2double(value);
        if isfinite(numericValue) && isscalar(numericValue) && numericValue > 0
            value = char(string(round(numericValue)));
        else
            value = 'all';
        end
end
end

function tf = hasPreciseScoreLabel(value)
value = normalizeScoreLabelParam(value);
numericValue = str2double(char(string(value)));
tf = isfinite(numericValue) && isscalar(numericValue) && numericValue > 0;
end

function tf = looksLikePixelClassifierMask(maskName, maskFrame)
name = lower(char(string(maskName)));
tf = startsWith(name, 'results_') || contains(name, 'classif') || contains(name, 'classification') || ...
    contains(name, 'unet') || contains(name, 'u-net') || contains(name, 'deeplab') || ...
    contains(name, 'seg') || contains(name, 'mask');
if tf
    return;
end

vals = unique(double(maskFrame(:)));
vals = vals(isfinite(vals));
if any(vals == 0) || ~any(vals == 1) || numel(vals) < 2
    tf = false;
    return;
end

labelOneFraction = nnz(double(maskFrame(:)) == 1) / max(1, numel(maskFrame));
border = [maskFrame(1,:) maskFrame(end,:) maskFrame(:,1).' maskFrame(:,end).'];
borderOneFraction = nnz(double(border(:)) == 1) / max(1, numel(border));
tf = labelOneFraction >= 0.5 && borderOneFraction >= 0.5;
end

function [area, minorAxis, majorAxis, eccentricity] = geometryForLabels(maskFrame, labels)
area = NaN(1, numel(labels));
minorAxis = NaN(1, numel(labels));
majorAxis = NaN(1, numel(labels));
eccentricity = NaN(1, numel(labels));
for i = 1:numel(labels)
    stats = regionprops(maskFrame == labels(i), 'Area', 'MajorAxisLength', 'MinorAxisLength', 'Eccentricity');
    if isempty(stats)
        continue;
    end
    area(i) = sum([stats.Area]);
    majorAxis(i) = max([stats.MajorAxisLength]);
    minorAxis(i) = max([stats.MinorAxisLength]);
    eccentricity(i) = mean([stats.Eccentricity]);
end
end

function field = metricFieldName(prefix)
switch prefix
    case 'Mean_Bckg'
        field = 'Mean_Bckg';
    case 'MeanNoBckg'
        field = 'MeanNoBckg';
    otherwise
        field = prefix;
end
end

function n = countParam(params, keys, defaultValue, minValue, maxValue)
n = defaultValue;
for i = 1:numel(keys)
    key = keys{i};
    if isfield(params, key) && ~isempty(params.(key))
        n = numericScalar(params.(key), defaultValue);
        break;
    end
end
n = min(maxValue, max(minValue, round(n)));
end

function n = inferIndexedCount(params, pattern, defaultValue)
n = defaultValue;
if ~isstruct(params)
    return;
end
names = fieldnames(params);
for i = 1:numel(names)
    tokens = regexp(names{i}, pattern, 'tokens', 'once');
    if ~isempty(tokens)
        n = max(n, str2double(tokens{1}));
    end
end
end

function out = selectedText(value, defaultValue)
out = defaultValue;
try
    if iscell(value)
        value = value{end};
    end
    out = char(string(value));
    out = strtrim(out);
    if isempty(out)
        out = defaultValue;
    end
catch
    out = defaultValue;
end
end

function tf = isLegacyAutoOutputName(value)
txt = lower(strtrim(char(string(value))));
tf = ~isempty(regexp(txt, '^processor_computemetrics(_\d+)?$', 'once'));
end

function out = numericScalar(value, defaultValue)
out = defaultValue;
try
    if iscell(value)
        value = value{end};
    end
    if ischar(value) || (isstring(value) && isscalar(value))
        out = str2double(strtrim(char(string(value))));
    else
        out = double(value);
    end
catch
    out = defaultValue;
end
if isempty(out) || ~isscalar(out) || ~isfinite(out)
    out = defaultValue;
end
end

function out = logicalScalar(value, defaultValue)
out = defaultValue;
try
    if iscell(value)
        value = value{end};
    end
    if ischar(value) || isstring(value)
        txt = lower(strtrim(char(string(value))));
        if any(strcmp(txt, {'true','1','yes','on'}))
            out = true;
            return;
        elseif any(strcmp(txt, {'false','0','no','off'}))
            out = false;
            return;
        end
    end
    value = logical(value);
catch
    value = defaultValue;
end
if isempty(value) || ~isscalar(value)
    out = defaultValue;
else
    out = logical(value);
end
end

function label = defaultMaskLabel(i)
defaults = {'cyto','nucleus'};
if i <= numel(defaults)
    label = defaults{i};
else
    label = sprintf('mask%d', i);
end
end

function txt = roiIdText(roiobj)
txt = '<unknown>';
try
    txt = char(string(roiobj.id));
catch
end
end

function topN = meanTopNValues(x, N)
x = x(~isnan(x));
if isempty(x)
    topN = NaN;
    return;
end
sortedX = sort(x, 'descend');
topN = mean(sortedX(1:min(N,end)));
end

function topN = sumTopNValues(x, N)
x = x(~isnan(x));
if isempty(x)
    topN = NaN;
    return;
end
sortedX = sort(x, 'descend');
topN = sum(sortedX(1:min(N,end)));
end

function out = localMetricVarName(prefix, channelName, maskLabel)
out = makeSafeVariableName(sprintf('%s_%s_%s', prefix, channelName, maskLabel));
end

function out = localRatioMetricVarName(channelName1, channelName2, maskLabel)
out = makeSafeVariableName(sprintf('Ratio_Mean_NoBckg_%s_%s_%s', channelName1, channelName2, maskLabel));
end
