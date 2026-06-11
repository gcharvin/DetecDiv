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

classif = applyExecutionParams(classif, ctx, outputName);

args = {};
if ~isempty(frames)
    args = [args, {'Frames', frames}]; %#ok<AGROW>
end
if ~isempty(channels)
    args = [args, {'Channel', normalizeChannelArg(channels)}]; %#ok<AGROW>
end
args = [args, {'Exec', double(gpu)}];

if isempty(classifier)
    classifier = classif.loadClassifier('force');
end

[data, image] = classifyPixelDeeplabNetFun(roiobj, classif, classifier, args{:});

out.data = data;
out.image = image;
out.patch = struct();
out.status = "OK";
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
end
end

function outputType = normalizeOutputType(value)
outputType = lower(strtrim(char(string(value))));
outputType = strrep(outputType, '-', '_');
outputType = strrep(outputType, ' ', '_');
switch outputType
    case {'probability','probabilities','probability_map','proba'}
        outputType = 'proba';
    case {'seg','mask','masks','semantic','semantic_segmentation'}
        outputType = 'segmentation';
    case {'post','postprocess','postprocessing'}
        outputType = 'postprocessing';
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
