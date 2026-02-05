function out = format(classif, rois, ctx)
% cellposesam.format  Build a Cellpose/CellposeSAM training set framebank.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end

out = cellposesam.utils.outInitSafe('cellposesam.format');

if nargin < 2 || isempty(rois)
    try
        if isprop(classif,'dataset') && isstruct(classif.dataset) && ...
                isfield(classif.dataset,'split') && isfield(classif.dataset.split,'train') && ...
                ~isempty(classif.dataset.split.train)
            rois = classif.dataset.split.train;
        else
            rois = classif.trainingset;
        end
    catch
        rois = classif.trainingset;
    end
end

foldername = 'trainingdataset';
if isfield(ctx,'params') && isstruct(ctx.params) && isfield(ctx.params,'foldername')
    foldername = ctx.params.foldername;
end

output = formatPixelTrainingSetCPSAMInternal(foldername, classif, rois, []);

out.status = "OK";
if isnumeric(output)
    out.metrics.outputCount = output;
end
end
function output = formatPixelTrainingSetCPSAMInternal(foldername, classif, trainrois, valrois)
% formatPixelTrainingSetCPSAM  Build a Cellpose/CellposeSAM training set
% stocké dans un framebank HDF5 au lieu d'images individuelles.
%
% HDF5 structure (dans classif.path/<strid>_framebank*.h5) :
%   /images      : uint8  [H W C N]   (C = 1 ou 3, N = nb de frames gardées)
%   /masks       : uint16 [H W N]     (0 = background, 1..K = ID instances)
%   /split       : uint8  [N 1]
%                  0 = test (hold-out, jamais utilisé pour le training)
%                  1 = train
%                  2 = val (validation interne pour CellposeSAM)
%   /roi_id      : int32  [N 1]       (ID de ROI dans classif.roi)
%   /frame_idx   : int32  [N 1]       (index de frame dans la ROI)
%
% Parameters
%   foldername : ignoré (compatibilité)
%   classif    : classification project object
%   trainrois  : indices de ROI pour split train
%   valrois    : ignoré ici (on ne met que les trainROIs dans le framebank)
%
% Returns
%   output     : nombre de frames exportées (N)

output = 0;
warning('off','all');  %#ok<WNOFF>

% -------------------------------------------------------------------------
% 1) Chemin de base du framebank (pourra être modifié plus bas)
% -------------------------------------------------------------------------

base = classif.path;  % dossier de la classif
fnameBase    = sprintf('%s_framebank.h5', classif.strid);
framebankPath = fullfile(base, fnameBase);  % pourra devenir *_framebank_001.h5, etc.

% -------------------------------------------------------------------------
% 2) Seuils depuis classif.trainingParam (optionnel)
% -------------------------------------------------------------------------

min_train_masks  = 1;
min_train_pixels = 0;

tp = [];
try
    if (isprop(classif, 'trainingParam') || isfield(classif, 'trainingParam')) ...
            && ~isempty(classif.trainingParam)
        tp = classif.trainingParam;
        if isfield(tp, 'min_train_masks')  && ~isempty(tp.min_train_masks)
            min_train_masks = tp.min_train_masks;
        end
        if isfield(tp, 'min_train_pixels') && ~isempty(tp.min_train_pixels)
            min_train_pixels = tp.min_train_pixels;
        end
    end
catch
end

fprintf('Using thresholds: min_train_masks = %d, min_train_pixels = %d\n', ...
    min_train_masks, min_train_pixels);

% -------------------------------------------------------------------------
% Paramètres de training / formatage (MaxTrainImages, Seed, NegDownsampleTrainRatio)
% -------------------------------------------------------------------------
MaxTrainImages          = 0;   % 0 = pas de limite (utilise toutes les frames)
Seed                    = [];
NegDownsampleTrainRatio = 0;   % 0 = pas de downsampling spécifique des négatifs
ValFraction             = 0;   % fraction interne val pour CPSAM

