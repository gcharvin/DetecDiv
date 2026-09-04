function [paramout,dataout,imageout] = process(param,roiobj,ctx)
%SELECTCAVITYTRAJECTORY.PROCESS Pipeline-compatible cavity role selector.

if nargin < 3 || isempty(ctx), ctx=struct(); end
if ~isstruct(ctx), ctx=struct('frames',ctx); end
if nargin == 0 || isempty(param)
    paramout=selectCavityTrajectory.setparam(ctx);
    dataout=[]; imageout=[];
    return;
end
paramout=selectCavityTrajectory.normalizeParam(param,ctx);
[paramout,dataout,imageout]=selectCavityTrajectory.core(paramout,roiobj,ctx);
end
