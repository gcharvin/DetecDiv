function h = score_drawMovieEventText(ax, layoutOptions, frameIndex)
% score_drawMovieEventText Show active event labels on movie images.

h = gobjects(0);
if nargin < 3 || ~isgraphics(ax) || ~isfield(layoutOptions, 'eventMarkers')
    return;
end

delete(findobj(ax, 'Tag', 'ScoreMovieEventText'));
events = score_normalizeMovieEvents(layoutOptions.eventMarkers);
if isempty(events)
    return;
end

try
    if isfield(layoutOptions, 'timeOffset') && layoutOptions.timeOffset
        t = (frameIndex - layoutOptions.frames(1)) * layoutOptions.framerate;
    else
        t = frameIndex * layoutOptions.framerate;
    end
catch
    t = frameIndex;
end

labels = strings(0);
textColor = [0.2 0.95 0.25];
for i = 1:numel(events)
    if t >= events(i).time && strlength(string(events(i).label)) > 0
        labels(end+1) = string(events(i).label); %#ok<AGROW>
        textColor = events(i).color;
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
    'Color', textColor, ...
    'FontWeight', 'bold', ...
    'FontSize', floor(sqrt(layoutOptions.scalingFactor) * layoutOptions.fontSize), ...
    'Interpreter', 'none', ...
    'BackgroundColor', layoutOptions.background, ...
    'Margin', 2, ...
    'Clipping', 'on', ...
    'Tag', 'ScoreMovieEventText');
end
