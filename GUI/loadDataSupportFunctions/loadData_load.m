function shallowObj=loadData_load(parsedData, hprogressbar)
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
    shallowObj = shallowNew('path', char(fullfile(projFolder, '/')), 'filename', [char(projFilename) '.mat']);
    if isempty(shallowObj)
        disp('Project creation canceled by the user.');
        return;
    end
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 0.10;
        hprogressbar.Message = 'Shallow project created...';
        drawnow;
    end
end

%% save parsedData in the current project
shallowObj.parsedData=parsedData;

%% Build the newdata structure to provide to addData
newdata.pos = [];
nPos = numel(parsedData.positions);
weight_positions = 0.30;  % progress portion allocated to this loop
newIndex = 0;             % index for newdata.pos

for i = 1:nPos

    % Protection anti-out-of-bounds si parsedData.positions a été modifié entre-temps
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
    duplicate = false;
    if isprop(shallowObj, 'fov') && ~isempty(shallowObj.fov)
        for k = 1:numel(shallowObj.fov)
            fovk = shallowObj.fov(k);

            if isempty(fovk) || ~isprop(fovk,'srcpath') || isempty(fovk.srcpath)
                continue;
            end

            % on vérifie qu'on peut accéder à srcpath{1} sans crasher
            sameFolder = false;
            if iscell(fovk.srcpath) && ~isempty(fovk.srcpath) && ...
               isfield(pos,'folder') && ~isempty(pos.folder)
                if ~isempty(fovk.srcpath{1})
                    sameFolder = strcmp(fovk.srcpath{1}, pos.folder);
                end
            end

            if sameFolder
                duplicate = true;
                disp(['Warning : position duplication ! Skipping position addition: ' num2str(i)]);
                break;
            end
        end
    end

    if duplicate
        continue;
    end

    % ----- Ok, on va créer une nouvelle entrée dans newdata.pos -----
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

    % Champ name
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

    % interval
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

        % tiffSource : dupliquer la même source pour chaque canal
        if isfield(pos,'tiffSource') && ~isempty(pos.tiffSource)
            newdata.pos(newIndex).tiffSource = repmat({pos.tiffSource}, 1, nChannels);
        else
            % fallback si pas défini
            newdata.pos(newIndex).tiffSource = repmat({''}, 1, nChannels);
        end

        % pageMap : pages = t1/ch1, t1/ch2, t2/ch1, t2/ch2, ...
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



if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.45;
    hprogressbar.Message = 'Adding data to the shallow project...';
    drawnow;
end


% AVANT l'ajout :
oldFovCount = numel(shallowObj.fov);
wasFirstDummyFov = false;
if oldFovCount == 1
    % regarder si c'est la FOV vide initiale
    if isempty(shallowObj.fov(1).srclist) || numel(shallowObj.fov(1).srclist)==0
        wasFirstDummyFov = true;
    end
end
nNewPos = numel(newdata.pos);


%% Add data to the shallow project
shallowObj.addData(newdata);
if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.50;
    hprogressbar.Message = 'Data added to the project...';
    drawnow;
end


% APRÈS l'ajout :
newFovCount = numel(shallowObj.fov);

if wasFirstDummyFov
    % Cas spécial : premier import dans un projet vide.
    % Dans addData, cc repart à 1, donc les nouvelles FOV sont
    % shallowObj.fov(1 : nNewPos).
    startNewFov = 1;
    endNewFov   = nNewPos;
else
    % Cas général : on append à la fin
    startNewFov = oldFovCount + 1;
    endNewFov   = oldFovCount + nNewPos;
end

newFovIdx = startNewFov:endNewFov;


%% Add ROIs only for the newly-added FOVs
if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.50;
    hprogressbar.Message = 'Adding ROIs...';
    drawnow;
end

% Sécurité : nombre de positions dans parsedData (celles du nouvel import)
nParsedPos = numel(parsedData.positions);

