function hLine = score_displayDataPanel(ax, groupIdx, layoutOptions, roiobj)
% Fonction d'affichage d'un panel de données.
% Les données X (frames) sont converties en minutes,
% le titre est affiché en ylabel et un xlabel "Time(min)" est ajouté.
%
% Robustesse:
% - supporte des variables table hétérogènes (numeric + categorical + string)
% - évite les concaténations de table variables incompatibles
% - force des YTick/YTickLabel stables quand la donnée est categorical
% - corrige l'indexation des marqueurs en mode timeoffset

ax.XTickMode = 'manual';
ax.XTickLabelMode = 'manual';

% IMPORTANT: éviter d'hériter des ticks/labels d'un panel précédent
set(ax, 'YTickMode', 'auto', 'YTickLabelMode', 'auto');

timeoffset    = layoutOptions.timeOffset;
framerate     = layoutOptions.framerate;
scalingFactor = layoutOptions.scalingFactor;

dataIndices = layoutOptions.plotidx{groupIdx};
data = roiobj.data(layoutOptions.dataidx{groupIdx});

% --- Extraction robuste de ydata.
% Une variable cellulaire numerique/vectorielle est etendue en une courbe par element.
[ydata, varname, yTickInfo, sourceIndex] = score_extractYData(data.data, dataIndices);

groupname = layoutOptions.plotidxgroup{groupIdx};
pix = find(matches(data.groupProperties(:,1), groupname));
plottype = data.groupProperties{pix,2};

ybounds = []; xbounds = [];
if numel(pix)
    ybounds = data.groupProperties{pix,4};
    xbounds = data.groupProperties{pix,3};
end

% --- Axe X (minutes) ---
if timeoffset
    xdata = ((1:size(ydata,1)) - layoutOptions.frames(1)) * framerate;
    keep = xdata >= 0;
    xdata = xdata(keep);
    ydata = ydata(keep, :);
else
    xdata = (1:size(ydata,1)) * framerate;
end

% --- Légendes (noms de colonnes) ---
str = cell(1, size(ydata,2));
for i = 1:size(ydata,2)
    str{i} = score_wrapDisplayLabel(varname{i}, 32);
end

