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

% ---- DEBUG options ----
dbg = false;
if isfield(args,'DebugEventsCompare') && ~isempty(args.DebugEventsCompare)
    dbg = logical(args.DebugEventsCompare);
end
dbgMaxROI = 5;
if isfield(args,'DebugMaxROI') && ~isempty(args.DebugMaxROI)
    dbgMaxROI = double(args.DebugMaxROI);
end
dbgMaxLabels = 12;
if isfield(args,'DebugMaxLabels') && ~isempty(args.DebugMaxLabels)
    dbgMaxLabels = double(args.DebugMaxLabels);
end
dbgPrintRules = true;
if isfield(args,'DebugPrintRules') && ~isempty(args.DebugPrintRules)
    dbgPrintRules = logical(args.DebugPrintRules);
end

matchMaxDtFrames = 10; % default
if isfield(args,'MatchMaxDtFrames') && ~isempty(args.MatchMaxDtFrames)
    matchMaxDtFrames = double(args.MatchMaxDtFrames);
end

% --- propagate debug options so localLog/localGetDbg see them ---
args.DebugEventsCompare = dbg;
args.DebugMaxROI        = dbgMaxROI;
args.DebugMaxLabels     = dbgMaxLabels;
args.DebugPrintRules    = dbgPrintRules;

logf = @(varargin) fprintf('[eventsCompare %s] %s\n', datestr(now,'HH:MM:SS.FFF'), sprintf(varargin{:}));

if dbg
    logf('START batonnets_eventsCompare');
    logf('dsKeys = {%s} , {%s}', char(string(dsKeys(1))), char(string(dsKeys(2))));

    logf('roiListAll=%d, roiListShown=%d', numel(roiListAll), numel(roiListShown));
end

if dbg
    for i=1:numel(dsKeys)
        k = char(dsKeys(i));
        if isKey(rulesByKey,k)
            v = rulesByKey(k);
            logf('Rules for "%s": size=%dx%d isempty=%d', k, size(v,1), size(v,2), isempty(v));
        else
            logf('Rules for "%s": MISSING KEY', k);
        end
    end
end

% hard warning (optional)
k1 = char(dsKeys(1)); k2 = char(dsKeys(2));
if isKey(rulesByKey,k1) && isKey(rulesByKey,k2) && isempty(rulesByKey(k1)) && isempty(rulesByKey(k2))
    warning('eventsCompare:NoRules', 'EventRulesByKey has entries but both are empty (0x0 struct). No events can be detected.');
end


if dbg, logf('CollectAllEvents...'); end
out.events = localCollectAllEvents(roiListAll, dsKeys, rulesByKey, args);
if dbg, logf('CollectAllEvents DONE'); end

if dbg, logf('RenderEventsFigure...'); end
out = localRenderEventsFigure(out, roiListShown, idxShown, dsKeys, H, W, Gcmp, Groi, args);
if dbg, logf('RenderEventsFigure DONE'); end

if dbg, logf('PlotMatchStats...'); end
out = localPlotMatchStats(out, roiListShown, idxShown, matchMaxDtFrames, args);
% --- build export-ready numeric stats (for Excel) ---
out.eventsStats = localBuildExportStats(out, idxShown, matchMaxDtFrames);

if dbg
    logf('EXPORT STATS built: out.eventsStats created (struct)');
    try
        logf('  Events: nTest=%d nRef=%d TP=%d FP=%d FN=%d prec=%.3f rec=%.3f', ...
            out.eventsStats.events.nTest, out.eventsStats.events.nRef, ...
            out.eventsStats.events.TP, out.eventsStats.events.FP, out.eventsStats.events.FN, ...
            out.eventsStats.events.precision, out.eventsStats.events.recall);
        logf('  Intervals: nMatched=%d', out.eventsStats.intervals.nMatched);
        logf('  dt: n=%d median=%.3g mean=%.3g p90=%.3g', ...
            out.eventsStats.events.dt.n, out.eventsStats.events.dt.median, ...
            out.eventsStats.events.dt.mean, out.eventsStats.events.dt.p90);
    catch ME
        logf('  (could not print summary) %s', ME.message);
    end
end


if dbg, logf('PlotMatchStats DONE'); end

end

% ======================================================================
% Local helpers
% ======================================================================

function S = localBuildExportStats(out, idxShown, matchMaxDtFrames)

S = struct();

% ---------- Events FP/FN/TP (NO artificial duplication) ----------
nROI = numel(idxShown);
nTestE = 0; nRefE = 0; nFP = 0; nFN = 0; nTP = 0;

dtAll = [];

for iR = 1:nROI
    iAll = idxShown(iR);

    % raw events
    evTestRaw = out.events(iAll,1).events;
    evRefRaw  = out.events(iAll,2).events;

    % collapse start/end duplicates for STATS
    evTest = localCollapseEventsForStats_(evTestRaw);
    evRef  = localCollapseEventsForStats_(evRefRaw);

    mt = localMatchEventsHungarianByName_IgnoreType_(evTest, evRef, matchMaxDtFrames);

    nTestE = nTestE + numel(evTest);
    nRefE  = nRefE  + numel(evRef);
    nFP    = nFP    + sum(mt.testUnmatched);
    nFN    = nFN    + sum(mt.refUnmatched);
    nTP    = nTP    + size(mt.pairs,1);

    if isfield(mt,'dt') && ~isempty(mt.dt)
        dtAll = [dtAll; mt.dt(:)]; %#ok<AGROW>
    end
end

S.events = struct();
S.events.nTest = nTestE;
S.events.nRef  = nRefE;
S.events.TP    = nTP;
S.events.FP    = nFP;
S.events.FN    = nFN;
S.events.precision = nTP / max(1,(nTP+nFP));
S.events.recall    = nTP / max(1,(nTP+nFN));
S.events.fpFrac    = nFP / max(1,nTestE);
S.events.fnFrac    = nFN / max(1,nRefE);

% dt stats (events)
S.events.dt = struct();
if ~isempty(dtAll)
    S.events.dt.n = numel(dtAll);
    S.events.dt.median = median(abs(dtAll),'omitnan');
    S.events.dt.mean   = mean(abs(dtAll),'omitnan');
    S.events.dt.p90    = prctile(abs(dtAll),90);
else
    S.events.dt.n = 0;
    S.events.dt.median = NaN;
    S.events.dt.mean = NaN;
    S.events.dt.p90 = NaN;
end

% dt histogram (fixed bins 0..matchMaxDtFrames by 0.5)
binW = 0.5;
edges = 0:binW:(matchMaxDtFrames+binW);
if edges(end) < matchMaxDtFrames, edges(end+1)=matchMaxDtFrames; end
if ~isempty(dtAll)
    counts = histcounts(abs(dtAll), edges);
