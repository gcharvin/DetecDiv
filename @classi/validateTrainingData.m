function validateTrainingData(classif, roiobj, varargin)
% validateTrainingData
% Safe wrapper around classifyData:
%   - always calls classifyData (writes inference outputs into ROI objects)
%   - optionally logs/stats/exports into a RUN FOLDER (if enabled and available)
%
% New behavior:
%   - If no runDirAbs is available and no override is provided => CLASSIFY ONLY (no error)
%   - Run I/O is controlled by LogMode: 'auto' (default), 'off', 'on'
%
% Assumption / invariant:
%   classif.run.runDir     : REL (portable)
%   classif.run.runDirAbs  : ABS (local)  <-- source of truth for I/O (when enabled)
%   classif.run.active     : runtime only (may be false during validation)
%
% Options (name/value or flags):
%   'LogMode'     : 'auto'|'off'|'on' (default 'auto')
%   'DoStats'     : 0/1 (default 1)  -> effective only if run I/O enabled
%   'CloseRun'    : 0/1 (default 0)
%   'StatsArgs'   : cell array of extra args for stats(classif,...)
%   'RunDirAbs'   : override target folder (absolute) [optional]
%
% Any other varargin is forwarded to classifyData unchanged
% (except summary keys: open/savecsv/runsroot/filter/sortby -> summarizeRuns).

% ---------------- defaults ----------------
doStats   = true;
closeRun  = false;
statsArgs = {};
runDirAbsOverride = '';
logMode = "auto";  % "auto"|"off"|"on"

argsClassify = {};
argsSummary  = {};
summaryKeys = ["open","savecsv","runsroot","filter","sortby"];

% ---------------- parse varargin ----------------
i = 1;
while i <= numel(varargin)

    key = varargin{i};
    if ~(ischar(key) || isstring(key))
        i = i + 1;
        continue;
    end
    keyL = lower(strtrim(string(key)));

    % ---- summarizeRuns args ----
    if any(keyL == summaryKeys)
        if i < numel(varargin)
            argsSummary = [argsSummary, {char(key), varargin{i+1}}]; %#ok<AGROW>
            i = i + 2;
        else
            argsSummary = [argsSummary, {char(key)}]; %#ok<AGROW>
            i = i + 1;
        end
        continue;
    end

    % ---- validation options ----
    if keyL == "logmode"
        if i < numel(varargin)
            logMode = lower(strtrim(string(varargin{i+1})));
            i = i + 2;
        else
            i = i + 1;
        end
        continue;
    end

    if keyL == "dostats"
        if i < numel(varargin) && (islogical(varargin{i+1}) || isnumeric(varargin{i+1}))
            doStats = logical(varargin{i+1});
            i = i + 2;
        else
            doStats = true;
            i = i + 1;
        end
        continue;
    end

    if keyL == "closerun"
        if i < numel(varargin) && (islogical(varargin{i+1}) || isnumeric(varargin{i+1}))
            closeRun = logical(varargin{i+1});
            i = i + 2;
        else
            closeRun = true;
            i = i + 1;
        end
        continue;
    end

    if keyL == "statsargs"
        if i < numel(varargin) && iscell(varargin{i+1})
            statsArgs = varargin{i+1};
            i = i + 2;
        else
            i = i + 1;
        end
        continue;
    end

    if keyL == "rundirabs"
        if i < numel(varargin)
            runDirAbsOverride = char(string(varargin{i+1}));
            i = i + 2;
        else
            i = i + 1;
        end
        continue;
    end

    % ---- forward to classifyData ----
    if i < numel(varargin)
        nxt = varargin{i+1};
        if (ischar(nxt) || isstring(nxt))
            flags = ["gpu","cpu","parallel","classifiercnn","roiwithgt"];
            if any(keyL == flags)
                argsClassify = [argsClassify, {char(key)}]; %#ok<AGROW>
                i = i + 1;
            else
                argsClassify = [argsClassify, {char(key), nxt}]; %#ok<AGROW>
                i = i + 2;
            end
        else
            argsClassify = [argsClassify, {char(key), nxt}]; %#ok<AGROW>
            i = i + 2;
        end
    else
        argsClassify = [argsClassify, {char(key)}]; %#ok<AGROW>
        i = i + 1;
    end
end

nROI = numel(roiobj);

% ---------------- resolve runDirAbs + runActive ----------------
[runDirAbs, runActive] = localGetRunDirAbsAndActive_(classif, runDirAbsOverride);

% ---------------- decide if run I/O is enabled ----------------
logMode = lower(strtrim(string(logMode)));
wantRunIO = true;

if logMode == "off"
    wantRunIO = false;
elseif logMode == "on"
    wantRunIO = true;
else
    % "auto": enable only if we have a runDirAbs
    wantRunIO = ~isempty(runDirAbs);
end

haveRunDir = wantRunIO && ~isempty(runDirAbs);

