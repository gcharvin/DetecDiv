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
p.parse(varargin{:});
layoutMode = string(p.Results.layoutMode);
layoutMode = lower(layoutMode);

if ~ismember(layoutMode, ["ctc_root","split_root"])
    error('layoutMode must be "ctc_root" or "split_root".');
end

% ===== Mode de division (flag temporaire; pourra être passé en argument plus tard) =====
% 'symmetric' pour dataset type MOMA ; 'asymmetric' pour bourgeonnement
division_mode = 'symmetric';

layoutMode="split_root";
%layoutMode="ctc_root"
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

                    if ~isempty(motherOf) && isKey(motherOf, int32(id)) && ~isKey(childAllowedStart, key)
                        childAllowedStart(key) = frame0 + 1;

                        motherId  = uint32(motherOf(int32(id)));
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

                    if ~isempty(motherOf) && isKey(motherOf, int32(id)) ...
                            && isKey(childAllowedStart, key) ...
                            && frame0 < childAllowedStart(key)
                        continue;
                    end

                    segMask(pixz) = uint16(id + kk);

                    parent_gid = uint32(0);
                    need_new_gid = ~isKey(local2global, key);

                    if need_new_gid
                        if isKey(motherPendingParent, key)
                            info = motherPendingParent(key);
                            if frame0 >= info.validFrom
                                parent_gid = info.gid;
                            end
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

    end
end

% === Mapping ROI → séquence
fid = fopen(mappingFile, 'w');
fprintf(fid, '%s\n', mappingLines{:});
fclose(fid);

fprintf('✅ Export CTC terminé (layout=%s) : %d frames exportées.\n', layoutMode, output);

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
