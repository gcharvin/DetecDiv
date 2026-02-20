function out = classify(roiobj, classif, ctx)
% cnn.classify  Package entry point for simple CNN image classifier.
%
% Returns struct with fields:
%   - data  : results (legacy struct)
%   - image : roi image
%   - patch : empty (handled by classi.classifyData fallback)

if nargin < 3
    ctx = struct();
end

classifier = [];
if isstruct(ctx) && isfield(ctx,'exec') && isfield(ctx.exec,'classifier')
    classifier = ctx.exec.classifier;
end

% Channels (legacy expects string/cell)
channels = [];
if isstruct(ctx) && isfield(ctx,'sel') && isfield(ctx.sel,'channels')
    channels = ctx.sel.channels;
end

args = {};
if ~isempty(channels)
    args = [args, {'Channel', channels}];
end

if isempty(classifier)
    classifier = classif.loadClassifier('force');
end

[results, image] = classifyImageGoogleNetFun(roiobj, classif, classifier, args{:});

out = struct();
out.data = results;
out.image = image;
out.patch = struct();
end
