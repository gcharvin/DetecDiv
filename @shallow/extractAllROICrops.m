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
ROISelect      = [];         % [] => toutes (par FOV), numeric ou cell array

% --- OPTIONS DIVERSES ---
ForceChannelNames = true;    % impose les noms de canaux des ROI = chanSelNames
Extend            = false;   % false = hard reset ; true = append/prolong

%% NEW (saveCroppedImages-compat)
Scale        = 1;            % scale factor on crops (1 = no resize)
CropDrift    = 1.0;          % fraction pour estimation drift (1 = full frame)
hprogressbar = [];           % ui handle (uiprogressdlg or compatible)

% =========================================================
% DRIFT CORRECTION OPTIONS — robust to jitter + slow drift
% =========================================================

CorrectDrift      = true;
DriftMethod       = 'subpixel';
DriftRefMode      = 'previous';
DriftSubpixel     = true;

DriftMaxShift     = 20;
DriftHipassSigma  = 3;
DriftApodize      = true;
DriftMask         = [];

DriftRollingRef   = 0;     % IMPORTANT pour le test
DriftWarmupFrames = 0;

DriftPsrMin       = 10;
DriftPsrRadius    = 6;

DriftMaxStep      = 10;
DriftSmoothWin    = 0;

DriftDebug        = true;
DriftDebugEvery   = 1;

DriftChannel = []; 
DriftRejectMode = 'hold';



% ----------------- PARSING -----------------
for i = 1:2:numel(varargin)
    key = lower(string(varargin{i}));

    % aliases for saveCroppedImages-style naming
    if key=="fov",     key = "fovindex"; end
    if key=="channel", key = "channels"; end

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

        % drift high-level
        case "correctdrift"
            CorrectDrift = logical(varargin{i+1});
        case "driftchannel"
            DriftChannel = varargin{i+1};
        case "driftmethod"
            DriftMethod = char(varargin{i+1});

        % drift ref mode (NEW)
        case "driftrefmode"
            DriftRefMode = char(varargin{i+1});

        % legacy compat (si tu reçois encore DriftRefLocal)
        case "driftreflocal"
            % ancien champ -> map simple:
            % 1 => previous ; 0/other => first
            if isequal(varargin{i+1},1)
                DriftRefMode = 'previous';
            else
                DriftRefMode = 'first';
            end

        % drift numeric params
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
        case "driftmask"
            DriftMask = varargin{i+1};

        % NEW robustness params
        case "driftwarmupframes"
            DriftWarmupFrames = varargin{i+1};
        case "driftpsrradius"
            DriftPsrRadius = varargin{i+1};
        case "driftpsrmin"
            DriftPsrMin = varargin{i+1};
        case "driftmaxjump"
            DriftMaxJump = varargin{i+1};
        case "driftrejectmode"
            DriftRejectMode = char(varargin{i+1});

        case "driftmaxstep"
            DriftMaxStep = varargin{i+1};
        case "driftmaxstepmode"
            DriftMaxStepMode = char(varargin{i+1});

        case "driftsmoothwin"
            DriftSmoothWin = varargin{i+1};
        case "driftsmoothmethod"
            DriftSmoothMethod = char(varargin{i+1});

        case "driftdebug"
            DriftDebug = logical(varargin{i+1});
        case "driftdebugevery"
            DriftDebugEvery = varargin{i+1};

        case "roi"
            ROISelect = varargin{i+1};

        % scale + cropdrift + progress handle
        case "scale"
            Scale = varargin{i+1};
        case "cropdrift"
            CropDrift = varargin{i+1};
        case "hprogressbar"
            hprogressbar = varargin{i+1};
    end
end

