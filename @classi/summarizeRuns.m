function T = summarizeRuns(classif, varargin)
% summarizeRuns  Build a table summarizing logged runs.
%
% T = summarizeRuns(classif)
% T = summarizeRuns(classif,'Open',true)
% T = summarizeRuns(classif,'SaveCSV',true)
% T = summarizeRuns(classif,'RunsRoot',fullfile(classif.path,'runs'))
% T = summarizeRuns(classif,'Filter',"viterbi")     % substring/regex on run folder name
% T = summarizeRuns(classif,'SortBy',"timestamp")   % timestamp|runName|LSTM_valAcc|val_fscore|...
%
% Expects per run folder:
%   run.json (meta)
%   CNN_info.mat / LSTM_info.mat (optional)
%   validation_summary.json (optional)
%   validation_scores.mat (optional)  % saved by validateTrainingData/stats
%
% Notes:
% - Handles TrainingInfo objects with TrainingHistory/ValidationHistory (trainnet),
%   plus older trainNetwork TrainingInfo and custom structs.
% - Writes runs_summary.xlsx to <classif.path>/runs (always).

p = inputParser;
addParameter(p,'Open',false,@islogical);
addParameter(p,'SaveCSV',false,@islogical);
addParameter(p,'RunsRoot',"",@(x) ischar(x) || isstring(x));
addParameter(p,'Filter',"",@(x) ischar(x) || isstring(x));
addParameter(p,'SortBy',"timestamp",@(x) ischar(x) || isstring(x));
parse(p,varargin{:});
opt = p.Results;

% ----- runs root -----
runsRoot = string(opt.RunsRoot);
if strlength(runsRoot)==0
    runsRoot = string(fullfile(classif.path,'runs'));
end
runsRoot = char(runsRoot);

if ~isfolder(runsRoot)
    warning('No runs folder: %s', runsRoot);
    T = table();
    return;
end

% ----- list run dirs -----
d = dir(runsRoot);
d = d([d.isdir]);
d = d(~ismember({d.name},{'.','..'}));

% optional filter on folder name
flt = string(opt.Filter);
if strlength(flt)>0
    keep = false(size(d));
    for i=1:numel(d)
        keep(i) = ~isempty(regexp(d(i).name, flt, 'once')); %#ok<RGXP1>
    end
    d = d(keep);
end


% ------------------------------------------------------------
% Batonnets strict_summary: fixed set of columns we expect
% ------------------------------------------------------------
batPrefix = "bat_";
batVars = [ ...
    "Events_nTest"
    "Events_nRef"
    "Events_TP"
    "Events_FP"
    "Events_FN"
    "Events_FP_rate_test"
    "Events_FN_rate_ref"
    "Events_TP_rate_test"
    "Events_TP_rate_ref"
    "Events_dtAbs_n"
    "Events_dtAbs_median"
    "Events_dtAbs_max"
    "Intervals_nMatched"
    "Intervals_durDiffAbs_median"
    "Intervals_durDiffAbs_max"
    "Intervals_All_nTest"
    "Intervals_All_nRef"
    "Intervals_All_medianTest"
    "Intervals_All_medianRef"
    "Intervals_All_KS2_p"
    "Intervals_All_KS2_D"
    "Intervals_Matched_corr_n"
    "Intervals_Matched_corr_Pearson"
    "Intervals_Matched_corr_Spearman" ...
];

