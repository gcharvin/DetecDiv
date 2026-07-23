function [paramout, dataout, imageout] = budMotherLinker(param, roiobj, frames)
% budMotherLinker  Legacy entry point for the builtin bud/mother linker.
%
% New configurations should use the builtin budMotherLinker classifier.

if nargin == 0
    paramout = budMotherLinker.utils.defaultExecutionParam();
    dataout = [];
    imageout = [];
    return;
end
if nargin < 3, frames = []; end
[paramout, dataout, imageout] = budMotherLinker.process(param, roiobj, frames);
end
