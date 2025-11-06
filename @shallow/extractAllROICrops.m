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

        

            % Bloc courant : [h w Csel Tblock]
            r.image     = roiBlock;
            r.channelid = 1:numel(chanSelNames);
            r.path      = fovOutDir;

            % Sauvegarde append: on passe UNIQUEMENT le bloc courant, avec les noms imposés
            didSave = r.save( chanSelNames, false );

            if ~didSave
                fprintf('        ⚠ nothing written for ROI %s\n', ROI(rIdx).id);
            end

            % libérer RAM immédiatement
            r.image = [];
            ROI(rIdx).obj = r;
        end

        pbBlk.update(ib, sprintf('bloc %d/%d terminé', ib, nBlocks));

        % 3) Progression
        doneFrames = fe;
       % fprintf('\x1b[2A');
       % fprintf('      Loading frames  %s   block %d/%d\n', ...
       %     progressBarString(doneFrames,totalFrames), ib, nBlocks);
        %fprintf('      Cropping ROIs   %s   block %d/%d\n', ...
        %    progressBarString(doneFrames,totalFrames), ib, nBlocks);
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
%MAKECONSOLEPB Console progress bar overwriting a single line using backspaces.
%   pb = makeConsolePB('Blocs', N)
%   pb = makeConsolePB('Frames', N, 'Indent',4, 'Width',40, 'MinInterval',0.05)
%
% Public API:
%   pb.update(i, msg)   % i in [0..N], msg optional short status
%   pb.close()

ip = inputParser;
ip.addParameter('Indent',0,@(x)isnumeric(x)&&isscalar(x));
ip.addParameter('Width',40,@(x)isnumeric(x)&&isscalar(x)&&x>=5);
ip.addParameter('MinInterval',0.05,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('ShowETA',true,@(x)islogical(x)&&isscalar(x));
ip.parse(varargin{:});

indentN = ip.Results.Indent;
width   = ip.Results.Width;
minInt  = ip.Results.MinInterval;
showETA = ip.Results.ShowETA;

indentStr  = repmat(' ',1,max(0,indentN));
totalCount = max(1, round(totalCount));

state.t0      = tic;
state.lastT   = -inf;
state.lastI   = 0;
state.lastLen = 0;   % printed chars count for backspacing
state.started = false;

% Titre (ligne séparée), puis on crée la ligne de PB vide
fprintf('%s%s\n', indentStr, char(titleStr));
fprintf('%s', indentStr);               % amener le curseur sur la ligne PB
state.started = true;

pb.update = @updatePB;
pb.close  = @closePB;

% ==================== nested ====================
    function updatePB(i, msg)
        if nargin < 2, msg = ''; end
        i = min(max(0, round(i)), totalCount);

        nowT = toc(state.t0);
        if (nowT - state.lastT < minInt) && (i < totalCount)
            state.lastI = i;
            return;
        end
        state.lastT = nowT;

        frac   = i / totalCount;
        filled = max(0, min(width, round(frac * width)));
        barStr = ['[', repmat('=',1,filled), repmat(' ',1,width-filled), ']'];
        pctStr = sprintf('%3.0f%%', 100*frac);

        if showETA
            if i > 0
                rate   = i / max(nowT, eps);
                remain = (totalCount - i) / max(rate, eps);
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

        % limiter la longueur globale ~100 caractères
        maxLine = 100;
        roomForMsg = max(0, maxLine - numel(fixed) - 1);
        if ~isempty(msg)
            if numel(msg) > roomForMsg
                msg = [msg(1:max(0,roomForMsg-3)) '...'];
            end
            line = sprintf('%s %s', fixed, msg);
        else
            line = fixed;
        end

        % effacer l'ancienne ligne (backspaces), puis réimprimer
        if state.started && state.lastLen > 0
            fprintf('%s', repmat('\b',1,state.lastLen));  % revenir en arrière
            fprintf('%s', repmat(' ',1,state.lastLen));   % effacer
            fprintf('%s', repmat('\b',1,state.lastLen));  % revenir au début de la ligne
        end

        % imprimer la nouvelle ligne (sans \n)
        fprintf('%s%s', indentStr, line);

        state.lastLen = numel(indentStr) + numel(line);
        state.lastI   = i;

        % si terminé, on fixe la ligne et passe à la suivante
        if i >= totalCount
            fprintf('\n');
            % réinitialiser le compteur de longueur, ligne validée
            state.lastLen = 0;
            % et replacer l'indent pour une future nouvelle PB imbriquée
            fprintf('%s', indentStr);
        end
    end

    function closePB()
        if state.lastI < totalCount
            updatePB(totalCount, 'done');
        elseif state.lastLen > 0
            % si quelqu'un a imprimé au milieu, sécuriser un retour à la ligne
            fprintf('\n');
            state.lastLen = 0;
        end
    end
end


function hardResetROIh5(roi)
if isfile(roi.h5path), delete(roi.h5path); end
if isfile(roi.matpath), delete(roi.matpath); end % si tu veux repartir de zéro
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
