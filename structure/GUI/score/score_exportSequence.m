function gh = score_exportSequence(dh, gh, rois, opts)
% Print the entire logical canvas, independently of desktop window limits.
[gh, ~] = score_layoutExport(gh, dh, rois, opts);
if isfield(opts,'previewOnly')&&opts.previewOnly, return; end
fig = dh.Figure;
canvas = gh.sequenceLayout.canvasSize;
dpi = get(groot,'ScreenPixelsPerInch');
if isfield(opts,'exportDPI'), dpi=opts.exportDPI; end
fig.PaperUnits = 'inches';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0 0 canvas/dpi];
fig.PaperSize = canvas/dpi;
fig.InvertHardcopy = 'off';
[folder, name] = fileparts(opts.name);
path = fullfile(folder,[name '.pdf']);
drawnow;
if isfield(opts,'exportCancel') && opts.exportCancel()
    error('score:ExportCancelled','Export cancelled.');
end
print(fig,path,'-dpdf','-painters','-r0');
if isfield(opts,'exportProgress'), opts.exportProgress(1); end
fprintf('Sequence saved as PDF: %s\n',path);
end