% ---- Drift fallbacks (avoid missing vars during refactor) ----
if ~exist('DriftMethod','var')       || isempty(DriftMethod),       DriftMethod = 'subpixel'; end
if ~exist('DriftRefMode','var')      || isempty(DriftRefMode),      DriftRefMode = 'previous'; end
if ~exist('DriftSubpixel','var')     || isempty(DriftSubpixel),     DriftSubpixel = true; end
if ~exist('DriftMaxShift','var')     || isempty(DriftMaxShift),     DriftMaxShift = 20; end
if ~exist('DriftHipassSigma','var')  || isempty(DriftHipassSigma),  DriftHipassSigma = 3; end
if ~exist('DriftApodize','var')      || isempty(DriftApodize),      DriftApodize = true; end
if ~exist('DriftMask','var'),                                   DriftMask = []; end
if ~exist('DriftWarmupFrames','var') || isempty(DriftWarmupFrames), DriftWarmupFrames = 0; end
if ~exist('DriftPsrRadius','var')    || isempty(DriftPsrRadius),    DriftPsrRadius = 6; end
if ~exist('DriftPsrMin','var')       || isempty(DriftPsrMin),       DriftPsrMin = 10; end
if ~exist('DriftRejectMode','var')   || isempty(DriftRejectMode),   DriftRejectMode = 'hold'; end
if ~exist('DriftMaxStep','var')      || isempty(DriftMaxStep),      DriftMaxStep = 10; end
if ~exist('DriftSmoothWin','var')    || isempty(DriftSmoothWin),    DriftSmoothWin = 0; end
if ~exist('DriftSmoothMethod','var') || isempty(DriftSmoothMethod), DriftSmoothMethod = 'median'; end
if ~exist('DriftDebug','var')        || isempty(DriftDebug),        DriftDebug = false; end
if ~exist('DriftDebugEvery','var')   || isempty(DriftDebugEvery),   DriftDebugEvery = 10; end



