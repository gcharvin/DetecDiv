function [paramout,dataout,imageout] = core(param, roiobj, frames)
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
%       - Mode 'mother_trap'  : mère proche du centre (et éventuellement grosse),
%       - Mode 'daughter_trap': mère au FOND de la cavité (bas de l'image),
%       - Bud : petit et proche de la mère.
%
%   Le Viterbi impose une continuité temporelle (faible mouvement, faible
%   variation d'aire, pénalité pour apparition/disparition et pour changements
%   trop brutaux). En mode 'daughter_trap', le changement de "mère" n'est
%   autorisé que lorsqu'un bud en bas devient suffisamment gros (bud->mère).
%
%   SORTIE CANAUX (sur roiobj.image) :
%     Soit baseName = param.outputChannelName :
%
%       1) Channel [baseName '_cell'] (H×W×1×Tfull, uint8) :
%          - 0   : fond
%          - 255 : mère
%          - 2–254 : bud, intensité ∝ aire du bud (normalisée sur toutes
%                    les frames traitées)
%
%       2) Channel [baseName '_conf'] (H×W×1×Tfull, uint8) :
%          - 0   : pas de bud / confiance nulle
%          - 1–255 : confiance Viterbi sur le bud, par pixel bud
%                    (constante à l'intérieur du bud)
%
% INPUTS
%   param   : struct de paramètres (géré par le GUI) contenant au minimum :
%       - param.instanceChannelName : cellstr
%           Liste de noms de canaux possibles pour la segmentation d'instances.
%           Le canal effectivement utilisé est param.instanceChannelName{end}.
%       - param.mode : {'mother_trap', ...} ou {'daughter_trap', ...}
%           * 'mother_trap'  : mère ~ centre
%           * 'daughter_trap': lignée fille au fond (bas de la cavité)
%       - param.outputChannelName : char
%           Nom de base des canaux de sortie :
%             * [baseName '_cell']  : mask mère+bud encodé taille (0,2–254,255)
%             * [baseName '_conf']  : map de confiance bud.
%
%   roiobj  : objet ROI, supposé contenir au moins :
%       - roiobj.image : tableau [H x W x C x Tfull]
%           Empilement d'images ou de masques, dont un canal avec les
%           labels d'instance.
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
%   (communs mother/daughter, mais interprétés différemment pour la mère)
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
%   (spécifique daughter_trap)
%   bottomSign     : +1 si le "fond" est vers y croissant (valeur par défaut)
%   ratioMin       : aire(bud)/aire(mère) minimale pour autoriser bud->mère
%   bonusSwitch    : petit bonus sur la transition bud->mère valide.
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
    paramout.mode               = {'mother_trap','mother_trap'};   % mother_trap ou daughter_trap
    paramout.outputChannelName  = 'MotherLineageViterbi';

    paramout.tip = { ...
        'Sélectionnez le canal contenant les labels d''instance (ex: CellposeSAM).', ...
        'Mode de suivi (mother_trap ou daughter_trap).', ...
        'Nom de base des canaux de sortie : baseName_cell (mask mère+bud), baseName_conf (confiance bud).'};
    dataout  = [];
    imageout = [];
    return;
else
    paramout = param;
end

paramout = trackMotherLineageViterbi.normalizeParam(paramout);

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
mode        = lower(param.mode{end});
isDaughter  = strcmp(mode,'daughter_trap');   % nouveau flag
isMother    = strcmp(mode,'mother_trap');

% Poids observation mère
wM_center   = localNumericParam(paramout, 'wM_center', 1.0);   % pour mother_trap (proximité centre)
wM_area     = localNumericParam(paramout, 'wM_area', 0.5);      % importance d'être grosse
wM_bottom   = localNumericParam(paramout, 'wM_bottom', 1.0);    % pour daughter_trap (proximité du fond)

% Poids observation bud
wB_dist     = localNumericParam(paramout, 'wB_dist', 1.0);      % bud proche de la mère
wB_small    = localNumericParam(paramout, 'wB_small', 1.0);     % bud plus petit que la mère

% Pénalités de transition mère
lambdaM_jump   = localNumericParam(paramout, 'lambdaM_jump', 0.05);   % pénalité par pixel de déplacement
lambdaM_area   = localNumericParam(paramout, 'lambdaM_area', 0.01);   % pénalité par variation d'aire
lambdaM_appear = localNumericParam(paramout, 'lambdaM_appear', 2.0);  % coût d'apparition d'une mère
lambdaM_disapp = localNumericParam(paramout, 'lambdaM_disapp', 2.0);  % coût de disparition de la mère

% Pénalités de transition bud
lambdaB_jump   = localNumericParam(paramout, 'lambdaB_jump', 0.05);   % pénalité par pixel de déplacement
lambdaB_area   = localNumericParam(paramout, 'lambdaB_area', 0.01);   % pénalité par variation d'aire
lambdaB_appear = localNumericParam(paramout, 'lambdaB_appear', 1.0);  % coût d'apparition d'un bud
lambdaB_disapp = localNumericParam(paramout, 'lambdaB_disapp', 1.0);  % coût de disparition du bud

% Paramètre de "température" pour la sigmoïde de confiance
tempConf   = localNumericParam(paramout, 'tempConf', 0.5);

% Paramètres spécifiques au mode daughter_trap
bottomSign  = localNumericParam(paramout, 'bottomSign', 1.0);   % suppose y croissant vers le fond (changer signe si besoin)
ratioMin    = localNumericParam(paramout, 'ratioMin', 0.4);     % aire(bud)/aire(mère) minimale pour autoriser bud->mère
bonusSwitch = localNumericParam(paramout, 'bonusSwitch', 1.0);  % petit bonus sur un switch bud->mère valide

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

    if Nf > 0
        % Distance au centre
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

        % Score "fond de cavité" pour daughter_trap
        if isDaughter
            proj   = ctr(:,2) * bottomSign;    % projection sur l'axe vertical
            minP   = min(proj);
            maxP   = max(proj);
            if maxP > minP
                bottomScore = (proj - minP) ./ (maxP - minP); % 0..1
            else
                bottomScore = 0.5 * ones(size(proj));         % tous équivalents
            end
        else
            bottomScore = [];
        end
    else
        areaNorm    = [];
        centerScore = [];
        bottomScore = [];
    end

    for kState = 1:Kf
        m = states(f).mIdx(kState);
        b = states(f).bIdx(kState);

        obsM = 0;
        obsB = 0;

        % --- Mère ---
        if m > 0 && Nf > 0
            if isMother
                % mode mother_trap : mère proche du centre
                obsM = wM_center * centerScore(m) + ...
                       wM_area   * areaNorm(m);
            elseif isDaughter
                % mode daughter_trap : mère au fond de la cavité
                obsM = wM_bottom * bottomScore(m) + ...
                       wM_area   * areaNorm(m);
            else
                obsM = wM_center * centerScore(m) + ...
                       wM_area   * areaNorm(m);
            end
        elseif m > 0 && Nf == 0
            obsM = -2.0;
        else
            % pas de mère : état moins favorable qu'une "bonne" mère
            obsM = -2.0;
        end

        % --- Bud ---
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

        % -------- Mère --------
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

        % -------- Bud --------
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

        % -------- Contraintes spécifiques au mode daughter_trap --------
        if isDaughter
            % Interdire les changements de mère SAUF si c'est
            % l'ancien bud qui devient mère (bud->mère)
            if mPrev ~= mCurr
                % cas autorisé : mPrev>0, bPrev>0, mCurr == bPrev
                if ~(mPrev > 0 && bPrev > 0 && mCurr == bPrev)
                    val = -Inf;
                    return;
                end

                % On est dans le motif bud->mère : vérifier que le bud est
                % bien en bas et suffisamment grand (dans la frame fidx)
                if ~isempty(ctrPrev) && ~isempty(areaPrev)
                    yM = ctrPrev(mPrev,2);
                    yB = ctrPrev(bPrev,2);
                    dy = (yB - yM) * bottomSign;

                    % Bud doit être "en bas" de la mère
                    if dy <= 0
                        val = -Inf;
                        return;
                    end

                    % Bud doit avoir une aire suffisante pour devenir fille
                    ratio = areaPrev(bPrev) / max(areaPrev(mPrev), eps);
                    if ratio < ratioMin
                        val = -Inf;
                        return;
                    end

                    % Switch bud->mère valide : petit bonus
                    val = val + bonusSwitch;
                end
            end
        end
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
fprintf('[trackMotherLineageViterbi] Viterbi path (M,B) sur %d frames (mode=%s):\n', nF, mode);

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

%% ---- Confiance bud (marge vs meilleur compétiteur, sigmoïde) ----
budConf = zeros(nF,1);

for f = 1:nF
    bIdx = bPath(f);
    if bIdx <= 0
        budConf(f) = 0;
        continue;
    end

    d = delta{f};
    if isempty(d) || all(isinf(d))
        budConf(f) = 0;
        continue;
    end

    kBest = statePath(f);
    dBest = d(kBest);

    % États compétiteurs : tous sauf ceux avec le même bud (y compris B=0)
    competitors = find(states(f).bIdx ~= bIdx);
    if isempty(competitors)
        dComp = min(d);  % aucun concurrent explicite → confiance forte
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

%% ---- Construction des deux sorties : motherMask et budMask ----
% motherBudMask : masque binaire (0/1) de la mère uniquement
% budConfMap    : masque binaire (0/1) du bud uniquement

motherBudMask = zeros(H, W, 1, nF, 'single');   % 1 = mère, 0 = fond
budConfMap    = zeros(H, W, 1, nF, 'single');   % 1 = bud,   0 = fond

for f = 1:nF
    tReal = frameIdx(f);
    frm   = maskSeq(:,:,1, tReal);  % labels d'instances

    mIdx = mPath(f);   % index mère
    bIdx = bPath(f);   % index bud

    planeMother = zeros(H, W, 'single');
    planeBud    = zeros(H, W, 'single');

    % ----- MÈRE -----
    if mIdx > 0 && ~isempty(feats(f).label)
        mLab = feats(f).label(mIdx);   % label d'instance de la mère
        maskM = (frm == mLab);
        planeMother(maskM) = 1;        % mère = 1
    end

    % ----- BUD -----
    if bIdx > 0 && ~isempty(feats(f).label)
        bLab = feats(f).label(bIdx);   % label d'instance du bud
        maskB = (frm == bLab);
        planeBud(maskB) = 1;           % bud = 1
    end

    motherBudMask(:,:,1,f) = planeMother;
    budConfMap   (:,:,1,f) = planeBud;
end


%% ---- Sauvegarde dans roiobj.image ----
baseName   = paramout.outputChannelName;
cellName   = [baseName '_cell'];
confName   = [baseName '_conf'];

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
    roiobj.addChannel(motherBudMaskFull, cellName, [1 0 0], [0 0 0]);
end
pixMask = roiobj.findChannelID(cellName);
if ~isempty(pixMask)
    localSetIndexedOutputDisplay(roiobj, pixMask, [1 0 0]);
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
    roiobj.addChannel(budConfFull, confName, [0 1 0], [0 0 0]);
end
pixConf = roiobj.findChannelID(confName);
if ~isempty(pixConf)
    localSetIndexedOutputDisplay(roiobj, pixConf, [0 1 0]);
end

dataout  = roiobj.data;
imageout = roiobj.image;
paramout.saveChannels = {cellName, confName};

end % main function


%% ========================================================================
function localSetIndexedOutputDisplay(roiobj, pix, rgb)
% Keep Viterbi outputs in indexed/overlay mode after both create and update.
if isempty(pix) || ~isprop(roiobj, 'channelid') || isempty(roiobj.channelid)
    return;
end

logicalId = unique(double(roiobj.channelid(pix)));
logicalId = logicalId(~isnan(logicalId) & logicalId > 0);
if isempty(logicalId)
    return;
end
logicalId = logicalId(1);

if isempty(roiobj.display) || ~isstruct(roiobj.display)
    roiobj.display = struct();
end

roiobj.display.intensity = localEnsureDisplayRows(roiobj.display, 'intensity', logicalId, [1 1 1]);
roiobj.display.rgb = localEnsureDisplayRows(roiobj.display, 'rgb', logicalId, [1 1 1]);
roiobj.display.indexed = localEnsureDisplayVector(roiobj.display, 'indexed', logicalId, 0);
roiobj.display.alpha = localEnsureDisplayVector(roiobj.display, 'alpha', logicalId, 1);
roiobj.display.contour = localEnsureDisplayVector(roiobj.display, 'contour', logicalId, 0);
roiobj.display.width = localEnsureDisplayVector(roiobj.display, 'width', logicalId, 0);
roiobj.display.selectedchannel = localEnsureDisplayVector(roiobj.display, 'selectedchannel', logicalId, 1);

roiobj.display.intensity(logicalId,:) = [0 0 0];
roiobj.display.rgb(logicalId,:) = double(rgb(:)).';
roiobj.display.indexed(logicalId) = 1;
roiobj.display.alpha(logicalId) = 0.5;
roiobj.display.contour(logicalId) = 1;
roiobj.display.width(logicalId) = 1.5;
roiobj.display.selectedchannel(logicalId) = 1;
end

function value = localEnsureDisplayRows(display, fieldName, nRows, defaultRow)
if isfield(display, fieldName) && ~isempty(display.(fieldName))
    value = double(display.(fieldName));
else
    value = zeros(0, numel(defaultRow));
end

if isvector(value) && numel(value) == numel(defaultRow)
    value = reshape(value, 1, []);
end
if size(value, 2) ~= numel(defaultRow)
    value = reshape(value, [], numel(defaultRow));
end
if size(value, 1) < nRows
    value(end+1:nRows,:) = repmat(defaultRow, nRows - size(value, 1), 1);
end
end

function value = localEnsureDisplayVector(display, fieldName, nValues, defaultValue)
if isfield(display, fieldName) && ~isempty(display.(fieldName))
    value = display.(fieldName);
    value = value(:).';
else
    value = zeros(1, 0);
end
if numel(value) < nValues
    value(end+1:nValues) = defaultValue;
end
end

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

function v = localNumericParam(param, fieldName, defaultValue)
v = defaultValue;
if ~isstruct(param) || ~isfield(param, fieldName) || isempty(param.(fieldName))
    return;
end

raw = param.(fieldName);
if iscell(raw)
    raw = raw{end};
end
if isstring(raw) || ischar(raw)
    parsed = str2double(char(raw));
    if ~isnan(parsed)
        v = parsed;
    end
elseif isnumeric(raw) && isscalar(raw)
    v = double(raw);
elseif islogical(raw) && isscalar(raw)
    v = double(raw);
end
end
