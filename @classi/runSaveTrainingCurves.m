function runSaveTrainingCurves(obj, info, prefix)
% runSaveTrainingCurves  Centralized saving of training curves (PNG) + raw info (MAT).
%
% - Saves raw info into: <prefix>_trainingInfo.mat
% - ALSO saves alias into: CNN_info.mat or LSTM_info.mat (so summarizeRuns finds it)
% - Saves PNG: <prefix>_loss.png and <prefix>_accuracy.png
% - Saves meta: <prefix>_meta.mat

if nargin < 3 || isempty(prefix)
    prefix = "training";
end
prefix = string(prefix);

% --- public-safe "active run" check (run can be struct or object) ---
runActive = false;
runDir = "";

if isprop(obj,'run') && ~isempty(obj.run)
    r = obj.run;

    try
        if isstruct(r)
            if isfield(r,'active') && r.active
                runActive = true;
            end
            if isfield(r,'runDir') && ~isempty(r.runDir)
                runDir = string(r.runDir);
            end

        elseif isobject(r)
            if isprop(r,'active') && r.active
                runActive = true;
            end
            if isprop(r,'runDir') && ~isempty(r.runDir)
                runDir = string(r.runDir);
            end
        end
    catch
        runActive = false;
        runDir = "";
    end
end

if ~runActive
    fprintf('Job is not active, cannot save...\n');
    return;
end

if strlength(runDir)==0
    warning('runDir is empty; cannot save training curves.');
    return;
end

if ~exist(runDir,'dir')
    warning('runDir does not exist: %s', runDir);
    return;
end

runDir = char(runDir);


runDir = obj.run.runDir;
if ~exist(runDir,'dir')
    warning('runDir does not exist: %s', runDir);
    return;
end



try
    % ---- save raw history ----
    obj.runSave(char(prefix + "_trainingInfo.mat"), 'info', info);

    % ---- alias for summarizeRuns (option 2) ----
    % summarizeRuns expects CNN_info.mat / LSTM_info.mat with variable "info"
    pfx = lower(prefix);
    if contains(pfx,"cnn")
        obj.runSave('CNN_info.mat','info',info);
    elseif contains(pfx,"lstm")
        obj.runSave('LSTM_info.mat','info',info);
    end

    % ---- try "trainnet" style first (TrainingHistory/ValidationHistory) ----
    didPlots = false;

    if isstruct(info) && isfield(info,'TrainingHistory') && isfield(info,'ValidationHistory')
        TH = info.TrainingHistory;
        VH = info.ValidationHistory;

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
            meta = struct();
            if isfield(info,'OutputNetworkIteration'), meta.OutputNetworkIteration = info.OutputNetworkIteration; end
            if isfield(info,'StopReason'),            meta.StopReason             = info.StopReason; end
            obj.runSaveStruct(char(prefix + "_meta.mat"), meta);

            didPlots = true;
        end
    end

    % ---- fallback: "trainNetwork" TrainingInfo object OR struct-like fields ----
    if ~didPlots
        [itT, lossT, itV, lossV, itTA, accT, itVA, accV, meta] = localExtractTrainNetworkStyle(info);

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

% ---------------- helpers ----------------
function [itT, lossT, itV, lossV, itTA, accT, itVA, accV, meta] = localExtractTrainNetworkStyle(info)
% Extract arrays from either TrainingInfo object (trainNetwork) or struct fields.
itT=[]; lossT=[]; itV=[]; lossV=[];
itTA=[]; accT=[]; itVA=[]; accV=[];
meta = struct();

try
    % TrainingInfo object (trainNetwork)
    if isa(info,'nnet.cnn.TrainingInfo')
        nT = numel(info.TrainingLoss);
        if nT>0
            itT   = 1:nT;
            lossT = double(info.TrainingLoss(:))';
        end
        nV = numel(info.ValidationLoss);
        if nV>0
            itV   = 1:nV;
            lossV = double(info.ValidationLoss(:))';
        end

        nTA = numel(info.TrainingAccuracy);
        if nTA>0
            itTA = 1:nTA;
            accT = double(info.TrainingAccuracy(:))';
        end
        nVA = numel(info.ValidationAccuracy);
        if nVA>0
            itVA = 1:nVA;
            accV = double(info.ValidationAccuracy(:))';
        end

        if isprop(info,'OutputNetworkIteration'), meta.OutputNetworkIteration = info.OutputNetworkIteration; end
        if isprop(info,'StopReason'),            meta.StopReason             = info.StopReason; end
        return;
    end
catch
end

% struct fallback
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
        if isfield(info,'OutputNetworkIteration'), meta.OutputNetworkIteration = info.OutputNetworkIteration; end
        if isfield(info,'StopReason'),            meta.StopReason             = info.StopReason; end
    end
catch
end
end