try
    if ~isempty(tp)
        if isfield(tp, 'MaxTrainImages') && ~isempty(tp.MaxTrainImages)
            MaxTrainImages = tp.MaxTrainImages;
            if isempty(MaxTrainImages) || MaxTrainImages <= 0
                MaxTrainImages = 0;  % normalisation
            end
        end
        if isfield(tp, 'Seed') && ~isempty(tp.Seed)
            Seed = tp.Seed;
        end
        if isfield(tp, 'NegDownsampleTrainRatio') && ~isempty(tp.NegDownsampleTrainRatio)
            NegDownsampleTrainRatio = tp.NegDownsampleTrainRatio;
            if isempty(NegDownsampleTrainRatio) || NegDownsampleTrainRatio <= 0
                NegDownsampleTrainRatio = 0;
            end
        end
        if isfield(tp,'CPSAM_ValFraction') && ~isempty(tp.CPSAM_ValFraction)
            ValFraction = tp.CPSAM_ValFraction;
        end

        % On va interpréter CPSAM_ValFraction comme fraction de VAL **et** de TEST
% Exemple : CPSAM_ValFraction = 0.2  ->  60% train, 20% val, 20% test
if isempty(ValFraction)
    ValFraction = 0;
end
% On évite d'avoir 2*ValFraction >= 1
if ValFraction < 0
    ValFraction = 0;
elseif ValFraction >= 0.5
    warning('CPSAM_ValFraction=%.3f >= 0.5, clamp to 0.25 (train≈50%%, val≈25%%, test≈25%%).', ValFraction);
    ValFraction = 0.25;
end


    end
catch
end

if MaxTrainImages > 0
    fprintf('MaxTrainImages set to %d (frames will be randomly subsampled if more are available).\n', MaxTrainImages);
else
    fprintf('MaxTrainImages not set or <= 0: using all available frames.\n');
end

% -------------------------------------------------------------------------
% 3) Paramètres généraux
% -------------------------------------------------------------------------

channel = classif.channelName;
cltmp   = classif.roi;

% On ne prend QUE les trainROIs dans le framebank (le "val" Python
% sera géré en interne via ValFraction, uniquement parmi ces frames).
all_rois = trainrois(:).';

fprintf('Scanning ROIs to build frame index...\n');

idx_roi   = [];
idx_frame = [];
idx_split = [];   % 1 = train (CPSAM split sera géré plus tard)
H = [];
W = [];
C = 0;
excludedCount = 0;
hasMaskVec = false(0,1);   % logical vide

% -------------------------------------------------------------------------
% 4) 1ère passe : H, W, C, frames gardées
% -------------------------------------------------------------------------

for ii = 1:numel(all_rois)
    roi_id = all_rois(ii);
    fprintf('  [scan] ROI %d...\n', roi_id);

    cltmp(roi_id).load;
    im = cltmp(roi_id).image;  % H x W x C x T

    pix = cltmp(roi_id).findChannelID(channel);
    if iscell(pix), pix = cell2mat(pix); end
    if isempty(pix)
        warning('No channel found for "%s" in ROI %d, skipping.', channel, roi_id);
        cltmp(roi_id).clear;
        continue;
    end

    T    = size(im, 4);
    Hloc = size(im, 1);
    Wloc = size(im, 2);

    if isempty(H)
        H = Hloc; W = Wloc;
    else
        if Hloc ~= H || Wloc ~= W
            error('formatPixelTrainingSetCPSAM:SizeMismatch', ...
                'ROI %d has different size (%dx%d) than previous (%dx%d).', ...
                roi_id, Hloc, Wloc, H, W);
        end
    end

    splitFlag = uint8(1);   % tout ce qu'on met dans le framebank = "train" (au sens global)

    % Nom ROI pour log
    roiName = '';
    try
        if isprop(cltmp(roi_id), 'id')
            roiName = cltmp(roi_id).id;
        elseif isfield(cltmp(roi_id), 'id')
            roiName = cltmp(roi_id).id;
        end
    catch
        roiName = '';
    end
    if isempty(roiName)
        roiName = sprintf('ROI_%d', roi_id);
    end

    for jj = 1:T
        instMask    = zeros(H, W, 'uint16');
        instCounter = uint16(0);

        for kk = 1:numel(classif.classes)
            chName = [classif.strid '_' classif.classes{kk}];
            cc     = cltmp(roi_id).findChannelID(chName);
            if isempty(cc), continue; end

            lab   = cltmp(roi_id).image(:, :, cc, jj);
            lab   = uint32(lab);
            maxId = max(lab(:));
            if maxId < 1, continue; end

            for id = 1:maxId
                pixz = (lab == id);
                if any(pixz(:))
                    instCounter = instCounter + 1;
                    writeIdx    = pixz & instMask == 0;
                    instMask(writeIdx) = instCounter;
                end
            end
        end

        n_masks  = double(max(instMask(:)));
        n_pixels = nnz(instMask);

        if n_masks < min_train_masks || n_pixels < min_train_pixels
            excludedCount = excludedCount + 1;
            fprintf('  [exclude] %s (id=%d), frame %d: masks=%d, pixels=%d\n', ...
                roiName, roi_id, jj, n_masks, n_pixels);
            continue;
        end

        if numel(pix) >= 3
            Cframe = 3;
        else
            Cframe = 1;
        end
        C = max(C, Cframe);

        idx_roi(end+1,1)    = int32(roi_id);    %#ok<AGROW>
        idx_frame(end+1,1)  = int32(jj);        %#ok<AGROW>
        idx_split(end+1,1)  = splitFlag;        %#ok<AGROW>
        hasMaskVec(end+1,1) = (n_masks > 0);    %#ok<AGROW>  % true = positif (au moins un masque)
    end

    cltmp(roi_id).clear;
