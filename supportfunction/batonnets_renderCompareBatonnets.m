function out = batonnets_renderCompareBatonnets(out, tl, roiListShown, roiListAll, dsKeys, H, W, Gcmp, Groi, globalLabelMap, globalLabels, globalCmap, args)
% BATONNETS_RENDERCOMPAREBATONNETS  Render compare mode (2 dsKeys) in one tile.
%
% SYNTAX
%   out = batonnets_renderCompareBatonnets(out, tl, roiListShown, roiListAll, dsKeys, ...
%       H, W, Gcmp, Groi, globalLabelMap, globalLabels, globalCmap, args)
%
% INPUTS
%   roiListShown : subset displayed
%   roiListAll   : all ROIs (kept for downstream processing; can also be used for stats later)
%   dsKeys       : string array with exactly 2 keys: dsKeys(1)=A, dsKeys(2)=B
%
% OUTPUT
%   out.axes(1)      : axes handle
%   out.classNames{1}: class names used
%
% NOTES
% - mismatch markers are drawn as ONE alpha overlay image (fast)
% - if one series is totally absent for a ROI (all NaN), no marker is drawn for that ROI
% - marker placement: bottom of A (top trace) and top of B (bottom trace)

ax = nexttile(tl);
out.axes = ax;
ax.YDir = 'normal';
ax.Box  = 'off';

dsKeyA = dsKeys(1);
dsKeyB = dsKeys(2);

[dsNameA, varNameA] = localSplitKey(dsKeyA);
[dsNameB, varNameB] = localSplitKey(dsKeyB);

% compute CA/CB on SHOWN only (fast display)
[seqA, TmaxA] = localCollectSequences(roiListShown, dsKeyA);
[seqB, TmaxB] = localCollectSequences(roiListShown, dsKeyB);
Tmax = max(TmaxA, TmaxB);

if Tmax == 0
    text(ax, 0.5, 0.5, "No data", 'Units','normalized', 'HorizontalAlignment','center');
    return;
end

[CA, CB, classNames, cmap, isLabel] = localBuildCompareIndexMatrices( ...
    seqA, seqB, Tmax, globalLabelMap, globalCmap, args.NumbersColormapName);

% stack: [2*nROI x T]
nROI = numel(roiListShown);
C2 = NaN(2*nROI, Tmax);
C2(1:2:end,:) = CA;
C2(2:2:end,:) = CB;

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

% NOTE: stats figure sur roiListAll -> on la fait dans un autre script (ou plus tard)
% pour rester à 3 fichiers max.
out.roiListAll_forStats = roiListAll;
out.dsKeysCompare = dsKeys;

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
    try
        if ismethod(rr,'load'), rr.load('data'); end
    catch
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
