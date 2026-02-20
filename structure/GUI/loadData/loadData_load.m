function shallowObj = loadData_load(parsedData, hprogressbar)
%% Initialize the progress bar if provided
if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0;
    hprogressbar.Message = 'Initializing...';
    pause(0.5);
    drawnow;
end

%% Vérifier si parsedData.projectPath correspond à un projet déjà chargé dans le workspace
% On recherche dans le workspace de base une variable de type "shallow" dont le chemin complet
% (io.path et io.file) correspond à parsedData.projectPath.
projectLoaded = false;
vars = evalin('base','who');
for k = 1:length(vars)
    candidate = evalin('base', vars{k});
    if isa(candidate, 'shallow')
        % Construire le chemin complet du projet stocké dans l'objet candidate
        candidateProjPath = fullfile(candidate.io.path, [candidate.io.file '.mat']);
        if strcmp(candidateProjPath, parsedData.projectPath)
            shallowObj = candidate;
            projectLoaded = true;
            if exist('hprogressbar','var') && ~isempty(hprogressbar)
                hprogressbar.Message = 'Using existing shallow project...';
                pause(0.5);
                drawnow;
            end
            break;
        end
    end
end

%% Si aucun projet déjà chargé n'a été trouvé, créer un nouvel objet shallow
if ~projectLoaded
    [projFolder, projFilename, ~] = fileparts(parsedData.projectPath);
    shallowObj = shallowNew('path', char(fullfile(projFolder, '/')), ...
        'filename', [char(projFilename) '.mat']);
    if isempty(shallowObj)
        disp('Project creation canceled by the user.');
        return;
    end
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 0.10;
        hprogressbar.Message = 'Shallow project created...';
        drawnow;
    end
else
    % garder projFolder / projFilename cohérents si re-load
    [projFolder, projFilename, ~] = fileparts(parsedData.projectPath);
end

%% save parsedData in the current project
shallowObj.parsedData = parsedData;

%% ------------------------------------------------------------------------
%% Construction de newdata.pos pour shallowObj.addData
%% et préparation du mode "re-extraction" pour les doublons
%% ------------------------------------------------------------------------
newdata.pos = [];
nPos = numel(parsedData.positions);
weight_positions = 0.30;  % portion de progression pour la boucle
newIndex = 0;             % index dans newdata.pos

% reextractList mémorise les FOV déjà existantes pour lesquelles on veut
% relancer l'extraction (plage de frames différente, etc.)
reextractList = struct('fovIndex', {}, 'parsedIndex', {}, 'name', {});