end

fprintf('Excluded %d frames not satisfying criteria (min_train_masks=%d, min_train_pixels=%d).\n', ...
    excludedCount, min_train_masks, min_train_pixels);

% -------------------------------------------------------------------------
% 4a) Sous-échantillonnage des frames négatives (train uniquement, ici tout est train)
% -------------------------------------------------------------------------

Ntotal = numel(idx_roi);

if Ntotal == 0
    warning('formatPixelTrainingSetCPSAM:Empty', ...
        'No frames with instances found after filtering. Nothing written.');
    warning('on','all');
    return;
end

if NegDownsampleTrainRatio > 0
    if numel(hasMaskVec) ~= Ntotal
        warning('Inconsistent hasMaskVec size (%d) vs Ntotal (%d). Skipping negative downsampling.', ...
            numel(hasMaskVec), Ntotal);
    else
        posIdx = find(hasMaskVec);      % frames avec au moins un masque
        negIdx = find(~hasMaskVec);     % frames sans masque

        nPos = numel(posIdx);
        nNeg = numel(negIdx);

        if nPos == 0
            fprintf('[NegDownsample] No positive frames found (nPos=0). Negative downsampling is skipped.\n');
        elseif nNeg == 0
            fprintf('[NegDownsample] No negative frames, nothing to downsample.\n');
        else
            maxNegTrain = min(nNeg, floor(NegDownsampleTrainRatio * nPos));

            if maxNegTrain < nNeg
                if ~isempty(Seed) && isnumeric(Seed) && isscalar(Seed)
                    rng(Seed);
                end
                permNeg      = randperm(nNeg, maxNegTrain);
                keepNegIdx   = negIdx(permNeg);
            else
                keepNegIdx   = negIdx;
            end

            keepPosIdx = posIdx;                  % on garde tous les positifs
            idxKeep    = [keepPosIdx; keepNegIdx];
            idxKeep    = idxKeep(randperm(numel(idxKeep)));

            % Filtrer tous les vecteurs
            idx_roi    = idx_roi(idxKeep);
            idx_frame  = idx_frame(idxKeep);
            idx_split  = idx_split(idxKeep);      % restera tout à 1
            hasMaskVec = hasMaskVec(idxKeep);

            Ntotal = numel(idx_roi);

            fprintf(['Negative downsampling: kept %d positive and %d negative frames ' ...
                     '(requested ratio <= %.2f, effective ratio = %.2f).\n'], ...
                    numel(keepPosIdx), numel(keepNegIdx), ...
                    NegDownsampleTrainRatio, ...
                    numel(keepNegIdx)/max(1,numel(keepPosIdx)));
        end
    end
end

