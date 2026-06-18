function out = train(classif, ctx)
% deeplab_pixel_classification.train
% Package entry point for DeepLab v3+ pixel classifier training.

if nargin < 2 || isempty(ctx)
    ctx = struct();
elseif ischar(ctx) || (isstring(ctx) && isscalar(ctx))
    ctx = struct('mode', char(string(ctx)));
end

out = deeplab_pixel_classification.utils.outInitSafe('deeplab_pixel_classification.train');

mode = "train";
if isfield(ctx, 'mode') && ~isempty(ctx.mode)
    mode = string(ctx.mode);
end

if strcmpi(mode, "init") || strcmpi(mode, "setparam") || strcmpi(mode, "param")
    classif.trainingParam = deeplab_pixel_classification.utils.defaultTrainingParam();
    deeplab_pixel_classification.ensureClassMetadata(classif);
    out.refs.trainingParam = classif.trainingParam;
    out.status = "OK";
    return;
end

if isempty(classif.trainingParam)
    classif.trainingParam = deeplab_pixel_classification.utils.defaultTrainingParam();
end

if isfield(ctx, 'params') && isstruct(ctx.params) && ~isempty(ctx.params)
    classif.trainingParam = deeplab_pixel_classification.utils.applyParamOverrides(classif.trainingParam, ctx.params);
end

deeplab_pixel_classification.ensureClassMetadata(classif);

trainPixelDeeplabNetFun(classif);

out.status = "OK";
out.provides = {'DeepLabPixelClassifier'};
out.refs.trainingParam = classif.trainingParam;
out.artifacts.classifier = fullfile(classif.path, [classif.strid '.mat']);
end
