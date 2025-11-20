function [paramout,dataout,imageout] = trackMotherLineageViterbi(param, roiobj, frames)
%TRACKMOTHERLINEAGEVITERBI Suivi Viterbi d'une lignée mère + bud dans un piège.
%
% SYNOPSIS
%   [paramout, dataout, imageout] = trackMotherLineageViterbi(param, roiobj, frames)
%
% DESCRIPTION
%   Suivi simultané d'une cellule "mère" et, éventuellement, d'un unique
%   bourgeon ("bud") dans un piège microfluidique.
%   À chaque frame t, on cherche l'état optimal (M_t, B_t) où :
%       - M_t est l'indice de la cellule mère (ou 0 si aucune mère suivie),
%       - B_t est l'indice du bud (ou 0 si pas de bud),
%       - au plus un bud à la fois et B_t ~= M_t si B_t>0.
%
%   L'observation privilégie :
%       - pour la mère : la cellule la plus proche du centre et (optionnellement) la plus grosse,
%       - pour le bud  : une cellule petite et proche de la mère.
%   Le Viterbi impose une continuité temporelle (faible mouvement, faible variation d'aire,
%   pénalité pour apparition/disparition et pour changements trop brutaux).
%
%   SORTIE CANAUX (sur roiobj.image) :
%     Soit baseName = param.outputChannelName :
%
%       1) Channel baseName (H×W×1×Tfull, uint8) :
%          - 0   : fond
%          - 255 : mère
%          - 2–254 : bud, intensité ∝ aire du bud (normalisée sur toutes les frames traitées)
%
%       2) Channel [baseName '_Bconf'] (H×W×1×Tfull, uint8) :
%          - 0   : pas de bud / confiance nulle
%          - 1–255 : confiance Viterbi sur le bud, par pixel bud (constante à l'intérieur du bud)
%          La confiance est basée sur la marge entre l'état (M,B) optimal et
%          le meilleur état concurrent, passée dans une sigmoïde.
%
% INPUTS
%   param   : struct de paramètres (géré par le GUI) contenant au minimum :
%       - param.instanceChannelName : cellstr
%           Liste de noms de canaux possibles pour la segmentation d'instances.
%           Le canal effectivement utilisé est param.instanceChannelName{end}.
%       - param.mode : {'mother_trap', ...}
%           Mode de suivi. Pour l'instant seul 'mother_trap' est supporté.
%       - param.outputChannelName : char
%           Nom de base des canaux de sortie :
%             * baseName          : mask mère+bud encodé taille (0, 2–254, 255)
%             * [baseName '_Bconf']: map de confiance bud.
%
%   roiobj  : objet ROI, supposé contenir au moins :
%       - roiobj.image : tableau [H x W x C x Tfull]
%           Empilement d'images ou de masques, dont un canal avec les labels d'instance.
%       - roiobj.data  : données associées (non modifiées ici).
%
%   frames  : (optionnel) vecteur d'indices de frames à traiter (1-based).
%             Exemples : [] (toutes les frames), 1:T, 30:35, [10 12 20].
%             Si vide ou non fourni, toutes les frames disponibles sont utilisées.
%
% OUTPUTS
%   paramout : struct param non modifié (placeholder pour compatibilité process)
%   dataout  : roiobj.data (passe-plat)
%   imageout : roiobj.image mis à jour avec les deux canaux de sortie.
%
% PARAMÈTRES INTERNES / RANGES (à tuner éventuellement)
%   wM_center      : poids de la proximité au centre pour la mère (~1.0)
%   wM_area        : poids de l'aire de la mère       (0–2)
%   wB_dist        : poids de la proximité mère–bud   (0.5–2)
%   wB_small       : poids pour favoriser un bud plus petit que la mère (0.5–2)
%
%   lambdaM_jump   : pénalité par pixel de déplacement mère     (0.01–0.5)
%   lambdaM_area   : pénalité sur variation d'aire mère         (0.001–0.1)
%   lambdaM_appear : pénalité apparition de mère                (0.5–5)
%   lambdaM_disapp : pénalité disparition de mère               (0.5–5)
%
%   lambdaB_jump   : pénalité par pixel de déplacement bud      (0.01–0.5)
%   lambdaB_area   : pénalité sur variation d'aire bud          (0.001–0.1)
%   lambdaB_appear : pénalité apparition bud                    (0.5–5)
%   lambdaB_disapp : pénalité disparition bud                   (0.5–5)
%
% DEBUG
%   La fonction affiche dans la console :
%   - la trajectoire finale frame par frame : M_t (label) et B_t (label),
%   - les SWITCHs de mère et de bud.

%% ---- GUI configuration / initialisation param par défaut ----
if nargin == 0
    % Liste des canaux disponibles pour l'instance segmentation
    ch = listAvailableChannels;
    if isempty(ch)
        ch = {'N/A'};
    end

    paramout.instanceChannelName = ['N/A', ch, ch{end}];
    paramout.mode               = {'mother_trap','mother_trap'};
    paramout.outputChannelName  = 'MotherLineageViterbi';

    paramout.tip = { ...
        'Sélectionnez le canal contenant les labels d''instance (ex: CellposeSAM).', ...
        'Mode de suivi (actuellement "mother_trap" uniquement).', ...
        'Nom de base des canaux de sortie : baseName (mask mère+bud), baseName_Bconf (confiance bud).'};
    dataout  = [];
    imageout = [];
    return;
else
    paramout = param;
end

%% ---- Chargement image si nécessaire ----
if isempty(roiobj.image)
    roiobj.load();
end

dataout  = roiobj.data;
imageout = roiobj.image;

% Récupération du canal d'instance
chanID = roiobj.findChannelID(param.instanceChannelName{end});
if isempty(chanID)
    disp('[trackMotherLineageViterbi] Canal instance introuvable; Skipping...');
    return;
end

maskSeq = roiobj.image(:,:,chanID,:);  % H×W×1×Tfull
[H,W,~,Tfull] = size(maskSeq);

%% ---- Gestion des frames (sous-ensemble éventuel) ----
if nargin < 3 || isempty(frames)
    frameIdx = 1:Tfull;
else
    frameIdx = frames(:)'; % vecteur ligne
end

if isempty(frameIdx)
    disp('[trackMotherLineageViterbi] Aucune frame à traiter; Skipping...');
    return;
end

nF = numel(frameIdx);

%% ---- Extraction des features par frame (candidats) ----
feats = localComputeFeaturesFromLabelSeq(maskSeq(:,:,1,frameIdx));

% Nb de candidats par frame
N = zeros(nF,1);
for f = 1:nF
    N(f) = size(feats(f).centroid,1);
end

% On autorise N(f)==0 : alors seul l'état (0,0) sera possible sur cette frame.

%% ---- Paramètres Viterbi (mère + bud) ----
mode = param.mode{end}; %#ok<NASGU>
mode = lower(mode);     %#ok<NASGU>

% Poids observation mère
wM_center   = 1.0;   % importance d'être proche du centre
wM_area     = 0.5;   % importance d'être grosse

% Poids observation bud
wB_dist     = 1.0;   % bud proche de la mère
wB_small    = 1.0;   % bud plus petit que la mère

% Pénalités de transition mère
lambdaM_jump   = 0.05;   % pénalité par pixel de déplacement
lambdaM_area   = 0.01;   % pénalité par variation d'aire
lambdaM_appear = 2.0;    % coût d'apparition d'une mère
lambdaM_disapp = 2.0;    % coût de disparition de la mère

% Pénalités de transition bud
lambdaB_jump   = 0.05;   % pénalité par pixel de déplacement
lambdaB_area   = 0.01;   % pénalité par variation d'aire
lambdaB_appear = 1.0;    % coût d'apparition d'un bud
lambdaB_disapp = 1.0;    % coût de disparition du bud

% Paramètre de "température" pour la sigmoïde de confiance
tempConf = 0.5;

% Géométrie du piège
center  = [W/2, H/2];
maxDistCenter = hypot(center(1), center(2));
maxDistMB     = maxDistCenter;   % même ordre de grandeur

%% ---- Construction des états (M,B) par frame ----
states = struct('mIdx',{},'bIdx',{});
K = zeros(nF,1);  % nombre d'états par frame

for f = 1:nF
    mList = [];
    bList = [];

    Nf = N(f);

    % États avec mère (M>0), bud optionnel (B>=0, B~=M si B>0)
    for m = 1:Nf
        % mère seule
        mList(end+1,1) = m; %#ok<AGROW>
        bList(end+1,1) = 0;
        % mère + bud
        for b = 1:Nf
            if b == m, continue; end
            mList(end+1,1) = m; %#ok<AGROW>
            bList(end+1,1) = b;
        end
    end

    % état (0,0) : aucune cellule suivie
    mList(end+1,1) = 0;
    bList(end+1,1) = 0;

    states(f).mIdx = mList;
    states(f).bIdx = bList;
    K(f)           = numel(mList);
end

%% ---- Construction des scores d'observation logB{f}(k) ----
logB = cell(nF,1);

for f = 1:nF
    Nf    = N(f);
    ctr   = feats(f).centroid;
    area  = feats(f).area;
    Kf    = K(f);

    logBf = zeros(1,Kf);

    % Si aucune cellule, tous les états sont (0,0), logBf sera juste 0
    if Nf > 0
        dxC = ctr(:,1) - center(1);
        dyC = ctr(:,2) - center(2);
        distC = hypot(dxC, dyC);

        if any(area)
            areaNorm = area ./ max(area);
        else
            areaNorm = zeros(size(area));
        end
        centerScore = 1 - distC ./ maxDistCenter;
        centerScore = max(centerScore, 0);
    else
        areaNorm    = [];
        centerScore = [];
    end

    for kState = 1:Kf
        m = states(f).mIdx(kState);
        b = states(f).bIdx(kState);

        obsM = 0;
        obsB = 0;

        % Mère
        if m > 0
            obsM = wM_center * centerScore(m) + ...
                   wM_area   * areaNorm(m);
        else
            % pas de mère : état moins favorable que "bonne" mère
            obsM = -2.0;
        end

        % Bud
        if b > 0 && m > 0 && Nf > 0
            dxMB = ctr(b,1) - ctr(m,1);
            dyMB = ctr(b,2) - ctr(m,2);
            distMB = hypot(dxMB, dyMB);
            distScore = 1 - distMB ./ maxDistMB;
            distScore = max(distScore, 0);

            budRelArea = area(b) ./ max(area(m), eps);
            budRelArea = min(budRelArea, 2);
            smallScore = 1 - budRelArea; % 1 si bud << mère

            obsB = wB_dist  * distScore + ...
                   wB_small * smallScore;
        elseif b > 0 && m == 0
            % bud sans mère : incohérent
            obsB = -10;
        else
            obsB = 0;   % pas de bud
        end

        logBf(kState) = obsM + obsB;
    end

    logB{f} = logBf;
end

%% ---- Fonction de coût de transition entre états (M,B) ----
    function val = transLogState(kPrev, kCurr, fidx)
        mPrev = states(fidx).mIdx(kPrev);
        bPrev = states(fidx).bIdx(kPrev);
        mCurr = states(fidx+1).mIdx(kCurr);
        bCurr = states(fidx+1).bIdx(kCurr);

        ctrPrev  = feats(fidx).centroid;
        ctrCurr  = feats(fidx+1).centroid;
        areaPrev = feats(fidx).area;
        areaCurr = feats(fidx+1).area;

        costM = 0;
        costB = 0;

        % Mère
        if mPrev > 0 && mCurr > 0 && ~isempty(ctrPrev) && ~isempty(ctrCurr)
            dxM = ctrPrev(mPrev,1) - ctrCurr(mCurr,1);
            dyM = ctrPrev(mPrev,2) - ctrCurr(mCurr,2);
            distM = hypot(dxM, dyM);
            dAreaM = abs(areaPrev(mPrev) - areaCurr(mCurr));
            costM = -lambdaM_jump * distM - lambdaM_area * dAreaM;
        elseif mPrev > 0 && mCurr == 0
            costM = -lambdaM_disapp;
        elseif mPrev == 0 && mCurr > 0
            costM = -lambdaM_appear;
        else
            costM = 0;
        end

        % Bud
        if bPrev > 0 && bCurr > 0 && ~isempty(ctrPrev) && ~isempty(ctrCurr)
            dxB = ctrPrev(bPrev,1) - ctrCurr(bCurr,1);
            dyB = ctrPrev(bPrev,2) - ctrCurr(bCurr,2);
            distB = hypot(dxB, dyB);
            dAreaB = abs(areaPrev(bPrev) - areaCurr(bCurr));
            costB = -lambdaB_jump * distB - lambdaB_area * dAreaB;
        elseif bPrev > 0 && bCurr == 0
            costB = -lambdaB_disapp;
        elseif bPrev == 0 && bCurr > 0
            costB = -lambdaB_appear;
        else
            costB = 0;
        end

        val = costM + costB;
    end

%% ---- Viterbi dynamique sur les états (M,B) ----
delta = cell(nF,1);
psi   = cell(nF,1);

delta{1} = logB{1};
psi{1}   = zeros(1, K(1));

for f = 2:nF
    Kprev = K(f-1);
    Kcurr = K(f);

    d  = -Inf(1, Kcurr);
    bp = zeros(1, Kcurr);

    for kCurr = 1:Kcurr
        best = -Inf;
        arg  = 0;
        for kPrev = 1:Kprev
            sc = delta{f-1}(kPrev) + transLogState(kPrev, kCurr, f-1);
            if sc > best
                best = sc;
                arg  = kPrev;
            end
        end
        d(kCurr)  = best + logB{f}(kCurr);
        bp(kCurr) = arg;
    end

    delta{f} = d;
    psi{f}   = bp;
end

statePath = nan(nF,1);
[~, kBest] = max(delta{nF});
statePath(nF) = kBest;

for f = nF:-1:2
    kPrev = psi{f}(kBest);
    statePath(f-1) = kPrev;
    kBest = kPrev;
end

%% ---- Extraction des chemins mère/bud et readout debug ----
fprintf('[trackMotherLineageViterbi] Viterbi path (M,B) sur %d frames:\n', nF);

mPath = zeros(nF,1);
bPath = zeros(nF,1);

for f = 1:nF
    k     = statePath(f);
    mIdx  = states(f).mIdx(k);
    bIdx  = states(f).bIdx(k);
    mPath(f) = mIdx;
    bPath(f) = bIdx;

    tReal = frameIdx(f);

    if mIdx > 0 && ~isempty(feats(f).label)
        mLab = feats(f).label(mIdx);
    else
        mLab = 0;
    end

    if bIdx > 0 && ~isempty(feats(f).label)
        bLab = feats(f).label(bIdx);
    else
        bLab = 0;
    end

    if f == 1
        fprintf('  Frame %3d: START M=%d (idx=%d), B=%d (idx=%d)\n', ...
            tReal, mLab, mIdx, bLab, bIdx);
    else
        prevMIdx = mPath(f-1);
        prevBIdx = bPath(f-1);
        prevMLab = 0;
        prevBLab = 0;
        if prevMIdx > 0 && ~isempty(feats(f-1).label), prevMLab = feats(f-1).label(prevMIdx); end
        if prevBIdx > 0 && ~isempty(feats(f-1).label), prevBLab = feats(f-1).label(prevBIdx); end

        msg = sprintf('  Frame %3d: M=%d (idx=%d), B=%d (idx=%d)', ...
                      tReal, mLab, mIdx, bLab, bIdx);

        if mLab ~= prevMLab
            msg = [msg, '  [M-SWITCH]']; %#ok<AGROW>
        end
        if bLab ~= prevBLab
            msg = [msg, '  [B-SWITCH]']; %#ok<AGROW>
        end

        fprintf('%s\n', msg);
    end
end

%% ---- Confiance bud (option B : marge vs meilleur compétiteur, sigmoïde) ----
budConf = zeros(nF,1);

for f = 1:nF
    bIdx = bPath(f);
    if bIdx <= 0
        budConf(f) = 0;
        continue;
    end

    d = delta{f};
    if isempty(d) || any(isinf(d))
        budConf(f) = 0;
        continue;
    end

    kBest = statePath(f);
    dBest = d(kBest);

    % États compétiteurs : tous sauf ceux avec même bud (y compris B=0)
    competitors = find(states(f).bIdx ~= bIdx);
    if isempty(competitors)
        dComp = min(d);  % aucun concurrent → confiance forte
    else
        dComp = max(d(competitors));
    end

    margin = dBest - dComp;
    conf   = 1 ./ (1 + exp(-margin / tempConf));  % sigmoïde
    conf   = max(min(conf,1), 0);

    budConf(f) = conf;
end

%% ---- Normalisation des tailles pour encoder l'intensité du bud (2–254) ----
allAreas = [];
for f = 1:nF
    if ~isempty(feats(f).area)
        allAreas = [allAreas; feats(f).area(:)]; %#ok<AGROW>
    end
end
allAreas = allAreas(allAreas > 0);

if isempty(allAreas)
    minA = 1;
    maxA = 1;
else
    minA = min(allAreas);
    maxA = max(allAreas);
    if maxA == minA
        maxA = minA + 1;
    end
end

%% ---- Construction des deux sorties : MBmask et BconfMap ----
motherBudMask = zeros(H,W,1,nF,'uint8');   % 0=fond, 255=mère, 2–254=bud (taille)
budConfMap    = zeros(H,W,1,nF,'uint8');   % 0=fond, 1–255=confiance bud

for f = 1:nF
    tReal = frameIdx(f);
    frm   = maskSeq(:,:,1,tReal);  % labels image

    mIdx = mPath(f);
    bIdx = bPath(f);

    planeMask = zeros(H,W,'uint8');
    planeConf = zeros(H,W,'uint8');

    % Mère = 255 (fixe)
    if mIdx > 0 && ~isempty(feats(f).label)
        mLab = feats(f).label(mIdx);
        planeMask(frm == mLab) = uint8(255);
    end

    % Bud = 2–254 selon taille, et confiance dans planeConf
    if bIdx > 0 && ~isempty(feats(f).label) && ~isempty(feats(f).area)
        bLab  = feats(f).label(bIdx);
        aBud  = feats(f).area(bIdx);
        x = (aBud - minA) / (maxA - minA);
        x = max(min(x,1),0);
        budVal = 2 + round(x * (254-2));  % [2..254]
        budVal = uint8(budVal);

        maskB = (frm == bLab);
        planeMask(maskB) = budVal;

        % Confiance bud (0..1 → 0..255) sur les pixels du bud
        c = budConf(f);
        cVal = uint8(round(max(min(c,1),0) * 255));
        planeConf(maskB) = cVal;
    end

    motherBudMask(:,:,1,f) = planeMask;
    budConfMap   (:,:,1,f) = planeConf;
end

%% ---- Sauvegarde dans roiobj.image ----
baseName   = paramout.outputChannelName;
cellName   = [baseName '_cell'];
confName   = [baseName '_conf'];

% Dimensions complètes
[Hfull,Wfull,~,Tfull] = size(roiobj.image);

% Sanity check spatial
if Hfull ~= H || Wfull ~= W
    error('trackMotherLineageViterbi:SizeMismatch', ...
        'Taille spatiale de roiobj.image [%d %d] différente de maskSeq [%d %d].', ...
        Hfull, Wfull, H, W);
end

% --- 1) Canal mask mère+bud encodé taille ---
pixMask = roiobj.findChannelID(cellName);
if ~isempty(pixMask)
    disp('[trackMotherLineageViterbi] Mask mère+bud existe déjà, mise à jour des frames sélectionnées.');
    for k = 1:nF
        roiobj.image(:,:,pixMask, frameIdx(k)) = motherBudMask(:,:,1,k);
    end
