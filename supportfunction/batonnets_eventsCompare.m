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
out = localRenderEventsFigure(out, roiListShown, idxShown, dsKeys, H, W, Gcmp, Groi);


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

function out = localRenderEventsFigure(out, roiListShown, idxShown, dsKeys, H, W, Gcmp, Groi)

% --- collect sequences on SHOWN to decide keep + Tmax (same logic as compare) ---
dsKeyA = dsKeys(1);
dsKeyB = dsKeys(2);

[seqA, TmaxA] = localCollectSequences(roiListShown, dsKeyA);
[seqB, TmaxB] = localCollectSequences(roiListShown, dsKeyB);
Tmax = max(TmaxA, TmaxB);

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

Tw   = Tmax * W;
nROI = numel(roiListShown);
HperROI = 2*H + Gcmp;
Htot = nROI*HperROI + (nROI-1)*Groi;

% --- FIGURE/AXES (NO tiledlayout) ---
fe = figure('Name','Batonnets - Events (compare)','Color','w');
out.eventsFigure = fe;
ax = axes('Parent', fe);

ax.YDir = 'normal';
ax.Box  = 'off';
ax.Visible = 'on';
ax.Clipping = 'off';
hold(ax,'on');

% --- base "transparent" image (same spirit as compare classes) ---
Cbase = NaN(Htot, Tw);
A = ~isnan(Cbase);             % false everywhere
imagesc(ax, [0.5 Tw-0.5], [1 Htot], Cbase, 'AlphaData', A);

xlim(ax, [0 Tw]);
ylim(ax, [0.5 Htot+0.5]);
xlabel(ax, "Frame");

% ticks frames -> pixels (same logic)
xtFrames = localNiceFrameTicks(Tmax, 6);
ax.XTick = xtFrames * W;
ax.XTickLabel = string(xtFrames);

% y labels
ax.YTick = localRoiPairCenters(nROI, H, Gcmp, Groi);
ax.YTickLabel = cellstr(string({roiListShown.label}));
ax.TickLabelInterpreter = 'none';

title(ax, "Events (compare): " + dsKeys(1) + " ↔ " + dsKeys(2), ...
    'Interpreter','none', 'FontWeight','bold');

% --- overlay events as ONE image ---
[rgb, alpha] = localBuildEventsOverlay(out.events, idxShown, Tmax, H, W, Gcmp, Groi, nROI);
image(ax, [0.5 Tw-0.5], [1 Htot], rgb, 'AlphaData', alpha, 'HitTest','off');

% HARD lock (important)
xlim(ax, [0 Tw]); ylim(ax, [0.5 Htot+0.5]);
ax.XLimMode = 'manual'; ax.YLimMode = 'manual';
axis(ax,'manual');

hold(ax,'off');

% (DEBUG) comment this back later
% localLegendFromEvents(ax, out.events, idxShown);

end

function [rgb, alpha] = localBuildEventsOverlay(Eall, idxShown, Tmax, H, W, Gcmp, Groi, nROI)
Tw = Tmax * W;
HperROI = 2*H + Gcmp;
Htot    = nROI*HperROI + (nROI-1)*Groi;

rgb   = zeros(Htot, Tw, 3, 'uint8');
alpha = zeros(Htot, Tw, 'single');

hMark = max(1, floor(H/2));

row0 = 1;
for iR = 1:nROI
    iAll = idxShown(iR);

    rA1 = row0 + H - 1;
    rA0 = max(row0, rA1 - hMark + 1);

    rBbase = row0 + H + Gcmp;
    rB0 = rBbase;
    rB1 = min(rBbase + hMark - 1, rBbase + H - 1);

    % A events
    evA = Eall(iAll,1).events;
    for k = 1:numel(evA)
        t = evA(k).frame;
        if ~isfinite(t) || t < 1 || t > Tmax, continue; end
        c = evA(k).color;
        if numel(c)~=3 || any(~isfinite(c)), continue; end
        col0 = (t-1)*W + 1;
        col1 = min(t*W, Tw);
        rgb(rA0:rA1, col0:col1, 1) = uint8(255*c(1));
        rgb(rA0:rA1, col0:col1, 2) = uint8(255*c(2));
        rgb(rA0:rA1, col0:col1, 3) = uint8(255*c(3));
        alpha(rA0:rA1, col0:col1)  = 1;
    end

    % B events
    evB = Eall(iAll,2).events;
    for k = 1:numel(evB)
        t = evB(k).frame;
        if ~isfinite(t) || t < 1 || t > Tmax, continue; end
        c = evB(k).color;
        if numel(c)~=3 || any(~isfinite(c)), continue; end
        col0 = (t-1)*W + 1;
        col1 = min(t*W, Tw);
        rgb(rB0:rB1, col0:col1, 1) = uint8(255*c(1));
        rgb(rB0:rB1, col0:col1, 2) = uint8(255*c(2));
        rgb(rB0:rB1, col0:col1, 3) = uint8(255*c(3));
        alpha(rB0:rB1, col0:col1)  = 1;
    end

    row0 = row0 + HperROI;
    if iR < nROI
        row0 = row0 + Groi;
    end
