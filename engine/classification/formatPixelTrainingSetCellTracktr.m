function output = formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois, varargin)
% formatPixelTrainingSetCellTracktr
%
% Export CTC (images + SEG/TRA + man_track.txt) from ROIs.
%
% NEW: optional layout flag to switch between:
%   - layoutMode = "ctc_root" (DEFAULT, current):
%       .../moma/CTC/train/<seq>/...
%       .../moma/CTC/val/<seq>/...
%   - layoutMode = "split_root" (your new requested layout):
%       .../moma/train/CTC/<seq>/...
%       .../moma/val/CTC/<seq>/...
%   - datasetSubfolder = "" writes the same layout directly under
%       .../<foldername>/...
%     This is used by SAM3.1, whose Python preparation scripts expect a
%     dataset root containing split/CTC directly.
%
% Usage:
%   formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois)
%   formatPixelTrainingSetCellTracktr(foldername, classif, trainrois, valrois, 'layoutMode',"split_root")

output = 0;

% =========================
% Parse options
% =========================
p = inputParser;
p.addParameter('layoutMode', "ctc_root", @(s) (ischar(s) || isstring(s)));
p.addParameter('mergeBudN', 3, @(x) isnumeric(x) && isscalar(x) && x>=0 && isfinite(x));
p.addParameter('runQA', true, @(x)islogical(x) && isscalar(x));
p.addParameter('qa_write_png', true, @(x)islogical(x) && isscalar(x));
p.addParameter('qa_png_max_frames', 50, @(x)isnumeric(x) && isscalar(x));
p.addParameter('qa_out_subdir', "_QA", @(s)ischar(s) || isstring(s));
p.addParameter('runCocoConversion', true, @(x)islogical(x) && isscalar(x));
p.addParameter('writeOverlayMovies', true, @(x)islogical(x) && isscalar(x));
p.addParameter('datasetSubfolder', "moma", @(s)ischar(s) || isstring(s));

p.parse(varargin{:});
%mergeBudN = uint32(p.Results.mergeBudN);
mergeBudN = 0 ;

layoutMode = string(p.Results.layoutMode);
layoutMode = lower(layoutMode);

runQA          = p.Results.runQA;
qa_write_png   = p.Results.qa_write_png;
qa_png_max     = p.Results.qa_png_max_frames;
qa_out_subdir  = string(p.Results.qa_out_subdir);
runCocoConversion = p.Results.runCocoConversion;
writeOverlayMovies = p.Results.writeOverlayMovies;
datasetSubfolder = strtrim(string(p.Results.datasetSubfolder));


if ~ismember(layoutMode, ["ctc_root","split_root"])
    error('layoutMode must be "ctc_root" or "split_root".');
end

totalBuds = 0;

% ===== Mode de division (flag temporaire; pourra être passé en argument plus tard) =====
% 'symmetric' pour dataset type MOMA ; 'asymmetric' pour bourgeonnement
division_mode = 'asymmetric';

layoutMode="split_root";  % train/CTC/01 etc....
%layoutMode="ctc_root"    % CTC/train/01 etc....
% =========================
% Roots depending on layout
% =========================
if datasetSubfolder == "" || datasetSubfolder == "."
    momaRoot = fullfile(classif.path, foldername);
else
    momaRoot = fullfile(classif.path, foldername, char(datasetSubfolder));
end
if ~exist(momaRoot,'dir'), mkdir(momaRoot); end

% mapping file location (single file for both splits)
% - old layout: keep exactly the same: moma/CTC/mapping.txt
% - new layout: put it at moma/mapping.txt (since there is no single moma/CTC root anymore)
if layoutMode == "ctc_root"
    ctcRoot = fullfile(momaRoot, 'CTC');               % contains train/ val
    if ~exist(ctcRoot,'dir'), mkdir(ctcRoot); end
    mappingFile = fullfile(ctcRoot, 'mapping.txt');
else
    ctcRoot = momaRoot;                                % contains train/CTC and val/CTC
    mappingFile = fullfile(momaRoot, 'mapping.txt');
end

% === Splits ===
splits  = {'train', trainrois; 'val', valrois};
channel = classif.channelName;
cltmp   = classif.roi;

mappingLines = {};
seqCounter = 1;

for s = 1:size(splits,1)
    splitName = splits{s,1};
    rois = splits{s,2};
    fprintf('Processing split: %s (%d ROIs)\n', splitName, numel(rois));

    % --- per-split base depending on layout ---
    if layoutMode == "ctc_root"
        splitBase = fullfile(ctcRoot, splitName);          % .../moma/CTC/train
    else
        splitBase = fullfile(momaRoot, splitName, 'CTC');  % .../moma/train/CTC
    end
    if ~exist(splitBase,'dir'), mkdir(splitBase); end

    for rr = 1:numel(rois)
        roi_id = rois(rr);
        seqName = sprintf('%02d', seqCounter); seqCounter = seqCounter + 1;

        % =========================
        % CTC folders (same inside splitBase)
        % =========================
        imgDir = fullfile(splitBase, seqName);
        segDir = fullfile(splitBase, [seqName '_GT'], 'SEG');
        traDir = fullfile(splitBase, [seqName '_GT'], 'TRA');
        if ~exist(imgDir,'dir'), mkdir(imgDir); end
        if ~exist(segDir,'dir'), mkdir(segDir); end
        if ~exist(traDir,'dir'), mkdir(traDir); end

        mappingLines{end+1} = sprintf('%s\t%s\t%s', splitName, seqName, cltmp(roi_id).id); %#ok<AGROW>
        % note: I include splitName in mapping now to avoid ambiguity in the new layout.
        % If you want the old 2-column mapping only, replace by:
        % mappingLines{end+1} = sprintf('%s\t%s', seqName, cltmp(roi_id).id);

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
        trackTable = [];
        globalID   = uint32(0);

        local2global        = containers.Map('KeyType','char','ValueType','uint32');
        trackRowOfGID       = containers.Map('KeyType','uint32','ValueType','uint32');
        childAllowedStart   = containers.Map('KeyType','char','ValueType','uint32');
        motherPendingParent = containers.Map('KeyType','char','ValueType','any');
        seenLocalKey        = containers.Map('KeyType','char','ValueType','logical');
        childBirthFrame = containers.Map('KeyType','char','ValueType','uint32'); % frame0 où le bud est vu pour la 1ère fois


        % ==== BOUCLE FRAMES ====
      
