function extractROICrops(shallowObj, args)
% extractROICrops - extrait les crops pour des ROIs (statiques ou trackées)
% et met à jour roi.image sans toucher inutilement à roi.display.
%
% INPUT:
%   shallowObj : objet shallow (projet courant)
%   args.fovList           : vecteur d'indices FOV à traiter
%   args.roiListPerFOV     : cell array {f} -> indices de ROI à extraire pour cette FOV
%                            ou [] pour "toutes les ROI de cette FOV"
%   args.framesPerFOV      : cell array {f} -> frames à extraire
%                            ou [] pour "toutes les frames"
%   args.channelsPerFOV    : cell array {f} -> canaux à extraire (indices de fov.channel)
%                            ou [] pour "tous les canaux"
%   args.scale             : facteur de resize spatial (1 = identique)
%   args.applyDrift        : bool (pas encore implémenté, hook)
%
% Effet de bord:
%   - met à jour shallowObj.fov(f).roi(r).image (+ éventuellement display/frame)
%   - sauvegarde chaque ROI (roi.save) puis nettoie mémoire (roi.clear)
%
% Notes:
%   - Les ROIs trackées (issues de createTrackedCellROIs) possèdent une
%     dataseries 'cell_presence' qui stocke boundingBoxesGlobal / Offsets etc.
%     On s'en sert pour recadrer frame par frame et ajouter le canal masque.
%
%   - Si la ROI n'a pas encore de display.intensity,
%     on tente de récupérer un displayTemplate stocké dans la dataseries
%     'cell_presence' du parent lors de la création.
%
%   - Si la ROI a déjà une image existante sur disque (on la recharge),
%     on essaye d'agrandir/compléter plutôt que tout recréer.
%
%   - On ne fait PAS de découpe en "cut" ici. On lit tous les frames d'un coup
%     pour la FOV, ce qui est plus simple. (Optimisation mémoire possible plus tard).
%

%% ----------- sécurisation args / valeurs par défaut -----------
if ~isfield(args, 'fovList')           || isempty(args.fovList)
    args.fovList = 1:numel(shallowObj.fov);
end
if ~isfield(args, 'roiListPerFOV')     ; args.roiListPerFOV = []; end
if ~isfield(args, 'framesPerFOV')      ; args.framesPerFOV = []; end
if ~isfield(args, 'channelsPerFOV')    ; args.channelsPerFOV = []; end
if ~isfield(args, 'scale')             || isempty(args.scale)
    args.scale = 1;
end
if ~isfield(args, 'applyDrift')        || isempty(args.applyDrift)
    args.applyDrift = false;
end

fprintf('[extractROICrops] start. scale=%.3f drift=%d\n', args.scale, args.applyDrift);

