function output = formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois)
% Exporte les ROIs en format CTC strict + lignage dans man_track.txt (colonne 4 = parentID)
% Les liens de lignage sont lus dans roi.data(groupid="cell_information").userData.motherOf (Map int32->double)

output = 0;

% === Racine dataset ===
base = fullfile(classif.path, foldername, 'moma', 'CTC');
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
        seqName = sprintf('%02d', seqCounter); seqCounter = seqCounter + 1;

        % === Dossiers CTC ===
        imgDir = fullfile(base, splitName, seqName);
        segDir = fullfile(base, splitName, [seqName '_GT'], 'SEG');
        traDir = fullfile(base, splitName, [seqName '_GT'], 'TRA');
        if ~exist(imgDir,'dir'), mkdir(imgDir); end
        if ~exist(segDir,'dir'), mkdir(segDir); end
        if ~exist(traDir,'dir'), mkdir(traDir); end

        mappingLines{end+1} = sprintf('%s\t%s', seqName, cltmp(roi_id).id); %#ok<AGROW>

        % Charger ROI (images + data pour accéder au lineage)
        cltmp(roi_id).load;
        if isempty(cltmp(roi_id).image)
            warning('ROI %d (%s) has no image data. Skipping.', roi_id, cltmp(roi_id).id);
            continue;
        end
        if isprop(cltmp(roi_id),'data') && ~isempty(cltmp(roi_id).data)
            % ok
        else
            % si l'objet sait charger séparément la data, tu peux faire: cltmp(roi_id).load('data');
        end

        % --- Récupère la Map motherOf (int32->double) si présente
        motherOf = getMotherMapFromROI(cltmp(roi_id));

        im = cltmp(roi_id).image; % H x W x C x T
        pix = cltmp(roi_id).findChannelID(channel);
        if iscell(pix), pix = cell2mat(pix); end
        if isempty(pix)
            warning('No channel found for "%s" in ROI %d', channel, roi_id);
            continue;
        end

        T = size(im,4); H = size(im,1); W = size(im,2);

        % === Tables & Maps de suivi
        % trackTable lignes: [gid, start, end, parent_gid] ; frames 0-index
        trackTable = [];
        globalID = uint32(0);
        local2global = containers.Map('KeyType','uint32','ValueType','uint32'); % localKey -> gid
        trackRowOfGID = containers.Map('KeyType','uint32','ValueType','uint32'); % gid -> row idx
        pendingParentOfChildGID = containers.Map('KeyType','uint32','ValueType','uint32'); % child_gid -> parentLocalKey

        debugMode = false;

        % === Export frames ===
        for jj = 1:T
            output = output + 1;

            % Image brute (CTC: t commence à 0)
            rawImg = im(:,:,pix(1),jj);
            imwrite(uint16(rawImg), fullfile(imgDir, sprintf('t%03d.tif', jj-1)));

            segMask   = zeros(H, W, 'uint16');
            trackMask = zeros(H, W, 'uint16');

            for kk = 1:numel(classif.classes)
                chName = [classif.strid '_' classif.classes{kk}];
                cc = cltmp(roi_id).findChannelID(chName);
                if isempty(cc), continue; end

                lab = uint32(cltmp(roi_id).image(:,:,cc,jj));
                maxId = max(lab(:));
                if maxId < 1, continue; end

                for id = 1:maxId
                    pixz = (lab == id);
                    if ~any(pixz(:)), continue; end

                    % --- man_seg: IDs locaux
                    segMask(pixz) = uint16(id + kk);

                    % --- Clé locale stable
                    localKey = uint32(id + kk*1000);

                    if ~isKey(local2global, localKey)
                        % Création du GID
                        globalID = globalID + 1;
                        gid = globalID;
                        local2global(localKey) = gid;

                        % Parent (par défaut 0)
                        parent_gid = uint32(0);

                        % Si motherOf dit que id a une mère → parentLocalKey = motherId + kk*1000
                        if ~isempty(motherOf) && isKey(motherOf, int32(id))
                            motherId = motherOf(int32(id)); % double en général
                            parentLocalKey = uint32(uint32(motherId) + kk*1000);
                            if isKey(local2global, parentLocalKey)
                                parent_gid = local2global(parentLocalKey);
                            else
                                % parent pas encore vu → backfill plus tard
                                pendingParentOfChildGID(gid) = parentLocalKey;
                            end
                        end

                        trackTable = [trackTable; double([gid, jj-1, jj-1, parent_gid])]; %#ok<AGROW>
                        trackRowOfGID(gid) = size(trackTable,1);

                    else
                        gid = local2global(localKey);
                        row = trackRowOfGID(gid);
                        trackTable(row,3) = jj-1; % maj end
                    end

                    % --- man_track: GID propagé
                    gid = local2global(localKey);
                    trackMask(pixz) = uint16(gid);
                end
            end

            if debugMode
                fprintf('Frame %03d exportée.\n', jj-1);
            end

            imwrite(uint16(segMask),   fullfile(segDir, sprintf('man_seg%03d.tif',   jj-1)));
            imwrite(uint16(trackMask), fullfile(traDir, sprintf('man_track%03d.tif', jj-1)));
        end

        % === Backfill parents (cas où la mère est apparue plus tard)
        if ~isempty(keys(pendingParentOfChildGID))
            childGIDs = keys(pendingParentOfChildGID);
            for ii = 1:numel(childGIDs)
                child_gid = uint32(childGIDs{ii});
                parentLocalKey = pendingParentOfChildGID(child_gid);
                if isKey(local2global, parentLocalKey)
                    parent_gid = local2global(parentLocalKey);
                    row = trackRowOfGID(child_gid);
                    trackTable(row,4) = double(parent_gid);
                end
            end
        end

        % === man_track.txt (CTC: ID start end parentID)
        fid = fopen(fullfile(traDir, 'man_track.txt'), 'w');
        for rline = 1:size(trackTable,1)
            fprintf(fid, '%d %d %d %d\n', ...
                trackTable(rline,1), trackTable(rline,2), trackTable(rline,3), trackTable(rline,4));
        end
        fclose(fid);

    end
end

% === Mapping ROI → séquence
fid = fopen(fullfile(base, 'mapping.txt'), 'w');
fprintf(fid, '%s\n', mappingLines{:});
fclose(fid);

fprintf('✅ Export CTC terminé : %d frames exportées.\n', output);

% === Conversion COCO (optionnelle, inchangée)
dataRoot = fullfile(classif.path, foldername,'moma');
pythonScript = fullfile(classif.trainingParam.repo_path, 'scripts', 'create_coco_dataset_from_CTC.py');
datasetName='';
cmd = sprintf('python "%s" --dataset "%s" --datapath "%s"', pythonScript, datasetName, dataRoot);
system(cmd);

end

% ======================================================================
% Helpers
% ======================================================================
function motherOf = getMotherMapFromROI(roi)
% Renvoie la Map containers.Map(int32->double) si disponible, sinon [].
% Cherche dans roi.data un dataseries avec groupid=="cell_information"
    motherOf = [];
    try
        if ~isprop(roi,'data') || isempty(roi.data), return; end
        dsIdx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data), 1, 'first');
        if isempty(dsIdx), return; end
        ds = roi.data(dsIdx);
        if ~isstruct(ds.userData) || ~isfield(ds.userData,'motherOf'), return; end
        mo = ds.userData.motherOf;
        if isa(mo, 'containers.Map')
            % Normaliser ValueType si besoin (double → ok)
            motherOf = mo;
        end
    catch
        motherOf = [];
    end
end