% ==== BOUCLE FRAMES ====

for jj = 1:T
    frame0 = uint32(jj-1);  % 0-index CTC
    output = output + 1;
    maxid=uint16(0);

%    rawImg = im(:,:,pix(1),jj);
% raw8   = normalizeFrameToUint8(rawImg);   % robust 1–99.8%
% imwrite(raw8, fullfile(imgDir, sprintf('t%03d.tif', frame0)));
    rawImg = im(:,:,pix(1),jj);
    imwrite(uint16(rawImg), fullfile(imgDir, sprintf('t%03d.tif', frame0)));


    segMask   = zeros(H, W, 'uint16');
    trackMask = zeros(H, W, 'uint16');

    % ---- 1) PRE-PASS
    mothersToSplitThisFrame = {};

    for kk = 1:numel(classif.classes)
        chName = [classif.strid '_' classif.classes{kk}];
        cc = cltmp(roi_id).findChannelID(chName);
        if isempty(cc), continue; end

        lab = uint32(cltmp(roi_id).image(:,:,cc,jj));
        maxId = max(lab(:));
        if maxId < 1, continue; end

        ids_present = find(accumarray(double(lab(:))+1,1)>0) - 1;
        ids_present(ids_present==0) = [];

        for id = uint32(ids_present(:))'
            key = makeKey(kk, id);

            if ~isKey(seenLocalKey, key)
                seenLocalKey(key) = true;
            end

            % --- première apparition d'un bud: mémorise sa "naissance" et calcule l'autorisation ---
            if ~isempty(motherOf) && isKey(motherOf, int32(id)) && ~isKey(childAllowedStart, key)

                if ~isKey(childBirthFrame, key)
                    childBirthFrame(key) = frame0; % naissance = première frame où il est vu
                end

                % mergeBudN=0 => bud séparé dès la birthFrame (pas de délai)
                % mergeBudN>0 => bud séparé à partir de birthFrame + mergeBudN
                childAllowedStart(key) = childBirthFrame(key) + mergeBudN;

                motherId = uint32(motherOf(int32(id)));
                mKey = makeKey(kk, motherId);
                if ~ismember(mKey, mothersToSplitThisFrame)
                    mothersToSplitThisFrame{end+1} = mKey; %#ok<AGROW>
                end
            end
        end
    end

    % ---- 2) PASS d'écriture
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

    % --- Si bud et pas encore autorisé: fusion bud->mère UNIQUEMENT si mergeBudN>0 ---
    if mergeBudN > 0 ...
            && ~isempty(motherOf) && isKey(motherOf, int32(id)) ...
            && isKey(childAllowedStart, key) ...
            && frame0 < childAllowedStart(key)

        motherId = uint32(motherOf(int32(id)));
        mKey     = makeKey(kk, motherId);

        % Si la mère n'a pas encore de GID, on la crée maintenant (parent=0 par défaut)
        if ~isKey(local2global, mKey)
            globalID = globalID + 1;
            mgid = globalID;
            local2global(mKey) = mgid;

            trackTable = [trackTable; double([mgid, frame0, frame0, 0])]; %#ok<AGROW>
            trackRowOfGID(mgid) = size(trackTable,1);
        else
            mgid = local2global(mKey);
            rowM = trackRowOfGID(mgid);
            trackTable(rowM,3) = double(frame0);
        end

        % ====== ICI: fusion mère+bud + pont si non connexe ======
        pixm = (lab == motherId);
        pixu = pixm | pixz;

        % si l'union est en plusieurs morceaux, on ajoute un pont minimal
    CC = bwconncomp(pixu, 8);
if CC.NumObjects > 1
    % --- log console : fusion non connexe détectée ---
    fprintf(['🔧 [merge-fix] ROI %s | frame %d | class %s | ' ...
             'mother %u + bud %u : %d composantes → pont ajouté\n'], ...
        cltmp(roi_id).id, frame0, classif.classes{kk}, motherId, id, CC.NumObjects);

    pixu = bridgeComponentsShortest(pixu, 8, 1); % radius=1 => pont minimal
end


        % Ecriture dans SEG/TRA sous l'ID/GID de la mère (sur l'union)
        segMask(pixu)   = uint16(motherId + kk);
        trackMask(pixu) = uint16(mgid);

        % Ne PAS créer/mettre à jour le GID du bud sur cette frame
        continue;
    end

    % --- cas normal: écrit sous son propre ID local + GID (même à la birthFrame si mergeBudN==0) ---
    segMask(pixz) = uint16(id + kk);

    parent_gid   = uint32(0);
    need_new_gid = ~isKey(local2global, key);

    if need_new_gid
        if isKey(motherPendingParent, key)
            info = motherPendingParent(key);
            if frame0 >= info.validFrom
                parent_gid = info.gid;
            end

        elseif ~isempty(motherOf) && isKey(motherOf, int32(id)) ...
                && isKey(childAllowedStart, key) ...
                && frame0 >= childAllowedStart(key)

            motherId = uint32(motherOf(int32(id)));
            mKey     = makeKey(kk, motherId);

            if isKey(motherPendingParent, mKey)
                info = motherPendingParent(mKey);
                if frame0 >= info.validFrom
                    parent_gid = info.gid;
                end
            else
                if strcmp(division_mode,'asymmetric') && isKey(local2global, mKey)
                    parent_gid = local2global(mKey);
                else
                    parent_gid = uint32(0);
                end
            end
        end

        globalID = globalID + 1;
        gid = globalID;
        local2global(key) = gid;

        trackTable = [trackTable; double([gid, frame0, frame0, parent_gid])]; %#ok<AGROW>
        trackRowOfGID(gid) = size(trackTable,1);

    else
        gid = local2global(key);
        row = trackRowOfGID(gid);
        trackTable(row,3) = double(frame0);
    end

    trackMask(pixz) = uint16(local2global(key));