% normalize scale
if isempty(Scale), Scale = 1; end
if islogical(Scale), Scale = double(Scale); end
if ~isscalar(Scale) || ~isfinite(Scale) || Scale<=0
    warning('Invalid Scale=%s -> forcing Scale=1', mat2str(Scale));
    Scale = 1;
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
    ChannelsPerFOV(:) = {{}}; % ALL
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

    % --- restreindre la liste selon ROISelect pour CE FOV ---
    selIdx = resolveROISelectionForFOV(roiList, ROISelect, kF, FOVIndex);
    if isempty(selIdx)
        fprintf('\n▶ FOV %d/%d — no selected ROI, skipped.\n', kF, numel(FOVIndex));
        continue;
    end
    roiList = roiList(selIdx);

    if isempty(roiList)
        fprintf('\n▶ FOV %d/%d — no ROI, skipped.\n', kF, numel(FOVIndex));
        continue;
    end

    % Infos temporelles / canaux pour la FOV
    [nFramesTotal, nChannels, sampleClass] = inferFOVTimeline(fovObj);

    % ---------- CANAUX POUR CETTE FOV ----------
    chanNamesFOV = getFOVChannelNames(fovObj, nChannels);
    chanNamesFOV = cellfun(@char, string(chanNamesFOV), 'UniformOutput', false);

    chans_for_this_fov = ChannelsPerFOV{kF};

    if isempty(chans_for_this_fov)
        chanSelIdx   = 1:nChannels;
        chanSelNames = chanNamesFOV;
    else
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
            names_req = cellfun(@char, string(chans_for_this_fov), 'UniformOutput', false);
        end

        [isHit, idx] = ismember(names_req, chanNamesFOV);
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

    % --- Frames pour CETTE FOV ---
    frames_for_this_fov = FrameListPerFOV{kF};
    if isempty(frames_for_this_fov)
        framesToDo = 1:nFramesTotal;
    else
        v = frames_for_this_fov;
        if iscell(v),    v = v{1};    end
        if isstring(v),  v = double(v); end
        if islogical(v), v = find(v);   end
        v = double(v(:)');
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

    % UI PB update
    pbUpdateUI(hprogressbar, (kF-1)/max(1,numel(FOVIndex)), sprintf('FOV %d/%d', kF, numel(FOVIndex)));

    % -------- Préparer les ROI --------
    nROI = numel(roiList);

    ROI = struct('obj',[],'bbox',[],'h',0,'w',0,'id','', 'chanNames',{{}});
    ROI(nROI).obj = [];
    for rIdx = 1:nROI
        r = roiList(rIdx);

        ROI(rIdx).obj = r;
        ROI(rIdx).id  = safeStr(getprop(r,'id',sprintf('%s_ROI_%02d',fovId,rIdx)));
        ROI(rIdx).didInit = false;

        r.path = fovOutDir;

        v = getprop(r,'value',[]);
        if isempty(v) || size(v,2) < 4
            ROI(rIdx).bbox = []; ROI(rIdx).h = 0; ROI(rIdx).w = 0;
            ROI(rIdx).mobile = false;
            ROI(rIdx).bboxPerFrame = [];
        else
            if size(v,1) == 1
                ROI(rIdx).mobile = false;
                ROI(rIdx).bbox = struct('xmin',v(1), 'ymin',v(2), 'w',v(3), 'h',v(4));
                ROI(rIdx).w = v(3); ROI(rIdx).h = v(4);
            else
                ROI(rIdx).mobile = true;
                ROI(rIdx).bboxPerFrame = v(:,1:4);

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
                ROI(rIdx).frames_abs = framesUD;
            end
        end

        if ~isstruct(r.display) || ~isfield(r.display,'channel') || isempty(r.display.channel)
            r.display = defaultDisplay(numel(chanNamesFOV), numel(chanNamesFOV));
            r.display.channel = chanNamesFOV;
        end
        ROI(rIdx).chanNames = r.display.channel;

        if isempty(r.channelid) || numel(r.channelid) ~= numel(chanNamesFOV)
            r.channelid = 1:numel(chanNamesFOV);
        end

        roiList(rIdx) = r;
    end

    % init ROI files / channels
    for rIdx = 1:nROI
        r = roiList(rIdx);
        if ~isprop(r,'id') || isempty(r.id), r.id = ROI(rIdx).id; end
        r.path = fovOutDir;
        if isprop(r,'h5path'),  r.h5path  = fullfile(fovOutDir, sprintf('im_%s.h5',  r.id)); end
        if isprop(r,'matpath'), r.matpath = fullfile(fovOutDir, sprintf('data_%s.mat',r.id)); end

        if ~Extend
            hardResetROIh5(r);
            r.image     = [];
            r.channelid = 1:Csel;
            r.display   = defaultDisplay(Csel, Csel);
            r.display.channel = chanSelNames(:)';
            ROI(rIdx).didInit = true;
        else
            [h5p, ~] = getROIFilePaths(r);
            existing = listH5Channels(h5p);
            if isempty(existing)
                r.image     = [];
                r.channelid = 1:Csel;
                if ForceChannelNames
                    r.display = defaultDisplay(Csel, Csel);
                    r.display.channel = chanSelNames(:)';
                end
                ROI(rIdx).didInit = true;
            else
                req = string(chanSelNames);
                keep = existing(ismember(existing, req));
                if isempty(keep)
                    warning('ROI %s: none of requested channels exist in H5 → nothing to append.', r.id);
                else
                    chanSelNames = cellstr(keep); %#ok<NASGU>
                    Csel = numel(keep);
                    if ForceChannelNames
                        r = normalizeROIChannels(r, chanSelNames);
                    end
                    ROI(rIdx).didInit = true;
                end
            end
        end

        roiList(rIdx) = r;
    end

    % -------- Estimation mémoire & taille de bloc temporel --------
    [H,W,sampleBytes] = probeFrameSpec(fovObj, chanSelIdx(1));

    perBlockBudget = max(64e6, 0.25 * double(availBytes));
    Tblock_auto    = max(1, floor(perBlockBudget / double(H*W*Csel*sampleBytes)));
    Tblock_auto    = max(1, min(Tblock_auto, nFramesThisRun));

    frameStarts = 1:Tblock_auto:nFramesThisRun;
    nBlocks     = numel(frameStarts);
    fprintf('   RAM avail ~ %.1f GB → Tblock=%d (H=%d,W=%d,Csel=%d,class=%s)\n', ...
        double(availBytes)/1e9, Tblock_auto, H, W, Csel, sampleClass);

    pbBlk = makeConsolePB(sprintf('  FOV %d/%d — blocs', kF, numel(FOVIndex)), nBlocks, 'Indent',2);

    % --------- Boucle bloc par bloc ---------
    for ib = 1:nBlocks
        fs = frameStarts(ib);
        fe = min(fs+Tblock_auto-1, nFramesThisRun);

        localRange = fs:fe;
        frameBatch = framesToDo(localRange);
        Tblock     = numel(localRange);

        pbFrm = makeConsolePB(sprintf('    Bloc %d/%d — frames', ib, nBlocks), Csel*Tblock, 'Indent',4);

        % 1) Lire bloc FOV (grayscale enforced)
        blockImg = loadFOVBlock_readImage( ...
            fovObj, frameBatch, chanSelIdx, ...
            @(it,NT,msg) pbFrm.update(it, msg) );

        % UI update
        fracGlobal = ((kF-1) + (ib-1)/max(1,nBlocks)) / max(1,numel(FOVIndex));
        pbUpdateUI(hprogressbar, fracGlobal, sprintf('FOV %d/%d - bloc %d/%d', kF, numel(FOVIndex), ib, nBlocks));


      % =========================================================
