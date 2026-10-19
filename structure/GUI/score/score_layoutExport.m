function [gh, opts] = score_layoutExport(gh, dh, rois, opts)
% Lay out an export in pixels, with separate boxes for every kind of text.
% Keep the original tile keys for frame updates, but detach the axes from
% tiledlayout: long categorical ticks must not shrink the microscopy images.
fig = dh.Figure;
fig.SizeChangedFcn = [];
setappdata(fig,'ScoreMovieTextColor',opts.textColor);
isSequence = strcmpi(opts.mode,'sequence');
prefix = 'ScoreMovie';
if isSequence, prefix = 'ScoreSequence'; end
[nMasks, maskIndices] = score_annotationRows(opts);
hasPhysicalChannels = any(~cellfun(@iscell,opts.levels));
nChannels = opts.Nchannel;
if opts.overlay, nChannels = 1; end
nColumns = nChannels;
if isSequence, nColumns = numel(opts.frames); end
nROI = min(numel(rois), opts.Nrow*opts.Ncol);
imageW = max(160, round(opts.tileW*opts.Nbrick));
imageH = max(80, round(imageW*opts.tileH/max(1,opts.tileW)));
font = max(11, min(round(opts.fontSize*96/72), floor(imageW/12)));
tickFont = max(10, font-1);
gap = max(12, round(font));
maskGutter = 0;
if ~isempty(maskIndices), maskGutter = 3*font + gap; end
channelGutter = 0;
if isSequence && ~opts.overlay && hasPhysicalChannels, channelGutter = 3*font + gap; end
imageWidth = nColumns*imageW + (nColumns-1)*gap;

plots = struct('tile',{},'roi',{},'index',{},'ax',{},'heading',{}, ...
    'tickLabels',{},'legend',{},'legendLabels',{},'height',{});
tickGutter = 4*tickFont;
for r = 1:nROI
    for ds = 1:opts.Ndataseries
        tile = localDataTile(dh, opts, r, ds);
        if ~isKey(gh.dataAxes,tile), continue; end
        ax = gh.dataAxes(tile);
        labels = {};
        if isstruct(ax.UserData) && isfield(ax.UserData,'ylim') && ...
                isequal(ax.UserData.ylim,'labels')
            labels = cellstr(string(ax.YTickLabel));
            labels = cellfun(@(s) score_wrapDisplayLabel(s,20), labels, 'UniformOutput',false);
            longest = max(cellfun(@(s) max(strlength(splitlines(string(s)))),labels));
            tickGutter = max(tickGutter, ceil(longest*tickFont*0.65)+gap);
        end
        legendHandle = ax.Legend;
        legendLabels = {};
        if ~isempty(legendHandle) && isgraphics(legendHandle)
            legendLabels = cellstr(string(legendHandle.String));
            if numel(legendLabels) <= 1
                delete(legendHandle); legendHandle = [];
            end
        end
        heading = string(opts.plotidxgroup{ds});
        bodyH = max(100, round(imageH/max(1,opts.Nbrick)));
        if ~isempty(labels)
            lineCount = max(cellfun(@(s) numel(splitlines(string(s))),labels));
            bodyH = max(bodyH,ceil((numel(labels)+1)*(lineCount*tickFont*1.3+5)));
        end
        plots(end+1) = struct('tile',tile,'roi',r,'index',ds,'ax',ax, ...
            'heading',heading,'tickLabels',{labels},'legend',legendHandle, ...
            'legendLabels',{legendLabels},'height',bodyH); %#ok<AGROW>
    end
end

left = max(maskGutter+channelGutter,tickGutter) + gap;
plotW = max(imageWidth,320);
imageLeft = left+(plotW-imageWidth)/2;
blockW = left + plotW + gap;
% The title and the column labels have separate vertical bands, including
% when either wraps onto several lines.
headerH = 7*font;
imageBlockH = nMasks*imageH + (nMasks-1)*gap;
maskBlockH = imageH;
if isSequence
    maskBlockH = nChannels*imageH + (nChannels-1)*gap;
    imageBlockH = nMasks*maskBlockH + (nMasks-1)*2*gap;