else
    motherBudMaskFull = zeros(Hfull,Wfull,1,Tfull,'uint8');
    nFill = min(nF, numel(frameIdx));
    for k = 1:nFill
        motherBudMaskFull(:,:,1, frameIdx(k)) = motherBudMask(:,:,1,k);
    end
    roiobj.addChannel(motherBudMaskFull, cellName, [1 1 1], [0 0 0]);
end

% --- 2) Canal confiance bud ---
pixConf = roiobj.findChannelID(confName);
if ~isempty(pixConf)
    disp('[trackMotherLineageViterbi] Canal de confiance bud existe déjà, mise à jour des frames sélectionnées.');
    for k = 1:nF
        roiobj.image(:,:,pixConf, frameIdx(k)) = budConfMap(:,:,1,k);
    end
else
    budConfFull = zeros(Hfull,Wfull,1,Tfull,'uint8');
    nFill = min(nF, numel(frameIdx));
    for k = 1:nFill
        budConfFull(:,:,1, frameIdx(k)) = budConfMap(:,:,1,k);
    end
    roiobj.addChannel(budConfFull, confName, [1 1 1], [0 0 0]);
end

dataout  = roiobj.data;
imageout = roiobj.image;

end % main function


%% ========================================================================
function feats = localComputeFeaturesFromLabelSeq(maskSeq)
%LOCALCOMPUTEFEATURESFROMLABELSEQ Convertit H×W×1×T de labels en features par frame.
%
% feats(t).centroid : [N_t x 2] (x,y) des centroids
% feats(t).area     : [N_t x 1] aire (en pixels) de chaque objet
% feats(t).label    : [N_t x 1] valeur de label dans le masque original

[H,W,~,T] = size(maskSeq); %#ok<ASGLU>

feats = repmat(struct('centroid',[],'area',[],'label',[]), 1, T);

for t = 1:T
    L = maskSeq(:,:,1,t);

    ids = unique(L(:));
    ids(ids == 0) = [];
    N = numel(ids);

    if N == 0
        feats(t).centroid = zeros(0,2);
        feats(t).area     = zeros(0,1);
        feats(t).label    = zeros(0,1);
        continue;
    end

    centroids = zeros(N,2);
    areas     = zeros(N,1);

    for k = 1:N
        id = ids(k);
        Mk = (L == id);
        A  = nnz(Mk);
        areas(k) = A;

        if A > 0
            s = regionprops(Mk, 'Centroid');
            if ~isempty(s)
                centroids(k,:) = s.Centroid;
            else
                [yy,xx] = find(Mk,1,'first');
                centroids(k,:) = [xx yy];
            end
        else
            centroids(k,:) = [W/2 H/2];
        end
    end

    feats(t).centroid = centroids;
    feats(t).area     = areas;
    feats(t).label    = ids;
end

end
