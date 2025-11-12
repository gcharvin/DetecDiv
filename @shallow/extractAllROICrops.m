function extractAllROICrops(shallowObj, varargin)
% extractAllROICrops — version "streaming append HDF5" (FOV & Channels & RAM-aware)
%
% Usage:
%   extractAllROICrops(shallowObj)
%   extractAllROICrops(shallowObj, 'Frames', 1:100)
%   extractAllROICrops(shallowObj, 'FOVIndex', [1 3 5], 'Channels', {'GFP','RFP'})
%
% - Lit la FOV par blocs (taille de bloc T choisie automatiquement selon la RAM)
% - Crops chaque ROI
% - Append les blocs directement dans im_<roi.id>.h5 (sans réécrire l'historique)
%
% Hypothèses côté roi.save():
%   - save(obj, requestedChannels) appelle upsertH5Dataset_frames (append sur T)
%   - "" (chaîne vide) déclenche un full save => on évite !
%
% Nouveautés:
%   - 'FOVIndex' : array d'indices de FOV à traiter (par défaut: toutes)
%   - 'Channels' : cellstr des noms logiques à extraire (par défaut: tous)
%   - Taille de bloc temporel auto en fonction de la RAM disponible.

% ----------------- PARAMS -----------------
FrameList      = [];
FOVIndex       = [];         % [] => toutes
RequestedChans = {};         % {} => tous
ROISelect      = [];         % [] => toutes (par FOV), peut être numeric ou cell array

% --- OPTIONS DIVERSES ---
ForceChannelNames = true;    % impose les noms de canaux des ROI = chanSelNames
Extend            = false;   % false = hard reset ; true = append/prolong

% --- DRIFT CORRECTION OPTIONS ---
CorrectDrift      = false;    % active ou non la correction
DriftChannel      = [];       % canal utilisé pour l'estimation du drift
DriftMethod       = 'circshift'; % 'circshift' | 'subpixel' | 'register'
DriftRefLocal     = 1;
DriftSubpixel     = false;    % subpixel shift
DriftMaxShift     = 20;       % px, [] = pas de limite
DriftHipassSigma  = 3;        % 0 = off
DriftApodize      = true;     % fenêtre Hann
DriftRollingRef   = 0;        % 0..1, 0 = off
DriftPyrLevels    = 1;        % niveaux pyramide, 1 = off
DriftMask         = [];       % masque optionnel (HxW logique)

% ----------------- PARSING -----------------
for i = 1:2:numel(varargin)
    key = lower(string(varargin{i}));
    switch key
        case "frames"
            FrameList = varargin{i+1};
        case "fovindex"
            FOVIndex = varargin{i+1};
        case "channels"
            RequestedChans = varargin{i+1};
        case "forcechannelnames"
            ForceChannelNames = logical(varargin{i+1});
        case "extend"
            Extend = logical(varargin{i+1});
        case "correctdrift"
            CorrectDrift = logical(varargin{i+1});
        case "driftchannel"
            DriftChannel = varargin{i+1};
        case "driftreflocal"
            DriftRefLocal = varargin{i+1};
        case "driftmethod"
            DriftMethod = char(varargin{i+1});
        case "driftsubpixel"
            DriftSubpixel = logical(varargin{i+1});
        case "driftmaxshift"
            DriftMaxShift = varargin{i+1};
        case "drifthipasssigma"
            DriftHipassSigma = varargin{i+1};
        case "driftapodize"
            DriftApodize = logical(varargin{i+1});
        case "driftrollingref"
            DriftRollingRef = varargin{i+1};
        case "driftpyramidlevels"
            DriftPyrLevels = varargin{i+1};
        case "driftmask"
            DriftMask = varargin{i+1};
        case "roi"
            ROISelect = varargin{i+1};  % numeric (appliqué à chaque FOV) ou cell array par FOV
    end
end

% ----------------- CHECK FOVS -----------------
if ~isprop(shallowObj,'fov') || isempty(shallowObj.fov)
    disp('⚠️  No FOV found in shallow object.');
    return;
end

% Liste des FOV à parcourir
allFOV = 1:numel(shallowObj.fov);
if ~isempty(FOVIndex)
    FOVIndex = FOVIndex(:)';          % row
    FOVIndex = intersect(allFOV, FOVIndex);
else
    FOVIndex = allFOV;
end
if isempty(FOVIndex)
    disp('⚠️  Provided FOVIndex contains no valid indices. Nothing to do.');
    return;
end

fprintf('\n=============================================\n');
fprintf('  🧩 ROI Extraction (HDF5 append) Started\n');
fprintf('  → FOV to process: %s\n', mat2str(FOVIndex));

% ----------------- NORMALISATION ARGS PAR FOV -----------------
nF = numel(FOVIndex);

% 1) Channels → ChannelsPerFOV (1xNfov cell ; chaque entrée = cellstr des noms ou [])
ChannelsPerFOV = cell(1, nF);
if isempty(RequestedChans)
    ChannelsPerFOV(:) = {{}};
elseif nF == 1
    tmp = RequestedChans;
    if iscell(tmp) && ~isempty(tmp) && iscell(tmp{1})
        tmp = tmp{1};
    end
    if iscell(tmp)
        ChannelsPerFOV{1} = cellfun(@char, string(tmp), 'UniformOutput', false);
    elseif isstring(tmp)
        ChannelsPerFOV{1} = cellstr(tmp);
    elseif ischar(tmp)
        ChannelsPerFOV{1} = {tmp};
    else
        ChannelsPerFOV{1} = tmp; % indices numériques éventuels -> convertis plus tard
    end
else
    tmp = RequestedChans;
    if iscell(tmp) && numel(tmp) == nF && iscell(tmp{1})
        for ii = 1:nF
            ChannelsPerFOV{ii} = cellfun(@char, string(tmp{ii}), 'UniformOutput', false);
        end
    else
        if iscell(tmp)
            one = cellfun(@char, string(tmp), 'UniformOutput', false);
        elseif isstring(tmp)
            one = cellstr(tmp);
        elseif ischar(tmp)
            one = {tmp};
        else
            one = tmp; % indices
        end
        ChannelsPerFOV(:) = {one};
    end