end
plotHeights = zeros(1,opts.Ndataseries);
for p = plots
    legendH = 0;
    if ~isempty(p.legend), [~,~,legendH] = localLegend(p.legendLabels,tickFont,plotW); end
    plotHeights(p.index) = max(plotHeights(p.index), p.height + 3.4*font + legendH + gap);
end
bottomH = 3*font + gap;
blockH = headerH + imageBlockH + gap + sum(plotHeights) + bottomH;
canvas = ceil([opts.Ncol*blockW,opts.Nrow*blockH]/2)*2;
fig.Units = 'pixels';
fig.WindowState = 'normal';
pos = fig.Position; pos(3:4) = canvas; fig.Position = pos;
fig.InvertHardcopy = 'off';
opts.movieTextPixels = font;
layout = struct('timeHandles',gobjects(0),'plots',plots, ...
    'canvasSize',canvas,'hideStamp',logical(opts.hideStamp),'fontPixels',font);

for r = 1:nROI
    x0 = mod(r-1,opts.Ncol)*blockW;
    yTop = canvas(2)-floor((r-1)/opts.Ncol)*blockH;
    header = localTextAxes(fig,[x0+left yTop-headerH plotW headerH]);
    titleParts = strings(0);
    if ~isempty(opts.title), titleParts(end+1) = string(opts.title); end %#ok<AGROW>
    if opts.ROITitle, titleParts(end+1) = string(rois(r).id); end %#ok<AGROW>
    titleText = strjoin(titleParts,' | ');
    titleW = plotW;
    if ~isSequence && ~opts.hideStamp, titleW = max(80,plotW-100); end
    localText(header,[0 headerH-font],titleText,font+1,[titleW 2*font], ...
        'HorizontalAlignment','left','VerticalAlignment','top','Tag',[prefix 'Header']);
    if ~isSequence && ~opts.hideStamp
        h = localText(header,[plotW headerH-font],'',font,[96 2*font], ...
            'HorizontalAlignment','right','VerticalAlignment','top','Tag','ScoreMovieTimestamp');
        layout.timeHandles(end+1) = h;
    end
    for col = 1:nColumns
        label = "";
        if isSequence
            if ~opts.hideStamp
                frame = opts.frames(col);
                if opts.timeOffset, frame = frame-opts.frames(1); end
                label = sprintf('%g min',frame*opts.framerate);
            end
        elseif ~opts.overlay && hasPhysicalChannels
            label = localChannelLabel(opts,col);
        end
        columnTag = 'ScoreMovieChannelLabel';
        if isSequence, columnTag = 'ScoreSequenceTimestamp'; end
        localText(header,[imageLeft-left+(col-1)*(imageW+gap)+imageW/2 font],label,font, ...
            [imageW-8 2.5*font],'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom','Tag',columnTag);
    end
    for row = 1:nMasks
        maskGap = gap;
        if isSequence, maskGap = 2*gap; end
        y = yTop-headerH-row*maskBlockH-(row-1)*maskGap;
        if ~isempty(maskIndices)
            mask = maskIndices(row);
            label = string(opts.channel{mask});
            if isfield(opts,'channelLabel') && mask <= numel(opts.channelLabel)
                label = string(opts.channelLabel{mask});
            end
            labelAxes = localTextAxes(fig,[x0+imageLeft-channelGutter-maskGutter y maskGutter-gap maskBlockH]);
            localText(labelAxes,[(maskGutter-gap)/2 maskBlockH/2],label,font, ...
                [maskBlockH-12 maskGutter-gap],'Rotation',90, ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'Tag','AnnotationRowLabel');
        end
        for ch = 1:nChannels
            imageY = y;
            if isSequence
                imageY = y+(nChannels-ch)*(imageH+gap);
                if ~opts.overlay && hasPhysicalChannels
                    labelAxes = localTextAxes(fig,[x0+imageLeft-channelGutter imageY channelGutter-gap imageH]);
                    localText(labelAxes,[(channelGutter-gap)/2 imageH/2],localChannelLabel(opts,ch),font, ...
                        [imageH-12 channelGutter-gap],'Rotation',90, ...
                        'HorizontalAlignment','center','VerticalAlignment','middle', ...
                        'Tag','ScoreSequenceChannelLabel');
                end
            end
            nFrames = 1;
            if isSequence, nFrames = nColumns; end
            for f = 1:nFrames
                tile = localImageTile(dh,opts,r,row,ch,f,nChannels,isSequence);
                if ~isKey(gh.imgHandles,tile), continue; end
                ax = gh.imgHandles(tile).Parent;
                localClearImageText(gh,tile,ax,font);
                ax.Parent = fig;
                ax.Units = 'pixels';
                ax.PositionConstraint = 'innerposition';
                col = ch;
                if isSequence, col = f; end
                ax.Position = [x0+imageLeft+(col-1)*(imageW+gap) imageY imageW imageH];
                if ~isstruct(ax.UserData), ax.UserData = struct(); end
                ax.UserData.scoreMovieImageSize = [imageW imageH];
                ax.FontUnits = 'pixels'; ax.FontSize = font;
                if isSequence && ch == 1
                    score_drawMovieEventText(ax,opts,opts.frames(f));
                end
            end
        end
    end
    y = yTop-headerH-imageBlockH-gap;
    for k = find([plots.roi] == r)
        p = plots(k);
        ax = p.ax;
        ax.Parent = fig; ax.Units = 'pixels';
        ax.PositionConstraint = 'innerposition';
        ax.FontUnits = 'pixels'; ax.FontSize = tickFont;
        ax.XTickLabelRotation = 0;
        ax.XLabel.String = ''; ax.YLabel.String = ''; ax.Title.String = '';
        headingH = 3.4*font;
        headingAxes = localTextAxes(fig,[x0+left y-headingH plotW headingH]);
        localText(headingAxes,[0 headingH-font/2],p.heading,font, ...
            [plotW headingH-font/2],'HorizontalAlignment','left', ...
            'VerticalAlignment','top','Tag',[prefix 'DataLabel']);
        legendH = 0;
        if ~isempty(p.legend) && isgraphics(p.legend)
            [legendLabels,legendCols,legendH] = localLegend(p.legendLabels,tickFont,plotW);
            lg = p.legend;
            lg.Parent = fig;
            lg.FontSize = tickFont*72/96;
            lg.NumColumns = legendCols;
            lg.Orientation = 'horizontal'; lg.Interpreter = 'none';
            lg.String = legendLabels;
            lg.Units = 'pixels';
            lg.Position = [x0+left y-headingH-legendH plotW legendH];
        end
        bodyTop = y-headingH-legendH;
        ax.Position = [x0+left bodyTop-p.height plotW p.height];
        if p.index == opts.Ndataseries
            ax.XLabel.String = 'Time (min)';
            ax.XLabel.FontUnits = 'pixels'; ax.XLabel.FontSize = tickFont;
        end
        y = y-plotHeights(p.index);
    end