% If user forced "on" but we still don't have a directory: degrade gracefully
if wantRunIO && isempty(runDirAbs)
    haveRunDir = false;
    warning('validateTrainingData:NoRunDirAbs', ...
        'LogMode="on" requested but no runDirAbs available. Falling back to classify-only (no logging/stats/exports).');
end

% Make folder only if we will use it
if haveRunDir
    if ~exist(runDirAbs,'dir')
        mkdir(runDirAbs);
    end
end

% ---------------- logging function ----------------
% - If haveRunDir: append to file + mirror to runMsg if active
% - Else: console only (and no runMsg)
vlog = @(fmt,varargin) localLog_(classif, runDirAbs, haveRunDir, runActive, fmt, varargin{:});

vlog('--- VALIDATION START ---');
vlog('validateTrainingData: nROI=%d | DoStats=%d | CloseRun=%d | LogMode=%s | haveRunDir=%d | runDirAbs=%s', ...
    nROI, doStats, closeRun, char(logMode), haveRunDir, string(runDirAbs));

% save context snapshot (only if run I/O)
if haveRunDir
    try
        roi_ids = {roiobj.id}; %#ok<NASGU>
        argsClassify_local = argsClassify; %#ok<NASGU>
        doStats_local = doStats; %#ok<NASGU>
        closeRun_local = closeRun; %#ok<NASGU>
        save(fullfile(runDirAbs,'validation_context.mat'), ...
            'roi_ids','argsClassify_local','doStats_local','closeRun_local','-v7.3');
    catch ME
        vlog('WARN: could not save validation_context.mat (%s)', ME.message);
    end
end

% ---------------- call inference engine (always) ----------------
disp('--- validateTrainingData: calling classifyData(...) ---');

tStart = tic;
classifyData(classif, roiobj, argsClassify{:});
elapsedClassify = toc(tStart);

vlog('classifyData done (%.1fs)', elapsedClassify);

% ---------------- stats (optional, only if run I/O) ----------------
if doStats && haveRunDir
    try
        % map roiobj -> indices in classif.roi if possible
        roiid = [];
        try
            allIDs = strtrim(string({classif.roi.id}));
            selIDs = strtrim(string({roiobj.id}));
            [tf, loc] = ismember(selIDs, allIDs);
            roiid = loc(tf);
        catch
            roiid = [];
        end

        exportBase = fullfile(runDirAbs, sprintf('validation_%s', char(string(classif.strid))));

        args = {'Force'};
        if ~isempty(roiid)
            args = [args, {'Rois', roiid}];
        end
        args = [args, {'Export', exportBase, 'Confusion', 'ROI', 'Classes', 'Silent'}];

        if ~isempty(statsArgs)
            args = [args, statsArgs];
        end

        stats(classif, args{:});
        vlog('stats() done (exportBase=%s)', exportBase);

        % snapshot scores into run folder
        try
            if ~isempty(classif.score)
                score = classif.score; %#ok<NASGU>
                save(fullfile(runDirAbs,'validation_scores.mat'), 'score','-v7.3');
            end
        catch
        end

    catch ME
        vlog('stats() FAILED: %s', ME.getReport('basic','hyperlinks','off'));
        warning('validateTrainingData: stats failed: %s', ME.message);
    end
elseif doStats && ~haveRunDir
    vlog('stats() skipped (no run I/O enabled)');
end

