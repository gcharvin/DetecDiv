function validateTrainingData(classif, roiobj, varargin)
% validateTrainingData
% Wrapper de validation autour de classifyData:
%   - appelle classifyData (mêmes chemins d'inférence, mêmes outputs écrits dans les ROIs)
%   - puis appelle stats() (export dans run folder si run actif)
%   - optionnellement ferme le run
%
% Options propres à la validation (name/value ou flags):
%   'DoStats'     : 0/1 (default 1)
%   'CloseRun'    : 0/1 (default 1)
%   'StatsArgs'   : cell array d'args additionnels pour stats(classif,...)
%
% Tout le reste des varargin est forwardé tel quel à classifyData.

% ---------------- defaults ----------------
doStats   = true;
closeRun  = true;
statsArgs = {};

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

% ---------------- run helpers (run est une PROP) ----------------
runActive = false;
runDir = '';

hasRunProp = isprop(classif, 'run') && ~isempty(classif.run);

if hasRunProp
    try
        % run peut être struct OU objet; on teste "active"
        if isstruct(classif.run)
            if isfield(classif.run,'active') && classif.run.active
                runActive = true;
            end
            if isfield(classif.run,'runDir')
                runDir = classif.run.runDir;
            end
        else
            % objet: access via dot
            if isprop(classif.run,'active') && classif.run.active
                runActive = true;
            elseif isfield(classif.run,'active') && classif.run.active %#ok<ISFLD>
                runActive = true;
            end

            if isprop(classif.run,'runDir')
                runDir = classif.run.runDir;
            elseif isfield(classif.run,'runDir') %#ok<ISFLD>
                runDir = classif.run.runDir;
            end
        end
    catch
        runActive = false;
        runDir = '';
    end
end

% petites fonctions safe pour éviter de crash si runMsg/runSave/runStop absents
runMsg  = @(varargin) [];
runSave = @(varargin) [];
runStop = @() [];

if hasRunProp
    if ismethod(classif,'runMsg')
        runMsg = @(varargin) classif.runMsg(varargin{:});
    end
    if ismethod(classif,'runSave')
        runSave = @(varargin) classif.runSave(varargin{:});
    end
    if ismethod(classif,'runStop')
        runStop = @() classif.runStop();
    end
end

% ---------------- run logging: start ----------------
if runActive
    runMsg('--- VALIDATION START ---');
    runMsg('validateTrainingData: nROI=%d | DoStats=%d | CloseRun=%d', nROI, doStats, closeRun);
    try
        runSave('validation_context.mat', ...
            'roi_ids', {roiobj.id}, ...
            'argsClassify', argsClassify, ...
            'doStats', doStats, ...
            'closeRun', closeRun);
    catch
    end
end

tStart = tic;

% ---------------- call inference engine ----------------
disp('--- validateTrainingData: calling classifyData(...) ---');
classifyData(classif, roiobj, argsClassify{:});

elapsedClassify = toc(tStart);

if runActive
    runMsg('classifyData done (%.1fs)', elapsedClassify);
end

% ---------------- stats (optional) ----------------
% ---------------- stats (optional) ----------------
if doStats
    try
        % map roiobj -> indices classif.roi si possible
        roiid = [];
        try
            allIDs = strtrim(string({classif.roi.id}));
            selIDs = strtrim(string({roiobj.id}));
            [tf, loc] = ismember(selIDs, allIDs);
            roiid = loc(tf);
        catch
            roiid = [];
        end

        % --- choisir un dossier d'export dans TOUS les cas ---
        if runActive && ~isempty(runDir) && exist(runDir,'dir')
            exportDir = runDir;
        else
            stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
            exportDir = fullfile(classif.path,'runs',['validation_' stamp]);
            if ~exist(exportDir,'dir'), mkdir(exportDir); end
        end

        exportBase = fullfile(exportDir, sprintf('validation_%s', classif.strid));

        % --- sauver context quoi qu'il arrive (run ou pas) ---
        try
            roi_ids = {roiobj.id}; %#ok<NASGU>
            argsClassify_local = argsClassify; %#ok<NASGU>
            doStats_local = doStats; %#ok<NASGU>
            closeRun_local = closeRun; %#ok<NASGU>
            save(fullfile(exportDir,'validation_context.mat'), ...
                'roi_ids','argsClassify_local','doStats_local','closeRun_local','-v7.3');
        catch
        end

        % --- appeler stats avec export + silent ---
        args = {'Force'};
        if ~isempty(roiid)
            args = [args, {'Rois', roiid}];
        end
        args = [args, {'Export', exportBase, 'Confusion', 'ROI', 'Classes', 'Silent'}];

        if ~isempty(statsArgs)
            args = [args, statsArgs];
        end

        stats(classif, args{:});

        % --- sauver scores quoi qu'il arrive ---
        try
            if ~isempty(classif.score)
                score = classif.score; %#ok<NASGU>
                save(fullfile(exportDir,'validation_scores.mat'), 'score','-v7.3');
            end
        catch
        end

        % --- si run actif, on loggue aussi via runSave (bonus) ---
        if runActive
            runMsg('stats() done (exportDir=%s)', exportDir);
            try
                if ~isempty(classif.score)
                    runSave('validation_scores.mat', 'score', classif.score);
                end
            catch
            end
        end

    catch ME
        if runActive
            runMsg('stats() FAILED: %s', ME.getReport('basic','hyperlinks','off'));
        else
            warning('validateTrainingData: stats failed: %s', ME.message);
        end
    end
end

% ---------------- close run (optional) ----------------
if runActive && closeRun
    runMsg('--- VALIDATION END ---');
    runStop();
end

% ---------------- summarize runs (silent update) ----------------
try
    summarizeRuns(classif, argsSummary{:});
catch ME
    if runActive
        runMsg('summarizeRuns failed: %s', ME.getReport('basic','hyperlinks','off'));
    end
end

end