end

    end

    if max(segMask(:)) > 255 || max(trackMask(:)) > 255
    error('Cannot write masks as uint8: maxId=%d > 255 (seq %s, frame %d)', ...
        max(max(segMask(:)), max(trackMask(:))), seqName, frame0);
    end

    
   % imwrite(uint8(segMask),   fullfile(segDir, sprintf('man_seg%03d.tif',   frame0)));
  %  imwrite(uint8(trackMask), fullfile(traDir, sprintf('man_track%03d.tif', frame0)));
    imwrite(uint16(segMask),   fullfile(segDir, sprintf('man_seg%03d.tif',   frame0)));
    imwrite(uint16(trackMask), fullfile(traDir, sprintf('man_track%03d.tif', frame0)));

    % ---- 3) FIN DE FRAME
    for mm = 1:numel(mothersToSplitThisFrame)
        mKey = mothersToSplitThisFrame{mm};
        if strcmp(division_mode,'symmetric') && isKey(local2global, mKey)
            old_m_gid = local2global(mKey);
            remove(local2global, mKey);
            motherPendingParent(mKey) = struct('gid', old_m_gid, 'validFrom', frame0 + 1);
        end
    end

    maxid=max(maxid,max(trackMask(:)));

end % frames

disp(['Max ID in this position : ', num2str(maxid)]);

% === DEBUG: vérifier cohérence startFrame (trackTable) vs première apparition dans TRA
try
    startByGid = containers.Map('KeyType','uint32','ValueType','uint32');
    for r = 1:size(trackTable,1)
        startByGid(uint32(trackTable(r,1))) = uint32(trackTable(r,2));
    end

    firstSeen = containers.Map('KeyType','uint32','ValueType','uint32');

    for f0 = uint32(0):uint32(T-1)
        I = imread(fullfile(traDir, sprintf('man_track%03d.tif', f0)));
        ids = unique(I(:)); ids(ids==0) = [];
        for gid = uint32(ids(:))'
            if ~isKey(firstSeen, gid)
                firstSeen(gid) = f0;
            end
        end
    end

    gids = cell2mat(keys(startByGid));
    bad = [];
    for i = 1:numel(gids)
        g = gids(i);
        if isKey(firstSeen, g)
            if firstSeen(g) ~= startByGid(g)
                bad(end+1,:) = [double(g) double(startByGid(g)) double(firstSeen(g))]; %#ok<AGROW>
            end
        end
    end

    if ~isempty(bad)
        fprintf('⚠️ Décalages startFrame vs première apparition TRA (gid, startTable, firstSeenTRA):\n');
        disp(bad);
    else
        fprintf('✅ startFrame(trackTable) cohérent avec première apparition dans TRA.\n');
    end
catch ME
    warning('DEBUG startFrame check failed: %s', ME.message);
