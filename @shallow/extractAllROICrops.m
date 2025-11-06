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


% --- AJOUT DANS LE PARSING DES ARGUMENTS ---
ForceChannelNames = true;  % impose les noms de canaux des ROI = chanSelNames
Extend            = false; % << NEW: false = hard reset ; true = append/prolong

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
        case "extend"                        % << NEW
            Extend = logical(varargin{i+1}); % << NEW
    end
end


if ~isprop(shallowObj,'fov') || isempty(shallowObj.fov)
    disp('⚠️  No FOV found in shallow object.');
    return;
end

% Liste des FOV à parcourir
allFOV = 1:numel(shallowObj.fov);
if ~isempty(FOVIndex)
    FOVIndex = FOVIndex(:)';
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
if ~isempty(RequestedChans)
    fprintf('  → Requested channels: {%s}\n', strjoin(RequestedChans, ', '));
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

    if isempty(roiList)
        fprintf('\n▶ FOV %d/%d — no ROI, skipped.\n', kF, numel(FOVIndex));

        continue;
    end

    % Infos temporelles / canaux pour la FOV
    [nFramesTotal, nChannels, sampleClass] = inferFOVTimeline(fovObj);

    % Noms de canaux disponibles dans la FOV
    chanNamesFOV = getFOVChannelNames(fovObj, nChannels);


    % Sous-ensemble canaux : par noms → indices
    if isempty(RequestedChans)
        chanSelNames = chanNamesFOV;
        chanSelIdx   = 1:nChannels;
    else
        [isHit, idx] = ismember(RequestedChans, chanNamesFOV);
        if any(~isHit)
            miss = RequestedChans(~isHit);
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

    % Appliquer sous-ensemble temporel si demandé
    if isempty(FrameList)
        framesToDo = 1:nFramesTotal;
    else
        framesToDo = FrameList;
        framesToDo = framesToDo(framesToDo >= 1 & framesToDo <= nFramesTotal);
        if isempty(framesToDo)
            disp('   ⚠️  Frame list outside range, skipping this FOV.');
            continue;
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
        validBox = ~isempty(r.value) && numel(r.value) >= 4;
        if ~validBox
            ROI(rIdx).bbox = [];
            ROI(rIdx).h = 0; ROI(rIdx).w = 0;
        else
            bb = r.value;  % [xmin ymin w h]
            ROI(rIdx).bbox = struct('xmin',bb(1),'ymin',bb(2),'w',bb(3),'h',bb(4));
            ROI(rIdx).h = bb(4); ROI(rIdx).w = bb(3);
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
    doneFrames  = 0; totalFrames = nFramesThisRun;
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
            roiBlock = zeros(h, w, Csel, Tblock, sampleClass);
            for it = 1:Tblock
                for ic = 1:Csel
                    roiBlock(:,:,ic,it) = cropWithPad(blockImg(:,:,ic,it), bb.xmin, bb.ymin, w, h);
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
            end

            r.image = [];           % free RAM
            r.display.write_abs_start = [];
            ROI(rIdx).obj = r;      % write-back

        end

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

function out = progressBarString(doneFrames,totalFrames)
if totalFrames <= 0, totalFrames = 1; end
pct = max(0,min(1, doneFrames/totalFrames));
barLen = 20;
nFull  = round(pct * barLen);
nEmpty = barLen - nFull;
barStr = ['[', repmat('#',1,nFull), repmat('-',1,nEmpty), ']'];
out = sprintf('%s %3.0f%% (%d/%d)', barStr, pct*100, doneFrames, totalFrames);
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


