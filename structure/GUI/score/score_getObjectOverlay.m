function h = score_getObjectOverlay(app, channelName, preferredAxes)
%SCORE_GETOBJECTOVERLAY Resolve the image overlay for one annotation channel.
% Comparison rows have separate overlays. Programmatic track navigation and
% mouse editing must use the same row, rather than the first image in a figure.

if nargin < 2, [~,channelName] = score_selectedObjectChannel(app); end
if nargin < 3, preferredAxes = []; end
h = [];
if isempty(app.graphicsHandles) || ~isfield(app.graphicsHandles,'overlayHandles')
    return;
end
overlays = app.graphicsHandles.overlayHandles;
if isfield(app.graphicsHandles,'comparisonPanels')
    if isempty(channelName) || ~isa(overlays,'containers.Map'), return; end
    for panel = app.graphicsHandles.comparisonPanels
        if ~isKey(overlays,panel.tile), continue; end
        candidate = overlays(panel.tile);
        if ~isgraphics(candidate) || ~isstruct(candidate.UserData) || ...
                ~isfield(candidate.UserData,'annotationChannel') || ...
                string(candidate.UserData.annotationChannel) ~= string(channelName)
            continue;
        end
        if isempty(h), h = candidate; end
        if isequal(preferredAxes,candidate.Parent)
            h = candidate;
            return;
        end
        images = app.graphicsHandles.imgHandles;
        if isKey(images,panel.tile)
            base = images(panel.tile);
            if isgraphics(base) && isequal(preferredAxes,base.Parent)
                h = candidate;
                return;
            end
        end
    end
    return;
end

% Older single-mask renderers use a map, cell, struct or graphics array.
if isa(overlays,'containers.Map')
    keys = overlays.keys;
    if ~isempty(keys), h = overlays(keys{1}); end
elseif iscell(overlays)
    if ~isempty(overlays), h = overlays{1}; end
elseif isstruct(overlays)
    fields = fieldnames(overlays);
    if ~isempty(fields), h = overlays.(fields{1}); end
elseif ~isempty(overlays)
    h = overlays(1);
end
if iscell(h) && ~isempty(h), h = h{1}; end
if ~isempty(h), h = h(1); end
if ~isgraphics(h), h = []; end
end