end


        % === (optional) renumérotation + reprojection TRA (UNCHANGED) ===
        ids = trackTable(:,1);
        n  = size(trackTable,1);
        ids_unique = numel(unique(ids)) == n;
        ids_contig = min(ids)==1 && isequal(sort(ids(:).'), 1:n);

        if ~(ids_unique && ids_contig)
            [~, ord] = sortrows(trackTable(:,2:3), [1 2]);
            lut_old2new = zeros(max(ids),1,'uint32');
            nextId = uint32(0);
            for k = 1:n
                gid = uint32(trackTable(ord(k),1));
                if lut_old2new(gid)==0
                    nextId = nextId + 1;
                    lut_old2new(gid) = nextId;
                end
            end
            trackTable(:,1) = double(lut_old2new(uint32(trackTable(:,1))));
            parents = uint32(trackTable(:,4));
            parents(parents>0) = lut_old2new(parents(parents>0));
            trackTable(:,4) = double(parents);

            lut_img = uint16(zeros(numel(lut_old2new),1));
            for ii=1:numel(lut_old2new)
                lut_img(ii) = uint16(lut_old2new(ii));
            end
            for frame0 = 0:(T-1)
                pth = fullfile(traDir, sprintf('man_track%03d.tif', frame0));
                I = imread(pth);
                Iu = unique(I(:)); Iu(Iu==0) = [];
                if ~isempty(Iu)
                    J = I;
                    for u = Iu.'
                        if u <= numel(lut_img)
                            J(I==u) = lut_img(u);
                        else
                            J(I==u) = uint16(0);
                        end
                    end
                    imwrite(J, pth);
                end
            end
        end

        % === man_track.txt
        fid = fopen(fullfile(traDir, 'man_track.txt'), 'w');
        for rline = 1:size(trackTable,1)
            fprintf(fid, '%d %d %d %d\n', ...
                trackTable(rline,1), trackTable(rline,2), trackTable(rline,3), trackTable(rline,4));
        end
        fclose(fid);

        % === QA instantanée (par séquence)
if runQA
    try
        % seqDir = dossier qui contient t***.tif + <seq>_GT/TRA
        % ici, imgDir = splitBase/seqName, donc seqDir = imgDir
        seqDir = imgDir;

        qaOutDir = fullfile(seqDir, qa_out_subdir); % .../01/_QA

        rep = qa_ctc_sequence(seqDir, ...
            'write_png', qa_write_png, ...
            'png_max_frames', qa_png_max, ...
            'out_dir', qaOutDir, ...
            'conn', 8);

        if isempty(rep.issues)
            fprintf('✅ QA CTC OK : %s\n', seqDir);
        else
            fprintf('⚠️ QA CTC: %d issues dans %s (voir %s)\n', ...
                size(rep.issues,1), seqDir, qaOutDir);
        end
    catch ME
        warning('QA CTC failed for %s: %s', imgDir, ME.message);
    end
end


        % === Compteur d'événements de bourgeonnement (par ROI)
nBuds = 0;
try
    if ~isempty(trackTable)
        nBuds = sum(trackTable(:,4) > 0);
    end
catch
    nBuds = 0;
end

fprintf('🧬 ROI %s (%s / seq %s) : %d budding events détectés\n', ...
    cltmp(roi_id).id, splitName, seqName, nBuds);

totalBuds = totalBuds + nBuds;


        % --- Sanity (UNCHANGED)
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

        % === Movie overlay (optionnel) : raw channel + overlay IDs (TRA)
if writeOverlayMovies
    try
        outMp4 = fullfile(splitBase, sprintf('%s_overlay.mp4', seqName));
        makeOverlayMovieFromCTC(imgDir, traDir, outMp4, trackTable);
    catch ME
        warning('Overlay movie failed for %s/%s: %s', splitName, seqName, ME.message);
    end
end



    end

    if runQA
    try
        fprintf('\n=== QA SUMMARY split %s ===\n', splitName);
        % splitBase = .../train/CTC ou .../CTC/train selon layout
        qa_ctc_all(splitBase);
    catch ME
        warning('QA summary failed for split %s: %s', splitName, ME.message);
    end
end



end

% === Mapping ROI → séquence
fid = fopen(mappingFile, 'w');
fprintf(fid, '%s\n', mappingLines{:});
fclose(fid);

fprintf('✅ Export CTC terminé (layout=%s) : %d frames exportées.\n', layoutMode, output);

fprintf('🧬 TOTAL budding events (tous ROIs) : %d\n', totalBuds);

% NOTE: if you rely on fix_all_sequences_man_track(), its old signature assumes
% ctcRoot contains train/ and val/ directly. With layoutMode="split_root",
% you probably want to call it separately on:
%   fullfile(momaRoot,'train','CTC') and fullfile(momaRoot,'val','CTC')
%
% Example:
% if layoutMode=="ctc_root"
%     fix_all_sequences_man_track(ctcRoot);
% else
%     fix_all_sequences_man_track(fullfile(momaRoot,'train','CTC'));
%     fix_all_sequences_man_track(fullfile(momaRoot,'val','CTC'));
% end

% === Conversion COCO (optionnelle)
if ~runCocoConversion
    return;
end

% WARNING: depending on how create_coco_dataset_from_CTC.py discovers train/val,
% the new layout may require adapting that script. I keep datapath=momaRoot.
dataRoot = momaRoot;
pythonScript = fullfile(classif.trainingParam.repo_path, 'scripts', 'create_coco_dataset_from_CTC.py');
pyexe = string(pyenv().Executable);
datasetName='';
cmd = sprintf('"%s" "%s" --dataset "%s" --datapath "%s"', pyexe, pythonScript, datasetName, dataRoot);
system(cmd);

end

% ======================================================================
% Helpers
% ======================================================================

function I8 = normalizeFrameToUint8(I)
% Normalise une image brute vers uint8 via percentiles (robuste).
Id = double(I);

% percentiles robustes (évite saturation sur outliers)
lo = prctile(Id(:), 1);
hi = prctile(Id(:), 99.8);

if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
    % fallback min/max
    lo = min(Id(:));
    hi = max(Id(:));
end

if hi <= lo
    I8 = uint8(zeros(size(I), 'uint8'));
    return;
end

J = (Id - lo) / (hi - lo);
J = min(max(J, 0), 1);
I8 = uint8(round(255 * J));
end


function motherOf = getMotherMapFromROI(roi)
motherOf = [];
try
    if ~isprop(roi,'data') || isempty(roi.data), return; end
    dsIdx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data), 1, 'first');
    if isempty(dsIdx), return; end
    ds = roi.data(dsIdx);
    if ~isstruct(ds.userData) || ~isfield(ds.userData,'motherOf'), return; end
    mo = ds.userData.motherOf;
    if isa(mo, 'containers.Map')
        motherOf = mo;
    end
catch
    motherOf = [];
end
end

function key = makeKey(kk, id)
key = sprintf('%d#%u', kk, uint32(id));
end


function makeOverlayMovieFromCTC(imgDir, traDir, outMp4, trackTable)
% makeOverlayMovieFromCTC
% MP4: raw + overlay couleurs par ID (gid) + liens mère->bud (trackTable parent column)
% MODS:
%  1) meilleure qualité vidéo (Quality=100) + upscale x2
%  2) affiche la frame en commençant à 0 (stamp "f=000")
%  3) ralentir à 5 fps
%  4) afficher les IDs en gros sur les masques (au centroïde)
%
% Notes:
% - l'upscale x2 est fait avec imresize avant écriture vidéo
% - les IDs sont dessinés en blanc avec contour noir (lisible sur couleurs)

% ---- rendu / qualité
alphaFill   = 0.75;
frameRate   = 5;          % (3) ralentir
upScale     = 2;          % (1) x2

useContrast = true;
prcLow  = 1;
prcHigh = 99.8;
gamma   = 0.9;

% ---- liens mère/bud
drawLinks   = true;
linkAlpha   = 1;
linkWidth   = 1;

% ---- IDs sur masques
drawIds     = true;
idFontSize  = 12;         % sera multiplié par upScale plus bas
idMinPixels = 0;         % ignore objets trop petits (évite spam)
idAlpha     = 1;          % opacité texte

% ---- liste frames (raw)
rawList = dir(fullfile(imgDir, 't*.tif'));
if isempty(rawList), error('No raw frames found in %s', imgDir); end

