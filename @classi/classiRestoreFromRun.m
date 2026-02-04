function out = classiRestoreFromRun(classif, runDirOrName, varargin)
% classiRestoreFromRun Restore main classifier artifacts from a run folder.
%
% Usage:
%   out = classiRestoreFromRun(classif, runDir)
%   out = classiRestoreFromRun(classif, runName)   % looks under classif.path/runs/runName
%
% Options (name-value):
%   'CopyClassification' (true/false) default true
%   'Verbose'            (true/false) default true
%
% Restores (when present) into classif.path:
%   <strid>.mat                           (required)
%   netCNN_<strid>.mat                    (optional)
%   netLSTM_<strid>.mat                   (optional)
%   trainingParam.mat                     (optional but usually present)
%   <strid>_classification.mat            (optional snapshot of classi object)
%   CNN_info.mat / CNN_split.mat          (optional legacy/info files)
%   validation_context.mat / validation_scores.mat (optional)
%
% Side effects:
%   - updates classif.trainingParam if trainingParam.mat or snapshot provides it
%   - updates classif.classes and classif.channelName if snapshot provides them
%   - prints a log of what was copied (unless Verbose=false)
%
% Output:
%   out struct with resolved runDir/base and copy statuses.

% ----------------------- parse inputs -----------------------
p = inputParser;
p.FunctionName = mfilename;

addParameter(p,'CopyClassification',true, @(x)islogical(x)||isnumeric(x));
addParameter(p,'Verbose',true,          @(x)islogical(x)||isnumeric(x));

parse(p,varargin{:});
copyClassif = logical(p.Results.CopyClassification);
verbose     = logical(p.Results.Verbose);

% ----------------------- resolve base & ids -----------------------
if ~isobject(classif)
    error('classiRestoreFromRun:InvalidInput','classif must be an object.');
end

sid  = char(string(classif.strid));
base = char(string(classif.path));  % IMPORTANT: destination base is classif.path

if isempty(base) || ~isfolder(base)
    error('classiRestoreFromRun:InvalidBasePath', ...
        'Destination folder classif.path is invalid or not found: %s', base);
end

% ----------------------- resolve runDir -----------------------
runDir = char(string(runDirOrName));
if ~isfolder(runDir)
    candidate = fullfile(base,'runs',runDir);
    if isfolder(candidate)
        runDir = candidate;
    else
        error('classiRestoreFromRun:RunNotFound', ...
            'Run folder not found: %s', runDirOrName);
    end
end

% ----------------------- helper: logging copy -----------------------
out = struct();
out.base   = base;
out.runDir = runDir;
out.sid    = sid;
out.copied = struct();

logf = @(varargin) fprintf(varargin{:});
if ~verbose
    logf = @(varargin) [];
end

    function st = localCopy(src, dst, required)
        % returns struct with status + message
        st = struct('src',src,'dst',dst,'exists',false,'copied',false,'msg',"");
        if exist(src,'file')==2
            st.exists = true;
            try
                % ensure destination folder exists
                dstDir = fileparts(dst);
                if ~isempty(dstDir) && ~isfolder(dstDir)
                    mkdir(dstDir);
                end
                copyfile(src,dst);
                st.copied = true;
                st.msg = "OK";
                logf('[OK]  %s -> %s\n', src, dst);
            catch ME
                st.msg = string(ME.message);
                logf('[ERR] %s -> %s\n      %s\n', src, dst, ME.message);
                if required
                    error('classiRestoreFromRun:CopyFailed', ...
                        'Failed to copy required file:\n  %s\n->%s\n%s', src, dst, ME.message);
                end
            end
        else
            st.exists = false;
            st.msg = "MISSING";
            if required
                logf('[ERR] Missing required: %s\n', src);
                error('classiRestoreFromRun:MissingRequired', ...
                    'Missing required artifact in run: %s', src);
            else
                logf('[--]  Missing (optional): %s\n', src);
            end
        end
    end

