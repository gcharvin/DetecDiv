function data = score_histogramData(plane,numEdges)
%SCORE_HISTOGRAMDATA Shared display histogram in the supplied pixel units.
if nargin < 2, numEdges = 200; end
if ndims(plane) == 3 && size(plane,3) == 3
    plane = .2989*double(plane(:,:,1)) + .5870*double(plane(:,:,2)) + .1140*double(plane(:,:,3));
end
values = double(plane(:)); values = values(isfinite(values));
data = struct('edges',[],'counts',[],'median',[],'range',[],'count',numel(values));
if isempty(values), return; end
lo = min(values); hi = max(values);
if hi <= lo, hi = lo + eps(max(1,abs(lo))); end
if lo > 0, edges = logspace(log10(max(lo,realmin)),log10(hi),numEdges);
else, edges = linspace(lo,hi,numEdges); end
% Include the observed endpoints despite logspace rounding.
edges(1) = lo; edges(end) = hi;
data.edges = edges; data.counts = histcounts(values,edges);
data.median = median(values); data.range = [lo hi];
end
