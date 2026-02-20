function [paramout,dataout,imageout] = trackMotherLineage(param,roiobj,frames)
%TRACKDAUGHTERLINEAGE Suivi mère–bourgeon selon spécification
% Inputs:
%   param   - struct avec champs .data (classifier), .listChannelName, .outputChannelName
%   roiobj  - objet ROI contenant .image (H×W×C×T) et .data
%   frames  - non utilisé
% Outputs:
%   paramout - renvoie param
%   dataout  - dataseries mise à jour
%   imageout - image avec canal de sortie

% --- GUI configuration
if nargin == 0
    % Liste des classifiers existants
    ds = listROIDataID('classification');
    paramout.data = ['N/A', ds, ds{end}];
    % Liste des canaux d'instance
    ch = listAvailableChannels;
    paramout.listChannelName = ['N/A', ch, ch{end}];
    paramout.outputChannelName = 'TrackedDaughters';
    paramout.tip = {...
        'Sélectionnez le dataseries classification',...
        'Sélectionnez le canal de masques de track IDs',...
        'Nom du canal en sortie pour mère+bourgeon'};
    dataout = [];
    imageout = [];
    return;
else
    paramout = param;
end

if numel(roiobj.image)==0
    roiobj.load();
end

dataout = roiobj.data;
imageout = roiobj.image;



% --- Récupération des labels et du masque séquentiel
% Labels (categorical→string)
pix = find(matches({roiobj.data.groupid}, param.data{end}));
if isempty(pix)

    disp('Classifier introuvable.... Skipping!');
    return;
 end


labelsCat = roiobj.data(pix).getData('labels');  % categorical 1×T
labels = string(labelsCat);                     % string 1×T

% Masque de tracks H×W×1×T
chanID = roiobj.findChannelID(param.listChannelName{end});

if isempty(chanID)
    
    disp('Canal mask introuvable; Skipping...'); 
    return;


end
maskSeq = roiobj.image(:,:,chanID,:);  % H×W×1×T
[H,W,~,T] = size(maskSeq);

%% Préallocation masques
cellMask = false(H,W,1,T);
budMask  = false(H,W,1,T);
allMask  = false(H,W,1,T);

swapflag=false;
swapv=false(T);


% --- 2) Initialisation trackedCell, budCell, events
trackedCell = [];
budCell     = [];
curEvent    = '';
prevEvent   = '';

% Enregistrer première frame d'apparition pour chaque ID
allIDs = unique(maskSeq(:)); allIDs(allIDs==0) = [];
firstAppearance = containers.Map('KeyType','double','ValueType','double');
for id = allIDs'
    framesWithID = find(squeeze(any(any(maskSeq(:,:,1,:)==id,1),2)));
    if ~isempty(framesWithID)
        firstAppearance(id) = framesWithID(1);
    else
        firstAppearance(id) = inf;
    end
end
% Frame du dernier transition large->small
lastTransFrame = 0;


% 1) première frame non-empty
firstIdx = find(labels ~= "empty" & labels ~= "dead", 1);
if isempty(firstIdx)
    disp('Aucune frame non-empty; Quitting...');
    return;
end

% 2) extraire masque et IDs
frm = maskSeq(:,:,1, firstIdx);
ids = unique(frm);
ids(ids==0) = [];

% 2b) robustesse : au moins une cellule ?
if isempty(ids)
    disp('Aucune cellule détectée sur la première frame non-empty');
    return;
end

% 3) centroïdes
stats     = regionprops(frm, 'Centroid');
centroids = cat(1, stats.Centroid);   % Nx2 [x, y]

% 4) centre de l’image
[H, W] = size(frm);
center = [W/2, H/2];

% % 4b) robustesse : on s’assure d’avoir bien un index
% if isempty(idxTracked)
%     error('Impossible de déterminer la cellule centrale');
% end

% 5) trackedCell = cellule la plus proche du centre
d2center = sqrt((centroids(:,1)-center(1)).^2 + (centroids(:,2)-center(2)).^2);
[~, idxTracked] = min(d2center);
trackedCell = ids(idxTracked);

% 6) récupérer l’état en char
state = labels(firstIdx);
if isstring(state)
    state = char(state);
end

% 7) si état 'small', chercher la cellule la plus proche de trackedCell
if strcmp(state, 'small')
    % indices de toutes les autres cellules
    otherIdx = setdiff(1:numel(ids), idxTracked);
    
    if isempty(otherIdx)
        warning('Aucune autre cellule présente : budCell reste vide');
    else
        tc = centroids(idxTracked, :);
        d2tracked = sqrt((centroids(otherIdx,1)-tc(1)).^2 + ...
                         (centroids(otherIdx,2)-tc(2)).^2);
        [~, k] = min(d2tracked);
        budCell = ids(otherIdx(k));
    end
end


