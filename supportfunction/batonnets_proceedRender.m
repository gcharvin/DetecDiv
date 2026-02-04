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
    args.EventWidthFrames (1,1) double = 3   % largeur marqueur event en frames
    args.MatchMaxDtFrames(1,1) double = 10
    args.Classifier = []   % struct from ROIclassiMismatchGUI (ownerVarStr/strid/path/run/exists)
end

logf = @(varargin) fprintf('[batonnets_proceedRender %s] %s\n', ...
    datestr(now,'HH:MM:SS.FFF'), sprintf(varargin{:}));

dbg=false;

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
out.classifier = args.Classifier;

runDirAbs = localResolveRunDirAbs_(out.classifier);
out.runDirAbs = runDirAbs;

if dbg
    try
        rdRaw = '';
        if ~isempty(out.classifier) && isfield(out.classifier,'run') && isfield(out.classifier.run,'runDir')
            rdRaw = char(string(out.classifier.run.runDir));
        end
        logf('runDir resolve: base=%s | raw=%s | abs=%s', char(string(out.classifier.path)), rdRaw, runDirAbs);
    catch
    end
end


% --- dispatch ---
if ~doCompare
    out = batonnets_renderStackedBatonnets(out, tl, roiListShown, dsKeys, ...
        H, W, Groi, globalLabelMap, globalCmap, args);
else


    % --- DEBUG rules ---
disp("---- DEBUG EventRulesByKey ----")
disp("dsKeys used:");
disp(dsKeys)

if isa(args.EventRulesByKey,'containers.Map')
    disp("Map keys:");
    disp(string(args.EventRulesByKey.keys))
end

for k = 1:numel(dsKeys)
    kk = char(dsKeys(k));
    if isKey(args.EventRulesByKey, kk)
        rr = args.EventRulesByKey(kk);
        fprintf("rules for %s: %d\n", kk, numel(rr));
        if ~isempty(rr), disp(rr(1)); end
    else
        fprintf("NO rules found for %s\n", kk);
    end
end

    out = batonnets_renderCompareBatonnets(out, tl, roiListShown, roiListAll, dsKeys, ...
        H, W, Gcmp, Groi, globalLabelMap, globalLabels, globalCmap, args);

        if args.ShowCompareStats
       out.compareStats = batonnets_compareStats( ...
           roiListAll, dsKeys, globalLabelMap, ...
           'FigureHandle', args.StatsFigureHandle, ...
           'Title', "Compare stats");
        end
        
    
        % --- events (compare) ---
if ~isempty(args.EventRulesByKey) && isa(args.EventRulesByKey,'containers.Map') ...
        && args.EventRulesByKey.Count > 0
    out = batonnets_eventsCompare(out, roiListAll, roiListShown, idxShown, dsKeys, args, H, W, Gcmp, Groi);
end



end

% ----------------------------------------------------------
% EXPORTS to runDir (if available)
% ----------------------------------------------------------
if dbg
    if isempty(runDirAbs)
        logf('EXPORTS skipped: runDirAbs is empty');
    else
        logf('EXPORTS enabled: runDirAbs = %s', runDirAbs);
    end
end


if ~isempty(runDirAbs)

    if dbg
        logf('EXPORT figure: batonnets_main');
    end
    % Main batonnets figure
    localSafeFigureExport_(out.figure, runDirAbs, "batonnets_main");

    % Compare stats figure (from out.compareStats.figure)
       try
        if isfield(out,'compareStats') && isstruct(out.compareStats) ...
                && isfield(out.compareStats,'figure') && ishandle(out.compareStats.figure)

            if dbg
                logf('EXPORT figure: batonnets_compareStats');
            end
            localSafeFigureExport_(out.compareStats.figure, runDirAbs, "batonnets_compareStats");
        elseif dbg
            logf('EXPORT figure skipped: compareStats.figure not found');
        end
    catch ME
        if dbg
            logf('EXPORT figure FAILED: batonnets_compareStats (%s)', ME.message);
        end
    end


    % Events figures
      try
        if isfield(out,'eventsFigure') && ishandle(out.eventsFigure)
            if dbg
                logf('EXPORT figure: batonnets_events');
            end
            localSafeFigureExport_(out.eventsFigure, runDirAbs, "batonnets_events");
        elseif dbg
            logf('EXPORT figure skipped: eventsFigure not found');
        end

        if isfield(out,'eventsStatsFigure') && ishandle(out.eventsStatsFigure)
            if dbg
                logf('EXPORT figure: batonnets_eventsStats');
            end
            localSafeFigureExport_(out.eventsStatsFigure, runDirAbs, "batonnets_eventsStats");
        elseif dbg
            logf('EXPORT figure skipped: eventsStatsFigure not found');
        end
    catch ME
        if dbg
            logf('EXPORT events figures FAILED (%s)', ME.message);
        end
    end


    % Save out struct for reproducibility
       try
        save(fullfile(runDirAbs,'batonnets_out.mat'),'out','dsKeys','args','-v7.3');
        if dbg
            logf('EXPORT MAT: batonnets_out.mat');
        end
    catch ME
        if dbg
            logf('EXPORT MAT FAILED (%s)', ME.message);
        end
    end


    % Excel
       try
        localWriteExcelStrict_(runDirAbs, out, dsKeys, args);
        if dbg
            logf('EXPORT Excel: comparison tables written in %s', runDirAbs);
        end
    catch ME
        if dbg
            logf('EXPORT Excel FAILED (%s)', ME.message);
        end
    end
