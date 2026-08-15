function output = formatDataForTraining(classif, varargin)
% Saves user annotated data to disk - works for Image, Pixel, and LSTM
% classification

output   = [];
Frames   = [];
Keep     = 0;     % 0: purge le dossier cible | 1: garde le contenu
rois     = [];
Fraction = 1;     % fraction des ROIs à échantillonner (LSTM)
Seed     = 12345; % seed déterministe (LSTM)

% NEW: collecter les arguments qu'on ne traite pas nous-mêmes
extraArgs = {};


% ---- Parse varargin de façon robuste (accepte flags ou paires) ----
i = 1;
while i <= numel(varargin)
    arg = varargin{i};
    if ischar(arg) || isstring(arg)
        key = lower(string(arg));
        switch key
            case "frames"
                if i+1 <= numel(varargin), Frames = varargin{i+1}; end
                i = i + 2;
                continue

            case "rois"
                if i+1 <= numel(varargin), rois = varargin{i+1}; end
                i = i + 2;
                continue

            case "keep"
                % accepte 'Keep' seul (=> true) OU 'Keep',value
                if i+1 <= numel(varargin) && ~(ischar(varargin{i+1}) || isstring(varargin{i+1}))
                    Keep = logical(varargin{i+1});
                    i = i + 2;
                    continue
                else
                    Keep = 1;
                    i = i + 1;
                    continue
                end

            case "fraction"
                if i+1 <= numel(varargin), Fraction = varargin{i+1}; end
                i = i + 2;
                continue

            case "seed"
                if i+1 <= numel(varargin), Seed = varargin{i+1}; end
                i = i + 2;
                continue

            otherwise
                % NEW: ne plus jeter, mais forwarder vers le formatter
                if i+1 <= numel(varargin) && ~(ischar(varargin{i+1}) || isstring(varargin{i+1}))
                    % Name-Value pair inconnu => on le stocke
                    extraArgs = [extraArgs, {arg, varargin{i+1}}];
                    i = i + 2;
                else
                    % Flag seul => on le forwarde aussi
                    extraArgs = [extraArgs, {arg}];
                    i = i + 1;
                end
                continue
        end
    else
        i = i + 1; % ignorer tokens non-string
    end
end

% ---- Validation soft des nouveaux paramètres (LSTM) ----
if ~(isnumeric(Fraction) && isscalar(Fraction) && ~isnan(Fraction))
    Fraction = 1;
end
Fraction = max(0, min(1, Fraction));

if ~(isnumeric(Seed) && isscalar(Seed) && isfinite(Seed))
    Seed = 12345;
else
    Seed = floor(Seed);
end

% ---- Répertoires ----
category   = classif.category;  category = category{1};
foldername = 'trainingdataset';


% ---- ROIs d'entraînement / validation ----
if numel(rois) == 0
    try
        rois = classif.getTrainingROIIndices();
    catch
        rois = classif.trainingset;
    end
end
rois = normalizeRoiListLocal(rois, numel(classif.roi));
testrois = [];
valrois = [];
hasExplicitVal = false;
try
    if isprop(classif, 'dataset') && isstruct(classif.dataset) && ...
            isfield(classif.dataset, 'split') && isstruct(classif.dataset.split)
        if isfield(classif.dataset.split, 'test')
            testrois = normalizeRoiListLocal(classif.dataset.split.test, numel(classif.roi));
        end
        if isfield(classif.dataset.split, 'val') && ~isempty(classif.dataset.split.val)
            valrois = normalizeRoiListLocal(classif.dataset.split.val, numel(classif.roi));
            hasExplicitVal = true;
        end
    end
catch
    testrois = [];
    valrois = [];
    hasExplicitVal = false;
end
if ~hasExplicitVal
    valrois = setdiff(1:numel(classif.roi), rois, 'stable');
end
if ~isempty(testrois)
    beforeTrain = rois;
    beforeVal = valrois;
    rois = setdiff(rois, testrois, 'stable');
    valrois = setdiff(valrois, testrois, 'stable');
    if numel(beforeTrain) ~= numel(rois) || numel(beforeVal) ~= numel(valrois)
        warning('classi:TestRoisExcludedFromTrainingExport', ...
            'FormatDataForTraining excluded test ROI(s) from training/validation export: %s', ...
            strjoin(cellstr(string(testrois)), ', '));
    end
end




% ---- Unified ctx build (passed to formatters) ----
ctx = struct();
ctx.sel = struct();
if ~isempty(Frames)
    ctx.sel.frames = Frames;
end
ctx.params = struct();
ctx.params.foldername = foldername;
ctx.params.Fraction = Fraction;
ctx.params.Seed = Seed;

% Forward all extraArgs into ctx.params (name/value or flags)
if ~isempty(extraArgs)
    k = 1;
    while k <= numel(extraArgs)
        key = extraArgs{k};
        if ischar(key) || isstring(key)
            if (k+1) <= numel(extraArgs) && ~(ischar(extraArgs{k+1}) || isstring(extraArgs{k+1}))
                ctx.params.(matlab.lang.makeValidName(char(key))) = extraArgs{k+1};
                k = k + 2;
            else
                ctx.params.(matlab.lang.makeValidName(char(key))) = true;
                k = k + 1;
            end
        else
            k = k + 1;
        end
    end
end

% Merge persisted run profile (format) with explicit overrides
try
    ctx = classif.buildCtx('format', ctx);