end
% Per-frame timestamps live in the header, outside the microscopy images.
opts.hideStamp = true;
if isSequence
    gh.sequenceLayout = layout;
    for p = plots
        if ~isempty(p.tickLabels), p.ax.YTickLabel = p.tickLabels; end
        ticks = linspace(p.ax.XLim(1),p.ax.XLim(2),5);
        p.ax.XTick = ticks;
        if p.index == opts.Ndataseries
            p.ax.XTickLabel = compose('%.3g',ticks);
        else
            p.ax.XTickLabel = [];
        end
    end
else
    gh.movieLayout = layout;
    score_updateMovieLayout(gh,opts,1);
end
% Figure windows can be constrained by the desktop or an inherited maximized
% state. Express the entire logical canvas in normalized coordinates so
% off-screen printing can render every row independently of window size.
for type = {'axes','legend'}
    for h = reshape(findall(fig,'Type',type{1}),1,[])
        if ~isequal(h.Parent,fig), continue; end
        h.Units = 'pixels';
        position = h.Position;
        h.Units = 'normalized';
        h.Position = position ./ canvas([1 2 1 2]);
    end
end
drawnow;
end

function [labels,columns,height] = localLegend(labels,font,width)
columns = min(2,numel(labels));
maxChars = max(8,floor((width/columns-35)/(0.6*font)));
labels = cellfun(@(s)score_wrapDisplayLabel(replace(string(s),newline,' '),maxChars), ...
    labels,'UniformOutput',false);
