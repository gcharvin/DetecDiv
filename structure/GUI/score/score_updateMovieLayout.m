function score_updateMovieLayout(gh,opts,frame)
% Keep moving text and tick labels within the boxes allocated at export start.
if ~isfield(gh,'movieLayout'), return; end
layout = gh.movieLayout;
actual = opts.frames(frame);
if opts.timeOffset, actual = actual-opts.frames(1); end
stamp = sprintf('%g min',actual*opts.framerate);
for h = layout.timeHandles
    if isgraphics(h), h.String = stamp; end
end
for p = layout.plots
    ax = p.ax;
    if ~isempty(p.tickLabels), ax.YTickLabel = p.tickLabels; end
    ticks = linspace(ax.XLim(1),ax.XLim(2),5);
    ax.XTick = ticks;
    ax.XTickLabelRotation = 0;
    if p.index == opts.Ndataseries
        ax.XTickLabel = compose('%.3g',ticks);
    else
        ax.XTickLabel = [];
    end
end
end
