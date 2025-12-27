function out = batonnets_eventsCompare(out, roiListAll, roiListShown, idxShown, dsKeys, args, H, W, Gcmp, Groi)

% batonnets_compareEvents
% Use GUI-defined event rules (name/type/from/to) to detect transitions and
% render an Events figure in Compare mode (two dsKeys).
%
% Called from batonnets_proceedRender when doCompare == true.

if numel(dsKeys) ~= 2
    return;
end

% ---- normalize map ----
rulesByKey = args.EventRulesByKey;
if isempty(rulesByKey)
    rulesByKey = containers.Map('KeyType','char','ValueType','any');
elseif ~isa(rulesByKey,'containers.Map')
    error('args.EventRulesByKey must be a containers.Map(char -> struct array rules).');
end

% ---- collect events for ALL rois (keeps full info in out) ----
out.events = localCollectAllEvents(roiListAll, dsKeys, rulesByKey);

% ---- render events figure (only shown subset) ----
out = localRenderEventsFigure(out, roiListShown, idxShown, dsKeys, H, W, Gcmp, Groi,args);

matchMaxDtFrames = 10; % à ajuster
if isfield(args,'MatchMaxDtFrames') && ~isempty(args.MatchMaxDtFrames)
    matchMaxDtFrames = args.MatchMaxDtFrames;
end

out = localPlotMatchStats(out, roiListShown, idxShown, matchMaxDtFrames);

end

% ======================================================================
% Local helpers
% ======================================================================

function E = localCollectAllEvents(roiListAll, dsKeys, rulesByKey)
nR  = numel(roiListAll);
nDS = numel(dsKeys);

E = repmat(struct('events',[],'nFrames',0,'roiLabel',"", 'dsKey',""), nR, nDS);

for iDS = 1:nDS
    dsKey   = dsKeys(iDS);
    keyChar = char(dsKey);

    rulesGUI = struct('name',{},'type',{},'from',{},'to',{});
    if ~isempty(rulesByKey) && isKey(rulesByKey, keyChar)
        rulesGUI = rulesByKey(keyChar);
    end

    % convert GUI rules -> internal rules with color/marker/linewidth
    rules = localConvertGUIRules(rulesGUI);

    for iR = 1:nR
        rr = roiListAll(iR).roiObj;

        % ensure data loaded if needed
        needLoad = true;
        try
            if isprop(rr,'data') && ~isempty(rr.data) && ~isempty(rr.data(1).data)
                needLoad = false;
            end
        end
        if needLoad
            try, if ismethod(rr,'load'), rr.load('data'); end, catch, end
        end

        seq = localGetSequenceForKey(rr, dsKey);

        E(iR,iDS).dsKey = string(dsKey);
        try
            E(iR,iDS).roiLabel = string(roiListAll(iR).label);
        catch
            E(iR,iDS).roiLabel = "ROI " + iR;
        end

        if isempty(seq)
            E(iR,iDS).events  = struct('frame',{},'name',{},'color',{},'marker',{},'linewidth',{});
            E(iR,iDS).nFrames = 0;
        else
            E(iR,iDS).nFrames = numel(seq);
            E(iR,iDS).events  = localDetectEventsFromTransitions(seq, rules);
        end
    end
end
end

function rules = localConvertGUIRules(rulesGUI)
% GUI rules fields: name,type,from,to
% Output rules fields: From,To,Name,Color,Marker,LineWidth

% canonical empty struct (ALL fields present)
emptyRule = struct( ...
    'From',     "", ...
    'To',       "", ...
    'Name',     "", ...
    'Color',    [0 0 0], ...
    'Marker',   '|', ...
    'LineWidth', 2);

% start empty
rules = repmat(emptyRule, 0, 1);

if isempty(rulesGUI)
    return;
end

names = strings(0,1);

for i = 1:numel(rulesGUI)

    % robust field access (in case some fields missing)
    fr = "";
    to = "";
    nm = "";

    try, if isfield(rulesGUI(i),'from'), fr = string(rulesGUI(i).from); end, catch, end
    try, if isfield(rulesGUI(i),'to'),   to = string(rulesGUI(i).to);   end, catch, end
    try, if isfield(rulesGUI(i),'name'), nm = string(rulesGUI(i).name); end, catch, end

    fr = strtrim(fr);
    to = strtrim(to);
    nm = strtrim(nm);

    % skip invalid
    if strlength(fr)==0 || strlength(to)==0
        continue;
    end

    if strlength(nm)==0
        nm = fr + "->" + to;
    end

    r = emptyRule;          % IMPORTANT: same fields as rules
    r.From = fr;
    r.To   = to;
    r.Name = nm;

    rules(end+1,1) = r; %#ok<AGROW>
    names(end+1,1) = nm; %#ok<AGROW>
end

if isempty(rules)
    return;
end

% stable colormap by unique names
u = unique(names, 'stable');
K = max(2, numel(u));
cmap = lines(K);

for i = 1:numel(rules)
    k = find(u == string(rules(i).Name), 1, 'first');
    rules(i).Color = cmap(k,:);
end
end


function ev = localDetectEventsFromTransitions(seqLabels, rules)
L = localToStringLabels(seqLabels);
L = strtrim(L);          % <- IMPORTANT
L = lower(L);   
L = L(:);
n = numel(L);

u = unique(L);
fprintf("[eventsCompare] unique labels (first 10): %s\n", strjoin(u(1:min(10,end)), ", "));


ev = struct('frame',{},'name',{},'color',{},'marker',{},'linewidth',{});
if n < 2 || isempty(rules), return; end

% sanitize empty
isEmpty = (strlength(L)==0);
L(isEmpty) = "<missing>";

prev = L(1:end-1);
curr = L(2:end);

for k = 1:numel(rules)
    fr = lower(strtrim(string(rules(k).From)));
to = lower(strtrim(string(rules(k).To)));

fprintf("[eventsCompare] rule %d: '%s' -> '%s'\n", k, fr, to);


    hit = (prev == fr) & (curr == to);
    idx = find(hit) + 1; % event at entry into "To"

    for ii = 1:numel(idx)
        e.frame = idx(ii);
        e.name = string(rules(k).Name);
        e.color = rules(k).Color;
        e.marker = rules(k).Marker;
        e.linewidth = rules(k).LineWidth;
        ev(end+1) = e; %#ok<AGROW>
    end