% DEBUG: inject synthetic drift (1 px right + 1 px down / frame)
% =========================================================
% if DriftDebug
%     fprintf('[drift inject] incremental drift + jitter (bounded per-frame steps)\n');
% 
%     T = size(blockImg,4);
%     C = size(blockImg,3);
% 
%     % target per-frame step (what computeDrift should recover with ref=previous)
%     driftStep_col = 1.0;     % px/frame
%     driftStep_row = 1.0;     % px/frame
% 
%     jitterStdStep = 0.5;     % px RMS on the STEP (not on absolute position)
%     maxStepJitter = 1.5;     % clamp step jitter
% 
%     injCol = zeros(1,T);
%     injRow = zeros(1,T);
% 
%     for it = 2:T
%         jCol = max(min(jitterStdStep*randn(), maxStepJitter), -maxStepJitter);
%         jRow = max(min(jitterStdStep*randn(), maxStepJitter), -maxStepJitter);
% 
%         stepCol = driftStep_col + jCol;
%         stepRow = driftStep_row + jRow;
% 
%         injCol(it) = injCol(it-1) + stepCol;
%         injRow(it) = injRow(it-1) + stepRow;
%     end
% 
%     % Apply translation
%     for it = 1:T
%         for ic = 1:C
%             fv = median(blockImg(:,:,ic,it), 'all');
%             blockImg(:,:,ic,it) = imtranslate(blockImg(:,:,ic,it), [injCol(it) injRow(it)], ...
%                 'linear', 'FillValues', fv);
%         end
%         fprintf('[drift inject] frame %02d: (col,row)=(%+.2f,%+.2f)\n', it, injCol(it), injRow(it));
%     end
% 
%     fprintf('[drift inject] step stats: mean(|d|) col=%.2f row=%.2f ; max(|d|) col=%.2f row=%.2f\n', ...
%         mean(abs(diff(injCol))), mean(abs(diff(injRow))), max(abs(diff(injCol))), max(abs(diff(injRow))));
% end




    if CorrectDrift
    disp('Computing drift....');

    % --- Choose channel used for drift estimation (local index in chanSelNames/blockImg)
    driftLocal = 1;
    if ~isempty(DriftChannel)
        if isnumeric(DriftChannel)
            driftLocal = double(DriftChannel(1));
        else
            try
                [tf, loc] = ismember(string(DriftChannel), string(chanSelNames));
                if tf && loc>0
                    driftLocal = loc;
                else
                    [tf2, loc2] = ismember(lower(string(DriftChannel)), lower(string(chanSelNames)));
                    if tf2 && loc2>0, driftLocal = loc2; end
                end
            catch
            end
        end
    end
    driftLocal = max(1, min(Csel, round(driftLocal)));

    % sanitize crop (computeDrift needs ]0,1])
cropReal = CropDrift;
if isempty(cropReal) || (islogical(cropReal) && ~cropReal), cropReal = 1; end
cropReal = double(cropReal(1));
if ~isfinite(cropReal) || cropReal <= 0 || cropReal > 1, cropReal = 1; end

driftArgs = { ...
  'channel',      driftLocal, ...
  'method',       DriftMethod, ...
  'refmode',      DriftRefMode, ...
  'subpixel',     DriftSubpixel, ...
  'maxshift',     DriftMaxShift, ...
  'hipasssigma',  DriftHipassSigma, ...
  'apodize',      DriftApodize, ...
  'mask',         DriftMask, ...
  'crop',         cropReal, ...
  'warmupframes', DriftWarmupFrames, ...
  'psrradius',    DriftPsrRadius, ...
  'psrmin',       DriftPsrMin, ...
  'rejectmode',   DriftRejectMode, ...   % (PSR reject)
  'maxstep',      DriftMaxStep, ...
  'smoothwin',    DriftSmoothWin, ...
  'smoothmethod', DriftSmoothMethod, ...
  'debug',        DriftDebug, ...
  'debugevery',   DriftDebugEvery ...
};



