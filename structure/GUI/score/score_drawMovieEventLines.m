function h = score_drawMovieEventLines(ax, layoutOptions)
% score_drawMovieEventLines Draw configured event interval boundaries.

h = gobjects(0);
if nargin < 2 || ~isgraphics(ax) || ~isfield(layoutOptions, 'eventMarkers')
    return;
end

events = score_normalizeMovieEvents(layoutOptions.eventMarkers);
if isempty(events)
    return;
end

axisColor = localAxisColor(layoutOptions);
holdState = ishold(ax);
hold(ax, 'on');

for i = 1:numel(events)
    xl = xlim(ax);
    [xStart, xEnd] = localEventXRange(layoutOptions, events(i), xl);
    if xEnd < min(xl) || xStart > max(xl)
        continue;
    end

    lineWidth = max(0.5, events(i).width * layoutOptions.scalingFactor);
    if xStart >= min(xl) && xStart <= max(xl)
        h(end+1) = xline(ax, xStart, ...
            'Color', axisColor, ...
            'LineWidth', lineWidth, ...
            'LineStyle', '--', ...
            'Tag', 'ScoreMovieEventLine'); %#ok<AGROW>
    end
    if xEnd > xStart && xEnd >= min(xl) && xEnd <= max(xl)
        h(end+1) = xline(ax, xEnd, ...
            'Color', axisColor, ...
            'LineWidth', lineWidth, ...
            'LineStyle', '--', ...
            'Tag', 'ScoreMovieEventLine'); %#ok<AGROW>
    end

    hText = localDrawEventLabel(ax, layoutOptions, events(i), xStart, xEnd, axisColor);
    if ~isempty(hText)
        h(end+1) = hText; %#ok<AGROW>
    end
end

if ~holdState
    hold(ax, 'off');
end
end

function [xStart, xEnd] = localEventXRange(layoutOptions, event, xl)
rawStart = double(event.startFrame);
rawEnd = double(event.endFrame);
xStart = localFrameToTimeX(layoutOptions, rawStart);
xEnd = localFrameToTimeX(layoutOptions, rawEnd);

timeVisible = ~(xEnd < min(xl) || xStart > max(xl));
rawVisible = ~(rawEnd < min(xl) || rawStart > max(xl));
if ~timeVisible && rawVisible
    xStart = rawStart;
    xEnd = rawEnd;
end
end

function x = localFrameToTimeX(layoutOptions, frameValue)
try
    framerate = double(layoutOptions.framerate);
    if isfield(layoutOptions, 'timeOffset') && layoutOptions.timeOffset
        x = (double(frameValue) - double(layoutOptions.frames(1))) * framerate;
    else
        x = double(frameValue) * framerate;
    end
catch
    x = double(frameValue);
end
end

function hText = localDrawEventLabel(ax, layoutOptions, event, xStart, xEnd, axisColor)
hText = gobjects(0);
try
    label = string(event.label);
    if strlength(label) == 0
        return;
    end

    xl = xlim(ax);
    yl = ylim(ax);
    visibleStart = max(xStart, min(xl));
    visibleEnd = min(xEnd, max(xl));
    if visibleEnd < visibleStart
        return;
    end

    dx = 0.035 * diff(xl);
    if xStart >= min(xl) && xStart <= max(xl)
        anchorX = xStart;
    else
        anchorX = visibleStart;
    end
    xText = min(anchorX + dx, max(xl) - dx);
    yText = yl(1) + 0.05 * diff(yl);

    fontSize = max(6, floor(0.9 * layoutOptions.fontSize));
    if isfield(layoutOptions, 'scalingFactor') && ~isempty(layoutOptions.scalingFactor)
        fontSize = max(6, floor(sqrt(layoutOptions.scalingFactor) * fontSize));
    end

    hText = text(ax, xText, yText, char(label), ...
        'Color', axisColor, ...
        'FontSize', fontSize, ...
        'FontWeight', 'bold', ...
        'Interpreter', 'none', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', ...
        'Rotation', 90, ...
        'BackgroundColor', localBackgroundColor(layoutOptions), ...
        'Margin', 1, ...
        'Clipping', 'on', ...
        'Tag', 'ScoreMovieEventLineLabel');
catch
    hText = gobjects(0);
end
end

function color = localBackgroundColor(layoutOptions)
color = [0 0 0];
try
    if isfield(layoutOptions, 'background') && isnumeric(layoutOptions.background) && numel(layoutOptions.background) == 3
        color = min(max(double(layoutOptions.background(:).'), 0), 1);
    end
catch
    color = [0 0 0];
end
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
