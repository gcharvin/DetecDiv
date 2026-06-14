function out = classify(roiobj, classif, ctx)
% deeplab_pixel_classification.classify
% Package entry point for DeepLab v3+ pixel classification.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end

out = deeplab_pixel_classification.utils.outInitSafe('deeplab_pixel_classification.classify');

classifier = [];
if isfield(ctx, 'exec') && isstruct(ctx.exec) && isfield(ctx.exec, 'classifier')
    classifier = ctx.exec.classifier;
end

frames = [];
channels = [];
gpu = false;
outputName = '';
probabilityOutputName = '';

if isfield(ctx, 'sel') && isstruct(ctx.sel)
    if isfield(ctx.sel, 'frames'), frames = ctx.sel.frames; end
    if isfield(ctx.sel, 'channels'), channels = ctx.sel.channels; end
end
if isfield(ctx, 'exec') && isstruct(ctx.exec) && isfield(ctx.exec, 'gpu')
    gpu = logical(ctx.exec.gpu);
end
if isfield(ctx, 'names') && isstruct(ctx.names) && isfield(ctx.names, 'outputName') && ~isempty(ctx.names.outputName)
    outputName = char(string(ctx.names.outputName));
elseif isfield(ctx, 'params') && isstruct(ctx.params) && isfield(ctx.params, 'outputName') && ~isempty(ctx.params.outputName)
    outputName = char(string(ctx.params.outputName));
end
if isfield(ctx, 'params') && isstruct(ctx.params) && ...
        isfield(ctx.params, 'probabilityOutputName') && ~isempty(ctx.params.probabilityOutputName)
    probabilityOutputName = char(string(ctx.params.probabilityOutputName));
end

classif = applyExecutionParams(classif, ctx, outputName);

if isempty(classifier)
    classifier = classif.loadClassifier('force');
end

[data, image] = classifyDeepLabPixel(roiobj, classif, classifier, frames, channels, gpu, outputName, probabilityOutputName);

out.data = data;
out.image = image;
out.patch = [];
out.status = "OK";
end

function [data, image] = classifyDeepLabPixel(roiobj, classif, classifier, frames, channels, gpu, outputName, probabilityOutputName)
if isempty(classifier)
    error('deeplab_pixel_classification:MissingClassifier', 'No DeepLab classifier network is available.');
end
if isempty(outputName)
    outputName = char(string(classif.strid));
end
if isempty(probabilityOutputName)
    probabilityOutputName = [outputName '_prob'];
end
[segmentationMode, probabilityThreshold] = resolveSegmentationParams(classif);

if isempty(roiobj.image)
    roiobj.load;
end
image = roiobj.image;
if isempty(image)
    error('deeplab_pixel_classification:EmptyROI', 'ROI image is empty.');
end

data = roiobj.data;
if isempty(data)
    roiobj.data = dataseries;
    data = roiobj.data;
end

pix = roiobj.findChannelID(normalizeChannelArg(channels));
if iscell(pix)
    pix = cell2mat(pix);
end
if isempty(pix)
    error('deeplab_pixel_classification:InputChannelNotFound', 'Input channel not found.');
end

if isempty(frames)
    frames = 1:size(image, 4);
