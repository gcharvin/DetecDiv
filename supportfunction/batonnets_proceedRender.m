function out = batonnets_proceedRender(roiList, dsKeys, args)
% BATONNETS_PROCEEDRENDERBATONNETS  Render batonnets for ROI dataseries (stacked or compare).
%
% SYNTAX
%   out = batonnets_proceedRenderBatonnets(roiList, dsKeys)
%   out = batonnets_proceedRenderBatonnets(roiList, dsKeys, Name, Value, ...)
%
% INPUTS
%   roiList : 1xN struct array with fields:
%       - roiObj : ROI handle/object (optionally supports roiObj.load('data'))
%       - label  : char/string used as Y tick label
%   dsKeys  : string array, each element "dsName|varName"
%
% NAME-VALUE PAIRS (args.*)
%   BarHeight, FrameWidth
%   ShowColorbar
%   LabelColormapName, NumbersColormapName
%   DisplayMaxTraj, DisplaySeed
%   FigureHandle
%   Compare (true/false), GapROI, GapCompare
%
% OUTPUT
%   out : struct with figure/axes handles and metadata:
%       - roiListAll / roiListShown / idxShown
%       - classNames, globalLabels, etc.
%
% NOTES
% - DisplayMaxTraj limits ONLY what is displayed (roiListShown); roiListAll is preserved in out.
% - In Compare mode (Compare=true AND numel(dsKeys)==2), both series are stacked per ROI in one tile.

arguments
    roiList (1,:) struct
    dsKeys  string

    args.BarHeight (1,1) double = 10
    args.FrameWidth (1,1) double = 2
    args.ShowColorbar (1,1) logical = false
    args.LabelColormapName (1,1) string = "lines"
    args.NumbersColormapName (1,1) string = "parula"

    args.DisplayMaxTraj (1,1) double = 20
    args.DisplaySeed    (1,1) double = 1

    args.FigureHandle = []

    args.Compare (1,1) logical = false
    args.GapROI (1,1) double = NaN
    args.GapCompare (1,1) double = NaN
    args.ShowCompareStats (1,1) logical = true
    args.StatsFigureHandle = []   % optionnel, pour réutiliser une figure

    args.EventRulesByKey = []   % containers.Map(char -> struct array)
end

% --- normalize EventRulesByKey ---
if isempty(args.EventRulesByKey)
    args.EventRulesByKey = containers.Map('KeyType','char','ValueType','any');
elseif ~isa(args.EventRulesByKey,'containers.Map')
    error('EventRulesByKey must be a containers.Map (char -> rules)');
end


% --- keep all + choose shown subset (random) ---
[roiListAll, roiListShown, idxShown] = localSampleROIs(roiList, args.DisplayMaxTraj, args.DisplaySeed);

% --- geometry ---
H = max(1, round(args.BarHeight));
W = max(1, round(args.FrameWidth));
if isnan(args.GapROI),     Groi = max(1, round(H/3)); else, Groi = max(0, round(args.GapROI)); end
if isnan(args.GapCompare), Gcmp = max(1, round(H/6)); else, Gcmp = max(0, round(args.GapCompare)); end

doCompare = args.Compare && (numel(dsKeys) == 2);

% --- figure ---
if isempty(args.FigureHandle) || ~ishandle(args.FigureHandle)
    f = figure('Name','Batonnets','Color','w');
else
    f = args.FigureHandle;
    figure(f);
    clf(f);
end

% --- layout ---
if doCompare
    tl = tiledlayout(f, 1, 1, 'Padding','tight', 'TileSpacing','compact');
else
    tl = tiledlayout(f, numel(dsKeys), 1, 'Padding','tight', 'TileSpacing','compact');
end

% --- global label map on ALL rois (for consistent colors) ---
[globalLabelMap, globalLabels, globalCmap] = localBuildGlobalLabelMap(roiListAll, dsKeys, args.LabelColormapName);


% --- out init (NE PAS écraser plus tard) ---
out = struct();
out.figure      = f;
out.tiledlayout = tl;
out.roiListAll   = roiListAll;
out.roiListShown = roiListShown;
out.idxShown     = idxShown;
out.nROIsAll      = numel(roiListAll);
out.nROIsShown    = numel(roiListShown);
out.globalLabels  = globalLabels;
out.globalLabelMap = globalLabelMap;

out.compareStats = [];
% --- dispatch ---
if ~doCompare
    out = batonnets_renderStackedBatonnets(out, tl, roiListShown, dsKeys, ...
        H, W, Groi, globalLabelMap, globalCmap, args);
else
    out = batonnets_renderCompareBatonnets(out, tl, roiListShown, roiListAll, dsKeys, ...
        H, W, Gcmp, Groi, globalLabelMap, globalLabels, globalCmap, args);

        if args.ShowCompareStats
       out.compareStats = batonnets_compareStats( ...
           roiListAll, dsKeys, globalLabelMap, ...
           'FigureHandle', args.StatsFigureHandle, ...
           'Title', "Compare stats");
        end

end

end

% =========================
% Local small helpers (main)
% =========================
function [roiListAll, roiListShown, idxShown] = localSampleROIs(roiList, maxShow, seed)
roiListAll = roiList;
nAll = numel(roiListAll);

maxShow = round(maxShow);
if isinf(maxShow) || maxShow <= 0 || nAll <= maxShow
    idxShown = 1:nAll;
else
    rng(seed,'twister');
    idxShown = sort(randperm(nAll, max(1, maxShow))); % stable visual order
end

roiListShown = roiListAll(idxShown);
end

function [globalLabelMap, globalLabels, globalCmap] = localBuildGlobalLabelMap(roiListAll, dsKeys, cmapName)
allLabels = strings(0,1);

for iDS = 1:numel(dsKeys)
    dsKey = dsKeys(iDS);
    for iR = 1:numel(roiListAll)
        rr = roiListAll(iR).roiObj;

% Charger les data uniquement si nécessaire
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
        if isempty(s), continue; end
        allLabels = [allLabels; localToStringLabels(s)]; %#ok<AGROW>
    end
end

allLabels = allLabels(strlength(allLabels)>0);
globalLabels = unique(allLabels, 'stable');

globalLabelMap = containers.Map('KeyType','char','ValueType','double');
for k = 1:numel(globalLabels)
    globalLabelMap(char(globalLabels(k))) = k;
end

Kglobal = max(2, numel(globalLabels));
globalCmap = localMakeColormap(cmapName, Kglobal);
end

% --- small shared utils (kept local to avoid extra files) ---
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