function [list_aligned, shifts, scores] = estimateAndApplyXYDrift(list, opts)
% list: H x W x C x T (uint16/uint8/…)
% opts:
%   .refFrame        (int)    frame de référence (défaut 1)
%   .refChannel      (int)    canal utilisé pour l'estimation (défaut 1)
%   .method          (char)   'phasecorr' (défaut) | 'xcorr' | 'circshift' (pixel)
%   .subpixel        (logical)true par défaut (affinage quadratique du pic)
%   .maxShift        (double) [px] borne max | [] pour illimité
%   .hipassSigma     (double) sigma du flou soustractif (défaut 3) ; 0 = off
%   .apodize         (logical)fenêtrage cosinus bord (défaut true)
%   .rollingRef      (double) alpha EMA 0..1 (0 = pas de rolling, défaut 0)
%   .pyramidLevels   (int)    0/1/2…, multi-échelle (défaut 1 = off)
%   .mask            (HxW)    masque binaire pour pondérer la corrélation (optionnel)

if nargin<2, opts = struct; end
opts = setDefault(opts, 'refFrame', 1);
opts = setDefault(opts, 'refChannel', 1);
opts = setDefault(opts, 'method', 'phasecorr');
opts = setDefault(opts, 'subpixel', true);
opts = setDefault(opts, 'maxShift', []);
opts = setDefault(opts, 'hipassSigma', 3);
opts = setDefault(opts, 'apodize', true);
opts = setDefault(opts, 'rollingRef', 0);
opts = setDefault(opts, 'pyramidLevels', 1);
opts = setDefault(opts, 'mask', []);

[H,W,C,T] = size(list);
list_aligned = list;
shifts = zeros(T,2);   % [dy, dx] par frame
scores = zeros(T,1);   % qualité (hauteur du pic)

% --- 1) Prépare image de référence (canal choisi)
ref = toFloat(list(:,:,opts.refChannel,opts.refFrame));
ref = preprocess(ref, opts);

% --- 2) Boucle frames: estimate -> apply to all channels
for t = 1:T
    mov = toFloat(list(:,:,opts.refChannel,t));
    mov = preprocess(mov, opts);

    switch lower(opts.method)
        case 'phasecorr'
            [dy,dx,score] = drift_phasecorr(ref, mov, opts);
        case 'xcorr'
            [dy,dx,score] = drift_xcorr(ref, mov, opts);
        case 'circshift'
            % estimation via phasecorr mais application pixel (arrondi)
            [dy,dx,score] = drift_phasecorr(ref, mov, opts);
            dy = round(dy); dx = round(dx);
        otherwise
            error('Unknown method: %s', opts.method);
    end

    % Clampe si maxShift défini
    if ~isempty(opts.maxShift)
        dy = max(min(dy, opts.maxShift), -opts.maxShift);
        dx = max(min(dx, opts.maxShift), -opts.maxShift);
    end

    shifts(t,:) = [dy,dx];
    scores(t)   = score;

    % Applique au cube multicanal de la frame t
    for c = 1:C
        frame = list(:,:,c,t);
        list_aligned(:,:,c,t) = imtranslate(frame, [dx, dy], 'linear', 'FillValues', 0);
    end

    % Rolling reference (EMA) si demandé
    if opts.rollingRef > 0 && t>1
        % Recalcule image alignée (canal ref) pour lisser la ref
        movAligned = imtranslate(toFloat(list(:,:,opts.refChannel,t)), [dx, dy], 'linear', 'FillValues', 0);
        movAligned = preprocess(movAligned, opts);
        alpha = opts.rollingRef;
        ref = (1-alpha)*ref + alpha*movAligned;
    end
end
end

% ---------- Helpers ----------

function img = toFloat(img)
if ~isa(img,'double'), img = double(img); end
if max(img(:))>0, img = img./max(img(:)); end
end

function S = setDefault(S, field, val)
if ~isfield(S, field) || isempty(S.(field)), S.(field) = val; end
end

function img = preprocess(img, opts)
if opts.hipassSigma>0
    img = img - imgaussfilt(img, opts.hipassSigma); % high-pass simple
end
if opts.apodize
    persistent win;
    if isempty(win) || ~isequal(size(win), size(img))
        [H,W] = size(img);
        wy = hann1d(H); wx = hann1d(W);
        win = wy*wx.';
    end
    img = img .* win;
end
img = img - mean(img(:));
if std(img(:))>0, img = img./std(img(:)); end
end

