function output = formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois)
% FORMATPIXELTRAININGSETCELLTRACKTR
% Exporte les ROIs en format CTC strict (compatible script create_coco_dataset_from_CTC.py)
%
% OUTPUT = nombre total de frames exportées

output = 0; % compteur global frames

% === Nom du dataset ===
if isfield(classif.trainingParam, 'dataset') && ~isempty(classif.trainingParam.dataset)
    datasetName = classif.trainingParam.dataset;
else
    error('❌ Aucun datasetName trouvé dans classif.trainingParam.dataset');
end

% === Racine dataset ===
base = fullfile(classif.path, foldername, datasetName, 'CTC');
if ~exist(base, 'dir'), mkdir(base); end

% === Splits ===
splits = {'train', trainrois; 'val', valrois};
channel = classif.channelName;
cltmp   = classif.roi;

mappingLines = {};
seqCounter = 1;

for s = 1:size(splits,1)
    splitName = splits{s,1};
    rois = splits{s,2};
    fprintf('Processing split: %s (%d ROIs)\n', splitName, numel(rois));

    for rr = 1:numel(rois)
        roi_id = rois(rr);
        seqName = sprintf('%02d', seqCounter);
        seqCounter = seqCounter + 1;

        % === Dossiers CTC ===
        imgDir = fullfile(base, splitName, seqName); % images brutes
        segDir = fullfile(base, splitName, [seqName '_GT'], 'SEG'); % segmentation masks
        traDir = fullfile(base, splitName, [seqName '_GT'], 'TRA'); % tracking masks + man_track.txt
        mkdir(imgDir); mkdir(segDir); mkdir(traDir);

        mappingLines{end+1} = sprintf('%s\t%s', seqName, cltmp(roi_id).id); %#ok<AGROW>

        % Charger ROI
        cltmp(roi_id).load;
        if isempty(cltmp(roi_id).image)
            warning('ROI %d (%s) has no image data. Skipping.', roi_id, cltmp(roi_id).id);
            continue;
        end

        im = cltmp(roi_id).image; % H x W x C x T
        pix = cltmp(roi_id).findChannelID(channel);
        if iscell(pix), pix = cell2mat(pix); end
        if isempty(pix)
            warning('No channel found for "%s" in ROI %d', channel, roi_id);
            continue;
        end

        T = size(im,4);
        H = size(im,1);
        W = size(im,2);

        % Table tracking [L B E P]
        trackTable = [];
        globalID = 0;
        local2global = containers.Map('KeyType','uint32','ValueType','uint32');
        parentMap = containers.Map('KeyType','uint32','ValueType','uint32'); % divisions éventuelles

        debugMode = false; % <-- Mets à false pour désactiver

% === Export frames ===
for jj = 1:T
    output = output + 1;

    % Image brute
    rawImg = im(:,:,pix(1),jj);
    imwrite(uint16(rawImg), fullfile(imgDir, sprintf('t%03d.tif', jj-1)));

    segMask  = zeros(H, W, 'uint16'); % man_seg : IDs locaux
    trackMask = zeros(H, W, 'uint16'); % man_track : IDs propagés
    objCount = 0; % compteur d'objets pour cette frame

    for kk = 1:numel(classif.classes)
        chName = [classif.strid '_' classif.classes{kk}];
        cc = cltmp(roi_id).findChannelID(chName);
        if isempty(cc), continue; end

        lab = uint32(cltmp(roi_id).image(:,:,cc,jj));
        maxId = max(lab(:));
        if maxId < 1, continue; end

        for id = 1:maxId
            pixz = (lab == id);
            if any(pixz(:))
                objCount = objCount + 1;

                % man_seg : ID locaux par frame
                segMask(pixz) = id + kk;%*1000;

                % man_track : ID global propagé
                if ~isKey(local2global, id + kk*1000)
                    globalID = globalID + 1;
                    local2global(id + kk*1000) = globalID;
                    parentMap(globalID) = 0;
                    trackTable = [trackTable; globalID, jj-1, jj-1, 0]; %#ok<AGROW>
                else
                    gid = local2global(id + kk*1000);
                    idx = find(trackTable(:,1) == gid, 1);
                    trackTable(idx,3) = jj-1;
                end

                gid = local2global(id + kk*1000);
                trackMask(pixz) = gid;
            end
        end
    end

    if debugMode
        fprintf('Frame %03d : %d objets trouvés\n', jj-1, objCount);
        if objCount == 0
            warning('Frame %03d : aucun objet détecté (masque vide)', jj-1);
            % pause(0.5); % décommente si tu veux ralentir pour observer
        end
    end

    imwrite(uint16(segMask),  fullfile(segDir, sprintf('man_seg%03d.tif',   jj-1)));
    imwrite(uint16(trackMask),fullfile(traDir, sprintf('man_track%03d.tif', jj-1)));
end


        % === man_track.txt ===
        fid = fopen(fullfile(traDir, 'man_track.txt'), 'w');
        for rline = 1:size(trackTable,1)
            fprintf(fid, '%d %d %d %d\n', ...
                trackTable(rline,1), trackTable(rline,2), trackTable(rline,3), trackTable(rline,4));
        end
        fclose(fid);
    end
end

% Mapping ROI → séquence
fid = fopen(fullfile(base, 'mapping.txt'), 'w');
fprintf(fid, '%s\n', mappingLines{:});
fclose(fid);

fprintf('✅ Export CTC terminé : %d frames exportées.\n', output);

% === Appel du script Python de conversion ===
% On suppose que classif.trainingParam.repo_path contient le chemin du repo Cell-TRACTR

dataRoot = fullfile(classif.path, foldername); % là où CTC/ se trouve
pythonScript = fullfile(classif.trainingParam.repo_path, 'scripts', 'create_coco_dataset_from_CTC.py');

cmd = sprintf('python "%s" --dataset "%s" --datapath "%s"', ...
    pythonScript, datasetName, dataRoot);
system(cmd);



end
