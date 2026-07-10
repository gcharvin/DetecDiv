function h = score_drawChannelScaleBar(ax, layoutOptions, ch, offsetIndex, offsetCount)
% score_drawChannelScaleBar Draw an intensity color scale inside an image axes.

h = gobjects(0);

if nargin < 4 || isempty(offsetIndex)
    offsetIndex = 1;
end
if nargin < 5 || isempty(offsetCount)
    offsetCount = 1;
end

if isempty(ax) || ~isgraphics(ax) || isempty(layoutOptions) || ...
        ~isfield(layoutOptions, 'scale') || ch > numel(layoutOptions.scale) || ...
        ~logical(layoutOptions.scale(ch))
    return;
end

if ~isfield(layoutOptions, 'levels') || ch > numel(layoutOptions.levels) || iscell(layoutOptions.levels{ch})
    return;
end

lims = double(layoutOptions.levels{ch});
tickLims = lims;
if isfield(layoutOptions, 'displayLevels') && ch <= numel(layoutOptions.displayLevels) && ...
        ~iscell(layoutOptions.displayLevels{ch}) && numel(layoutOptions.displayLevels{ch}) >= 2
    tickLims = double(layoutOptions.displayLevels{ch});
end
if numel(lims) < 2 || any(~isfinite(lims(1:2)))
    return;
end
lo = lims(1);
hi = lims(2);
tickLo = tickLims(1);
tickHi = tickLims(2);
if hi <= lo
    hi = lo + 1;
end
if tickHi <= tickLo
    tickHi = tickLo + eps(max(1, abs(tickLo)));
end

xl = xlim(ax);
yl = ylim(ax);
imgW = abs(diff(xl));
imgH = abs(diff(yl));

barW = max(3, 0.035 * imgW);
barH = 0.62 * imgH;
gap = max(2, 0.02 * imgW);
rightPad = max(4, 0.035 * imgW);

xRight = max(xl) - rightPad - (offsetCount - offsetIndex) * (barW + gap);
xLeft = xRight - barW;
yTop = min(yl) + 0.18 * imgH;
yBottom = yTop + barH;

n = 128;
if localUsesColormap(layoutOptions, ch)
    cmapName = localColormapName(layoutOptions, ch);
    grad = reshape(score_colormapFromName(cmapName, n), [n 1 3]);
    grad = grad(end:-1:1, :, :);
else
    rgb = [1 1 1];
    if isfield(layoutOptions, 'RGB') && ch <= numel(layoutOptions.RGB) && numel(layoutOptions.RGB{ch}) == 3
        rgb = double(layoutOptions.RGB{ch});
    end
    rgb = min(max(rgb(:).', 0), 1);
    vals = linspace(1, 0, n)';
    grad = cat(3, vals * rgb(1), vals * rgb(2), vals * rgb(3));
end
grad = repmat(grad, [1 max(2, round(barW)) 1]);

holdState = ishold(ax);
hold(ax, 'on');

h(end+1) = image(ax, [xLeft xRight], [yTop yBottom], grad, 'Clipping', 'on');
h(end+1) = rectangle(ax, 'Position', [xLeft yTop barW barH], ...
    'EdgeColor', layoutOptions.textColor, ...
    'LineWidth', max(0.5, 0.8 * layoutOptions.scalingFactor), ...
    'FaceColor', 'none', ...
    'Clipping', 'on');

ticks = localNiceTicks(tickLo, tickHi, 5);
tickLen = max(3, 0.018 * imgW);
fontSize = max(6, floor(0.75 * layoutOptions.fontSize));

for i = 1:numel(ticks)
    t = localTickFraction(ticks(i), tickLo, tickHi, layoutOptions, ch);
    y = yBottom - t * barH;
    h(end+1) = line(ax, [xLeft - tickLen, xLeft], [y y], ...
        'Color', layoutOptions.textColor, ...
        'LineWidth', max(0.5, 0.8 * layoutOptions.scalingFactor), ...
        'Clipping', 'on'); %#ok<AGROW>
    h(end+1) = text(ax, xLeft - 1.35 * tickLen, y, localFormatTick(ticks(i)), ...
        'Color', layoutOptions.textColor, ...
        'FontSize', fontSize, ...
        'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle', ...
        'Interpreter', 'none', ...
        'BackgroundColor', layoutOptions.background, ...
        'Margin', 1, ...
        'Clipping', 'on'); %#ok<AGROW>
end

if ~holdState
    hold(ax, 'off');
end
end

function t = localTickFraction(value, lo, hi, layoutOptions, ch)
if isfield(layoutOptions, 'log') && ch <= numel(layoutOptions.log) && logical(layoutOptions.log(ch)) && ...
        lo > -1 && hi > lo
    denom = log1p(hi) - log1p(lo);
    if denom > 0
        t = (log1p(value) - log1p(lo)) / denom;
    else
        t = (value - lo) / (hi - lo);
    end
else
    t = (value - lo) / (hi - lo);
end
t = min(max(t, 0), 1);
end

function tf = localUsesColormap(layoutOptions, ch)
tf = false;
try
    tf = isfield(layoutOptions, 'colorMode') && ch <= numel(layoutOptions.colorMode) && ...
        strcmpi(strtrim(char(string(layoutOptions.colorMode{ch}))), 'colormap');
catch
    tf = false;
end
end

function name = localColormapName(layoutOptions, ch)
name = 'parula';
try
    if isfield(layoutOptions, 'colormapName') && ch <= numel(layoutOptions.colormapName) && ...
            strlength(string(layoutOptions.colormapName{ch})) > 0
        name = char(string(layoutOptions.colormapName{ch}));
    end
catch
    name = 'parula';
end
end

function ticks = localNiceTicks(lo, hi, maxTicks)
if hi <= lo
    ticks = lo;
    return;
end

rawStep = (hi - lo) / max(1, maxTicks - 1);
mag = 10 ^ floor(log10(rawStep));
steps = [1 2 2.5 5 10] * mag;
step = steps(find(steps >= rawStep, 1, 'first'));
if isempty(step)
    step = 10 * mag;
end

firstTick = ceil(lo / step) * step;
lastTick = floor(hi / step) * step;
ticks = firstTick:step:lastTick;

if isempty(ticks)
    ticks = [lo hi];
elseif numel(ticks) < 2
    ticks = unique([lo ticks hi]);
end

while numel(ticks) > maxTicks
    step = step * 2;
    firstTick = ceil(lo / step) * step;
    lastTick = floor(hi / step) * step;
    ticks = firstTick:step:lastTick;
end
end

function txt = localFormatTick(v)
if abs(v) >= 100
    txt = sprintf('%.0f', v);
elseif abs(v) >= 10
    txt = sprintf('%.1f', v);
else
    txt = sprintf('%.2g', v);
end
end