fprintf('DEBUG: after NegDownsample, train=%d (pos=%d, neg=%d), val=%d.\n', ...
    sum(idx_split==1), ...
    sum(idx_split==1 & hasMaskVec), ...
    sum(idx_split==1 & ~hasMaskVec), ...
    sum(idx_split==2));


% -------------------------------------------------------------------------
% 4b) Sous-échantillonnage global en fonction de MaxTrainImages
%     (ratio final contrôlé par NegDownsampleTrainRatio si >0)
% -------------------------------------------------------------------------

if MaxTrainImages > 0 && MaxTrainImages < Ntotal
    if ~isempty(Seed) && isnumeric(Seed) && isscalar(Seed)
        rng(Seed);
    end

    posAll = find(hasMaskVec);
    negAll = find(~hasMaskVec);

    nPosAll = numel(posAll);
    nNegAll = numel(negAll);

    if nPosAll == 0
        warning('No positive frames at all, cannot balance dataset. Random subsampling only.');
        idxKeep = randperm(Ntotal, MaxTrainImages);

    else
        if NegDownsampleTrainRatio > 0
            % --- Mode "contrôle du ratio" ---
            R = NegDownsampleTrainRatio;   % ratio neg/pos souhaité au max
            % fraction théorique de positifs = 1 / (1+R)
            fracPos = 1 / (1 + R);
        else
            % --- Mode "pas de rebalance global" ---
            % On garde le ratio tel qu'il est dans le pool courant
            fracPos = nPosAll / max(1, (nPosAll + nNegAll));
        end

        % nombre cible de positifs dans le framebank final
        targetPos = min(nPosAll, max(1, round(MaxTrainImages * fracPos)));
        targetNeg = MaxTrainImages - targetPos;

        % on ne peut pas dépasser les négatifs disponibles
        targetNeg = min(nNegAll, max(0, targetNeg));

        % si on n'atteint pas MaxTrainImages, on complète au mieux
        if targetPos + targetNeg < MaxTrainImages
            deficit  = MaxTrainImages - (targetPos + targetNeg);
            % essayer de compléter d'abord avec des positifs, puis négatifs
            extraPos = min(deficit, nPosAll - targetPos);
            targetPos = targetPos + extraPos;
            deficit   = MaxTrainImages - (targetPos + targetNeg);
            extraNeg  = min(deficit, nNegAll - targetNeg);
            targetNeg = targetNeg + extraNeg;
        end

        % tirage aléatoire
        permPos = randperm(nPosAll, targetPos);
        permNeg = randperm(nNegAll, targetNeg);

        idxKeep = [posAll(permPos); negAll(permNeg)];
        idxKeep = idxKeep(randperm(numel(idxKeep)));  % mélange
    end

    % appliquer
    idx_roi    = idx_roi(idxKeep);
    idx_frame  = idx_frame(idxKeep);
    idx_split  = idx_split(idxKeep);      % tout = 1 (train)
    hasMaskVec = hasMaskVec(idxKeep);

    N = numel(idx_roi);

    nPosFinal = sum(hasMaskVec);
    nNegFinal = sum(~hasMaskVec);

    fprintf(['GLOBAL subsampling %d/%d (MaxTrainImages) -> ' ...
             '%d frames total, %d pos, %d neg (%.1f%%%% pos, ratio neg/pos=%.2f)\n'], ...
            N, Ntotal, N, nPosFinal, nNegFinal, ...
            100*nPosFinal/max(1,N), nNegFinal/max(1,nPosFinal));
else
    if MaxTrainImages > 0 && MaxTrainImages >= Ntotal
        fprintf('MaxTrainImages (%d) >= available frames (%d): using all frames.\n', ...
            MaxTrainImages, Ntotal);
    end
    N = Ntotal;
end


% -------------------------------------------------------------------------
% 4c) Split global train / val / test (pour CellposeSAM)
%     /split :
%       0 = test (hold-out, jamais utilisé pour le training)
%       1 = train
%       2 = val
%
%     On utilise CPSAM_ValFraction comme fraction de VAL et de TEST :
%       f_val   = ValFraction
%       f_test  = ValFraction
%       f_train = 1 - 2*ValFraction
% -------------------------------------------------------------------------

idx_split = uint8(zeros(N,1));  % initialement tout en "test" (0)