else
    frames = intersect(double(frames(:))', 1:size(image, 4));
end
if isempty(frames)
    return;
end

outputType = 'segmentation';
try
    if isprop(classif, 'outputType') && ~isempty(classif.outputType)
        outputType = normalizeOutputType(classif.outputType);
    end
catch
end
wantSegmentation = any(strcmp(outputType, {'segmentation','both'}));
wantProbability = any(strcmp(outputType, {'proba','probability','both'}));

net = classifier;
inputSize = [];
try
    inputSize = net.Layers(1).InputSize(1:2);
catch
end

nY = size(image, 1);
nX = size(image, 2);
nF = numel(frames);
inputStack = zeros(nY, nX, 3, nF, 'uint8');
for i = 1:nF
    frameIdx = frames(i);
    tmp = roiobj.preProcessROIData(pix, frameIdx, []);
    if size(tmp, 3) == 1
        tmp = repmat(tmp, [1 1 3]);
    elseif size(tmp, 3) > 3
        tmp = tmp(:, :, 1:3);
    end
    inputStack(:, :, :, i) = uint8(max(0, min(255, round(255 * mat2gray(tmp)))));
end
execEnv = "cpu";
if gpu
    execEnv = "gpu";
end
[labelIdx, scores] = segmentDeepLabFrames(inputStack, net, execEnv, inputSize, [nY nX]);
foregroundProbability = foregroundProbabilityFromScores(scores, labelIdx);
if strcmp(segmentationMode, 'threshold_foreground')
    labelIdx = applyForegroundThreshold(labelIdx, foregroundProbability, probabilityThreshold);
end

if wantSegmentation
    segChannel = ensureChannel(roiobj, ['results_' outputName], 'uint16', [1 1 1], [0 0 0], true);
    image = roiobj.image;
    image(:, :, segChannel, frames) = uint16(labelIdx);
    roiobj.image = image;
end

if wantProbability
    probChannel = ensureChannel(roiobj, probabilityOutputName, 'uint16', [1 1 1], [1 1 1], false);
    image = roiobj.image;
    prob = foregroundProbability;
    prob = min(max(prob, 0), 1);
    image(:, :, probChannel, frames) = uint16(round(65535 * prob));
end
end

function [segmentationMode, probabilityThreshold] = resolveSegmentationParams(classif)
segmentationMode = 'max_probability';
probabilityThreshold = 0.9;
try
    if isprop(classif, 'executionParam') && isstruct(classif.executionParam)
        p = classif.executionParam;
        if isfield(p, 'segmentationMode') && ~isempty(p.segmentationMode)
            segmentationMode = normalizeSegmentationMode(p.segmentationMode);
        end
        if isfield(p, 'probabilityThreshold') && ~isempty(p.probabilityThreshold)
            probabilityThreshold = normalizeProbabilityThreshold(p.probabilityThreshold);
        end
    end
catch
end
end

function prob = foregroundProbabilityFromScores(scores, labelIdx)
if ndims(scores) >= 4 && size(scores, 3) >= 2
    prob = max(scores(:, :, 2:end, :), [], 3);
else
    prob = reshape(scores, size(scores, 1), size(scores, 2), 1, size(scores, 4));
    prob(labelIdx <= 1) = 0;
end
end

function labelIdx = applyForegroundThreshold(labelIdx, foregroundProbability, threshold)
labelIdx(foregroundProbability < threshold) = 1;
end

function [labelIdx, scores] = segmentDeepLabFrames(inputStack, net, execEnv, inputSize, targetSize)
nF = size(inputStack, 4);
[labelIdx, scores] = tryBatchDeepLabFrames(inputStack, net, execEnv, inputSize, targetSize, nF);
if ~isempty(labelIdx)
    return;
end

labelIdx = zeros(targetSize(1), targetSize(2), 1, nF, 'uint16');
scores = [];
for i = 1:nF
    frameInput = inputStack(:, :, :, i);
    if ~isempty(inputSize) && (size(frameInput, 1) ~= inputSize(1) || size(frameInput, 2) ~= inputSize(2))
        frameInput = imresize(frameInput, inputSize);
    end
    [frameLabels, frameScores] = semanticseg(frameInput, net, 'ExecutionEnvironment', execEnv);
    labelIdx(:, :, 1, i) = labelsToIndex(frameLabels, net, targetSize);
    frameScores = normalizeScoreFrame(frameScores, targetSize);
    if isempty(scores)
        scores = zeros(targetSize(1), targetSize(2), size(frameScores, 3), nF, 'like', frameScores);
    end
    scores(:, :, :, i) = frameScores;
end
end

function [labelIdx, scores] = tryBatchDeepLabFrames(inputStack, net, execEnv, inputSize, targetSize, nF)
labelIdx = [];
scores = [];
if nF <= 1
    return;
end
try
    if ~isempty(inputSize) && (size(inputStack, 1) ~= inputSize(1) || size(inputStack, 2) ~= inputSize(2))
        inputForNet = imresize(inputStack, inputSize);
    else
        inputForNet = inputStack;
    end
    [batchLabels, batchScores] = semanticseg(inputForNet, net, 'ExecutionEnvironment', execEnv);
    if ndims(batchLabels) < 3 || size(batchLabels, 3) ~= nF
        return;
    end
    labelIdx = zeros(targetSize(1), targetSize(2), 1, nF, 'uint16');
    for i = 1:nF
        labelIdx(:, :, 1, i) = labelsToIndex(batchLabels(:, :, i), net, targetSize);
    end
    scores = normalizeBatchScores(batchScores, targetSize, nF);
catch
    labelIdx = [];
    scores = [];
end
end

function scores = normalizeBatchScores(batchScores, targetSize, nF)
if ndims(batchScores) < 4 && size(batchScores, 3) == nF
    scores = zeros(targetSize(1), targetSize(2), 1, nF, 'like', batchScores);
    for i = 1:nF
        frameScore = batchScores(:, :, i);
        if size(frameScore, 1) ~= targetSize(1) || size(frameScore, 2) ~= targetSize(2)
            frameScore = imresize(frameScore, targetSize);
        end
        scores(:, :, 1, i) = frameScore;
    end
    return;
end
if size(batchScores, 1) ~= targetSize(1) || size(batchScores, 2) ~= targetSize(2)
    batchScores = resizeScoreStack(batchScores, targetSize);
end
scores = batchScores;
end

function idx = labelsToIndex(labels, net, targetSize)
classNames = [];
try
    classNames = string(net.Layers(end).Classes);
catch
end
if isempty(classNames)
    classNames = string(categories(labels));
end
labelNames = string(labels);
idx = zeros(size(labelNames), 'uint16');
for k = 1:numel(classNames)
    idx(labelNames == classNames(k)) = uint16(k);
end
idx(idx == 0) = 1;
if size(idx, 1) ~= targetSize(1) || size(idx, 2) ~= targetSize(2)
    idx = uint16(imresize(idx, targetSize, 'nearest'));
end
end

function frameScores = normalizeScoreFrame(frameScores, targetSize)
if ndims(frameScores) < 3
    frameScores = reshape(frameScores, size(frameScores, 1), size(frameScores, 2), 1);
elseif ndims(frameScores) > 3
    frameScores = frameScores(:, :, :, 1);
end
if size(frameScores, 1) ~= targetSize(1) || size(frameScores, 2) ~= targetSize(2)
    frameScores = resizeScoreStack(frameScores, targetSize);
end
end

function scoresOut = resizeScoreStack(scores, targetSize)
nC = size(scores, 3);
nF = size(scores, 4);
scoresOut = zeros(targetSize(1), targetSize(2), nC, nF, 'like', scores);
for f = 1:nF
    for c = 1:nC
        scoresOut(:, :, c, f) = imresize(scores(:, :, c, f), targetSize);
    end
end
end

function pixid = ensureChannel(roiobj, channelName, typeName, rgb, intensity, indexedFlag)
pixid = roiobj.findChannelID(channelName);
if iscell(pixid)
    pixid = cell2mat(pixid);
end
if isempty(pixid)
    base = zeros(size(roiobj.image, 1), size(roiobj.image, 2), 1, size(roiobj.image, 4), typeName);
    roiobj.addChannel(base, channelName, rgb, intensity);
    pixid = roiobj.findChannelID(channelName);
    if iscell(pixid)
        pixid = cell2mat(pixid);
    end
end
if isempty(pixid)
    error('deeplab_pixel_classification:OutputChannelCreateFailed', ...
        'Unable to create output channel "%s".', channelName);
end
configureDisplay(roiobj, pixid(1), rgb, intensity, indexedFlag);
pixid = pixid(1);
end

function configureDisplay(roiobj, pixid, rgb, intensity, indexedFlag)
try
    if ~isprop(roiobj, 'channelid') || isempty(roiobj.channelid) || ~isprop(roiobj, 'display') || ~isstruct(roiobj.display)
        return;
    end
    logIdx = roiobj.channelid(pixid);
    nLog = max(double(logIdx), numel(roiobj.display.channel));
    roiobj.display = ensureDisplayVector(roiobj.display, 'selectedchannel', nLog, 0);
    roiobj.display = ensureDisplayVector(roiobj.display, 'indexed', nLog, 0);
    roiobj.display = ensureDisplayVector(roiobj.display, 'alpha', nLog, 1);
    roiobj.display = ensureDisplayVector(roiobj.display, 'contour', nLog, 0);
    roiobj.display = ensureDisplayVector(roiobj.display, 'width', nLog, 0);
    roiobj.display = ensureDisplayMatrix(roiobj.display, 'rgb', nLog, [1 1 1]);
    roiobj.display = ensureDisplayMatrix(roiobj.display, 'intensity', nLog, [1 1 1]);
    roiobj.display.selectedchannel(logIdx) = true;
    roiobj.display.indexed(logIdx) = logical(indexedFlag);
    roiobj.display.rgb(logIdx, :) = rgb;
    roiobj.display.intensity(logIdx, :) = intensity;
    if indexedFlag
        roiobj.display.contour(logIdx) = 1;
        roiobj.display.alpha(logIdx) = 0.35;
        roiobj.display.width(logIdx) = 1.5;
    end
catch
end
end

function display = ensureDisplayVector(display, fieldName, nRows, defaultValue)
if ~isfield(display, fieldName) || isempty(display.(fieldName))
    display.(fieldName) = repmat(defaultValue, 1, nRows);
elseif numel(display.(fieldName)) < nRows
    display.(fieldName)(end+1:nRows) = defaultValue;
end
end

function display = ensureDisplayMatrix(display, fieldName, nRows, defaultRow)
if ~isfield(display, fieldName) || isempty(display.(fieldName))
    display.(fieldName) = repmat(defaultRow, nRows, 1);
elseif size(display.(fieldName), 1) < nRows
    display.(fieldName)(end+1:nRows, :) = repmat(defaultRow, nRows - size(display.(fieldName), 1), 1);
end
end

function classif = applyExecutionParams(classif, ctx, outputName)
if ~isempty(outputName)
    try
        classif.strid = outputName;
    catch
    end
end

outputType = '';
if isfield(ctx, 'params') && isstruct(ctx.params)
    if isfield(ctx.params, 'outputType') && ~isempty(ctx.params.outputType)
        outputType = ctx.params.outputType;
    elseif isfield(ctx.params, 'outputMode') && ~isempty(ctx.params.outputMode)
        outputType = ctx.params.outputMode;
    end
end

if ~isempty(outputType)
    try
        classif.outputType = normalizeOutputType(outputType);
    catch
    end
elseif isempty(classif.outputType)
    try
        classif.outputType = 'segmentation';
    catch
    end
end

if isfield(ctx, 'params') && isstruct(ctx.params)
    if isfield(ctx.params, 'outputFun') && ~isempty(ctx.params.outputFun)
        try
            classif.outputFun = char(string(ctx.params.outputFun));
        catch
        end
    end
    if isfield(ctx.params, 'outputArg') && ~isempty(ctx.params.outputArg)
        try
            classif.outputArg = ctx.params.outputArg;
        catch
        end
    elseif isfield(ctx.params, 'postprocessThreshold') && ~isempty(ctx.params.postprocessThreshold)
        try
            classif.outputArg = {'threshold', num2str(ctx.params.postprocessThreshold)};
        catch
        end
    end
    if isfield(ctx.params, 'segmentationMode') && ~isempty(ctx.params.segmentationMode)
        try
            classif.executionParam.segmentationMode = normalizeSegmentationMode(ctx.params.segmentationMode);
        catch
        end
    end
    if isfield(ctx.params, 'probabilityThreshold') && ~isempty(ctx.params.probabilityThreshold)
        try
            classif.executionParam.probabilityThreshold = normalizeProbabilityThreshold(ctx.params.probabilityThreshold);
        catch
        end
    end
end
end

function mode = normalizeSegmentationMode(value)
mode = lower(strtrim(char(string(value))));
mode = strrep(mode, '-', '_');
mode = strrep(mode, ' ', '_');
switch mode
    case {'threshold','thresholded','threshold_foreground','probability_threshold','proba_threshold'}
        mode = 'threshold_foreground';
    otherwise
        mode = 'max_probability';
end
end

function threshold = normalizeProbabilityThreshold(value)
threshold = 0.9;
try
    threshold = double(value);
    threshold = threshold(1);
catch
end
if ~isfinite(threshold)
    threshold = 0.9;
end
threshold = max(0, min(1, threshold));
end

function outputType = normalizeOutputType(value)
outputType = lower(strtrim(char(string(value))));
outputType = strrep(outputType, '-', '_');
outputType = strrep(outputType, ' ', '_');
switch outputType
    case {'probability','probabilities','probability_map','proba'}
        outputType = 'probability';
    case {'seg','mask','masks','semantic','semantic_segmentation'}
        outputType = 'segmentation';
    case {'both','segmentation_and_probability','all'}
        outputType = 'both';
    otherwise
        if isempty(outputType)
            outputType = 'segmentation';
        end
end
end

function channel = normalizeChannelArg(channels)
if isstring(channels)
    channel = cellstr(channels);
elseif ischar(channels)
    channel = {channels};
elseif iscell(channels)
    channel = channels;
else
    channel = channels;
end
end
