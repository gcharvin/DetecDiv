function [paramout, dataout, imageout] = process(param, roiobj, ctx)
%BUDMOTHERLINKER.PROCESS Pipeline-compatible builtin bud/mother linker.

if nargin < 3
    ctx = struct();
elseif ~isstruct(ctx)
    ctx = struct('frames', ctx);
end
if nargin == 0 || isempty(param)
    paramout = budMotherLinker.setparam(ctx);
    dataout = [];
    imageout = [];
    return;
end

paramout = budMotherLinker.normalizeParam(param, ctx);
[paramout, dataout, imageout] = budMotherLinker.core(paramout, roiobj, ctx);
end