for i = 1:nPos

    % Sécuriser si parsedData.positions a bougé
    if i > numel(parsedData.positions)
        break;
    end

    pos = parsedData.positions(i);

    % ----- Sécurité sur .selected -----
    isSel = true;
    if isfield(pos, 'selected')
        isSel = logical(pos.selected);
    end
    if ~isSel
        % ne pas importer cette position dans le projet
        continue;
    end

    % ----- Détection doublon -----
    duplicate  = false;
    dupFovIdx  = [];
    if isprop(shallowObj, 'fov') && ~isempty(shallowObj.fov)
        for kk = 1:numel(shallowObj.fov)
            fovk = shallowObj.fov(kk);

            if isempty(fovk) || ~isprop(fovk,'srcpath') || isempty(fovk.srcpath)
                continue;
            end

            sameFolder = false;
            if iscell(fovk.srcpath) && ~isempty(fovk.srcpath) && ...
                    isfield(pos,'folder') && ~isempty(pos.folder)
                if ~isempty(fovk.srcpath{1})
                    sameFolder = strcmp(fovk.srcpath{1}, pos.folder);
                end
            end

            if sameFolder
                duplicate = true;
                dupFovIdx = kk;
                disp(['Warning : position duplication ! Will RE-EXTRACT instead of adding: ' num2str(i)]);
                break;
            end
        end
    end

    if duplicate
        % On enregistre pour la phase re-extraction de cette FOV existante
        reextractList(end+1).fovIndex    = dupFovIdx;
        reextractList(end).parsedIndex   = i;
        if isfield(pos,'userName')
            reextractList(end).name = pos.userName;
        else
            reextractList(end).name = sprintf('Pos%d', i-1);
        end

        % On NE crée PAS de nouvelle entrée pour cette position,
        % parce qu'on ne veut pas dupliquer la FOV dans le projet.
        continue;
    end

    % ----- Sinon : créer une nouvelle entrée dans newdata.pos -----
    newIndex = newIndex + 1;

    % Progress bar info
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Message = sprintf('Processing position %d/%d...', i, nPos);
        drawnow;
    end

    % Nombre de canaux
    if isfield(pos, 'channelsDir') && ~isempty(pos.channelsDir)
        nChannels = numel(pos.channelsDir);
    else
        nChannels = 0;
    end

    % Nom FOV
    if isfield(pos,'userName') && ~isempty(pos.userName)
        newdata.pos(newIndex).name = pos.userName;
    else
        newdata.pos(newIndex).name = sprintf('Pos%d', i-1);
    end

    newdata.pos(newIndex).contours  = [];

    % pathlist : répéter pos.folder pour chaque canal
    if isfield(pos,'folder') && ~isempty(pos.folder)
        baseFolder = pos.folder;
    else
        baseFolder = '';
    end
    newdata.pos(newIndex).pathlist  = repmat({baseFolder}, 1, nChannels);

    % filelist : channelsDir direct
    if isfield(pos,'channelsDir') && ~isempty(pos.channelsDir)
        newdata.pos(newIndex).filelist  = pos.channelsDir;
    else
        newdata.pos(newIndex).filelist  = cell(1,nChannels);
    end

    % channelname
    if isfield(pos, 'userChanName') && numel(pos.userChanName) == nChannels
        newdata.pos(newIndex).channelname = pos.userChanName;
    elseif isfield(pos, 'channels') && numel(pos.channels) == nChannels
        newdata.pos(newIndex).channelname = pos.channels;
    else
        tmpNames = cell(1, nChannels);
        for j = 1:nChannels
            tmpNames{j} = sprintf('Channel%d', j-1);
        end
        newdata.pos(newIndex).channelname = tmpNames;
    end

    % frames (nb d'images par canal)
    newdata.pos(newIndex).frames = zeros(1, nChannels);
    for j = 1:nChannels
        if ~isempty(newdata.pos(newIndex).filelist{j})
            newdata.pos(newIndex).frames(j) = numel(newdata.pos(newIndex).filelist{j});
        else
            newdata.pos(newIndex).frames(j) = 0;
        end

        if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
            hprogressbar.Message = sprintf('Position %d/%d, channel %d/%d: computing frames', ...
                i, nPos, j, nChannels);
            drawnow;
        end
    end

    % interval (fréquence par canal)
    if isfield(pos, 'channelFrequencies') && numel(pos.channelFrequencies) >= nChannels
        newdata.pos(newIndex).interval = pos.channelFrequencies(1:nChannels);
    else
        newdata.pos(newIndex).interval = ones(1, nChannels);
    end

    % binning
    newdata.pos(newIndex).binning = zeros(1, nChannels);
    for j = 1:nChannels
        bj = 1;
        if isfield(pos,'channelSizes') && numel(pos.channelSizes) >= j && ~isempty(pos.channelSizes{j})
            % essayer "677 946"
            dims = sscanf(pos.channelSizes{j}, '%d %d');
            if isempty(dims)
                % essayer "677 x 946"
                dims = sscanf(pos.channelSizes{j}, '%d x %d');
            end
            if ~isempty(dims)
                bj = dims(1);
            end
        end
        newdata.pos(newIndex).binning(j) = bj;

        if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
            hprogressbar.Message = sprintf('Position %d/%d, channel %d/%d: computing binning', ...
                i, nPos, j, nChannels);
            drawnow;
        end
    end
    if nChannels > 0 && newdata.pos(newIndex).binning(1) ~= 0
        newdata.pos(newIndex).binning = newdata.pos(newIndex).binning ./ newdata.pos(newIndex).binning(1);
    end

    % ----- multi-TIFF -----
    if isfield(pos,'isMultiTiff') && ~isempty(pos.isMultiTiff) && pos.isMultiTiff
        newdata.pos(newIndex).isMultiTiff = true;

        % On essaye d'abord multiTiffPath, sinon tiffSource, sinon warning
        if isfield(pos,'multiTiffPath') && ~isempty(pos.multiTiffPath)
            thisSourcePath = pos.multiTiffPath;
        elseif isfield(pos,'tiffSource') && ~isempty(pos.tiffSource)
            thisSourcePath = pos.tiffSource;
        else
            thisSourcePath = '';
            fprintf('DEBUG: WARNING pas de multiTiffPath/tiffSource défini pour la position %d (%s)\n', ...
                i, newdata.pos(newIndex).name);
        end

        % tiffSource doit être un cell array 1 x nChannels attendu par addData / fov.readImage
        newdata.pos(newIndex).tiffSource = repmat({thisSourcePath}, 1, nChannels);

        % On garde aussi une trace directe
        newdata.pos(newIndex).multiTiffPath = thisSourcePath;

        % pageMap : index des pages dans l'ordre t1ch1, t1ch2, t2ch1, ...
        newdata.pos(newIndex).pageMap = cell(1, nChannels);
        for cIdx = 1:nChannels
            nF = newdata.pos(newIndex).frames(cIdx);
            newdata.pos(newIndex).pageMap{cIdx} = ((0:nF-1)*nChannels + cIdx);
        end
    else
        newdata.pos(newIndex).isMultiTiff = false;
        newdata.pos(newIndex).tiffSource  = cell(1, nChannels);
        newdata.pos(newIndex).pageMap     = cell(1, nChannels);
    end

    % progress bar update
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        progressValue = 0.10 + weight_positions * (i / nPos);
        hprogressbar.Value = progressValue;
        drawnow;
    end
end

%% Barre de progression
if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.45;
    hprogressbar.Message = 'Adding data to the shallow project...';
    drawnow;
end

%% -------- AVANT l'ajout dans shallowObj --------
oldFovCount = numel(shallowObj.fov);
wasFirstDummyFov = false;
if oldFovCount == 1
    % regarder si c'est la FOV vide initiale
    if isempty(shallowObj.fov(1).srclist) || numel(shallowObj.fov(1).srclist)==0
        wasFirstDummyFov = true;
    end
end

%% -------- AJOUT DES DONNÉES AU PROJET --------
if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.50;
    hprogressbar.Message = 'Adding data to the shallow project...';
    drawnow;
end

fprintf('DEBUG: calling shallowObj.addData(newdata)\n');
shallowObj.addData(newdata);
fprintf('DEBUG: shallowObj.addData(newdata) DONE\n');

if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.55;
    hprogressbar.Message = 'Data added to the project...';
    drawnow;
end

%% -------- APRÈS L'AJOUT : déterminer les nouvelles FOV --------
newFovCount = numel(shallowObj.fov);
deltaFov = newFovCount - oldFovCount;
if deltaFov < 0
    deltaFov = 0;
end

if wasFirstDummyFov
    % Cas spécial : premier import dans un projet vide
    startNewFov = 1;
    endNewFov   = newFovCount;
elseif deltaFov > 0
    % les nouvelles FOV sont les deltaFov dernières
    startNewFov = newFovCount - deltaFov + 1;
    endNewFov   = newFovCount;
else
    % rien de nouveau
    startNewFov = [];
    endNewFov   = [];
end

if isempty(startNewFov) || isempty(endNewFov)
    newFovIdx = [];
else
    newFovIdx = startNewFov:endNewFov;
end

numJustAdded = numel(newFovIdx);

fprintf('DEBUG: oldFovCount=%d, newFovCount=%d, deltaFov=%d, numJustAdded=%d\n', ...
    oldFovCount, newFovCount, deltaFov, numJustAdded);

%% Cas où rien n'a été ajouté ET pas de re-extraction demandée
if numJustAdded == 0 && isempty(reextractList)
    fprintf('DEBUG: aucune nouvelle FOV et aucune FOV à réextraire, on ne relance pas l''extraction.\n');

    shallowSave(shallowObj);

    shallowObj.parsedData = loadData_rebuildParsedDataFromProject(shallowObj);
    shallowSave(shallowObj);

    if ~projectLoaded
        fullpath = fullfile(char(projFolder), [char(projFilename) '.mat']);
        projName = shallowObj.io.file;
        [shallowObj, msg] = shallowLoad(fullpath);
        if ~isempty(msg)
            disp(msg);
        end
        assignin('base', projName, shallowObj);
    end

    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 1.0;
        hprogressbar.Message = '';
        drawnow;
    end

    return;
end

%% =======================================================================
% Étape A : Associer FOV ↔ parsedData, gérer (ré-)création des ROIs
%% =======================================================================
newFovIndicesInProject = [];    % indices FOV dans shallowObj à extraire
newFovIndicesInParsed  = [];    % indices correspondants dans parsedData.positions

% 1) FOV vraiment nouvelles
for kAdded = 1:numJustAdded
    iFovProject = newFovIdx(kAdded);        % index global dans shallowObj.fov
    refName = newdata.pos(kAdded).name;     % 'Pos0', etc.

    % retrouver iParsed via userName
    iParsed = [];
    for p = 1:numel(parsedData.positions)
        if isfield(parsedData.positions(p),'userName') && ~isempty(parsedData.positions(p).userName)
            if strcmp(parsedData.positions(p).userName, refName)
                iParsed = p;
                break;
            end
        end
    end
    if isempty(iParsed)
        iParsed = kAdded;
        fprintf('DEBUG: WARNING pas trouvé par name, fallback iParsed=%d\n', iParsed);
    else
        fprintf('DEBUG: mapping newFOV #%d -> parsedData.positions(%d) via userName ''%s''\n', ...
            kAdded, iParsed, refName);
    end

    newFovIndicesInProject(end+1) = iFovProject; %#ok<AGROW>
    newFovIndicesInParsed(end+1)  = iParsed;     %#ok<AGROW>
