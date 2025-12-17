function out = batonnets_renderStackedBatonnets(out, tl, roiListShown, dsKeys, H, W, Groi, globalLabelMap, globalCmap, args)
% BATONNETS_RENDERSTACKEDBATONNETS  Render one tile per dsKey, stacking ROIs vertically.
%
% SYNTAX
%   out = batonnets_renderStackedBatonnets(out, tl, roiListShown, dsKeys, H, W, Groi, globalLabelMap, globalCmap, args)
%
% INPUTS
%   out           : struct accumulator (created by batonnets_proceedRenderBatonnets)
%   tl            : tiledlayout handle
%   roiListShown  : ROI subset to display (struct with roiObj/label)
%   dsKeys        : string array "dsName|varName"
%   H,W,Groi      : rendering geometry (pixels)
%   globalLabelMap/globalCmap : shared mapping for label variables
%   args          : name-value struct (ShowColorbar, NumbersColormapName, etc.)
%
% OUTPUT
%   out.axes(i)       : axes handles
%   out.classNames{i} : class names per dsKey

out.axes = gobjects(numel(dsKeys),1);
out.classNames = cell(numel(dsKeys),1);

for iDS = 1:numel(dsKeys)
    dsKey = dsKeys(iDS);
    [dsName, varName] = localSplitKey(dsKey);

    ax = nexttile(tl);
    out.axes(iDS) = ax;
    ax.YDir = 'normal';
    ax.Box  = 'off';

    % collect sequences
    [seqs, Tmax] = localCollectSequences(roiListShown, dsKey);

    if Tmax == 0
        text(ax, 0.5, 0.5, "No data", 'Units','normalized', 'HorizontalAlignment','center');
        continue;
    end

    isLabel = localIsLabelSeqs(seqs);

    if isLabel
        [C, classNames] = localSequencesToGlobalIndex(seqs, Tmax, globalLabelMap);
        cmap = globalCmap;
    else
        [C, classNames] = localNumericToBinnedIndex(seqs, Tmax);
        cmap = localMakeColormap(args.NumbersColormapName, numel(classNames));
    end
    out.classNames{iDS} = classNames;

    localRenderMatrixOnAxis(ax, C, cmap, H, W, Groi);

    % title
    if strlength(varName) > 0
        ax.Title.String = sprintf('%s — %s', dsName, varName);
    else
        ax.Title.String = char(dsName);
    end
    ax.Title.Interpreter = 'none';
    ax.Title.FontWeight  = 'bold';

    % y ticks
    nROI = size(C,1);
    ax.YTick = localRoiCenters(nROI, H, Groi);
    ax.YTickLabel = cellstr(string({roiListShown.label}));
    ax.TickLabelInterpreter = 'none';

    if args.ShowColorbar
        K = size(cmap,1);
        cb = colorbar(ax);
        cb.Ticks = 1:K;
        cb.TickLabels = cellstr(string(classNames));
        cb.TickLabelInterpreter = 'none';
    end


end
end

% =========================
% Local helpers (stacked)
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

function tf = localIsLabelSeqs(seqs)
tf = any(cellfun(@(x) iscategorical(x) || isstring(x) || ischar(x) || ...
    (iscell(x) && all(cellfun(@(c)ischar(c)||isstring(c), x(:)))), seqs));
end

function localRenderMatrixOnAxis(ax, C, cmap, H, W, G)
nROI = size(C,1);
T    = size(C,2);

Cw = kron(C, ones(1, W));
Tw = size(Cw,2);

Htot = nROI*H + (nROI-1)*G;
Cexp = NaN(Htot, Tw);

row0 = 1;
for iR = 1:nROI
    Cexp(row0:row0+H-1,:) = repmat(Cw(iR,:), H, 1);
    row0 = row0 + H + G;
end

A = ~isnan(Cexp);
% --- X en pixels (bord à bord, pas centres) ---
imagesc(ax, [0.5 Tw-0.5], [1 size(Cexp,1)], Cexp, 'AlphaData', A);

xlim(ax, [0 Tw]);
xlabel(ax, "Pixel");

% ticks en frames, alignés sur les bords
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

function yc = localRoiCenters(nROI, H, G)
yc = zeros(nROI,1);
row0 = 1;
for iR = 1:nROI
    yc(iR) = row0 + (H-1)/2;
    row0 = row0 + H + G;
end
end

% --- mapping helpers ---
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

% --- shared micro utils (kept local) ---
function s = localGetSequenceForKey(rr, dsKey)
% (copié tel quel de ton code)
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
