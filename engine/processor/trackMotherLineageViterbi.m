function [paramout, dataout, imageout] = trackMotherLineageViterbi(param, roiobj, frames)
% trackMotherLineageViterbi  Legacy wrapper for the packaged processor.
%
% New code should call trackMotherLineageViterbi.process(param, roiobj, ctx).

if nargin == 0
    paramout = trackMotherLineageViterbi.setparam(struct());
    dataout = [];
    imageout = [];
    return;
end

if nargin < 3
    frames = [];
end

[paramout, dataout, imageout] = trackMotherLineageViterbi.process(param, roiobj, frames);
end
