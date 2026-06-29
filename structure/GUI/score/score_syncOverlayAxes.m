function score_syncOverlayAxes(graphicsHandles)
% score_syncOverlayAxes Keep annotation overlay axes aligned with image axes.
%
% Annotation masks are displayed on transparent axes stacked above the image
% axes. Tiled layouts update managed image axes on figure resize, but the
% extra overlay axes are unmanaged and must be moved explicitly.

if nargin < 1 || isempty(graphicsHandles) || ~isstruct(graphicsHandles)
    return;
end
if ~isfield(graphicsHandles, 'imgHandles') || ~isfield(graphicsHandles, 'overlayHandles')
    return;
end
if isempty(graphicsHandles.imgHandles) || isempty(graphicsHandles.overlayHandles)
    return;
end

keys = localOverlayKeys(graphicsHandles.overlayHandles);
for i = 1:numel(keys)
    key = keys{i};
    hOverlay = localMapValue(graphicsHandles.overlayHandles, key);
    hImage = localMapValue(graphicsHandles.imgHandles, key);

    hOverlay = localFirstImage(hOverlay);
    hImage = localFirstImage(hImage);
    if isempty(hOverlay) || isempty(hImage)
        continue;
    end
    if ~isgraphics(hOverlay) || ~isgraphics(hImage)
        continue;
    end

    axOverlay = ancestor(hOverlay, 'axes');
    axImage = ancestor(hImage, 'axes');
    if isempty(axOverlay) || isempty(axImage) || ~isgraphics(axOverlay) || ~isgraphics(axImage)
        continue;
    end

    localSyncAxes(axImage, axOverlay);
end
end

function keys = localOverlayKeys(mapLike)
keys = {};
if isa(mapLike, 'containers.Map')
    keys = mapLike.keys;
elseif isstruct(mapLike)
    names = fieldnames(mapLike);
    keys = names(:)';
elseif iscell(mapLike)
    keys = num2cell(1:numel(mapLike));
elseif ~isempty(mapLike)
    keys = num2cell(1:numel(mapLike));
end
end

function value = localMapValue(mapLike, key)
value = [];
try
    if isa(mapLike, 'containers.Map')
        if isKey(mapLike, key)
            value = mapLike(key);
        end
    elseif isstruct(mapLike)
        if ischar(key) || isstring(key)
            key = char(string(key));
            if isfield(mapLike, key)
                value = mapLike.(key);
            end
        end
    elseif iscell(mapLike)
        if isnumeric(key) && key >= 1 && key <= numel(mapLike)
            value = mapLike{key};
        end
    elseif isnumeric(key) && key >= 1 && key <= numel(mapLike)
        value = mapLike(key);
    end
catch
    value = [];
end
end

function h = localFirstImage(h)
if iscell(h) && ~isempty(h)
    h = h{1};
end
if isempty(h)
    h = [];
    return;
end
try
    h = h(:);
    isImg = arrayfun(@(x) isgraphics(x) && isa(x, 'matlab.graphics.primitive.Image'), h);
    idx = find(isImg, 1, 'first');
    if isempty(idx)
        h = [];
    else
        h = h(idx);
    end
catch
    h = [];
end
end

function localSyncAxes(axImage, axOverlay)
oldUnitsImage = '';
oldUnitsOverlay = '';
try
    oldUnitsImage = axImage.Units;
catch
end
try
    oldUnitsOverlay = axOverlay.Units;
catch
end

try
    axImage.Units = 'normalized';
catch
end
try
    axOverlay.Units = 'normalized';
catch
end

try
    axOverlay.Position = axImage.Position;
catch
end
try
    axOverlay.InnerPosition = axImage.InnerPosition;
catch
end
try
    axOverlay.XLim = axImage.XLim;
catch
end
try
    axOverlay.YLim = axImage.YLim;
catch
end
try
    axOverlay.XDir = axImage.XDir;
catch
end
try
    axOverlay.YDir = axImage.YDir;
catch
end
try
    axOverlay.DataAspectRatio = axImage.DataAspectRatio;
catch
end
try
    axOverlay.PlotBoxAspectRatio = axImage.PlotBoxAspectRatio;
catch
end
try
    axOverlay.Visible = 'off';
catch
end
try
    axOverlay.Color = 'none';
catch
end
try
    axOverlay.HitTest = 'off';
catch
end
try
    uistack(axOverlay, 'top');
catch
end

if ~isempty(oldUnitsImage)
    try
        axImage.Units = oldUnitsImage;
    catch
    end
end
if ~isempty(oldUnitsOverlay)
    try
        axOverlay.Units = oldUnitsOverlay;
    catch
    end
end
end
