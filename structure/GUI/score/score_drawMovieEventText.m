function h = score_drawMovieEventText(ax, layoutOptions, frameIndex)
% score_drawMovieEventText Show labels for event intervals active on image axes.

h = gobjects(0);
if nargin < 3 || ~isgraphics(ax) || ~isfield(layoutOptions, 'eventMarkers')
    return;
end

delete(findobj(ax, 'Tag', 'ScoreMovieEventText'));
events = score_normalizeMovieEvents(layoutOptions.eventMarkers);
if isempty(events)
    return;
end

labels = strings(0);
frameIndex = double(frameIndex);
for i = 1:numel(events)
    if frameIndex >= events(i).startFrame && frameIndex <= events(i).endFrame && ...
            strlength(string(events(i).label)) > 0
        labels(end+1) = string(events(i).label); %#ok<AGROW>
    end
end
if isempty(labels)
    return;
end

txt = strjoin(labels, " | ");
h = text(ax, 0.02, 0.02, score_wrapDisplayLabel(txt, 28), ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'bottom', ...
    'Color', localAxisColor(layoutOptions), ...
    'FontWeight', 'bold', ...
    'FontSize', floor(sqrt(layoutOptions.scalingFactor) * layoutOptions.fontSize), ...
    'Interpreter', 'none', ...
    'BackgroundColor', layoutOptions.background, ...
    'Margin', 2, ...
    'Clipping', 'on', ...
    'Tag', 'ScoreMovieEventText');
end

function color = localAxisColor(layoutOptions)
color = [1 1 1];
try
    if isfield(layoutOptions, 'textColor') && isnumeric(layoutOptions.textColor) && numel(layoutOptions.textColor) == 3
        color = min(max(double(layoutOptions.textColor(:).'), 0), 1);
    end
catch
    color = [1 1 1];
end
end