for localIdx = 1:numel(newFovIdx)

    fovIndex = newFovIdx(localIdx);   % index absolu dans shallowObj.fov
    posIndex = localIdx;              % index local correspondant dans parsedData.positions

    % Sanity: si pour une raison X, posIndex > nParsedPos, on skip
    if posIndex > nParsedPos
        continue;
    end

    thisPos = parsedData.positions(posIndex);

    % Vérifier si la position (dans l'import courant) est sélectionnée
    isSel = true;
    if isfield(thisPos,'selected') && ~isempty(thisPos.selected)
        isSel = logical(thisPos.selected);
    end
    if ~isSel
        continue;
    end

    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Message = sprintf('Adding ROIs for new FOV %d/%d...', localIdx, numel(newFovIdx));
        drawnow;
    end

    % Choisir les ROI candidates pour CETTE position importée
    candidateROIs = [];

    if isfield(thisPos,'roibb') && ~isempty(thisPos.roibb)
        candidateROIs = thisPos.roibb;
    elseif isfield(parsedData,'roibb') && ~isempty(parsedData.roibb)
        candidateROIs = parsedData.roibb;
    else
        % fallback full frame
        fullW = [];
        fullH = [];
        if isfield(thisPos,'channelSizes') && ~isempty(thisPos.channelSizes)
            dims = sscanf(thisPos.channelSizes{1}, '%d %d');
            if isempty(dims)
                dims = sscanf(thisPos.channelSizes{1}, '%d x %d');
            end
            if ~isempty(dims)
                fullW = dims(1);
                fullH = dims(2);
            end
        end
        if ~isempty(fullW) && ~isempty(fullH)
            candidateROIs = [1 1 fullW fullH];
        end
    end

    if isempty(candidateROIs)
        continue;
    end

    % Ajouter ces ROIs dans shallowObj.fov(fovIndex) si pas déjà présentes
    for j = 1:size(candidateROIs,1)
        roiVal = candidateROIs(j,:);
        roiID  = sprintf('%s_%d', shallowObj.fov(fovIndex).id, j);

        % Vérifier si elle existe déjà
        roiExists = false;
        if ~isempty(shallowObj.fov(fovIndex).roi)
            for k = 1:numel(shallowObj.fov(fovIndex).roi)
                if strcmp(shallowObj.fov(fovIndex).roi(k).id, roiID) && ...
                        isequal(shallowObj.fov(fovIndex).roi(k).value, roiVal)
                    roiExists = true;
                    break;
                end
            end
        end

        if ~roiExists
            shallowObj.fov(fovIndex).addROI(roiVal, shallowObj.fov(fovIndex).id);

            if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
                hprogressbar.Message = sprintf('FOV %d/%d: added ROI %d/%d', ...
                    localIdx, numel(newFovIdx), j, size(candidateROIs,1));
                drawnow;
            end
        end
    end

    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        % on fait monter un peu la barre
        hprogressbar.Value = 0.50 + 0.10 * (localIdx / max(1,numel(newFovIdx)));
        drawnow;
    end
end



%% Extract ROI data
if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.65;
    hprogressbar.Message = 'Extracting ROI data...';
    drawnow;
end

selectedPos = find([parsedData.positions.selected]);
if isempty(selectedPos)
    error('No position selected in the table.');
end


% Initialiser les cell arrays pour les frames et les channels
framesCell = {};
channelCell = {};
fovArg = [];

cc = 1;
for idx = 1:numel(selectedPos)
    i = selectedPos(idx);
    pos = parsedData.positions(i);
    % Ne traiter que les positions dont extractROI est true
    if pos.extractROI
        fovArg(end+1) = i;  %#ok<AGROW>

        if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
            hprogressbar.Message = sprintf('Extracting frames for FOV %d/%d...', cc, numel(selectedPos));
            drawnow;
        end
        if isfield(pos, 'currentMinFrame') && isfield(pos, 'currentMaxFrame') && ...
                ~isempty(pos.currentMinFrame) && ~isempty(pos.currentMaxFrame)
            framesCell{cc} = pos.currentMinFrame : pos.currentMaxFrame;
        else
            framesCell{cc} = pos.frames;
        end

        if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
            hprogressbar.Message = sprintf('Extracting channels for FOV %d/%d...', cc, numel(selectedPos));
            drawnow;
        end
        channelCell{cc} = find(pos.channelsSelected);

        cc = cc + 1;
    end
end

% fovArg = selectedPos;
if parsedData.correctdrift
    corrDrift = true;
else
    corrDrift = false;
end

if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.70;
    hprogressbar.Message = 'Saving cropped images...';
    drawnow;
end


%% Call saveCroppedImages with the constructed arguments

% Build the list of FOVs to crop (new FOVs only),
% plus les frames/channels demandés pour chaque.
framesCell  = {};
channelCell = {};
fovArg      = [];

cc = 1;
for posLocal = 1:numel(parsedData.positions)

    thisPos = parsedData.positions(posLocal);

    % seulement si la position est à extraire
    if isfield(thisPos,'selected') && ~thisPos.selected
        continue;
    end
    if isfield(thisPos,'extractROI') && ~thisPos.extractROI
        continue;
    end

    % map position locale -> index FOV absolu
    if posLocal > numel(newFovIdx)
        % pas de FOV correspondante (sécurité)
        continue;
    end
    thisFovIndex = newFovIdx(posLocal);

    % frames pour cette position
    if isfield(thisPos,'currentMinFrame') && isfield(thisPos,'currentMaxFrame') && ...
       ~isempty(thisPos.currentMinFrame) && ~isempty(thisPos.currentMaxFrame)
        framesHere = thisPos.currentMinFrame : thisPos.currentMaxFrame;
    else
        framesHere = thisPos.frames;
    end

    % channels sélectionnés pour cette position
    if isfield(thisPos,'channelsSelected') && ~isempty(thisPos.channelsSelected)
        chanSel = find(thisPos.channelsSelected);
    else
        % fallback : tous les canaux
        chanSel = 1:numel(thisPos.channelsDir);
    end

    framesCell{cc}  = framesHere;
    channelCell{cc} = chanSel;
    fovArg(cc)      = thisFovIndex;

    cc = cc + 1;
end

if ~isempty(fovArg)
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 0.65;
        hprogressbar.Message = 'Saving cropped images...';
        drawnow;
    end

    if parsedData.correctdrift
        corrDrift = true;
    else
        corrDrift = false;
    end

    shallowObj.saveCroppedImages( ...
        'frames',       framesCell, ...
        'fov',          fovArg, ...
        'cut',          parsedData.maxframeloading, ...
        'correctdrift', corrDrift, ...
        'cropdrift',    1, ...
        'crashrecovery',0, ...
        'channel',      channelCell, ...
        'scale',        parsedData.scale, ...
        'hprogressbar', hprogressbar );

    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 0.80;
        hprogressbar.Message = 'Cropped images saved...';
        drawnow;
    end
else
    % pas de FOV à extraire → juste faire un save projet classique
    shallowSave(shallowObj);
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 0.80;
        hprogressbar.Message = 'Project saved...';
        drawnow;
    end
end




% disp(['Shallow project created and saved: ' fullpath]);


%% Manage the variable in the workspace

if ~projectLoaded % in this case load the project in the workspace

    fullpath = fullfile(char(projFolder), [char(projFilename) '.mat']);
    projName = shallowObj.io.file;
    % if evalin('base', sprintf('exist(''%s'', ''var'')', projName))
    %      evalin('base', sprintf('clear %s', projName));
    %      disp(['Variable ', projName, ' already existed and has been cleared.']);
    % end

    [shallowObj, msg] = shallowLoad(fullpath);
    if ~isempty(msg)
        disp(msg);
    end
    assignin('base', projName, shallowObj);
end


%% loading regions of interest
if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.95;
    hprogressbar.Message = 'Loading ROIs';
    drawnow;
end

nroimax = parsedData.maxroidisplay;

if nroimax==0
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Value = 1.0;
        hprogressbar.Message = '';
        drawnow;
    end
    return
end

figures = findall(0, 'Type', 'figure');
appFigure = findobj(figures, 'Name', 'ScoreApp');

% Nombre maximum de ROIs à afficher
% Initialiser le compteur de ROIs ajoutées
roiCount = 0;

% Parcourir tous les FOV de shallowObj
for f = 1:numel(shallowObj.fov)

    if numel(find(fovArg==f))==0
        continue
    end

    currentFOV = shallowObj.fov(f);

    % Tester si ce FOV contient des ROIs
    if isempty(currentFOV.roi) || numel(currentFOV.roi) == 0
        continue;
    end

    % Parcourir chacune des ROIs de ce FOV
    for r = 1:numel(currentFOV.roi)
        roiObj = currentFOV.roi(r);
        roiCount = roiCount + 1;

        % Si le nombre maximum est atteint, sortir des boucles
        if roiCount > nroimax
            break;
        end

        roiObj.parent=currentFOV;

        % Si la figure ScoreApp n'existe pas, la créer en passant la première ROI
        if isempty(appFigure)
            appFigure = score(roiObj);
        else
            appFigure.RunningAppInstance.addROI(roiObj);
        end
    end

    if roiCount >= nroimax
        break;
    end
end

if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 1.0;
    hprogressbar.Message = '';
    drawnow;
end

if roiCount == 0
    disp('Aucune ROI disponible pour l''affichage.');
    return;
end

end