end
end


function out = localRenderEventsFigure(out, roiListShown, idxShown, dsKeys, H, W, Gcmp, Groi,args)

dsKeyA = dsKeys(1);
dsKeyB = dsKeys(2);

[seqA, TmaxA] = localCollectSequences(roiListShown, dsKeyA);
[seqB, TmaxB] = localCollectSequences(roiListShown, dsKeyB);

absA = localSeqCellIsAbsent(seqA);
absB = localSeqCellIsAbsent(seqB);
keep = ~(absA | absB);

if ~any(keep)
    fe = figure('Name','Batonnets - Events (compare)','Color','w');
    ax = axes('Parent', fe);
    text(ax, 0.5, 0.5, "No comparable data", 'Units','normalized', 'HorizontalAlignment','center');
    out.eventsFigure = fe;
    return;
end

roiListShown = roiListShown(keep);
idxShown     = idxShown(keep);
seqA         = seqA(keep);
seqB         = seqB(keep);

Tmax = max(localMaxLen(seqA), localMaxLen(seqB));
if Tmax <= 0
    fe = figure('Name','Batonnets - Events (compare)','Color','w');
    ax = axes('Parent', fe);
    text(ax, 0.5, 0.5, "No data", 'Units','normalized', 'HorizontalAlignment','center');
    out.eventsFigure = fe;
    return;
end

% ----- IMPORTANT: integer geometry -----
W  = max(1, round(W));
Tw = max(1, round(Tmax * W));

nROI = numel(roiListShown);
HperROI = 2*H + Gcmp;
Htot = nROI*HperROI + (nROI-1)*Groi;

fe = figure('Name','Batonnets - Events (compare)','Color','w');
out.eventsFigure = fe;
ax = axes('Parent', fe);

ax.YDir = 'normal';
ax.Box  = 'off';
ax.Visible = 'on';
ax.Clipping = 'off';

% background blanc
ax.Color = 'w';

hold(ax,'on');

% base image (transparent)
Cbase = NaN(Htot, Tw);
A = ~isnan(Cbase); % false
imagesc(ax, [0.5 Tw-0.5], [1 Htot], Cbase, 'AlphaData', A);

% lock axes early
xlim(ax, [0 Tw]);
ylim(ax, [0.5 Htot+0.5]);
ax.XLimMode = 'manual';
ax.YLimMode = 'manual';
axis(ax,'manual');

xlabel(ax, "Frame");

ax.YTick = localRoiPairCenters(nROI, H, Gcmp, Groi);
ax.YTickLabel = cellstr(string({roiListShown.label}));
ax.TickLabelInterpreter = 'none';

title(ax, "Events (compare): " + dsKeys(1) + " ↔ " + dsKeys(2), ...
    'Interpreter','none', 'FontWeight','bold');

% defaults
eventWidthFrames = 1;
if isfield(args,'EventWidthFrames') && ~isempty(args.EventWidthFrames)
    eventWidthFrames = args.EventWidthFrames;
end

matchMaxDtFrames = 10; % à ajuster
if isfield(args,'MatchMaxDtFrames') && ~isempty(args.MatchMaxDtFrames)
    matchMaxDtFrames = args.MatchMaxDtFrames;
end

[rgbEv, alphaEv, dtAll] = localBuildEventsOverlayMatched( ...
    out.events, idxShown, Tmax, H, W, Gcmp, Groi, nROI, eventWidthFrames, matchMaxDtFrames);

% interval overlay BW (white->black)
maxDurDiffForBlack = 10;
if isfield(args,'IntervalMaxDurDiffForBlack') && ~isempty(args.IntervalMaxDurDiffForBlack)
    maxDurDiffForBlack = args.IntervalMaxDurDiffForBlack;
end

[rgbInt, alphaInt, durDiffAll, dtStartAll, durTestAll, durRefAll, matchedLinkFramesAll] = localBuildIntervalsOverlayBW( ...
    out.events, idxShown, Tmax, H, W, Gcmp, Groi, nROI, matchMaxDtFrames, maxDurDiffForBlack);

out.intervalDurDiffAll = durDiffAll;       % matched only
out.intervalDtAll      = dtStartAll;       % can be empty
out.intervalDurTestAll = durTestAll;       % ALL
out.intervalDurRefAll  = durRefAll;        % ALL
out.intervalMatchedLinkFramesAll = matchedLinkFramesAll; % optional, if you want

% draw intervals (BW) first
if any(alphaInt(:))
    image(ax, [0.5 Tw-0.5], [1 Htot], rgbInt, 'AlphaData', alphaInt, 'HitTest','off');
end

% draw match links + edges (vector)
localDrawMatchLinks(ax, out.events, idxShown, Tmax, H, W, Gcmp, Groi, nROI, matchMaxDtFrames);
localDrawIntervalLinks(ax, out.events, idxShown, Tmax, H, W, Gcmp, Groi, nROI, matchMaxDtFrames);
localDrawBatonnetEdges(ax, Tmax, H, W, Gcmp, Groi, nROI);

out.dtAll = dtAll;

% draw events overlay last (color)
if any(alphaEv(:))
    image(ax, [0.5 Tw-0.5], [1 Htot], rgbEv, 'AlphaData', alphaEv, 'HitTest','off');
end

% colormap green->red for |dt|
N = 256;
a = linspace(0,1,N)';        % 0..1
cmap = [a, 1-a, zeros(N,1)]; % red, green, 0
colormap(ax, cmap);
caxis(ax, [0 matchMaxDtFrames]);

cb = colorbar(ax, 'Location','southoutside');
cb.Label.String = sprintf('|Δt| (frames), capped at %d', matchMaxDtFrames);
cb.TickDirection = 'out';

% small text legend for blue meaning
text(ax, 0.99, 0.02, "Blue = FP(test) or FN(ref)", ...
    'Units','normalized', 'HorizontalAlignment','right', 'Color',[0 0 1], ...
    'FontWeight','bold');

% ---- PATCH: second grayscale scale BELOW the Δt colorbar ----
drawnow; % ensure cb.Position is valid

