function [paramout, dataout, imageout] = budMotherLinker(param, roiobj, frames)
% budMotherLinker  Legacy entry point for the builtin bud/mother linker.
%
% New pipeline code should call budMotherLinker.process(param, roiobj, ctx).

if nargin == 0
    paramout = budMotherLinker.setparam(struct());
    dataout = [];
    imageout = [];
    return;
end
if nargin < 3, frames = []; end
[paramout, dataout, imageout] = budMotherLinker.process(param, roiobj, frames);
end