% ---- parent map gid->parent_gid depuis trackTable
parentOf = [];
if nargin >= 4 && ~isempty(trackTable)
    maxGid = max(trackTable(:,1));
    parentOf = zeros(maxGid, 1, 'uint32');
    gids = uint32(trackTable(:,1));
    moms = uint32(trackTable(:,4));
    parentOf(gids) = moms;
else
    maxGid = 1;
end

% ---- trouver maxId (si trackTable vide, on le détecte via man_track)
maxId = 0;
for k = 1:numel(rawList)
    tok = regexp(rawList(k).name, 't(\d+)\.tif$', 'tokens', 'once');
    if isempty(tok), continue; end
    frame0 = str2double(tok{1});
    pTra = fullfile(traDir, sprintf('man_track%03d.tif', frame0));
    if ~exist(pTra,'file'), continue; end
    Itra = imread(pTra);
    maxId = max(maxId, double(max(Itra(:))));
end
if maxId < 1, maxId = double(maxGid); end
if maxId < 1, maxId = 1; end

% ---- colormap déterministe (gid->couleur stable)
rng(0);
cmap = rand(maxId, 3);
cmap = 0.2 + 0.8*cmap;

% ---- mémoires pour centroïdes (pour tracer même si un parent saute une frame)
lastX = nan(maxId,1);
lastY = nan(maxId,1);

% ---- VideoWriter
v = VideoWriter(outMp4, 'MPEG-4');
v.FrameRate = frameRate;
try, v.Quality = 100; end
open(v);

for k = 1:numel(rawList)
    tok = regexp(rawList(k).name, 't(\d+)\.tif$', 'tokens', 'once');
    if isempty(tok), continue; end
    frame0 = str2double(tok{1});

    pRaw = fullfile(imgDir, rawList(k).name);
    pTra = fullfile(traDir, sprintf('man_track%03d.tif', frame0));

    Iraw = imread(pRaw);

    % ---- base (raw -> uint8) + contraste
    base = normalizeToUint8(Iraw); % fallback
    if useContrast
        Id = double(Iraw);
        lo = prctile(Id(:), prcLow);
        hi = prctile(Id(:), prcHigh);
        if hi > lo
            base = uint8(255 * min(max((Id - lo) / (hi - lo), 0), 1));
            if gamma ~= 1
                base = uint8(255 * (double(base)/255) .^ gamma);
            end
        end
    end
    out = repmat(base, 1,1,3);

    % ---- si pas de TRA, on met juste le stamp frame et on écrit
    if ~exist(pTra,'file')
        out = stampFrame(out, frame0, upScale);
        if upScale ~= 1
            out = imresize(out, upScale, 'nearest');
        end
        writeVideo(v, out);
        continue;
    end

    Itra = imread(pTra); % uint16 gids
    mask = Itra > 0;

    % ---- overlay par ID (remplissage uniquement)
    if any(mask(:))
        id = double(Itra);

        col = zeros([size(Itra) 3], 'double');
        idx = id(mask);
        for c = 1:3
            tmp = zeros(size(Itra), 'double');
            tmp(mask) = cmap(idx, c);
            col(:,:,c) = tmp;
        end
        col = uint8(255 * col);

        a = alphaFill;
        for c = 1:3
            ch   = out(:,:,c);
            colc = col(:,:,c);
            ch(mask) = uint8((1-a)*double(ch(mask)) + a*double(colc(mask)));
            out(:,:,c) = ch;
        end
    end

    % ---- centroïdes par gid (rapide via accumarray) + liens + IDs
    if any(mask(:))
        [yy, xx] = find(mask);
        gids = double(Itra(mask));

        cnt = accumarray(gids, 1, [maxId 1], @sum, 0);
        sx  = accumarray(gids, double(xx), [maxId 1], @sum, 0);
        sy  = accumarray(gids, double(yy), [maxId 1], @sum, 0);

        present = cnt > 0;
        cx = nan(maxId,1); cy = nan(maxId,1);
        cx(present) = sx(present) ./ cnt(present);
        cy(present) = sy(present) ./ cnt(present);

        % update mémoire
        lastX(present) = cx(present);
        lastY(present) = cy(present);

        % ---- liens child->mother
        if drawLinks && ~isempty(parentOf)
            childList = find(present);
            for ii = 1:numel(childList)
                child = childList(ii);
                if child > numel(parentOf), continue; end
                mom = double(parentOf(child));
                if mom <= 0 || mom > maxId, continue; end

                if ~isnan(lastX(child)) && ~isnan(lastX(mom))
                    colLine = uint8([255 255 255]); % blanc
                    out = drawLineRGB(out, lastX(mom), lastY(mom), lastX(child), lastY(child), colLine, linkWidth, linkAlpha);
                end
            end
        end

        % ---- IDs en gros sur les masques
        if drawIds
            idsHere = find(present & (cnt >= idMinPixels));
            for ii = 1:numel(idsHere)
                g = idsHere(ii);
                if ~isnan(cx(g)) && ~isnan(cy(g))
pos = [cx(g)-6, cy(g)-6];  % léger recentrage vers l'intérieur

out = insertText(out, pos, sprintf('%d', g), ...
    'FontSize', idFontSize, ...
    'TextColor', 'white', ...
    'BoxOpacity', 0.15, ...     % fond très léger (lisibilité)
    'BoxColor', 'black');

                end
            end
        end
    end

    % ---- stamp frame index starting at 0 (2)
    out = stampFrame(out, frame0, 1);

    % ---- upscale x2 before writing (1)
    if upScale ~= 1
        out = imresize(out, upScale, 'nearest');
    end

    writeVideo(v, out);
end

close(v);
end

% ======================================================================
% Helpers (local)
% ======================================================================

function out = stampFrame(out, frame0, scaleHint)
% stamp "f=000" top-left. scaleHint used only to choose a larger font
if nargin < 3, scaleHint = 1; end
fs = max(12, round(12 * scaleHint));
txt = sprintf('f=%03d', frame0);

% draw with black outline + white text for readability
out = drawTextOutline(out, 1, 1, txt, fs, 1);
end