try
    pos = cb.Position; % [x y w h] in normalized figure units
    h2  = pos(4)*0.55;  % height of grayscale bar
    gap = pos(4)*0.35;  % gap between colorbars

    % create an axes for grayscale bar (no ticks)
    axg = axes('Parent', fe, 'Units','normalized', ...
               'Position', [pos(1), pos(2)-h2-gap, pos(3), h2]);
    axg.Visible = 'off';
    axg.HitTest = 'off';
    axg.Clipping = 'off';

    grad = uint8(linspace(255,0,256));                 % white->black
    gradRGB = repmat(reshape(grad,1,[],1), [12 1 3]);   % small height image
    image(axg, [0 1], [0 1], gradRGB, 'HitTest','off');

    text(axg, 0, 1.25, sprintf('|Δdur| intervals (frames): white=0 black≥%g', maxDurDiffForBlack), ...
        'Units','normalized', 'HorizontalAlignment','left', 'Color',[0 0 0], ...
        'FontSize',9, 'Interpreter','none', 'HitTest','off');
catch
    % fail silently: keep only the main colorbar if something goes wrong
end
% ---- END PATCH ----

% re-lock after overlay
xtFrames = localNiceFrameTicks(Tmax, 6);
set(ax, ...
    'XLim', [0 Tw], ...
    'YLim', [0.5 Htot+0.5], ...
    'XTick', xtFrames * W, ...
    'XTickLabel', string(xtFrames), ...
    'XLimMode','manual', ...
    'YLimMode','manual');
axis(ax,'manual');

hold(ax,'off');

end



function localDrawBatonnetEdges(ax, Tmax, H, W, Gcmp, Groi, nROI)
Tw = Tmax*W;
HperROI = 2*H + Gcmp;
row0 = 1;
for iR = 1:nROI
    rA0 = row0;           rA1 = row0 + H - 1;
    rB0 = row0 + H + Gcmp; rB1 = rB0 + H - 1;

    % top+bottom lines for each bar
    plot(ax, [0 Tw], [rA0 rA0], 'k-', 'LineWidth',0.5, 'HitTest','off');
    plot(ax, [0 Tw], [rA1 rA1], 'k-', 'LineWidth',0.5, 'HitTest','off');
    plot(ax, [0 Tw], [rB0 rB0], 'k-', 'LineWidth',0.5, 'HitTest','off');
    plot(ax, [0 Tw], [rB1 rB1], 'k-', 'LineWidth',0.5, 'HitTest','off');

    row0 = row0 + HperROI;
    if iR < nROI, row0 = row0 + Groi; end
end
end


function out = localPlotMatchStats(out, roiListShown, idxShown, matchMaxDtFrames)
% Panels:
% 1) hist |Δt| matched EVENTS
% 2) bar FP/FN EVENTS
% 3) hist |Δdur| matched INTERVALS (matched only)
% 4) hist duration distributions (ALL intervals) TEST vs REF + stats + test
% 5) loglog scatter matched intervals: REF vs TEST + y=x dashed

dtAll = [];
if isfield(out,'dtAll'), dtAll = out.dtAll; end

durDiffMatchedAbsAll = [];
if isfield(out,'intervalDurDiffAll'), durDiffMatchedAbsAll = out.intervalDurDiffAll; end

durTestAll = [];
durRefAll  = [];
if isfield(out,'intervalDurTestAll'), durTestAll = out.intervalDurTestAll; end
if isfield(out,'intervalDurRefAll'),  durRefAll  = out.intervalDurRefAll;  end

nROI = numel(idxShown);

% event FP/FN aggregation
nTestE = 0; nRefE = 0; nFP = 0; nFN = 0;
for iR = 1:nROI
    iAll = idxShown(iR);
    evTest = out.events(iAll,1).events;
    evRef  = out.events(iAll,2).events;
    mt = localMatchEventsHungarianByName(evTest, evRef, matchMaxDtFrames);
    nTestE = nTestE + numel(evTest);
    nRefE  = nRefE  + numel(evRef);
    nFP    = nFP    + sum(mt.testUnmatched);
    nFN    = nFN    + sum(mt.refUnmatched);
end
fpFrac = nFP / max(1,nTestE);
fnFrac = nFN / max(1,nRefE);

fs = figure('Name','Events/Intervals matching stats (test vs ref)','Color','w');
out.eventsStatsFigure = fs;

tl = tiledlayout(fs, 5, 1, 'Padding','compact', 'TileSpacing','compact');

% -------- Panel 1: matched event dt
ax1 = nexttile(tl,1);
if isempty(dtAll)
    text(ax1,0.5,0.5,"No matched events",'Units','normalized','HorizontalAlignment','center'); axis(ax1,'off');
else
    histogram(ax1, abs(dtAll), 'BinMethod','integers');
    xlabel(ax1,'|Δt| matched events (frames)'); ylabel(ax1,'Count');
    medDt = median(abs(dtAll), 'omitnan');
    title(ax1, sprintf('Matched events |Δt| (median=%.2f frames)', medDt));
    xlim(ax1, [0 matchMaxDtFrames]);
end

% -------- Panel 2: FP/FN events
ax2 = nexttile(tl,2);
bar(ax2, [fpFrac fnFrac]);
ax2.XTickLabel = {'FP(test)','FN(ref)'};
ylabel(ax2,'Fraction'); ylim(ax2,[0 1]);
title(ax2, sprintf('Events: FP=%d/%d (%.1f%%), FN=%d/%d (%.1f%%)', ...
    nFP, nTestE, 100*fpFrac, nFN, nRefE, 100*fnFrac));

% -------- Panel 3: matched interval duration diff
ax3 = nexttile(tl,3);
if isempty(durDiffMatchedAbsAll)
    text(ax3,0.5,0.5,"No matched intervals",'Units','normalized','HorizontalAlignment','center'); axis(ax3,'off');
else
    histogram(ax3, durDiffMatchedAbsAll, 'BinMethod','integers');
    xlabel(ax3,'|Δdur| matched intervals (frames)'); ylabel(ax3,'Count');
    medDur = median(durDiffMatchedAbsAll,'omitnan');
    title(ax3, sprintf('Matched intervals |Δdur| (median=%.2f frames)', medDur));
end

% -------- Panel 4: ALL interval duration distributions (test vs ref) + stats + test
ax4 = nexttile(tl,4);
hold(ax4,'on');
if isempty(durTestAll) && isempty(durRefAll)
    text(ax4,0.5,0.5,"No intervals",'Units','normalized','HorizontalAlignment','center'); axis(ax4,'off');
