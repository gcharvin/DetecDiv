function score_refreshScaleBars(graphicsHandles, layoutOptions)
% score_refreshScaleBars Redraw display-mode channel scales after axes sync.

if nargin < 2 || isempty(graphicsHandles) || isempty(layoutOptions) || ...
        ~isstruct(graphicsHandles) || ~isfield(graphicsHandles, 'scaleBarHandles') || ...
        ~isfield(layoutOptions, 'mode') || ~strcmpi(string(layoutOptions.mode), "display") || ...
        ~isfield(layoutOptions, 'scale') || isempty(layoutOptions.scale)
    return;
end

if ~isfield(graphicsHandles, 'imgHandles') || isempty(graphicsHandles.imgHandles)
    return;
end

if isfield(layoutOptions, 'overlay') && logical(layoutOptions.overlay)
    localRefreshOverlayScale(graphicsHandles, layoutOptions);
else
    localRefreshChannelScales(graphicsHandles, layoutOptions);
end
end

function localRefreshOverlayScale(graphicsHandles, layoutOptions)
tileIndex = 1;
ax = localAxesForTile(graphicsHandles, tileIndex);
if isempty(ax)
    return;
end

localDeleteScale(graphicsHandles, tileIndex);
hScale = localDrawAllScales(ax, layoutOptions);
if ~isempty(hScale)
    graphicsHandles.scaleBarHandles(tileIndex) = hScale;
end
end

function localRefreshChannelScales(graphicsHandles, layoutOptions)
nCh = localChannelCount(layoutOptions);
for ch = 1:nCh
    tileIndex = (ch - 1) * layoutOptions.Nbrick + 1;
    ax = localAxesForTile(graphicsHandles, tileIndex);
    if isempty(ax)
        continue;
    end

    localDeleteScale(graphicsHandles, tileIndex);
    hScale = score_drawChannelScaleBar(ax, layoutOptions, ch);
    if ~isempty(hScale)
        graphicsHandles.scaleBarHandles(tileIndex) = hScale;
    end
end
end

function ax = localAxesForTile(graphicsHandles, tileIndex)
ax = [];
try
    if isfield(graphicsHandles, 'overlayHandles') && ~isempty(graphicsHandles.overlayHandles) && ...
            isKey(graphicsHandles.overlayHandles, tileIndex)
        h = graphicsHandles.overlayHandles(tileIndex);
        h = h(1);
        if isgraphics(h)
            ax = ancestor(h, 'axes');
            return;
        end
    end

    if isfield(graphicsHandles, 'imgHandles') && ~isempty(graphicsHandles.imgHandles) && ...
            isKey(graphicsHandles.imgHandles, tileIndex)
        h = graphicsHandles.imgHandles(tileIndex);
        h = h(1);
        if isgraphics(h)
            ax = ancestor(h, 'axes');
        end
    end
catch
    ax = [];
end
end

function localDeleteScale(graphicsHandles, tileIndex)
try
    if isKey(graphicsHandles.scaleBarHandles, tileIndex)
        oldHandles = graphicsHandles.scaleBarHandles(tileIndex);
        if ~isempty(oldHandles)
            delete(oldHandles(isgraphics(oldHandles)));
        end
        remove(graphicsHandles.scaleBarHandles, tileIndex);
    end
catch
end
end

function hScale = localDrawAllScales(ax, layoutOptions)
hScale = gobjects(0);
nCh = localChannelCount(layoutOptions);
scaledChannels = find(logical(layoutOptions.scale(1:nCh)));
offsetCount = numel(scaledChannels);
for i = 1:offsetCount
    h = score_drawChannelScaleBar(ax, layoutOptions, scaledChannels(i), i, offsetCount);
    if ~isempty(h)
        hScale = [hScale h]; %#ok<AGROW>
    end
end
end

function nCh = localChannelCount(layoutOptions)
nCh = numel(layoutOptions.scale);
if isfield(layoutOptions, 'Nchannel') && ~isempty(layoutOptions.Nchannel)
    nCh = min(nCh, layoutOptions.Nchannel);
end
end
