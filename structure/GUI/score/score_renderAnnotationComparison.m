function gh = score_renderAnnotationComparison(dh, rois, opts)
% Shared comparison renderer for interactive display, PDF sequences and movies.
fields = {'imgHandles','lineHandles','dataAxes','overlayHandles', ...
    'vectorHandles','textHandles','scaleBarHandles','lineageHandles'};
for k = 1:numel(fields)
    gh.(fields{k}) = containers.Map('KeyType','double','ValueType','any');
end
gh.axesLink = [];
gh.comparisonPanels = struct('tile',{},'roi',{},'row',{},'channel',{},'frame',{});
[nRows, ~, imageRows] = score_annotationRows(opts);
isSequence = strcmpi(opts.mode, 'sequence');
isDisplay = strcmpi(opts.mode, 'display');
% Managed axes labels need an outer margin, including in movie exports.
dh.masterTiledLayout.Padding = 'tight';
nChannels = opts.Nchannel;
if opts.overlay, nChannels = 1; end
nFrames = 1;
if isSequence, nFrames = numel(opts.frames); end
axesToLink = gobjects(0);
nROI = min(numel(rois), opts.Nrow * opts.Ncol);
if isDisplay, nROI = 1; end
for r = 1:nROI
    roiRow = floor((r-1)/opts.Ncol);
    roiCol = mod(r-1, opts.Ncol);
    if isDisplay, roiRow = 0; roiCol = 0; end
    for row = 1:nRows
        rowOpts = score_annotationRowOptions(opts, row);
        for f = 1:nFrames
            [imageData, contours, overlay, alpha] = score_makeComposite(rois(r), f, rowOpts);
            for ch = 1:nChannels
                if isSequence
                    localRow = ((row-1)*nChannels + ch-1)*opts.Nbrick;
                    localCol = (f-1)*opts.Nbrick;
                else
                    localRow = (row-1)*opts.Nbrick;
                    localCol = (ch-1)*opts.Nbrick;
                end
                tile = (roiRow*dh.ROI_rows + localRow)*dh.MasterCols + ...
                    roiCol*dh.ROI_cols + localCol + 1;
                ax = nexttile(dh.masterTiledLayout, tile, [opts.Nbrick opts.Nbrick]);
                if opts.overlay, img = imageData; else, img = imageData(:,:,:,ch); end
                gh.imgHandles(tile) = imshow(img, 'Parent', ax);
                ax.UserData.annotationChannel = rowOpts.annotationChannel;
                overlayAxes = ax;
                if isDisplay
                    ax.HitTest = 'off';
                    overlayAxes = axes('Parent', dh.Figure, 'Position', ax.Position, ...
                        'Color','none','XTick',[],'YTick',[], 'HitTest','off');
                    h = imshow(overlay, 'Parent', overlayAxes);
                    overlayAxes.UserData.annotationChannel = rowOpts.annotationChannel;
                    h.Tag = 'IndexedOverlay';
                    h.UserData.annotationChannel = rowOpts.annotationChannel;
                    h.AlphaData = alpha;
                    h.AlphaDataMapping = 'none';
                    gh.overlayHandles(tile) = h;
                    axesToLink = [axesToLink ax overlayAxes]; %#ok<AGROW>
                else
                    [ht, hv] = score_displayVectorGraphics(ax, f, ch, contours, rowOpts);
                    gh.vectorHandles(tile) = [ht hv];
                    if ch == 1, score_drawMovieEventText(ax, opts, opts.frames(f)); end
                end
                if ~isSequence || f == nFrames
                    scales = gobjects(0);
                    if opts.overlay, scaleChannels = find(opts.scale); else, scaleChannels = ch; end
                    for s = 1:numel(scaleChannels)
                        scales = [scales score_drawChannelScaleBar(overlayAxes, opts, ...
                            scaleChannels(s), s, numel(scaleChannels))]; %#ok<AGROW>
                    end
                    if ~isempty(scales), gh.scaleBarHandles(tile) = scales; end
                end
                if (~isSequence && ch == 1) || (isSequence && f == 1)
                    label = rowOpts.annotationChannel;
                    maskIndex = find(string(opts.channel) == label, 1);
                    if isfield(opts,'channelLabel') && maskIndex <= numel(opts.channelLabel)
                        label = string(opts.channelLabel{maskIndex});
                    end
                    if ~isDisplay && opts.ROITitle
                        label = string(rois(r).id) + " | " + label;
                    end
                    if ~isDisplay && ~isempty(opts.title)
                        label = string(opts.title) + " | " + label;
                    end
                    ylabel(ax, score_wrapDisplayLabel(label, 20), ...
                        'Rotation',90,'Visible','on', ...
                        'Color',opts.textColor, ...
                        'FontSize',max(1,floor(sqrt(opts.scalingFactor)*opts.fontSize)), ...
                        'Interpreter','none','Tag','AnnotationRowLabel');
                end
                if ~opts.overlay && (~isSequence || f == 1)
                    title(ax, score_wrapDisplayLabel(localLabel(opts,ch),24), ...
                        'Color',opts.textColor,'Interpreter','none','FontWeight','normal');
                end
                gh.comparisonPanels(end+1) = struct('tile',tile,'roi',r, ...
                    'row',row,'channel',ch,'frame',f);
            end
        end
    end
    if opts.Ndataseries > 0 && ~isempty(rois(r).data)
        for ds = 1:opts.Ndataseries
            tile = (roiRow*dh.ROI_rows + imageRows + ds-1)*dh.MasterCols + roiCol*dh.ROI_cols + 1;
            ax = nexttile(dh.masterTiledLayout, tile, [1 dh.ROI_cols]);
            gh.lineHandles(tile) = score_displayDataPanel(ax, ds, opts, rois(r));
            gh.dataAxes(tile) = ax;
        end
    end
end
if numel(axesToLink) > 1
    gh.axesLink = linkprop(axesToLink, {'XLim','YLim'});
end
score_syncOverlayAxes(gh);
refreshLineageOverlays(gh, rois, opts, dh, opts.frames(1:nFrames));
end

function label = localLabel(opts, ch)
label = "";
if ch <= numel(opts.channel), label = string(opts.channel{ch}); end
if isfield(opts,'channelLabel') && ch <= numel(opts.channelLabel)
    label = string(opts.channelLabel{ch});
end
end