else
    if ~isempty(durRefAll)
        histogram(ax4, durRefAll, 'Normalization','probability', 'DisplayStyle','stairs', 'LineWidth',1.5);
    end
    if ~isempty(durTestAll)
        histogram(ax4, durTestAll,'Normalization','probability', 'DisplayStyle','stairs', 'LineWidth',1.5);
    end
    xlabel(ax4,'Interval duration (frames)'); ylabel(ax4,'Probability');
    legend(ax4, {'REF (all intervals)','TEST (all intervals)'}, 'Location','northeast');

    % stats
    medT = median(durTestAll,'omitnan'); medR = median(durRefAll,'omitnan');
    iqrT = iqr(durTestAll); iqrR = iqr(durRefAll);

    % test de distribution: KS2 (non-param)
    p = NaN; ksstat = NaN;
    if numel(durTestAll) >= 2 && numel(durRefAll) >= 2
        try
            [~,p,ksstat] = kstest2(durTestAll, durRefAll);
        catch
        end
    end

    title(ax4, sprintf('All interval durations: med(T)=%.2f, IQR(T)=%.2f | med(R)=%.2f, IQR(R)=%.2f | KS2 p=%.3g (D=%.3g)', ...
        medT, iqrT, medR, iqrR, p, ksstat));
end
hold(ax4,'off');

% -------- Panel 5: loglog matched intervals REF vs TEST + diagonal
ax5 = nexttile(tl,5);
% We need matched pairs arrays; rebuild quickly from per-ROI (robust and simple)
xRef = []; yTest = [];
for iR = 1:nROI
    iAll = idxShown(iR);
    evTest = out.events(iAll,1).events;
    evRef  = out.events(iAll,2).events;
    mt = localMatchEventsHungarianByName(evTest, evRef, matchMaxDtFrames);
    I  = localIntervalsAllAndMatchedFromEventMatch(evTest, evRef, mt);
    if ~isempty(I.matchedRefDur)
        xRef  = [xRef;  I.matchedRefDur(:)];  %#ok<AGROW>
        yTest = [yTest; I.matchedTestDur(:)]; %#ok<AGROW>
    end
end

if isempty(xRef)
    text(ax5,0.5,0.5,"No matched intervals for log-log scatter",'Units','normalized','HorizontalAlignment','center'); axis(ax5,'off');
else
    % avoid zeros for log
    ok = isfinite(xRef) & isfinite(yTest) & xRef>0 & yTest>0;
    xRef = xRef(ok); yTest = yTest(ok);

    loglog(ax5, xRef, yTest, '.', 'MarkerSize',10);
    hold(ax5,'on');
    mn = min([xRef; yTest]); mx = max([xRef; yTest]);
    loglog(ax5, [mn mx], [mn mx], 'k--', 'LineWidth',1); % diagonal y=x
    hold(ax5,'off');

    xlabel(ax5,'REF interval duration (frames)'); ylabel(ax5,'TEST interval duration (frames)');
    title(ax5, sprintf('Matched intervals (log-log): REF vs TEST (n=%d)', numel(xRef)));
    grid(ax5,'on');
end
end


function [rgb, alpha] = localBuildBatonnetBackground(Tmax, H, W, Gcmp, Groi, nROI)
Tw = Tmax * W;
HperROI = 2*H + Gcmp;
Htot    = nROI*HperROI + (nROI-1)*Groi;

rgb   = 255 * ones(Htot, Tw, 3, 'uint8');     % white everywhere
alpha = zeros(Htot, Tw, 'single');            % transparent by default

% light gray batonnet color
g = uint8(245);                               % tweak 240..250
barRGB = cat(3, g, g, g);

row0 = 1;
for iR = 1:nROI
    % A bar region
    rA0 = row0;
    rA1 = row0 + H - 1;

    % B bar region
    rB0 = row0 + H + Gcmp;
    rB1 = rB0 + H - 1;

    % fill A and B with light gray (opaque)
    rgb(rA0:rA1,:,:) = repmat(barRGB, [rA1-rA0+1, Tw, 1]);
    rgb(rB0:rB1,:,:) = repmat(barRGB, [rB1-rB0+1, Tw, 1]);
    alpha(rA0:rA1,:) = 1;
    alpha(rB0:rB1,:) = 1;

    row0 = row0 + HperROI;
    if iR < nROI
        row0 = row0 + Groi;
    end
end
end




function [rgb, alpha, dtAll] = localBuildEventsOverlayMatched(Eall, idxShown, Tmax, H, W, Gcmp, Groi, nROI, eventWidthFrames, matchMaxDtFrames)
% Colors:
% - REF (bas): black if matched, blue if FN (unmatched in ref)
% - TEST (haut): green->red by |dt| if matched, blue if FP (unmatched in test)

if nargin < 9 || isempty(eventWidthFrames), eventWidthFrames = 1; end
eventWidthFrames = max(1, round(eventWidthFrames));
eventWidthPx = eventWidthFrames * W;

if nargin < 10 || isempty(matchMaxDtFrames), matchMaxDtFrames = 10; end

Tw = Tmax * W;
HperROI = 2*H + Gcmp;
Htot    = nROI*HperROI + (nROI-1)*Groi;

rgb   = zeros(Htot, Tw, 3, 'uint8');
alpha = zeros(Htot, Tw, 'single');

dtAll = [];

% col constants
colBlue  = [0 0 1];
colBlack = [0 0 0];

% dt -> color (green->red)
dt2col = @(dtAbs, dtMax) [min(dtAbs/dtMax,1), max(0,1-dtAbs/dtMax), 0];