lines = max(cellfun(@(s)numel(splitlines(string(s))),labels));
height = ceil(numel(labels)/columns)*(lines*font*1.35+8);
end

function tile = localImageTile(dh,opts,r,row,ch,f,nChannels,isSequence)
localRow = row-1;
localCol = ch-1;
if isSequence
    localRow = (row-1)*nChannels+ch-1;
    localCol = f-1;
end
tile = (floor((r-1)/opts.Ncol)*dh.ROI_rows+localRow*opts.Nbrick)*dh.MasterCols + ...
    mod(r-1,opts.Ncol)*dh.ROI_cols+localCol*opts.Nbrick+1;
end

function label = localChannelLabel(opts,ch)
label = "";
if ch <= numel(opts.channel), label = string(opts.channel{ch}); end
if isfield(opts,'channelLabel') && ch <= numel(opts.channelLabel)
    label = string(opts.channelLabel{ch});
end
end

function tile = localDataTile(dh,opts,r,ds)
[~,~,imageRows] = score_annotationRows(opts);
tile = (floor((r-1)/opts.Ncol)*dh.ROI_rows+imageRows+ds-1)*dh.MasterCols + ...
    mod(r-1,opts.Ncol)*dh.ROI_cols+1;
end

function ax = localTextAxes(fig,position)
ax = axes('Parent',fig,'Units','pixels','Position',position, ...
    'XLim',[0 position(3)],'YLim',[0 position(4)],'Visible','off', ...
    'HitTest','off','PickableParts','none');
end

function h = localText(ax,position,label,font,box,varargin)
% Fit with actual renderer extents, including rotation and line wrapping.
rotation = 0;
if any(strcmp(varargin,'Rotation')), rotation = varargin{find(strcmp(varargin,'Rotation'),1)+1}; end
maxChars = max(8,floor(box(1)/(0.6*font)));
color = getappdata(ax.Parent,'ScoreMovieTextColor');
if isempty(color), color = [1 1 1]; end
h = text(ax,position(1),position(2),score_wrapDisplayLabel(label,maxChars), ...
    'FontUnits','pixels','FontSize',font,'Interpreter','none', ...
    'Color',color,'Clipping','off',varargin{:});
extent = h.Extent;
limits = box;
if rotation == 90, limits = fliplr(box); end
while (extent(3) > limits(1) || extent(4) > limits(2)) && h.FontSize > 8
    h.FontSize = h.FontSize-0.5;
    extent = h.Extent;
end
end

function localClearImageText(gh,tile,ax,font)
keep = [ax.Title ax.XLabel ax.YLabel ax.ZLabel];
if isKey(gh.scaleBarHandles,tile)
    scales = gh.scaleBarHandles(tile);
    keep = [keep scales(isgraphics(scales,'text'))];
    for h = scales(isgraphics(scales,'text'))
        h.FontUnits = 'pixels'; h.FontSize = max(8,font-2);
    end
end
labels = findall(ax,'Type','text');
delete(labels(~ismember(labels,keep)));
ax.Title.String = ''; ax.YLabel.String = ''; ax.XLabel.String = '';
ax.YLabel.Tag = '';
if isKey(gh.vectorHandles,tile)
    h = gh.vectorHandles(tile);
    gh.vectorHandles(tile) = h(isgraphics(h));
end
end