function w = hann1d(n)
if n==1, w=1; return; end
w = 0.5*(1-cos(2*pi*(0:n-1)/(n-1)));
end

function [dy,dx,score] = drift_phasecorr(ref, mov, opts)
% Optionnel: pyramide
levels = max(1, round(opts.pyramidLevels));
scaleDy = 0; scaleDx = 0;
for L = levels:-1:1
    s = 1/(2^(L-1));
    R = imresize(ref, s, 'bilinear');
    M = imresize(mov, s, 'bilinear');
    if ~isempty(opts.mask)
        mask = imresize(opts.mask, s, 'nearest');
    else
        mask = [];
    end
    [dyl,dxl,score] = phasecorr2D(R,M,opts.subpixel,mask);
    % Remonte d'échelle
    scaleDy = (scaleDy + dyl)/s;
    scaleDx = (scaleDx + dxl)/s;
    % Recentre mov pour le niveau supérieur
    mov = imtranslate(mov, [scaleDx, scaleDy], 'linear', 'FillValues', 0);
end
dy = scaleDy; dx = scaleDx;
end

function [dy,dx,score] = phasecorr2D(A,B,doSubpixel,mask)
if ~isempty(mask)
    A = A.*mask; B = B.*mask;
end
FA = fft2(A); FB = fft2(B);
R = FA.*conj(FB);
R = R ./ max(eps, abs(R));
r = real(ifft2(R));
[score, idx] = max(r(:));          % hauteur du pic
[py,px] = ind2sub(size(r), idx);   % position
[H,W] = size(r);
% wrap vers décalage signé
if py > H/2, py = py - H; end
if px > W/2, px = px - W; end
dy = py; dx = px;

if doSubpixel
    dy = dy + subpixQuad(r, py, px, 1);
    dx = dx + subpixQuad(r, py, px, 2);
end
end

function ofs = subpixQuad(r, py, px, dim)
% Ajustement quadratique 1D local (dim=1 vertical / 2 horizontal)
try
    if dim==1
        if py<=1 || py>=size(r,1), ofs=0; return; end
        v = r(py-1:px+1<=px); %#ok<NASGU> % silence l'avertissement
        y1 = r(py-1,px); y2 = r(py,px); y3 = r(py+1,px);
    else
        if px<=1 || px>=size(r,2), ofs=0; return; end
        y1 = r(py,px-1); y2 = r(py,px); y3 = r(py,px+1);
    end
    denom = (y1 - 2*y2 + y3);
    if abs(denom) < 1e-12, ofs = 0; else, ofs = 0.5*(y1 - y3)/denom; end
    ofs = max(min(ofs, 0.5), -0.5); % évite les grosses dérives
catch
    ofs = 0;
end
end

function [dy,dx,score] = drift_xcorr(ref, mov, opts)
% Normxcorr2 sur une ROI centrale (plus robuste si bords non informatifs)
win = centerWindow(size(ref), 0.8);  % 80% centre
tpl = ref(win.r, win.c);
c = normxcorr2(tpl, mov);
[score, idx] = max(c(:));
[py,px] = ind2sub(size(c), idx);
% Conversion en décalage
py = py - size(tpl,1);
px = px - size(tpl,2);
% Décalage relatif à l'origine du template
dy = py - (win.r(1)-1);
dx = px - (win.c(1)-1);
if ~opts.subpixel, dy=round(dy); dx=round(dx); end
end

function win = centerWindow(sz, frac)
H = sz(1); W = sz(2);
h = max(8, round(H*frac)); w = max(8, round(W*frac));
r0 = floor((H-h)/2)+1; c0 = floor((W-w)/2)+1;
win.r = r0:(r0+h-1);
win.c = c0:(c0+w-1);
end

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

function T = getH5TimeLen(h5path, dset)
% retourne la taille T (4e dim) si dataset existe, sinon 0
T = 0;
if ~isfile(h5path), return; end
try
    info = h5info(h5path, ['/' dset]);
    sz = info.Dataspace.Size;
    if numel(sz)>=4, T = sz(4); end
catch
    % dataset absent
end
end