end


end

% =========================
% Local small helpers (main)
% =========================



function runDirAbs = localResolveRunDirAbs_(classifier)
runDirAbs = '';

try

    base = char(string(classifier.path));      % racine projet locale (sur cette machine)
    rd0  = char(string(classifier.run.runDir)); % runDir tel que fourni (peut être relatif/abs/hybride)

    if isempty(base) || isempty(rd0), return; end

    % Normaliser séparateurs pour les tests
    rd = rd0;
    rd = strrep(rd, '/', filesep);
    rd = strrep(rd, '\', filesep);

    % Helpers
    isAbsWin = ~isempty(regexp(rd,'^[A-Za-z]:[\\/]', 'once')) || startsWith(rd, ['\\' filesep]) || startsWith(rd, ['\\']);
    isAbsUnix = startsWith(rd0,'/') || startsWith(rd,'/'); % rd0 pour être sûr

    % ------------------------------------------------------------
    % 1) CAS HYBRIDE DÉJÀ CASSÉ : "C:\...\viterbi_1\homes\...\runs\..."
    %    => on rebased sur base + suffixe "\runs\..."
    % ------------------------------------------------------------
    if isAbsWin && contains(rd, [filesep 'homes' filesep])
        k = strfind(rd, [filesep 'runs' filesep]);
        if ~isempty(k)
            suffix = rd(k(1):end);              % "\runs\...."
            runDirAbs = fullfile(base, suffix); % fullfile gère le \runs\...
            if ~exist(runDirAbs,'dir'), mkdir(runDirAbs); end
            return;
        end
        % si pas de "\runs\" trouvé : on garde tel quel (fallback)
        runDirAbs = rd;
        if ~exist(runDirAbs,'dir'), mkdir(runDirAbs); end
        return;
    end

    % ------------------------------------------------------------
    % 2) CAS ABSOLU UNIX : "/homes/.../runs/...."
    %    => on essaie de garder seulement "/runs/..." et on rebased sur base
    % ------------------------------------------------------------
    if isAbsUnix && ~isAbsWin
        % normaliser en filesep
        rdU = strrep(rd0, '/', filesep);
        rdU = strrep(rdU, '\', filesep);

        k = strfind(rdU, [filesep 'runs' filesep]);
        if ~isempty(k)
            suffix = rdU(k(1):end);             % "\runs\...."
            runDirAbs = fullfile(base, suffix);
        else
            % Pas de "runs" : fallback -> tenter base + basename du dossier
            [~, leaf] = fileparts(rdU);
            runDirAbs = fullfile(base, 'runs', leaf);
        end

        if ~exist(runDirAbs,'dir'), mkdir(runDirAbs); end
        return;
    end

    % ------------------------------------------------------------
    % 3) CAS ABSOLU WINDOWS : "C:\..." ou UNC "\\server\share\..."
    % ------------------------------------------------------------
    if isAbsWin
        runDirAbs = rd;
        if ~exist(runDirAbs,'dir'), mkdir(runDirAbs); end
        return;
    end

    % ------------------------------------------------------------
    % 4) CAS RELATIF : "runs\...."
    % ------------------------------------------------------------
    runDirAbs = fullfile(base, rd);
    if ~exist(runDirAbs,'dir'), mkdir(runDirAbs); end

catch
    runDirAbs = '';
end
end



