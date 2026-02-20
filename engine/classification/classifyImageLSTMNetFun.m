function out = classifyImageLSTMNetFun(roiobj, classif, varargin)
% classifyImageLSTMNetFun
% Wrapper kept for backward compatibility.
% Actual implementation lives in classification/+cnn_lstm/classify.m.
%
% Supported usage:
%   out = classifyImageLSTMNetFun(roiobj, classif, ctx)
%   out = classifyImageLSTMNetFun(roiobj, classif, classifier, 'Name',value,...)

if nargin >= 3 && isstruct(varargin{1})
    ctx = varargin{1};
else
    ctx = struct();
    classifier = [];
    if nargin >= 3
        classifier = varargin{1};
    end

    ctx.exec = struct();
    ctx.sel = struct();
    ctx.names = struct();
    ctx.params = struct();

    ctx.exec.classifier = classifier;

    i = 2;
    while i <= numel(varargin)
        key = varargin{i};
        if ischar(key) || isstring(key)
            key = lower(string(key));
            switch key
                case "classifiercnn"
                    ctx.exec.classifierCNN = varargin{i+1};
                    i = i + 2;
                    continue;
                case "frames"
                    ctx.sel.frames = varargin{i+1};
                    i = i + 2;
                    continue;
                case "channel"
                    ctx.sel.channels = varargin{i+1};
                    i = i + 2;
                    continue;
                case "exec"
                    ctx.exec.gpu = varargin{i+1};
                    i = i + 2;
                    continue;
                case "crop"
                    ctx.params.crop = varargin{i+1};
                    i = i + 2;
                    continue;
                case "cropcenter"
                    ctx.params.cropcenter = varargin{i+1};
                    i = i + 2;
                    continue;
                case "cropsize"
                    ctx.params.cropsize = varargin{i+1};
                    i = i + 2;
                    continue;
                case "outputname"
                    ctx.names.outputName = varargin{i+1};
                    i = i + 2;
                    continue;
            end
        end
        i = i + 1;
    end
end

out = cnn_lstm.classify(roiobj, classif, ctx);
end
