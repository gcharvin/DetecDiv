function scoreHistogramTest()
%SCOREHISTOGRAMTEST Legacy Score consumes the shared statistics unchanged.
source = roi('Histogram',[]); source.image = uint16(reshape(1:100,10,10));
source.channelid = 1; source.display.channel = {'Signal'};
source.display.intensity = [1 1]; source.display.rgb = [1 1 1];
source.display.frame = 1; source.display.displaylim = [10;80]/65535;
pixels = source.image; metadata = source.display;
figure = uifigure('Visible','off'); cleanup = onCleanup(@()delete(figure));
axes = uiaxes(figure);
app = struct(); app.content.ROIList = {source}; app.UIROITable.Data = {true};
app.UIChannelTable.Data = {true}; app.UIDisplayAxes = axes;
score_updateHistogram(app,'slow');
lines = findall(axes,'Type','line'); assert(isscalar(lines));
stats = score_histogramData(pixels);
assert(isequal(lines.XData,stats.edges(1:end-1)));
counts = lines.YData; counts(isnan(counts)) = 0;
assert(isequal(counts,stats.counts) && sum(counts) == 100);
limits = findall(axes,'Type','constantline');
assert(isequal(sort([limits.Value]),[10 80]));
assert(isequal(source.image,pixels) && isequal(source.display,metadata));
disp('Score histogram test passed: legacy curves, counts, levels and unchanged source metadata.');
end