function localSafeFigureExport_(figH, runDirAbs, baseName)
if isempty(runDirAbs) || ~exist(runDirAbs,'dir'), return; end
if isempty(figH) || ~ishandle(figH), return; end
try
    png = fullfile(runDirAbs, baseName + ".png");
    fig = fullfile(runDirAbs, baseName + ".fig");
    try
        exportgraphics(figH, png, 'Resolution', 200);
    catch
        saveas(figH, png);
    end
    try, savefig(figH, fig); catch, end
catch
end
end

function localWriteExcelStrict_(runDirAbs, out, dsKeys, args)

xlsxFile = fullfile(runDirAbs, 'batonnets_compare_metrics.xlsx');

% ---------------- meta ----------------
meta = table();
meta.timestamp = datetime('now');
meta.dsKeyA = ""; meta.dsKeyB = "";
if numel(dsKeys) >= 1, meta.dsKeyA = string(dsKeys(1)); end
if numel(dsKeys) >= 2, meta.dsKeyB = string(dsKeys(2)); end

meta.nROIsAll   = NaN;
meta.nROIsShown = NaN;
try, meta.nROIsAll = out.nROIsAll; end
try, meta.nROIsShown = out.nROIsShown; end

meta.Compare = false;
try, meta.Compare = logical(args.Compare); end

writetable(meta, xlsxFile, 'Sheet','meta', 'WriteMode','overwritesheet');

% ---------------- compareStats: confusion matrix + per-class ----------------
if isfield(out,'compareStats') && isstruct(out.compareStats) && isfield(out.compareStats,'confusionMatrix')
    cm = out.compareStats.confusionMatrix;
    cn = string(out.compareStats.classNames(:));
    if isempty(cn), cn = "class"+string(1:size(cm,1)); end

    % Confusion as table with row/col labels
    % Confusion as table with row/col labels
Tcm = array2table(cm, 'VariableNames', matlab.lang.makeValidName(cn));

% Ajouter une vraie colonne "Class" (robuste Excel)
Tcm = addvars(Tcm, cn(:), 'Before', 1, 'NewVariableNames', "Class");

writetable(Tcm, xlsxFile, 'Sheet','compare_confusion', 'WriteMode','overwritesheet');


    % Per-class recall/precision
    diagv = diag(cm);
    rowSum = sum(cm,2);
    colSum = sum(cm,1)';

    recall = diagv ./ max(1,rowSum);
    precision = diagv ./ max(1,colSum);

    Tpc = table(cn, diagv, rowSum, colSum, recall, precision, ...
        'VariableNames',{'Class','TP','RowSum','ColSum','Recall','Precision'});
    writetable(Tpc, xlsxFile, 'Sheet','compare_perclass', 'WriteMode','overwritesheet');

    % Global
    tot = sum(cm(:));
    acc = sum(diagv) / max(1,tot);

    mm = NaN; np = NaN;
    try, mm = out.compareStats.mismatchRate; end
    try, np = out.compareStats.nPairs; end

    misc = table(acc, mm, np, 'VariableNames',{'Accuracy','MismatchRate','nPairs'});
    writetable(misc, xlsxFile, 'Sheet','compare_summary', 'WriteMode','overwritesheet');
else
    writetable(table("no compareStats"), xlsxFile, 'Sheet','compare_summary', 'WriteMode','overwritesheet');
end

% ---------------- events / intervals stats (STRICT metrics) ----------------
% We will write ONE strict summary sheet + keep your existing sheets (hist etc.) if available.

Tstrict = table();

% ---------------- EVENTS strict ----------------
% Default NaNs
E_nTest = NaN; E_nRef = NaN; E_TP = NaN; E_FP = NaN; E_FN = NaN;
E_FP_rate_test = NaN; E_FN_rate_ref = NaN;
E_TP_rate_test = NaN; E_TP_rate_ref = NaN;

DT_n = 0; DT_median = NaN; DT_max = NaN;

