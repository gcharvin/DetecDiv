function [paramout,dataout,imageout] = trackMotherLineageViterbi(param, roiobj, frames)
%TRACKMOTHERLINEAGEVITERBI Suivi Viterbi d'une lignée de cellule mère dans un piège.
%
% SYNOPSIS
%   [paramout, dataout, imageout] = trackMotherLineageViterbi(param, roiobj, frames)
%
% DESCRIPTION
%   Suivi d'une cellule "mère" unique dans un piège microfluidique, en supposant
%   qu'il y a une seule cellule mère dans la cavité et des buds autour.
%   L'observation privilégie la cellule la plus proche du centre (et
%   éventuellement la plus grosse), et le Viterbi impose la continuité
%   temporelle (faible mouvement, faible variation d'aire, pénalité de switch).
%
% INPUTS
%   param   : struct de paramètres (géré par le GUI) contenant au minimum :
%       - param.instanceChannelName : cellstr
%           Liste de noms de canaux possibles pour la segmentation d'instances.
%           Le canal effectivement utilisé est param.instanceChannelName{end}.
%       - param.mode : {'mother_trap', ...}
%           Mode de suivi. Pour l'instant seul 'mother_trap' est supporté.
%       - param.outputChannelName : char
%           Nom du canal de sortie qui contiendra le masque logique de la lignée mère.
%
%   roiobj  : objet ROI, supposé contenir au moins :
%       - roiobj.image : tableau [H x W x C x T]
%           Empilement d'images ou de masques, dont un canal avec les labels d'instance.
%       - roiobj.data  : données associées (non modifiées ici sauf si besoin futur).
%
%   frames  : (optionnel) vecteur d'indices de frames à traiter (1-based).
%             Exemples : [] (toutes les frames), 1:T, 30:35, [10 12 20].
%             Si vide ou non fourni, toutes les frames disponibles sont utilisées.
%
% OUTPUTS
%   paramout : struct param non modifié (placeholder pour compatibilité process)
%   dataout  : roiobj.data (passe-plat, pour compatibilité)
%   imageout : roiobj.image mis à jour avec le canal 'outputChannelName'
%              contenant la lignée mère (masque uint16 logique).
%
% PARAMÈTRES INTERNE / RANGES (à tuner éventuellement)
%   w_center       : poids de la proximité au centre      (recommandé ~1.0)
%   w_area         : poids de l'aire de l'objet           (0 → ignore la taille,
%                                                          0.5–2 → donne du poids à la mère)
%   lambda_jump    : pénalité par pixel de déplacement    (0.01–0.5 typiquement)
%   lambda_area    : pénalité sur variation d'aire        (0.001–0.1 selon quality segmentation)
%   lambda_switch  : pénalité de switch d'ID entre frames (1–10, plus grand = trajectoire plus rigide)
%
% DEBUG
%   La fonction affiche dans la console :
%   - la trajectoire finale frame par frame (label et état),
%   - les SWITCHs entre labels successifs,
%   - les corrections où Viterbi modifie le "best match" greedy local.

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
        'Nom du canal de sortie contenant la lignée mère (mask logique).'};

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

% Ici on suppose qu'il y a toujours au moins une cellule par frame.
if any(N == 0)
    warning('[trackMotherLineageViterbi] Au moins une frame sans cellule détectée (N(f)==0). Viterbi simple sans état null non adapté. Skipping...');
    return;
end

%% ---- Paramètres Viterbi (mono-occupant, "mère au centre") ----
mode = param.mode{end}; %#ok<NASGU>
mode = lower(mode);     %#ok<NASGU>

% Poids observation
w_center = 1.0;  % importance d'être proche du centre
w_area   = 0.0;  % importance de l'aire (0 = ignore la taille)
w_bias   = 1e-6; % petit biais pour éviter log(0)

% Pénalités de transition
lambda_jump   = 0.05;   % pénalité par pixel de déplacement
lambda_area   = 0.01;   % pénalité par variation d'aire
lambda_switch = 1.5;    % pénalité pour changer de candidat (switch d'ID)

% Géométrie du piège
center  = [W/2, H/2];
maxDist = hypot(center(1), center(2));  % distance max pour normalisation

%% ---- Construction des log-scores d'observation logB{f}(k) ----
logB           = cell(nF,1);
bestIdxGreedy  = nan(nF,1);
bestLabelGreedy = nan(nF,1);

for f = 1:nF

    centroids = feats(f).centroid;  % [N x 2]
    areas     = feats(f).area;      % [N x 1]

    % distance au centre
    dx = centroids(:,1) - center(1);
    dy = centroids(:,2) - center(2);
    dist = hypot(dx, dy);          % 0 au centre, maxDist aux coins

    % 1) score de centrage normalisé [0..1]
    centerScore = 1 - dist ./ maxDist;   % 1 = pile au centre, 0 = très loin
    centerScore = max(centerScore, 0);   % clamp au cas où

    % 2) score de taille normalisé [0..1]
    if any(areas)
        areaNorm = areas ./ max(areas);  % 1 = plus grosse cellule de la frame
    else
        areaNorm = zeros(size(areas));
    end

    % 3) combinaison pondérée
    B = w_center * centerScore + w_area * areaNorm + w_bias;

    % Greedy best match (pour debug)
    [~, bestIdx] = max(B);
    bestIdxGreedy(f)   = bestIdx;
    bestLabelGreedy(f) = feats(f).label(bestIdx);

    % log-observation
    logB{f} = log(B);