row0 = 1;
for iR = 1:nROI
    iAll = idxShown(iR);

    rA0 = row0;
    rA1 = row0 + H - 1;

    rB0 = row0 + H + Gcmp;
    rB1 = rB0 + H - 1;

    evTest = Eall(iAll,1).events; % dsKeys(1)=test
    evRef  = Eall(iAll,2).events; % dsKeys(2)=ref

    mt = localMatchEventsHungarianByName(evTest, evRef, matchMaxDtFrames);

    % --- REF rendering (black if matched, blue if FN) ---
    for k = 1:numel(evRef)
        t = evRef(k).frame;
        if ~isfinite(t) || t < 1 || t > Tmax, continue; end

        if mt.refUnmatched(k)
            c = colBlue;   % FN in ref => blue
        else
            c = colBlack;  % matched => black
        end

        [col0,col1] = localEventColRange(t, W, Tw, eventWidthPx);

        rgb(rB0:rB1, col0:col1, 1) = uint8(255*c(1));
        rgb(rB0:rB1, col0:col1, 2) = uint8(255*c(2));
        rgb(rB0:rB1, col0:col1, 3) = uint8(255*c(3));
        alpha(rB0:rB1, col0:col1)  = 1;
    end

    % --- TEST rendering (blue if FP, else green->red by |dt|) ---
    % build quick map testIndex -> |dt|
    dtAbsPerTest = nan(numel(evTest),1);
    for m = 1:size(mt.pairs,1)
        iTest = mt.pairs(m,1);
        dtAbsPerTest(iTest) = abs(mt.dt(m));
    end
    dtAll = [dtAll; dtAbsPerTest(~isnan(dtAbsPerTest))]; %#ok<AGROW>

    for k = 1:numel(evTest)
        t = evTest(k).frame;
        if ~isfinite(t) || t < 1 || t > Tmax, continue; end

        if mt.testUnmatched(k)
            c = colBlue; % FP in test
        else
            c = dt2col(dtAbsPerTest(k), matchMaxDtFrames);
        end

        [col0,col1] = localEventColRange(t, W, Tw, eventWidthPx);

        rgb(rA0:rA1, col0:col1, 1) = uint8(255*c(1));
        rgb(rA0:rA1, col0:col1, 2) = uint8(255*c(2));
        rgb(rA0:rA1, col0:col1, 3) = uint8(255*c(3));
        alpha(rA0:rA1, col0:col1)  = 1;
    end

    row0 = row0 + HperROI;
    if iR < nROI
        row0 = row0 + Groi;
    end
end
end

function [col0,col1] = localEventColRange(tFrame, W, Tw, eventWidthPx)
xc = (tFrame-1)*W + floor(W/2) + 1;         % center of frame block
col0 = max(1, xc - floor(eventWidthPx/2));
col1 = min(Tw, col0 + eventWidthPx - 1);
end




% ---- small utilities (self-contained) ----

function s = localGetSequenceForKey(rr, dsKey)
s = [];

sp = strsplit(char(dsKey), '|');
dsName = string(sp{1});
varName = "";
if numel(sp) >= 2, varName = string(sp{2}); end

try
    dss = rr.data;
catch
    dss = [];
end
if isempty(dss), return; end
dss = dss(:);

ds = [];
for j = 1:numel(dss)
    dd = dss(j);
    name = "";
    try
        if isprop(dd,'groupid') && ~isempty(dd.groupid), name = string(dd.groupid);
        elseif isprop(dd,'name') && ~isempty(dd.name), name = string(dd.name);
        end
    catch
    end
    if name == dsName
        ds = dd;
        break;
    end
end
if isempty(ds), return; end

if ~isprop(ds,'data') || isempty(ds.data), return; end
dt = ds.data;

try
    if (istable(dt) || istimetable(dt)) && varName ~= "" && any(strcmp(dt.Properties.VariableNames, char(varName)))
        s = dt.(char(varName)); return;
    end
    if isstruct(dt) && varName ~= "" && isfield(dt, char(varName))
        s = dt.(char(varName)); return;
    end
catch
end
end

function s = localToStringLabels(x)
try
    if iscategorical(x), s = string(x(:));
    elseif isstring(x),   s = x(:);
    elseif ischar(x),     s = string(x);
    elseif iscell(x)
        s = strings(numel(x),1);
        for i=1:numel(x)
            if isstring(x{i}), s(i)=x{i};
            elseif ischar(x{i}), s(i)=string(x{i});
            else, s(i)="";
            end
        end
    else
        s = string(x(:));
    end
catch
    s = strings(0,1);
end
end

function [seqs, Tmax] = localCollectSequences(roiList, dsKey)
seqs = cell(numel(roiList),1);
Tmax = 0;
for iR = 1:numel(roiList)
    rr = roiList(iR).roiObj;

  %  try, if ismethod(rr,'load'), rr.load('data'); end, catch, end


try
    if isprop(rr,'data') && ~isempty(rr.data) && ~isempty(rr.data(1).data)
        % ok déjà chargé
    else
        if ismethod(rr,'load'), rr.load('data'); end
    end
catch
end


    s = localGetSequenceForKey(rr, dsKey);
    s = s(:)'; % row
    seqs{iR} = s;
    Tmax = max(Tmax, numel(s));
end
end

function absent = localSeqCellIsAbsent(seqs)
n = numel(seqs);
absent = false(n,1);
for i = 1:n
    x = seqs{i};
    if isempty(x)
        absent(i) = true; continue;
    end
    if isnumeric(x) || islogical(x)
        absent(i) = all(isnan(double(x(:))));
        continue;
    end
    s = localToStringLabels(x);
    if isempty(s)
        absent(i) = true;
    else
        s = strtrim(s);
        absent(i) = all(strlength(s)==0);
    end
end
end

function Tmax = localMaxLen(seqs)
Tmax = 0;
for i=1:numel(seqs)
    Tmax = max(Tmax, numel(seqs{i}));
end
end

function yc = localRoiPairCenters(nROI, H, Gcmp, Groi)
yc = zeros(nROI,1);
row0 = 1;
for iR = 1:nROI
    yc(iR) = row0 + (2*H + Gcmp - 1)/2;
    row0 = row0 + (2*H + Gcmp);
    if iR < nROI
        row0 = row0 + Groi;
    end
end
end

function xt = localNiceFrameTicks(nFrames, nMax)
if nargin < 2, nMax = 6; end
if nFrames <= 0, xt = []; return; end
ord = 10^floor(log10(nFrames));
steps = [1 2 5 10] * ord;
steps = sort([steps, steps/10]);
step = steps(end);
for k = 1:numel(steps)
    if ceil(nFrames/steps(k)) <= nMax
        step = steps(k);
        break;
    end
end
xt = 0:step:nFrames;
if xt(end) ~= nFrames, xt(end+1) = nFrames; end
end

function [frames, names, valid] = localExtractEventFramesNames(ev)
% Robust extraction of event frames and names
% NO struct expansion, safe against missing fields
%
% Outputs:
%   frames : [n x 1] double (NaN if invalid)
%   names  : [n x 1] string
%   valid  : logical mask of valid events