if plottype=="Plot"

    % --- Plot lignes ---
    cmap = eval([layoutOptions.dataColormap '(' num2str(size(ydata,2)) ')']);
    ax.ColorOrder = cmap;
    ax.NextPlot = 'add';

    cc = 1;
    hold(ax, 'on');
    hLine = gobjects(1, size(ydata,2));

    for i = 1:size(ydata,2)
        wid = data.plotProperties{sourceIndex(i),5};
        col = data.plotProperties{sourceIndex(i),4};
        rgb = parseRGBstring(col);

        if col=="k" || col=="auto"
            color = cmap(cc,:);
            cc = cc + 1;
        elseif numel(rgb)
            color = rgb;
        else
            color = [0.5 0.5 0.5];
        end

        hLine(i) = plot(ax, xdata, ydata(:,i), 'LineWidth', wid, 'Color', color);
    end

    % --- Marqueurs sur frames (corrige timeoffset) ---
    hLine2 = gobjects(0);
    cc = 1;
    markerSize = 10;

    for k = 1:length(layoutOptions.frames)
        fIdx = layoutOptions.frames(k);

        if timeoffset
            xMarker = (fIdx - layoutOptions.frames(1)) * framerate;
            fRel = fIdx - layoutOptions.frames(1) + 1; % <-- index relatif dans ydata tronqué
        else
            xMarker = fIdx * framerate;
            fRel = fIdx;
        end

        if fRel >= 1 && fRel <= size(ydata,1)
            for j = 1:length(hLine)
                yMarker = ydata(fRel, j);
                hLine2(cc) = plot(ax, xMarker, yMarker, 'o', ...
                    'MarkerSize', markerSize, ...
                    'MarkerFaceColor', hLine(j).Color, ...
                    'MarkerEdgeColor', hLine(j).Color);
                hLine2(cc).UserData = struct('LinkedLine', hLine(j));
                cc = cc + 1;
            end
        end
    end

    hLine = [hLine(:); hLine2(:)];
    hold(ax, 'off');

    % --- Labels axes ---
    ylabel(ax, score_wrapDisplayLabel(layoutOptions.plotidxgroup{groupIdx}), ...
        'FontSize', floor(layoutOptions.fontSize), ...
        'FontName', 'Arial', 'Color', layoutOptions.textColor, ...
        'Interpreter', 'none');

    xlabel(ax, 'Time(min)', 'FontName', 'Arial', ...
        'FontSize', floor(layoutOptions.fontSize), ...
        'Color', layoutOptions.textColor);

    % --- Légende ---
    if layoutOptions.legend
        lgd = legend(ax, str);
        set(lgd, 'Color', layoutOptions.background, ...
            'Interpreter', 'none', ...
            'TextColor', layoutOptions.textColor);
    else
        legend(ax, 'off');
    end

    % --- Style axes ---
    set(ax, 'XColor', layoutOptions.textColor, ...
            'YColor', layoutOptions.textColor, ...
            'Box', 'off');
    set(ax, 'Color', layoutOptions.background, ...
            'FontSize', floor(sqrt(scalingFactor)*layoutOptions.fontSize));

    % --- XLim (tracking/auto/bornes) ---
    track = false;
    if layoutOptions.track
        if layoutOptions.mode ~= "Sequence"
            track = true;
        end
    end

    if track
        amin = xMarker - layoutOptions.trackWindow * framerate;
        amax = xMarker + layoutOptions.trackWindow * framerate;
        ax.UserData.xlim = [amin amax];
    else
        if isempty(xbounds) || xbounds=="auto"
            amin = min(xdata);
            if amin>0, amin = 0.95*amin-0.01; else, amin = 1.05*amin-0.01; end

            amax = max(xdata);
            if amax>0, amax = 0.95*amax-0.01; else, amax = 1.05*amax+0.01; end

            ax.UserData.xlim = 'auto';
        else
            xb = str2num(xbounds); %#ok<ST2NM>
            amin = xb(1); amax = xb(2);
            ax.UserData.xlim = [amin amax];
        end
    end
    xlim(ax, [amin amax]);

    % --- Y: si on a une référence categorical => ticks/labels stables ---
    if ~isempty(yTickInfo) && ~isempty(yTickInfo.isLabel) && any(yTickInfo.isLabel) && ~isempty(yTickInfo.ticks)
        yticks(ax, yTickInfo.ticks);
        yticklabels(ax, yTickInfo.labels);
        ylim(ax, [min(yTickInfo.ticks)-0.5, max(yTickInfo.ticks)+0.5]);

        set(ax, 'YTickMode', 'manual', 'YTickLabelMode', 'manual');
        ax.UserData.ylim = 'labels';
    else
        % --- YLim normal (numérique) ---
        if isempty(ybounds) || ybounds=="auto" || isnan(str2num(ybounds)) %#ok<ST2NM>
            ax.UserData.ylim = 'auto';
        else
            yb = str2num(ybounds); %#ok<ST2NM>
            amin = yb(1); amax = yb(2);
            ylim(ax, [amin amax]);
            ax.UserData.ylim = [amin amax];
        end
    end

    % --- XTicks (joli) ---
    amin = min(xdata);
    if amin>0, amin = 0.95*amin-0.01; else, amin = 1.05*amin-0.01; end

    amax = max(xdata);
    if amax>0, amax = 0.95*amax-0.01; else, amax = 1.05*amax+0.01; end

    xlims = [amin amax];
    ticks = niceTicks(xlims(1), xlims(2), 10);
    set(ax, 'XTick', ticks);

    if groupIdx < layoutOptions.ngroup
        set(ax, 'XTickLabel', []);
    else
        xticklabels = arrayfun(@(x) sprintf('%.0f', x), ticks, 'UniformOutput', false);
        set(ax, 'XTickLabel', xticklabels);
    end

    set(ax, 'box', 'off');

