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
p.parse(varargin{:});
mergeBudN = uint32(p.Results.mergeBudN);
mergeBudN = 0 ;

layoutMode = string(p.Results.layoutMode);
layoutMode = lower(layoutMode);

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
momaRoot = fullfile(classif.path, foldername, 'moma');
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
end % frames


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
try
    outMp4 = fullfile(splitBase, sprintf('%s_overlay.mp4', seqName));
    makeOverlayMovieFromCTC(imgDir, traDir, outMp4, trackTable);
catch ME
    warning('Overlay movie failed for %s/%s: %s', splitName, seqName, ME.message);
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

% ---- rendu / qualité
alphaFill   = 0.75;   % plus opaque => masque bien visible
frameRate   = 10;

useContrast = true;
prcLow  = 1;
prcHigh = 99.8;
gamma   = 0.9;

% ---- liens mère/bud
drawLinks   = true;
linkAlpha   = 1;
linkWidth   = 1;      % épaisseur du trait

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
    % une seule entrée par gid (normalement)
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

    if ~exist(pTra,'file')
        writeVideo(v, out);
        continue;
    end

    Itra = imread(pTra); % uint16 gids
    mask = Itra > 0;

    % ---- overlay par ID (remplissage uniquement)
    if any(mask(:))
        id = double(Itra);

        col = zeros([size(Itra) 3], 'double');
        for c = 1:3
            tmp = zeros(size(Itra), 'double');
            idx = id(mask);
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

    % ---- centroïdes par gid (rapide via accumarray)
    if drawLinks && ~isempty(parentOf) && any(mask(:))
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

        % tracer liens child->mother (si parent connu et centroids dispo)
        childList = find(present);
        for ii = 1:numel(childList)
            child = childList(ii);
            if child > numel(parentOf), continue; end
            mom = double(parentOf(child));
            if mom <= 0 || mom > maxId, continue; end

            if ~isnan(lastX(child)) && ~isnan(lastX(mom))
                % couleur du child
                colLine = uint8([255 255 255]); % blanc
                out = drawLineRGB(out, lastX(mom), lastY(mom), lastX(child), lastY(child), colLine, linkWidth, linkAlpha);
            end
        end
    end

    writeVideo(v, out);
end

close(v);
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
% col : 1x3 uint8, width: épaisseur, alpha: opacité du trait

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