end

% 2) FOV en re-extraction (doublons, mais qu'on veut retraiter)
for rr = 1:numel(reextractList)
    iFovProject = reextractList(rr).fovIndex;
    iParsed     = reextractList(rr).parsedIndex;
    fprintf('DEBUG: re-extraction FOV %d (parsedData.positions(%d) "%s")\n', ...
        iFovProject, iParsed, reextractList(rr).name);

    newFovIndicesInProject(end+1) = iFovProject;
    newFovIndicesInParsed(end+1)  = iParsed;
end

% 3) Pour chaque FOV qu'on va traiter, (ré)injecter les ROIs
for idxLocal = 1:numel(newFovIndicesInProject)
    fProj   = newFovIndicesInProject(idxLocal);
    iParsed = newFovIndicesInParsed(idxLocal);

    % Sécurité
    if fProj > numel(shallowObj.fov) || iParsed > numel(parsedData.positions)
        continue;
    end

    posParsed = parsedData.positions(iParsed);
    thisFOV   = shallowObj.fov(fProj);

    % Si cette FOV fait partie d'une re-extraction, on efface les anciennes ROIs
    isReextractThisOne = false;
    for rr = 1:numel(reextractList)
        if reextractList(rr).fovIndex == fProj
            isReextractThisOne = true;
            break;
        end
    end
    if isReextractThisOne
        fprintf('DEBUG: wiping previous ROIs in FOV %d before re-extraction\n', fProj);
        thisFOV.roi = roi;  % on écrase

        % Effacer physiquement les anciens fichiers ROI du disque
    % chemin dossier où vivent im_<roiID>.mat / data_<roiID>.mat
    roiFolder = fullfile(shallowObj.io.path, shallowObj.io.file, thisFOV.id);

    % pour chaque ROI existante, supprimer les fichiers correspondants
    if isprop(thisFOV,'roi') && ~isempty(thisFOV.roi)
        for r = 1:numel(thisFOV.roi)
            roiID = thisFOV.roi(r).id;

            % im_<roiID>.mat
            imgFile  = fullfile(roiFolder, ['im_'   roiID '.mat']);
            if exist(imgFile,'file')
                try
                    delete(imgFile);
                    fprintf('DEBUG: deleted old ROI image file %s\n', imgFile);
                catch ME
                    fprintf('DEBUG: could not delete %s (%s)\n', imgFile, ME.message);
                end
            end

            % data_<roiID>.mat
            dataFile = fullfile(roiFolder, ['data_' roiID '.mat']);
            if exist(dataFile,'file')
                try
                    delete(dataFile);
                    fprintf('DEBUG: deleted old ROI data file %s\n', dataFile);
                catch ME
                    fprintf('DEBUG: could not delete %s (%s)\n', dataFile, ME.message);
                end
            end
        end
    end

    end

    % Déterminer les ROI candidates
    candidateROIs = [];

    % 1. ROI spécifique à cette position ?
    if isfield(posParsed,'roibb') && ~isempty(posParsed.roibb)
        fprintf('DEBUG: posParsed.roibb trouvé pour FOV %d: %d ROI(s)\n', ...
            fProj, size(posParsed.roibb,1));
        candidateROIs = posParsed.roibb;

        % 2. ROI globale ?
    elseif isfield(parsedData,'roibb') && ~isempty(parsedData.roibb)
        fprintf('DEBUG: parsedData.roibb global utilisé pour FOV %d: %d ROI(s)\n', ...
            fProj, size(parsedData.roibb,1));
        candidateROIs = parsedData.roibb;

        % 3. fallback "full-frame" si roitype='full'
    else
        isFullFrameMode = (isfield(parsedData,'roitype') && strcmpi(parsedData.roitype,'full'));

        if isFullFrameMode
            fprintf('DEBUG: Aucune ROI explicite. On tente fallback full-frame.\n');

            % Essayer de déduire la taille W,H
            Wguess = [];
            Hguess = [];

            % a) à partir de channelSizes "677 946" ou "677 x 946"
            if isfield(posParsed,'channelSizes') && ~isempty(posParsed.channelSizes) ...
                    && ~isempty(posParsed.channelSizes{1})
                dims = sscanf(posParsed.channelSizes{1}, '%d %d');
                if isempty(dims)
                    dims = sscanf(posParsed.channelSizes{1}, '%d x %d');
                end
                if numel(dims) >= 2
                    Wguess = dims(1);
                    Hguess = dims(2);
                    fprintf('DEBUG: taille extraite de channelSizes: W=%d H=%d\n', Wguess, Hguess);
                end
            end

            % b) sinon, multiTIFF -> imfinfo
            if (isempty(Wguess) || isempty(Hguess)) && ...
                    isfield(posParsed,'isMultiTiff') && posParsed.isMultiTiff && ...
                    isfield(posParsed,'multiTiffPath') && ~isempty(posParsed.multiTiffPath)
                try
                    infoTmp = imfinfo(posParsed.multiTiffPath);
                    Wguess = infoTmp(1).Width;
                    Hguess = infoTmp(1).Height;
                    fprintf('DEBUG: taille via imfinfo multiTIFF: W=%d H=%d\n', Wguess, Hguess);
                catch ME
                    fprintf('DEBUG: imfinfo fallback a échoué pour FOV %d: %s\n', fProj, ME.message);
                end
            end

            % c) si toujours rien -> pas de ROI
            if isempty(Wguess) || isempty(Hguess)
                fprintf('DEBUG: Impossible de déterminer la taille image pour FOV %d. Pas de ROI ajoutée.\n', fProj);
                candidateROIs = [];
            else
                candidateROIs = [1 1 double(Wguess) double(Hguess)];
                fprintf('DEBUG: ROI full-frame générée pour FOV %d: [%d %d %d %d]\n', ...
                    fProj, candidateROIs(1),candidateROIs(2),candidateROIs(3),candidateROIs(4));
            end
        else
            fprintf('DEBUG: roitype != full et aucune ROI détectée pour FOV %d -> pas de ROI.\n', fProj);
            candidateROIs = [];
        end
    end

    % Ajouter physiquement les ROIs
    if isempty(candidateROIs)
        fprintf('DEBUG: candidateROIs vide pour FOV %d -> aucune ROI ajoutée.\n', fProj);
    else
        for j = 1:size(candidateROIs,1)
            bb = candidateROIs(j,:);  % [x y w h]
            if numel(bb) < 4
                fprintf('DEBUG: ROI #%d pour FOV %d invalide (<4 vals) -> skip.\n', j, fProj);
                continue;
            end

            roiID = sprintf('%s_%d', thisFOV.id, j);

            % Vérifier duplication ROI
            roiExists = false;
            if ~isempty(thisFOV.roi)
                for kR = 1:numel(thisFOV.roi)
                    existingROI = thisFOV.roi(kR);
                    if isprop(existingROI,'id') && isprop(existingROI,'value') ...
                            && strcmp(existingROI.id, roiID) && isequal(existingROI.value, bb)
                        roiExists = true;
                        fprintf('DEBUG: ROI %s déjà existante dans FOV %d. skip.\n', roiID, fProj);
                        break;
                    end
                end
            end

            if ~roiExists
                fprintf('DEBUG: Ajout ROI %s à FOV %d, bb=[%d %d %d %d]\n', ...
                    roiID, fProj, bb(1),bb(2),bb(3),bb(4));
                thisFOV.addROI(bb, thisFOV.id);
            end
        end
    end

    % Réinjecter FOV modifiée dans le projet
    shallowObj.fov(fProj) = thisFOV;
