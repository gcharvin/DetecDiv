function gh = score_exportSequence(dh, gh, rois, opts)
% Print the entire logical canvas, independently of desktop window limits.
[gh, ~] = score_layoutExport(gh, dh, rois, opts);
fig = dh.Figure;
canvas = gh.sequenceLayout.canvasSize;
dpi = get(groot,'ScreenPixelsPerInch');
fig.PaperUnits = 'inches';
fig.PaperPositionMode = 'manual';
fig.PaperPosition = [0 0 canvas/dpi];
fig.PaperSize = canvas/dpi;
fig.InvertHardcopy = 'off';
[folder, name] = fileparts(opts.name);
path = fullfile(folder,[name '.pdf']);
drawnow;
print(fig,path,'-dpdf','-painters','-r0');
fprintf('Sequence saved as PDF: %s\n',path);
end
