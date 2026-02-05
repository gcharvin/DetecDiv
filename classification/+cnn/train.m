function out = train(classif, ctx)
% cnn.train  Package entry point for simple CNN image classifier training.
%
% ctx.mode:
%   - 'init'     -> initialize training parameters
%   - 'train'    -> run training

if nargin < 2 || isempty(ctx)
    ctx = struct();
end

out = cnn.utils.outInitSafe('cnn.train');

mode = "train";
if isfield(ctx,'mode') && ~isempty(ctx.mode)
    mode = string(ctx.mode);
end

if strcmpi(mode,"init") || strcmpi(mode,"setparam") || strcmpi(mode,"param")
    classif.trainingParam = cnn.utils.defaultTrainingParam();
    out.refs.trainingParam = classif.trainingParam;
    out.status = "OK";
    return;
end

if isempty(classif.trainingParam)
    classif.trainingParam = cnn.utils.defaultTrainingParam();
end

% Optional overrides from ctx.params
if isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
    classif.trainingParam = cnn.utils.applyParamOverrides(classif.trainingParam, ctx.params);
end

% Training: attach to current run started by classi.trainClassifier
try
    trainImageGoogleNetFun(classif, 'ok', [], 'AttachRun', true);
catch
    % Fallback to legacy call if signature differs
    trainImageGoogleNetFun(classif);
end

out.status = "OK";
end
