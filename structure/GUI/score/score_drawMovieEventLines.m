function h = score_drawMovieEventLines(ax, layoutOptions)
% score_drawMovieEventLines Draw configured vertical event markers in a dataseries axis.

h = gobjects(0);
if nargin < 2 || ~isgraphics(ax) || ~isfield(layoutOptions, 'eventMarkers')
    return;
end

events = score_normalizeMovieEvents(layoutOptions.eventMarkers);
if isempty(events)
    return;
end

holdState = ishold(ax);
hold(ax, 'on');
for i = 1:numel(events)
    x = localEventX(ax, layoutOptions, events(i).time);
    h(end+1) = xline(ax, x, ...
        'Color', events(i).color, ...
        'LineWidth', max(0.5, events(i).width * layoutOptions.scalingFactor), ...
        'LineStyle', '--', ...
        'Tag', 'ScoreMovieEventLine'); %#ok<AGROW>
end
if ~holdState
    hold(ax, 'off');
end
end

function x = localEventX(ax, layoutOptions, eventTime)
x = eventTime;
try
    if ~isfield(layoutOptions, 'framerate') || layoutOptions.framerate <= 0
        return;
    end
    xl = xlim(ax);
    frameX = eventTime / layoutOptions.framerate;
    if (eventTime < min(xl) || eventTime > max(xl)) && frameX >= min(xl) && frameX <= max(xl)
        x = frameX;
    end
catch
    x = eventTime;
end
end