else
    counts = zeros(1, numel(edges)-1);
end
S.events.dtHist = struct('edges',edges,'counts',counts,'binW',binW);

% ---------- Intervals (unchanged, from precomputed aggregates if present) ----------
durDiff = [];
durTest = [];
durRef  = [];
if isfield(out,'intervalDurDiffAll') && ~isempty(out.intervalDurDiffAll)
    durDiff = out.intervalDurDiffAll(:);
end
if isfield(out,'intervalDurTestAll') && ~isempty(out.intervalDurTestAll)
    durTest = out.intervalDurTestAll(:);
end
if isfield(out,'intervalDurRefAll') && ~isempty(out.intervalDurRefAll)
    durRef = out.intervalDurRefAll(:);
end

durDiff = durDiff(isfinite(durDiff));
durTest = durTest(isfinite(durTest));
durRef  = durRef(isfinite(durRef));

S.intervals = struct();
S.intervals.nMatched = numel(durDiff);

if ~isempty(durDiff)
    S.intervals.durDiffAbs_median = median(durDiff,'omitnan');
    S.intervals.durDiffAbs_mean   = mean(durDiff,'omitnan');
    S.intervals.durDiffAbs_p90    = prctile(durDiff,90);
else
    S.intervals.durDiffAbs_median = NaN;
    S.intervals.durDiffAbs_mean   = NaN;
    S.intervals.durDiffAbs_p90    = NaN;
end

S.intervals.all = struct();
S.intervals.all.nTest = numel(durTest);
S.intervals.all.nRef  = numel(durRef);
S.intervals.all.medTest = median(durTest,'omitnan');
S.intervals.all.medRef  = median(durRef,'omitnan');
S.intervals.all.iqrTest = iqr(durTest);
S.intervals.all.iqrRef  = iqr(durRef);

S.intervals.all.ks2_p = NaN;
S.intervals.all.ks2_D = NaN;
if numel(durTest) >= 2 && numel(durRef) >= 2
    try
        [~,p,D] = kstest2(durTest, durRef);
        S.intervals.all.ks2_p = p;
        S.intervals.all.ks2_D = D;
    catch
    end
end

binW2 = 1.0;
mx = 0;
if ~isempty(durDiff), mx = max(mx, max(durDiff)); end
edges2 = 0:binW2:(mx+binW2);
if numel(edges2)<2, edges2=[0 1]; end
counts2 = histcounts(durDiff, edges2);
S.intervals.durDiffHist = struct('edges',edges2,'counts',counts2,'binW',binW2);

end


function [dbg, dbgMaxROI, dbgMaxLabels, dbgPrintRules] = localGetDbg(args)
dbg = false; dbgMaxROI=5; dbgMaxLabels=12; dbgPrintRules=true;
try
    if isfield(args,'DebugEventsCompare') && ~isempty(args.DebugEventsCompare), dbg = logical(args.DebugEventsCompare); end
    if isfield(args,'DebugMaxROI') && ~isempty(args.DebugMaxROI), dbgMaxROI = double(args.DebugMaxROI); end
    if isfield(args,'DebugMaxLabels') && ~isempty(args.DebugMaxLabels), dbgMaxLabels = double(args.DebugMaxLabels); end
    if isfield(args,'DebugPrintRules') && ~isempty(args.DebugPrintRules), dbgPrintRules = logical(args.DebugPrintRules); end
catch
end
end

function localLog(args, fmt, varargin)
[dbg] = localGetDbg(args);
if ~dbg, return; end
fprintf('[eventsCompare %s] %s\n', datestr(now,'HH:MM:SS.FFF'), sprintf(fmt, varargin{:}));
end


function E = localCollectAllEvents(roiListAll, dsKeys, rulesByKey, args)

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

    if isKey(rulesByKey, keyChar)
    v = rulesByKey(keyChar);
    try
        cls = class(v);
    catch
        cls = "<no class>";
    end
    try
        sz = size(v);
        szs = sprintf('%dx%d', sz(1), sz(2));
    catch
        szs = "<no size>";
    end

    f = {};
    try
        if isstruct(v), f = fieldnames(v); end
    catch
    end

    localLog(args,'rulesByKey("%s"): class=%s size=%s isstruct=%d fields=%s isempty=%d', ...
        string(dsKey), cls, szs, isstruct(v), strjoin(string(f),','), isempty(v));
end



    % convert GUI rules -> internal rules with color/marker/linewidth
    rules = localConvertGUIRules(rulesGUI,args);

        localLog(args,'dsKey=%s : rulesGUI=%d -> rules=%d', string(dsKey), numel(rulesGUI), numel(rules));

    if numel(rules)>0
        [~,~,~,dbgPrintRules] = localGetDbg(args);
        if dbgPrintRules
            for k=1:min(10,numel(rules))
                localLog(args,'  rule[%d] "%s" : "%s" -> "%s"', k, string(rules(k).Name), string(rules(k).From), string(rules(k).To));
            end
        end
    end


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

dsKeyStr = string(dsKey);      % <-- FIX
seqLabels = seq;               % <-- FIX (on passe la séquence brute, la fonction convertit)

E(iR,iDS).dsKey = dsKeyStr;

if isempty(seqLabels)
    E(iR,iDS).events  = struct('frame',{},'name',{},'type',{},'color',{},'marker',{},'linewidth',{});

    E(iR,iDS).nFrames = 0;
else
    E(iR,iDS).nFrames = numel(seqLabels);
    E(iR,iDS).events  = localDetectEventsFromTransitions(seqLabels, rules, args, iR, iDS, dsKeyStr);
end


            % light per-ROI sampling
        [~,dbgMaxROI] = localGetDbg(args);
        if iR <= dbgMaxROI
            localLog(args,'ROI %d ds=%d (%s): nFrames=%d, nEvents=%d', iR, iDS, string(dsKey), E(iR,iDS).nFrames, numel(E(iR,iDS).events));
        end
    end
end
end

function rules = localConvertGUIRules(rulesGUI, args)
% GUI rules fields: name,type,from,to
% Output rules fields: From,To,Name,Type,Color,Marker,LineWidth

localLog(args,'ConvertGUIRules: input=%d', numel(rulesGUI));

% canonical empty struct (ALL fields present)
emptyRule = struct( ...
    'From',      "", ...
    'To',        "", ...
    'Name',      "", ...
    'Type',      "", ...          % <-- KEEP type ("start"/"end")
    'Color',     [0 0 0], ...
    'Marker',    '|', ...
    'LineWidth', 2);

rules = repmat(emptyRule, 0, 1);
if isempty(rulesGUI), return; end