% which of these should be numeric? (spoiler: all)
batIsNum = true(size(batVars));



    S.runDir  = string(runDir);
    S.runName = string(d(i).name);

    % ---- read run.json ----
    meta = struct();
    try
        txt = fileread(jf);
        meta = jsondecode(txt);
    catch
        meta = struct();
    end

    S.timestamp   = localToString(localGet(meta,'timestamp',""));
    S.trainingFun = localToString(localGet(meta,'trainingFun',""));
    S.strid       = localToString(localGet(meta,'strid', classif.strid));

    % ---- trainingParam snapshot (light) ----
    tp = [];
    if isstruct(meta) && isfield(meta,'trainingParam')
        tp = meta.trainingParam;
    end

    % backend: take LAST element if list/cell/array
    S.backend = localLastScalarString(localGet(tp,'Format_StorageBackend',""));

    % CNN params
    S.CNN_epochs    = localScalarNum(localGet(tp,'CNN_max_epochs',nan));
    S.CNN_miniBatch = localScalarNum(localGet(tp,'CNN_mini_batch_size',nan));
    S.CNN_lr        = localScalarNum(localGet(tp,'CNN_initial_learning_rate',nan));
    S.CNN_net       = localLastScalarString(localGet(tp,'CNN_network',""));

    % LSTM params
    S.LSTM_epochs    = localScalarNum(localGet(tp,'LSTM_max_epochs',nan));
    S.LSTM_miniBatch = localScalarNum(localGet(tp,'LSTM_mini_batch_size',nan));
    S.LSTM_lr        = localScalarNum(localGet(tp,'LSTM_initial_learning_rate',nan));
    S.LSTM_hidden    = localScalarNum(localGet(tp,'LSTM_hidden_size',nan));
    S.LSTM_L         = localScalarNum(localGet(tp,'LSTM_sequence_length',nan));

    % ---- files presence ----
    fCNN  = fullfile(runDir,'CNN_info.mat');
    fLSTM = fullfile(runDir,'LSTM_info.mat');
    S.hasCNN  = exist(fCNN,'file')  > 0;
    S.hasLSTM = exist(fLSTM,'file') > 0;

    % ---- Metrics from info ----
    % CNN
    S.CNN_valAcc     = nan; S.CNN_trainAcc = nan;
    S.CNN_valLoss    = nan; S.CNN_trainLoss = nan;
    S.CNN_bestValAcc = nan; S.CNN_bestValLoss = nan;

    % LSTM
    S.LSTM_valAcc     = nan; S.LSTM_trainAcc = nan;
    S.LSTM_valLoss    = nan; S.LSTM_trainLoss = nan;
    S.LSTM_bestValAcc = nan; S.LSTM_bestValLoss = nan;

    % CNN
if S.hasCNN
    try
        info = localLoadInfoNoPlot(fCNN);  % <-- au lieu de A = load(...)
        [S.CNN_valAcc, S.CNN_trainAcc, S.CNN_valLoss, S.CNN_trainLoss, ...
         S.CNN_bestValAcc, S.CNN_bestValLoss] = localExtractInfo(info);
    catch
    end
end

% LSTM
if S.hasLSTM
    try
        info = localLoadInfoNoPlot(fLSTM); % <-- au lieu de A = load(...)
        [S.LSTM_valAcc, S.LSTM_trainAcc, S.LSTM_valLoss, S.LSTM_trainLoss, ...
         S.LSTM_bestValAcc, S.LSTM_bestValLoss] = localExtractInfo(info);
    catch
    end