if ValFraction <= 0
    % Pas de val/test : tout en train
    idx_split(:) = uint8(1);
    nTrain = N;
    nVal   = 0;
    nTest  = 0;
else
    % Fractions théoriques
    f_val   = ValFraction;
    f_test  = ValFraction;
    f_train = 1 - 2*ValFraction;   % ex : 0.6 pour ValFraction=0.2

    if f_train <= 0
        % Sécurité (ne devrait pas arriver car clampé plus haut)
        warning('Computed f_train=%.3f <= 0, using fallback fractions 0.6/0.2/0.2.', f_train);
        f_train = 0.6;
        f_val   = 0.2;
        f_test  = 0.2;
    end

    % Nombres de frames par split (arrondis)
    nVal   = round(f_val   * N);
    nTest  = round(f_test  * N);
    nTrain = N - nVal - nTest;

    % Corrige au cas où les arrondis seraient trop agressifs
    if nTrain < 1
        nTrain = 1;
        remaining = N - nTrain;
        nVal   = floor(remaining/2);
        nTest  = remaining - nVal;
    elseif nVal < 0
        nVal = 0;
        nTest = N - nTrain;
    elseif nTest < 0
        nTest = 0;
        nVal = N - nTrain;
    end

    if nTrain + nVal + nTest ~= N
        % Sécurité finale si un off-by-one traîne
        diffN = N - (nTrain + nVal + nTest);
        nTrain = nTrain + diffN;
    end

    % Tirage aléatoire reproductible pour répartir les indices
    if ~isempty(Seed) && isnumeric(Seed) && isscalar(Seed)
        rng(Seed);
    end
    perm = randperm(N);

    trainIdx = perm(1:nTrain);
    valIdx   = perm(nTrain+1 : nTrain+nVal);
    testIdx  = perm(nTrain+nVal+1 : nTrain+nVal+nTest);

    idx_split(trainIdx) = uint8(1);  % train
    idx_split(valIdx)   = uint8(2);  % val
    idx_split(testIdx)  = uint8(0);  % test
end

nTrain = sum(idx_split == 1);
nVal   = sum(idx_split == 2);
nTest  = sum(idx_split == 0);

fprintf('Global split: %d train, %d val, %d test frames (ValFraction=%.3f -> f_train≈%.3f, f_val≈%.3f, f_test≈%.3f).\n', ...
    nTrain, nVal, nTest, ValFraction, ...
    nTrain/max(1,N), nVal/max(1,N), nTest/max(1,N));

output = N;
fprintf('Final selection: %d frames -> %d train, %d val, %d test (H=%d, W=%d, C=%d).\n', ...
    N, nTrain, nVal, nTest, H, W, C);

% -------------------------------------------------------------------------
% 5) Choix robuste du chemin HDF5 + création des datasets
% -------------------------------------------------------------------------

% Choisir un chemin de framebank "sain":
% - si <strid>_framebank.h5 existe et est supprimable -> on le réutilise
% - s'il est vérolé/verrouillé -> on essaie <strid>_framebank_001.h5, etc.
framebankPath = chooseFramebankPath(framebankPath);

fprintf('Creating framebank HDF5: %s\n', framebankPath);

h5create(framebankPath, '/images',    [H, W, C, N], 'Datatype', 'uint8');
h5create(framebankPath, '/masks',     [H, W,    N], 'Datatype', 'uint16');
h5create(framebankPath, '/split',     [N, 1],       'Datatype', 'uint8');
h5create(framebankPath, '/roi_id',    [N, 1],       'Datatype', 'int32');
h5create(framebankPath, '/frame_idx', [N, 1],       'Datatype', 'int32');

h5write(framebankPath, '/split',     idx_split, [1 1], [N 1]);
h5write(framebankPath, '/roi_id',    idx_roi,   [1 1], [N 1]);
h5write(framebankPath, '/frame_idx', idx_frame, [1 1], [N 1]);

% -------------------------------------------------------------------------
% 6) 2e passe : écriture images / masks
% -------------------------------------------------------------------------

fprintf('Filling framebank with image/mask data...\n');

k     = 0;
cltmp = classif.roi;