end

% 2) Frames → FrameListPerFOV (1xNfov cell ; chaque entrée = numeric row vector ou [])
FrameListPerFOV = cell(1, nF);
if isempty(FrameList)
    FrameListPerFOV(:) = {[]};   % [] = toutes les frames
elseif nF == 1
    v = FrameList;
    if iscell(v),    v = v{1}; end
    if isstring(v),  v = double(v); end
    if islogical(v), v = find(v);   end
    FrameListPerFOV{1} = v(:)';     % row vector
else
    if iscell(FrameList) && numel(FrameList) == nF
        for ii = 1:nF
            v = FrameList{ii};
            if isstring(v),  v = double(v); end
            if islogical(v), v = find(v);   end
            FrameListPerFOV{ii} = v(:)';    % row
        end
    else
        v = FrameList;
        if iscell(v),    v = v{1}; end
        if isstring(v),  v = double(v); end
        if islogical(v), v = find(v);   end
        v = v(:)';
        FrameListPerFOV(:) = {v};
    end
end

% ----------------- LOG CANAUX DEMANDÉS -----------------
fprintf('  → Requested channels per FOV:\n');
for ii = 1:nF
    ci = ChannelsPerFOV{ii};
    try
        if isempty(ci)
            fprintf('    - FOV %d: {ALL}\n', FOVIndex(ii));
        elseif iscell(ci)
            names = cellfun(@char, string(ci), 'UniformOutput', false);
            fprintf('    - FOV %d: {%s}\n', FOVIndex(ii), strjoin(names, ', '));
        elseif isstring(ci)
            fprintf('    - FOV %d: {%s}\n', FOVIndex(ii), strjoin(cellstr(ci), ', '));
        elseif ischar(ci)
            fprintf('    - FOV %d: {%s}\n', FOVIndex(ii), ci);
        else
            fprintf('    - FOV %d: {indices}\n', FOVIndex(ii));
        end
    catch
        fprintf('    - FOV %d: (unprintable channels arg)\n', FOVIndex(ii));
    end
end
fprintf('=============================================\n');

% ====== Qualifier la RAM dispo + classe d'échantillon en amont ======

% ====== Qualifier la RAM dispo + classe d'échantillon en amont ======
[availBytes, fallbackReason] = getAvailableMemoryBytes();
if ~isempty(fallbackReason)
    fprintf('   (mem) %s\n', fallbackReason);
end


% =============== LOOP OVER SELECTED FOV ===============
pbFOV = makeConsolePB('FOV', numel(FOVIndex), 'Indent',0);

for kF = 1:numel(FOVIndex)
    iFov  = FOVIndex(kF);
    fovObj = shallowObj.fov(iFov);


    % Lien parent ROI <-> FOV
    roiList = getprop(fovObj,'roi',[]);
    if ~isempty(roiList)
        for rIdx = 1:numel(roiList)
            if isempty(roiList(rIdx).parent)
                roiList(rIdx).parent = fovObj;
            end
        end
    end

      % --- NEW: restreindre la liste selon ROISelect pour CE FOV ---
    selIdx = resolveROISelectionForFOV(roiList, ROISelect, kF, FOVIndex);
    if isempty(selIdx)
        fprintf('\n▶ FOV %d/%d — no selected ROI, skipped.\n', kF, numel(FOVIndex));
        continue;
    end
    roiList = roiList(selIdx);   % on garde uniquement les ROIs choisies

    if isempty(roiList)
        fprintf('\n▶ FOV %d/%d — no ROI, skipped.\n', kF, numel(FOVIndex));
        continue;
    end

    % Infos temporelles / canaux pour la FOV
    [nFramesTotal, nChannels, sampleClass] = inferFOVTimeline(fovObj);

 
    % ---------- CANAUX POUR CETTE FOV ----------
% Noms de canaux disponibles dans la FOV (forcer en cellstr)
chanNamesFOV = getFOVChannelNames(fovObj, nChannels);
chanNamesFOV = cellfun(@char, string(chanNamesFOV), 'UniformOutput', false);

% Récupérer l'argument canaux pour CETTE FOV
chans_for_this_fov = ChannelsPerFOV{kF};

if isempty(chans_for_this_fov)
    % Aucun filtre demandé -> tous
    chanSelIdx   = 1:nChannels;
    chanSelNames = chanNamesFOV;
else
    % Construire la liste de noms demandés "names_req" (cellstr)
    if isnumeric(chans_for_this_fov) || islogical(chans_for_this_fov)
        idx = chans_for_this_fov;
        if islogical(idx), idx = find(idx); end
        names_req = chanNamesFOV(idx);
    elseif iscell(chans_for_this_fov)
        names_req = cellfun(@char, string(chans_for_this_fov), 'UniformOutput', false);
    elseif isstring(chans_for_this_fov)
        names_req = cellstr(chans_for_this_fov);
    elseif ischar(chans_for_this_fov)
        names_req = {chans_for_this_fov};
    else
        % Cas exotique: tentative de conversion générique
        names_req = cellfun(@char, string(chans_for_this_fov), 'UniformOutput', false);
    end

    % Faire correspondre aux canaux de la FOV
    [isHit, idx] = ismember(names_req, chanNamesFOV);  % <-- plus de RequestedChans ici
    if any(~isHit)
        miss = names_req(~isHit);
        warning('⚠ Some requested channels not found in FOV: {%s}', strjoin(miss, ', '));
    end
    idx = idx(isHit);
    if isempty(idx)
        fprintf('\n▶ FOV %d/%d — none of the requested channels present, skipped.\n', kF, numel(FOVIndex));
        continue;
    end
    chanSelIdx   = idx(:)';
    chanSelNames = chanNamesFOV(chanSelIdx);
end

