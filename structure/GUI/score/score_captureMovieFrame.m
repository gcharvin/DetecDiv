function rgb = score_captureMovieFrame(fig, graphicsHandles)
% Render the complete export canvas, independently of the desktop viewport.
canvas = graphicsHandles.movieLayout.canvasSize;
dpi = get(groot,'ScreenPixelsPerInch');
fig.PaperUnits = 'inches';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0 0 canvas/dpi];
fig.PaperSize = canvas/dpi;
fig.InvertHardcopy = 'off';
rgb = print(fig,'-RGBImage','-r0');
actual = [size(rgb,2) size(rgb,1)];
if ~isequal(actual,canvas)
    % Do not silently crop a viewport-sized frame and lose image rows.
    error('score:MovieCanvasSize', ...
        'Movie capture returned %d x %d pixels; the full canvas requires %d x %d.', ...
        actual(1),actual(2),canvas(1),canvas(2));
end
end