for ii = 1:numel(all_rois)
    roi_id = all_rois(ii);
    fprintf('  [write] ROI %d...\n', roi_id);

    cltmp(roi_id).load;
    im  = cltmp(roi_id).image;
    pix = cltmp(roi_id).findChannelID(channel);
    if iscell(pix), pix = cell2mat(pix); end
    if isempty(pix)
        cltmp(roi_id).clear;
        continue;
    end

    T = size(im, 4);

    % Ne garder que les frames sélectionnés pour CE ROI
    mask_roi       = (idx_roi == int32(roi_id));
    frames_for_roi = idx_frame(mask_roi);

    % Si aucun frame de ce ROI n'a été retenu après le sous-échantillonnage,
    % on passe simplement au suivant.
    if isempty(frames_for_roi)
        cltmp(roi_id).clear;
        continue;
    end

    for jj = 1:T
        % Ne traiter que les frames explicitement retenus à la 1ère passe
        if ~ismember(jj, frames_for_roi)
            continue;
        end

        instMask    = zeros(H, W, 'uint16');
        instCounter = uint16(0);

        for kk = 1:numel(classif.classes)
            chName = [classif.strid '_' classif.classes{kk}];
            cc     = cltmp(roi_id).findChannelID(chName);
            if isempty(cc), continue; end

            lab   = cltmp(roi_id).image(:, :, cc, jj);
            lab   = uint32(lab);
            maxId = max(lab(:));
            if maxId < 1, continue; end

            for id = 1:maxId
                pixz = (lab == id);
                if any(pixz(:))
                    instCounter = instCounter + 1;
                    writeIdx    = pixz & instMask == 0;
                    instMask(writeIdx) = instCounter;
                end
            end
        end

        % --- gestion des frames sans masque ---
        if max(instMask(:)) == 0
            if min_train_masks > 0
                % On *rejette* ces frames seulement si min_train_masks > 0
                warning('[warn] ROI %d frame %d had empty instMask in 2nd pass, skipping', roi_id, jj);
                continue;
            else
                % min_train_masks == 0 : on garde les frames totalement négatifs
                % (instMask tout à 0 = fond)
            end
        end

        % ---- image locale ----
        if numel(pix) >= 3
            useCh  = pix(1:3); %#ok<NASGU>
            imgLoc = im(:, :, useCh, jj);
            tmpC   = size(imgLoc,3);
            for c = 1:tmpC
                ch = imgLoc(:, :, c);
                if ~isa(ch, 'uint8')
                    ch = uint8(255 * mat2gray(ch));
                end
                imgLoc(:, :, c) = ch;
            end
        else
            useCh = pix(1); %#ok<NASGU>
            ch    = im(:, :, useCh, jj);
            if ~isa(ch, 'uint8')
                imgLoc = uint8(255 * mat2gray(ch));
            else
                imgLoc = ch;
            end
            imgLoc = reshape(imgLoc, H, W, 1);
        end

        % ---- imgWrite EXACTEMENT [H W C] ----
        imgWrite = zeros(H, W, C, 'uint8');

        if size(imgLoc,1) ~= H || size(imgLoc,2) ~= W
            error('Unexpected local image size [%d %d], expected [%d %d].', ...
                size(imgLoc,1), size(imgLoc,2), H, W);
        end

        if size(imgLoc,3) == C
            imgWrite = imgLoc;
        elseif C == 3 && size(imgLoc,3) == 1
            imgWrite(:,:,1) = imgLoc(:,:,1);
            imgWrite(:,:,2) = imgLoc(:,:,1);
            imgWrite(:,:,3) = imgLoc(:,:,1);
        elseif C == 1 && size(imgLoc,3) == 3
            imgWrite(:,:,1) = imgLoc(:,:,1); % on prend le 1er canal
        else
            error('Inconsistent channel configuration: imgLoc has %d channels, C=%d.', ...
                size(imgLoc,3), C);
        end

        if ~isa(instMask, 'uint16')
            instMask = uint16(instMask);
        end

        k = k + 1;
        if k > N
            error('formatPixelTrainingSetCPSAM:IndexOverflow', ...
                'Internal indexing bug (k > N).');
        end

        if k == 1
            fprintf('[DEBUG] First imgWrite size: [%d %d %d], H=%d, W=%d, C=%d\n', ...
                size(imgWrite,1), size(imgWrite,2), size(imgWrite,3), H, W, C);
        end

        % /images : [H W C N]
        h5write(framebankPath, '/images', imgWrite, [1 1 1 k], [H W C 1]);
        % /masks : [H W N]
        h5write(framebankPath, '/masks',  instMask, [1 1 k],   [H W 1]);
    end

    cltmp(roi_id).clear;