end

%% ---- Fonction de coût de transition entre états réels ----
    function val = transLogReal(iState, jState, fidx)
        % iState in 1..N(fidx), jState in 1..N(fidx+1)
        ci = feats(fidx).centroid(iState,:);  % [x,y]
        cj = feats(fidx+1).centroid(jState,:);
        ai = feats(fidx).area(iState);
        aj = feats(fidx+1).area(jState);

        % distance en pixels
        dist_ij = hypot(ci(1)-cj(1), ci(2)-cj(2));

        % coût de base : on pénalise les grands déplacements et changements brusques d'aire
        base = -lambda_jump * dist_ij - lambda_area * abs(ai - aj);

        % pénalité de switch : si on change de candidat entre fidx et fidx+1
        if iState ~= jState
            base = base - lambda_switch;
        end

        val = base;
    end

%% ---- Viterbi dynamique (sans état null) ----
delta = cell(nF,1);  % delta{f}(j) = meilleur log-score en arrivant à l'état j à f
psi   = cell(nF,1);  % psi{f}(j)   = index de l'état précédent qui donne ce max

% Initialisation f=1
delta{1} = logB{1};              % [1 x N(1)]
psi{1}   = zeros(1, N(1));       % 0 = pas de précédent

% DP
for f = 2:nF
    Kprev = N(f-1);
    Kcurr = N(f);

    d  = -Inf(1, Kcurr);
    bp = zeros(1, Kcurr);

    for j = 1:Kcurr
        best = -Inf;
        arg  = 0;
        for i = 1:Kprev
            sc = delta{f-1}(i) + transLogReal(i,j,f-1);
            if sc > best
                best = sc;
                arg  = i;
            end
        end
        d(j)  = best + logB{f}(j);
        bp(j) = arg;
    end

    delta{f} = d;
    psi{f}   = bp;
end

% Backtracking
main_id = nan(nF,1);  % index candidat (par frame)
[~, k] = max(delta{nF});   % état final optimal à la dernière frame
main_id(nF) = k;

for f = nF:-1:2
    kPrev = psi{f}(k);
    main_id(f-1) = kPrev;
    k = kPrev;
end

%% ---- Readout de tracking frame par frame (debug) ----
fprintf('[trackMotherLineageViterbi] Viterbi path sur %d frames:\n', nF);
for f = 1:nF
    idx  = main_id(f);
    lab  = feats(f).label(idx);
    tReal = frameIdx(f);

    if f == 1
        fprintf('  Frame %3d: START label=%d (state=%d)\n', tReal, lab, idx);
    else
        prevIdx = main_id(f-1);
        prevLab = feats(f-1).label(prevIdx);

        if lab ~= prevLab
            fprintf('  Frame %3d: SWITCH label %d (state=%d) -> %d (state=%d)\n', ...
                tReal, prevLab, prevIdx, lab, idx);
        else
            fprintf('  Frame %3d: keep   label %d (state=%d)\n', ...
                tReal, lab, idx);
        end
    end

    % Comparaison greedy vs Viterbi
    gIdx  = bestIdxGreedy(f);
    gLab  = bestLabelGreedy(f);
    if gIdx ~= idx
        fprintf('              (Viterbi override) greedy state=%d (label=%d) -> state=%d (label=%d)\n', ...
            gIdx, gLab, idx, lab);
    end
end

%% ---- Construction du masque de lignée mère ----
motherMask = uint16(zeros(H,W,1,nF));

for f = 1:nF
    idx   = main_id(f);
    lab   = feats(f).label(idx);
    tReal = frameIdx(f);

    frm = maskSeq(:,:,1,tReal);      % labels de la frame réelle
    motherMask(:,:,1,f) = uint16(frm == lab);
end

%% ---- Sauvegarde dans roiobj.image ----
outName = paramout.outputChannelName;
pix = roiobj.findChannelID(outName);

if ~isempty(pix)
    disp('[trackMotherLineageViterbi] Masks exist already, overwriting selected frames.');
    roiobj.image(:,:,pix,frameIdx) = motherMask;
else
    roiobj.addChannel(motherMask, outName, [1 1 1], [0 0 0]); % blanc, fond noir
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