end
end


function localOverlayEventsPixels(ax, Eall, idxShown, Tmax, H, W, Gcmp, Groi, nROI)
% Build an RGB image + Alpha mask, like localOverlayMismatchPixels,
% but for events (frame -> colored marker bands).

Tw = Tmax * W;

HperROI = 2*H + Gcmp;
Htot    = nROI*HperROI + (nROI-1)*Groi;

% alpha per event-color: we can't have per-pixel colormap with single alpha,
% so we build an RGB image with alpha 1 on event pixels.
rgb   = zeros(Htot, Tw, 3, 'uint8');
alpha = zeros(Htot, Tw, 'single');

hMark = max(1, floor(H/2));

row0 = 1;
for iR = 1:nROI
    iAll = idxShown(iR);

    % A band
    rA1 = row0 + H - 1;
    rA0 = max(row0, rA1 - hMark + 1);

    % B band
    rBbase = row0 + H + Gcmp;
    rB0 = rBbase;
    rB1 = min(rBbase + hMark - 1, rBbase + H - 1);

    % --- events A ---
    evA = Eall(iAll,1).events;
    for k = 1:numel(evA)
        t = evA(k).frame;
        if ~isfinite(t) || t < 1 || t > Tmax, continue; end
        c = evA(k).color;
        if numel(c)~=3 || any(~isfinite(c)), continue; end

        col0 = (t-1)*W + 1;
        col1 = min(t*W, Tw);

        rgb(rA0:rA1, col0:col1, 1) = uint8(255*c(1));
        rgb(rA0:rA1, col0:col1, 2) = uint8(255*c(2));
        rgb(rA0:rA1, col0:col1, 3) = uint8(255*c(3));
        alpha(rA0:rA1, col0:col1)  = 1;
    end

    % --- events B ---
    evB = Eall(iAll,2).events;
    for k = 1:numel(evB)
        t = evB(k).frame;
        if ~isfinite(t) || t < 1 || t > Tmax, continue; end
        c = evB(k).color;
        if numel(c)~=3 || any(~isfinite(c)), continue; end

        col0 = (t-1)*W + 1;
        col1 = min(t*W, Tw);

        rgb(rB0:rB1, col0:col1, 1) = uint8(255*c(1));
        rgb(rB0:rB1, col0:col1, 2) = uint8(255*c(2));
        rgb(rB0:rB1, col0:col1, 3) = uint8(255*c(3));
        alpha(rB0:rB1, col0:col1)  = 1;
    end

    row0 = row0 + HperROI;
    if iR < nROI
        row0 = row0 + Groi;
    end
end

hold(ax,'on');
image(ax, [0.5 Tw-0.5], [1 Htot], rgb, 'AlphaData', alpha, 'HitTest','off');
hold(ax,'off');
end

function localLegendFromEvents(ax, Eall, idxShown)
names = strings(0,1);
cols  = zeros(0,3);

nROI = numel(idxShown);
for j=1:2
    for iR=1:nROI
        iAll = idxShown(iR);
        evs = Eall(iAll,j).events;
        for k=1:numel(evs)
            nm = string(evs(k).name);
            c  = evs(k).color;
            if strlength(nm)==0 || numel(c)~=3, continue; end
            names(end+1,1) = nm; %#ok<AGROW>
            cols(end+1,:)  = c;  %#ok<AGROW>
        end
    end
end

if isempty(names), return; end
[un, ia] = unique(names, 'stable');

h = gobjects(0,1);
for i=1:numel(un)
    h(end+1) = plot(ax, nan, nan, 'LineWidth', 6, 'Color', cols(ia(i),:)); %#ok<AGROW>
end
legend(ax, h, cellstr(un), 'Interpreter','none', 'Location','eastoutside');
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
