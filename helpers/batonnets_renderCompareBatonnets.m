function out = batonnets_renderCompareBatonnets(out, tl, roiListShown, roiListAll, dsKeys, H, W, Gcmp, Groi, globalLabelMap, globalLabels, globalCmap, args)
% BATONNETS_RENDERCOMPAREBATONNETS  Render compare mode (2 dsKeys) in one tile.
%
% DEBUG:
%   Enable by passing args.DebugCompare = true (and optionally args.DebugMaxRoiPrint)

% -------------------------
% Debug options
% -------------------------
dbg = true;
dbgMax = 5;
try
    if isfield(args,'DebugCompare'), dbg = logical(args.DebugCompare); end
    if isfield(args,'DebugMaxRoiPrint'), dbgMax = max(0, round(args.DebugMaxRoiPrint)); end
catch
end

dprintf = @(varargin) fprintf(varargin{:});
dline   = @() fprintf('\n');

if dbg
    dline();
    dprintf('[compare] ===== batonnets_renderCompareBatonnets =====\n');
    dprintf('[compare] roiListShown=%d, roiListAll=%d\n', numel(roiListShown), numel(roiListAll));
    dprintf('[compare] H=%d W=%d Gcmp=%d Groi=%d\n', H, W, Gcmp, Groi);
    dprintf('[compare] dsKeys: (%d)\n', numel(dsKeys));
    disp(dsKeys);
    try
        dprintf('[compare] globalLabelMap.Count=%d, globalLabels=%d, globalCmap=%dx%d\n', ...
            globalLabelMap.Count, numel(globalLabels), size(globalCmap,1), size(globalCmap,2));
    catch
    end
end

ax = nexttile(tl);
out.axes = ax;
ax.YDir = 'normal';
ax.Box  = 'off';

% --- ds keys
if numel(dsKeys) < 2
    if dbg
        dprintf('[compare] ERROR: dsKeys has <2 elements\n');
    end
    text(ax, 0.5, 0.5, "Compare needs 2 dsKeys", 'Units','normalized','HorizontalAlignment','center');
    return;
end

dsKeyA = dsKeys(1);
dsKeyB = dsKeys(2);

[dsNameA, varNameA] = localSplitKey(dsKeyA);
[dsNameB, varNameB] = localSplitKey(dsKeyB);

if dbg
    dprintf('[compare] dsKeyA=%s | split: ds=%s var=%s\n', string(dsKeyA), dsNameA, varNameA);
    dprintf('[compare] dsKeyB=%s | split: ds=%s var=%s\n', string(dsKeyB), dsNameB, varNameB);
end

% -------------------------
% Collect sequences (shown only)
% -------------------------
[seqA, TmaxA] = localCollectSequences(roiListShown, dsKeyA);
[seqB, TmaxB] = localCollectSequences(roiListShown, dsKeyB);
Tmax = max(TmaxA, TmaxB);

if dbg
    dprintf('[compare] localCollectSequences: TmaxA=%d TmaxB=%d Tmax=%d\n', TmaxA, TmaxB, Tmax);
    dprintf('[compare] seqA cells=%d, seqB cells=%d\n', numel(seqA), numel(seqB));
end

% ---------------------------------------------------------
% Drop ROIs for which A or B is totally missing
% ---------------------------------------------------------
absA = localSeqCellIsAbsent(seqA);
absB = localSeqCellIsAbsent(seqB);
keep = ~(absA | absB);

if dbg
    dprintf('[compare] absent A: %d/%d, absent B: %d/%d\n', nnz(absA), numel(absA), nnz(absB), numel(absB));
    dprintf('[compare] keep: %d/%d\n', nnz(keep), numel(keep));
    if dbgMax > 0
        ii = find(true(size(keep)));
        ii = ii(1:min(numel(ii), dbgMax));
        for k = 1:numel(ii)
            r = ii(k);
            la = 0; lb = 0;
            try, la = numel(seqA{r}); end
            try, lb = numel(seqB{r}); end
            dprintf('[compare] ROI #%d label="%s" lenA=%d lenB=%d absA=%d absB=%d keep=%d\n', ...
                r, string(roiListShown(r).label), la, lb, absA(r), absB(r), keep(r));
        end
    end
end