if isfield(out,'eventsStats') && isstruct(out.eventsStats) && isfield(out.eventsStats,'events') && isstruct(out.eventsStats.events)
    e = out.eventsStats.events;

    % counts
    if isfield(e,'nTest'), E_nTest = double(e.nTest); end
    if isfield(e,'nRef'),  E_nRef  = double(e.nRef);  end
    if isfield(e,'TP'),    E_TP    = double(e.TP);    end
    if isfield(e,'FP'),    E_FP    = double(e.FP);    end
    if isfield(e,'FN'),    E_FN    = double(e.FN);    end

    % rates (strictly as requested)
    if isfinite(E_nTest) && E_nTest > 0
        E_FP_rate_test = E_FP / E_nTest;
        E_TP_rate_test = E_TP / E_nTest;
    end
    if isfinite(E_nRef) && E_nRef > 0
        E_FN_rate_ref = E_FN / E_nRef;
        E_TP_rate_ref = E_TP / E_nRef;
    end

    % dt stats (use e.dt if present, else compute from hist if possible)
    if isfield(e,'dt') && isstruct(e.dt)
        if isfield(e.dt,'n'),      DT_n      = double(e.dt.n); end
        if isfield(e.dt,'median'), DT_median = double(e.dt.median); end
        if isfield(e.dt,'max'),    DT_max    = double(e.dt.max); end
    end

    % If max missing but we have out.dtAll (or can infer)
    if ~isfinite(DT_max)
        try
            if isfield(out,'dtAll') && ~isempty(out.dtAll)
                x = abs(double(out.dtAll(:)));
                x = x(isfinite(x));
                if ~isempty(x)
                    DT_max = max(x);
                    if ~isfinite(DT_median), DT_median = median(x,'omitnan'); end
                    DT_n = numel(x);
                end
            end
        catch
        end
    end
end

% Populate strict events columns
Tstrict.Events_nTest = E_nTest;
Tstrict.Events_nRef  = E_nRef;

Tstrict.Events_TP = E_TP;
Tstrict.Events_FP = E_FP;
Tstrict.Events_FN = E_FN;

Tstrict.Events_FP_rate_test = E_FP_rate_test;  % FP / nTest
Tstrict.Events_FN_rate_ref  = E_FN_rate_ref;   % FN / nRef
Tstrict.Events_TP_rate_test = E_TP_rate_test;  % TP / nTest
Tstrict.Events_TP_rate_ref  = E_TP_rate_ref;   % TP / nRef

Tstrict.Events_dtAbs_n      = DT_n;
Tstrict.Events_dtAbs_median = DT_median;
Tstrict.Events_dtAbs_max    = DT_max;

% ---------------- INTERVALS strict ----------------
% Defaults
I_nMatched = NaN;
I_durDiffAbs_median = NaN;
I_durDiffAbs_max    = NaN;

I_nTestAll = NaN;
I_nRefAll  = NaN;
I_medTestAll = NaN;
I_medRefAll  = NaN;

I_ks2_p = NaN;
I_ks2_D = NaN;

I_corr_pearson  = NaN;
I_corr_spearman = NaN;
I_corr_n = 0;

% Pull from out.eventsStats if present
if isfield(out,'eventsStats') && isstruct(out.eventsStats) && isfield(out.eventsStats,'intervals') && isstruct(out.eventsStats.intervals)

    it = out.eventsStats.intervals;

    if isfield(it,'nMatched'), I_nMatched = double(it.nMatched); end
    if isfield(it,'durDiffAbs_median'), I_durDiffAbs_median = double(it.durDiffAbs_median); end

    % max: prefer computing from out.intervalDurDiffAll (matched diffs)
    try
        if isfield(out,'intervalDurDiffAll') && ~isempty(out.intervalDurDiffAll)
            x = double(out.intervalDurDiffAll(:));
            x = x(isfinite(x));
            if ~isempty(x)
                I_durDiffAbs_max = max(x);
                if ~isfinite(I_durDiffAbs_median)
                    I_durDiffAbs_median = median(x,'omitnan');
                end
                if ~isfinite(I_nMatched)
                    I_nMatched = numel(x);
                end
            end
        end
    catch
    end

    if isfield(it,'all') && isstruct(it.all)
        if isfield(it.all,'nTest'),   I_nTestAll = double(it.all.nTest); end
        if isfield(it.all,'nRef'),    I_nRefAll  = double(it.all.nRef);  end
        if isfield(it.all,'medTest'), I_medTestAll = double(it.all.medTest); end
        if isfield(it.all,'medRef'),  I_medRefAll  = double(it.all.medRef);  end
        if isfield(it.all,'ks2_p'),   I_ks2_p = double(it.all.ks2_p); end
        if isfield(it.all,'ks2_D'),   I_ks2_D = double(it.all.ks2_D); end
    end
end