else
    % ===========================
    % ======= TRAJ MODE =========
    % ===========================

    if timeoffset
        keep = xdata >= 0;
        ydata = ydata(keep,:);
        xdata = xdata(keep);
    end

    % Y bounds
    if isempty(ybounds) || ybounds=="auto" || isnan(str2num(ybounds)) %#ok<ST2NM>
        ax.UserData.ylim = 'auto';
        amin = min(ydata(:));
        amax = max(ydata(:));
    else
        yb = str2num(ybounds); %#ok<ST2NM>
        amin = yb(1); amax = yb(2);
        ax.UserData.ylim = [amin amax];
    end

    hold(ax, 'on');

    [rgbImage, alphaImage, color] = render_ydata_as_image(ydata, amin, amax, layoutOptions, data, sourceIndex);

    hLine = imagesc(ax, rgbImage, 'AlphaData', alphaImage);
    axis(ax, 'normal');

    set(ax, 'XColor', layoutOptions.textColor, 'YColor', layoutOptions.background, 'Box', 'off');
    set(ax, 'Color', layoutOptions.background, 'FontSize', floor(sqrt(scalingFactor)*layoutOptions.fontSize));

    ylabel(ax, score_wrapDisplayLabel(layoutOptions.plotidxgroup{groupIdx}), ...
        'FontName', 'Arial', 'Color', layoutOptions.textColor, ...
        'Interpreter', 'none', 'FontSize', floor(sqrt(scalingFactor)*layoutOptions.fontSize));

    xlabel(ax, 'Time(min)', 'FontName', 'Arial', ...
        'FontSize', floor(sqrt(scalingFactor)*layoutOptions.fontSize), ...
        'Color', layoutOptions.textColor);

    ylim(ax, [-1, size(rgbImage,1) + 1]);

    if isempty(xbounds) || xbounds=="auto"
        amin = min(xdata);
        if amin>0, amin = 0.95*amin-0.01; else, amin = 1.05*amin-0.01; end

        amax = max(xdata);
        if amax>0, amax = 0.95*amax-0.01; else, amax = 1.05*amax+0.01; end

        ax.UserData.xlim = 'auto';
    else
        xb = str2num(xbounds); %#ok<ST2NM>
        amin = xb(1); amax = xb(2);
        ax.UserData.xlim = [amin amax];
    end

    xlim(ax, [amin amax] / layoutOptions.framerate);

    xlims = layoutOptions.framerate * get(ax, 'XLim');
    ticks = niceTicks(xlims(1), xlims(2), 5);
    set(ax, 'XTick', ticks / layoutOptions.framerate);

    if groupIdx < layoutOptions.ngroup
        set(ax, 'XTickLabel', []);
    else
        xticklabels = arrayfun(@(x) sprintf('%.0f', x), ticks, 'UniformOutput', false);
        set(ax, 'XTickLabel', xticklabels);
    end

    axPos = get(ax, 'Position');
    W = 0.28;
    H = min(axPos(4) * 0.85, max(0.08, 0.055 * size(ydata,2)));

    panelLeft   = axPos(1) + axPos(3) - W - 0.01;
    panelBottom = axPos(2) + axPos(4) - H;

    if layoutOptions.legend
        addHorizontalColorbarLegend(ax.Parent.Parent, ydata, color, [panelLeft, panelBottom, W, H], layoutOptions, str);
    end

    hold(ax, 'off');
end

end


% =======================
% ===== Subfunctions =====
% =======================

function rgb = parseRGBstring(str)
rgb = [];
try
    val = str2num(str); %#ok<ST2NM>
    if isnumeric(val) && numel(val) == 3 && all(val >= 0) && all(val <= 1)
        rgb = val;
    end
catch
    rgb = [];
end
end


function [rgbImage_rescaled, alphaImage_rescaled, colorsOrColormap] = render_ydata_as_image(ydata, minVal, maxVal, layoutOptions, data, dataIndices)

num_series = size(ydata, 2);
baseCmap = eval([layoutOptions.dataColormap '(' num2str(num_series) ')']);
cc = 1;

refColor = zeros(num_series, 3);
useCustomColormap = false(num_series,1);