%% ----------- boucle principale sur les FOV demandées -----------
for idxF = 1:numel(args.fovList)
    fovId = args.fovList(idxF);

    if fovId < 1 || fovId > numel(shallowObj.fov)
        fprintf('[extractROICrops] WARNING: skip invalid FOV index %d\n', fovId);
        continue;
    end

    fovObj = shallowObj.fov(fovId);
    fprintf('[extractROICrops] FOV %s (index %d)\n', fovObj.id, fovId);

    % --- frames à traiter pour cette FOV
    if isempty(args.framesPerFOV)
        % pas fourni du tout -> tout
        frameList = 1:numel(fovObj.srclist{1});
    else
        % fourni globalement sous forme de cell ? ou direct vecteur ?
        if iscell(args.framesPerFOV)
            if idxF <= numel(args.framesPerFOV) && ~isempty(args.framesPerFOV{idxF})
                frameList = args.framesPerFOV{idxF};
            else
                frameList = 1:numel(fovObj.srclist{1});
            end
        else
            frameList = args.framesPerFOV;
        end
    end
    frameList = unique(frameList(:)');

    % --- canaux à traiter pour cette FOV
    if isempty(args.channelsPerFOV)
        chanList = 1:numel(fovObj.channel);
    else
        if iscell(args.channelsPerFOV)
            if idxF <= numel(args.channelsPerFOV) && ~isempty(args.channelsPerFOV{idxF})
                chanList = args.channelsPerFOV{idxF};
            else
                chanList = 1:numel(fovObj.channel);
            end
        else
            chanList = args.channelsPerFOV;
        end
    end
    chanList = unique(chanList(:)');

    % --- ROIs à traiter pour cette FOV
    if isempty(args.roiListPerFOV)
        roiIdxList = 1:numel(fovObj.roi);
    else
        if iscell(args.roiListPerFOV)
            if idxF <= numel(args.roiListPerFOV) && ~isempty(args.roiListPerFOV{idxF})
                roiIdxList = args.roiListPerFOV{idxF};
            else
                roiIdxList = 1:numel(fovObj.roi);
            end
        else
            roiIdxList = args.roiListPerFOV;
        end
    end
    roiIdxList = unique(roiIdxList(:)');

    if isempty(roiIdxList)
        fprintf('[extractROICrops]   no ROI for FOV %s -> skip\n', fovObj.id);
        continue;
    end

    % ----------- 1. Lire toutes les images demandées pour cette FOV ----------
    fprintf('[extractROICrops]   loading raw frames for FOV %s ...\n', fovObj.id);

    % On lit une pile 4D brute : scene(y,x,c,t)
    % c = concat des canaux demandés (si certains canaux sont multichan/ RGB -> on empile)
    %
    % On doit aussi mémoriser la correspondance "quel(s) sous-canal appartiennent à tel canal logique"
    %
    scene = [];
    perChannelDepth = zeros(1, numel(chanList)); % nb plans par canal logique
    totalC = 0;

    % On lit d'abord le tout premier frame pour dimensionner
    firstFrame = frameList(1);
    firstIm = fovObj.readImage(firstFrame, chanList(1));
    firstIm = ensureGrayscale(firstIm); % helper plus bas

    baseH = size(firstIm,1);
    baseW = size(firstIm,2);

    % calculer profondeur totale
    for ic = 1:numel(chanList)
        testIm = fovObj.readImage(firstFrame, chanList(ic));
        testIm = ensureGrayscale(testIm);
        perChannelDepth(ic) = size(testIm,3);
        totalC = totalC + perChannelDepth(ic);
    end

    % allouer scene
    scene = zeros(baseH, baseW, totalC, numel(frameList), 'uint16');

    % remplir
    for it = 1:numel(frameList)
        fr = frameList(it);
        cOffset = 1;
        for ic = 1:numel(chanList)
            rawIm = fovObj.readImage(fr, chanList(ic));
            rawIm = ensureGrayscale(rawIm); % retourne [H W depth] uint16
            depth = size(rawIm,3);

            % TODO : binning / rescale par fovObj.display.binning si tu l'utilises encore
            % pour l’instant on assume même binning entre canaux.

            scene(:,:,cOffset:cOffset+depth-1,it) = rawIm;
            cOffset = cOffset + depth;
        end
    end

    % Drift ?
    if args.applyDrift
        % hook : si tu as déjà fovObj.computeDrift, tu peux l'appeler ici et appliquer
        % un shift sur scene(:,:,:,t)
        % Pour l'instant on ne fait rien.
        fprintf('[extractROICrops]   drift correction NOT IMPLEMENTED yet.\n');
    end

    % ----------- 2. Pour chaque ROI demandée -----------
    for rr = roiIdxList
        if rr < 1 || rr > numel(fovObj.roi); continue; end

        thisROI = fovObj.roi(rr);

        % Charger l'ROI existante du disque (pour récupérer .image et .display si elle existe déjà)
        try
            thisROI.load;
        catch
            % si planté, tant pis, on continue avec l'objet en RAM
        end

        fprintf('[extractROICrops]   ROI %s (idx %d)\n', thisROI.id, rr);

        % 2.a. Récupérer les infos de tracking / bbox dynamiques si c'est une ROI "cellule"
        trk = getTrackingInfo(thisROI);

        % Si pas de tracking => bbox fixe
        if ~trk.hasTracking
            roiBoxesGlobal = repmat(double(thisROI.value(:)'), numel(frameList), 1); % [x y w h] constant
            maskChannelActive = false;
        else
            % ROI suivie : on veut la boîte union globale (boundingBoxUnionGlobal)
            % + éventuellement par-frame
            roiBoxesGlobal = boxesForFrames(trk, frameList);
            maskChannelActive = ~isempty(trk.labelMaskUnion);
        end

        % 2.b. Construire / mettre à jour le cube roi.image
        % Déterminer dimensions finales du crop commun
        [targetH, targetW] = computeUnionSize(roiBoxesGlobal);

        % nb canaux dans l'output ROI :
        roiChanCount = totalC + double(maskChannelActive);

        % nombre de frames à stocker pour CETTE ROI
        % - si tracking: longueur réelle de présence (trk.frameCount)
        % - sinon: numel(frameList)
        if trk.hasTracking && trk.frameCount > 0
            Tlocal = trk.frameCount;
        else
            Tlocal = numel(frameList);
        end
        if Tlocal < 1
            Tlocal = numel(frameList);
        end

        % si roi.image existe déjà et a les bonnes dims XY/C, on va la réutiliser.
        needInit = true;
        if ~isempty(thisROI.image)
            sz = size(thisROI.image);
            while numel(sz)<4, sz(end+1)=1; end
            if sz(1)==targetH && sz(2)==targetW && sz(3)==roiChanCount
                % ok dimensions spatiales + canaux
                % si Tlocal > sz(4) on agrandira à la volée
                needInit = false;
            end
        end

        % si on doit init, on crée une nouvelle pile et on prépare display
        if needInit
            thisROI.image = zeros(targetH, targetW, roiChanCount, Tlocal,'uint16');

            % hériter du display du parent si besoin
            if ~hasValidDisplay(thisROI)
                % essayer de récupérer un template stocké lors de la création
                if ~isempty(trk.displayTemplate)
                    thisROI.display = trk.displayTemplate;
                end
            end

            % s'assurer qu'on a un frame affichable
            if ~isfield(thisROI.display,'frame') || isempty(thisROI.display.frame)
                thisROI.display.frame = frameList(1);
            end

            % si on n'a toujours pas de channelid cohérent, essayer d'en récupérer
            if (~isprop(thisROI,'channelid') || isempty(thisROI.channelid)) && ~isempty(trk.channelTemplate)
                thisROI.channelid = trk.channelTemplate;
            end
        else
            % déjà existante : ne pas toucher thisROI.display (c'est TA règle)
            if size(thisROI.image,4) < Tlocal
                % on étend dans le temps si besoin
                tmpOld = thisROI.image;
                thisROI.image = zeros(targetH, targetW, roiChanCount, Tlocal,'uint16');
                thisROI.image(:,:,:,1:size(tmpOld,4)) = tmpOld;
            end
        end

        % 2.c. Remplir chaque frame
        for idxFrame = 1:numel(frameList)
            fr = frameList(idxFrame);

            % calcul index temporel dans le cube ROI:
            % - ROI tracking: il faut mapper "frame absolue fr" -> index local
            tgtT = mapFrameToLocalIndex(trk, fr, idxFrame);

            if isempty(tgtT) || tgtT<1 || tgtT>size(thisROI.image,4)
                % frame pas présente pour cette ROI (ex: la cellule n'existe pas encore)
                continue;
            end

            % bbox globale de cette frame
            box = roiBoxesGlobal(idxFrame, :); % [x y w h] dans coords FOV
            if any(~isfinite(box)) || box(3)<=0 || box(4)<=0
                continue;
            end

            % crop intensité depuis scene
            patchInt = cropFromScene(scene, box);

            % redimensionner si scale != 1
            if args.scale ~= 1
                patchInt = imresize(patchInt, args.scale);
            end

            % ajuster à [targetH,targetW]
            patchInt = forceSize(patchInt, [targetH targetW]);

            % si canal masque actif, construire le masque pour cette frame
            if maskChannelActive
                patchMask = buildMaskForFrame(trk, fr, box, [targetH targetW], args.scale);
                % fusionner intensité + masque dans un cube final
                finalFrame = zeros(targetH, targetW, roiChanCount, 'uint16');
                finalFrame(:,:,1:totalC) = uint16(patchInt);
                finalFrame(:,:,roiChanCount) = uint16(patchMask);
            else
                finalFrame = uint16(patchInt); % already HxWxC
            end

            thisROI.image(:,:,:,tgtT) = finalFrame;
        end

        % 2.d. Sauvegarder ROI
        % mettre à jour .path si besoin
        if isempty(thisROI.path)
            basePath = fullfile(shallowObj.io.path, shallowObj.io.file, fovObj.id);
            thisROI.path = basePath;
        end

        % définir frame courant pour l'affichage (par défaut premier frameList)
        if trk.hasTracking && ~isempty(trk.frameIndices)
            thisROI.display.frame = trk.frameIndices(1);
        else
            thisROI.display.frame = frameList(1);
        end

        % save & clear
        thisROI.save;
        thisROI.clear;

        % refléter dans l'objet fov du projet
        fovObj.roi(rr) = thisROI;
    end

    % écrire le fov modifié dans le shallowObj
    shallowObj.fov(fovId) = fovObj;
end

fprintf('[extractROICrops] done.\n');

end % ====== fin main function ======


%% =======================================================================
function img = ensureGrayscale(im)
    % force une image en uint16 [H W depth]
    % accepte:
    %   - 2D grayscale
    %   - RGB (H W 3)
    %   - déjà stack multi-z
    if ndims(im)==2
        img = im;
    elseif ndims(im)==3 && size(im,3)==3
        img = rgb2gray(im); % MATLAB raccourci -> uint8 normalement, tu peux adapter
        if ~isa(img,'uint16')
            img = im2uint16(img);
        end
        img = reshape(img, size(img,1), size(img,2), 1);
    else
        % on assume que c'est déjà [H W depth]
        img = im;
        if ~isa(img,'uint16')
            img = im2uint16(img);
        end
    end
end


function trk = getTrackingInfo(roiObj)
    % extrait les infos de tracking à partir du dataseries 'cell_presence'
    % S'il n'y en a pas, renvoie hasTracking=false
    trk = struct('hasTracking',false,...
                 'unionBox',[],...
                 'frameBoxes',[],...
                 'presence',[],...
                 'frameIndices',[],...
                 'frameCount',0,...
                 'labelMaskUnion',[],...
                 'labelMaskFrames',[],...
                 'displayTemplate',[],...
                 'channelTemplate',[]);

    % charger les dataseries si pas là
    if isempty(roiObj.data) || (numel(roiObj.data)==1 && isempty(roiObj.data(1).data))
        try
            roiObj.load('data');
        catch
        end
    end
    if isempty(roiObj.data); return; end

    idx = find(arrayfun(@(d) isprop(d,'groupid') && strcmp(d.groupid,'cell_presence'), roiObj.data),1,'first');
    if isempty(idx); return; end

    ds = roiObj.data(idx);
    if ~isstruct(ds.userData); return; end

    needed = {'boundingBoxUnionGlobal','boundingBoxesGlobal','boundingBoxOffsets'};
    for k=1:numel(needed)
        if ~isfield(ds.userData,needed{k})
            return;
        end
    end

    trk.hasTracking = true;

    trk.unionBox        = double(ds.userData.boundingBoxUnionGlobal);   % [x y w h] globale
    trk.frameBoxes      = double(ds.userData.boundingBoxesGlobal);      % N x 4
    trk.presence        = all(isfinite(trk.frameBoxes),2) & trk.frameBoxes(:,3)>0 & trk.frameBoxes(:,4)>0;

    if isfield(ds.userData,'frames') && ~isempty(ds.userData.frames)
        trk.frameIndices = double(ds.userData.frames(:)');
    else
        trk.frameIndices = find(trk.presence)';
    end
    trk.frameCount = numel(trk.frameIndices);

    if isfield(ds.userData,'labelMaskUnion')
        trk.labelMaskUnion = ds.userData.labelMaskUnion; % HxWxTmask
    else
        trk.labelMaskUnion = [];
    end
    if isfield(ds.userData,'labelMaskFrames')
        trk.labelMaskFrames = double(ds.userData.labelMaskFrames(:)');
    else
        trk.labelMaskFrames = trk.frameIndices;
    end

    % héritage displayTemplate / channelTemplate
    if isfield(ds.userData,'displayTemplate')
        trk.displayTemplate = ds.userData.displayTemplate;
    end
    if isfield(ds.userData,'channelTemplate')
        trk.channelTemplate = ds.userData.channelTemplate;
    end
end


function boxes = boxesForFrames(trk, frameList)
    % renvoie pour chaque frame demandée la bbox globale (unionBox)
    % si tracking -> on veut recadrer autour de la box union (trk.unionBox)
    %
    % Ici choix simple : on recadre TOUJOURS sur la boundingBoxUnionGlobal
    % pour avoir une taille fixe. Donc même taille pour toutes frames.
    %
    if ~trk.hasTracking
        error('boxesForFrames called on non-tracked ROI');
    end
    boxes = repmat(trk.unionBox(:)', numel(frameList), 1); % [Nframes x 4]
end


function [H,W] = computeUnionSize(boxes)
    % boxes: [N x 4] [x y w h]
    % on prend le max w,h
    wmax = max(boxes(:,3));
    hmax = max(boxes(:,4));
    H = max(1, round(hmax));
    W = max(1, round(wmax));
end


function tgtT = mapFrameToLocalIndex(trk, absFrame, fallbackIdx)
    % mappe un numéro de frame absolu (absFrame) vers l'indice temporel
    % dans roi.image.
    % Pour une ROI statique -> juste fallbackIdx.
    % Pour une ROI trackée -> trouver la position dans trk.frameIndices.
    if ~trk.hasTracking
        tgtT = fallbackIdx;
        return;
    end
    pos = find(trk.frameIndices==absFrame,1,'first');
    if isempty(pos)
        tgtT = [];
    else
        tgtT = pos;
    end
end


function patchInt = cropFromScene(scene, box)
    % scene: [H0 W0 C T]
    % box: [x y w h] en coords de la FOV (1-based)
    x1 = floor(box(1));
    y1 = floor(box(2));
    w  = floor(box(3));
    h  = floor(box(4));

    x1 = max(1,x1);
    y1 = max(1,y1);
    x2 = min(size(scene,2), x1+w-1);
    y2 = min(size(scene,1), y1+h-1);

    % On prend toutes les frames en même temps ? Non:
    % ATTENTION : ici on ne connaît pas t. Donc on va spécialiser:
    % NON, en fait on doit découper pour UN seul frame. Re-ecrivons.
    error('cropFromScene called without time dimension context.');
end



function patchInt = cropFromSingleFrame(sceneFrame, box)
    % sceneFrame: [H0 W0 C]
    x1 = floor(box(1));
    y1 = floor(box(2));
    w  = floor(box(3));
    h  = floor(box(4));

    x1 = max(1,x1);
    y1 = max(1,y1);
    x2 = min(size(sceneFrame,2), x1+w-1);
    y2 = min(size(sceneFrame,1), y1+h-1);

    if x2 < x1 || y2 < y1
        patchInt = zeros(h, w, size(sceneFrame,3), 'like', sceneFrame);
        return;
    end

    patchInt = zeros(h, w, size(sceneFrame,3), 'like', sceneFrame);
    destX1 = 1 + (x1 - floor(box(1)));
    destY1 = 1 + (y1 - floor(box(2)));
    destX2 = destX1 + (x2 - x1);
    destY2 = destY1 + (y2 - y1);

    patchInt(destY1:destY2, destX1:destX2, :) = sceneFrame(y1:y2, x1:x2, :);
end

function outIm = forceSize(im, HW)
    targetH = HW(1); targetW = HW(2);
    if size(im,1)==targetH && size(im,2)==targetW
        outIm = im;
    else
        outIm = imresize(im, [targetH targetW], 'nearest');
    end
end

function tf = hasValidDisplay(r)
    tf = false;
    if isfield(r,'display') && isstruct(r.display) ...
       && isfield(r.display,'intensity') && ~isempty(r.display.intensity)
        tf = true;
    end
end

function patchMask = buildMaskForFrame(trk, absFrame, box, targetHW, scaleFactor)
    Ht = targetHW(1);
    Wt = targetHW(2);
    patchMask = zeros(Ht, Wt, 'uint16');

    if ~trk.hasTracking || isempty(trk.labelMaskUnion)
        return;
    end

    % On cherche dans labelMaskFrames quelle "slice" correspond à absFrame
    idxMask = find(trk.labelMaskFrames == absFrame, 1, 'first');
    if isempty(idxMask)
        % fallback si absFrame pas trouvé : rien
        return;
    end
    if idxMask > size(trk.labelMaskUnion,3)
        return;
    end

    unionMask = trk.labelMaskUnion(:,:,idxMask); % uint16/whatever

    % recadrer la maskUnion dans la même logique que cropFromSingleFrame
    x1 = floor(box(1));
    y1 = floor(box(2));
    w  = floor(box(3));
    h  = floor(box(4));
    x1 = max(1,x1);
    y1 = max(1,y1);
    x2 = x1+w-1;
    y2 = y1+h-1;

    x2 = min(x2, size(unionMask,2));
    y2 = min(y2, size(unionMask,1));
    if x2<x1 || y2<y1
        return;
    end

    % créer un canevas de taille (h,w)
    localMask = zeros(h, w, 'like', unionMask);

    destX1 = 1 + (x1 - floor(box(1)));
    destY1 = 1 + (y1 - floor(box(2)));
    destX2 = destX1 + (x2 - x1);
    destY2 = destY1 + (y2 - y1);

    localMask(destY1:destY2, destX1:destX2) = unionMask(y1:y2, x1:x2);

    % scale si besoin
    if scaleFactor ~= 1
        localMask = imresize(localMask, scaleFactor, 'nearest');
    end

    % forcer [Ht Wt]
    patchMask = forceSize(localMask, [Ht Wt]);
end