% --- 3) Boucle sur les frames
maskOut = false(H,W,1,T);

prevBudCell=zeros(1,T) ; % records the cell previously defined as bud cell 
prevBudSize=zeros(1,T); % records the size of the bud

for t = firstIdx:T
    %  t
    state = labels(t);

    frm   = maskSeq(:,:,1,t);
    ids   = unique(frm); ids(ids==0)=[];
    % cas empty: réinitialiser
    if ismember(state, ["empty","dead"])
        trackedCell = [];
        budCell     = [];
        curEvent    = '';
        prevEvent   = '';
        maskOut(:,:,1,t) = false(H,W);
 
        continue;
    end

    % transition large->small?
    if t>1 && labels(t-1)=="large" && ismember(state,["small", "unbud"])   % HERE
        prevEvent = curEvent;
     %   curEvent  = state;
        lastTransFrame = t;

            prevBudCell=budCell;
            budCell = [];
     
    end

 

    % assigner budCell si vide et voisinage
    if isempty(budCell) && ~isempty(trackedCell) && state == "large"
   

        % 2) calculer CENTROÏDES de toutes les cellules
stats     = regionprops(frm, 'Centroid');  
centroids = cat(1, stats.Centroid);   % Nx2 [x, y], lignes triées comme 'ids'

% 3) extraire le centroïde de trackedCell
tc = centroids(idxTracked, :);    % [x_tr, y_tr]

% 4) pour chaque id candidat, mesurer la distance 2D, tout en appliquant le filtre 'side'
cands = [];  % tableaux [distance, id]
for k = 1:numel(ids)
    id = ids(k);
    % 4a) on ne regarde que les cellules apparues après lastTransFrame

    %if firstAppearance(id) <= lastTransFrame % cell existed before the transition

% check

   % end


    % 4b) on exclut la trackedCell elle-même
    if id == trackedCell
        continue;
    end
    
    % 4c) appliquer le filtre vertical
    yk = centroids(k,2);
    
    % 4d) calculer la distance euclidienne 2D
    xk = centroids(k,1);
    d  = hypot(xk - tc(1), yk - tc(2));
    
    % 4e) stocker [distance, id]
    cands(end+1, :) = [d, id];  %#ok<AGROW>
end

% --- 5) Choix de budCell basée sur apparition la plus tardive
validIDs    = [];
appearTimes = [];
%maskOther   = (frm>0 & frm~=trackedCell);

for k = 1:size(cands,1)
    id = cands(k,2);
    % a) doit être apparue après la transition
 %   if firstAppearance(id) <= lastTransFrame
 %       continue;
 %   end

    % b) récupérer les centroïdes
    tc   = centroids(idxTracked, :);       % [x, y] de trackedCell
    idxC = find(ids==id,1);
    ck   = centroids(idxC, :);             % [x, y] du candidat

    % c) tracer la ligne en échantillons
    nPts = max(abs(round(tc)-round(ck))) + 1;
    xv   = round(linspace(tc(1), ck(1), nPts));
    yv   = round(linspace(tc(2), ck(2), nPts));

    % d) recadrage pour rester dans l'image
    xv = min(max(xv, 1), W);
    yv = min(max(yv, 1), H);

    maskOther = (frm>0) & (frm~=trackedCell) & (frm~=id);

    % e) test d'absence d'obstacle
    idxLine = sub2ind([H, W], yv, xv);

   % aa=maskOther(idxLine)

    if all(~maskOther(idxLine))
        validIDs(end+1)     = id;                  %#ok<AGROW>
        appearTimes(end+1) = firstAppearance(id); %#ok<AGROW>
    end
end

% f) sélectionner la cellule la plus tardive
if isempty(validIDs)
    budCell = [];
else
    [~, idxMax] = max(appearTimes);
    budCell      = validIDs(idxMax);
end


    end

% prevBudSize(t)=sum(find(frm==budCell));
% prevBudCell(t)=budCell;
    % Stockage masques

    if ~isempty(trackedCell)
        cellMask(:,:,1,t) = (frm == trackedCell);
    end
    if ~isempty(budCell)
        budMask(:,:,1,t) = (frm == budCell);
    end
    allMask(:,:,1,t) = cellMask(:,:,1,t) | budMask(:,:,1,t);
end

%% Sauvegarde des canaux
baseName = paramout.outputChannelName;
channels = {'_cell','_bud','_all'};
masks = {cellMask, budMask, allMask};

for i = 1:length(channels)
    name = [baseName, channels{i}];
    pix = roiobj.findChannelID(name);
    if ~isempty(pix)
        roiobj.image(:,:,pix,:) = masks{i};
    else
        roiobj.addChannel(masks{i}, name, [1 1 1], [0 0 0]);
    end

    dataout = roiobj.data;
    imageout = roiobj.image;
end