% Correlation REF/TEST for matched intervals
% Prefer intervalMatchedLinkFramesAll = [t0 t1 r0 r1]
try
    if isfield(out,'intervalMatchedLinkFramesAll') && ~isempty(out.intervalMatchedLinkFramesAll)
        L = double(out.intervalMatchedLinkFramesAll);
        if size(L,2) >= 4
            durT = L(:,2) - L(:,1);
            durR = L(:,4) - L(:,3);

            ok = isfinite(durT) & isfinite(durR) & (durT > 0) & (durR > 0);
            durT = durT(ok);
            durR = durR(ok);

            I_corr_n = numel(durT);
            if I_corr_n >= 2
                I_corr_pearson  = corr(durR(:), durT(:), 'Rows','complete', 'Type','Pearson');
                I_corr_spearman = corr(durR(:), durT(:), 'Rows','complete', 'Type','Spearman');
            end

            % also compute durDiff max/median if missing
            if ~isfinite(I_durDiffAbs_max) || ~isfinite(I_durDiffAbs_median)
                dd = abs(durT - durR);
                if ~isempty(dd)
                    if ~isfinite(I_durDiffAbs_max),    I_durDiffAbs_max    = max(dd); end
                    if ~isfinite(I_durDiffAbs_median), I_durDiffAbs_median = median(dd,'omitnan'); end
                    if ~isfinite(I_nMatched),          I_nMatched          = numel(dd); end
                end
            end
        end
    end
catch
end

% Fill strict interval columns
Tstrict.Intervals_nMatched = I_nMatched;
Tstrict.Intervals_durDiffAbs_median = I_durDiffAbs_median;
Tstrict.Intervals_durDiffAbs_max    = I_durDiffAbs_max;

Tstrict.Intervals_All_nTest = I_nTestAll;
Tstrict.Intervals_All_nRef  = I_nRefAll;
Tstrict.Intervals_All_medianTest = I_medTestAll;
Tstrict.Intervals_All_medianRef  = I_medRefAll;

Tstrict.Intervals_All_KS2_p = I_ks2_p;
Tstrict.Intervals_All_KS2_D = I_ks2_D;

Tstrict.Intervals_Matched_corr_n = I_corr_n;
Tstrict.Intervals_Matched_corr_Pearson  = I_corr_pearson;
Tstrict.Intervals_Matched_corr_Spearman = I_corr_spearman;

% Write strict summary
writetable(Tstrict, xlsxFile, 'Sheet','strict_summary', 'WriteMode','overwritesheet');

% ---------------- Keep your existing detailed sheets (optional) ----------------
if isfield(out,'eventsStats') && isstruct(out.eventsStats)

    % events summary (keep, but now you also have strict_summary)
    try
        e = out.eventsStats.events;
        Te = struct2table(e);
        writetable(Te, xlsxFile, 'Sheet','events_summary', 'WriteMode','overwritesheet');
    catch
    end

    % dt histogram
    try
        dh = out.eventsStats.events.dtHist;
        Tdh = table(dh.edges(1:end-1)', dh.edges(2:end)', dh.counts(:), ...
            'VariableNames',{'EdgeLeft','EdgeRight','Count'});
        writetable(Tdh, xlsxFile, 'Sheet','events_dt_hist', 'WriteMode','overwritesheet');
    catch
    end

    % intervals summary (flatten)
    try
        it = out.eventsStats.intervals;
        Ti = table();
        Ti.nMatched = it.nMatched;
        Ti.durDiffAbs_median = it.durDiffAbs_median;
        Ti.durDiffAbs_mean   = it.durDiffAbs_mean;
        Ti.durDiffAbs_p90    = it.durDiffAbs_p90;
        Ti.nTest = it.all.nTest;
        Ti.nRef  = it.all.nRef;
        Ti.medTest = it.all.medTest;
        Ti.medRef  = it.all.medRef;
        Ti.iqrTest = it.all.iqrTest;
        Ti.iqrRef  = it.all.iqrRef;
        Ti.ks2_p = it.all.ks2_p;
        Ti.ks2_D = it.all.ks2_D;
        writetable(Ti, xlsxFile, 'Sheet','intervals_summary', 'WriteMode','overwritesheet');
    catch
    end

    % intervals histogram (durDiff)
    try
        ih = out.eventsStats.intervals.durDiffHist;
        Tih = table(ih.edges(1:end-1)', ih.edges(2:end)', ih.counts(:), ...
            'VariableNames',{'EdgeLeft','EdgeRight','Count'});
        writetable(Tih, xlsxFile, 'Sheet','intervals_hist', 'WriteMode','overwritesheet');
    catch
    end

else
    writetable(table("no eventsStats"), xlsxFile, 'Sheet','events_summary', 'WriteMode','overwritesheet');
end

end



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