n = numel(ev);
frames = nan(n,1);
names  = strings(n,1);

for i = 1:n
    if isfield(ev(i),'frame') && isnumeric(ev(i).frame) ...
            && isscalar(ev(i).frame) && isfinite(ev(i).frame)
        frames(i) = double(ev(i).frame);
    end

    if isfield(ev(i),'name') && ~isempty(ev(i).name)
        names(i) = string(ev(i).name);
    end
end

names = strtrim(names);
valid = isfinite(frames) & (strlength(names) > 0);
end


function match = localMatchEventsHungarianByName(evTest, evRef, maxDt)
% Match events between test/ref using Hungarian algorithm (matchpairs),
% separately for each event name. Cost = |dt|, rejected if dt > maxDt.

if nargin < 3 || isempty(maxDt), maxDt = 10; end

% frames + names
[tFrames, tNames] = localExtractEventFramesNames(evTest);
[rFrames, rNames] = localExtractEventFramesNames(evRef);

validT = isfinite(tFrames) & strlength(strtrim(tNames))>0;
validR = isfinite(rFrames) & strlength(strtrim(rNames))>0;



match = struct();
match.maxDt = maxDt;
match.pairs = zeros(0,2);        % [iTest, iRef] indices in evTest/evRef
match.dt    = zeros(0,1);        % dt = test - ref (signed)
match.testUnmatched = true(numel(evTest),1);
match.refUnmatched  = true(numel(evRef),1);

if isempty(evTest) && isempty(evRef), return; end
if isempty(evTest)
    % all ref unmatched
    return;
end
if isempty(evRef)
    % all test unmatched
    return;
end

% match by unique names present in either side
allNames = unique([tNames; rNames]);

for kName = 1:numel(allNames)
    nm = allNames(kName);

    it = find(validT & (tNames == nm));