names = strings(0,1);

for i = 1:numel(rulesGUI)

    fr = ""; to = ""; nm = ""; tp = "";

    try, if isfield(rulesGUI(i),'from'), fr = string(rulesGUI(i).from); end, catch, end
    try, if isfield(rulesGUI(i),'to'),   to = string(rulesGUI(i).to);   end, catch, end
    try, if isfield(rulesGUI(i),'name'), nm = string(rulesGUI(i).name); end, catch, end
    try, if isfield(rulesGUI(i),'type'), tp = string(rulesGUI(i).type); end, catch, end

    fr = strtrim(fr);
    to = strtrim(to);
    nm = strtrim(nm);
    tp = lower(strtrim(tp));

    if strlength(fr)==0 || strlength(to)==0
        localLog(args,'  SKIP rule i=%d (from="%s", to="%s", name="%s")', i, fr, to, nm);
        continue;
    end

    % normalize type
    if tp == "start" || tp == "begin"
        tp = "start";
    elseif tp == "end" || tp == "stop" || tp == "finish"
        tp = "end";
    else
        % default: treat unknown/empty as "start" (conservative)
        tp = "start";
    end

    if strlength(nm)==0
        nm = fr + "->" + to; % keep stable naming
    end

    r = emptyRule;
    r.From = fr;
    r.To   = to;
    r.Name = nm;
    r.Type = tp;

    rules(end+1,1) = r; %#ok<AGROW>
    names(end+1,1) = nm; %#ok<AGROW>
end

localLog(args,'ConvertGUIRules: output=%d uniqueNames=%d', numel(rules), numel(unique(names,'stable')));

if isempty(rules), return; end

% stable colormap by unique names
u = unique(names, 'stable');
K = max(2, numel(u));
cmap = lines(K);

for i = 1:numel(rules)
    k = find(u == string(rules(i).Name), 1, 'first');
    rules(i).Color = cmap(k,:);
end
end


function ev = localDetectEventsFromTransitions(seqLabels, rules, args, iR, iDS, dsKeyStr)
% Detect transition events. Each rule produces events with:
%   frame, name, type ("start"/"end"), color, marker, linewidth
%
% NOTE: event frame is the "curr" index (transition prev->curr occurs at idx+1)

[dbg, dbgMaxROI, dbgMaxLabels] = localGetDbg(args);

L = localToStringLabels(seqLabels);
L = strtrim(L);
L = lower(L);
L = L(:);
n = numel(L);

ev = struct('frame',{},'name',{},'type',{},'color',{},'marker',{},'linewidth',{});
if n < 2 || isempty(rules)
    if dbg && iR <= dbgMaxROI
        localLog(args,'DetectEvents ROI%d ds=%d %s: n=%d rules=%d -> early return', iR, iDS, dsKeyStr, n, numel(rules));
    end
    return;
end

% sanitize empty labels
isEmpty = (strlength(L)==0);
L(isEmpty) = "<missing>";

if dbg && iR <= dbgMaxROI
    u = unique(L);
    u = u(1:min(dbgMaxLabels,end));
    localLog(args,'DetectEvents ROI%d ds=%d %s: n=%d uniqueLabels=%d first={%s}', ...
        iR, iDS, dsKeyStr, n, numel(unique(L)), strjoin(u, ", "));
end

prev = L(1:end-1);
curr = L(2:end);

nHitTot = 0;

