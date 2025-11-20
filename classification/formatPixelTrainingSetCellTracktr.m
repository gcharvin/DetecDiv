function output = formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois)
% OPTION A (style MOMA strict)
% - Au frame N de division: on affiche UNIQUEMENT la mère, on termine sa piste à N.
% - Au frame N+1: on démarre 2 filles (continuité de la mère + fille ROI), parent = ancienne mère.
% - CTC: man_segNNN.tif n'affiche pas les filles à N ; man_track.txt code le parent (col 4).
%
% Sorties:
%   CTC/<split>/<seq>/tNNN.tif
%   CTC/<split>/<seq>_GT/SEG/man_segNNN.tif
%   CTC/<split>/<seq>_GT/TRA/man_trackNNN.tif
%   CTC/<split>/<seq>_GT/TRA/man_track.txt  [gid start end parent]

output = 0;

% === Racine dataset ===
base = fullfile(classif.path, foldername, 'moma', 'CTC');
if ~exist(base, 'dir'), mkdir(base); end

% ===== Mode de division (flag temporaire; pourra être passé en argument plus tard) =====
% 'symmetric' pour dataset type MOMA ; 'asymmetric' pour bourgeonnement
division_mode = 'symmetric';

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

        % Charger ROI (images + data pour lineage)
        cltmp(roi_id).load;
        if isempty(cltmp(roi_id).image)
            warning('ROI %d (%s) has no image data. Skipping.', roi_id, cltmp(roi_id).id);
            continue;
        end

        % --- Map fille->mère (int32 -> double)
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
        % trackTable : [gid, start, end, parent_gid] ; frames 0-index (CTC)
        trackTable = [];
        globalID   = uint32(0);

        % Clés robustes "kk#id"
        local2global        = containers.Map('KeyType','char','ValueType','uint32'); % key -> GID courant
        trackRowOfGID       = containers.Map('KeyType','uint32','ValueType','uint32'); % GID -> ligne
        childAllowedStart   = containers.Map('KeyType','char','ValueType','uint32');  % key fille -> N+1
        motherPendingParent = containers.Map('KeyType','char','ValueType','any');     % key mère -> struct('gid',old,'validFrom',N+1)
        seenLocalKey        = containers.Map('KeyType','char','ValueType','logical'); % détection 1ʳᵉ occurrence

        % ==== BOUCLE FRAMES ====
        for jj = 1:T
            frame0 = uint32(jj-1);  % 0-index CTC
            output = output + 1;

            % Image brute
            rawImg = im(:,:,pix(1),jj);
            imwrite(uint16(rawImg), fullfile(imgDir, sprintf('t%03d.tif', frame0)));

            segMask   = zeros(H, W, 'uint16');
            trackMask = zeros(H, W, 'uint16');

            % ---- 1) PRE-PASS: détecter les premiers enfants à ce frame,
            %         et planifier la clôture de la mère à frame N (=frame0).
            mothersToSplitThisFrame = {}; % cellstr de keys mères

            for kk = 1:numel(classif.classes)
                chName = [classif.strid '_' classif.classes{kk}];
                cc = cltmp(roi_id).findChannelID(chName);
                if isempty(cc), continue; end

                lab = uint32(cltmp(roi_id).image(:,:,cc,jj)); % labels locaux présents à jj
                maxId = max(lab(:));
                if maxId < 1, continue; end

                % ids présents
                ids_present = find(accumarray(double(lab(:))+1,1)>0) - 1;
                ids_present(ids_present==0) = []; % retirer 0

                for id = uint32(ids_present(:))'
                    key = makeKey(kk, id);

                    if ~isKey(seenLocalKey, key)
                        seenLocalKey(key) = true;
                    end

                    % Si c'est une fille ET c'est sa première fois vue:
                    if ~isempty(motherOf) && isKey(motherOf, int32(id)) && ~isKey(childAllowedStart, key)
                        % budding frame = frame0 ; fille doit débuter à frame0+1
                        childAllowedStart(key) = frame0 + 1;

                        % marquer la mère à clore à frame0
                        motherId  = uint32(motherOf(int32(id)));
                        mKey = makeKey(kk, motherId);
                        if ~ismember(mKey, mothersToSplitThisFrame)
                            mothersToSplitThisFrame{end+1} = mKey; %#ok<AGROW>
                        end
                    end
                end
            end

            % ---- 2) PASS d'écriture: générer SEG/TRA pour le frame courant.
            %     Règle Option A:
            %       - Si c'est une fille et frame0 < childAllowedStart: on SKIP au frame N.
            %       - La mère est encore vivante à N: on l'écrit normalement.
            for kk = 1:numel(classif.classes)
                chName = [classif.strid '_' classif.classes{kk}];
                cc = cltmp(roi_id).findChannelID(chName);
                if isempty(cc), continue; end

                lab = uint32(cltmp(roi_id).image(:,:,cc,jj));
                maxId = max(lab(:));
                if maxId < 1, continue; end

                for id = uint32(1):uint32(maxId)
                    pixz = (lab == id);
                    if ~any(pixz(:)), continue; end

                    key = makeKey(kk, id);

                    % --- FILLE ? et doit-elle être masquée au frame N ? ---
                    if ~isempty(motherOf) && isKey(motherOf, int32(id)) ...
                            && isKey(childAllowedStart, key) ...
                            && frame0 < childAllowedStart(key)
                        % Fille visible en ROI au frame N, mais on la décale à N+1 -> skip
                        continue;
                    end

                    % --- SEG: IDs locaux (arbitraires, par classe) ---
                    segMask(pixz) = uint16(id + kk);

                    % --- Création / mise à jour TRA ---
                    parent_gid = uint32(0);
                    need_new_gid = ~isKey(local2global, key);

                    if need_new_gid
                        % Cas A-1: continuité de MÈRE après split -> parent = ancienne mère
                        if isKey(motherPendingParent, key)
                            info = motherPendingParent(key);
                            if frame0 >= info.validFrom
                                parent_gid = info.gid;
                                % NOTE: NE PAS supprimer ici -> la fille ROI utilisera le même parent
                            end

                            % Cas A-2: FILLE qui débute (frame0 >= childAllowedStart) -> parent = ancienne mère
                        elseif ~isempty(motherOf) && isKey(motherOf, int32(id)) && isKey(childAllowedStart, key) ...
                                && frame0 >= childAllowedStart(key)
                            motherId = uint32(motherOf(int32(id)));
                            mKey = makeKey(kk, motherId);
                            if isKey(motherPendingParent, mKey)
                                info = motherPendingParent(mKey);
                                if frame0 >= info.validFrom
                                    parent_gid = info.gid;
                                end
                            else
                                % Mode asymétrique: la mère n'est pas splittée, on peut lire son GID courant
                                if strcmp(division_mode,'asymmetric') && isKey(local2global, mKey)
                                    parent_gid = local2global(mKey);
                                else
                                    parent_gid = uint32(0); % parent inconnu (rare)
                                end
                            end
                        end

                        % Créer le GID
                        globalID = globalID + 1;
                        gid = globalID;
                        local2global(key) = gid;

                        % Start=end=frame0 au début
                        trackTable = [trackTable; double([gid, frame0, frame0, parent_gid])]; %#ok<AGROW>
                        trackRowOfGID(gid) = size(trackTable,1);

                    else
                        % Piste existante -> prolonger jusqu'à frame0
                        gid = local2global(key);
                        row = trackRowOfGID(gid);
                        trackTable(row,3) = double(frame0);
                    end

                    % --- TRA: peindre le gid ---
                    trackMask(pixz) = uint16(local2global(key));
                end
            end

            % Sauvegarde des masques pour ce frame
            imwrite(uint16(segMask),   fullfile(segDir, sprintf('man_seg%03d.tif',   frame0)));
            imwrite(uint16(trackMask), fullfile(traDir, sprintf('man_track%03d.tif', frame0)));

            % ---- 3) FIN DE FRAME: appliquer les splits (clore la mère à N et préparer N+1)
            for mm = 1:numel(mothersToSplitThisFrame)
                mKey = mothersToSplitThisFrame{mm};
                if strcmp(division_mode,'symmetric') && isKey(local2global, mKey)
                    old_m_gid = local2global(mKey);
                    % la ligne de la mère est déjà prolongée jusqu'à frame0
                    % Forcer un nouveau GID pour la mère dès N+1
                    remove(local2global, mKey);
                    % Stocker le parent (réutilisé par mère-continuité ET fille ROI au frame N+1)
                    motherPendingParent(mKey) = struct('gid', old_m_gid, 'validFrom', frame0 + 1);
                end
            end

        end % frames

        % === Sanity & (optionnel) renumérotation locale 1..N avec reprojection TRA ===
        ids = trackTable(:,1);
        n  = size(trackTable,1);
        ids_unique = numel(unique(ids)) == n;
        ids_contig = min(ids)==1 && isequal(sort(ids(:).'), 1:n);

        if ~(ids_unique && ids_contig)
            % Renumérote en 1..N dans un ordre stable (par start, puis end)
            [~, ord] = sortrows(trackTable(:,2:3), [1 2]);       % tri par [start,end]
            lut_old2new = zeros(max(ids),1,'uint32');
            nextId = uint32(0);
            for k = 1:n
                gid = uint32(trackTable(ord(k),1));
                if lut_old2new(gid)==0
                    nextId = nextId + 1;
                    lut_old2new(gid) = nextId;
                end
            end
            % Applique LUT sur la table (col1 = id, col4 = parent)
            trackTable(:,1) = double(lut_old2new(uint32(trackTable(:,1))));
            parents = uint32(trackTable(:,4));
            parents(parents>0) = lut_old2new(parents(parents>0));
            trackTable(:,4) = double(parents);

            % Reprojeter les masques TRA avec la même LUT pour rester cohérent
            lut_img = uint16(zeros(numel(lut_old2new),1));
            for ii=1:numel(lut_old2new)
                lut_img(ii) = uint16(lut_old2new(ii));
            end
            % recharge, mappe et réécrit chaque man_track%03d.tif
            for frame0 = 0:(T-1)
                p = fullfile(traDir, sprintf('man_track%03d.tif', frame0));
                I = imread(p);
                Iu = unique(I(:)); Iu(Iu==0) = [];   % 0 = fond, ne pas mapper
                if ~isempty(Iu)
                    % mapping par LUT (les IDs TRA sont censés être <= max(ids))
                    J = I;
                    for u = Iu.'
                        if u <= numel(lut_img)
                            J(I==u) = lut_img(u);
                        else
                            % ID hors LUT (anormal) -> on remet 0
                            J(I==u) = uint16(0);
                        end
                    end
                    imwrite(J, p);
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

        % --- Sanity: mère doit avoir 0 ou 2 filles (diagnostic uniquement)
        try
            mt = trackTable;
            maxid = max(mt(:,1));
            childCounts = zeros(maxid,1);
            for i=1:size(mt,1)
                mom = mt(i,4);
                if mom>0 && mom<=maxid, childCounts(mom)=childCounts(mom)+1; end
            end
            bad_moms = find(childCounts~=0 & childCounts~=2);
            if strcmp(division_mode,'symmetric') && ~isempty(bad_moms)
                warning('Mothers with !=0/2 daughters in %s/%s seq %s: %s', splitName, foldername, seqName, mat2str(bad_moms(:)'));
            end
        catch
        end

    end
end

% === Mapping ROI → séquence
fid = fopen(fullfile(base, 'mapping.txt'), 'w');
fprintf(fid, '%s\n', mappingLines{:});
fclose(fid);

fprintf('✅ Export CTC terminé (Option A MOMA strict) : %d frames exportées.\n', output);

ctcRoot = fullfile(classif.path, foldername, 'moma', 'CTC');
%fix_all_sequences_man_track(ctcRoot);

% === Conversion COCO (optionnelle)
dataRoot = fullfile(classif.path, foldername,'moma');
pythonScript = fullfile(classif.trainingParam.repo_path, 'scripts', 'create_coco_dataset_from_CTC.py');
pyexe = string(pyenv().Executable);
datasetName='';
cmd = sprintf('"%s" "%s" --dataset "%s" --datapath "%s"', pyexe,pythonScript, datasetName, dataRoot);
system(cmd);


end

% ======================================================================
% Helpers
% ======================================================================
function motherOf = getMotherMapFromROI(roi)
% Renvoie containers.Map(int32->double) si roi.data{cell_information}.userData.motherOf existe
motherOf = [];
try
    if ~isprop(roi,'data') || isempty(roi.data), return; end
    dsIdx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data), 1, 'first');
    if isempty(dsIdx), return; end
    ds = roi.data(dsIdx);
    if ~isstruct(ds.userData) || ~isfield(ds.userData,'motherOf'), return; end
    mo = ds.userData.motherOf;
    if isa(mo, 'containers.Map')
        motherOf = mo; % int32 -> double
    end
catch
    motherOf = [];
end
end

function key = makeKey(kk, id)
% Clé de suivi robuste par (classe, id local)
key = sprintf('%d#%u', kk, uint32(id));
end


% mode classique : cellule mère qui persiste  + fille
% function output = formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois)
% % Exporte les ROIs en format CTC strict + lignage dans man_track.txt (colonne 4 = parentID)
% % Les liens de lignage sont lus dans roi.data(groupid="cell_information").userData.motherOf (Map int32->double)
%
% output = 0;
%
% % === Racine dataset ===
% base = fullfile(classif.path, foldername, 'moma', 'CTC');
% if ~exist(base, 'dir'), mkdir(base); end
%
% % === Splits ===
% splits = {'train', trainrois; 'val', valrois};
% channel = classif.channelName;
% cltmp   = classif.roi;
%
% mappingLines = {};
% seqCounter = 1;
%
% for s = 1:size(splits,1)
%     splitName = splits{s,1};
%     rois = splits{s,2};
%     fprintf('Processing split: %s (%d ROIs)\n', splitName, numel(rois));
%
%     for rr = 1:numel(rois)
%         roi_id = rois(rr);
%         seqName = sprintf('%02d', seqCounter); seqCounter = seqCounter + 1;
%
%         % === Dossiers CTC ===
%         imgDir = fullfile(base, splitName, seqName);
%         segDir = fullfile(base, splitName, [seqName '_GT'], 'SEG');
%         traDir = fullfile(base, splitName, [seqName '_GT'], 'TRA');
%         if ~exist(imgDir,'dir'), mkdir(imgDir); end
%         if ~exist(segDir,'dir'), mkdir(segDir); end
%         if ~exist(traDir,'dir'), mkdir(traDir); end
%
%         mappingLines{end+1} = sprintf('%s\t%s', seqName, cltmp(roi_id).id); %#ok<AGROW>
%
%         % Charger ROI (images + data pour accéder au lineage)
%         cltmp(roi_id).load;
%         if isempty(cltmp(roi_id).image)
%             warning('ROI %d (%s) has no image data. Skipping.', roi_id, cltmp(roi_id).id);
%             continue;
%         end
%         if isprop(cltmp(roi_id),'data') && ~isempty(cltmp(roi_id).data)
%             % ok
%         else
%             % si l'objet sait charger séparément la data, tu peux faire: cltmp(roi_id).load('data');
%         end
%
%         % --- Récupère la Map motherOf (int32->double) si présente
%         motherOf = getMotherMapFromROI(cltmp(roi_id));
%
%         im = cltmp(roi_id).image; % H x W x C x T
%         pix = cltmp(roi_id).findChannelID(channel);
%         if iscell(pix), pix = cell2mat(pix); end
%         if isempty(pix)
%             warning('No channel found for "%s" in ROI %d', channel, roi_id);
%             continue;
%         end
%
%         T = size(im,4); H = size(im,1); W = size(im,2);
%
%         % === Tables & Maps de suivi
%         % trackTable lignes: [gid, start, end, parent_gid] ; frames 0-index
%         trackTable = [];
%         globalID = uint32(0);
%         local2global = containers.Map('KeyType','uint32','ValueType','uint32'); % localKey -> gid
%         trackRowOfGID = containers.Map('KeyType','uint32','ValueType','uint32'); % gid -> row idx
%         pendingParentOfChildGID = containers.Map('KeyType','uint32','ValueType','uint32'); % child_gid -> parentLocalKey
%
%         debugMode = false;
%
%         % === Export frames ===
%         for jj = 1:T
%             output = output + 1;
%
%             % Image brute (CTC: t commence à 0)
%             rawImg = im(:,:,pix(1),jj);
%             imwrite(uint16(rawImg), fullfile(imgDir, sprintf('t%03d.tif', jj-1)));
%
%             segMask   = zeros(H, W, 'uint16');
%             trackMask = zeros(H, W, 'uint16');
%
%             for kk = 1:numel(classif.classes)
%                 chName = [classif.strid '_' classif.classes{kk}];
%                 cc = cltmp(roi_id).findChannelID(chName);
%                 if isempty(cc), continue; end
%
%                 lab = uint32(cltmp(roi_id).image(:,:,cc,jj));
%                 maxId = max(lab(:));
%                 if maxId < 1, continue; end
%
%                 for id = 1:maxId
%                     pixz = (lab == id);
%                     if ~any(pixz(:)), continue; end
%
%                     % --- man_seg: IDs locaux
%                     segMask(pixz) = uint16(id + kk);
%
%                     % --- Clé locale stable
%                     localKey = uint32(id + kk*1000);
%
%                     if ~isKey(local2global, localKey)
%                         % Création du GID
%                         globalID = globalID + 1;
%                         gid = globalID;
%                         local2global(localKey) = gid;
%
%                         % Parent (par défaut 0)
%                         parent_gid = uint32(0);
%
%                         % Si motherOf dit que id a une mère → parentLocalKey = motherId + kk*1000
%                         if ~isempty(motherOf) && isKey(motherOf, int32(id))
%                             motherId = motherOf(int32(id)); % double en général
%                             parentLocalKey = uint32(uint32(motherId) + kk*1000);
%                             if isKey(local2global, parentLocalKey)
%                                 parent_gid = local2global(parentLocalKey);
%                             else
%                                 % parent pas encore vu → backfill plus tard
%                                 pendingParentOfChildGID(gid) = parentLocalKey;
%                             end
%                         end
%
%                         trackTable = [trackTable; double([gid, jj-1, jj-1, parent_gid])]; %#ok<AGROW>
%                         trackRowOfGID(gid) = size(trackTable,1);
%
%                     else
%                         gid = local2global(localKey);
%                         row = trackRowOfGID(gid);
%                         trackTable(row,3) = jj-1; % maj end
%                     end
%
%                     % --- man_track: GID propagé
%                     gid = local2global(localKey);
%                     trackMask(pixz) = uint16(gid);
%                 end
%             end
%
%             if debugMode
%                 fprintf('Frame %03d exportée.\n', jj-1);
%             end
%
%             imwrite(uint16(segMask),   fullfile(segDir, sprintf('man_seg%03d.tif',   jj-1)));
%             imwrite(uint16(trackMask), fullfile(traDir, sprintf('man_track%03d.tif', jj-1)));
%         end
%
%         % === Backfill parents (cas où la mère est apparue plus tard)
%         if ~isempty(keys(pendingParentOfChildGID))
%             childGIDs = keys(pendingParentOfChildGID);
%             for ii = 1:numel(childGIDs)
%                 child_gid = uint32(childGIDs{ii});
%                 parentLocalKey = pendingParentOfChildGID(child_gid);
%                 if isKey(local2global, parentLocalKey)
%                     parent_gid = local2global(parentLocalKey);
%                     row = trackRowOfGID(child_gid);
%                     trackTable(row,4) = double(parent_gid);
%                 end
%             end
%         end
%
%         % === man_track.txt (CTC: ID start end parentID)
%         fid = fopen(fullfile(traDir, 'man_track.txt'), 'w');
%         for rline = 1:size(trackTable,1)
%             fprintf(fid, '%d %d %d %d\n', ...
%                 trackTable(rline,1), trackTable(rline,2), trackTable(rline,3), trackTable(rline,4));
%         end
%         fclose(fid);
%
%     end
% end
%
% % === Mapping ROI → séquence
% fid = fopen(fullfile(base, 'mapping.txt'), 'w');
% fprintf(fid, '%s\n', mappingLines{:});
% fclose(fid);
%
% fprintf('✅ Export CTC terminé : %d frames exportées.\n', output);
%
% % === Conversion COCO (optionnelle, inchangée)
% dataRoot = fullfile(classif.path, foldername,'moma');
% pythonScript = fullfile(classif.trainingParam.repo_path, 'scripts', 'create_coco_dataset_from_CTC.py');
% datasetName='';
% cmd = sprintf('python "%s" --dataset "%s" --datapath "%s"', pythonScript, datasetName, dataRoot);
% system(cmd);
%
% end
%
% % ======================================================================
% % Helpers
% % ======================================================================
% function motherOf = getMotherMapFromROI(roi)
% % Renvoie la Map containers.Map(int32->double) si disponible, sinon [].
% % Cherche dans roi.data un dataseries avec groupid=="cell_information"
%     motherOf = [];
%     try
%         if ~isprop(roi,'data') || isempty(roi.data), return; end
%         dsIdx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data), 1, 'first');
%         if isempty(dsIdx), return; end
%         ds = roi.data(dsIdx);
%         if ~isstruct(ds.userData) || ~isfield(ds.userData,'motherOf'), return; end
%         mo = ds.userData.motherOf;
%         if isa(mo, 'containers.Map')
%             % Normaliser ValueType si besoin (double → ok)
%             motherOf = mo;
%         end
%     catch
%         motherOf = [];
%     end
% end


