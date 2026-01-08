function stats = batonnets_compareStats(roiListAll, dsKeysCompare, globalLabelMap, args)
% BATONNETS_COMPARESTATS  Compare two dataseries on ALL ROIs and plot confusion-style stats.
%
% SYNTAX
%   stats = batonnets_compareStats(roiListAll, dsKeysCompare, globalLabelMap, args)
%
% INPUTS
%   roiListAll     : 1xN ROI struct list (fields: roiObj, label)
%   dsKeysCompare  : 1x2 string array ["dsA|varA", "dsB|varB"]
%   globalLabelMap : containers.Map(label->index) used for label variables (consistent across ROIs)
%   args           : struct with fields (optional):
%       - NumbersColormapName (string) : for numeric mode fallback
%       - FigureHandle (optional)      : reuse figure if desired
%       - Title (string)              : custom title
%
% OUTPUT
%   stats : struct with fields:
%       - nPairs, mismatchRate
%       - confusionMatrix (KxK)
%       - classNames (Kx1 string)
%       - isLabel (logical)
%
% NOTES
% - Uses only positions where BOTH series are present at a given ROI/frame (~isnan(A)&~isnan(B)).
% - If variable is numeric, builds a binned-class representation (same as your renderer logic).

arguments
    roiListAll (1,:) struct
    dsKeysCompare (1,2) string
    globalLabelMap

    args.NumbersColormapName (1,1) string = "parula"
    args.FigureHandle = []
    args.Title (1,1) string = ""
end

dsKeyA = dsKeysCompare(1);
dsKeyB = dsKeysCompare(2);

% --- collect sequences on ALL rois ---
[seqA, TmaxA] = localCollectSequences(roiListAll, dsKeyA);
[seqB, TmaxB] = localCollectSequences(roiListAll, dsKeyB);
Tmax = max(TmaxA, TmaxB);

stats = struct();
stats.nPairs = 0;
stats.mismatchRate = NaN;
stats.confusionMatrix = [];
stats.classNames = strings(0,1);

if Tmax == 0
    localPlotEmpty(args.FigureHandle, localKeyTitle(dsKeyA) + " vs " + localKeyTitle(dsKeyB), "No data");
    return;
end

% label vs numeric
isLabel = localIsLabelSeqs(seqA) || localIsLabelSeqs(seqB);
stats.isLabel = isLabel;

if isLabel
    [CA, classNames] = localSequencesToGlobalIndex(seqA, Tmax, globalLabelMap);
    [CB, ~]          = localSequencesToGlobalIndex(seqB, Tmax, globalLabelMap);
else
    [CA, classNamesA] = localNumericToBinnedIndex(seqA, Tmax);
    [CB, classNamesB] = localNumericToBinnedIndex(seqB, Tmax);
    classNames = union(string(classNamesA), string(classNamesB), 'stable');
end

% valid pairs only
valid = ~isnan(CA) & ~isnan(CB);
a = CA(valid);
b = CB(valid);

stats.nPairs = numel(a);
if isempty(a)
    localPlotEmpty(args.FigureHandle, localKeyTitle(dsKeyA) + " vs " + localKeyTitle(dsKeyB), "No valid pairs (A & B)");
    stats.classNames = classNames;
    return;
end

stats.mismatchRate = mean(a ~= b);

K = max(1, numel(classNames));
cm = accumarray([a(:), b(:)], 1, [K K], @sum, 0);
stats.confusionMatrix = cm;
stats.classNames = classNames(:);

% --- plot ---
ttl = args.Title;
if strlength(ttl)==0
    ttl = localKeyTitle(dsKeyA) + "  ↔  " + localKeyTitle(dsKeyB);
end

