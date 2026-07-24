function [paramout,dataout,imageout] = process(param,roiobj,ctx)
%CELLLATENTMODEL.PROCESS Pipeline-compatible wrapper.
if nargin < 3, ctx = struct(); end
if nargin == 0 || isempty(param)
    paramout = cellLatentModel.utils.defaultExecutionParam();
    dataout = [];
    imageout = [];
    return;
end
paramout = cellLatentModel.normalizeParam(param,ctx);
[paramout,dataout,imageout] = cellLatentModel.core( ...
    paramout,roiobj,ctx);
end
