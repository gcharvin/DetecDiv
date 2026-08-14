function frames = frames(classif, roiRef, frameCount, requested, varargin)
%TRAININGBOUNDS.FRAMES Intersect run selection with effective ROI bounds.
if nargin < 4, requested = []; end
frames = normalizeTrainingFrameSelection(requested, frameCount, varargin{:}, ...
    'RoiId', roiIndex(classif, roiRef));
bounds = trainingBounds.resolve(classif, roiRef, 'FrameCount', frameCount);
if ~isempty(bounds)
    frames = frames(frames >= bounds(1) & frames <= bounds(2));
end
frames = unique(round(double(frames(:).')), 'stable');
end

function value = roiIndex(classif, roiRef)
if isa(roiRef,'roi')
    value = find(string({classif.roi.id}) == string(roiRef.id),1);
else
    value = round(double(roiRef));
end
if isempty(value), value = NaN; end
end