% ==========================================================
% OPTIONAL: batonnets_proceedRender (only for LSTM + CNN, and only with run I/O)
% ==========================================================
if haveRunDir
    try
        doBatonnets = localIsLSTMCNN_(classif);

        if ~doBatonnets
            vlog('batonnets_proceedRender skipped (classifier ≠ "LSTM + CNN")');
        else
            aa = struct();
            aa.BarHeight            = 10;
            aa.FrameWidth           = 2;
            aa.ShowColorbar         = 1;
            aa.LabelColormapName    = "lines";
            aa.NumbersColormapName  = "jet";

            k1 = string(classif.strid) + "|labels";
            k2 = string(classif.strid) + "|labels_training";
            compareKeys = [k1 k2];

            gapROI     = max(1, round(aa.BarHeight / 2));
            gapCompare = max(1, round(aa.BarHeight / 4));

            % auto EventRulesByKey
            classNames  = string(classif.classes(:)');
            classNamesL = lower(strtrim(classNames));

            % --- class2 list: prefer "small", else fallback to smallb/smallt ---
            class2List = strings(1,0);
            if any(classNamesL == "small")
                class2List = "small";
            else
                if any(classNamesL == "smallb"), class2List(end+1) = "smallb"; end %#ok<AGROW>
                if any(classNamesL == "smallt"), class2List(end+1) = "smallt"; end %#ok<AGROW>
            end

            % --- class1 list: we want both large and unbud if present ---
            class1Wanted = ["large","unbud"];
            class1List = strings(1,0);
            for c1 = class1Wanted
                if any(classNamesL == c1)
                    class1List(end+1) = c1; %#ok<AGROW>
                end
            end

            % --- build rules: Start + End for every (class1, class2) pair ---
            rules = struct('name',{},'type',{},'from',{},'to',{});
            if ~isempty(class1List) && ~isempty(class2List)
                for c1 = class1List
                    for c2 = class2List
                        rules(end+1) = struct('name',"Event", 'type',"Start", 'from',c1, 'to',c2); %#ok<AGROW>
                        rules(end+1) = struct('name',"Event", 'type',"End",   'from',c1, 'to',c2); %#ok<AGROW>
                    end
                end
            end

            eventRulesByKey = containers.Map('KeyType','char','ValueType','any');
            eventRulesByKey(char(k1)) = rules;
            eventRulesByKey(char(k2)) = rules;

            % ---- convert ROI objects -> roiList struct expected by batonnets_proceedRender ----
            roiList = localMakeRoiList_(roiobj);

            batonnets_proceedRender(roiList, compareKeys, ...
                'BarHeight', aa.BarHeight, ...
                'FrameWidth', aa.FrameWidth, ...
                'ShowColorbar', aa.ShowColorbar, ...
                'LabelColormapName', aa.LabelColormapName, ...
                'NumbersColormapName', aa.NumbersColormapName, ...
                'DisplayMaxTraj', Inf, ...
                'EventRulesByKey', eventRulesByKey, ...
                'Compare', true, ...
                'GapROI', gapROI, ...
                'GapCompare', gapCompare, ...
                'Classifier', classif);

            vlog('batonnets_proceedRender done (LSTM + CNN | nRules=%d)', numel(rules));
        end

    catch MEb
        vlog('batonnets_proceedRender FAILED: %s', MEb.getReport('basic','hyperlinks','off'));
        warning('validateTrainingData: batonnets_proceedRender failed: %s', MEb.message);
    end
else
    vlog('batonnets_proceedRender skipped (no run I/O enabled)');
end

% ---------------- summarize runs (best effort, only if run I/O) ----------------
if haveRunDir
    try
        summarizeRuns(classif, argsSummary{:});
    catch ME
        vlog('summarizeRuns failed: %s', ME.getReport('basic','hyperlinks','off'));
    end
else
    if ~isempty(argsSummary)
        vlog('summarizeRuns skipped (no run I/O enabled)');
    end
end

vlog('--- VALIDATION END ---');

end

% =====================================================================
% LOCAL HELPERS
% =====================================================================

function roiList = localMakeRoiList_(roiobj)
n = numel(roiobj);
roiList = repmat(struct('roiObj',[], 'label',""), 1, n);
for k = 1:n
    roiList(k).roiObj = roiobj(k);
    try
        roiList(k).label = string(roiobj(k).id);
    catch
        roiList(k).label = "ROI " + k;
    end
end
end

function [runDirAbs, runActive] = localGetRunDirAbsAndActive_(classif, overrideAbs)
runDirAbs = '';
runActive = false;

if nargin >= 2 && ~isempty(overrideAbs)
    runDirAbs = char(string(overrideAbs));
end

if isempty(runDirAbs)
    try
        if isprop(classif,'run') && isstruct(classif.run)
            if isfield(classif.run,'runDirAbs') && ~isempty(classif.run.runDirAbs)
                runDirAbs = char(string(classif.run.runDirAbs));
            end
        end
    catch
    end
end

try
    if isprop(classif,'run') && isstruct(classif.run)
        if isfield(classif.run,'active') && isequal(classif.run.active,true)
            runActive = true;
        end
    end
catch
    runActive = false;
end
end

function tf = localIsLSTMCNN_(classif)
tf = false;
try
    if isprop(classif,'description') && ~isempty(classif.description)
        if numel(classif.description) >= 3
            d3 = classif.description{3};
            if ischar(d3) || isstring(d3)
                tf = string(d3) == "LSTM + CNN";
            end
        end
    end
catch
    tf = false;
end
end

function localLog_(classif, runDirAbs, haveRunDir, runActive, fmt, varargin)
% If haveRunDir: append to <runDirAbs>/events_validation.log.
% Mirror to classif.runMsg only if runActive.
% If no run dir: console only.

% Build message
try
    if isempty(varargin)
        msg = sprintf('%s', fmt);
    else
        msg = sprintf(fmt, varargin{:});
    end
catch
    msg = 'LOG_FORMAT_ERROR';
end

ts = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
line = sprintf('[%s] %s', ts, msg);

% 1) file log
if haveRunDir
    try
        fp = fullfile(runDirAbs,'events_validation.log');
        fid = fopen(fp,'a');
        if fid >= 0
            fprintf(fid,'%s\n', line);
            fclose(fid);
        end
    catch
        try, fclose(fid); catch, end %#ok<TRYNC>
    end
else
    % 1b) console only
    try
        disp(line);
    catch
    end
end

% 2) runMsg mirror (only if active)
if runActive
    try
        if ismethod(classif,'runMsg')
            classif.runMsg(fmt, varargin{:});
        end
    catch
    end
end
end
