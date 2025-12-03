function output = formatPixelTrainingSetCPSAM(foldername, classif, trainrois, valrois)
% formatPixelTrainingSetCPSAM  Build a Cellpose/CellposeSAM training set
% stocké dans un framebank HDF5 au lieu d'images individuelles.
%
% HDF5 structure (dans classif.path/foldername/framebank_cpsam.h5) :
%   /images      : uint8 [H W C N]   (C = 1 ou 3, N = nb de frames avec instances)
%   /masks       : uint16 [H W N]    (0 = background, 1..K = ID instances)
%   /split       : uint8 [N 1]       (1 = train, 2 = val)
%   /roi_id      : int32 [N 1]       (ID de ROI)
%   /frame_idx   : int32 [N 1]       (index de frame dans la ROI)
%
% Parameters
%   foldername : subfolder under classif.path where dataset will be written
%   classif    : classification project object
%   trainrois  : list of ROI indices for training split
%   valrois    : list of ROI indices for validation split
%
% Returns
%   output     : number of frames exported (N)

output = 0;
warning('off','all');

% Base path
% Root folder of the classifier (NOT foldername)
base = classif.path;

% Final framebank name:  <strid>_framebank.h5
fname = sprintf('%s_framebank.h5', classif.strid);

% HDF5 output path
framebankPath = fullfile(base, fname);

if exist(framebankPath, 'file')
    warning('formatPixelTrainingSetCPSAM:Overwrite',...
        'Existing framebank found, deleting: %s', framebankPath);
    delete(framebankPath);
end

% Channel selection
channel = classif.channelName;
cltmp   = classif.roi;

% Combine splits for processing
all_rois = [trainrois(:).'  valrois(:).'];

% ---------- 1ère passe : compter les frames et déterminer tailles ----------
fprintf('Scanning ROIs to build frame index...\n');

idx_roi   = [];
idx_frame = [];
idx_split = [];   % 1 = train, 2 = val

H = [];
W = [];
C = 0;           % nb de canaux utilisé (1 ou 3)

for ii = 1:numel(all_rois)
    roi_id = all_rois(ii);
    fprintf('  [scan] ROI %d...\n', roi_id);

    % Load ROI data
    cltmp(roi_id).load;
    im = cltmp(roi_id).image;  % H x W x C x T

    % Find image channels to export (grayscale or first 3 channels)
    pix = cltmp(roi_id).findChannelID(channel);
    if iscell(pix), pix = cell2mat(pix); end
    if isempty(pix)
        warning('No channel found for "%s" in ROI %d, skipping.', channel, roi_id);
        cltmp(roi_id).clear;
        continue;
    end

    T = size(im, 4);
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

    % split flag
    if ismember(roi_id, trainrois)
        splitFlag = uint8(1);
    else
        splitFlag = uint8(2);
    end

    % Iterate over frames to savoir lesquelles on garde
    for jj = 1:T
        % Construire mask instances (comme avant)
        instMask = zeros(H, W, 'uint16');
        instCounter = uint16(0);

        for kk = 1:numel(classif.classes)
            chName = [classif.strid '_' classif.classes{kk}];
            cc = cltmp(roi_id).findChannelID(chName);
            if isempty(cc), continue; end

            lab = cltmp(roi_id).image(:, :, cc, jj);
            lab = uint32(lab);
            maxId = max(lab(:));
            if maxId < 1, continue; end

            for id = 1:maxId
                pixz = (lab == id);
                if any(pixz(:))
                    instCounter = instCounter + 1;
                    writeIdx = pixz & instMask == 0;
                    instMask(writeIdx) = instCounter;
                end
            end
        end

        % Skip frames with no instances
        if max(instMask(:)) == 0
            continue;
        end

        % Déterminer le nombre de canaux utilisé pour cette frame (1 ou 3)
        if numel(pix) >= 3
            Cframe = 3;
        else
            Cframe = 1;
        end
        C = max(C, Cframe);

        % Enregistrer dans l'index
        idx_roi(end+1,1)   = int32(roi_id); %#ok<AGROW>
        idx_frame(end+1,1) = int32(jj);      %#ok<AGROW>
        idx_split(end+1,1) = splitFlag;      %#ok<AGROW>
    end

    cltmp(roi_id).clear;
end

N = numel(idx_roi);
output = N;

if N == 0
    warning('formatPixelTrainingSetCPSAM:Empty',...
        'No frames with instances found. Nothing written.');
    warning('on','all');
    return;
end

fprintf('Found %d frames with instances (H=%d, W=%d, C=%d).\n', N, H, W, C);