ir = find(validR & (rNames == nm));


    if isempty(it) || isempty(ir)
        continue;
    end

    % cost matrix |dt|, Inf beyond maxDt
    Ct = tFrames(it);
    Cr = rFrames(ir);

    cost = abs(Ct - Cr'); % [nT x nR]
    cost(cost > maxDt) = Inf;

    % Hungarian
    % penalty = maxDt -> anything > maxDt was already Inf
    [ass, ~, ~] = matchpairs(cost, maxDt);

    if isempty(ass), continue; end

    for m = 1:size(ass,1)
        iTest = it(ass(m,1));
        iRef  = ir(ass(m,2));
        match.pairs(end+1,:) = [iTest, iRef]; %#ok<AGROW>
        match.dt(end+1,1)    = tFrames(iTest) - rFrames(iRef); %#ok<AGROW>
        match.testUnmatched(iTest) = false;
        match.refUnmatched(iRef)   = false;
    end
end
end


function localDrawMatchLinks(ax, Eall, idxShown, Tmax, H, W, Gcmp, Groi, nROI, matchMaxDtFrames)
% Draw thin black lines connecting matched events (test top -> ref bottom)
% Uses vector line objects (one big polyline with NaNs for speed).

Tw = Tmax * W;
HperROI = 2*H + Gcmp;

xAll = [];
yAll = [];

row0 = 1;
for iR = 1:nROI
    iAll = idxShown(iR);

    rA0 = row0;
    rB0 = row0 + H + Gcmp;

    yA = rA0 + (H-1)/2;
    yB = rB0 + (H-1)/2;

    evTest = Eall(iAll,1).events;
    evRef  = Eall(iAll,2).events;

    mt = localMatchEventsHungarianByName(evTest, evRef, matchMaxDtFrames);

    for m = 1:size(mt.pairs,1)
        iT = mt.pairs(m,1);
        iRr = mt.pairs(m,2);

        tT = evTest(iT).frame;
        tR = evRef(iRr).frame;

        if ~isfinite(tT) || ~isfinite(tR), continue; end
        if tT < 1 || tT > Tmax || tR < 1 || tR > Tmax, continue; end

        xT = (tT-1)*W + floor(W/2) + 1;
        xR = (tR-1)*W + floor(W/2) + 1;

        xAll = [xAll; xT; xR; NaN]; %#ok<AGROW>
        yAll = [yAll; yA; yB; NaN]; %#ok<AGROW>
    end

    row0 = row0 + HperROI;
    if iR < nROI
        row0 = row0 + Groi;
    end
end

if ~isempty(xAll)
    plot(ax, xAll, yAll, '-', 'Color',[0 0 0], 'LineWidth',0.5, 'HitTest','off');
end
end

function I = localIntervalsFromEvents(ev)
% Intervals strictly between successive events (sorted by frame)
% I: struct array with fields startFrame,endFrame,dur

I = struct('startFrame',{},'endFrame',{},'dur',{});
if isempty(ev), return; end

frames = nan(numel(ev),1);
for k=1:numel(ev)
    if isfield(ev(k),'frame') && isfinite(ev(k).frame) && isscalar(ev(k).frame)
        frames(k) = double(ev(k).frame);
    end
end
frames = frames(isfinite(frames));
frames = sort(frames);

if numel(frames) < 2, return; end

n = numel(frames)-1;
I = repmat(struct('startFrame',0,'endFrame',0,'dur',0), n, 1);
for i=1:n
    I(i).startFrame = frames(i);
    I(i).endFrame   = frames(i+1);
    I(i).dur        = frames(i+1) - frames(i);
end
end

function M = localMatchIntervalsHungarian(It, Ir, maxDt)
% Match intervals by startFrame proximity (Hungarian).
% Cost = |start_t - start_r|, reject if > maxDt.

if nargin < 3 || isempty(maxDt), maxDt = 10; end

M = struct();
M.pairs = zeros(0,2);   % [iIt, iIr]
M.dtStart = zeros(0,1);
M.durDiff = zeros(0,1);
M.testUnmatched = true(numel(It),1);
M.refUnmatched  = true(numel(Ir),1);

if isempty(It) || isempty(Ir), return; end

stT = [It.startFrame]';  % OK here because non-empty, scalar numeric
stR = [Ir.startFrame]';

cost = abs(stT - stR');
cost(cost > maxDt) = Inf;

[ass,~,~] = matchpairs(cost, maxDt);
if isempty(ass), return; end

for m=1:size(ass,1)
    iT = ass(m,1);
    iR = ass(m,2);
    M.pairs(end+1,:) = [iT iR]; %#ok<AGROW>
    M.dtStart(end+1,1) = stT(iT) - stR(iR); %#ok<AGROW>
    M.durDiff(end+1,1) = abs(It(iT).dur - Ir(iR).dur); %#ok<AGROW>
    M.testUnmatched(iT) = false;
    M.refUnmatched(iR)  = false;
end
end

function [rgb, alpha, durDiffMatchedAbsAll, dtStartAll, durTestAll, durRefAll, matchedLinkFramesAll] = ...
    localBuildIntervalsOverlayBW(Eall, idxShown, Tmax, H, W, Gcmp, Groi, nROI, matchMaxDtFrames, maxDurDiffForBlack)
% Draw grayscale ONLY on TEST batonnet (top): |Δdur| for MATCHED intervals only.
% Interval is matchable ONLY if both bounding events are matched.
%
% Also returns:
% - durTestAll/durRefAll: ALL interval durations (distributions)
% - durDiffMatchedAbsAll: |Δdur| for matched intervals only (for histogram)
% - matchedLinkFramesAll: [t0 t1 r0 r1] for drawing black links
% - dtStartAll: optional (here we use |Δt_mid| as a diagnostic, can be empty)

if nargin < 9 || isempty(matchMaxDtFrames), matchMaxDtFrames = 10; end
if nargin < 10 || isempty(maxDurDiffForBlack), maxDurDiffForBlack = 10; end

Tw = Tmax * W;
HperROI = 2*H + Gcmp;
Htot    = nROI*HperROI + (nROI-1)*Groi;

rgb   = zeros(Htot, Tw, 3, 'uint8');
alpha = zeros(Htot, Tw, 'single');

durDiffMatchedAbsAll = [];
dtStartAll = []; % can remain empty if you don't use it
durTestAll = [];
durRefAll  = [];
matchedLinkFramesAll = zeros(0,4);

row0 = 1;
for iR = 1:nROI
    iAll = idxShown(iR);

    % TEST on top, REF on bottom (CONVENTION)
    rT0 = row0;            rT1 = row0 + H - 1;           % TEST (top)
    rR0 = row0 + H + Gcmp; rR1 = rR0 + H - 1;            % REF  (bottom) not painted in BW

    evTest = Eall(iAll,1).events; % TEST = col 1 (TOP)
    evRef  = Eall(iAll,2).events; % REF  = col 2 (BOTTOM)

    mt = localMatchEventsHungarianByName(evTest, evRef, matchMaxDtFrames);

    I = localIntervalsAllAndMatchedFromEventMatch(evTest, evRef, mt);

    % collect ALL durations for distributions
    if ~isempty(I.testDurAll), durTestAll = [durTestAll; I.testDurAll(:)]; end %#ok<AGROW>
    if ~isempty(I.refDurAll),  durRefAll  = [durRefAll;  I.refDurAll(:)];  end %#ok<AGROW>

    % nothing matched -> skip drawing
    if isempty(I.matchedDurDiffAbs)
        row0 = row0 + HperROI;
        if iR < nROI, row0 = row0 + Groi; end
        continue;
    end

    durDiffMatchedAbsAll = [durDiffMatchedAbsAll; I.matchedDurDiffAbs(:)]; %#ok<AGROW>
    matchedLinkFramesAll = [matchedLinkFramesAll; I.matchedLinkFrames]; %#ok<AGROW>

    % draw grayscale bands ONLY on TEST bar using TEST interval extents [t0,t1]
    for m = 1:size(I.matchedLinkFrames,1)
        t0 = I.matchedLinkFrames(m,1);
        t1 = I.matchedLinkFrames(m,2);
        dd = I.matchedDurDiffAbs(m);

        if ~isfinite(t0) || ~isfinite(t1) || t1 <= t0, continue; end
        if t0 < 1 || t1 > Tmax, continue; end

        a01 = min(dd / maxDurDiffForBlack, 1);      % 0..1
        v   = uint8(255 * (1 - a01));              % 255 white -> 0 black

        c0T = max(1, round((t0-1)*W + 1));
        c1T = min(Tw, round((t1-1)*W + 1));

        % thin band inside TEST batonnet
        rr0 = rT0 + floor(H/3);
        rr1 = rT0 + ceil(2*H/3);

        rgb(rr0:rr1, c0T:c1T, :) = v;
        alpha(rr0:rr1, c0T:c1T) = 0.85;
    end

    row0 = row0 + HperROI;
    if iR < nROI
        row0 = row0 + Groi;
    end
end
end

function localDrawIntervalLinks(ax, Eall, idxShown, Tmax, H, W, Gcmp, Groi, nROI, matchMaxDtFrames)
% Draw thin black lines connecting MATCHED intervals (midpoint test -> midpoint ref)
% Interval is matched ONLY if both bounding events are matched.

HperROI = 2*H + Gcmp;

xAll = [];
yAll = [];

row0 = 1;
for iR = 1:nROI
    iAll = idxShown(iR);

    yTest = row0 + (H-1)/2;
    yRef  = (row0 + H + Gcmp) + (H-1)/2;

    evTest = Eall(iAll,1).events; % TEST top
    evRef  = Eall(iAll,2).events; % REF bottom

    mt = localMatchEventsHungarianByName(evTest, evRef, matchMaxDtFrames);
    I  = localIntervalsAllAndMatchedFromEventMatch(evTest, evRef, mt);

    for m = 1:size(I.matchedLinkFrames,1)
        t0 = I.matchedLinkFrames(m,1); t1 = I.matchedLinkFrames(m,2);
        r0 = I.matchedLinkFrames(m,3); r1 = I.matchedLinkFrames(m,4);

        % midpoints
        tMid = 0.5*(t0+t1);
        rMid = 0.5*(r0+r1);

        if ~isfinite(tMid) || ~isfinite(rMid), continue; end
        if tMid < 1 || tMid > Tmax || rMid < 1 || rMid > Tmax, continue; end

        xT = (tMid-1)*W + floor(W/2) + 1;
        xR = (rMid-1)*W + floor(W/2) + 1;

        xAll = [xAll; xT; xR; NaN]; %#ok<AGROW>
        yAll = [yAll; yTest; yRef; NaN]; %#ok<AGROW>
    end

    row0 = row0 + HperROI;
    if iR < nROI, row0 = row0 + Groi; end
end

if ~isempty(xAll)
    plot(ax, xAll, yAll, '-', 'Color',[0 0 0], 'LineWidth',0.5, 'HitTest','off');
end
end

function I = localIntervalsAllAndMatchedFromEventMatch(evTest, evRef, mt)
% localIntervalsAllAndMatchedFromEventMatch
% Build:
% - ALL consecutive intervals (TEST + REF) for distributions (independent of matching)
% - MATCHED intervals ONLY when both bounding events are matched AND matched to each other
%   in the sense: consecutive in TEST-by-time and their matched REF events are also consecutive
%   in REF-by-time (no skipping / no cross).
%
% Output I fields:
%   I.testDurAll, I.refDurAll
%   I.matchedRefDur, I.matchedTestDur, I.matchedDurDiffAbs
%   I.matchedLinkFrames : [t0_test t1_test r0_ref r1_ref] per matched interval (for drawing)

I = struct();
I.testDurAll = [];
I.refDurAll  = [];
I.matchedRefDur = [];
I.matchedTestDur = [];
I.matchedDurDiffAbs = [];
I.matchedLinkFrames = zeros(0,4);

% -----------------------------
% 1) Extract valid frames + original indices (robust)
% -----------------------------
[tFramesRaw, tOkRaw] = localExtractFramesOnly(evTest);
[rFramesRaw, rOkRaw] = localExtractFramesOnly(evRef);

tIdxValid = find(tOkRaw);
rIdxValid = find(rOkRaw);

tFramesValid = tFramesRaw(tIdxValid);
rFramesValid = rFramesRaw(rIdxValid);

% -----------------------------
% 2) ALL intervals for distributions (strictly consecutive in TIME)
% -----------------------------
tFramesSort = sort(tFramesValid(:));
rFramesSort = sort(rFramesValid(:));