for i = 1:num_series
    if i <= numel(dataIndices)
        colSpec = data.plotProperties{dataIndices(i), 4};
    else
        colSpec = "auto";
    end

    if strcmp(colSpec, "colormap")
        useCustomColormap(i) = true;
        refColor(i,:) = [0 0 0];
    else
        rgbVal = parseRGBstring(colSpec);
        if strcmp(colSpec, "k") || strcmp(colSpec, "auto")
            refColor(i,:) = baseCmap(cc,:);
            cc = cc + 1;
        elseif numel(rgbVal)==3
            refColor(i,:) = rgbVal;
        else
            refColor(i,:) = [0.5 0.5 0.5];
        end
    end
end

if num_series == 1 && (strcmp(data.plotProperties{dataIndices(1), 4}, "k") || strcmp(data.plotProperties{dataIndices(1), 4}, "auto"))
    refColor = eval([layoutOptions.dataColormap '(256)']);
end

bgColor = parseRGBstring(layoutOptions.background);
if isempty(bgColor) || numel(bgColor) ~= 3
    bgColor = [0 0 0];
end

if strcmp(layoutOptions.dataColormap, 'lines')
    uniqueVals = unique(ydata(:));
    if numel(uniqueVals) < 256
        nSteps = numel(uniqueVals);
    else
        nSteps = 256;
    end
else
    nSteps = 256;
end

