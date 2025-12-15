function runSaveTrainingCurves(obj, info, prefix)
% runSaveTrainingCurves  Centralized saving of training curves (PNG) + stable raw info (MAT).
%
% What it saves (into active runDir):
% - <prefix>_trainingInfo.mat  (variable "info" = STRUCT stable across MATLAB versions)
% - alias CNN_info.mat or LSTM_info.mat (variable "info" = same struct), so summarizeRuns finds it
% - <prefix>_loss.png / <prefix>_accuracy.png
% - <prefix>_meta.mat (struct)
%
% IMPORTANT:
% We do NOT save deep.TrainingInfo objects directly, because loading across versions can emit:
% "Warning: While loading an object of class 'deep.TrainingInfo': Unrecognized field name 'StopReason'."

if nargin < 3 || isempty(prefix)
    prefix = "training";
end
prefix = string(prefix);

% ------------------------------------------------------------
% Resolve active run / runDir (run can be struct or object)
% ------------------------------------------------------------
[runActive, runDir] = localGetActiveRunDir(obj);
if ~runActive
    fprintf('Job is not active, cannot save...\n');
    return;
end
if strlength(runDir) == 0
    warning('runDir is empty; cannot save training curves.');
    return;
end
runDir = char(runDir);
if ~exist(runDir,'dir')
    warning('runDir does not exist: %s', runDir);
    return;
end

% ------------------------------------------------------------
% Build a version-stable info struct (infoLite)
% ------------------------------------------------------------
infoLite = localMakeInfoLite(info);

