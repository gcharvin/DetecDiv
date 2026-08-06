function [maskOut, report] = score_splitMaskObject(maskFrame, oldLabel, varargin)
%SCORE_SPLITMASKOBJECT Split one mask label into independently labeled parts.

p = inputParser;
p.addParameter('UsedLabels', [], @isnumeric);
p.addParameter('Connectivity', 8, @(x) isscalar(x) && any(x == [4 8]));
p.addParameter('CloseRadius', 2, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('HMax', 1, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.parse(varargin{:});

maskOut = maskFrame;
oldLabel = double(oldLabel);
foreground = maskFrame == oldLabel;
report = struct('status', 'unchanged', 'method', 'none', ...
    'componentCount', 0, 'keptLabel', oldLabel, 'newLabels', []);
if ~any(foreground(:))
    report.status = 'missing';
    return;
end

% Disconnected pieces are already a valid split. Watershed is reserved for
% a genuinely connected object, otherwise morphology can bridge the gap.
[splitLabels, componentCount] = bwlabel(foreground, p.Results.Connectivity);
if componentCount > 1
    method = 'connected_components';
else
    [splitLabels, componentCount] = localWatershedSplit( ...
        foreground, p.Results.Connectivity, ...
        p.Results.CloseRadius, p.Results.HMax);
    method = 'watershed';
end

report.method = method;
report.componentCount = componentCount;
if componentCount <= 1
    return;
end

stats = regionprops(splitLabels, 'Area');
[~, keepComponent] = max([stats.Area]);
maskOut(foreground) = 0;
maskOut(splitLabels == keepComponent) = cast(oldLabel, 'like', maskOut);

used = unique([double(maskFrame(:)); double(p.Results.UsedLabels(:))]);
used = used(isfinite(used) & used > 0);
newLabels = zeros(1, componentCount - 1);
newIndex = 0;
for component = 1:componentCount
    if component == keepComponent, continue; end
    newIndex = newIndex + 1;
    candidate = 1;
    while ismember(candidate, used)
        candidate = candidate + 1;
    end
    maskOut(splitLabels == component) = cast(candidate, 'like', maskOut);
    newLabels(newIndex) = candidate;
    used(end + 1) = candidate; %#ok<AGROW>
end

report.status = 'split';
report.newLabels = newLabels;
end

function [labelsOut, componentCount] = localWatershedSplit( ...
        foreground, connectivity, closeRadius, hMax)
distance = bwdist(~foreground);
if closeRadius > 0
    distance = imclose(distance, strel('disk', closeRadius));
end
if hMax > 0
    distance = imhmax(distance, hMax);
end
watershedLabels = watershed(-distance, connectivity);
watershedLabels(~foreground) = 0;

values = unique(watershedLabels);
values(values == 0) = [];
labelsOut = zeros(size(watershedLabels), 'double');
componentCount = 0;
for i = 1:numel(values)
    [components, count] = bwlabel( ...
        watershedLabels == values(i), connectivity);
    if count == 0, continue; end
    components(components > 0) = components(components > 0) + componentCount;
    labelsOut = labelsOut + components;
    componentCount = componentCount + count;
end
labelsOut(~foreground) = 0;
end