for k = 1:numel(rules)
    fr = lower(strtrim(string(rules(k).From)));
    to = lower(strtrim(string(rules(k).To)));
    tp = lower(strtrim(string(rules(k).Type))); % "start"/"end"
    if tp ~= "start" && tp ~= "end"
        tp = "start";
    end

    hit = (prev == fr) & (curr == to);
    idx = find(hit) + 1;

    if dbg && iR <= dbgMaxROI
        localLog(args,'  rule[%d] "%s" (%s): "%s"->"%s" hits=%d', ...
            k, string(rules(k).Name), tp, fr, to, numel(idx));
        if ~isempty(idx)
            localLog(args,'    frames sample: %s', mat2str(idx(1:min(8,end))'));
        end
    end

    for ii = 1:numel(idx)
        e = struct();
        e.frame = idx(ii);
        e.name  = string(rules(k).Name);
        e.type  = tp; % <-- CRITICAL
        e.color = rules(k).Color;
        e.marker = rules(k).Marker;
        e.linewidth = rules(k).LineWidth;
        ev(end+1) = e; %#ok<AGROW>
    end

    nHitTot = nHitTot + numel(idx);
end

if dbg && iR <= dbgMaxROI
    localLog(args,'DetectEvents ROI%d ds=%d %s: totalEvents=%d (totalHits=%d)', iR, iDS, dsKeyStr, numel(ev), nHitTot);
end
end

function out = localRenderEventsFigure(out, roiListShown, idxShown, dsKeys, H, W, Gcmp, Groi, args)
% Render events figure in Compare mode with a HARD PIXEL CAP to avoid
% graphics timeout / handshaking issues.
%
% - Caps total raster size by downscaling W/H/Gcmp/Groi if needed.
% - Keeps event marks visible (min pixel width).
% - Builds figure with Visible='off' then shows it.

dsKeyA = dsKeys(1); % TEST (top)
dsKeyB = dsKeys(2); % REF  (bottom)

% -------------------- collect sequences and filter absent --------------------
[seqA, ~] = localCollectSequences(roiListShown, dsKeyA);
[seqB, ~] = localCollectSequences(roiListShown, dsKeyB);

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

% -------------------- parameters --------------------
eventWidthFrames = 1;
if isfield(args,'EventWidthFrames') && ~isempty(args.EventWidthFrames)
    eventWidthFrames = double(args.EventWidthFrames);
end

matchMaxDtFrames = 10;
if isfield(args,'MatchMaxDtFrames') && ~isempty(args.MatchMaxDtFrames)
    matchMaxDtFrames = double(args.MatchMaxDtFrames);
end

maxDurDiffForBlack = 10;
if isfield(args,'IntervalMaxDurDiffForBlack') && ~isempty(args.IntervalMaxDurDiffForBlack)
    maxDurDiffForBlack = double(args.IntervalMaxDurDiffForBlack);
end

% Manual bars geometry (normalized units)
left   = 0.08;
right  = 0.02;
top    = 0.06;
bottom = 0.07;
gap    = 0.05;

hDu = 0.05;  % grayscale bar height
hDt = 0.05;  % dt bar height

% Optional overrides
if isfield(args,'DtBarHeight') && ~isempty(args.DtBarHeight), hDt = double(args.DtBarHeight); end
if isfield(args,'DurBarHeight') && ~isempty(args.DurBarHeight), hDu = double(args.DurBarHeight); end

% -------------------- HARD PIXEL CAP (key part) --------------------
% Compute current raster size
W  = max(1, round(W));
H  = max(2, round(H));
Gcmp = max(1, round(Gcmp));
Groi = max(1, round(Groi));

nROI    = numel(roiListShown);
HperROI = 2*H + Gcmp;
Htot    = nROI*HperROI + (nROI-1)*Groi;
Tw      = Tmax * W;

% Caps (can be overridden via args)
maxPixW = 2000;
maxPixH = 1500;
if isfield(args,'MaxEventsFigPixW') && ~isempty(args.MaxEventsFigPixW), maxPixW = double(args.MaxEventsFigPixW); end
if isfield(args,'MaxEventsFigPixH') && ~isempty(args.MaxEventsFigPixH), maxPixH = double(args.MaxEventsFigPixH); end

scaleW = min(1, maxPixW / max(1, Tw));
scaleH = min(1, maxPixH / max(1, Htot));
scale  = min(scaleW, scaleH);

if scale < 1
    W    = max(1, round(W * scale));
    H    = max(2, round(H * scale));
    Gcmp = max(1, round(Gcmp * scale));
    Groi = max(1, round(Groi * scale));

    % recompute after scaling
    HperROI = 2*H + Gcmp;
    Htot    = nROI*HperROI + (nROI-1)*Groi;
    Tw      = Tmax * W;
end

% -------------------- keep marks visible after downscale --------------------
eventWidthFrames = max(1, round(eventWidthFrames));
eventWidthPx     = max(2, eventWidthFrames * W);  % min 2 px so you still see it

% -------------------- figure + axes layout (build offscreen) --------------------
fe = figure('Name','Batonnets - Events (compare)', 'Color','w', 'Visible','off');
out.eventsFigure = fe;

wAll = 1 - left - right;

yDu   = bottom;
yDt   = yDu + hDu + gap;
yMain = yDt + hDt + gap;
hMain = 1 - top - yMain;

ax   = axes('Parent', fe, 'Units','normalized', 'Position', [left yMain wAll hMain]);
axDt = axes('Parent', fe, 'Units','normalized', 'Position', [left yDt  wAll hDt]);
axDu = axes('Parent', fe, 'Units','normalized', 'Position', [left yDu  wAll hDu]);

% -------------------- MAIN AX setup --------------------
ax.YDir = 'normal';
ax.Box  = 'off';
ax.Visible = 'on';
ax.Clipping = 'off';
ax.Color = 'w';
hold(ax,'on');

% Transparent base image to lock coordinates (no huge background RGB)
Cbase = NaN(Htot, Tw);
A = ~isnan(Cbase); % false everywhere
imagesc(ax, [0.5 Tw-0.5], [1 Htot], Cbase, 'AlphaData', A);

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

% -------------------- build overlays --------------------
% Events overlay (color, matched/unmatched)
[rgbEv, alphaEv, dtAll] = localBuildEventsOverlayMatched( ...
    out.events, idxShown, Tmax, H, W, Gcmp, Groi, nROI, eventWidthFrames, matchMaxDtFrames, args);

% Intervals overlay (BW on TEST)
[rgbInt, alphaInt, durDiffAll, dtStartAll, durTestAll, durRefAll, matchedLinkFramesAll] = localBuildIntervalsOverlayBW( ...
    out.events, idxShown, Tmax, H, W, Gcmp, Groi, nROI, matchMaxDtFrames, maxDurDiffForBlack);

% store aggregates
out.dtAll = dtAll;
out.intervalDurDiffAll = durDiffAll;
out.intervalDtAll      = dtStartAll;
out.intervalDurTestAll = durTestAll;
out.intervalDurRefAll  = durRefAll;
out.intervalMatchedLinkFramesAll = matchedLinkFramesAll;

% draw intervals (BW) first
if any(alphaInt(:))
    image(ax, [0.5 Tw-0.5], [1 Htot], rgbInt, 'AlphaData', alphaInt, 'HitTest','off');
end

% vector links + edges (keep line widths minimal but visible)
try
    localDrawMatchLinks(ax, out.events, idxShown, Tmax, H, W, Gcmp, Groi, nROI, matchMaxDtFrames);
catch
end
try
    localDrawIntervalLinks(ax, out.events, idxShown, Tmax, H, W, Gcmp, Groi, nROI, matchMaxDtFrames);
catch
end
try
    localDrawBatonnetEdges(ax, Tmax, H, W, Gcmp, Groi, nROI);
catch
end

% draw events overlay last (color)
if any(alphaEv(:))
    image(ax, [0.5 Tw-0.5], [1 Htot], rgbEv, 'AlphaData', alphaEv, 'HitTest','off');
end

% re-lock ticks (frame ticks in "frame" units, spaced)
xtFrames = localNiceFrameTicks(Tmax, 6);
set(ax, ...
    'XLim', [0 Tw], ...
    'YLim', [0.5 Htot+0.5], ...
    'XTick', xtFrames * W, ...
    'XTickLabel', string(xtFrames), ...
    'XLimMode','manual', ...
    'YLimMode','manual');
axis(ax,'manual');

text(ax, 0.99, 0.02, "Blue = FP(test) or FN(ref)", ...
    'Units','normalized', 'HorizontalAlignment','right', 'Color',[0 0 1], ...
    'FontWeight','bold', 'HitTest','off');

hold(ax,'off');

% -------------------- Δt manual bar (green -> red) --------------------
cla(axDt);
axDt.Visible  = 'on';
axDt.Box      = 'on';
axDt.Clipping = 'off';
axDt.TickDir  = 'out';
axDt.YTick    = [];
axDt.YColor   = [0 0 0];

N = 512;
a = linspace(0,1,N);
grad = zeros(1,N,3);
grad(1,:,1) = a;       % R
grad(1,:,2) = 1-a;     % G
grad(1,:,3) = 0;       % B

image(axDt, [0 matchMaxDtFrames], [0 1], grad, 'HitTest','off');
xlim(axDt, [0 matchMaxDtFrames]);
ylim(axDt, [0 1]);
axDt.YTick = [];
axDt.XTick = unique([0, round(linspace(0, matchMaxDtFrames, min(matchMaxDtFrames+1, 6)))]); %#ok<NBRAK>
xlabel(axDt, sprintf('|Δt| (frames), capped at %d', matchMaxDtFrames), 'Interpreter','none');

% -------------------- Δdur manual grayscale bar (white -> black) --------------------
cla(axDu);
axDu.Visible  = 'on';
axDu.Box      = 'on';
axDu.Clipping = 'off';
axDu.TickDir  = 'out';
axDu.YTick    = [];
axDu.YColor   = [0 0 0];

g = linspace(1,0,N); % white->black
grad2 = repmat(reshape(g,1,[],1), [1 1 3]);

image(axDu, [0 maxDurDiffForBlack], [0 1], grad2, 'HitTest','off');
xlim(axDu, [0 maxDurDiffForBlack]);
ylim(axDu, [0 1]);
axDu.YTick = [];
axDu.XTick = unique([0, round(linspace(0, maxDurDiffForBlack, min(maxDurDiffForBlack+1, 6)))]); %#ok<NBRAK>
xlabel(axDu, sprintf('|Δdur| intervals (frames): white=0 black≥%g', maxDurDiffForBlack), 'Interpreter','none');

% -------------------- show figure (after build) --------------------
drawnow limitrate nocallbacks
fe.Visible = 'on';
drawnow

% Optional: expose applied scaling (useful for debugging)
out.eventsFigureRender = struct();
out.eventsFigureRender.Tmax = Tmax;
out.eventsFigureRender.nROI = nROI;
out.eventsFigureRender.W = W;
out.eventsFigureRender.H = H;
out.eventsFigureRender.Gcmp = Gcmp;
out.eventsFigureRender.Groi = Groi;
out.eventsFigureRender.Tw = Tw;
out.eventsFigureRender.Htot = Htot;
out.eventsFigureRender.maxPixW = maxPixW;
out.eventsFigureRender.maxPixH = maxPixH;
out.eventsFigureRender.scaleApplied = scale;

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

function out = localPlotMatchStats(out, roiListShown, idxShown, matchMaxDtFrames, args)

nROI = numel(idxShown);
localLog(args,'PlotMatchStats: nROI=%d', nROI);

% -------------------- aggregate EVENT dt + FP/FN with NO-type matching --------------------
dtAll = [];
nTestE = 0; nRefE = 0; nFP = 0; nFN = 0;

for iR = 1:nROI
    iAll   = idxShown(iR);

    evTestRaw = out.events(iAll,1).events;
    evRefRaw  = out.events(iAll,2).events;

    evTest = localCollapseEventsForStats_(evTestRaw);
    evRef  = localCollapseEventsForStats_(evRefRaw);

    roiTag = sprintf('ROI%d(allIdx=%d)', iR, iAll);
    mt = localMatchEventsHungarianByName_IgnoreType_(evTest, evRef, matchMaxDtFrames, args, roiTag);

    nTestE = nTestE + numel(evTest);
    nRefE  = nRefE  + numel(evRef);
    nFP    = nFP    + sum(mt.testUnmatched);
    nFN    = nFN    + sum(mt.refUnmatched);

    if ~isempty(mt.dt)
        dtAll = [dtAll; mt.dt(:)]; %#ok<AGROW>
    end
end

fpFrac = nFP / max(1,nTestE);
fnFrac = nFN / max(1,nRefE);

localLog(args,'PlotMatchStats totals (events collapsed): nTestE=%d nRefE=%d nFP=%d nFN=%d', ...
    nTestE, nRefE, nFP, nFN);

% -------------------- interval aggregates (unchanged) --------------------
durDiffMatchedAbsAll = [];
if isfield(out,'intervalDurDiffAll'), durDiffMatchedAbsAll = out.intervalDurDiffAll; end

durTestAll = [];
durRefAll  = [];
if isfield(out,'intervalDurTestAll'), durTestAll = out.intervalDurTestAll; end
if isfield(out,'intervalDurRefAll'),  durRefAll  = out.intervalDurRefAll;  end

% -------------------- figure / tiledlayout 3x2 --------------------
fs = figure('Name','Events/Intervals matching stats (test vs ref)','Color','w');
out.eventsStatsFigure = fs;

tl = tiledlayout(fs, 3, 2, 'Padding','compact', 'TileSpacing','compact');

dtBinW    = 0.5;
durBinW   = 1.0;
durDiffW  = 1.0;

% ========== (1,1) matched event |dt| ==========
ax1 = nexttile(tl, 1);
if isempty(dtAll)
    text(ax1,0.5,0.5,"No matched events",'Units','normalized','HorizontalAlignment','center');
    axis(ax1,'off');
else
    x = abs(dtAll(:));
    edges = 0:dtBinW:max(matchMaxDtFrames, max(x,[],'omitnan')+dtBinW);
    histogram(ax1, x, 'BinEdges', edges);
    xlabel(ax1,'|Δt| matched events (frames)'); ylabel(ax1,'Count');
    title(ax1, sprintf('Matched EVENTS |Δt| (median=%.2f frames)', median(x,'omitnan')));
    xlim(ax1, [0 matchMaxDtFrames]);
end

% ========== (1,2) FP/FN events ==========
ax2 = nexttile(tl, 2);
bar(ax2, [fpFrac fnFrac]);
ax2.XTickLabel = {'FP(test)','FN(ref)'};
ylabel(ax2,'Fraction'); ylim(ax2,[0 1]);
title(ax2, sprintf('Events (collapsed start/end): FP=%d/%d (%.1f%%), FN=%d/%d (%.1f%%)', ...
    nFP, nTestE, 100*fpFrac, nFN, nRefE, 100*fnFrac));

% ========== (2,1) matched interval |Δdur| ==========
ax3 = nexttile(tl, 3);
if isempty(durDiffMatchedAbsAll)
    text(ax3,0.5,0.5,"No matched intervals",'Units','normalized','HorizontalAlignment','center');
    axis(ax3,'off');
else
    x = durDiffMatchedAbsAll(:);
    x = x(isfinite(x));
    if isempty(x)
        text(ax3,0.5,0.5,"No matched intervals",'Units','normalized','HorizontalAlignment','center');
        axis(ax3,'off');
    else
        edges = 0:durDiffW:(max(x)+durDiffW);
        histogram(ax3, x, 'BinEdges', edges);
        xlabel(ax3,'|Δdur| matched intervals (frames)'); ylabel(ax3,'Count');
        title(ax3, sprintf('Matched INTERVALS |Δdur| (median=%.2f frames)', median(x,'omitnan')));
    end
end

% ========== (2,2) ALL interval durations TEST vs REF ==========
ax4 = nexttile(tl, 4);
hold(ax4,'on');
if isempty(durTestAll) && isempty(durRefAll)
    text(ax4,0.5,0.5,"No intervals",'Units','normalized','HorizontalAlignment','center');
    axis(ax4,'off');
else
    durTestAll = durTestAll(:); durRefAll = durRefAll(:);
    durTestAll = durTestAll(isfinite(durTestAll));
    durRefAll  = durRefAll(isfinite(durRefAll));

    mx = 0;
    if ~isempty(durTestAll), mx = max(mx, max(durTestAll)); end
    if ~isempty(durRefAll),  mx = max(mx, max(durRefAll));  end
    edges = 0:durBinW:(mx + durBinW);

    if ~isempty(durRefAll)
        histogram(ax4, durRefAll, 'BinEdges', edges, 'Normalization','probability', ...
            'DisplayStyle','stairs', 'LineWidth',1.5);
    end
    if ~isempty(durTestAll)
        histogram(ax4, durTestAll, 'BinEdges', edges, 'Normalization','probability', ...
            'DisplayStyle','stairs', 'LineWidth',1.5);
    end

    xlabel(ax4,'Interval duration (frames)');
    ylabel(ax4,'Probability');
    legend(ax4, {'REF (all intervals)','TEST (all intervals)'}, 'Location','northeast');

    medT = median(durTestAll,'omitnan'); medR = median(durRefAll,'omitnan');
    iqrT = iqr(durTestAll);              iqrR = iqr(durRefAll);

    p = NaN; ksD = NaN;
    if numel(durTestAll) >= 2 && numel(durRefAll) >= 2
        try
            [~,p,ksD] = kstest2(durTestAll, durRefAll);
        catch
        end
    end

    title(ax4, sprintf('All interval durations: med(T)=%.2f IQR(T)=%.2f | med(R)=%.2f IQR(R)=%.2f | KS2 p=%.3g (D=%.3g)', ...
        medT, iqrT, medR, iqrR, p, ksD));
end
hold(ax4,'off');

% ========== (3,1) loglog matched intervals REF vs TEST (unchanged) ==========
ax5 = nexttile(tl, 5);

xRef = []; yTest = [];
for iR = 1:nROI
    iAll   = idxShown(iR);
    evTest = out.events(iAll,1).events;
    evRef  = out.events(iAll,2).events;

    mt = localMatchEventsHungarianByName(evTest, evRef, matchMaxDtFrames);
    I  = localIntervalsAllAndMatchedFromEventMatch(evTest, evRef, mt);

    if isfield(I,'matchedRefDur') && ~isempty(I.matchedRefDur)
        xRef  = [xRef;  I.matchedRefDur(:)];  %#ok<AGROW>
        yTest = [yTest; I.matchedTestDur(:)]; %#ok<AGROW>
    end
end

if isempty(xRef)
    text(ax5,0.5,0.5,"No matched intervals for log-log scatter",'Units','normalized','HorizontalAlignment','center');
    axis(ax5,'off');
else
    ok = isfinite(xRef) & isfinite(yTest) & xRef>0 & yTest>0;
    xRef  = xRef(ok);
    yTest = yTest(ok);

    if isempty(xRef)
        text(ax5,0.5,0.5,"No valid (>0) matched intervals for log-log scatter",'Units','normalized','HorizontalAlignment','center');
        axis(ax5,'off');
    else
        loglog(ax5, xRef, yTest, '.', 'MarkerSize',10);
        hold(ax5,'on');
        mn = min([xRef; yTest]);
        mx = max([xRef; yTest]);
        loglog(ax5, [mn mx], [mn mx], 'k--', 'LineWidth',1);
        hold(ax5,'off');
        grid(ax5,'on');

        rLin = NaN; rLog = NaN;
        try
            if numel(xRef) >= 2
                rLin = corr(xRef, yTest, 'Rows','complete');
                rLog = corr(log10(xRef), log10(yTest), 'Rows','complete');
            end
        catch
        end

        xlabel(ax5,'REF interval duration (frames)');
        ylabel(ax5,'TEST interval duration (frames)');
        title(ax5, sprintf('Matched intervals (log-log): n=%d | r=%.3f | r(log10)=%.3f', numel(xRef), rLin, rLog));
    end
end

% ========== (3,2) empty ==========
ax6 = nexttile(tl, 6);
axis(ax6,'off');
text(ax6, 0.5, 0.5, " ", 'Units','normalized', 'HorizontalAlignment','center');

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


function [rgb, alpha, dtAll] = localBuildEventsOverlayMatched(Eall, idxShown, Tmax, H, W, Gcmp, Groi, nROI, eventWidthFrames, matchMaxDtFrames,args)

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

colBlue  = [0 0 1];
colBlack = [0 0 0];
dt2col = @(dtAbs, dtMax) [min(dtAbs/dtMax,1), max(0,1-dtAbs/dtMax), 0];

row0 = 1;
for iR = 1:nROI
    iAll = idxShown(iR);

    rA0 = row0;
    rA1 = row0 + H - 1;

    rB0 = row0 + H + Gcmp;
    rB1 = rB0 + H - 1;

    evTestRaw = Eall(iAll,1).events; % test top
    evRefRaw  = Eall(iAll,2).events; % ref bottom

    % collapse duplicates for display logic (so FP/FN not doubled)
    evTest = localCollapseEventsForStats_(evTestRaw);
    evRef  = localCollapseEventsForStats_(evRefRaw);

    mt = localMatchEventsHungarianByName_IgnoreType_(evTest, evRef, matchMaxDtFrames, args, sprintf('ROI%d', iR));

    % --- REF rendering (black if matched, blue if FN) ---
    for k = 1:numel(evRef)
        t = evRef(k).frame;
        if ~isfinite(t) || t < 1 || t > Tmax, continue; end

        if mt.refUnmatched(k)
            c = colBlue;
        else
            c = colBlack;
        end

        [col0,col1] = localEventColRange(t, W, Tw, eventWidthPx);

        rgb(rB0:rB1, col0:col1, 1) = uint8(255*c(1));
        rgb(rB0:rB1, col0:col1, 2) = uint8(255*c(2));
        rgb(rB0:rB1, col0:col1, 3) = uint8(255*c(3));
        alpha(rB0:rB1, col0:col1)  = 1;
    end

    % --- TEST rendering (blue if FP, else green->red by |dt|) ---
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
            c = colBlue;
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

function [frames, keys, valid] = localExtractEventFramesKeys(ev)
% Robust extraction of event frames + matching key (name|type)
n = numel(ev);
frames = nan(n,1);
keys   = strings(n,1);

for i = 1:n
    % frame
    if isfield(ev(i),'frame') && isnumeric(ev(i).frame) && isscalar(ev(i).frame) && isfinite(ev(i).frame)
        frames(i) = double(ev(i).frame);
    end

    % name
    nm = "";
    if isfield(ev(i),'name') && ~isempty(ev(i).name)
        nm = string(ev(i).name);
    end
    nm = lower(strtrim(nm));

    % type
    tp = "";
    if isfield(ev(i),'type') && ~isempty(ev(i).type)
        tp = string(ev(i).type);
    end
    tp = lower(strtrim(tp));
    if tp ~= "start" && tp ~= "end"
        tp = "start"; % fallback conservative
    end

    if strlength(nm) > 0
        keys(i) = nm + "|" + tp;   % <-- CRITICAL
    end
end

valid = isfinite(frames) & (strlength(keys) > 0);
end

function ev2 = localCollapseEventsForStats_(ev)
% Collapse "start/end artifice" so one transition counts once:
% key = lower(name) + "@" + frame
% Keeps one representative per (name,frame). Type is kept but irrelevant.

ev2 = ev;
if isempty(ev), return; end

n = numel(ev);
frames = nan(n,1);
names  = strings(n,1);

for i = 1:n
    if isfield(ev(i),'frame') && isnumeric(ev(i).frame) && isscalar(ev(i).frame) && isfinite(ev(i).frame)
        frames(i) = double(ev(i).frame);
    end
    nm = "";
    if isfield(ev(i),'name') && ~isempty(ev(i).name)
        nm = lower(strtrim(string(ev(i).name)));
    end
    names(i) = nm;
end

valid = isfinite(frames) & (strlength(names) > 0);
if ~any(valid)
    ev2 = ev([]); % empty, same type
    return;
end

frames = frames(valid);
names  = names(valid);
idxMap = find(valid);

% build unique key per transition occurrence
keys = names + "@" + string(frames);

% keep first occurrence for each key (stable)
[~, ia] = unique(keys, 'stable');
keepIdx = idxMap(ia);

ev2 = ev(keepIdx);

% Optional: sort by frame (stable)
try
    fr2 = arrayfun(@(e) double(e.frame), ev2);
    [~,ord] = sort(fr2);
    ev2 = ev2(ord);
catch
end
end


function match = localMatchEventsHungarianByName_IgnoreType_(evTest, evRef, maxDt, args, roiTag)
% Match events by NAME ONLY (ignore start/end), after collapsing duplicates.
% Cost = |dt|, rejected if dt > maxDt.

if nargin < 4, args = struct(); end
if nargin < 5, roiTag = ""; end
if nargin < 3 || isempty(maxDt), maxDt = 10; end

% collapse the "start/end artifice" duplicates
evTest = localCollapseEventsForStats_(evTest);
evRef  = localCollapseEventsForStats_(evRef);

localLog(args,'MatchEvents(noType) %s: nTest=%d nRef=%d maxDt=%g', roiTag, numel(evTest), numel(evRef), maxDt);

% frames + keys (NAME ONLY)
nT = numel(evTest); nR = numel(evRef);
tFrames = nan(nT,1); tKeys = strings(nT,1);
rFrames = nan(nR,1); rKeys = strings(nR,1);

for i=1:nT
    if isfield(evTest(i),'frame') && isfinite(evTest(i).frame), tFrames(i)=double(evTest(i).frame); end
    nm=""; if isfield(evTest(i),'name') && ~isempty(evTest(i).name), nm=string(evTest(i).name); end
    tKeys(i)=lower(strtrim(nm));
end
for i=1:nR
    if isfield(evRef(i),'frame') && isfinite(evRef(i).frame), rFrames(i)=double(evRef(i).frame); end
    nm=""; if isfield(evRef(i),'name') && ~isempty(evRef(i).name), nm=string(evRef(i).name); end
    rKeys(i)=lower(strtrim(nm));
end

validT = isfinite(tFrames) & (strlength(tKeys)>0);
validR = isfinite(rFrames) & (strlength(rKeys)>0);

match = struct();
match.maxDt = maxDt;
match.pairs = zeros(0,2);
match.dt    = zeros(0,1);
match.testUnmatched = true(nT,1);
match.refUnmatched  = true(nR,1);

if isempty(evTest) || isempty(evRef) || ~any(validT) || ~any(validR)
    return;
end

allKeys = unique([tKeys(validT); rKeys(validR)]);

for kKey = 1:numel(allKeys)
    kk = allKeys(kKey);

    it = find(validT & (tKeys == kk));
    ir = find(validR & (rKeys == kk));
    if isempty(it) || isempty(ir), continue; end

    Ct = tFrames(it);
    Cr = rFrames(ir);

    cost = abs(Ct - Cr');
    cost(cost > maxDt) = Inf;

    if ~any(isfinite(cost(:)))
        continue;
    end

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

localLog(args,'MatchEvents(noType) %s DONE: pairs=%d', roiTag, size(match.pairs,1));
end


function match = localMatchEventsHungarianByName(evTest, evRef, maxDt, args, roiTag)
% Match events using Hungarian (matchpairs), by key = lower(name)|type.
% Cost = |dt|, rejected if dt > maxDt.

if nargin < 4, args = struct(); end
if nargin < 5, roiTag = ""; end
if nargin < 3 || isempty(maxDt), maxDt = 10; end

localLog(args,'MatchEvents %s: nTest=%d nRef=%d maxDt=%g', roiTag, numel(evTest), numel(evRef), maxDt);

% frames + keys
[tFrames, tKeys, validT] = localExtractEventFramesKeys(evTest);
[rFrames, rKeys, validR] = localExtractEventFramesKeys(evRef);

if any(~validT) && numel(evTest)>0
    localLog(args,'  %s invalid test events: %d/%d', roiTag, sum(~validT), numel(evTest));
end
if any(~validR) && numel(evRef)>0
    localLog(args,'  %s invalid ref events: %d/%d', roiTag, sum(~validR), numel(evRef));
end

uT = unique(tKeys(validT));
uR = unique(rKeys(validR));
uI = intersect(uT,uR);

localLog(args,'  %s uniqueKeys: test=%d ref=%d intersect=%d', roiTag, numel(uT), numel(uR), numel(uI));
if ~isempty(uT), localLog(args,'   test keys sample: %s', strjoin(uT(1:min(8,end)), ", ")); end
if ~isempty(uR), localLog(args,'   ref  keys sample: %s', strjoin(uR(1:min(8,end)), ", ")); end

match = struct();
match.maxDt = maxDt;
match.pairs = zeros(0,2);                 % [iTest, iRef] indices in evTest/evRef
match.dt    = zeros(0,1);                 % signed dt = test - ref
match.testUnmatched = true(numel(evTest),1);
match.refUnmatched  = true(numel(evRef),1);

if isempty(evTest) || isempty(evRef)
    return;
end

allKeys = unique([tKeys(validT); rKeys(validR)]);

for kKey = 1:numel(allKeys)
    kk = allKeys(kKey);

    it = find(validT & (tKeys == kk));
    ir = find(validR & (rKeys == kk));
    if isempty(it) || isempty(ir)
        continue;
    end

    localLog(args,'  %s key="%s": nT=%d nR=%d', roiTag, kk, numel(it), numel(ir));

    Ct = tFrames(it);
    Cr = rFrames(ir);

    cost = abs(Ct - Cr');        % [nT x nR]
    cost(cost > maxDt) = Inf;

    nFinite = sum(isfinite(cost(:)));
    if nFinite == 0
        localLog(args,'    cost finite=0/%d -> skip (all costs>maxDt)', numel(cost));
        continue;
    else
        localLog(args,'    cost finite=%d/%d min=%.3g', nFinite, numel(cost), min(cost(isfinite(cost))));
    end

    [ass, ~, ~] = matchpairs(cost, maxDt);

    if isempty(ass)
        localLog(args,'    matchpairs -> empty');
        continue;
    else
        localLog(args,'    matchpairs -> %d pairs', size(ass,1));
    end

    for m = 1:size(ass,1)
        iTest = it(ass(m,1));
        iRef  = ir(ass(m,2));
        match.pairs(end+1,:) = [iTest, iRef]; %#ok<AGROW>
        match.dt(end+1,1)    = tFrames(iTest) - rFrames(iRef); %#ok<AGROW>
        match.testUnmatched(iTest) = false;
        match.refUnmatched(iRef)   = false;
    end
end

localLog(args,'MatchEvents %s DONE: pairs=%d', roiTag, size(match.pairs,1));
end


function localDrawMatchLinks(ax, Eall, idxShown, Tmax, H, W, Gcmp, Groi, nROI, matchMaxDtFrames)
% Draw thin black lines connecting matched events (test top -> ref bottom)
% Using collapsed events (ignore type) to avoid double links.

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

    evTest = localCollapseEventsForStats_(Eall(iAll,1).events);
    evRef  = localCollapseEventsForStats_(Eall(iAll,2).events);

    mt = localMatchEventsHungarianByName_IgnoreType_(evTest, evRef, matchMaxDtFrames);

    for m = 1:size(mt.pairs,1)
        iT  = mt.pairs(m,1);
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
% Build:
% - ALL interval durations (TEST + REF) for distributions, from typed intervals
% - MATCHED intervals by Hungarian matching on interval start (|dtStart| <= mt.maxDt or 10)
%
% INTERVAL DEFINITION (as agreed):
% - Any START with any END can define an interval, but in practice we build
%   intervals by scanning events ordered by (frame asc, END before START at same frame).
% - Valid interval requires endFrame >= startFrame + 1 (no zero-length).
% - If startFrame == endFrame: close previous (if any) and immediately open new (END then START).

I = struct();
I.testDurAll = [];
I.refDurAll  = [];
I.matchedRefDur = [];
I.matchedTestDur = [];
I.matchedDurDiffAbs = [];
I.matchedLinkFrames = zeros(0,4);  % [t0 t1 r0 r1]

% derive maxDt
maxDt = 10;
try
    if isstruct(mt) && isfield(mt,'maxDt') && ~isempty(mt.maxDt) && isfinite(mt.maxDt)
        maxDt = double(mt.maxDt);
    end
catch
end

% typed intervals for each side
It = localIntervalsFromTypedEvents_(evTest);
Ir = localIntervalsFromTypedEvents_(evRef);

% ALL durations (for distributions)
if ~isempty(It)
    I.testDurAll = [It.dur]';
end
if ~isempty(Ir)
    I.refDurAll  = [Ir.dur]';
end

% MATCH intervals by startFrame proximity (Hungarian), then compute dur diffs
M = localMatchIntervalsHungarian(It, Ir, maxDt);
if isempty(M) || ~isfield(M,'pairs') || isempty(M.pairs)
    return;
end

for m = 1:size(M.pairs,1)
    iT = M.pairs(m,1);
    iR = M.pairs(m,2);

    t0 = double(It(iT).startFrame);
    t1 = double(It(iT).endFrame);
    r0 = double(Ir(iR).startFrame);
    r1 = double(Ir(iR).endFrame);

    durT = double(It(iT).dur);
    durR = double(Ir(iR).dur);

    I.matchedTestDur(end+1,1)    = durT; %#ok<AGROW>
    I.matchedRefDur(end+1,1)     = durR; %#ok<AGROW>
    I.matchedDurDiffAbs(end+1,1) = abs(durT - durR); %#ok<AGROW>
    I.matchedLinkFrames(end+1,:) = [t0 t1 r0 r1]; %#ok<AGROW>
end

end

% -------------------------------------------------------------------------
% Local helper: build intervals from typed events with END before START tie
% -------------------------------------------------------------------------
function Itv = localIntervalsFromTypedEvents_(ev)
% Returns struct array with fields startFrame,endFrame,dur

Itv = struct('startFrame',{},'endFrame',{},'dur',{});
if isempty(ev), return; end

% extract valid frame + type
n = numel(ev);
frames = nan(n,1);
isEnd  = false(n,1);   % end has priority at same frame
valid  = false(n,1);

for i = 1:n
    % frame
    if isstruct(ev) && isfield(ev(i),'frame') && isnumeric(ev(i).frame) && isscalar(ev(i).frame) && isfinite(ev(i).frame)
        frames(i) = double(ev(i).frame);
    end

    % type
    tp = "";
    if isstruct(ev) && isfield(ev(i),'type') && ~isempty(ev(i).type)
        tp = lower(strtrim(string(ev(i).type)));
    end
    if tp == "end"
        isEnd(i) = true;
    elseif tp == "start"
        isEnd(i) = false;
    else
        % default unknown -> start (conservative)
        isEnd(i) = false;
    end

    valid(i) = isfinite(frames(i));
end

frames = frames(valid);
isEnd  = isEnd(valid);

if isempty(frames), return; end

% sort by frame asc, and for ties: END first
% (i.e. isEnd==true should come before isEnd==false)
[~, ord] = sortrows([frames, double(~isEnd)]); % ~isEnd: end->0, start->1
frames = frames(ord);
isEnd  = isEnd(ord);

openStart = NaN;
kOut = 0;

for k = 1:numel(frames)
    t = frames(k);

    if isEnd(k)
        % close if open
        if isfinite(openStart)
            if t >= openStart + 1
                kOut = kOut + 1;
                Itv(kOut,1).startFrame = openStart;
                Itv(kOut,1).endFrame   = t;
                Itv(kOut,1).dur        = t - openStart;
            end
            % close regardless (even if t==openStart, we discard zero-length)
            openStart = NaN;
        end

    else
        % start
        if ~isfinite(openStart)
            openStart = t;
        else
            % multiple starts without end: keep the FIRST (conservative)
            % If you prefer "last start wins", replace with: openStart = t;
        end
    end
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