try
    % --------------------------------------------------------
    % Save stable info + aliases for summarizeRuns
    % --------------------------------------------------------
    obj.runSave(char(prefix + "_trainingInfo.mat"), 'info', infoLite);

    pfx = lower(prefix);
    if contains(pfx,"cnn")
        obj.runSave('CNN_info.mat','info',infoLite);
    elseif contains(pfx,"lstm")
        obj.runSave('LSTM_info.mat','info',infoLite);
    end

    % --------------------------------------------------------
    % Try trainnet-style first (TrainingHistory/ValidationHistory tables)
    % --------------------------------------------------------
    didPlots = false;

    if isstruct(infoLite) && isfield(infoLite,'TrainingHistory') && isfield(infoLite,'ValidationHistory')
        TH = infoLite.TrainingHistory;
        VH = infoLite.ValidationHistory;

        if istable(TH) && istable(VH)
            thVars = TH.Properties.VariableNames;
            vhVars = VH.Properties.VariableNames;

            % ---------- LOSS ----------
            hasTrainLoss = ismember('Loss', thVars) && ~isempty(TH.Loss);
            hasValLoss   = ismember('Loss', vhVars) && ~isempty(VH.Loss);

            if hasTrainLoss || hasValLoss
                h = figure('Visible','off','Color','w'); hold on;
                leg = strings(0,1);

                if hasTrainLoss
                    plot(TH.Iteration, TH.Loss, 'LineWidth',1.5);
                    leg(end+1) = "TrainingLoss";
                end
                if hasValLoss
                    plot(VH.Iteration, VH.Loss, '--', 'LineWidth',1.5);
                    leg(end+1) = "ValidationLoss";
                end

                legend(leg,'Location','best','Interpreter','none');
                xlabel('Iteration'); ylabel('Loss');
                title(prefix + " loss");

                exportgraphics(h, fullfile(runDir, char(prefix + "_loss.png")), 'Resolution',200);
                close(h);
            end

            % ---------- ACCURACY ----------
            accFields = ["Accuracy","Top1Accuracy","ClassificationAccuracy"];
            accName = "";

            for k = 1:numel(accFields)
                if ismember(accFields(k), thVars)
                    accName = accFields(k);
                    break;
                end
            end

            if accName ~= ""
                h = figure('Visible','off','Color','w'); hold on;
                leg = strings(0,1);

                plot(TH.Iteration, TH.(accName), 'LineWidth',1.5);
                leg(end+1) = "Training";

                if ismember(accName, vhVars)
                    plot(VH.Iteration, VH.(accName), '--', 'LineWidth',1.5);
                    leg(end+1) = "Validation";
                end

                legend(leg,'Location','best','Interpreter','none');
                xlabel('Iteration'); ylabel(accName);
                title(prefix + " accuracy");

                exportgraphics(h, fullfile(runDir, char(prefix + "_accuracy.png")), 'Resolution',200);
                close(h);
            end

            % ---------- META ----------
            meta = localExtractMeta(infoLite);
            obj.runSaveStruct(char(prefix + "_meta.mat"), meta);

            didPlots = true;
        end
    end

    % --------------------------------------------------------
    % Fallback: trainNetwork-style vectors (TrainingLoss, etc.)
    % --------------------------------------------------------
    if ~didPlots
        [itT, lossT, itV, lossV, itTA, accT, itVA, accV, meta] = localExtractTrainNetworkStyle(infoLite);

        % LOSS
        if ~isempty(lossT) || ~isempty(lossV)
            h = figure('Visible','off','Color','w'); hold on;
            leg = strings(0,1);
            if ~isempty(lossT)
                plot(itT, lossT, 'LineWidth',1.5);
                leg(end+1) = "TrainingLoss";
            end
            if ~isempty(lossV)
                plot(itV, lossV, '--', 'LineWidth',1.5);
                leg(end+1) = "ValidationLoss";
            end
            legend(leg,'Location','best','Interpreter','none');
            xlabel('Iteration'); ylabel('Loss');
            title(prefix + " loss");
            exportgraphics(h, fullfile(runDir, char(prefix + "_loss.png")), 'Resolution',200);
            close(h);
        end

        % ACCURACY
        if ~isempty(accT) || ~isempty(accV)
            h = figure('Visible','off','Color','w'); hold on;
            leg = strings(0,1);
            if ~isempty(accT)
                plot(itTA, accT, 'LineWidth',1.5);
                leg(end+1) = "Training";
            end
            if ~isempty(accV)
                plot(itVA, accV, '--', 'LineWidth',1.5);
                leg(end+1) = "Validation";
            end
            legend(leg,'Location','best','Interpreter','none');
            xlabel('Iteration'); ylabel('Accuracy');
            title(prefix + " accuracy");
            exportgraphics(h, fullfile(runDir, char(prefix + "_accuracy.png")), 'Resolution',200);
            close(h);
        end

        obj.runSaveStruct(char(prefix + "_meta.mat"), meta);
    end

    obj.runMsg('Saved %s training curves (loss/accuracy) into %s', prefix, runDir);

catch ME
    obj.runMsg('WARN: could not save %s training curves (%s)', prefix, ME.getReport('basic','hyperlinks','off'));
end

end

% =====================================================================
% Helpers
% =====================================================================

function [runActive, runDir] = localGetActiveRunDir(obj)
runActive = false;
runDir = "";

if ~(isprop(obj,'run') && ~isempty(obj.run))
    return;
end

r = obj.run;

try
    if isstruct(r)
        if isfield(r,'active') && islogical(r.active) && isscalar(r.active)
            runActive = r.active;
        end
        if isfield(r,'runDir') && ~isempty(r.runDir)
            runDir = string(r.runDir);
        end

    elseif isobject(r)
        if isprop(r,'active')
            a = r.active;
            if islogical(a) && isscalar(a)
                runActive = a;
            end
        end
        if isprop(r,'runDir')
            rd = r.runDir;
            if ~isempty(rd)
                runDir = string(rd);
            end
        end
    end
catch
    runActive = false;
    runDir = "";
end
end

function infoLite = localMakeInfoLite(info)
% Build a version-stable struct from various training info formats.
% Avoids saving deep.TrainingInfo objects directly.

infoLite = struct();
infoLite.Kind = "";
infoLite.CreatedOn = datetime('now');