function fix_all_sequences_man_track(ctcRoot)
% ctcRoot = ...\moma\CTC (dossier qui contient train/ et val/)
splits = {'train','val'};
for s = 1:numel(splits)
    split = splits{s};
    splitRoot = fullfile(ctcRoot, split);
    if ~isfolder(splitRoot), warning('Split manquant: %s', splitRoot); continue; end

    seqDirs = dir(fullfile(splitRoot, '*'));
    seqDirs = seqDirs([seqDirs.isdir]);

    for i = 1:numel(seqDirs)
        name = seqDirs(i).name;
        if strcmp(name,'.') || strcmp(name,'..') || endsWith(name,'_GT')
            continue; % on ignore . .. et les *_GT
        end

        % Vérif minimale : il doit exister un dossier frère "<name>_GT/TRA"
        traDir = fullfile(splitRoot, [name '_GT'], 'TRA');
        if ~isfolder(traDir)
            warning('[FIX] %s/%s : TRA introuvable: %s', split, name, traDir);
            continue;
        end

        try
            fix_one_sequence_man_track(splitRoot, name);
            fprintf('[FIX] %s/%s : OK\n', split, name);
        catch ME
            warning('[FIX] %s/%s : %s', split, name, ME.message);
        end
    end
end
end
function fix_one_sequence_man_track(splitRoot, seqName)
% splitRoot = ...\CTC\train  (ou ...\CTC\val)
% seqName   = '01'
traDir = fullfile(splitRoot, [seqName '_GT'], 'TRA');
files = dir(fullfile(traDir, 'man_track*.tif'));
if isempty(files)
    error('Aucun man_track*.tif dans %s', traDir);