end

    % ---- validation summary (optional) ----
    S.val_nROI = nan; S.val_nClassified = nan; S.val_nSkipped = nan; S.val_nErrors = nan; S.val_seconds = nan;
    vjs = fullfile(runDir,'validation_summary.json');
    if exist(vjs,'file')
        try
            vtxt = fileread(vjs);
            vs = jsondecode(vtxt);
            S.val_nROI        = localScalarNum(localGet(vs,'nROI',nan));
            S.val_nClassified = localScalarNum(localGet(vs,'nClassified',nan));
            S.val_nSkipped    = localScalarNum(localGet(vs,'nSkipped',nan));
            S.val_nErrors     = localScalarNum(localGet(vs,'nErrors',nan));
            S.val_seconds     = localScalarNum(localGet(vs,'seconds',nan));
        catch
        end
    end

    % ---- validation scores (optional) ----
    S.val_thr      = nan;
    S.val_accuracy = nan;
    S.val_recall   = nan;
    S.val_fscore   = nan;
    S.val_N        = nan;
    S.val_comments = "";

    for c = 1:K
        S.(sprintf('val_c%d_accuracy',c)) = nan;
        S.(sprintf('val_c%d_recall',c))   = nan;
        S.(sprintf('val_c%d_fscore',c))   = nan;
        S.(sprintf('val_c%d_N',c))        = nan;
    end

    fVS = fullfile(runDir,'validation_scores.mat');
    if exist(fVS,'file')
        try
            Q = load(fVS);

            % accept both "score" or "scores" or first struct variable
            sc = [];
            if isfield(Q,'score')
                sc = Q.score;
            elseif isfield(Q,'scores')
                sc = Q.scores;
            else
                fn = fieldnames(Q);
                for kk=1:numel(fn)
                    v = Q.(fn{kk});
                    if isstruct(v)
                        sc = v; break;
                    end
                end
            end

            % if array, take first element (or best one if you prefer later)
            if numel(sc) > 1
                sc = sc(1);
            end

            if isstruct(sc)
                if isfield(sc,'thr'),      S.val_thr      = localScalarNum(sc.thr); end
                if isfield(sc,'accuracy'), S.val_accuracy = localScalarNum(sc.accuracy); end
                if isfield(sc,'recall'),   S.val_recall   = localScalarNum(sc.recall); end
                if isfield(sc,'fscore'),   S.val_fscore   = localScalarNum(sc.fscore); end
                if isfield(sc,'N'),        S.val_N        = localScalarNum(sc.N); end
                if isfield(sc,'comments') && ~isempty(sc.comments)
                    S.val_comments = localToString(sc.comments);
                end

                % per class metrics (NO confusion matrix in table)
                if isfield(sc,'classes') && ~isempty(sc.classes)
                    C = sc.classes;
                    nC = min(numel(C), K);
                    for c = 1:nC
                        if isfield(C(c),'accuracy'), S.(sprintf('val_c%d_accuracy',c)) = localScalarNum(C(c).accuracy); end
                        if isfield(C(c),'recall'),   S.(sprintf('val_c%d_recall',c))   = localScalarNum(C(c).recall);   end
                        if isfield(C(c),'fscore'),   S.(sprintf('val_c%d_fscore',c))   = localScalarNum(C(c).fscore);   end
                        if isfield(C(c),'N'),        S.(sprintf('val_c%d_N',c))        = localScalarNum(C(c).N);        end
                    end
                end
            end
        catch
        end
    end

    % ---- bestThreshold if stored ----
    S.bestThreshold = nan;
    fBT = fullfile(runDir, sprintf('netLSTM_%s.mat', classif.strid));
    if exist(fBT,'file')
        try
            B = load(fBT,'bestThreshold');
            if isfield(B,'bestThreshold')
                S.bestThreshold = localScalarNum(B.bestThreshold);
            end
        catch
        end
    end

    % ------------------------------------------------------------
% Batonnets strict_summary (optional) -> add as columns
% ------------------------------------------------------------
fx = fullfile(runDir,'batonnets_compare_metrics.xlsx');
if exist(fx,'file')==2 && ~isempty(batVars)
    try
        Tbat = readtable(fx,'Sheet','strict_summary');

        if ~isempty(Tbat) && height(Tbat) >= 1
            r = Tbat(1,:);

            % normalize names once
            vns = string(r.Properties.VariableNames(:));
            vns = string(matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(vns)));
            r.Properties.VariableNames = cellstr(vns);

            for k = 1:numel(batVars)
                vnWanted = matlab.lang.makeValidName(char(batVars(k)));
                fnOut    = matlab.lang.makeValidName(char(batPrefix + batVars(k)));

                if ismember(vnWanted, string(r.Properties.VariableNames))
                    val = r.(vnWanted);
                    S.(fnOut) = localScalarNum(val);
                end
            end
        end
    catch
    end
end



    rows = [rows; struct2table(S,'AsArray',true)]; %#ok<AGROW>
end

if isempty(rows)
    T = table();
    return;
end

T = rows;

% ---- sorting ----
sortBy = lower(string(opt.SortBy));
T = localSortTable(T, sortBy);

% ---- outputs ----
outDir = fullfile(classif.path,'runs');
if ~exist(outDir,'dir')
    mkdir(outDir);
end

T = localMakeTableExcelSafe(T);

outXLSX = fullfile(outDir,'runs_summary.xlsx');
try
    writetable(T, outXLSX);
    fprintf('Saved runs summary: %s\n', outXLSX);
catch ME
    warning('Could not write XLSX: %s', ME.message);
end

if opt.SaveCSV
    outCSV = fullfile(outDir,'runs_summary.csv');
    try
        writetable(T,outCSV);
        fprintf('Saved runs summary CSV: %s\n', outCSV);
    catch ME
        warning('Could not write CSV: %s', ME.message);
    end
end

if opt.Open
    assignin('base','RunsSummary',T);
    openvar('RunsSummary');
end

end

% ======================================================================
% Helpers
% ======================================================================

function v = localGet(S, field, default)
v = default;
try
    if isempty(S), return; end
    if isstruct(S) && isfield(S,field)
        v = S.(field);
    end
