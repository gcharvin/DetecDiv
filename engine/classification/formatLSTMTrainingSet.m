function out = formatLSTMTrainingSet(varargin)
% formatLSTMTrainingSet
% Wrapper kept for backward compatibility.
% Actual implementation lives in classification/+cnn_lstm/format.m.
%
% Supported usage:
%   out = formatLSTMTrainingSet(classif, rois, ctx)
%   out = formatLSTMTrainingSet(foldername, classif, rois, 'frames', Frames)

if nargin >= 1 && (ischar(varargin{1}) || isstring(varargin{1}))
    % Legacy signature: (foldername, classif, rois, ...)
    foldername = varargin{1};
    classif    = varargin{2};
    rois       = varargin{3};
    ctx = struct();
    ctx.params = struct('foldername', foldername);
    ctx.sel = struct();

    i = 4;
    while i <= numel(varargin)
        key = varargin{i};
        if ischar(key) || isstring(key)
            key = lower(string(key));
            switch key
                case "frames"
                    if i+1 <= numel(varargin)
                        ctx.sel.frames = varargin{i+1};
                        i = i + 2;
                        continue;
                    end
            end
        end
        i = i + 1;
    end
else
    % New signature: (classif, rois, ctx)
    classif = varargin{1};
    rois    = varargin{2};
    if nargin >= 3
        ctx = varargin{3};
    else
        ctx = struct();
    end
end

out = cnn_lstm.format(classif, rois, ctx);
end