if numel(tFramesSort) >= 2
    I.testDurAll = diff(tFramesSort);
end
if numel(rFramesSort) >= 2
    I.refDurAll  = diff(rFramesSort);
end

% -----------------------------
% 3) Early exit if no event matches
% -----------------------------
if isempty(mt) || ~isstruct(mt) || ~isfield(mt,'pairs') || isempty(mt.pairs)
    return;
end

% -----------------------------
% 4) Build mapping testIndex -> refIndex from mt.pairs (original indices)
% -----------------------------
mapT2R = nan(numel(evTest),1);
pairs = mt.pairs;
for k = 1:size(pairs,1)
    iT = pairs(k,1);
    iR = pairs(k,2);
    if iT>=1 && iT<=numel(evTest) && iR>=1 && iR<=numel(evRef)
        mapT2R(iT) = iR;
    end
end

% -----------------------------
% 5) Define "consecutive" in TIME using sorted-by-frame order
%    (this avoids weird indexing artifacts if events were not stored chronologically)
% -----------------------------
% TEST order by time (over valid events only)
[~, ordT] = sort(tFramesValid);
tIdxTime  = tIdxValid(ordT);     % original indices in evTest, sorted by frame
tFramesTime = tFramesValid(ordT);

% REF order by time (over valid events only)
[~, ordR] = sort(rFramesValid);
rIdxTime  = rIdxValid(ordR);     % original indices in evRef, sorted by frame
rFramesTime = rFramesValid(ordR);

% rank maps: original index -> time rank (1..N) for quick "consecutive in time" checks
rankT = nan(numel(evTest),1);
for k = 1:numel(tIdxTime), rankT(tIdxTime(k)) = k; end
rankR = nan(numel(evRef),1);
for k = 1:numel(rIdxTime), rankR(rIdxTime(k)) = k; end

% -----------------------------
% 6) Matched intervals:
%    iterate consecutive TEST events in TIME; interval is matchable if:
%      - both test events are matched (mapT2R finite)
%      - their matched REF events are consecutive in REF-by-time
%      - order is preserved (frames increasing on both sides)
% -----------------------------
for kT = 1:(numel(tIdxTime)-1)
    iT0 = tIdxTime(kT);
    iT1 = tIdxTime(kT+1);

    iR0 = mapT2R(iT0);
    iR1 = mapT2R(iT1);

    if ~isfinite(iR0) || ~isfinite(iR1)
        continue; % one of the bounding events is unmatched
    end

    % Must also be valid in ref ranking
    if iR0 < 1 || iR0 > numel(evRef) || iR1 < 1 || iR1 > numel(evRef)
        continue;
    end
    r0Rank = rankR(iR0);
    r1Rank = rankR(iR1);
    if ~isfinite(r0Rank) || ~isfinite(r1Rank)
        continue;
    end

    % CRITICAL: "matched to each other" => consecutive in REF time order
    % (prevents matching a long ref interval to multiple small test intervals and double-links)
    if r1Rank ~= (r0Rank + 1)
        continue;
    end

    % Frames (use the time-ordered ones for test; for ref we read from events)
    t0 = double(tFramesTime(kT));
    t1 = double(tFramesTime(kT+1));

    r0 = double(evRef(iR0).frame);
    r1 = double(evRef(iR1).frame);

    if ~(isfinite(t0) && isfinite(t1) && isfinite(r0) && isfinite(r1))
        continue;
    end

    % must be strictly increasing (valid interval)
    if t1 <= t0 || r1 <= r0
        continue;
    end

    durT = t1 - t0;
    durR = r1 - r0;

    I.matchedTestDur(end+1,1)     = durT; %#ok<AGROW>
    I.matchedRefDur(end+1,1)      = durR; %#ok<AGROW>
    I.matchedDurDiffAbs(end+1,1)  = abs(durT - durR); %#ok<AGROW>
    I.matchedLinkFrames(end+1,:)  = [t0 t1 r0 r1]; %#ok<AGROW>
end

end

% -------------------------------------------------------------------------
% helper: robust extraction of frames only (NO names), returns raw arrays
% -------------------------------------------------------------------------
function [frames, ok] = localExtractFramesOnly(ev)
n = numel(ev);
frames = nan(n,1);
ok = false(n,1);

for i = 1:n
    if isstruct(ev) && isfield(ev(i),'frame') && ~isempty(ev(i).frame) ...
            && isnumeric(ev(i).frame) && isscalar(ev(i).frame)
        f = double(ev(i).frame);
        if isfinite(f)
            frames(i) = f;
            ok(i) = true;
        end
    end
end
end
