function output = formatPixelTrainingSetCPSAM(foldername, classif, trainrois, valrois)
% formatPixelTrainingSetCPSAM  Build a Cellpose/CellposeSAM training set
%
% Output directory structure (inside classif.path/foldername):
%   train/   -> contains paired image + instance mask (same basename)
%   val/     -> contains paired image + instance mask (same basename)
%
% Files naming:
%   <basename>.tif            (image)
%   <basename>_masks.tif      (instance mask)
%
% Instance mask format expected by Cellpose:
%   0 = background, 1..N = instance IDs (uint16 recommended)
%
% The function collects per-frame instance labels from your ROI objects.
% For each class listed in classif.classes, it expects a per‑instance label
% channel named "[classif.strid '_' class]" where pixel value k denotes the
% k‑th instance of that class in the frame.
%
% Parameters
%   foldername : subfolder under classif.path where dataset will be written
%   classif    : classification project object
%   trainrois  : list of ROI indices for training split
%   valrois    : list of ROI indices for validation split
%
% Returns
%   output     : number of frames exported

output = 0;
warning('off','all');

% Base paths (Cellpose expects image & mask in SAME folder per split)
base     = fullfile(classif.path, foldername);
trainDir = fullfile(base, 'train');
valDir   = fullfile(base, 'val');
for d = {trainDir, valDir}
    if ~exist(d{1}, 'dir'), mkdir(d{1}); end
end

% Channel selection for saving input images
channel = classif.channelName;
cltmp   = classif.roi;

% Combine splits for processing
all_rois = [trainrois(:).'  valrois(:).'];

for ii = 1:numel(all_rois)
    roi_id = all_rois(ii);
    fprintf('Processing ROI %d...\n', roi_id);

    % Load ROI data
    cltmp(roi_id).load;
    im = cltmp(roi_id).image;  % H x W x C x T

    % Find image channels to export (grayscale or first 3 channels)
    pix = cltmp(roi_id).findChannelID(channel);
    if iscell(pix), pix = cell2mat(pix); end
    if isempty(pix)
        warning('No channel found for "%s" in ROI %d, skipping.', channel, roi_id);
        continue;
    end

    % Determine split
    if ismember(roi_id, trainrois)
        splitDir = trainDir;
    else
        splitDir = valDir;
    end

    % Iterate over frames
    T = size(im, 4);
    H = size(im, 1); W = size(im, 2);

    for jj = 1:T
        % Build instance mask by merging all classes into a single label image
        instMask = zeros(H, W, 'uint16');
        instCounter = uint16(0);

        for kk = 1:numel(classif.classes)
            chName = [classif.strid '_' classif.classes{kk}];
            cc = cltmp(roi_id).findChannelID(chName);
            if isempty(cc), continue; end

            % per‑frame label image with integer instance IDs per class
            lab = cltmp(roi_id).image(:, :, cc, jj);
            lab = uint32(lab); % in case stored as single/double
            maxId = max(lab(:));
            if maxId < 1, continue; end

            for id = 1:maxId
                pixz = (lab == id);
                if any(pixz(:))
                    instCounter = instCounter + 1;
                    % write only where instMask is still background
                    writeIdx = pixz & instMask == 0;
                    instMask(writeIdx) = instCounter;
                end
            end
        end

        % Skip frames with no instances
        if max(instMask(:)) == 0
            continue;
        end

        % Prepare image to save (grayscale or RGB up to 3 channels)
        if numel(pix) >= 3
            useCh = pix(1:3);
            imgOut = im(:, :, useCh, jj);
            % normalize each channel to uint8
            for c = 1:3
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
        end

        % Filenames (paired image + mask in same folder)
        frameStr = sprintf('%04d', jj);
        baseName = sprintf('%s_frame_%s', cltmp(roi_id).id, frameStr);
        imgPath  = fullfile(splitDir, [baseName '.tif']);
        mskPath  = fullfile(splitDir, [baseName '_masks.tif']);

        % Write files
        try
            imwrite(imgOut, imgPath, 'Compression', 'none');
            imwrite(instMask, mskPath, 'Compression', 'none');
            output = output + 1;
        catch ME
            warning('Failed writing frame ROI %d, t=%d: %s', roi_id, jj, ME.message);
        end
    end

    % Free ROI memory
    cltmp(roi_id).clear;
end

warning('on','all');

% Optional: simple summary
fprintf('Exported %d frames to %s\n', output, base);

end