% ----------------------- list of artifacts -----------------------
% Required
srcMain = fullfile(runDir, [sid '.mat']);
dstMain = fullfile(base,   [sid '.mat']);

out.copied.main = localCopy(srcMain, dstMain, true);

% Optional networks (support both netCNN_ and netCNN- naming just in case)
srcCNN = fullfile(runDir, ['netCNN_' sid '.mat']);
dstCNN = fullfile(base,   ['netCNN_' sid '.mat']);
out.copied.netCNN = localCopy(srcCNN, dstCNN, false);

srcLSTM = fullfile(runDir, ['netLSTM_' sid '.mat']);
dstLSTM = fullfile(base,   ['netLSTM_' sid '.mat']);
out.copied.netLSTM = localCopy(srcLSTM, dstLSTM, false);

% Optional training parameters
srcTP = fullfile(runDir, 'trainingParam.mat');
dstTP = fullfile(base,   'trainingParam.mat');
out.copied.trainingParam = localCopy(srcTP, dstTP, false);

% Optional snapshot of classifier object
srcCls = fullfile(runDir, [sid '_classification.mat']);
dstCls = fullfile(base,   [sid '_classification.mat']);
out.copied.classificationSnapshot = localCopy(srcCls, dstCls, false);

% Optional legacy/info files sometimes present in your runs
out.copied.CNN_info  = localCopy(fullfile(runDir,'CNN_info.mat'),  fullfile(base,'CNN_info.mat'),  false);
out.copied.CNN_split = localCopy(fullfile(runDir,'CNN_split.mat'), fullfile(base,'CNN_split.mat'), false);

% Optional validation artifacts (keep them alongside the classifier folder)
out.copied.validation_context = localCopy(fullfile(runDir,'validation_context.mat'), fullfile(base,'validation_context.mat'), false);
out.copied.validation_scores  = localCopy(fullfile(runDir,'validation_scores.mat'),  fullfile(base,'validation_scores.mat'),  false);

% ----------------------- hydrate classif fields -----------------------
% Priority for trainingParam:
%   1) trainingParam.mat if present
%   2) snapshot if present and CopyClassification==true
%
% classes/channelName:
%   from snapshot if present and CopyClassification==true
%
out.hydrate = struct('trainingParam',false,'classes',false,'channelName',false,'fromSnapshot',false);

% 1) trainingParam.mat
if out.copied.trainingParam.copied
    try
        S = load(dstTP);
        if isfield(S,'trainingParam')
            classif.trainingParam = S.trainingParam;
            out.hydrate.trainingParam = true;
            logf('[OK]  Hydrated classif.trainingParam from %s\n', dstTP);
        else
            logf('[--] trainingParam.mat has no variable named "trainingParam"\n');
        end
    catch ME
        logf('[ERR] Failed to load/hydrate trainingParam: %s\n', ME.message);
    end
end

