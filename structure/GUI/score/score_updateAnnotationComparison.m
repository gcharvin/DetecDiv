function score_updateAnnotationComparison(gh, rois, opts, newframe)
% Refresh each mask independently; base-channel overlay remains orthogonal.
isDisplay = strcmpi(opts.mode,'display');
if isDisplay, opts.frames = newframe; frameIndex = 1; else, frameIndex = newframe; end
previousROI = 0;
previousRow = 0;
for p = gh.comparisonPanels
    if p.roi ~= previousROI || p.row ~= previousRow
        rowOpts = score_annotationRowOptions(opts, p.row);
        [images, contours, overlay, alpha] = score_makeComposite(rois(p.roi), frameIndex, rowOpts);
        previousROI = p.roi;
        previousRow = p.row;
    end
    h = gh.imgHandles(p.tile);
    if isempty(h) || ~isgraphics(h) || ~isa(h,'matlab.graphics.primitive.Image')
        error('score_updateRender:InvalidImageHandle', ...
            'Stored comparison image handle is no longer valid.');
    end
    if opts.overlay, h.CData = images; else, h.CData = images(:,:,:,p.channel); end
    if isDisplay
        hOverlay = gh.overlayHandles(p.tile);
        hOverlay.CData = overlay;
        hOverlay.AlphaData = alpha;
    else
        if isKey(gh.vectorHandles,p.tile), delete(gh.vectorHandles(p.tile)); end
        [ht,hv] = score_displayVectorGraphics(h.Parent, frameIndex, p.channel, contours, rowOpts);
        gh.vectorHandles(p.tile) = [ht hv];
        if p.channel == 1, score_drawMovieEventText(h.Parent, opts, opts.frames(frameIndex)); end
    end
end
end