end

% Trier par numéro de frame (0-index)
fnames = {files.name};
tokens = regexp(fnames, '^man_track(\d+)\.tif$', 'tokens', 'once');
hasTok = ~cellfun('isempty', tokens);
if ~all(hasTok), error('Nom inattendu dans %s', traDir); end
fnums = cellfun(@(t) str2double(t{1}), tokens);
[~,ord] = sort(fnums);
files = files(ord);
fnums = fnums(ord);

% 1) Collecter pour chaque gid la liste des frames où il apparaît
framesOf = containers.Map('KeyType','double','ValueType','any'); % gid -> row vector frames
for k = 1:numel(files)
    fr = fnums(k);
    I = imread(fullfile(traDir, files(k).name));
    u = unique(double(I(:))); u(u==0) = [];
    if isempty(u), continue; end
    for gid = u.'
        if ~isKey(framesOf, gid)
            framesOf(gid) = fr;
        else
            framesOf(gid) = [framesOf(gid) fr]; %#ok<AGROW>
        end
    end
end

% 2) Lire parents existants (si présents)
mtxt = fullfile(traDir, 'man_track.txt');
parents = containers.Map('KeyType','double','ValueType','double');
if exist(mtxt,'file')
    old = readmatrix(mtxt);
    if ~isempty(old)
        for r = 1:size(old,1)
            parents(old(r,1)) = old(r,4); % gid -> parent
        end
    end
