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
    hText = localDrawEventLabel(ax, layoutOptions, events(i), x);
    if ~isempty(hText)
        h(end+1) = hText; %#ok<AGROW>
    end
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

function hText = localDrawEventLabel(ax, layoutOptions, event, x)
hText = gobjects(0);
try
    label = string(event.label);
    if strlength(label) == 0
        return;
    end
    xl = xlim(ax);
    yl = ylim(ax);
    if x < min(xl) || x > max(xl)
        return;
    end

    dx = 0.012 * diff(xl);
    xText = min(x + dx, xl(2) - dx);
    yText = yl(1) + 0.08 * diff(yl);
    fontSize = max(6, floor(0.9 * layoutOptions.fontSize));
    if isfield(layoutOptions, 'scalingFactor') && ~isempty(layoutOptions.scalingFactor)
        fontSize = max(6, floor(sqrt(layoutOptions.scalingFactor) * fontSize));
    end
    bg = [0 0 0];
    if isfield(layoutOptions, 'background')
        rawBg = layoutOptions.background;
        if isnumeric(rawBg) && numel(rawBg) == 3
            parsedBg = rawBg;
        else
            parsedBg = str2num(char(string(rawBg))); %#ok<ST2NM>
        end
        if isnumeric(parsedBg) && numel(parsedBg) == 3 && all(isfinite(parsedBg(:)))
            bg = min(max(double(parsedBg(:).'), 0), 1);
        end
    end
    hText = text(ax, xText, yText, char(label), ...
        'Color', event.color, ...
        'FontSize', fontSize, ...
        'FontWeight', 'bold', ...
        'Interpreter', 'none', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'bottom', ...
        'BackgroundColor', bg, ...
        'Margin', 1, ...
        'Clipping', 'on', ...
        'Tag', 'ScoreMovieEventLineLabel');
catch
    hText = gobjects(0);
end
end