function I8 = normalizeToUint8(I)
if isa(I,'uint8'), I8 = I; return; end
Id = double(I);
mn = min(Id(:)); mx = max(Id(:));
if mx <= mn
    I8 = uint8(zeros(size(I), 'uint8'));
else
    I8 = uint8(255 * (Id - mn) / (mx - mn));
end
end

function RGB = drawLineRGB(RGB, x1, y1, x2, y2, col, width, alpha)
% drawLineRGB : trace une ligne (x1,y1)->(x2,y2) dans RGB (uint8), sans toolbox.
[h,w,~] = size(RGB);
n = max(abs(x2-x1), abs(y2-y1));
n = max(1, round(n));

xs = round(linspace(x1, x2, n));
ys = round(linspace(y1, y2, n));

r = max(0, floor(width/2));
for k = 1:numel(xs)
    x = xs(k); y = ys(k);
    for dy = -r:r
        for dx = -r:r
            xx = x + dx; yy = y + dy;
            if xx>=1 && xx<=w && yy>=1 && yy<=h
                for c = 1:3
                    RGB(yy,xx,c) = uint8((1-alpha)*double(RGB(yy,xx,c)) + alpha*double(col(c)));
                end
            end
        end
    end
end
end

function RGB = drawTextBig(RGB, x, y, str, fontSize, alpha)
% Draw big ID at (x,y) with outline for readability.
% Uses insertText if available; otherwise fall back to crude bitmap-free method:
% outline via multiple offsets using insertText if available, else use text-to-image workaround.
try
    % insertText expects [x y] in pixels, x horizontal, y vertical
    pos = [x y];
    RGB = drawTextOutline(RGB, pos(1), pos(2), str, fontSize, alpha);
catch
    % If insertText not available, no text drawing (avoid crashing)
end
end

function RGB = drawTextOutline(RGB, x, y, str, fontSize, alpha)
% Best effort: use insertText when available (Computer Vision Toolbox).
% Outline = black offsets, then white on top.
if exist('insertText','file') ~= 2
    error('insertText not available');
end

pos = [x y];
% outline offsets
offs = [-1 -1; -1 0; -1 1; 0 -1; 0 1; 1 -1; 1 0; 1 1] * 2;

for i=1:size(offs,1)
    RGB = insertText(RGB, pos + offs(i,:), str, ...
        'FontSize', fontSize, 'BoxOpacity', 0, 'TextColor', 'black');
end

RGB = insertText(RGB, pos, str, ...
    'FontSize', fontSize, 'BoxOpacity', 0, 'TextColor', 'white');

if alpha < 1
    % crude alpha blend: mix with original not kept; leave as-is
end
end


function M = bridgeComponentsShortest(M, conn, radius)
% Relie les composantes connexes d'un masque binaire en ajoutant
% un pont minimal entre la composante principale et chaque autre.
% radius = 0/1/2... : épaississement du pont (0 = 1 pixel)

if nargin < 2 || isempty(conn), conn = 8; end
if nargin < 3 || isempty(radius), radius = 1; end

CC = bwconncomp(M, conn);
if CC.NumObjects <= 1, return; end

% Label image + composante principale (la plus grande)
L = labelmatrix(CC);
sz = cellfun(@numel, CC.PixelIdxList);
[~, iMain] = max(sz);
mainMask = (L == iMain);

% Pour chaque autre composante: trouver les 2 pixels les plus proches et tracer une ligne
for i = 1:CC.NumObjects
    if i == iMain, continue; end
    otherMask = (L == i);

    % distance transform depuis la main + indices du plus proche pixel main
    [D, idx] = bwdist(mainMask);

    % point dans "other" le plus proche de "main"
    otherIdx = find(otherMask);
    [~, j] = min(D(otherIdx));
    p2 = otherIdx(j);      % pixel dans other
    p1 = idx(p2);          % pixel correspondant le plus proche dans main

    [y1, x1] = ind2sub(size(M), p1);
    [y2, x2] = ind2sub(size(M), p2);

    % tracer ligne (pont minimal)
    rrcc = bresenhamLine(y1, x1, y2, x2, size(M));
    M(rrcc) = true;

    % mettre à jour mainMask pour relier en chaîne proprement
    mainMask = mainMask | otherMask | M;
end

% épaississement optionnel
if radius > 0
    M = imdilate(M, strel('disk', radius, 0));
end
end

function idx = bresenhamLine(y1, x1, y2, x2, sz)
% Retourne les indices linéaires d'une ligne discrète (Bresenham)
h = sz(1); w = sz(2);
x1 = round(x1); x2 = round(x2);
y1 = round(y1); y2 = round(y2);

dx = abs(x2 - x1);
dy = abs(y2 - y1);
sx = sign(x2 - x1); if sx == 0, sx = 1; end
sy = sign(y2 - y1); if sy == 0, sy = 1; end

x = x1; y = y1;
idxList = zeros(max(dx,dy)+1,1,'uint32');
k = 1;

if dx >= dy
    err = dx/2;
    for i = 1:(dx+1)
        if x>=1 && x<=w && y>=1 && y<=h
            idxList(k) = sub2ind([h w], y, x); k = k + 1;
        end
        x = x + sx;
        err = err - dy;
        if err < 0
            y = y + sy;
            err = err + dx;
        end
    end
else
    err = dy/2;
    for i = 1:(dy+1)
        if x>=1 && x<=w && y>=1 && y<=h
            idxList(k) = sub2ind([h w], y, x); k = k + 1;
        end
        y = y + sy;
        err = err - dx;
        if err < 0
            x = x + sx;
            err = err + dy;
        end
    end
end

idx = idxList(1:k-1);
end

function reps = qa_ctc_all(ctcSplitRoot)
d = dir(ctcSplitRoot);
d = d([d.isdir]);
names = {d.name};
names = names(~ismember(names,{'.','..'}));

