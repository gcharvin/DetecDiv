function output = resizeToReferenceGrid(image, targetHeight, targetWidth)
%ROIEXTRACT.RESIZETOREFERENCEGRID Normalize one raw channel to the ROI grid.
%
% Channels acquired with different camera binning still cover the same
% physical field of view.  Spatial resampling, rather than upper-left
% zero-padding, preserves their common coordinate system.

if isempty(image) || ~isnumeric(image) || ndims(image) ~= 2
    error('roiExtract:InvalidChannelImage', ...
        'A non-empty two-dimensional numeric channel image is required.');
end
targetHeight = round(double(targetHeight));
targetWidth = round(double(targetWidth));
if ~isscalar(targetHeight) || ~isscalar(targetWidth) || ...
        ~isfinite(targetHeight) || ~isfinite(targetWidth) || ...
        targetHeight < 1 || targetWidth < 1
    error('roiExtract:InvalidReferenceGrid', ...
        'Reference-grid dimensions must be positive finite scalars.');
end
if size(image,1) == targetHeight && size(image,2) == targetWidth
    output = image;
    return;
end
output = imresize(image, [targetHeight targetWidth]);
end
