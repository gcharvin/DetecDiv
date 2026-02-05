function out = trainImageLSTMNetFun(classif, varargin)
% trainImageLSTMNetFun
% Wrapper kept for backward compatibility.
% Actual implementation lives in classification/+cnn_lstm/train.m.
%
% Supported usage:
%   out = trainImageLSTMNetFun(classif, ctx)
%   trainImageLSTMNetFun(classif, setparam)  % legacy init

ctx = struct();
if nargin >= 2
    if isstruct(varargin{1})
        ctx = varargin{1};
    else
        % legacy init path
        ctx.mode = 'init';
    end
else
    ctx.mode = 'train';
end

out = cnn_lstm.train(classif, ctx);
end