% 2) snapshot
if copyClassif && out.copied.classificationSnapshot.copied
    try
        S = load(dstCls);
        out.hydrate.fromSnapshot = true;

        % Most common case: variable is classiObj
        snap = [];
        if isfield(S,'classiObj')
            snap = S.classiObj;
        elseif isfield(S,'classif')
            snap = S.classif;
        end

        % If snap found: hydrate safe fields
        if ~isempty(snap)
            % Do NOT touch ROI (heavy + side effects)
            if isprop(snap,'classes') || isfieldSafe(snap,'classes')
                try, classif.classes = snap.classes; out.hydrate.classes = true; end
            end
            if isprop(snap,'channelName') || isfieldSafe(snap,'channelName')
                try, classif.channelName = snap.channelName; out.hydrate.channelName = true; end
            end

            % trainingParam only if not already hydrated
            if ~out.hydrate.trainingParam
                try
                    if isprop(snap,'trainingParam') || isfieldSafe(snap,'trainingParam')
                        if ~isempty(snap.trainingParam)
                            classif.trainingParam = snap.trainingParam;
                            out.hydrate.trainingParam = true;
                            logf('[OK]  Hydrated classif.trainingParam from snapshot\n');
                        end
                    end
                catch
                end
            end

            % Optional additional safe metadata (best effort)
            try, classif.description = snap.description; end
            try, classif.category    = snap.category;    end
            try, classif.outputType  = snap.outputType;  end
            try, classif.outputFun   = snap.outputFun;   end
            try, classif.outputArg   = snap.outputArg;   end

            logf('[OK]  Hydrated classif.classes/channelName (when available) from snapshot\n');
        else
            % Fallback: some files may store a pipeline struct (e.g., viterbi.processing.classification(1))
            % Best-effort guess (won't error if absent).
            try
                fn = fieldnames(S);
                % attempt to find a struct with processing.classification
                for k=1:numel(fn)
                    v = S.(fn{k});
                    if isstruct(v) && isfield(v,'processing')
                        if isfield(v.processing,'classification') && ~isempty(v.processing.classification)
                            c1 = v.processing.classification(1);
                            if isfield(c1,'classes')
                                classif.classes = c1.classes;
                                out.hydrate.classes = true;
                            end
                            if isfield(c1,'channelName')
                                classif.channelName = c1.channelName;
                                out.hydrate.channelName = true;
                            end
                            if ~out.hydrate.trainingParam && isfield(c1,'trainingParam')
                                classif.trainingParam = c1.trainingParam;
                                out.hydrate.trainingParam = true;
                            end
                            logf('[OK]  Hydrated from %s.processing.classification(1)\n', fn{k});
                            break
                        end
                    end
                end
            catch ME
                logf('[--] Snapshot fallback parse failed: %s\n', ME.message);
            end
        end

    catch ME
        logf('[ERR] Failed to load/hydrate from snapshot: %s\n', ME.message);
    end
end


% ----------------------- update classif.run (inactive) -----------------------
try
    % Determine run folder name relative to <base>/runs
    runDirAbs = runDir; % already absolute here
    % Extract run name if it's under base/runs
    baseRuns = fullfile(base,'runs');

    relRun = '';
    if startsWith(string(runDirAbs), string(baseRuns))
        % rel path after ".../runs/"
        relRun = char(string(runDirAbs));
        relRun = relRun(numel(baseRuns)+2:end); % skip file sep
        relRun = fullfile('runs', relRun);
    else
        % fallback: just take folder name
        [~, rn] = fileparts(runDirAbs);
        relRun = fullfile('runs', rn);
    end

    % Ensure run struct exists
    if ~isprop(classif,'run') || isempty(classif.run) || ~isstruct(classif.run)
        classif.run = struct( ...
            'active', false, ...
            'runDir', '', ...
            'runDirAbs', '', ...
            'consoleFile', '', ...
            'eventsFile', '', ...
            'metaFile', '', ...
            'startTime', [], ...
            'tag', '', ...
            'fun', '' );
    end

    classif.run.active    = false;
    classif.run.runDir    = relRun;
    classif.run.runDirAbs = fullfile(base, relRun);

    % standard rel files
    classif.run.consoleFile = fullfile(relRun,'console.log');
    classif.run.eventsFile  = fullfile(relRun,'events.log');
    classif.run.metaFile    = fullfile(relRun,'run.json');

    % Final normalization (defensive)
    classif.runNormalizePaths();
catch
end


% ----------------------- final log -----------------------
logf('Restored classifier from run:\n  %s\n', runDir);
logf('Destination base:\n  %s\n', base);
logf('Main classifier:\n  %s\n', dstMain);

end

% -------- local helper (outside main function) --------
function tf = isfieldSafe(objOrStruct, name)
% Safely test field existence on struct-like or object-like things.
tf = false;
try
    if isstruct(objOrStruct)
        tf = isfield(objOrStruct, name);
    else
        % object
        tf = isprop(objOrStruct, name);
    end
catch
end
end