catch
end
end

function s = localToString(x)
try
    if isempty(x), s = ""; return; end
    if iscell(x), x = x{end}; end
    s = string(x);
    if numel(s) > 1
        s = join(s(:), " | ");
    end
catch
    s = "";
end
end

function s = localLastScalarString(x)
try
    if isempty(x), s = ""; return; end
    if iscell(x), x = x{end}; end
    x = string(x);
    s = x(end);
catch
    s = "";
end
end


function n = localScalarNum(x)
n = nan;
try
    if isempty(x), return; end

    % unwrap table/cell
    if istable(x)
        x = x{1,1};
    end
    if iscell(x)
        if isempty(x), return; end
        x = x{end};
    end
    if iscategorical(x)
        x = string(x);
    end

    % numeric/logical already OK
    if islogical(x)
        n = double(x(end));
        return;
    end
    if isnumeric(x)
        n = double(x(end));
        return;
    end

    % parse string/char with possible decimal comma
    xs = string(x);
    xs = strtrim(xs);

    if strlength(xs)==0, return; end

    % IMPORTANT: decimal comma -> dot
    xs = replace(xs, ",", ".");

    % also remove spaces (some exports add them)
    xs = replace(xs, " ", "");

    nn = str2double(xs);
    if ~isnan(nn)
        n = nn;
    end
catch
end
end



function T = localMakeTableExcelSafe(T)
% Avoid cell columns / weird objects for writetable(xlsx).
vn = T.Properties.VariableNames;
for k = 1:numel(vn)
    v = T.(vn{k});
    if iscell(v)
        out = strings(size(v));
        for i = 1:numel(v)
            out(i) = localToString(v{i});
        end
        T.(vn{k}) = out;
    elseif isobject(v)
        % should not happen for scalar fields, but keep safe
        try
            T.(vn{k}) = string(v);
        catch
        end
    end
end
end

function [valAcc, trainAcc, valLoss, trainLoss, bestValAcc, bestValLoss] = localExtractInfo(info)
% Supports:
% - trainnet TrainingInfo (has TrainingHistory/ValidationHistory tables)
% - trainNetwork TrainingInfo (fields ValidationAccuracy, etc.)
% - struct wrappers

valAcc = nan; trainAcc = nan; valLoss = nan; trainLoss = nan;
bestValAcc = nan; bestValLoss = nan;

if isempty(info), return; end

% ---------------- trainnet TrainingInfo (your case) ----------------
try
    if isobject(info) && isprop(info,'TrainingHistory') && istable(info.TrainingHistory)
        TH = info.TrainingHistory;
        if ismember('Loss', TH.Properties.VariableNames) && ~isempty(TH.Loss)
            trainLoss = double(TH.Loss(end));
        end

        accName = localPickAccName(TH.Properties.VariableNames);
        if accName ~= "" && ~isempty(TH.(accName))
            trainAcc = double(TH.(accName)(end));
        end
    end

    if isobject(info) && isprop(info,'ValidationHistory') && istable(info.ValidationHistory)
        VH = info.ValidationHistory;
        if ismember('Loss', VH.Properties.VariableNames) && ~isempty(VH.Loss)
            valLoss = double(VH.Loss(end));
            bestValLoss = double(min(VH.Loss));
        end

        accName = localPickAccName(VH.Properties.VariableNames);
        if accName ~= "" && ~isempty(VH.(accName))
            valAcc = double(VH.(accName)(end));
            bestValAcc = double(max(VH.(accName)));
        end
    end

    if ~isnan(valAcc) || ~isnan(trainAcc) || ~isnan(valLoss) || ~isnan(trainLoss)
        return;
    end
catch
end

% ---------------- trainNetwork TrainingInfo (legacy) ----------------
try
    if isobject(info)
        if isprop(info,'ValidationAccuracy') && ~isempty(info.ValidationAccuracy)
            valAcc = double(info.ValidationAccuracy(end));
            bestValAcc = double(max(info.ValidationAccuracy));
        end
        if isprop(info,'TrainingAccuracy') && ~isempty(info.TrainingAccuracy)
            trainAcc = double(info.TrainingAccuracy(end));
        end
        if isprop(info,'ValidationLoss') && ~isempty(info.ValidationLoss)
            valLoss = double(info.ValidationLoss(end));
            bestValLoss = double(min(info.ValidationLoss));
        end
        if isprop(info,'TrainingLoss') && ~isempty(info.TrainingLoss)
            trainLoss = double(info.TrainingLoss(end));
        end
        if ~isnan(valAcc) || ~isnan(trainAcc) || ~isnan(valLoss) || ~isnan(trainLoss)
            return;
        end
    end