% --- plot (confusionchart ne peut PAS être enfant d'un axes, donc on crée un axes placeholder) ---
if isempty(args.FigureHandle) || ~ishandle(args.FigureHandle)
    f = figure('Color','w','Name','Compare stats');
else
    f = args.FigureHandle;
    figure(f); clf(f);
end

ax = axes('Parent', f, 'Units','normalized', 'Position',[0.08 0.12 0.85 0.8]); %#ok<LAXES>
cc = localPlotConfusion(ax, cm, classNames, ttl, stats.mismatchRate, stats.nPairs);

% --- export-friendly handles + extra metrics ---
stats.figure = f;
stats.confusionchart = [];
try, stats.confusionchart = cc; catch, end

% Simple global metrics
try
    tot = sum(cm(:));
    diagv = sum(diag(cm));
    stats.accuracy = diagv / max(1, tot);
catch
    stats.accuracy = NaN;
end

end

% =========================
% Local helpers
% =========================
function [seqs, Tmax] = localCollectSequences(roiList, dsKey)
seqs = cell(numel(roiList),1);
Tmax = 0;
for iR = 1:numel(roiList)
    rr = roiList(iR).roiObj;
    needLoad = true;

try
    if isprop(rr,'data') && ~isempty(rr.data) && ~isempty(rr.data(1).data)
        needLoad = false;
    end
end

if needLoad
    try
        if ismethod(rr,'load')
            rr.load('data');
        end
    catch
    end
end
    s = localGetSequenceForKey(rr, dsKey);
    s = s(:)'; % row
    seqs{iR} = s;
    Tmax = max(Tmax, numel(s));
end
end

function tf = localIsLabelSeqs(seqs)
tf = any(cellfun(@(x) iscategorical(x) || isstring(x) || ischar(x) || ...
    (iscell(x) && all(cellfun(@(c)ischar(c)||isstring(c), x(:)))), seqs));
end

function [C, classNames] = localSequencesToGlobalIndex(seqs, Tmax, globalMap)
n = numel(seqs);
C = NaN(n, Tmax);

classNames = strings(globalMap.Count,1);
ks = globalMap.keys;
for i=1:numel(ks)
    classNames(globalMap(ks{i})) = string(ks{i});
end

for i=1:n
    lab = localToStringLabels(seqs{i});
    T = min(Tmax, numel(lab));
    for t = 1:T
        key = char(lab(t));
        if globalMap.isKey(key)
            C(i,t) = globalMap(key);
        end
    end
end
end

function [C, classNames] = localNumericToBinnedIndex(seqs, Tmax)
allv = [];
for i=1:numel(seqs)
    x = seqs{i};
    if isempty(x), continue; end
    if isnumeric(x) || islogical(x)
        allv = [allv; double(x(:))]; %#ok<AGROW>
    end
end
allv = allv(~isnan(allv));

if isempty(allv)
    classNames = "NaN";
    C = NaN(numel(seqs), Tmax);
    return;
end

u = unique(allv);
if numel(u) <= 20 && all(abs(u-round(u))<1e-9)
    classNames = string(u(:));
    mp = containers.Map('KeyType','double','ValueType','double');
    for k=1:numel(u), mp(u(k)) = k; end

    C = NaN(numel(seqs), Tmax);
    for i=1:numel(seqs)
        x = double(seqs{i}(:)');
        T = min(Tmax, numel(x));
        for t=1:T
            v = x(t);
            if ~isnan(v) && isKey(mp,v)
                C(i,t) = mp(v);
            end
        end
    end
else
    nb = 10;
    edges = linspace(min(allv), max(allv), nb+1);
    classNames = "bin" + string(1:nb);

    C = NaN(numel(seqs), Tmax);
    for i=1:numel(seqs)
        x = double(seqs{i}(:)');
        T = min(Tmax, numel(x));
        if T==0, continue; end
        C(i,1:T) = discretize(x(1:T), edges);
    end
end
end

function cc = localPlotConfusion(ax, cm, classNames, ttl, mismatchRate, nPairs)

    % --- récupérer la figure et la position de l'axes ---
    fig = ancestor(ax, 'figure');
    pos = ax.Position;          % en unités normalisées si ax.Units = 'normalized'
    units = ax.Units;

    % --- supprimer l'axes "placeholder" ---
    delete(ax);

    % --- créer un panel au même endroit (parent OK pour confusionchart) ---
    pan = uipanel(fig, 'Units', units, 'Position', pos, 'BorderType', 'none');

    % --- créer le confusionchart DANS le panel ---
    cc = confusionchart(pan, cm, cellstr(string(classNames)));

    % --- titres / annotations ---
    cc.Title = sprintf("%s (mismatch %.1f%%, n=%d)", string(ttl), 100*mismatchRate, nPairs);
    cc.RowSummary = "row-normalized";
    cc.ColumnSummary = "column-normalized";
end


function localPlotEmpty(figHandle, ttl, msg)
if isempty(figHandle) || ~ishandle(figHandle)
    f = figure('Color','w','Name','Compare stats');
else
    f = figHandle;
    figure(f); clf(f);
end
ax = axes(f); %#ok<LAXES>
text(ax,0.5,0.5,msg,'Units','normalized','HorizontalAlignment','center');
axis(ax,'off');
title(ax, ttl, 'Interpreter','none');
end

function t = localKeyTitle(dsKey)
sp = strsplit(string(dsKey),'|');
ds = sp(1);
vr = "";
if numel(sp)>=2, vr = sp(2); end
if strlength(vr)>0
    t = ds + " | " + vr;
else
    t = ds;
end
end

function s = localGetSequenceForKey(rr, dsKey)
% identique à ton helper
s = [];
sp = strsplit(char(dsKey), '|');
dsName = string(sp{1});
varName = "";
if numel(sp) >= 2, varName = string(sp{2}); end

try, dss = rr.data; catch, dss = []; end
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
    if name == dsName, ds = dd; break; end
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
