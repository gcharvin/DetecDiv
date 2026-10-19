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
for pass = 1:2
    layoutChanged = false;
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

        layoutChanged = localSyncAxes(axImage, axOverlay) || layoutChanged;
    end
    if ~layoutChanged || pass == 2
        break;
    end
    % MATLAB settles tiled-layout geometry lazily after zoom, resize or a
    % stacking repair. Resync once after that update, only when geometry changed.
    drawnow nocallbacks;
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

function layoutChanged = localSyncAxes(axImage, axOverlay)
layoutChanged = false;
% uistack rebuilds MATLAB graphics controllers even if the overlay already
% covers its image. Only repair stacking when their relative order is wrong.
% A tiled image axes has the layout as its parent; compare the layout's
% position among the figure children with the unmanaged overlay axes.
try
    imageChild = axImage;
    parent = axOverlay.Parent;
    while ~isempty(imageChild.Parent) && ~isequal(imageChild.Parent, parent)
        imageChild = imageChild.Parent;
    end
    children = parent.Children;
    overlayIndex = find(children == axOverlay, 1);
    imageIndex = find(children == imageChild, 1);
    if isempty(overlayIndex) || isempty(imageIndex) || overlayIndex > imageIndex
        uistack(axOverlay, 'top');
        layoutChanged = true;
    end
catch
end

oldUnitsImage = axImage.Units;
oldUnitsOverlay = axOverlay.Units;
localSetIfDifferent(axImage, 'Units', 'normalized');
localSetIfDifferent(axOverlay, 'Units', 'normalized');

% Writing unchanged limits/aspect ratios triggers listeners on every linked
% axes. In comparison mode this work otherwise grows with all image tiles.
geometryProperties = {'Position','InnerPosition','XLim','YLim','XDir','YDir', ...
    'DataAspectRatio','PlotBoxAspectRatio'};
for k = 1:numel(geometryProperties)
    name = geometryProperties{k};
    layoutChanged = localSetIfDifferent(axOverlay, name, axImage.(name)) || layoutChanged;
end
localSetIfDifferent(axOverlay, 'Visible', 'off');
localSetIfDifferent(axOverlay, 'Color', 'none');
localSetIfDifferent(axOverlay, 'HitTest', 'off');

localSetIfDifferent(axImage, 'Units', oldUnitsImage);
localSetIfDifferent(axOverlay, 'Units', oldUnitsOverlay);
end

function changed = localSetIfDifferent(obj, name, value)
changed = false;
try
    % Setting a numeric axes property also selects manual mode. Preserve
    % that effect once, even if its automatic value currently matches.
    modeName = [name 'Mode'];
    autoMode = isprop(obj, modeName) && strcmp(obj.(modeName), 'auto');
    if autoMode || ~isequaln(obj.(name), value)
        obj.(name) = value;
        changed = true;
    end
catch
end
end