catch
end

% ---------------- struct fallback ----------------
try
    if isstruct(info)
        % struct trainnet-like
        if isfield(info,'TrainingHistory') && istable(info.TrainingHistory)
            TH = info.TrainingHistory;
            if ismember('Loss', TH.Properties.VariableNames) && ~isempty(TH.Loss)
                trainLoss = double(TH.Loss(end));
            end
            accName = localPickAccName(TH.Properties.VariableNames);
            if accName ~= "" && ~isempty(TH.(accName))
                trainAcc = double(TH.(accName)(end));
            end
        end
        if isfield(info,'ValidationHistory') && istable(info.ValidationHistory)
            VH = info.ValidationHistory;
            if ismember('Loss', VH.Properties.VariableNames) && ~isempty(VH.Loss)
                valLoss = double(VH.Loss(end));
                bestValLoss = double(min(VH.Loss));
            end
            accName = localPickAccName(VH.Properties.VariableNames);
            if accName ~= "" && ~isempty(VH.(accName))
                valAcc = double(VH.(accName)(end));
                bestValAcc = double(max(VH.(accName)));
            end
        end

        % classic fields
        if isfield(info,'ValidationAccuracy') && ~isempty(info.ValidationAccuracy)
            valAcc = double(info.ValidationAccuracy(end));
            bestValAcc = double(max(info.ValidationAccuracy));
        end
        if isfield(info,'TrainingAccuracy') && ~isempty(info.TrainingAccuracy)
            trainAcc = double(info.TrainingAccuracy(end));
        end
        if isfield(info,'ValidationLoss') && ~isempty(info.ValidationLoss)
            valLoss = double(info.ValidationLoss(end));
            bestValLoss = double(min(info.ValidationLoss));
        end
        if isfield(info,'TrainingLoss') && ~isempty(info.TrainingLoss)
            trainLoss = double(info.TrainingLoss(end));
        end
    end
catch
end
end

function accName = localPickAccName(varNames)
accName = "";
try
    accFields = ["Accuracy","Top1Accuracy","ClassificationAccuracy"];
    for k = 1:numel(accFields)
        if any(string(varNames) == accFields(k))
            accName = accFields(k);
            return;
        end
    end
catch
end
end

function T = localSortTable(T, sortBy)
if isempty(T), return; end
sortBy = lower(string(sortBy));

if sortBy == "timestamp"
    try
        dt = datetime(T.timestamp);
        [~,ix] = sort(dt,'descend');
        T = T(ix,:);
        return;
    catch
        try
            [~,ix] = sort(string(T.timestamp),'descend');
            T = T(ix,:);
            return;
        catch
        end
    end
end

vars = lower(string(T.Properties.VariableNames));
if any(vars == sortBy)
    varName = char(T.Properties.VariableNames(vars == sortBy));
    try
        x = T.(varName);
        if isstring(x) || iscellstr(x)
            [~,ix] = sort(string(x),'descend');
        else
            [~,ix] = sort(x,'descend','MissingPlacement','last');
        end
        T = T(ix,:);
        return;
    catch
    end
end

% fallback: runName desc
try
    [~,ix] = sort(string(T.runName),'descend');
    T = T(ix,:);
catch
end
end

function info = localLoadInfoNoPlot(matFile)
% localLoadInfoNoPlot  Load variable "info" while preventing any training-curve figures.
info = [];

% snapshot existing figures
figBefore = findall(0,'Type','figure');

% force figures invisible during load
oldVis = get(0,'DefaultFigureVisible');
set(0,'DefaultFigureVisible','off');
c = onCleanup(@() set(0,'DefaultFigureVisible',oldVis)); %#ok<NASGU>

try
    A = load(matFile,'info');   % load only what we need
    if isfield(A,'info')
        info = A.info;
    end
catch
    info = [];
end

% close any figures that still popped up
figAfter = findall(0,'Type','figure');
newFigs = setdiff(figAfter, figBefore);
if ~isempty(newFigs)
    try, close(newFigs); catch, end
end
end