% keep only pure seq folders (e.g. '12') and drop '*_GT'
isGT = endsWith(names, '_GT');
names = names(~isGT);

% option: only folders that are exactly 2 digits
isSeq = ~cellfun(@isempty, regexp(names, '^\d{2}$', 'once'));
names = names(isSeq);

reps = cell(numel(names),1);
for i=1:numel(names)
    reps{i} = qa_ctc_sequence(fullfile(ctcSplitRoot, names{i}));
end
end



function rep = qa_ctc_sequence(seqDir, varargin)
% qa_ctc_sequence
% QA for one CTC sequence.
%
% seqDir: .../CTC/<seq> (contains raw frames t*.tif). Ground-truth is in:
%   Layout A (sibling): .../CTC/<seq> and .../CTC/<seq>_GT/{TRA,SEG}
%   Layout B (nested) : .../CTC/<seq>/<seq>_GT/{TRA,SEG}
%
% Checks:
%  - ID set equality between man_track.txt (col 1) and TRA masks (unique >0)
%  - time window consistency (start/end vs first/last seen in masks)
%  - parent consistency (parent exists; parent doesn't start after child)
%  - optional: per-id connexity in each frame (slow but robust)
%
% Output:
%  rep struct with fields:
%    seqDir, traDir, segDir, numFrames, issues, connIssues, csvPath, outDir

% =========================
% Parse options
% =========================
p = inputParser;
p.addParameter('write_png', true, @(x)islogical(x)&&isscalar(x));
p.addParameter('png_max_frames', 50, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
p.addParameter('out_dir', fullfile(seqDir, '_QA'), @(s)ischar(s)||isstring(s));
p.addParameter('conn', 8, @(x)isnumeric(x)&&isscalar(x) && any(x==[4 8]));
p.addParameter('check_connex', true, @(x)islogical(x)&&isscalar(x));
p.addParameter('verbose_frames', false, @(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});

% normalize incoming path
seqDir = char(seqDir);

% outDir: FORCE char for exist/mkdir safety
outDir = char(p.Results.out_dir);
if ~exist(outDir,'dir'), mkdir(outDir); end

[seqParent, seqName] = fileparts(seqDir);

% =========================
% Locate TRA/SEG dirs (two layouts)
% =========================
traDirA = fullfile(seqParent, [seqName '_GT'], 'TRA');
segDirA = fullfile(seqParent, [seqName '_GT'], 'SEG');

traDirB = fullfile(seqDir, [seqName '_GT'], 'TRA');
segDirB = fullfile(seqDir, [seqName '_GT'], 'SEG');

if exist(traDirA,'dir')
    traDir = traDirA;  segDir = segDirA;
elseif exist(traDirB,'dir')
    traDir = traDirB;  segDir = segDirB;
else
    error('TRA dir not found. Tried:\n%s\n%s', traDirA, traDirB);
end

txtPath = fullfile(traDir, 'man_track.txt');
if ~exist(txtPath,'file')
    error('man_track.txt not found: %s', txtPath);
end

% =========================
% Read man_track.txt (robust)
% =========================
mt = readmatrix(txtPath, 'FileType','text');
if isempty(mt) || size(mt,2) < 4
    error('man_track.txt must have 4 columns: id start end parent');
end
mt = mt(:,1:4);

% drop NaN rows (trailing blank lines etc.)
mt = mt(~any(isnan(mt),2), :);

gid_txt    = uint32(mt(:,1));
start_txt  = uint32(mt(:,2));
end_txt    = uint32(mt(:,3));
parent_txt = uint32(mt(:,4));

% drop id==0 rows if any
keep = gid_txt > 0;
gid_txt    = gid_txt(keep);
start_txt  = start_txt(keep);
end_txt    = end_txt(keep);
parent_txt = parent_txt(keep);

idsTxtU = unique(gid_txt(:));
idsTxtU(idsTxtU==0) = [];
idsTxtU = sort(idsTxtU);

maxTxtId = 0;
if ~isempty(idsTxtU), maxTxtId = double(max(idsTxtU)); end

% =========================
% List TRA frames and infer T
% =========================
traList = dir(fullfile(traDir, 'man_track*.tif'));
if isempty(traList)
    error('No man_track*.tif in %s', traDir);
end

fnums = nan(numel(traList),1);
for k=1:numel(traList)
    tok = regexp(traList(k).name, 'man_track(\d+)\.tif$', 'tokens', 'once');
    if ~isempty(tok)
        fnums(k) = str2double(tok{1});
    end
end
fnums = fnums(~isnan(fnums));
if isempty(fnums)
    error('Could not parse any man_track###.tif filenames in %s', traDir);
end
T = max(fnums) + 1;

% =========================
% Scan TRA masks: first/last seen, ids set, optional connexity
% =========================
firstSeen   = containers.Map('KeyType','uint32','ValueType','uint32');
lastSeen    = containers.Map('KeyType','uint32','ValueType','uint32');
ids_in_imgs = containers.Map('KeyType','uint32','ValueType','logical');

issues = {};
connIssues = []; % rows: [gid frame0 numComponents]

for f0 = uint32(0):uint32(T-1)
    pTra = fullfile(traDir, sprintf('man_track%03d.tif', f0));
    if ~exist(pTra,'file')
        issues(end+1,:) = { "missing_frame_tif", double(f0), "", "" }; %#ok<AGROW>
        continue
    end

    I = imread(pTra);
    ids = unique(uint32(I(:)));
    ids(ids==0) = [];

    for g = uint32(ids(:))'
        ids_in_imgs(g) = true;
        if ~isKey(firstSeen, g), firstSeen(g) = f0; end
        lastSeen(g) = f0;
    end

    if p.Results.check_connex && ~isempty(ids)
        idsU = uint32(ids(:))';
        for g = idsU
            M = (I == g);
            CC = bwconncomp(M, p.Results.conn);
            if CC.NumObjects > 1
                connIssues = [connIssues; double([g f0 CC.NumObjects])]; %#ok<AGROW>
            end
        end
    end

    if p.Results.verbose_frames
        mx = double(max(I(:)));
        if mx > 0
            fprintf('  frame %03d: max_id=%d, n_ids=%d\n', f0, mx, numel(ids));
        end
    end
end

idsImgU = uint32(cell2mat(keys(ids_in_imgs)));
idsImgU = unique(idsImgU(:));
idsImgU(idsImgU==0) = [];
idsImgU = sort(idsImgU);

maxImgId = 0;
if ~isempty(idsImgU), maxImgId = double(max(idsImgU)); end

% =========================
% C1: ID set equality checks (TXT vs TIF)
% =========================
extra_in_tif   = setdiff(idsImgU, idsTxtU);
missing_in_tif = setdiff(idsTxtU, idsImgU);

for i=1:numel(extra_in_tif)
    issues(end+1,:) = { "id_in_tif_not_in_txt", double(extra_in_tif(i)), "", "" }; %#ok<AGROW>
end
for i=1:numel(missing_in_tif)
    issues(end+1,:) = { "id_in_txt_not_in_tif", double(missing_in_tif(i)), "", "" }; %#ok<AGROW>
end

% =========================
% C2: time window mismatch
% =========================
for i=1:numel(gid_txt)
    g = gid_txt(i);
    if isKey(firstSeen, g)
        fs = firstSeen(g);
        ls = lastSeen(g);
        if fs ~= start_txt(i) || ls ~= end_txt(i)
            issues(end+1,:) = { ...
                "time_window_mismatch", double(g), ...
                sprintf("txt=[%d,%d]", start_txt(i), end_txt(i)), ...
                sprintf("tif=[%d,%d]", fs, ls) ...
                }; %#ok<AGROW>
        end
    end
end

% =========================
% C3: parent checks
% =========================
gidToRow = containers.Map('KeyType','uint32','ValueType','uint32');
for i=1:numel(gid_txt)
    if ~isKey(gidToRow, gid_txt(i))
        gidToRow(gid_txt(i)) = uint32(i);
    end
end

for i=1:numel(gid_txt)
    g = gid_txt(i);
    pId = parent_txt(i);
    if pId > 0
        if ~isKey(gidToRow, pId)
            issues(end+1,:) = { "parent_missing_in_txt", double(g), sprintf("parent=%d",pId), "" }; %#ok<AGROW>
        else
            ip = gidToRow(pId);
            if start_txt(i) < start_txt(ip)
                issues(end+1,:) = { ...
                    "parent_starts_after_child", double(g), ...
                    sprintf("child_start=%d", start_txt(i)), ...
                    sprintf("parent=%d parent_start=%d", pId, start_txt(ip)) ...
                    }; %#ok<AGROW>
            end
        end
    end
end

% =========================
% C4: connexity issues
% =========================
if ~isempty(connIssues)
    for r=1:size(connIssues,1)
        issues(end+1,:) = { ...
            "non_connex_id", connIssues(r,1), ...
            sprintf("frame=%d", connIssues(r,2)), ...
            sprintf("components=%d", connIssues(r,3)) ...
            }; %#ok<AGROW>
    end
end

% =========================
% Write CSV report
% =========================
rep = struct();
rep.seqDir = seqDir;
rep.traDir = traDir;
rep.segDir = segDir;
rep.numFrames = T;
rep.issues = issues;
rep.connIssues = connIssues;
rep.outDir = outDir;

csvPath = fullfile(outDir, sprintf('%s_QA.csv', seqName));
rep.csvPath = csvPath;

if isempty(issues)
    writematrix(["OK"], csvPath);
else
    Tiss = cell2table(issues, 'VariableNames', {'type','id','a','b'});
    writetable(Tiss, csvPath);
end

% =========================
% Optionally write PNGs for problematic frames
% =========================
if p.Results.write_png && ~isempty(connIssues)
    framesBad = unique(uint32(connIssues(:,2)));
    framesBad = framesBad(1:min(numel(framesBad), p.Results.png_max_frames));
    for k=1:numel(framesBad)
        f0 = framesBad(k);
        pTra = fullfile(traDir, sprintf('man_track%03d.tif', f0));
        if ~exist(pTra,'file'), continue; end
        I = imread(pTra);
        try
            J = label2rgb(uint16(I), 'jet', 'k', 'shuffle');
            imwrite(J, fullfile(outDir, sprintf('bad_conn_frame_%03d.png', f0)));
        catch
            % If IPT missing, skip PNG
        end
    end
end

% =========================
% Console summary (single source of truth)
% =========================
fprintf('\n=== QA %s ===\n', seqName);
fprintf('Frames: %d\n', T);
fprintf('IDs in txt(unique): %d | IDs in tif(unique): %d\n', numel(idsTxtU), numel(idsImgU));
fprintf('max_txt=%d | max_tif=%d\n', maxTxtId, maxImgId);
fprintf('extra_in_tif=%d | missing_in_tif=%d\n', numel(extra_in_tif), numel(missing_in_tif));

if isempty(extra_in_tif)
    fprintf('  ✅ extra_in_tif: none\n');
else
    fprintf('  ❌ extra_in_tif (first 20): %s\n', mat2str(double(extra_in_tif(1:min(20,end)))'));
end

if isempty(missing_in_tif)
    fprintf('  ✅ missing_in_tif: none\n');
else
    fprintf('  ❌ missing_in_tif (first 20): %s\n', mat2str(double(missing_in_tif(1:min(20,end)))'));
end

fprintf('Issues: %d\n', size(issues,1));
if ~isempty(issues)
    types = string(issues(:,1));
    u = unique(types);
    for i=1:numel(u)
        fprintf('  - %s : %d\n', u(i), sum(types==u(i)));
    end
end
fprintf('CSV: %s\n', csvPath);
fprintf('OUT: %s\n\n', outDir);

end