end

if k ~= N
    warning('formatPixelTrainingSetCPSAM:CountMismatch', ...
        'Expected %d frames, actually wrote %d.', N, k);
end

warning('on','all');
fprintf('Exported %d frames to HDF5 framebank:\n  %s\n', output, framebankPath);

fprintf('Exported %d frames to HDF5 framebank:\n  %s\n', output, framebankPath);

% -------------------------------------------------------------------------
% 7) Copie de traçabilité dans un sous-dossier "framebank" avec timestamp
% -------------------------------------------------------------------------
try
    backupDir = fullfile(classif.path, 'framebank');
    if ~exist(backupDir, 'dir')
        mkdir(backupDir);
        fprintf('[INFO] Created framebank backup directory: %s\n', backupDir);
    end

    % Timestamp compact, ex: 20251208_140512
    ts = datestr(now, 'yyyymmdd_HHMMSS');

    % baseName = nom du fichier sans chemin ni extension
    [~, baseName, ext] = fileparts(framebankPath);
    backupName = sprintf('%s_%s%s', baseName, ts, ext);
    backupPath = fullfile(backupDir, backupName);

    copyfile(framebankPath, backupPath);
    fprintf('[INFO] Framebank backup copy saved to: %s\n', backupPath);
catch ME
    warning('[WARN] Could not create framebank backup copy: %s', ME.message);
end

warning('on','all');
fprintf('Exported %d frames to HDF5 framebank:\n  %s\n', output, framebankPath);



% =========================================================================
% === Nested helper functions =============================================
% =========================================================================

    function tf = tryDeleteSafe(fpath)
        % Essaye de supprimer 'fpath' et vérifie qu'il a vraiment disparu.
        % Renvoie true si supprimé ou absent, false si encore présent.
        tf = false;
        if ~exist(fpath, 'file')
            tf = true;    % déjà absent
            return;
        end

        try
            delete(fpath);
        catch
            % delete() a échoué -> fichier suspect
            return;
        end

        % Attente brève (filesystem / cache / NFS)
        for kk = 1:20
            pause(0.05); % 50 ms
            if ~exist(fpath, 'file')
                tf = true;
                return;
            end
        end

        % Toujours présent -> fichier vérolé / fantôme
        tf = false;
    end

    function fbPath = chooseFramebankPath(basePath)
        % Choisit un chemin de framebank "sain" :
        % - teste basePath, puis basePath_001, basePath_002, ...
        % - si un chemin existe et est supprimable -> on le réutilise
        % - si un chemin existe et n'est PAS supprimable -> on le considère vérolé et on passe au suivant
        [folder, baseName, ext] = fileparts(basePath);

        maxTries = 999;
        for kk = 0:maxTries
            if kk == 0
                candidateName = baseName;
            else
                candidateName = sprintf('%s_%03d', baseName, kk);
            end
            candidatePath = fullfile(folder, [candidateName ext]);

            if exist(candidatePath, 'file')
                fprintf('WARNING: candidate framebank exists, trying delete: %s\n', candidatePath);
                if tryDeleteSafe(candidatePath)
                    fprintf('  -> old framebank deleted, reusing path: %s\n', candidatePath);
                    fbPath = candidatePath;
                    return;
                else
                    fprintf('  -> cannot delete (locked/corrupted?), skipping this path.\n');
                    continue;
                end
            else
                fprintf('Using new framebank path: %s\n', candidatePath);
                fbPath = candidatePath;
                return;
            end
        end

        error('formatPixelTrainingSetCPSAM:NoFramebankPath', ...
              'Could not find usable framebank path after %d attempts starting from %s', ...
              maxTries+1, basePath);
    end

end