if ~any(keep)
    if dbg
        dprintf('[compare] No comparable data after keep-filter.\n');
    end
    text(ax, 0.5, 0.5, "No comparable data", 'Units','normalized', ...
        'HorizontalAlignment','center');
    return;
end

roiListShown = roiListShown(keep);
seqA = seqA(keep);
seqB = seqB(keep);

% recompute Tmax on kept ROIs only
TmaxA = localMaxLen(seqA);
TmaxB = localMaxLen(seqB);
Tmax  = max(TmaxA, TmaxB);

if dbg
    dprintf('[compare] after keep: roiListShown=%d, TmaxA=%d TmaxB=%d Tmax=%d\n', numel(roiListShown), TmaxA, TmaxB, Tmax);
end

if Tmax == 0
    if dbg, dprintf('[compare] Tmax==0 -> No data\n'); end
    text(ax, 0.5, 0.5, "No data", 'Units','normalized', 'HorizontalAlignment','center');
    return;
end

% -------------------------
% Build index matrices CA/CB
% -------------------------
[CA, CB, classNames, cmap, isLabel] = localBuildCompareIndexMatrices( ...
    seqA, seqB, Tmax, globalLabelMap, globalCmap, args.NumbersColormapName);

if dbg
    dprintf('[compare] build matrices: CA=%dx%d CB=%dx%d isLabel=%d\n', size(CA,1), size(CA,2), size(CB,1), size(CB,2), isLabel);
    dprintf('[compare] classNames=%d cmap=%dx%d\n', numel(classNames), size(cmap,1), size(cmap,2));

    % Quick mismatch stats on indices
    try
        m = (CA ~= CB) & ~isnan(CA) & ~isnan(CB);
        dprintf('[compare] mismatch frames (index space): %d / %d (%.2f%%)\n', nnz(m), nnz(~isnan(CA) & ~isnan(CB)), 100*nnz(m)/max(1,nnz(~isnan(CA) & ~isnan(CB))));
    catch
    end

    % Preview first few sequences (raw)
    if dbgMax > 0
        nPrev = min(numel(seqA), dbgMax);
        for i = 1:nPrev
            a = seqA{i}; b = seqB{i};
            if isLabel
                sa = localToStringLabels(a); sb = localToStringLabels(b);
                ua = unique(strtrim(sa)); ua = ua(strlength(ua)>0);
                ub = unique(strtrim(sb)); ub = ub(strlength(ub)>0);
                dprintf('[compare] ROIprev #%d "%s": uniqA(%d)=%s | uniqB(%d)=%s\n', ...
                    i, string(roiListShown(i).label), numel(ua), join(ua(1:min(5,end)),","), numel(ub), join(ub(1:min(5,end)),","));
            else
                xa = []; xb = [];
                try, xa = double(a(:)); end
                try, xb = double(b(:)); end
                xa = xa(~isnan(xa)); xb = xb(~isnan(xb));
                ra = "[empty]"; rb = "[empty]";
                if ~isempty(xa), ra = sprintf('[%.3g..%.3g] n=%d', min(xa), max(xa), numel(xa)); end
                if ~isempty(xb), rb = sprintf('[%.3g..%.3g] n=%d', min(xb), max(xb), numel(xb)); end
                dprintf('[compare] ROIprev #%d "%s": rangeA=%s rangeB=%s\n', i, string(roiListShown(i).label), ra, rb);
            end
        end
    end
end

% -------------------------
% Stack A/B : [2*nROI x T]
% -------------------------
nROI = numel(roiListShown);
C2 = NaN(2*nROI, Tmax);
C2(1:2:end,:) = CA;
C2(2:2:end,:) = CB;

if dbg
    dprintf('[compare] stacked C2=%dx%d\n', size(C2,1), size(C2,2));
end

% -------------------------
% Render + mismatch overlay
% -------------------------
localRenderCompareOnAxis(ax, C2, cmap, H, W, Gcmp, Groi);
localOverlayMismatchPixels(ax, CA, CB, H, W, Gcmp, Groi);

% y labels
ax.YTick = localRoiPairCenters(nROI, H, Gcmp, Groi);
ax.YTickLabel = cellstr(string({roiListShown.label}));
ax.TickLabelInterpreter = 'none';