end

%% =======================================================================
% Étape B : Préparer les arguments pour extractAllROICrops
%% =======================================================================
fovArg      = [];
framesCell  = {};
channelCell = {};

for idxLocal = 1:numel(newFovIndicesInProject)
    fProj   = newFovIndicesInProject(idxLocal);  % index FOV dans shallowObj
    iParsed = newFovIndicesInParsed(idxLocal);   % index parsedData.positions

    if fProj > numel(shallowObj.fov)
        fprintf('DEBUG: fProj=%d dépasse shallowObj.fov. skip.\n', fProj);
        continue;
    end
    if iParsed > numel(parsedData.positions)
        fprintf('DEBUG: iParsed=%d dépasse parsedData.positions. skip.\n', iParsed);
        continue;
    end

    posParsed = parsedData.positions(iParsed);
    thisFOV   = shallowObj.fov(fProj);   % nécessaire pour récupérer les noms de canaux

    % Vérifier sélection / extractROI
    if ~isfield(posParsed,'selected') || ~posParsed.selected
        fprintf('DEBUG: FOV %d non sélectionnée (selected=false). skip extraction.\n', fProj);
        continue;
    end
    if ~isfield(posParsed,'extractROI') || ~posParsed.extractROI
        fprintf('DEBUG: FOV %d extractROI=false. skip extraction.\n', fProj);
        continue;
    end

    % Frames à prendre (UI clamp)
    if isfield(posParsed,'currentMinFrame') && isfield(posParsed,'currentMaxFrame') && ...
            ~isempty(posParsed.currentMinFrame) && ~isempty(posParsed.currentMaxFrame)

        startF = max(1, floor(posParsed.currentMinFrame));

        % borne dure = maxFrame si présent (typiquement nb total d'images)
        if isfield(posParsed,'maxFrame') && ~isempty(posParsed.maxFrame)
            hardMax = posParsed.maxFrame;
        else
            if isfield(posParsed,'frames') && ~isempty(posParsed.frames)
                hardMax = max(posParsed.frames(:));
            else
                hardMax = startF;
            end
        end

        stopF  = min( ceil(posParsed.currentMaxFrame), hardMax );
        if stopF < startF
            stopF = startF;
        end

        frameRange = startF:stopF;
        fprintf('DEBUG: FOV %d frameRange (UI-clamped) = [%d..%d] -> %d frames\n', ...
            fProj, startF, stopF, numel(frameRange));

    elseif isfield(posParsed,'frames') && ~isempty(posParsed.frames)
        frameRange = posParsed.frames;
        fprintf('DEBUG: FOV %d frameRange (full) = [%d..%d] -> %d frames\n', ...
            fProj, frameRange(1), frameRange(end), numel(frameRange));
    else
        frameRange = 1;
        fprintf('DEBUG: FOV %d frameRange defaulted to [1]\n', fProj);
    end

    % Channels sélectionnés
    if isfield(posParsed,'channelsSelected') && ~isempty(posParsed.channelsSelected)
        chanMask = logical(posParsed.channelsSelected);
    else
        nChGuess = numel(shallowObj.fov(fProj).channel);
        if nChGuess==0, nChGuess=1; end
        chanMask = true(1,nChGuess);
    end
    chanSelected = find(chanMask);
    fprintf('DEBUG: FOV %d channelsSelected = %s\n', fProj, mat2str(chanSelected));

    % Stocker pour saveCroppedImages
    fovArg(end+1)      = fProj;            %#ok<AGROW>
    framesCell{end+1}  = frameRange;       %#ok<AGROW>
   % channelCell{end+1} = chanSelected;     %#ok<AGROW>
    channelCell{end+1} = cellfun(@char, string(thisFOV.channel(chanSelected)), 'UniformOutput', false);

end

% --- Normalisation des canaux selon le nb de FOVs ---
% (1) si une seule FOV, on passe directement une cellstr {'Channel0','Channel1'}
% (2) sinon, on passe une cell (1xNfov) dont chaque élément est une cellstr
if numel(fovArg) == 1
    channelsArg = channelCell{1};   % dépaqueter 1x1 cell -> 1xN cell
else
    channelsArg = channelCell;      % rester en 1xNfov cell
end

% --- Forcer le type en cellstr partout (strjoin-compatible) ---
if iscell(channelsArg)
    if ~isempty(channelsArg) && iscell(channelsArg{1})
        % Cas multi-FOV : chaque entrée doit être une cellstr
        for k = 1:numel(channelsArg)
            channelsArg{k} = cellfun(@char, string(channelsArg{k}), 'UniformOutput', false);
        end
    else
        % Cas mono-FOV (ou cell plate) : convertir en cellstr
        channelsArg = cellfun(@char, string(channelsArg), 'UniformOutput', false);
    end
elseif isstring(channelsArg)
    channelsArg = cellstr(channelsArg);
elseif ischar(channelsArg)
    channelsArg = {channelsArg};
else
    channelsArg = cellstr(string(channelsArg));
end



if isempty(fovArg)
    fprintf('DEBUG: Aucune FOV à extraire (fovArg vide). On va juste sauver le projet.\n');
end


%% =======================================================================
% Étape D : extractAllROICrops ou juste save
%% =======================================================================
if ~isempty(fovArg)
    fprintf('DEBUG: Appel extractAllROICrops sur fovArg=%s\n', mat2str(fovArg));
    corrDrift = false;
    if isfield(parsedData,'correctdrift') && parsedData.correctdrift
        corrDrift = true;
    end

shallowObj.extractAllROICrops( ...
    'FOVIndex',      fovArg, ...
    'Frames',        framesCell, ...
    'Channels',      channelsArg, ...
    'CorrectDrift',  corrDrift, ...
    'CropDrift',     1, ...
    'CrashRecovery', 0);



    fprintf('DEBUG: extractAllROICrops terminé.\n');
else
    fprintf('DEBUG: Rien à extraire -> shallowSave(shallowObj) direct.\n');
    shallowSave(shallowObj);
end


%% =======================================================================
% Étape E : resynchroniser les ROIs en mémoire après extraction/re-extraction
%% =======================================================================
% On veut que shallowObj.fov(f).roi(r) ait bien son image/path à jour,
% sinon ScoreApp pensera qu'il n'y a rien à afficher.
% fovProcessed = unique([newFovIndicesInProject(:)' [reextractList.fovIndex] ]);
% for idx = 1:numel(fovProcessed)
%     fProj = fovProcessed(idx);
%     if isempty(fProj) || fProj > numel(shallowObj.fov)
%         continue;
%     end
%     thisFOV = shallowObj.fov(fProj);
%     if isempty(thisFOV.roi)
%         continue;
%     end
% 
%     for r = 1:numel(thisFOV.roi)
%         roiObj = thisFOV.roi(r);
% 
%         % Tenter de recharger complètement la ROI depuis disque
%         if ismethod(roiObj,'load')
%             try
%                 roiObj.load();
%                 fprintf('DEBUG: ROI %s reloaded from disk for FOV %d\n', roiObj.id, fProj);
%             catch ME
%                 fprintf('DEBUG: reload failed for ROI %s in FOV %d: %s\n', roiObj.id, fProj, ME.message);
%             end
%         else
%             % fallback : si roiObj.path est vide, on essaie de l'inférer
%             if (~isprop(roiObj,'path') || isempty(roiObj.path)) && isprop(roiObj,'id')
%                 % On tente un chemin du type <tmpProject>/<FOVID>/im_<ROIID>.mat
%                 basepath = shallowObj.io.path;
%                 if isprop(thisFOV,'id')
%                     guessPath = fullfile(basepath, thisFOV.id, ['im_' roiObj.id '.mat']);
%                     if exist('guessPath','var') && isfile(guessPath)
%                         if isprop(roiObj,'path')
%                             roiObj.path = guessPath;
%                             fprintf('DEBUG: ROI %s assigned path %s\n', roiObj.id, guessPath);
%                         end
%                     end
%                 end
%             end
%         end
% 
%         % réécrire dans FOV
%         thisFOV.roi(r) = roiObj;
%     end
% 
%     shallowObj.fov(fProj) = thisFOV;
% end


%% Après extraction/sauvegarde : reconstruire parsedData depuis le projet
shallowObj.parsedData = loadData_rebuildParsedDataFromProject(shallowObj);
shallowSave(shallowObj);

if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.80;
    hprogressbar.Message = 'Project saved...';
    drawnow;
end

%% Manage the variable in the workspace
if ~projectLoaded
    fullpath = fullfile(char(projFolder), [char(projFilename) '.mat']);
    projName = shallowObj.io.file;

    [shallowObj, msg] = shallowLoad(fullpath);
    if ~isempty(msg)
        disp(msg);
    end
    assignin('base', projName, shallowObj);
end

%% =======================================================================
% Étape F : Préparer l'affichage des ROIs dans ScoreApp
%% =======================================================================
if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.95;
    hprogressbar.Message = 'Loading ROIs';
    drawnow;
end

nroimax = parsedData.maxroidisplay;

if nroimax == 0
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 1.0;
        hprogressbar.Message = '';
        drawnow;
    end
    return;
end

figures   = findall(0, 'Type', 'figure');
appFigure = findobj(figures, 'Name', 'ScoreApp');

% On collecte d'abord les ROIs affichables
roiToDisplay = {};

% On veut afficher les FOV nouvellement ajoutées ET les FOV retraitées.
fovsForDisplay = unique([newFovIdx(:)' [reextractList.fovIndex] ]);


for f = fovsForDisplay
    if isempty(f) || f > numel(shallowObj.fov)
        continue;
    end

    currentFOV = shallowObj.fov(f);

    if isempty(currentFOV.roi) || numel(currentFOV.roi) == 0
        continue;
    end

    for r = 1:numel(currentFOV.roi)
        roiObj = currentFOV.roi(r);


        % Heuristique "affichable"
        hasImage = false;

        % 1. Image déjà en RAM ?
        if isprop(roiObj,'image') && ~isempty(roiObj.image)
            hasImage = true;
        end

        % 2. ou bien un champ 'path' ou 'imagepath' pointant vers un .mat sur disque ?
        if ~hasImage
            candidatePaths = {};
            if isprop(roiObj,'path') && ~isempty(roiObj.path)
                candidatePaths{end+1} = roiObj.path;
            end
            if isprop(roiObj,'imagepath') && ~isempty(roiObj.imagepath)
                candidatePaths{end+1} = roiObj.imagepath;
            end
            if isprop(roiObj,'datafile') && ~isempty(roiObj.datafile)
                candidatePaths{end+1} = roiObj.datafile;
            end

            for cp = 1:numel(candidatePaths)
                if ~isempty(candidatePaths{cp}) && exist(candidatePaths{cp},'file')
                    hasImage = true;
                    break;
                end
            end
        end

        % 3. en dernier recours : accepte la ROI quand même.
        %    Pourquoi ? Parce que 'score(roiObj)' sait RE-load la ROI depuis le disk
        %    (on l'a vu dans les logs : "ROI: ... successfully loaded").
        %    Donc l'absence d'image immédiate n'est PAS bloquante.
        if ~hasImage
            fprintf('DEBUG: ROI %d de FOV %d sans image préchargée, on tente quand même pour ScoreApp.\n', r, f);
            hasImage = true;
        end

        % Maintenant on push.
        roiObj.parent = currentFOV;
        roiToDisplay{end+1} = roiObj;


        if numel(roiToDisplay) >= nroimax
            break;
        end
    end

    if numel(roiToDisplay) >= nroimax
        break;
    end
end

if isempty(roiToDisplay)
    disp('Aucune ROI disponible et affichable (pas d''image). ScoreApp ne sera pas lancé.');

    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 1.0;
        hprogressbar.Message = '';
        drawnow;
    end
    return;
end

% Ici seulement on lance / met à jour ScoreApp

figures=findall(0,'Type','figure');
appFigure=findobj(figures,'Name','ScoreApp');


for k = 1:numel(roiToDisplay)

  roiObj=roiToDisplay{k};

  if isprop(appFigure,'RunningAppInstance')
        appFigure.RunningAppInstance.addROI(roiObj);
  else
        score(roiObj);
  end

end



if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 1.0;
    hprogressbar.Message = '';
    drawnow;
end

end
