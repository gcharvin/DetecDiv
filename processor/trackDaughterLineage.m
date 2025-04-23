function [paramout,dataout,imageout] = trackDaughterLineage(param,roiobj,frames)
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
    paramout.outputChannelName = 'TrackedDaughters_cell';
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

dataout = roiobj.data;
imageout = roiobj.image;

% --- Récupération des labels et du masque séquentiel
% Labels (categorical→string)
pix = find(matches({roiobj.data.groupid}, param.data{end}));
if isempty(pix), error('Classifier introuvable'); end
labelsCat = roiobj.data(pix).getData('labels');  % categorical 1×T
labels = string(labelsCat);                     % string 1×T

% Masque de tracks H×W×1×T
chanID = roiobj.findChannelID(param.listChannelName{end});
if isempty(chanID), error('Canal mask introuvable'); end
maskSeq = roiobj.image(:,:,chanID,:);  % H×W×1×T
[H,W,~,T] = size(maskSeq);

% --- 1) Orientation cavité (haut vs bas) par flux moyen en y
dyList = [];
for t = 1:T-1
    frm0 = maskSeq(:,:,1,t);
    frm1 = maskSeq(:,:,1,t+1);
    ids = unique(frm0); ids(ids==0)=[];
    for id = ids'
        [ys0, ~] = find(frm0 == id);
            y0 = mean(ys0);
        if ismember(id, unique(frm1))
            [ys1, ~] = find(frm1 == id);
            y1 = mean(ys1);
            dyList(end+1) = y1 - y0; %#ok<AGROW>
        end
    end
end
% Calcul du signe : +1 si flux monté (y croissant), -1 si flux descendu (y décroissant)
if isempty(dyList)
    bottomSign = 1;  % défaut vers y croissant
else
    bottomSign = sign(mean(dyList));
    % s'il est nul, on force +1
    if bottomSign == 0
        bottomSign = 1;
    end
end
bottomSign=-bottomSign;

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

% État initial selon premier label non-empty
firstIdx = find(labels ~= "empty", 1);
if ~isempty(firstIdx)
    state = labels(firstIdx);
    frm = maskSeq(:,:,1,firstIdx);
    ids = unique(frm); ids(ids==0)=[];
    ys = zeros(size(ids));
        for k = 1:numel(ids)
            [ys_k, ~] = find(frm == ids(k));
            ys(k) = mean(ys_k);
        end
    if state == "smallt"
        % tracked = bas, bud = au-dessus
        [~,i] = max(ys * bottomSign);
        trackedCell = ids(i);
        % trouver budCell au-dessus le plus proche
        cy = ys(i);
        ods = ys < cy; candidates = ids(ods);
        if ~isempty(candidates)
            [~,j] = min(abs(ys(ods)-cy)); budCell = candidates(j);
        end
    elseif state == "smallb"
        % attente de large puis assignation
        trackedCell = [];
    else % large
        % tracked = plus bas
        [~,i] = max(ys * bottomSign);
        trackedCell = ids(i);
    end
end

% --- 3) Boucle sur les frames
maskOut = false(H,W,1,T);
for t = 1:T
    t
    state = labels(t)

    frm   = maskSeq(:,:,1,t);
    ids   = unique(frm); ids(ids==0)=[];
    % cas empty: réinitialiser
    if state == "empty"
        trackedCell = [];
        budCell     = [];
        curEvent    = '';
        prevEvent   = '';
        maskOut(:,:,1,t) = false(H,W);
        continue;
    end
    % transition large->small?
    if t>1 && labels(t-1)=="large" && ismember(state,["smallb","smallt"])
        prevEvent = curEvent;
        curEvent  = state;
        lastTransFrame = t;
        if strcmp(prevEvent,'smallt')
            % cas smallt précédant: supprime ancien bourgeon
            budCell = [];
            'remove t'
        elseif strcmp(prevEvent,'smallb')
            % cas smallb précédant: switch trackedCell
           % if ~isempty(budCell)
            %    trackedCell = budCell;
          %  end
          'ok remove'
            budCell = [];
         %   pause
        end
    end
    % si pas de trackedCell en périoed smallb->large, init
        % si pas de trackedCell en période smallb->large, init à la cellule la plus basse
    if isempty(trackedCell) && state=="large"
        % calcul explicite des centroïdes en y
        ys_temp = zeros(size(ids));
        for k_id = 1:numel(ids)
            [ys_k, ~] = find(frm == ids(k_id));
            ys_temp(k_id) = mean(ys_k);
        end
        [~, idx_min] = max(ys_temp * bottomSign);
        trackedCell = ids(idx_min);
    end
    % assigner budCell si vide et voisinage
    if isempty(budCell) && ~isempty(trackedCell) && ~isempty(curEvent)
        % orientation pour bud selon curEvent (sinon both)
        if strcmp(curEvent,'smallt'), side='top';
        elseif strcmp(curEvent,'smallb'), side='bottom';
        else side='both';
        end
        [ys_tr, ~] = find(frm == trackedCell);
        cy = mean(ys_tr);
        cand = [];
        for id = ids'
             % ne considérer que les IDs apparus après la dernière transition
            if firstAppearance(id) <= lastTransFrame
                continue;
            end
            if id==trackedCell, continue; end
            [ys_bud, ~] = find(frm == id);
            yb = mean(ys_bud);
            dy = (yb - cy)*bottomSign;
            ok = strcmp(side,'both') || (strcmp(side,'bottom')&&dy>0) || (strcmp(side,'top')&&dy<0);
            if ok
                cand(end+1,:) = [abs(yb-cy), id]; %#ok<AGROW>
            end
        end



        if ~isempty(cand)
            [~,j] = min(cand(:,1)); budCell = cand(j,2);

            if strcmp(curEvent,'smallb')
            % swapping tracked cell and budcell
            swap=trackedCell;
            trackedCell=budCell;
            budCell=swap;
            end
        end

   
    end
    % construire masque mère+bud
         if t>110
    %    pause;
         end

    m = false(H,W);
    if ~isempty(trackedCell), m = m | (frm==trackedCell); end
    if ~isempty(budCell),     m = m | (frm==budCell); end
    maskOut(:,:,1,t) = m;
end

% --- 4) Sauvegarde dans roiobj
outChan = paramout.outputChannelName;
pix = roiobj.findChannelID(outChan);
if ~isempty(pix)
    roiobj.image(:,:,pix,:) = maskOut;
else
    roiobj.addChannel(maskOut, outChan, [1 1 1], [0 0 0]);
end

dataout = roiobj.data;
imageout = roiobj.image;
end
