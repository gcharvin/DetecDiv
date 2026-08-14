function spec = selectionSpec(classif, requested)
%TRAININGBOUNDS.SELECTIONSPEC Build the per-ROI selector passed to formatters.
if nargin < 2, requested = []; end
nRois = numel(classif.roi);
hasPerRoi = false;
for i = 1:nRois
    if ~isempty(trainingBounds.resolve(classif, i))
        hasPerRoi = true;
        break;
    end
end
if ~hasPerRoi
    spec = requested;
    return;
end

spec = struct();
for i = 1:nRois
    total = frameCount(classif.roi(i));
    selected = trainingBounds.frames(classif, i, total, requested, ...
        'RoiPosition', i);
    if isempty(selected)
        error('trainingBounds:EmptyIntersection', ...
            'ROI %s has no frame in the intersection of its bounds and the run selection.', ...
            char(string(classif.roi(i).id)));
    end
    spec.(sprintf('roi%d',i)) = selected;
end
end

function count = frameCount(roiObj)
count = 0;
try count = annotationManager.frameCount(roiObj); catch, end
if count < 1
    try count = size(roiObj.image,4); catch, end
end
end