% title
tA = dsNameA; if strlength(varNameA)>0, tA = tA + " | " + varNameA; end
tB = dsNameB; if strlength(varNameB)>0, tB = tB + " | " + varNameB; end
ax.Title.String = sprintf('%s  ↔  %s', tA, tB);
ax.Title.Interpreter = 'none';
ax.Title.FontWeight  = 'bold';

out.classNames = {classNames};
out.isLabelCompare = isLabel;

if args.ShowColorbar
    K = size(cmap,1);
    cb = colorbar(ax);
    cb.Ticks = 1:K;
    if isLabel
        cb.TickLabels = cellstr(string(globalLabels));
    else
        cb.TickLabels = cellstr(string(classNames));
    end
    cb.TickLabelInterpreter = 'none';
end

out.roiListAll_forStats = roiListAll;
out.dsKeysCompare = dsKeys;

if dbg
    dprintf('[compare] DONE renderCompare.\n');
    dprintf('[compare] ===========================================\n');
end

end


% =========================
% Local helpers (compare)
% =========================
function [dsName, varName] = localSplitKey(dsKey)
sp = strsplit(string(dsKey), '|');
dsName = sp(1);
if numel(sp)>=2, varName = sp(2); else, varName = ""; end
end

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

function [CA, CB, classNames, cmap, isLabel] = localBuildCompareIndexMatrices(seqsA, seqsB, Tmax, globalLabelMap, globalCmap, numbersCmapName)

isLabelA = localIsLabelSeqs(seqsA);
isLabelB = localIsLabelSeqs(seqsB);
isLabel = isLabelA || isLabelB;

if isLabel
    [CA, classNamesA] = localSequencesToGlobalIndex(seqsA, Tmax, globalLabelMap);
    [CB, classNamesB] = localSequencesToGlobalIndex(seqsB, Tmax, globalLabelMap);
    classNames = union(string(classNamesA), string(classNamesB), 'stable'); %#ok<NASGU>
    classNames = string(classNamesA); % global index ordering
    cmap = globalCmap;
else
    [CA, classNamesA] = localNumericToBinnedIndex(seqsA, Tmax);
    [CB, classNamesB] = localNumericToBinnedIndex(seqsB, Tmax);
    classNames = union(string(classNamesA), string(classNamesB), 'stable');
    cmap = localMakeColormap(numbersCmapName, numel(classNames));
end
end

function tf = localIsLabelSeqs(seqs)
tf = any(cellfun(@(x) iscategorical(x) || isstring(x) || ischar(x) || ...
    (iscell(x) && all(cellfun(@(c)ischar(c)||isstring(c), x(:)))), seqs));
end

function localRenderCompareOnAxis(ax, C2, cmap, H, W, Gcmp, Groi)
nTracks = size(C2,1);
T       = size(C2,2);
nROI    = nTracks/2;

Cw = kron(C2, ones(1, W));
Tw = size(Cw,2);

HperROI = 2*H + Gcmp;
Htot = nROI*HperROI + (nROI-1)*Groi;

Cexp = NaN(Htot, Tw);

row0 = 1;
for iR = 1:nROI
    rA = 2*iR-1; rB = 2*iR;

    Cexp(row0:row0+H-1,:) = repmat(Cw(rA,:), H, 1);
    row0 = row0 + H + Gcmp;

    Cexp(row0:row0+H-1,:) = repmat(Cw(rB,:), H, 1);
    row0 = row0 + H;

    if iR < nROI
        row0 = row0 + Groi;
    end
end

A = ~isnan(Cexp);

% --- X en pixels (bord à bord) ---
imagesc(ax, [0.5 Tw-0.5], [1 size(Cexp,1)], Cexp, 'AlphaData', A);

xlim(ax, [0 Tw]);
xlabel(ax, "Frame");

% ticks en frames (labels) mais positions en pixels
xtFrames = localNiceFrameTicks(T, 6);
ax.XTick = xtFrames * W;
ax.XTickLabel = string(xtFrames);


K = size(cmap,1);
caxis(ax, [1 K]);
colormap(ax, cmap);

ylim(ax, [0.5, Htot+0.5]);
ax.Visible  = 'on';
ax.Clipping = 'off';
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