end

% 3) Pour chaque gid, découper en runs contigus et émettre une ligne par run
gids = sort(cell2mat(keys(framesOf)));
T = [];
gaps_report = {}; % debug

for i = 1:numel(gids)
    gid = gids(i);
    frs = sort(unique(framesOf(gid)));
    if isempty(frs), continue; end

    % détecter les gaps (>1)
    d = diff(frs);
    brk = find(d > 1);
    % indices de début et fin de segments dans frs
    seg_st_idx = [1, brk+1];
    seg_en_idx = [brk, numel(frs)];

    % report debug si gaps
    if ~isempty(brk)
        gaps_report{end+1} = sprintf('gid=%d gaps at frames %s', gid, mat2str(frs(brk))); %#ok<AGROW>
    end

    par = 0; if isKey(parents, gid), par = parents(gid); end
    for s = 1:numel(seg_st_idx)
        st = frs(seg_st_idx(s));
        en = frs(seg_en_idx(s));
        T = [T; gid, st, en, par]; %#ok<AGROW>
    end
end

% 4) Écrire le man_track.txt consolidé (runs contigus uniquement)
writematrix(T, mtxt, 'Delimiter',' ');

% 5) Logs utiles
if ~isempty(gaps_report)
    fprintf('[FIX][%s] %d GIDs avaient des trous et ont été segmentés:\n', seqName, numel(gaps_report));
    for ii=1:numel(gaps_report), fprintf('  - %s\n', gaps_report{ii}); end
end
end
