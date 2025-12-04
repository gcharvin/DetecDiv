function output = formatPixelTrainingSetCPSAM(foldername, classif, trainrois, valrois)
% formatPixelTrainingSetCPSAM  Build a Cellpose/CellposeSAM training set
% stocké dans un framebank HDF5 au lieu d'images individuelles.
%
% HDF5 structure (dans classif.path/<strid>_framebank.h5) :
%   /images      : uint8  [H W C N]   (C = 1 ou 3, N = nb de frames gardées)
%   /masks       : uint16 [H W N]     (0 = background, 1..K = ID instances)
%   /split       : uint8  [N 1]       (1 = train, 2 = val)
%   /roi_id      : int32  [N 1]       (ID de ROI dans classif.roi)
%   /frame_idx   : int32  [N 1]       (index de frame dans la ROI)
%
% Parameters
%   foldername : ignoré (compatibilité)
%   classif    : classification project object
%   trainrois  : indices de ROI pour split train
%   valrois    : indices de ROI pour split val
%
% Returns
%   output     : nombre de frames exportées (N)

output = 0;
warning('off','all');  %#ok<WNOFF>

% -------------------------------------------------------------------------
% 1) Chemin du framebank
% -------------------------------------------------------------------------

base = classif.path;  % dossier de la classif

fname         = sprintf('%s_framebank.h5', classif.strid);
framebankPath = fullfile(base, fname);

if exist(framebankPath, 'file')
    fprintf('Existing framebank found, deleting: %s\n', framebankPath);
    delete(framebankPath);
end

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
% Paramètres de training / formatage (MaxTrainImages, Seed)
% -------------------------------------------------------------------------
MaxTrainImages = 0;   % 0 = pas de limite (utilise toutes les frames)
Seed           = [];

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

all_rois = [trainrois(:).'  valrois(:).'];

fprintf('Scanning ROIs to build frame index...\n');

idx_roi   = [];
idx_frame = [];
idx_split = [];   % 1 = train, 2 = val

H = [];
W = [];
C = 0;
excludedCount = 0;

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

    if ismember(roi_id, trainrois)
        splitFlag = uint8(1);
    else
        splitFlag = uint8(2);
    end

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

        idx_roi(end+1,1)   = int32(roi_id); %#ok<AGROW>
        idx_frame(end+1,1) = int32(jj);     %#ok<AGROW>
        idx_split(end+1,1) = splitFlag;     %#ok<AGROW>
    end

    cltmp(roi_id).clear;
end

fprintf('Excluded %d frames not satisfying criteria (min_train_masks=%d, min_train_pixels=%d).\n', ...
    excludedCount, min_train_masks, min_train_pixels);

% -------------------------------------------------------------------------
% 4b) Sous-échantillonnage global en fonction de MaxTrainImages
% -------------------------------------------------------------------------

Ntotal = numel(idx_roi);

if Ntotal == 0
    warning('formatPixelTrainingSetCPSAM:Empty', ...
        'No frames with instances found after filtering. Nothing written.');
    warning('on','all');
    return;
end

if MaxTrainImages > 0 && MaxTrainImages < Ntotal
    % rendre le tirage reproductible si Seed est fourni
    if ~isempty(Seed) && isnumeric(Seed) && isscalar(Seed)
        rng(Seed);
    end

    idxKeep = randperm(Ntotal, MaxTrainImages);

    idx_roi   = idx_roi(idxKeep);
    idx_frame = idx_frame(idxKeep);
    idx_split = idx_split(idxKeep);

    fprintf('Subsampling %d/%d frames according to trainingParam.MaxTrainImages.\n', ...
        MaxTrainImages, Ntotal);

    N = MaxTrainImages;
else
    if MaxTrainImages > 0 && MaxTrainImages >= Ntotal
        fprintf('MaxTrainImages (%d) >= available frames (%d): using all frames.\n', ...
            MaxTrainImages, Ntotal);
    end
    N = Ntotal;
end

nTrain = sum(idx_split == 1);
nVal   = sum(idx_split == 2);

output = N;

fprintf('Final selection: %d frames -> %d train, %d val (H=%d, W=%d, C=%d).\n', ...
    N, nTrain, nVal, H, W, C);

% -------------------------------------------------------------------------
% 5) Création du HDF5 : images [H W C N], masks [H W N]
% -------------------------------------------------------------------------

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

    % === CORRECTION : ne garder que les frames sélectionnés pour CE ROI ===
    mask_roi       = (idx_roi == int32(roi_id));   % au lieu de (idx_roi == idx_roi)
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
            useCh  = pix(1:3);
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
            useCh = pix(1);
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

end