function localOverlayMismatchPixels(ax, CA, CB, H, W, Gcmp, Groi)
if isempty(CA) || isempty(CB), return; end
[nROI, T] = size(CA);
if any(size(CB) ~= [nROI T]) || T<=0, return; end

absentA = all(isnan(CA), 2);
absentB = all(isnan(CB), 2);
roiOK   = ~(absentA | absentB);
if ~any(roiOK), return; end

mismatch = (CA ~= CB) & ~isnan(CA) & ~isnan(CB);
mismatch(~roiOK,:) = false;
if ~any(mismatch(:)), return; end

Tw = T * W;
mW = kron(mismatch, ones(1, W)) > 0;

HperROI = 2*H + Gcmp;
Htot    = nROI*HperROI + (nROI-1)*Groi;

alpha = zeros(Htot, Tw, 'single');
hMark = max(1, floor(H/2));

row0 = 1;
for iR = 1:nROI
    if ~roiOK(iR)
        row0 = row0 + HperROI + (iR < nROI)*Groi;
        continue;
    end

    cols = mW(iR,:);
    if any(cols)
        % A (top): marker at BOTTOM
        rA1 = row0 + H - 1;
        rA0 = max(row0, rA1 - hMark + 1);

        % B (bottom): marker at TOP
        rBbase = row0 + H + Gcmp;
        rB0 = rBbase;
        rB1 = min(rBbase + hMark - 1, rBbase + H - 1);

        alpha(rA0:rA1, cols) = 1;
        alpha(rB0:rB1, cols) = 1;
    end

    row0 = row0 + HperROI;
    if iR < nROI
        row0 = row0 + Groi;
    end
end

rgb = zeros(Htot, Tw, 3, 'uint8');
hold(ax,'on');
image(ax, [0.5 Tw-0.5], [1 Htot], rgb, 'AlphaData', alpha, 'HitTest','off');

hold(ax,'off');
end

% --- mapping helpers (same as stacked, local copy to avoid extra files) ---
function [C, classNames] = localSequencesToGlobalIndex(seqs, Tmax, globalLabelMap)
% seqs : cell array, seqs{i} = labels sur le temps (string/cellstr/categorical/numeric)
% C    : nRoi x Tmax, indices globaux (0 = absent/missing)

n = numel(seqs);
C = zeros(n, Tmax, 'uint16');

for i = 1:n
    lab = seqs{i};
    if isempty(lab)
        continue;
    end

    % Convertit tout en string (gère cellstr, char, categorical, string)
    s = string(lab);

    % Sécurise la longueur
    if numel(s) < Tmax
        s(Tmax) = missing;   % pad
    elseif numel(s) > Tmax
        s = s(1:Tmax);
    end

    for t = 1:Tmax
        st = s(t);

        % ---> coeur du fix : ne JAMAIS char() sur missing / vide
      if ismissing(st) || strlength(st)==0
    fprintf('[compare] missing label: roi=%d t=%d (class=0)\n', i, t);
    C(i,t) = 0;
    continue;
end

        key = char(st);  % maintenant c'est safe

        if isKey(globalLabelMap, key)
            C(i,t) = uint16(globalLabelMap(key));
        else
            % option: inconnu => 0 (ou warning)
            C(i,t) = 0;
        end
    end
end

% classNames si tu en as besoin côté affichage
try
    classNames = string(keys(globalLabelMap));
catch
    classNames = string.empty;
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

function cmap = localMakeColormap(name, K)
name = strtrim(string(name));
if strlength(name)==0, name = "lines"; end
try
    f = str2func(char(name));
    cmap = f(max(2,K));
catch
    cmap = lines(max(2,K));
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

function absent = localSeqCellIsAbsent(seqs)
% seqs: cell array, one per ROI, each is row vector (numeric or labels)
n = numel(seqs);
absent = false(n,1);

for i = 1:n
    x = seqs{i};
    if isempty(x)
        absent(i) = true;
        continue;
    end

    % numeric/logical: absent if all NaN
    if isnumeric(x) || islogical(x)
        absent(i) = all(isnan(double(x(:))));
        continue;
    end

    % label-like: absent if all empty/whitespace after string conversion
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
if isempty(seqs)
    Tmax = 0;
else
    Tmax = 0;
    for i=1:numel(seqs)
        Tmax = max(Tmax, numel(seqs{i}));
    end
end
end