% --- trainnet style: deep.TrainingInfo ---
try
    if isa(info,'deep.TrainingInfo')
        infoLite.Kind = "deep.TrainingInfo";
        try, infoLite.TrainingHistory   = info.TrainingHistory;   catch, infoLite.TrainingHistory = table(); end
        try, infoLite.ValidationHistory = info.ValidationHistory; catch, infoLite.ValidationHistory = table(); end
        try, infoLite.OutputNetworkIteration = info.OutputNetworkIteration; catch, end
        try, infoLite.StopReason = string(info.StopReason); catch, infoLite.StopReason = ""; end
        return;
    end
catch
end

% --- trainNetwork style: nnet.cnn.TrainingInfo ---
try
    if isa(info,'nnet.cnn.TrainingInfo')
        infoLite.Kind = "nnet.cnn.TrainingInfo";
        try, infoLite.TrainingLoss       = double(info.TrainingLoss(:));       catch, infoLite.TrainingLoss = []; end
        try, infoLite.ValidationLoss     = double(info.ValidationLoss(:));     catch, infoLite.ValidationLoss = []; end
        try, infoLite.TrainingAccuracy   = double(info.TrainingAccuracy(:));   catch, infoLite.TrainingAccuracy = []; end
        try, infoLite.ValidationAccuracy = double(info.ValidationAccuracy(:)); catch, infoLite.ValidationAccuracy = []; end
        try, infoLite.OutputNetworkIteration = info.OutputNetworkIteration; catch, end
        try, infoLite.StopReason = string(info.StopReason); catch, infoLite.StopReason = ""; end
        return;
    end
catch
end

% --- already struct ---
if isstruct(info)
    infoLite = info;
    if ~isfield(infoLite,'Kind'), infoLite.Kind = "struct"; end
    if isfield(infoLite,'StopReason')
        try, infoLite.StopReason = string(infoLite.StopReason); catch, end
    end
    return;
end

% --- fallback: store just class name ---
try
    infoLite.Kind = "unknown";
    infoLite.SourceClass = string(class(info));
catch
    infoLite.Kind = "unknown";
    infoLite.SourceClass = "";
end
end

function meta = localExtractMeta(infoS)
meta = struct();
if ~isstruct(infoS), return; end

if isfield(infoS,'OutputNetworkIteration')
    meta.OutputNetworkIteration = infoS.OutputNetworkIteration;
end
if isfield(infoS,'StopReason')
    try
        meta.StopReason = string(infoS.StopReason);
    catch
        meta.StopReason = "";
    end
end

% helpful extras if present
if isfield(infoS,'Kind'), meta.Kind = infoS.Kind; end
if isfield(infoS,'SourceClass'), meta.SourceClass = infoS.SourceClass; end
if isfield(infoS,'CreatedOn'), meta.CreatedOn = infoS.CreatedOn; end
end

function [itT, lossT, itV, lossV, itTA, accT, itVA, accV, meta] = localExtractTrainNetworkStyle(info)
% Extract arrays from either:
% - struct with TrainingLoss/ValidationLoss/TrainingAccuracy/ValidationAccuracy
% - (we already converted objects to struct in localMakeInfoLite)

itT=[]; lossT=[]; itV=[]; lossV=[];
itTA=[]; accT=[]; itVA=[]; accV=[];
meta = localExtractMeta(info);

try
    if isstruct(info)
        if isfield(info,'TrainingLoss') && ~isempty(info.TrainingLoss)
            lossT = double(info.TrainingLoss(:))';
            itT   = 1:numel(lossT);
        end
        if isfield(info,'ValidationLoss') && ~isempty(info.ValidationLoss)
            lossV = double(info.ValidationLoss(:))';
            itV   = 1:numel(lossV);
        end
        if isfield(info,'TrainingAccuracy') && ~isempty(info.TrainingAccuracy)
            accT = double(info.TrainingAccuracy(:))';
            itTA = 1:numel(accT);
        end
        if isfield(info,'ValidationAccuracy') && ~isempty(info.ValidationAccuracy)
            accV = double(info.ValidationAccuracy(:))';
            itVA = 1:numel(accV);
        end
    end
catch
end
end