% ---------- Création du HDF5 ----------
fprintf('Creating framebank HDF5: %s\n', framebankPath);

h5create(framebankPath, '/images',   [H, W, C, N], 'Datatype', 'uint8');
h5create(framebankPath, '/masks',    [H, W,    N], 'Datatype', 'uint16');
h5create(framebankPath, '/split',    [N, 1],      'Datatype', 'uint8');
h5create(framebankPath, '/roi_id',   [N, 1],      'Datatype', 'int32');
h5create(framebankPath, '/frame_idx',[N, 1],      'Datatype', 'int32');

% Écrire les méta
h5write(framebankPath, '/split',     idx_split, [1 1],      [N 1]);
h5write(framebankPath, '/roi_id',    idx_roi,   [1 1],      [N 1]);
h5write(framebankPath, '/frame_idx', idx_frame, [1 1],      [N 1]);

% ---------- 2e passe : écrire images et masks ----------
fprintf('Filling framebank with image/mask data...\n');

k = 0;
cltmp = classif.roi;  % re-récupérer référence propre

for ii = 1:numel(all_rois)
    roi_id = all_rois(ii);
    fprintf('  [write] ROI %d...\n', roi_id);

    cltmp(roi_id).load;
    im = cltmp(roi_id).image;
    pix = cltmp(roi_id).findChannelID(channel);
    if iscell(pix), pix = cell2mat(pix); end
    if isempty(pix)
        cltmp(roi_id).clear;
        continue;
    end

    T = size(im, 4);

    % pré-calcul : quelles entrées de idx_roi correspondent à cette ROI
    mask_roi = (idx_roi == roi_id);
    frames_for_roi = idx_frame(mask_roi);

    for jj = 1:T
        if ~ismember(jj, frames_for_roi)
            continue; % frame sans instances (déjà filtrée en 1ère passe)
        end

        % ----- reconstruire instMask (comme plus haut) -----
        instMask = zeros(H, W, 'uint16');
        instCounter = uint16(0);

        for kk = 1:numel(classif.classes)
            chName = [classif.strid '_' classif.classes{kk}];
            cc = cltmp(roi_id).findChannelID(chName);
            if isempty(cc), continue; end

            lab = cltmp(roi_id).image(:, :, cc, jj);
            lab = uint32(lab);
            maxId = max(lab(:));
            if maxId < 1, continue; end

            for id = 1:maxId
                pixz = (lab == id);
                if any(pixz(:))
                    instCounter = instCounter + 1;
                    writeIdx = pixz & instMask == 0;
                    instMask(writeIdx) = instCounter;
                end
            end
        end

        if max(instMask(:)) == 0
            % ne devrait pas arriver (filtré en 1ère passe), mais on check
            continue;
        end

        % ----- préparer imgOut avec C canaux uniformes -----
        if numel(pix) >= 3
            useCh = pix(1:3);
            imgOut = im(:, :, useCh, jj);
            % normalize each channel to uint8
            tmpC = size(imgOut,3);
            for c = 1:tmpC
                ch = imgOut(:, :, c);
                if ~isa(ch, 'uint8')
                    ch = uint8(255 * mat2gray(ch));
                end
                imgOut(:, :, c) = ch;
            end
        else
            useCh = pix(1);
            ch = im(:, :, useCh, jj);
            if ~isa(ch, 'uint8')
                imgOut = uint8(255 * mat2gray(ch));
            else
                imgOut = ch;
            end
            imgOut = reshape(imgOut, H, W, 1);
        end

        % adapter à C global (1 ou 3)
        if C == 3 && size(imgOut,3) == 1
            imgOut = repmat(imgOut, [1 1 3]);
        elseif C == 1 && size(imgOut,3) == 3
            % si jamais ça arrive (normalement non), on prend la 1ère composante
            imgOut = imgOut(:,:,1);
            imgOut = reshape(imgOut, H, W, 1);
        end

        % ----- écriture dans HDF5 -----
        k = k + 1;
        if k > N
            error('formatPixelTrainingSetCPSAM:IndexOverflow','Internal indexing bug (k > N).');
        end

        h5write(framebankPath, '/images', imgOut, [1 1 1 k], [H W C 1]);
        h5write(framebankPath, '/masks',  instMask, [1 1 k], [H W 1]);
    end

    cltmp(roi_id).clear;
end

if k ~= N
    warning('formatPixelTrainingSetCPSAM:CountMismatch',...
        'Expected %d frames, actually wrote %d.', N, k);
end

warning('on','all');
fprintf('Exported %d frames to HDF5 framebank:\n  %s\n', output, framebankPath);

end