gradMap = cell(num_series,1);
for i = 1:num_series
    if useCustomColormap(i)
        gradMap{i} = eval([layoutOptions.colormap '(' num2str(nSteps) ')']);
    else
        gradMap{i} = [linspace(bgColor(1), refColor(i,1), nSteps)', ...
                      linspace(bgColor(2), refColor(i,2), nSteps)', ...
                      linspace(bgColor(3), refColor(i,3), nSteps)'];
    end
end

colorsOrColormap = gradMap;

if strcmp(layoutOptions.mode, "Sequence")
    fadeFrame = -1;
else
    fadeFrame = layoutOptions.frames;
end

N = 60;
[Nframes, nb_col] = size(ydata);
rgbImage = zeros(N, Nframes, 3);

ydataNorm = (ydata - minVal) / (maxVal - minVal);
ydataNorm = min(max(ydataNorm, 0), 1);

if nb_col == 1
    grad = gradMap{1};
    idx = round(ydataNorm * (nSteps - 1)) + 1;
    idx = min(max(idx, 1), nSteps);
    for j = 1:Nframes
        rgbImage(:, j, :) = repmat(reshape(grad(idx(j), :), 1, 1, 3), N, 1);
    end
else
    for s = 1:nb_col
        grad = gradMap{s};
        for j = 1:Nframes
            idx = round(ydataNorm(j, s) * (nSteps - 1)) + 1;
            idx = min(max(idx, 1), nSteps);
            colorPixel = grad(idx, :);
            rgbImage(:, j, :) = rgbImage(:, j, :) + repmat(reshape(colorPixel, 1, 1, 3), N, 1);
        end
    end
    rgbImage = min(rgbImage, 1);
end

RGBtop    = [0.1, 0.1, 0.1];
RGBbottom = [0.8, 0.8, 0.8];
RGBtop = reshape(RGBtop, [1, 3]);
RGBbottom = reshape(RGBbottom, [1, 3]);

numCols = size(rgbImage, 2);
nTop    = round(0.25 * N);
nBottom = round(0.25 * N);
nMiddle = N - nTop - nBottom;

newImg = zeros(size(rgbImage));
for r = 1:N
    rowColors = reshape(rgbImage(r, :, :), [numCols, 3]);
    if r <= nTop
        if nTop > 1
            factor = (r - 1) / (nTop - 1);
        else
            factor = 1;
        end
        targetTop = repmat(RGBtop, [numCols, 1]);
        newLine = (1 - factor) * targetTop + factor * rowColors;
    elseif r <= nTop + nMiddle
        newLine = rowColors;
    else
        r_blend = r - (nTop + nMiddle);
        if nBottom > 1
            t = (r_blend - 1) / (nBottom - 1);
        else
            t = 1;
        end
        targetBottom = repmat(RGBbottom, [numCols, 1]);
        newLine = (1 - t) * rowColors + t * targetBottom;
    end
    newImg(r, :, :) = reshape(newLine, [1, numCols, 3]);
end
rgbImage = newImg;

if isempty(fadeFrame) || ~isscalar(fadeFrame) || ~isnumeric(fadeFrame) || fadeFrame < 0
    fadeFrame = Nframes;
end
fadeFrame = max(1, min(round(fadeFrame), Nframes));
alphaVec = ones(1, Nframes);
if fadeFrame <= Nframes
    alphaVec(fadeFrame:end) = 0.2;
end
alphaImage = repmat(alphaVec, N, 1);

Nfinal = size(ydata, 1);
rgbImage_rescaled = imresize(rgbImage, [N, Nfinal], 'nearest');
alphaImage_rescaled = imresize(alphaImage, [N, Nfinal], 'nearest');
end


function axLegend = addHorizontalColorbarLegend(parentFigOrPanel, ydata, cmap, panelPosition, layoutOptions, varName)

minVal = min(ydata(:), [], 'omitnan');
maxVal = max(ydata(:), [], 'omitnan');

numSeries = numel(cmap);
axLegend = cell(1, numSeries);
subH = 1 / numSeries;

for i = 1:numSeries
    subY = 1 - i * subH;
    pos = [ panelPosition(1), ...
            panelPosition(2) + subY * panelPosition(4), ...
            panelPosition(3), ...
            subH * panelPosition(4) ];

    ax = axes('Parent', parentFigOrPanel, ...
              'Units', 'normalized', ...
              'Position', pos, ...
              'Color', layoutOptions.background);

    currentCmap = cmap{i};
    if ~isa(currentCmap, 'double')
        currentCmap = double(currentCmap);
    end

    nColor = size(currentCmap, 1);
    gradientVal = linspace(0, 1, nColor);
    indices = round(gradientVal * (nColor - 1)) + 1;
    legendRGB = ind2rgb(indices, currentCmap);
    legendRGB = reshape(legendRGB, [1, nColor, 3]);

    imagesc(ax, [minVal, maxVal], [0, 1], legendRGB);
    axis(ax, 'normal');
    ylim(ax, [-0.7, 1.65]);

    posInset = pos;
    marginX = 0.1 * pos(3);
    marginY = 0.2 * pos(4);
    posInset(1) = pos(1) + marginX;
    posInset(2) = pos(2) + marginY;
    posInset(3) = pos(3) - 2*marginX;
    posInset(4) = pos(4) - marginY;
    set(ax, 'Position', posInset);

    ax.XColor = layoutOptions.textColor;
    ax.YColor = layoutOptions.textColor;

    set(ax, 'XTick', []);
    set(ax, 'YTick', []);

    labelText = score_wrapDisplayLabel(varName{i}, 26);

    text(ax, 0.5, 0.98, labelText, ...
        'Units', 'normalized', ...
        'Color', layoutOptions.textColor, ...
        'FontWeight', 'bold', ...
        'FontSize', max(6, floor(0.85 * layoutOptions.fontSize)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', ...
        'Interpreter', 'none', ...
        'BackgroundColor', layoutOptions.background, ...
        'Margin', 1);

    text(ax, 0, 0.05, num2str(minVal, '%.1f'), ...
        'Units', 'normalized', ...
        'Color', layoutOptions.textColor, ...
        'FontSize', max(6, floor(0.8 * layoutOptions.fontSize)), ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'bottom');

    text(ax, 1, 0.05, num2str(maxVal, '%.1f'), ...
        'Units', 'normalized', ...
        'Color', layoutOptions.textColor, ...
        'FontSize', max(6, floor(0.8 * layoutOptions.fontSize)), ...
        'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'bottom');

    axLegend{i} = ax;
end
end


function ticks = niceTicks(xmin, xmax, nticks)
range = xmax - xmin;
rawStep = range / (nticks - 1);

mag = 10^floor(log10(rawStep));
niceSteps = [0,1, 2, 5, 10];
step = mag * niceSteps(find(rawStep <= mag * niceSteps, 1));

tmin = floor(xmin / step) * step;
tmax = ceil(xmax / step) * step;

ticks = tmin:step:tmax;
end
