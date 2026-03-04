function out = stretchToUnit(im, levels, useAuto)
% workflowui.stretchToUnit  Normalize image intensities into [0,1].

out = [];
if isempty(im)
    return;
end
im = double(im);
if nargin < 2 || isempty(levels)
    levels = [min(im(:)) max(im(:))];
end
if nargin < 3
    useAuto = false;
end
if useAuto || numel(levels) ~= 2 || ~isfinite(levels(1)) || ~isfinite(levels(2)) || levels(2) <= levels(1)
    lo = min(im(:));
    hi = max(im(:));
else
    lo = double(levels(1));
    hi = double(levels(2));
end
if ~isfinite(lo), lo = 0; end
if ~isfinite(hi), hi = lo + 1; end
if hi <= lo
    hi = lo + 1;
end
out = (im - lo) ./ (hi - lo);
out(out < 0) = 0;
out(out > 1) = 1;
end
