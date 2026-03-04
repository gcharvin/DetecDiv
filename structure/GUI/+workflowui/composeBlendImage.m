function rgb = composeBlendImage(channelImages, channelCfg)
% workflowui.composeBlendImage  Build a blended RGB image from raw channels.

rgb = [];
if isempty(channelImages)
    return;
end

firstIm = [];
for i = 1:numel(channelImages)
    if ~isempty(channelImages{i})
        firstIm = channelImages{i};
        break;
    end
end
if isempty(firstIm)
    return;
end

sz = size(firstIm);
rgb = zeros(sz(1), sz(2), 3);

for i = 1:min(numel(channelImages), numel(channelCfg))
    im = channelImages{i};
    cfg = channelCfg(i);
    if isempty(im) || ~cfg.enabled
        continue;
    end
    scaled = workflowui.stretchToUnit(im, cfg.levels, cfg.auto);
    weight = cfg.weight;
    if isempty(weight) || ~isscalar(weight) || ~isfinite(weight)
        weight = 1;
    end
    color = cfg.color;
    if isempty(color) || numel(color) ~= 3
        color = [1 1 1];
    end
    color = double(reshape(color, 1, 1, 3));
    rgb = rgb + weight .* scaled .* color;
end

mx = max(rgb(:));
if mx > 0
    rgb = rgb ./ mx;
end
rgb(rgb < 0) = 0;
rgb(rgb > 1) = 1;
end