catch
end

% Apply the classifier's per-ROI training bounds after merging the run
% profile.  A missing bound deliberately means "all" and therefore leaves
% the caller's frame selector unchanged.
requestedFrames = Frames;
try
    if isfield(ctx, 'sel') && isfield(ctx.sel, 'frames')
        requestedFrames = ctx.sel.frames;
    end
catch
end
boundedFrames = trainingBounds.selectionSpec(classif, requestedFrames);
ctx.sel.frames = boundedFrames;
Frames = boundedFrames;

% ---- Prefer standardized package formatter when available ----
pkg = '';
if isprop(classif, 'classifierPkg') && ~isempty(classif.classifierPkg)
    pkg = classif.classifierPkg;
else
    % Backfill from legacy fun names if present
    try
        if isprop(classif,'trainingFun') && ~isempty(classif.trainingFun)
            pkg = localInferPkg(classif.trainingFun);
        elseif isprop(classif,'classifyFun') && ~isempty(classif.classifyFun)
            pkg = localInferPkg(classif.classifyFun);
        end
    catch
    end
end

    if ~isempty(pkg)
        fmtFun = [pkg '.format'];
        if ~isempty(which(fmtFun))
            preflightFun = [pkg '.preflightFormat'];
            if ~isempty(which(preflightFun))
                feval(preflightFun, classif, rois, ctx);
            end
            if Keep == 0
                resetTrainingDatasetLocal(classif.path, foldername);
            end
            disp(['[PKG FORMAT] ' fmtFun]);
            output = feval(fmtFun, classif, rois, ctx);
            return;
        end
    end

% ---- Legacy fallback by category (kept for other classifiers) ----
if Keep == 0
    resetTrainingDatasetLocal(classif.path, foldername);
end
switch category
    case {'Image', 'Image Regression'}
        % (pour l'instant je ne forwarde pas extraArgs aux formats Image,
        %  mais on peut le faire si tu veux y brancher le crop, etc.)
        output = formatImageTrainingSet(foldername, classif, rois, 'Frames', Frames);

    case 'LSTM'

        output = cnn_lstm.format(classif, rois, ctx);

    case 'Pixel'
        if isprop(classif, 'description')
            if (iscell(classif.description{1}) && strcmp(classif.description{1}{1}, 'YOLO instance segmentation')) || ...
                    (ischar(classif.description{1}) && strcmp(classif.description{1},     'YOLO instance segmentation'))
                output = formatPixelTrainingSetYOLO(foldername, classif, rois, valrois, 'Frames', Frames);

            elseif (iscell(classif.description{1}) && strcmp(classif.description{1}{1}, 'CellposeSAM')) || ...
                    (ischar(classif.description{1}) && strcmp(classif.description{1},     'CellposeSAM'))
                output = formatPixelTrainingSetCPSAM(foldername, classif, rois, valrois, 'Frames', Frames);

            elseif (iscell(classif.description{1}) && strcmp(classif.description{1}{1}, 'Cell-TRACKTR')) || ...
                    (ischar(classif.description{1}) && strcmp(classif.description{1},     'Cell-TRACKTR'))
                output = formatPixelTrainingSetCellTracktr(foldername, classif, rois, valrois, 'Frames', Frames);

            else
                output = formatPixelTrainingSet(foldername, classif, rois, 'Frames', Frames);
            end
        else
            output = formatPixelTrainingSet(foldername, classif, rois, 'Frames', Frames);
        end

    case 'Object'
        output = formatObjectTrainingSet(foldername, classif, rois, 'Frames', Frames);

    case 'Pedigree'
        output = formatDeltaPedigreeTrainingSet(foldername, classif, rois, ...
            'Frames', Frames);

    case 'Tracking'
        output = formatTrackingTrainingSet(foldername, classif, rois, ...
            'Frames', Frames);

    case 'Timeseries'
        output = formatTimeseriesTrainingSet(foldername, classif, rois, ...
            'Frames', Frames);

    case 'Delta'
        if ~isempty(Frames)
            output = formatDeltaTrainingSet(foldername, classif, rois, 'Frames', Frames);
        else
            output = formatDeltaTrainingSet(foldername, classif, rois);
        end

    otherwise
        disp('Unknown category. No action taken.');
end

    function pkg = localInferPkg(funSpec)
        pkg = '';
        f = funSpec;
        if isa(f,'function_handle')
            f = func2str(f);
        end
        if isstring(f), f = char(f); end
        dot = strfind(f, '.');
        if ~isempty(dot)
            pkg = f(1:dot(1)-1);
        end
    end

    function roisOut = normalizeRoiListLocal(roisIn, nRois)
        if isempty(roisIn)
            roisOut = [];
            return;
        end
        roisOut = unique(round(double(roisIn(:)')), 'stable');
        roisOut = roisOut(isfinite(roisOut) & roisOut >= 1 & roisOut <= nRois);
    end

    function resetTrainingDatasetLocal(classifierPath, name)
        target = fullfile(classifierPath, name);
        disp(['Removing previous labeled datasets from folders... ' ...
            'This can take a very long time...']);
        if isfolder(target)
            try
                rmdir(target, 's');
            catch ME
                error('classi:TrainingDatasetResetFailed', ...
                    'Could not replace formatted dataset "%s": %s', ...
                    target, ME.message);
            end
        end
        mkdir(classifierPath, name);
    end
end
