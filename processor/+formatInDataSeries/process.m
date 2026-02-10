function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% formatInDataSeries.process  Pipeline-compatible wrapper.

if nargin < 3
    ctx = struct(); %#ok<NASGU>
elseif ~isstruct(ctx)
    ctx = struct(); %#ok<NASGU>
end

if nargin == 0 || isempty(param)
    paramout = formatInDataSeries.setparam();
    dataout = [];
    imageout = [];
    return;
end

paramout = param;
formatInDataSeries(roiobj);

dataout = roiobj.data;
imageout = roiobj.image;
end