Csel = numel(chanSelIdx);

 
    % --- Frames pour CETTE FOV (robuste à cell/string/logical) ---
    frames_for_this_fov = FrameListPerFOV{kF};
    
    if isempty(frames_for_this_fov)
    framesToDo = 1:nFramesTotal;
    else
    v = frames_for_this_fov;
    if iscell(v),    v = v{1};    end   % cell -> contenu
    if isstring(v),  v = double(v); end % string -> numeric
    if islogical(v), v = find(v);   end % logical mask -> indices
    v = double(v(:)');                   % row vector numeric
    if isempty(v)
        framesToDo = 1:nFramesTotal;
    else
        framesToDo = v(v >= 1 & v <= nFramesTotal);
        if isempty(framesToDo)
            disp('   ⚠️  Frame list outside range, skipping this FOV.');
            continue;
        end
    end
    end
    
    nFramesThisRun = numel(framesToDo);


    % ID FOV & dossier de sortie
    fovId     = safeStr(getprop(fovObj,'id',sprintf('FOV_%d',iFov)));
    fovOutDir = getFOVOutputPath(shallowObj, fovObj, fovId);
    fprintf('\n▶ FOV %d/%d (%s) — %d frame(s) × %d channel(s) [selected %d]\n', ...
        kF, numel(FOVIndex), fovId, nFramesThisRun, nChannels, Csel);
    fprintf('   Output dir: %s\n', fovOutDir);

    % -------- Préparer les ROI (path + display minimal + bbox) --------
    nROI = numel(roiList);

    ROI = struct('obj',[],'bbox',[],'h',0,'w',0,'id','', 'chanNames',{{}});
    ROI(nROI).obj = [];
    for rIdx = 1:nROI
        r = roiList(rIdx);

        ROI(rIdx).obj = r;
        ROI(rIdx).id  = safeStr(getprop(r,'id',sprintf('%s_ROI_%02d',fovId,rIdx)));
        ROI(rIdx).didInit = false;

        % Path projet/FOV
        r.path = fovOutDir;

        % BBox
        v = getprop(r,'value',[]);
        if isempty(v) || size(v,2) < 4
            ROI(rIdx).bbox = []; ROI(rIdx).h = 0; ROI(rIdx).w = 0;
            ROI(rIdx).mobile = false;
            ROI(rIdx).bboxPerFrame = [];
        else
            if size(v,1) == 1
                % Fixe
                ROI(rIdx).mobile = false;
                ROI(rIdx).bbox = struct('xmin',v(1), 'ymin',v(2), 'w',v(3), 'h',v(4));
                ROI(rIdx).w = v(3); ROI(rIdx).h = v(4);
            else
                % Mobile (N×4)
                ROI(rIdx).mobile = true;
                ROI(rIdx).bboxPerFrame = v(:,1:4);

                % LIRE fixed_wh & frames dans ds=userData du dataseries EXISTANT
                fixed_wh = [];
                framesUD = [];
                try
                    if isprop(r,'data') && ~isempty(r.data) && isprop(r.data,'userData') && ~isempty(r.data.userData)
                        ud = r.data.userData;
                        if isfield(ud,'fixed_wh') && numel(ud.fixed_wh)==2
                            fixed_wh = ud.fixed_wh;
                        end
                        if isfield(ud,'frames') && ~isempty(ud.frames)
                            framesUD = ud.frames;
                        end
                    end
                catch, end

                if isempty(fixed_wh), fixed_wh = [v(1,3), v(1,4)]; end

                ROI(rIdx).w = fixed_wh(1);
                ROI(rIdx).h = fixed_wh(2);

                ROI(rIdx).bbox = struct('xmin',v(1,1),'ymin',v(1,2),'w',ROI(rIdx).w,'h',ROI(rIdx).h);
                ROI(rIdx).frames_abs = framesUD; % peut être []
            end
        end

        % Display minimal si absent, puis on stocke les noms FOV complets (pour cohérence)
        if ~isstruct(r.display) || ~isfield(r.display,'channel') || isempty(r.display.channel)
            r.display = defaultDisplay(numel(chanNamesFOV), numel(chanNamesFOV));
            r.display.channel = chanNamesFOV;
        end
        ROI(rIdx).chanNames = r.display.channel;

        % channelid trivial sur base FOV complète ; sera réajusté si ForceChannelNames
        if isempty(r.channelid) || numel(r.channelid) ~= numel(chanNamesFOV)
            r.channelid = 1:numel(chanNamesFOV);
        end

        % Ecrire retour dans l'objet
        roiList(rIdx) = r;
    end

    % --- AFTER the loop that fills ROI(...) and updates roiList(rIdx) = r;
    %     We now have: chanSelNames, Csel, fovOutDir defined.

    for rIdx = 1:nROI
        r = roiList(rIdx);
        if ~isprop(r,'id') || isempty(r.id), r.id = ROI(rIdx).id; end
        r.path = fovOutDir;
        if isprop(r,'h5path'),  r.h5path  = fullfile(fovOutDir, sprintf('im_%s.h5',  r.id)); end
        if isprop(r,'matpath'), r.matpath = fullfile(fovOutDir, sprintf('data_%s.mat',r.id)); end

        if ~Extend
            % HARD RESET (inchangé)
            hardResetROIh5(r);
            r.image     = [];
            r.channelid = 1:Csel;
            r.display   = defaultDisplay(Csel, Csel);
            r.display.channel = chanSelNames(:)';
            ROI(rIdx).didInit = true;
        else
            % EXTEND: lire canaux existants et ordonner chanSelNames en conséquence
            [h5p, ~] = getROIFilePaths(r);
            existing = listH5Channels(h5p); % ex: ["Channel0","Channel1","Channel2"]
            if isempty(existing)
                % Pas de fichier/datasets → on se comporte comme un hard reset implicite (sans delete)
                r.image     = [];
                r.channelid = 1:Csel;
                if ForceChannelNames
                    r.display = defaultDisplay(Csel, Csel);
                    r.display.channel = chanSelNames(:)';
                end
                ROI(rIdx).didInit = true;
            else
                % On restreint et ORDRE = celui du fichier !
                req = string(chanSelNames);
                keep = existing(ismember(existing, req));
                if isempty(keep)
                    warning('ROI %s: none of requested channels exist in H5 → nothing to append.', r.id);
                else
                    % impose l'ordre fichier pour éviter "1 canal seulement"
                    chanSelNames = cellstr(keep); %#ok<NASGU>  % IMPORTANT: écrase pour la suite !
                    Csel = numel(keep);
                    % aligne l'affichage
                    if ForceChannelNames
                        r = normalizeROIChannels(r, chanSelNames);
                    end
                    ROI(rIdx).didInit = true;
                end
            end
        end

        roiList(rIdx) = r;
    end

    [h5p, matp] = getROIFilePaths(roiList(rIdx));
    fprintf('   ROI %d: id=%s\n', rIdx, roiList(rIdx).id);
    fprintf('           H5=%s\n', h5p);
    fprintf('           MAT=%s\n', matp);
    if ~Extend
        fprintf('           (hard reset ON)\n');
    else
        fprintf('           (extend mode)\n');
    end

    % -------- Estimation mémoire & taille de bloc temporel --------
    % Lire une image témoin pour H,W et bytes/sample
    [H,W,sampleBytes] = probeFrameSpec(fovObj, chanSelIdx(1));

    % Mémoire à réserver par bloc : FOV-block ~ H*W*Csel*Tblock*sampleBytes
    % On garde une marge (overhead MATLAB + crops) : on cible ~25% de la RAM libre
    perBlockBudget = max(64e6, 0.25 * double(availBytes)); % >=64MB, sinon trop petit
    Tblock_auto    = max(1, floor(perBlockBudget / double(H*W*Csel*sampleBytes)));
    % Sécurité : pas plus que les frames restantes, pas moins que 1
    Tblock_auto    = max(1, min(Tblock_auto, nFramesThisRun));

    % Découpage en blocs
    frameStarts = 1:Tblock_auto:nFramesThisRun;
    nBlocks     = numel(frameStarts);
    fprintf('   RAM avail ~ %.1f GB → Tblock=%d (H=%d,W=%d,Csel=%d,class=%s)\n', ...
        double(availBytes)/1e9, Tblock_auto, H, W, Csel, sampleClass);

    pbBlk = makeConsolePB(sprintf('  FOV %d/%d — blocs', kF, numel(FOVIndex)), nBlocks, 'Indent',2);

    % -------- Progression --------
    doneFrames  = 0;
    totalFrames = nFramesThisRun;
    % fprintf('      Loading frames  %s\n', progressBarString(doneFrames,totalFrames));
    % fprintf('      Cropping ROIs   %s\n', progressBarString(doneFrames,totalFrames));

    % --------- Boucle bloc par bloc ---------
    for ib = 1:nBlocks
        fs = frameStarts(ib);
        fe = min(fs+Tblock_auto-1, nFramesThisRun);

        localRange = fs:fe;                 % indices temps locaux (dans framesToDo)
        frameBatch = framesToDo(localRange);% frames absolues
        Tblock     = numel(localRange);

        pbFrm = makeConsolePB(sprintf('    Bloc %d/%d — frames', ib, nBlocks), Csel*Tblock, 'Indent',4);

        % 1) Lire bloc sur la FOV : [H W Csel Tblock]
        blockImg = loadFOVBlock_readImage( ...
            fovObj, frameBatch, chanSelIdx, ...
            @(it,NT,msg) pbFrm.update(it, msg) );


        if CorrectDrift
            disp('Computing drift....');

            [blockImg, driftBlk, scoreBlk] = fovObj.computeDrift('images', blockImg,  ...
                'channel',      DriftRefLocal, ...   % index local 1..Csel
                'framesid',     frameBatch, ...      % frames absolues
                'refframeid',   frameBatch(1), ...
                'method',       DriftMethod, ...
                'subpixel',     DriftSubpixel, ...
                'maxshift',     DriftMaxShift, ...
                'hipasssigma',  DriftHipassSigma, ...
                'apodize',      DriftApodize, ...
                'rollingref',   DriftRollingRef, ...
                'mask',         DriftMask, ...
                'crop',         1.0 ...              % ou 0.8 si tu veux un recentrage robuste
                );

            % journalise dans fovObj.drift (fusion remplaçante)
            if ~isfield(fovObj,'drift') || ~isstruct(fovObj.drift)
                fovObj.drift = struct('frames',[],'dx',[],'dy',[],'score',[]);
            end
            [allF, ia] = union(fovObj.drift.frames, frameBatch(:)');
            dxNew = nan(1, numel(allF)); dyNew = dxNew; scNew = dxNew;

            [~,locOld] = ismember(fovObj.drift.frames, allF);
            dxNew(locOld) = fovObj.drift.x;
            dyNew(locOld) = fovObj.drift.y;
            scNew(locOld) = getfield(fovObj.drift, 'score', nan(size(fovObj.drift.x))); %#ok<GFLD>

            [~,locNew] = ismember(frameBatch(:)', allF);
            dxNew(locNew) = driftBlk.x(frameBatch);
            dyNew(locNew) = driftBlk.y(frameBatch);
            scNew(locNew) = scoreBlk(:)';

            tmp=fovObj.drift

            fovObj.drift.frames = allF;
            fovObj.drift.x      = dxNew;
            fovObj.drift.y      = dyNew;
            fovObj.drift.score  = scNew;
        end


        pbFrm.close();


        % 2) Crops + Append immédiat ROI par ROI
        for rIdx = 1:nROI
            r  = ROI(rIdx).obj;
            bb = ROI(rIdx).bbox;

            if isempty(bb)
                fprintf('   • ROI %d/%d (%s): invalid bbox → skipped\n', rIdx, nROI, ROI(rIdx).id);
                continue;
            end


            % --- Crops du bloc en [h w Csel Tblock]
            h = ROI(rIdx).h; w = ROI(rIdx).w;


               % --- BEGIN: Extend idempotent guard (skip if block fully ≤ T_exist) ---
            if Extend
                % Détermine un dataset existant pour estimer T_exist
                h5File = fullfile(fovOutDir, sprintf('im_%s.h5', r.id));
                T_exist = 0;
                if isfile(h5File)
                    try
                        existingCh = listH5Channels(h5File);
                        if ~isempty(existingCh)
                            % on prend le premier canal demandé qui existe réellement
                            req = string(chanSelNames);
                            firstHit = intersect(req, existingCh, 'stable');
                            if ~isempty(firstHit)
                                dsPath = "/" + firstHit(1);
                                info   = h5info(h5File, char(dsPath));
                                if numel(info.Dataspace.Size) >= 4
                                    T_exist = info.Dataspace.Size(4); % [H W k T]
                                end
                            end
                        end
                    catch
                        % si h5info échoue (fichier temporairement lock), on laisse T_exist=0
                    end
                end
        
                if ~isempty(frameBatch) && max(frameBatch) <= T_exist
                    % Tout le bloc est déjà écrit → no-op pour cette ROI
                    fprintf('   • ROI %d/%d (%s): Extend noop (T_exist=%d, frames %d–%d) → skipped block\n', ...
                        rIdx, nROI, ROI(rIdx).id, T_exist, frameBatch(1), frameBatch(end));
                    continue; % passe à la ROI suivante pour ce bloc
                end
                % (cas "mixte" partiel > T_exist: on ne tranche pas ici; on laisse
                %  la logique actuelle écrire tout le bloc. Ça suffira à régler le
                %  cas "2ᵉ fois exactement les mêmes frames", qui est le problème.)
            end


            roiBlock = zeros(h, w, Csel, Tblock, sampleClass);

            for it = 1:Tblock
                bb_now = pickBBoxForFrame(ROI(rIdx), frameBatch(it), it, framesToDo);
                for ic = 1:Csel
                    roiBlock(:,:,ic,it) = cropWithPad(blockImg(:,:,ic,it), bb_now(1), bb_now(2), w, h);
                end
            end

            % Sauvegarde append: on passe UNIQUEMENT le bloc courant
            r.image     = roiBlock;          % [h w Csel Tblock]
            r.channelid = 1:Csel;            % 1 logique par canal sélectionné

            if ~isstruct(r.display) || ~isfield(r.display,'channel') || isempty(r.display.channel)
                r.display = defaultDisplay(Csel, Csel);
                r.display.channel = chanNamesFOV; % base complète (on filtra à l'appel)
            end

            r.path = fovOutDir;

            % -- Normalisation des noms de canaux de la ROI pour coller à chanSelNames --
            if ForceChannelNames
                % On force la ROI à adopter EXACTEMENT les noms demandés pour cette extraction
                r.display.channel = chanSelNames;   % ex. {'GFP','RFP'}

                r.channelid       = 1:Csel;         % mapping 1:1 avec roiBlock(:,:,ic,:)
            else
                % Si on ne force pas, on vérifie que tous les noms demandés existent côté ROI
                [ok,~] = ismember(chanSelNames, r.display.channel);
                if ~all(ok)
                    warning('ROI %s: requested channels not present in ROI.display.channel and ForceChannelNames=false → skipping write.', ROI(rIdx).id);
                    r.image = [];
                    ROI(rIdx).obj = r;
                    continue;
                end
            end

            % -- Normalisation des noms & dimensions de display pour coller à chanSelNames --
            r = normalizeROIChannels(r, chanSelNames);


            % Minimal assignments before save:
            r.image     = roiBlock;              % [h w Csel Tblock]
            r.channelid = 1:Csel;                % mapping 1:1
            r.path      = fovOutDir;             % ensure it stays valid

            % If your roi class uses explicit paths, keep them consistent
            if isprop(r,'h5path');  r.h5path  = fullfile(fovOutDir, sprintf('im_%s.h5',  r.id)); end
            if isprop(r,'matpath'); r.matpath = fullfile(fovOutDir, sprintf('data_%s.mat', r.id)); end

            % Save (append on T); r.save must create datasets if file was deleted
            r.display.write_abs_start = frameBatch(1) - 1;


            didSave = r.save(chanSelNames, false);

            if ~didSave
                fprintf('        ⚠ nothing written for ROI %s\n', ROI(rIdx).id);
            else
                fprintf('.');
            end

            r.image = [];           % free RAM
            r.display.write_abs_start = [];
            ROI(rIdx).obj = r;      % write-back

        end
        fprintf('\n');
        pbBlk.update(ib, sprintf('bloc %d/%d terminé', ib, nBlocks));

    end

    pbBlk.close();
    pbFOV.update(kF, sprintf('FOV %d/%d terminé', kF, numel(FOVIndex)));
    %fprintf('\n   ✔ done FOV %s (%d ROI)\n', fovId, nROI);
end
pbFOV.close();

fprintf('\n✅ Extraction complete (append mode).\n');
fprintf('=============================================\n\n');
end

% ========= Helpers =========

function pb = makeConsolePB(titleStr, totalCount, varargin)
%MAKECONSOLEPB Console progress bar on a single line.
%   pb = makeConsolePB('Task', N, 'Indent',4, 'Width',40, 'MinInterval',0.05, 'Mode','auto')
%
% Public API:
%   pb.update(i, msg)   % 0 <= i <= N ; msg optionnel (court)
%   pb.close()

ip = inputParser;
ip.addParameter('Indent',0,@(x)isnumeric(x)&&isscalar(x));
ip.addParameter('Width',40,@(x)isnumeric(x)&&isscalar(x)&&x>=5);
ip.addParameter('MinInterval',0.05,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('ShowETA',true,@(x)islogical(x)&&isscalar(x));
ip.addParameter('Mode','auto',@(s)ischar(s)&&ismember(lower(s),{'auto','cr','bs'}));
ip.parse(varargin{:});

indentN = ip.Results.Indent;
width   = ip.Results.Width;
minInt  = ip.Results.MinInterval;
showETA = ip.Results.ShowETA;
mode    = lower(ip.Results.Mode);

indentStr  = repmat(' ',1,max(0,indentN));
totalCount = max(1, round(totalCount));

% Mode auto: si diary ON, évite les backspaces -> CR
diaryState = get(0,'Diary'); % 'on'/'off'
if strcmp(mode,'auto')
    if strcmpi(diaryState,'on')
        mode = 'cr';
    else
        mode = 'cr'; % CR est le plus robuste dans le Command Window/Live Script
    end
end

% --- état interne
st.t0      = tic;
st.lastT   = -inf;
st.lastI   = 0;
st.lastLen = 0;    % longueur imprimée (pour padding)
st.lineOpen = false; % vrai dès qu'une ligne de PB est affichée

% Titre sur sa propre ligne
fprintf('%s%s\n', indentStr, char(titleStr));

% API
pb.update = @updatePB;
pb.close  = @closePB;

% ================= nested =================
    function updatePB(i, msg)
        if nargin < 2, msg = ''; end
        i = min(max(0, round(i)), totalCount);

        nowT = toc(st.t0);
        if (nowT - st.lastT < minInt) && (i < totalCount)
            st.lastI = i;
            return;
        end
        st.lastT = nowT;

        % contenu barre
        frac   = i/totalCount;
        filled = max(0, min(width, round(frac*width)));
        barStr = ['[', repmat('=',1,filled), repmat(' ',1,width-filled), ']'];
        pctStr = sprintf('%3.0f%%', 100*frac);

        if showETA
            if i>0
                rate   = i/max(nowT,eps);
                remain = (totalCount - i)/max(rate,eps);
                mm = floor(remain/60);
                ss = round(remain - 60*mm);
                etaStr = sprintf(' ETA %02d:%02d', mm, ss);
            else
                etaStr = ' ETA --:--';
            end
        else
            etaStr = '';
        end

        fixed = sprintf('%s %d/%d %s%s', barStr, i, totalCount, pctStr, etaStr);

        % limite douce de la longueur ~100 char
        maxLine = 100;
        roomForMsg = max(0, maxLine - numel(fixed) - 1);
        if ~isempty(msg)
            if numel(msg) > roomForMsg
                if roomForMsg >= 3
                    msg = [msg(1:roomForMsg-3) '...'];
                else
                    msg = '';
                end
            end
        end

        if isempty(msg)
            line = sprintf('%s%s', indentStr, fixed);
        else
            line = sprintf('%s%s %s', indentStr, fixed, msg);
        end

        % calcul padding pour effacer les restes d'une ligne plus longue
        pad = max(0, st.lastLen - numel(line));
        tail = repmat(' ',1,pad);

        switch mode
            case 'cr'
                % CR: on réécrit LA MÊME LIGNE, pas de \n avant la fin
                if st.lineOpen
                    fprintf('\r'); % retour début de ligne courante
                end
                fprintf('%s%s', line, tail);
                st.lineOpen = true;

            case 'bs'
                % Backspaces (déconseillé si diary on)
                if st.lineOpen && st.lastLen > 0
                    fprintf('%s', repmat('\b',1,st.lastLen)); % reculer
                    fprintf('%s', repmat(' ',1,st.lastLen));  % effacer
                    fprintf('%s', repmat('\b',1,st.lastLen)); % revenir
                end
                fprintf('%s', line);
                st.lineOpen = true;
        end

        if i>=totalCount
            fprintf('\n');    % on valide la ligne puis saute à la suivante
            st.lineOpen = false;
            st.lastLen = 0;
        else
            st.lastLen = numel(line); % mémoriser la longueur pour le prochain padding
        end

        st.lastI = i;
    end

    function closePB()
        if st.lastI < totalCount
            updatePB(totalCount, 'done');
        elseif st.lineOpen
            fprintf('\n'); % sécurité : terminer la ligne en cours
            st.lineOpen = false;
            st.lastLen = 0;
        end
    end
end

function [h5path, matpath] = getROIFilePaths(r)
% Construit les chemins attendus: im_<id>.h5 et data_<id>.mat dans r.path
roiId = safeStr(getprop(r,'id','ROI'));
roiDir = safeStr(getprop(r,'path',pwd));
h5path  = fullfile(roiDir, sprintf('im_%s.h5',  roiId));
matpath = fullfile(roiDir, sprintf('data_%s.mat',roiId));
end

function hardResetROIh5(r)
% Supprime proprement H5 + MAT si présents (compat: avec ou sans r.h5path/matpath)
h5p = ''; matp = '';
if isprop(r,'h5path') && ~isempty(r.h5path),   h5p  = r.h5path;  end
if isprop(r,'matpath') && ~isempty(r.matpath), matp = r.matpath; end
if isempty(h5p) || isempty(matp)
    [h5p,matp] = getROIFilePaths(r);
end
if isfile(h5p),  delete(h5p);  end
if isfile(matp), delete(matp); end
end


function [availBytes, note] = getAvailableMemoryBytes()
% Retourne une estimation prudente de la RAM libre pour MATLAB.
% Windows: memory(); Linux/macOS: heuristique via feature('memstats') si dispo, sinon fallback.
note = '';
availBytes = 2e9; % fallback 2GB
try
    if ispc
        m = memory; % Windows only
        availBytes = double(m.MaxPossibleArrayBytes); % conservateur
        note = sprintf('Windows memory(): MaxPossibleArrayBytes=%.1f GB', availBytes/1e9);
    else
        % Tentatives alternatives
        try
            s = feature('memstats'); %#ok<NASGU>
            % Pas de champ standardisé ⇒ on reste sur le fallback 2GB.
            note = 'feature(''memstats'') available (no unified free bytes) → using 2 GB fallback.';
        catch
            note = 'No memory() on this platform → using 2 GB fallback.';
        end
    end
catch
    note = 'Unable to query memory → using 2 GB fallback.';
end
% garder une marge pour l'OS et le reste
availBytes = max(256e6, 0.8 * availBytes);
end

function [H,W,sampleBytes] = probeFrameSpec(fovObj, firstChan)
if nargin<2 || isempty(firstChan), firstChan = 1; end
testIm = fovObj.readImage(1, firstChan);
if isempty(testIm)
    testIm = uint16(0);
    H=1; W=1;
else
    [H,W] = size(testIm);
end
switch class(testIm)
    case {'uint8','int8'},     sampleBytes = 1;
    case {'uint16','int16'},   sampleBytes = 2;
    case {'uint32','int32','single'}, sampleBytes = 4;
    case {'uint64','int64','double'}, sampleBytes = 8;
    otherwise, sampleBytes = 2; % conservateur
end
end

function chanNames = getFOVChannelNames(fovObj, nChannels)
chanNames = {};
if isprop(fovObj,'channel') && ~isempty(fovObj.channel)
    ch = fovObj.channel;
    if isstring(ch), ch = cellstr(ch); end
    if ~iscell(ch), ch = {char(string(ch))}; end
    chanNames = ch;
end
if isempty(chanNames) || numel(chanNames) ~= nChannels
    chanNames = arrayfun(@(i)sprintf('channel_%03d',i), 1:nChannels, 'UniformOutput', false);
end
end

function [nFrames, nChannels, sampleClass] = inferFOVTimeline(fovObj)
if isprop(fovObj,'channel') && ~isempty(fovObj.channel)
    nChannels = numel(fovObj.channel);
else
    nChannels = 1;
end

if isprop(fovObj,'frames') && ~isempty(fovObj.frames)
    try
        nFrames = max(double(fovObj.frames(:)));
    catch
        nFrames = double(fovObj.frames(1));
    end
else
    nFrames = 1;
end

try
    testIm = fovObj.readImage(1,1);
    if isempty(testIm)
        sampleClass = 'uint16';
    else
        sampleClass = class(testIm);
    end
catch
    sampleClass = 'uint16';
end
end

function blockImg = loadFOVBlock_readImage(fovObj, frameIdxVec, channelIdxVec, progressFcn)
if nargin < 4, progressFcn = []; end

frameIdxVec   = frameIdxVec(:)';
channelIdxVec = channelIdxVec(:)';

testIm = fovObj.readImage(frameIdxVec(1), channelIdxVec(1));
[H, W] = size(testIm);
C = numel(channelIdxVec);
T = numel(frameIdxVec);

blockImg = zeros(H, W, C, T, class(testIm));

for ic = 1:C
    c = channelIdxVec(ic);
    for it = 1:T
        t = frameIdxVec(it);
        im = fovObj.readImage(t, c);
        if isempty(im), continue; end
        if size(im,1)~=H || size(im,2)~=W
            im = safeResizeTo(im, H, W);
        end
        blockImg(:,:,ic,it) = im;

        % ⬇️ CHANGE ICI : index cumulé (1..C*T)
        if ~isempty(progressFcn)
            idx = (ic-1)*T + it;           % 1..C*T
            msg = sprintf('ch%d frame %d/%d', c, it, T);
            progressFcn(idx, [], msg);     % le 2e arg est ignoré par ta PB
        end
    end
end
end

function im2 = safeResizeTo(im,H,W)
im2 = zeros(H,W,class(im));
h0 = min(H,size(im,1));
w0 = min(W,size(im,2));
im2(1:h0,1:w0) = im(1:h0,1:w0);
end

function outCrop = cropWithPad(frameImg, xmin, ymin, w, h)
Hfull = size(frameImg,1); Wfull = size(frameImg,2);
xRange = xmin + (0:w-1);  yRange = ymin + (0:h-1);
xValid = xRange(xRange >= 1 & xRange <= Wfull);
yValid = yRange(yRange >= 1 & yRange <= Hfull);
outCrop = zeros(h,w,class(frameImg));
if isempty(xValid) || isempty(yValid), return; end
xOffsetOut = find(xRange==xValid(1),1);
yOffsetOut = find(yRange==yValid(1),1);
outCrop(yOffsetOut+(0:numel(yValid)-1), xOffsetOut+(0:numel(xValid)-1)) = frameImg(yValid,xValid);
end

function s = safeStr(x)
if isempty(x)
    s = '';
elseif ischar(x)
    s = x;
elseif isstring(x)
    s = strjoin(cellstr(x), ', ');
else
    s = char(string(x));
end
end

function val = getprop(obj, field, defaultVal)
if isprop(obj,field)
    val = obj.(field);
    if isempty(val), val = defaultVal; end
else
    val = defaultVal;
end
end

function fovOutDir = getFOVOutputPath(shallowObj, fovObj, fovIdFallback)
projRoot = '';
if isprop(shallowObj,'io') && isstruct(shallowObj.io)
    hasPath = isfield(shallowObj.io,'path') && ~isempty(shallowObj.io.path);
    hasFile = isfield(shallowObj.io,'file') && ~isempty(shallowObj.io.file);
    if hasPath && hasFile
        rawPath = shallowObj.io.path;
        rawFile = shallowObj.io.file;
        [~, baseName, ext] = fileparts(rawFile);
        if strcmpi(ext,'.mat'), projectFolderName = baseName;
        else,                 projectFolderName = rawFile;
        end
        projRoot = fullfile(rawPath, projectFolderName);
    end
end
if isempty(projRoot), projRoot = detectProjectRoot(shallowObj); end
if isprop(fovObj,'id') && ~isempty(fovObj.id), fovName = fovObj.id;
else, fovName = fovIdFallback; end
fovOutDir = fullfile(projRoot, fovName);
if ~exist(fovOutDir,'dir'), mkdir(fovOutDir); end
end

function root = detectProjectRoot(shallowObj)
root = '';
if ismethod(shallowObj,'getPath')
    try, [pth, ~] = shallowObj.getPath; if exist(pth,'dir'), root = pth; end, catch, end
end
if isempty(root) && isprop(shallowObj,'path') && ~isempty(shallowObj.path)
    if exist(shallowObj.path,'dir'), root = shallowObj.path; end
end
if isempty(root), root = pwd; end
end

function d = defaultDisplay(N, C)
d = struct();
d.intensity       = repmat([1 1 1], N, 1);
d.frame           = 1;
d.selectedchannel = ones(1,N);
d.binning         = 1;
d.rgb             = repmat([1 1 1], N, 1);  % N x 3 (par canal logique)
d.channel         = arrayfun(@(k)sprintf('channel_%d',k), 1:N, 'UniformOutput', false);
d.stretchlim      = [];
d.displaylim      = repmat([0;1], 1, C);
d.indexed         = zeros(1,N);
d.alpha           = ones(1,N);
d.contour         = zeros(1,N);
d.width           = ones(1,N);
d.log             = zeros(1,N);
end

function r = normalizeROIChannels(r, chanSelNames)
% Force r.display & r.channelid à correspondre exactement à chanSelNames
Csel = numel(chanSelNames);
oldD = struct();
if isstruct(r.display), oldD = r.display; end

% Nouveau display "propre" de taille Csel
newD = defaultDisplay(Csel, Csel);
newD.channel = chanSelNames(:)';  % impose les noms

% Si l'ancien display a des noms, essaie de répliquer les per-channel props
if isfield(oldD,'channel') && ~isempty(oldD.channel)
    oldNames = string(oldD.channel);
    for ii = 1:Csel
        nm = string(chanSelNames{ii});
        jj = find(oldNames==nm, 1); % map par nom
        if ~isempty(jj)
            % Copie "safe" champ par champ si dimension ok
            newD = copyIfValidRow(oldD, newD, 'intensity', jj, ii);
            newD = copyIfValidRow(oldD, newD, 'rgb',       jj, ii);
            newD = copyIfValidRowScal(oldD, newD, 'selectedchannel', jj, ii);
            newD = copyIfValidRowScal(oldD, newD, 'indexed', jj, ii);
            newD = copyIfValidRowScal(oldD, newD, 'alpha',   jj, ii);
            newD = copyIfValidRowScal(oldD, newD, 'contour', jj, ii);
            newD = copyIfValidRowScal(oldD, newD, 'width',   jj, ii);
            newD = copyIfValidRowScal(oldD, newD, 'log',     jj, ii);
        end
    end

    % displaylim: taille attendue 2 x C. Si oldD.displaylim correspond,
    % on copie colonne par colonne par nom de canal.
    if isfield(oldD,'displaylim') && ~isempty(oldD.displaylim) && size(oldD.displaylim,1)==2
        % On suppose oldD.displaylim a autant de colonnes que oldD.channel
        for ii = 1:Csel
            nm = string(chanSelNames{ii});
            jj = find(oldNames==nm, 1);
            if ~isempty(jj) && jj <= size(oldD.displaylim,2) && ii <= size(newD.displaylim,2)
                newD.displaylim(:,ii) = oldD.displaylim(:,jj);
            end
        end
    end
end

% Affecte le display normalisé
r.display   = newD;
r.channelid = 1:Csel;  % mapping 1:1 (un dataset logique par canal)
end

function newD = copyIfValidRow(oldD, newD, fieldName, jOld, iNew)
if isfield(oldD,fieldName) && ~isempty(oldD.(fieldName)) ...
        && size(oldD.(fieldName),1) >= jOld ...
        && size(newD.(fieldName),1) >= iNew ...
        && size(oldD.(fieldName),2) == size(newD.(fieldName),2)
    newD.(fieldName)(iNew,:) = oldD.(fieldName)(jOld,:);
end
end

function newD = copyIfValidRowScal(oldD, newD, fieldName, jOld, iNew)
if isfield(oldD,fieldName) && ~isempty(oldD.(fieldName)) ...
        && numel(oldD.(fieldName)) >= jOld ...
        && numel(newD.(fieldName)) >= iNew
    tmp = newD.(fieldName);
    tmp(iNew) = oldD.(fieldName)(jOld);
    newD.(fieldName) = tmp;
end
end

% ---------- Helpers ----------


function names = listH5Channels(h5path)
names = string.empty(1,0);
if ~isfile(h5path), return; end
try
    info = h5info(h5path,'/');
    names = string({info.Datasets.Name});
catch
    % fichier vide/incomplet → aucun dataset détecté
end
end

function bb = pickBBoxForFrame(ROIe, tAbs, tLocal, framesToDo)
if ~isfield(ROIe,'mobile') || ~ROIe.mobile || ~isfield(ROIe,'bboxPerFrame') || isempty(ROIe.bboxPerFrame)
    bb = [ROIe.bbox.xmin, ROIe.bbox.ymin, ROIe.bbox.w, ROIe.bbox.h];
    return;
end

V = ROIe.bboxPerFrame; N = size(V,1);

if isfield(ROIe,'frames_abs') && ~isempty(ROIe.frames_abs)
    [tf,loc] = ismember(tAbs, ROIe.frames_abs);
    row = tf .* loc + (~tf) .* min(max(1,tAbs), N);
else
    if numel(framesToDo) == N
        row = tLocal;
    else
        row = min(max(1,tAbs), N);
    end
end

xmin = V(row,1); ymin = V(row,2);
w = ROIe.w; h = ROIe.h;
bb = [xmin, ymin, w, h];
end

function selIdx = resolveROISelectionForFOV(roiList, ROISelect, positionInFOVIndex, FOVIndex)
% ROISelect:
%   - []            -> toutes les ROIs
%   - numeric vec   -> indices appliqués à TOUS les FOV sélectionnés
%   - cell array    -> ROISelect{j} appliqué au j-ième FOV de FOVIndex
%
% positionInFOVIndex = rang courant (kF) dans la boucle FOVIndex (1..numel(FOVIndex))

n = numel(roiList);
if n==0
    selIdx = [];
    return;
end

% A) pas de sélection -> tout
if isempty(ROISelect)
    selIdx = 1:n;
    return;
end

% B) sélection numérique -> appliquée à tous les FOV
if isnumeric(ROISelect)
    vals = ROISelect(:)';
    mask = vals>=1 & vals<=n;
    selIdx = unique(vals(mask), 'stable');
    return;
end

% C) sélection cell array par FOV
if iscell(ROISelect)
    if positionInFOVIndex < 1 || positionInFOVIndex > numel(ROISelect)
        selIdx = 1:n; % par défaut: toutes si l'entrée n'existe pas
        return;
    end
    cur = ROISelect{positionInFOVIndex};
    if isempty(cur)
        selIdx = 1:n;
        return;
    end
    vals = cur(:)';
    mask = vals>=1 & vals<=n;
    selIdx = unique(vals(mask), 'stable');
    return;
end

% D) fallback
selIdx = 1:n;
end


