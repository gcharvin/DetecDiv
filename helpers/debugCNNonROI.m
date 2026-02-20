function [labelsFrame, scoresFrame, vidCNN] = debugCNNOnROI(roiobj, classif, netCNN, frames, useGPU)
% debugCNNOnROI  Teste le CNN sur une seule ROI avec le même préprocessing que l'inférence.
%
%   [labelsFrame, scoresFrame, vidCNN] = debugCNNOnROI(roiobj, classif, netCNN)
%   [labelsFrame, scoresFrame, vidCNN] = debugCNNOnROI(..., frames)
%   [labelsFrame, scoresFrame, vidCNN] = debugCNNOnROI(..., frames, useGPU)
%
% Inputs
%   roiobj  : objet ROI (avec .image, .data, .preProcessROIData, etc.)
%   classif : objet classi (pour channelName, trainingParam, classes, ...)
%   netCNN  : réseau CNN (DAGNetwork / SeriesNetwork)
%   frames  : vecteur de frames à classifier (par défaut 1:T)
%   useGPU  : 0 (CPU), 1 (GPU), par défaut 0
%
% Outputs
%   labelsFrame : labels prédits par frame (categorical)
%   scoresFrame : scores par frame (Nframes x NclassesTarget)
%   vidCNN      : stack d'images réellement passées au CNN (H x W x 3 x T, single)

    if nargin < 4 || isempty(frames)
        if isempty(roiobj.image); roiobj.load; end
        if isempty(roiobj.image)
            error('ROI image is empty, cannot debug CNN.');
        end
        frames = 1:size(roiobj.image,4);
    end
    if nargin < 5 || isempty(useGPU)
        useGPU = 0;
    end

    % Charger l'image si besoin
    if isempty(roiobj.image); roiobj.load; end
    if isempty(roiobj.image)
        error('Could not load ROI image.');
    end

    % --- Classes cibles (ordre de classif.classes) ---
    classesTarget = string(classif.classes(:))';

    % --- Taille d'entrée du CNN ---
    inputSizeCNN = netCNN.Layers(1).InputSize(1:2);
    targetSizeCNN = inputSizeCNN;

    % --- Lire les paramètres de formatage utilisés pour le framebank HDF5 ---
    tp = struct;
    if isprop(classif,'trainingParam') && ~isempty(classif.trainingParam)
        tp = classif.trainingParam;
    end

    % Defaults (si jamais Format_* n'existent pas)
    CropCNN       = false;
    CropCenterCNN = [88 194];
    CropSizeCNN   = [60 60];

    if isfield(tp,'Format_Crop')
        CropCNN = logical(tp.Format_Crop);
    end
    if isfield(tp,'Format_CropCenter') && ~isempty(tp.Format_CropCenter)
        CropCenterCNN = tp.Format_CropCenter;
    end
    if isfield(tp,'Format_CropSize') && ~isempty(tp.Format_CropSize)
        CropSizeCNN = tp.Format_CropSize;
    end

    % --- Construction du stack d'images pour le CNN (comme dans classifyImageLSTMNetFun) ---
    vidCNN = buildCNNVidFromROI_forDebug(roiobj, classif, frames, ...
                                         CropCNN, CropCenterCNN, CropSizeCNN, ...
                                         targetSizeCNN);

    fprintf('debugCNNOnROI: ROI "%s" | frames [%d..%d] (N=%d) | CNN input size = [%d %d 3]\n', ...
        roiobj.id, frames(1), frames(end), numel(frames), ...
        size(vidCNN,1), size(vidCNN,2));

    % --- Inference CNN ---
    env = iff(useGPU==1, "gpu", "cpu");
    try
        [lblC, scC] = classify(netCNN, vidCNN, 'ExecutionEnvironment', env);
    catch ME
        warning('CNN classify failed on %s (%s), retrying on CPU.', upper(string(env)), ME.message);
        [lblC, scC] = classify(netCNN, vidCNN, 'ExecutionEnvironment', 'cpu');
    end

    % Mise en forme des outputs
    labelsNet = string(netCNN.Layers(end).ClassNames);
    scores    = scC;
    if size(scores,1) == numel(labelsNet)
        scores = scores';
    end
    % scores : Nframes x NclassesNet

    % --- Realignement des scores sur classif.classes ---
    [isInC, permC] = ismember(classesTarget, labelsNet);
    if any(~isInC)
        warning('debugCNNOnROI: classes absentes dans le CNN: %s', ...
            strjoin(classesTarget(~isInC), ', '));
    end

    scoresAligned = zeros(size(scores,1), numel(classesTarget), 'like', scores);
    validC = find(isInC);
    scoresAligned(:, validC) = scores(:, permC(validC));

    [~, idxBest] = max(scoresAligned, [], 2);
    labelsFrame  = categorical(classesTarget(idxBest), classesTarget);
    scoresFrame  = scoresAligned;

    % --- Petit résumé console ---
    P = gather(scoresAligned);
    fprintf('Classes (classif.classes): %s\n', strjoin(classesTarget, ', '));
    for i = 1:numel(classesTarget)
        cname = classesTarget(i);
        col   = P(:, i);
        if all(col == 0)
            fprintf('  %s : all scores = 0\n', cname);
        else
            q = quantile(col, [0 0.25 0.5 0.75 0.9 0.95 0.99]);
            fprintf('  %s : q[0 25 50 75 90 95 99] = [%0.3f %0.3f %0.3f %0.3f %0.3f %0.3f %0.3f]\n', ...
                cname, q);
        end
    end

    labCats = categories(labelsFrame);
    cnt     = countcats(labelsFrame);
    fprintf('  Labels CNN (après réalignement) sur cette ROI :\n');
    for k = 1:numel(labCats)
        fprintf('    %s : %d frames\n', string(labCats{k}), cnt(k));
    end
end

% ================== Helpers locaux ==================

function vid = buildCNNVidFromROI_forDebug(roiobj, classif, frames, Crop, CropCenter, CropSize, targetSize)
    % Reprise de la logique de buildCNNVidFromROI (inférence) :
    % - preProcessROIData(pix, j, 1) -> double [0,1], déjà stretchlim + repmat
    % - crop optionnel avec localCrop
    % - resize vers targetSize
    % - sortie en single [0,1], comme H5ImageDatastore

    channel = classif.channelName;
    pix     = roiobj.findChannelID(channel)
    if iscell(pix); pix = cell2mat(pix); end

    T   = numel(frames);
    Ht  = targetSize(1);
    Wt  = targetSize(2);

    vid = zeros(Ht, Wt, 3, T, 'single');

    for k = 1:T
        j   = frames(k);
        tmp = roiobj.preProcessROIData(pix, j, 1);  % double [0,1], dorepmat=1

        if isempty(tmp)
            vid(:,:,:,k) = 0;
            continue;
        end

        if size(tmp,3) == 1
            tmp = repmat(tmp,[1 1 3]);
        end

        if Crop
            tmp = localCrop(tmp, CropCenter, CropSize);
        end

        if size(tmp,1) ~= Ht || size(tmp,2) ~= Wt
            tmp = imresize(tmp, [Ht Wt]);
        end

        vid(:,:,:,k) = single(tmp);
    end
end

function out = localCrop(in, center, cropSz)
    % Copié de formatLSTMTrainingSet pour avoir EXACTEMENT le même crop.
    cx = round(center(1)); cy = round(center(2));
    cw = round(cropSz(1)); ch = round(cropSz(2));
    [H,W,C] = size(in);
    if C==1, in = repmat(in,[1 1 3]); C=3; end

    x1 = cx - floor((cw-1)/2);  x2 = x1 + cw - 1;
    y1 = cy - floor((ch-1)/2);  y2 = y1 + ch - 1;

    padL = max(0, 1 - x1);
    padT = max(0, 1 - y1);
    padR = max(0, x2 - W);
    padB = max(0, y2 - H);

    if any([padL padR padT padB] > 0)
        in = padarray(in, [padT padL], 'replicate', 'pre');
        in = padarray(in, [padB padR], 'replicate', 'post');
    end

    x1p = x1 + padL; x2p = x2 + padL;
    y1p = y1 + padT; y2p = y1 + padT + (ch-1);
    out = in(y1p:y2p, x1p:x2p, :);
end

function v = iff(cond, a, b)
    if cond, v = a; else, v = b; end
end