%  if DriftDebug && Tblock >= 10
%     tmp = blockImg;
% 
%     % inject known shift at local frame #10
%     I10 = tmp(:,:,driftLocal,10);
%     fv  = median(I10(:));
%     tmp(:,:,driftLocal,10) = imtranslate(I10, [3 -2], 'FillValues', fv);
% 
%     % run drift, keep corrected images
%     [tmpCorr, ~, scoreT] = fovObj.computeDrift('images', tmp, driftArgs{:});
% 
%    % --- build preprocess like computeDrift ---
% prep = @(I) preprocess(cropCenter(toGray(I), cropReal), DriftHipassSigma, DriftApodize, DriftMask);
% 
% A0 = prep(tmp(:,:,driftLocal,9));
% B0 = prep(tmp(:,:,driftLocal,10));
% A1 = prep(tmpCorr(:,:,driftLocal,9));
% B1 = prep(tmpCorr(:,:,driftLocal,10));
% 
% [r0,c0] = phaseShift(A0,B0);
% [r1,c1] = phaseShift(A1,B1);
% 
% fprintf('[drift test] BEFORE(prep) est shift (row %+g, col %+g)\n', r0, c0);
% fprintf('[drift test] AFTER (prep) est shift (row %+g, col %+g)\n', r1, c1);
% 
% end



   [blockImg, driftBlk, scoreBlk] = fovObj.computeDrift( ...
    'images', blockImg, ...
    'framesid', frameBatch, ...
    driftArgs{:});

 


    % ---- journalise dans fovObj.drift (frames ABS) ----
    if ~isfield(fovObj,'drift') || ~isstruct(fovObj.drift)
        fovObj.drift = struct('frames',[],'x',[],'y',[],'score',[]);
    end

    oldF = [];
    if isfield(fovObj.drift,'frames') && ~isempty(fovObj.drift.frames)
        oldF = fovObj.drift.frames(:)';
    end
    allF = union(oldF, frameBatch(:)');

    xNew  = nan(1, numel(allF));
    yNew  = nan(1, numel(allF));
    scNew = nan(1, numel(allF));

    if ~isempty(oldF)
        [~,locOld] = ismember(oldF, allF);
        if isfield(fovObj.drift,'x') && ~isempty(fovObj.drift.x), xNew(locOld) = fovObj.drift.x; end
        if isfield(fovObj.drift,'y') && ~isempty(fovObj.drift.y), yNew(locOld) = fovObj.drift.y; end
        if isfield(fovObj.drift,'score') && ~isempty(fovObj.drift.score), scNew(locOld) = fovObj.drift.score; end
    end

    [~,locNew] = ismember(frameBatch(:)', allF);

    % driftBlk may be indexed by absolute frame id OR by local block index.
    if numel(driftBlk.x) >= max(frameBatch)  % looks like absolute indexing
        xNew(locNew) = driftBlk.x(frameBatch);
        yNew(locNew) = driftBlk.y(frameBatch);
    else                                     % local indexing 1..Tblock
        xNew(locNew) = driftBlk.x(:)';
        yNew(locNew) = driftBlk.y(:)';
    end

    if numel(scoreBlk) >= numel(frameBatch)
        scNew(locNew) = scoreBlk(:)';
    end

    fovObj.drift.frames = allF;
    fovObj.drift.x      = xNew;
    fovObj.drift.y      = yNew;
    fovObj.drift.score  = scNew;
end



        pbFrm.close();

        % 2) Crops + Append ROI par ROI
        for rIdx = 1:nROI
            r  = ROI(rIdx).obj;
            bb = ROI(rIdx).bbox;

            if isempty(bb)
                fprintf('   • ROI %d/%d (%s): invalid bbox → skipped\n', rIdx, nROI, ROI(rIdx).id);
                continue;
            end

            h = ROI(rIdx).h; w = ROI(rIdx).w;

            % --- Extend idempotent guard ---
            if Extend
                h5File = fullfile(fovOutDir, sprintf('im_%s.h5', r.id));
                T_exist = 0;
                if isfile(h5File)
                    try
                        existingCh = listH5Channels(h5File);
                        if ~isempty(existingCh)
                            req = string(chanSelNames);
                            firstHit = intersect(req, existingCh, 'stable');
                            if ~isempty(firstHit)
                                dsPath = "/" + firstHit(1);
                                info   = h5info(h5File, char(dsPath));
                                if numel(info.Dataspace.Size) >= 4
                                    T_exist = info.Dataspace.Size(4);
                                end
                            end
                        end
                    catch
                    end
                end

                if ~isempty(frameBatch) && max(frameBatch) <= T_exist
                    fprintf('   • ROI %d/%d (%s): Extend noop (T_exist=%d, frames %d–%d) → skipped block\n', ...
                        rIdx, nROI, ROI(rIdx).id, T_exist, frameBatch(1), frameBatch(end));
                    continue;
                end
            end

            roiBlock = zeros(h, w, Csel, Tblock, sampleClass);

            for it = 1:Tblock
                bb_now = pickBBoxForFrame(ROI(rIdx), frameBatch(it), it, framesToDo);
                for ic = 1:Csel
                    crop = cropWithPad(blockImg(:,:,ic,it), bb_now(1), bb_now(2), w, h);

                    %% NEW: scale on crop
                    if Scale ~= 1
                        crop = imresize(crop, Scale); % keeps class for numeric types
                    end

                    % if scaled, roiBlock size must match → handle by allocating resized block if needed
                    if Scale ~= 1 && (it==1) && (ic==1)
                        [hh,ww] = size(crop);
                        roiBlock = zeros(hh, ww, Csel, Tblock, sampleClass);
                    end
                    roiBlock(:,:,ic,it) = crop;
                end
            end

            r.image     = roiBlock;
            r.channelid = 1:Csel;

            if ~isstruct(r.display) || ~isfield(r.display,'channel') || isempty(r.display.channel)
                r.display = defaultDisplay(Csel, Csel);
                r.display.channel = chanNamesFOV;
            end

            r.path = fovOutDir;

            if ForceChannelNames
                r.display.channel = chanSelNames;
                r.channelid       = 1:Csel;
            else
                [ok,~] = ismember(chanSelNames, r.display.channel);
                if ~all(ok)
                    warning('ROI %s: requested channels not present in ROI.display.channel and ForceChannelNames=false → skipping write.', ROI(rIdx).id);
                    r.image = [];
                    ROI(rIdx).obj = r;
                    continue;
                end
            end

            r = normalizeROIChannels(r, chanSelNames);

            r.image     = roiBlock;
            r.channelid = 1:Csel;
            r.path      = fovOutDir;

            if isprop(r,'h5path');  r.h5path  = fullfile(fovOutDir, sprintf('im_%s.h5',  r.id)); end
            if isprop(r,'matpath'); r.matpath = fullfile(fovOutDir, sprintf('data_%s.mat', r.id)); end

            r.display.write_abs_start = frameBatch(1) - 1;

            didSave = r.save(chanSelNames, false);

            if ~didSave
                fprintf('        ⚠ nothing written for ROI %s\n', ROI(rIdx).id);
            else
                fprintf('.');
            end

            r.image = [];
            r.display.write_abs_start = [];
            ROI(rIdx).obj = r;
        end

        fprintf('\n');
        pbBlk.update(ib, sprintf('bloc %d/%d terminé', ib, nBlocks));
    end

    pbBlk.close();
    pbFOV.update(kF, sprintf('FOV %d/%d terminé', kF, numel(FOVIndex)));
end
pbFOV.close();

pbUpdateUI(hprogressbar, 1, 'done');

fprintf('\n✅ Extraction complete (append mode).\n');
fprintf('=============================================\n\n');
end

% ========= Helpers =========

function [row,col] = phaseShift(ref, mov)
    ref = ref - mean(ref(:));
    mov = mov - mean(mov(:));
    R = fft2(ref).*conj(fft2(mov));
    R = R ./ max(abs(R), eps);
    r = real(ifft2(R));
    [~,ix] = max(r(:));
    [py,px] = ind2sub(size(r),ix);
    H=size(r,1); W=size(r,2);
    row = py-1; col = px-1;
    if row>H/2, row=row-H; end
    if col>W/2, col=col-W; end
end


function img = toGray(img)
if ndims(img)==3 && size(img,3)==3
    img = rgb2gray(img);
end
end

function out = cropCenter(im, frac)
if frac==1, out = im; return; end
if ~(frac>0 && frac<=1), error('cropping factor must be ]0,1]'); end
[H,W] = size(im);
h = round(H*frac); w = round(W*frac);
r0 = floor((H-h)/2)+1; c0 = floor((W-w)/2)+1;
out = im(r0:r0+h-1, c0:c0+w-1);
end

function im2 = preprocess(im, hipasssigma, apodize, mask)
im2 = double(im);
if hipasssigma>0
    im2 = im2 - imgaussfilt(im2, hipasssigma);
end
if apodize
    persistent win;
    if isempty(win) || ~isequal(size(win), size(im2))
        [H,W] = size(im2);
        wy = hann1d(H);
        wx = hann1d(W);
        win = wy * (wx.');
    end
    im2 = im2 .* win;
end
if ~isempty(mask)
    im2 = im2 .* double(mask);
end
im2 = im2 - mean(im2(:));
s = std(im2(:));
if s>0, im2 = im2./s; end
end

function w = hann1d(n)
if n <= 1
    w = 1;
    return;
end
w = 0.5*(1 - cos(2*pi*(0:n-1)/(n-1)));
w = w(:);
end

function pbUpdateUI(h, frac, msg)
% Compatible with uiprogressdlg or any handle exposing Value/Message
if isempty(h) || ~isvalidHandle(h), return; end
try
    if isprop(h,'Value') && ~isempty(frac) && isfinite(frac)
        h.Value = min(max(double(frac),0),1);
    end
    if nargin>=3 && ~isempty(msg) && isprop(h,'Message')
        h.Message = char(string(msg));
    end
    drawnow limitrate;
catch
end
end

function tf = isvalidHandle(h)
tf = false;
try
    tf = ~isempty(h) && isvalid(h);
catch
    try
        tf = ~isempty(h) && ishghandle(h);
    catch
        tf = false;
    end
end
end

function pb = makeConsolePB(titleStr, totalCount, varargin)
% (UNCHANGED) ...
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

diaryState = get(0,'Diary');
if strcmp(mode,'auto')
    if strcmpi(diaryState,'on')
        mode = 'cr';
    else
        mode = 'cr';
    end
end

st.t0      = tic;
st.lastT   = -inf;
st.lastI   = 0;
st.lastLen = 0;
st.lineOpen = false;

fprintf('%s%s\n', indentStr, char(titleStr));

pb.update = @updatePB;
pb.close  = @closePB;

    function updatePB(i, msg)
        if nargin < 2, msg = ''; end
        i = min(max(0, round(i)), totalCount);

        nowT = toc(st.t0);
        if (nowT - st.lastT < minInt) && (i < totalCount)
            st.lastI = i;
            return;
        end
        st.lastT = nowT;

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

        pad = max(0, st.lastLen - numel(line));
        tail = repmat(' ',1,pad);

        switch mode
            case 'cr'
                if st.lineOpen
                    fprintf('\r');
                end
                fprintf('%s%s', line, tail);
                st.lineOpen = true;

            case 'bs'
                if st.lineOpen && st.lastLen > 0
                    fprintf('%s', repmat('\b',1,st.lastLen));
                    fprintf('%s', repmat(' ',1,st.lastLen));
                    fprintf('%s', repmat('\b',1,st.lastLen));
                end
                fprintf('%s', line);
                st.lineOpen = true;
        end

        if i>=totalCount
            fprintf('\n');
            st.lineOpen = false;
            st.lastLen = 0;
        else
            st.lastLen = numel(line);
        end

        st.lastI = i;
    end

    function closePB()
        if st.lastI < totalCount
            updatePB(totalCount, 'done');
        elseif st.lineOpen
            fprintf('\n');
            st.lineOpen = false;
            st.lastLen = 0;
        end
    end
end

function [h5path, matpath] = getROIFilePaths(r)
roiId = safeStr(getprop(r,'id','ROI'));
roiDir = safeStr(getprop(r,'path',pwd));
h5path  = fullfile(roiDir, sprintf('im_%s.h5',  roiId));
matpath = fullfile(roiDir, sprintf('data_%s.mat',roiId));
end

function hardResetROIh5(r)
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
note = '';
availBytes = 2e9;
try
    if ispc
        m = memory;
        availBytes = double(m.MaxPossibleArrayBytes);
        note = sprintf('Windows memory(): MaxPossibleArrayBytes=%.1f GB', availBytes/1e9);
    else
        try
            feature('memstats'); %#ok<NASGU>
            note = 'feature(''memstats'') available (no unified free bytes) → using 2 GB fallback.';
        catch
            note = 'No memory() on this platform → using 2 GB fallback.';
        end
    end
catch
    note = 'Unable to query memory → using 2 GB fallback.';
end
availBytes = max(256e6, 0.8 * availBytes);
end

function [H,W,sampleBytes] = probeFrameSpec(fovObj, firstChan)
if nargin<2 || isempty(firstChan), firstChan = 1; end
testIm = fovObj.readImage(1, firstChan);
if ~isempty(testIm)
    testIm = forceGray(testIm); % NEW
    [H,W] = size(testIm);
else
    testIm = uint16(0); H=1; W=1;
end
switch class(testIm)
    case {'uint8','int8'},     sampleBytes = 1;
    case {'uint16','int16'},   sampleBytes = 2;
    case {'uint32','int32','single'}, sampleBytes = 4;
    case {'uint64','int64','double'}, sampleBytes = 8;
    otherwise, sampleBytes = 2;
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
        testIm = forceGray(testIm); % NEW
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
testIm = forceGray(testIm); % NEW
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
        im = forceGray(im); % NEW
        if size(im,1)~=H || size(im,2)~=W
            im = safeResizeTo(im, H, W);
        end
        blockImg(:,:,ic,it) = im;

        if ~isempty(progressFcn)
            idx = (ic-1)*T + it;
            msg = sprintf('ch%d frame %d/%d', c, it, T);
            progressFcn(idx, [], msg);
        end
    end
end
end

function im = forceGray(im)
% NEW: ensure grayscale 2D
try
    if ndims(im)==3 && size(im,3)==3
        im = rgb2gray(im);
    elseif ndims(im)>2
        im = im(:,:,1);
    end
catch
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
d.rgb             = repmat([1 1 1], N, 1);
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
Csel = numel(chanSelNames);
oldD = struct();
if isstruct(r.display), oldD = r.display; end

newD = defaultDisplay(Csel, Csel);
newD.channel = chanSelNames(:)';

if isfield(oldD,'channel') && ~isempty(oldD.channel)
    oldNames = string(oldD.channel);
    for ii = 1:Csel
        nm = string(chanSelNames{ii});
        jj = find(oldNames==nm, 1);
        if ~isempty(jj)
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

    if isfield(oldD,'displaylim') && ~isempty(oldD.displaylim) && size(oldD.displaylim,1)==2
        for ii = 1:Csel
            nm = string(chanSelNames{ii});
            jj = find(oldNames==nm, 1);
            if ~isempty(jj) && jj <= size(oldD.displaylim,2) && ii <= size(newD.displaylim,2)
                newD.displaylim(:,ii) = oldD.displaylim(:,jj);
            end
        end
    end
end

r.display   = newD;
r.channelid = 1:Csel;
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

function names = listH5Channels(h5path)
names = string.empty(1,0);
if ~isfile(h5path), return; end
try
    info = h5info(h5path,'/');
    names = string({info.Datasets.Name});
catch
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
n = numel(roiList);
if n==0
    selIdx = [];
    return;
end

if isempty(ROISelect)
    selIdx = 1:n;
    return;
end

if isnumeric(ROISelect)
    vals = ROISelect(:)';
    mask = vals>=1 & vals<=n;
    selIdx = unique(vals(mask), 'stable');
    return;
end

if iscell(ROISelect)
    if positionInFOVIndex < 1 || positionInFOVIndex > numel(ROISelect)
        selIdx = 1:n;
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

selIdx = 1:n;
end
