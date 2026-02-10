function [paramout, dataout, imageout] = basicObjectTracking(param, roiobj, frames)
% basicObjectTracking  Legacy wrapper for the package implementation.
%
% Use basicObjectTracking.process for the packaged version.

    if nargin == 0
        paramout = basicObjectTracking.setparam();
        dataout = [];
        imageout = [];
        return;
    end

    if nargin < 3
        frames = [];
    end

    [paramout, dataout, imageout] = basicObjectTracking.process(param, roiobj, frames);
end
