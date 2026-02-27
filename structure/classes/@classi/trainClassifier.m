function trainClassifier(classif, setparam)
% trainClassifier  Entry point for classifier training and parameter init.
%
% nargin == 1 : launch actual training
% nargin == 2 : initialize / set training parameters

[trainingFun, usesPkg] = resolveTrainingFun(classif);
setparamFun = resolveSetparamFun(classif);
if isempty(trainingFun)
    error('trainClassifier:NoTrainingFun','No training function available for this classifier.');
end

if nargin == 1
    disp(['Launching training procedure with ' trainingFun]);
    if usesPkg
        disp(['[PKG TRAIN] ' trainingFun]);
    end

    % ============================================================
    % START RUN (TRAINING)
    % ============================================================
    classif.runStop;
    classif.runStart(trainingFun, classif.trainingParam, 'Tag', 'Train');
    classif.runMsg('trainClassifier started (nargin=1)');
    classif.runMsg('Classifier: %s', classif.strid);

    try
        % --- Actual training ---
        if usesPkg || any(strcmpi(trainingFun, {'trainImageLSTMNetFun','cnn_lstm.train'}))
            ctx = struct('mode', 'train');
            try
                ctx = classif.buildCtx('train', ctx);
            catch
            end
            feval(trainingFun, classif, ctx);
        else
            feval(trainingFun, classif);
        end

        classif.runMsg('Training finished successfully');

        try
            classif.runCopyArtifacts();
        catch ME
            classif.runMsg('WARN runCopyArtifacts failed: %s', ME.message);
        end

    catch ME
        % --- Log error with full stack ---
        classif.runMsg('ERROR during training:');
        classif.runMsg('%s', ME.getReport('extended','hyperlinks','off'));

        classif.runStop();
        rethrow(ME);
    end

    % ============================================================
    % STOP RUN
    % ============================================================
    %classif.runStop();

else
    disp(['Setting parameters for ' trainingFun]);

    % ============================================================
    % PARAMETER INITIALIZATION
    % ============================================================
    if ~isempty(setparamFun)
        disp(['[PKG SETPARAM] ' setparamFun]);
        classif = callSetparamCompat(classif, setparamFun);
    elseif usesPkg || any(strcmpi(trainingFun, {'trainImageLSTMNetFun','cnn_lstm.train'}))
        ctx = struct('mode', 'init');
        try
            ctx = classif.buildCtx('train', ctx);
        catch
        end
        feval(trainingFun, classif, ctx);
    else
        feval(trainingFun, classif, setparam);
    end

    % Backward compatibility: ensure transfer_learning exists
    if ~isfield(classif.trainingParam,'transfer_learning')
        [t,~] = classif.version;
        str = t(:,1);
        str = ['ImageNet', str', 'ImageNet'];

        classif.trainingParam.transfer_learning = str;
        classif.trainingParam.tip{end+1} = ...
            'Select version of the classifier to be used';
    end

    % ============================================================
    % LOG PARAMETERIZATION AS A RUN (LIGHTWEIGHT)
    % ============================================================
    classif.runStart(trainingFun, classif.trainingParam, 'Tag', 'InitParam');
    classif.runMsg('Training parameters initialized (nargin=2)');
    classif.runMsg('Saved trainingParam snapshot');

    % Optional but useful for diffing runs
    classif.runSaveStruct('trainingParam.mat', classif.trainingParam);

    classif.runStop();
end
end

function [fun, usesPkg] = resolveTrainingFun(classif)
% Prefer standardized package dispatch if available.
usesPkg = false;
fun = '';

pkg = '';
if isprop(classif,'classifierPkg') && ~isempty(classif.classifierPkg)
    pkg = classif.classifierPkg;
else
    % Backfill from legacy trainingFun (if package-style)
    if isprop(classif,'trainingFun') && ~isempty(classif.trainingFun)
        pkg = localInferPkg(classif.trainingFun);
    end
end

if ~isempty(pkg)
    cand = [pkg '.train'];
    if ~isempty(which(cand))
        fun = cand;
        usesPkg = true;
        return;
    end
end

if isprop(classif,'trainingFun')
    fun = classif.trainingFun;
end
end

function pkg = localInferPkg(funSpec)
pkg = '';
f = funSpec;
if isa(f,'function_handle'), f = func2str(f); end
if isstring(f), f = char(f); end
dot = strfind(f, '.');
if ~isempty(dot)
    pkg = f(1:dot(1)-1);
    return;
end

if any(strcmp(f, {'trainImageLSTMNetFun','classifyImageLSTMNetFun'}))
    pkg = 'cnn_lstm';
elseif any(strcmp(f, {'trainImageGoogleNetFun','classifyImageGoogleNetFun'}))
    pkg = 'cnn';
elseif any(strcmp(f, {'trainCPSAMFun','classifyCPSAMFun'}))
    pkg = 'cellposesam';
end
end

function fun = resolveSetparamFun(classif)
% Prefer standardized package setparam if available.
fun = '';

pkg = '';
if isprop(classif,'classifierPkg') && ~isempty(classif.classifierPkg)
    pkg = classif.classifierPkg;
else
    if isprop(classif,'trainingFun') && ~isempty(classif.trainingFun)
        pkg = localInferPkg(classif.trainingFun);
    end
end

if ~isempty(pkg)
    cand = [pkg '.setparam'];
    if ~isempty(which(cand))
        fun = cand;
        return;
    end
end
end

function classif = callSetparamCompat(classif, setparamFun)
% callSetparamCompat  Support legacy and pkg setparam signatures:
%   - setparam(classif)
%   - setparam() returning trainingParam struct
%   - setparam(classif) returning refs/status struct

called = false;
lastErr = [];
res = [];

% 1) Preferred signature: setparam(classif)
try
    res = feval(setparamFun, classif);
    called = true;
catch ME
    lastErr = ME;
end

% 2) Fallback: setparam()
if ~called
    try
        res = feval(setparamFun);
        called = true;
    catch ME
        lastErr = ME;
    end
end

if ~called
    if isempty(lastErr)
        error('trainClassifier:SetparamCallFailed', ...
            'Could not call setparam function: %s', setparamFun);
    else
        rethrow(lastErr);
    end
end

% Harmonize returned payload if any
if isempty(res) || ~isstruct(res)
    return;
end

% Pure trainingParam struct (e.g. cnn_lstm.setparam)
if isfield(res,'tip') || isfield(res,'ExecutionEnvironment') || isfield(res,'Parallel')
    classif.trainingParam = res;
    return;
end

% Wrapper struct with refs.trainingParam (e.g. cellposesam.setparam)
if isfield(res,'refs') && isstruct(res.refs) && isfield(res.refs,'trainingParam')
    classif.trainingParam = res.refs.trainingParam;
end
end
