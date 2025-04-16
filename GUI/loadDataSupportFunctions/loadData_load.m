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
newIndex = 0;  % indice pour newdata.pos

for i = 1:nPos
    pos = parsedData.positions(i);
    
    % Vérifier que la position est sélectionnée
    if ~isfield(pos, 'selected') || ~pos.selected
        continue;  % on saute la position si elle n'est pas sélectionnée
    end
    
    % Vérifier si la position existe déjà dans shallowObj :
    % comparer l'identifiant (ici pos.userName) et le chemin de données (pos.folder)
    duplicate = false;
    if isprop(shallowObj, 'fov') && ~isempty(shallowObj.fov)
        for k = 1:numel(shallowObj.fov)
            % On suppose que l'identifiant de la FOV est stocké dans shallowObj.fov(k).id
            % et que le chemin de données source est dans shallowObj.fov(k).srcPath{1}.
            % Si les deux sont identiques à pos.userName et pos.folder respectivement, 
            % c'est la même data.
            if  strcmp(shallowObj.fov(k).srcpath{1}, pos.folder)
                duplicate = true;
                disp(['Warning : position duplication ! Skipping position addition: ' num2str(i)])
                break;
            end
        end
    end
    

    % Si cette position existe déjà, on ne l'ajoute pas.
    if duplicate
        continue;
    end

    % Sinon, on incrémente l'indice interne pour newdata et on remplit les champs.
    newIndex = newIndex + 1;
    
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
        hprogressbar.Message = sprintf('Processing position %d/%d...', i, nPos);
        drawnow;
    end
    
    % Déterminer le nombre de canaux pour cette position
    if isfield(pos, 'channelsDir') && ~isempty(pos.channelsDir)
        nChannels = numel(pos.channelsDir);
    else
        nChannels = 0;
    end
    
    newdata.pos(newIndex).name = pos.userName;
    newdata.pos(newIndex).contours = [];
    
    % Le champ pathlist : le même dossier répété pour chaque canal
    newdata.pos(newIndex).pathlist = repmat({pos.folder}, 1, nChannels);
    
    % Le champ filelist est directement la cellule channelsDir
    newdata.pos(newIndex).filelist = pos.channelsDir;
    
    % Déterminer les noms des canaux : si pos.userChanName est défini et cohérent, on l'utilise ;
    % sinon, on se base sur pos.channels.
    if isfield(pos, 'userChanName') && numel(pos.userChanName) == nChannels
        newdata.pos(newIndex).channelname = pos.userChanName;
    elseif isfield(pos, 'channels') && numel(pos.channels) == nChannels
        newdata.pos(newIndex).channelname = pos.channels;
    else
        newdata.pos(newIndex).channelname = cell(1, nChannels);
        for j = 1:nChannels
            newdata.pos(newIndex).channelname{j} = sprintf('Channel %d', j-1);
            if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
                hprogressbar.Message = sprintf('Position %d/%d, channel %d/%d: updating channel name', i, nPos, j, nChannels);
                drawnow;
            end
        end
    end
    
    % Calculer le nombre de frames pour chaque canal
    newdata.pos(newIndex).frames = zeros(1, nChannels);
    for j = 1:nChannels
        newdata.pos(newIndex).frames(j) = numel(pos.channelsDir{j});
        if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
            hprogressbar.Message = sprintf('Position %d/%d, channel %d/%d: computing frames', i, nPos, j, nChannels);
            drawnow;
        end
    end
    
    % Déterminer l'intervalle (fréquence)
    if isfield(pos, 'channelFrequencies') && numel(pos.channelFrequencies) >= nChannels
        newdata.pos(newIndex).interval = pos.channelFrequencies(1:nChannels);
    else
        newdata.pos(newIndex).interval = ones(1, nChannels);
    end
    
    % Calculer le binning pour chaque canal : extraire la largeur depuis pos.channelSizes et normaliser
    newdata.pos(newIndex).binning = zeros(1, nChannels);
    for j = 1:nChannels
        if isfield(pos, 'channelSizes') && numel(pos.channelSizes) >= j && ~isempty(pos.channelSizes{j})
            dims = sscanf(pos.channelSizes{j}, '%d x %d');
            if ~isempty(dims)
                newdata.pos(newIndex).binning(j) = dims(1);
            else
                newdata.pos(newIndex).binning(j) = 1;
            end
        else
            newdata.pos(newIndex).binning(j) = 1;
        end
        if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
            hprogressbar.Message = sprintf('Position %d/%d, channel %d/%d: computing binning', i, nPos, j, nChannels);
            drawnow;
        end
    end
    if nChannels > 0 && newdata.pos(newIndex).binning(1) ~= 0
        newdata.pos(newIndex).binning = newdata.pos(newIndex).binning ./ newdata.pos(newIndex).binning(1);
    end
    
    % Mise à jour de la barre de progression pour cette position
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

%% Add data to the shallow project
shallowObj.addData(newdata);
if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
    hprogressbar.Value = 0.50;
    hprogressbar.Message = 'Data added to the project...';
    drawnow;
end

   

%% Add ROIs
nFov = numel(shallowObj.fov);
for i = 1:nFov
    % Ne traiter que les positions (FOV) sélectionnées dans parsedData
    if ~parsedData.positions(i).selected
         continue;
    end

    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Message = sprintf('Adding ROIs for FOV %d/%d...', i, nFov);
         drawnow;
    end

    % Déterminer les ROI candidates :
    if isempty(parsedData.positions(i).roibb)
         if isempty(parsedData.roibb)
             % Aucun ROI défini ni par position ni globalement : 
             % on prend le full frame basé sur la taille du premier canal de la première position
             tmp = str2num(parsedData.positions(1).channelSizes{1});
             candidateROIs = reshape([1 1 tmp(1) tmp(2)], 1, []);  % un ROI sous forme 1x4
         else
             candidateROIs = parsedData.roibb;
         end
    else
         candidateROIs = parsedData.positions(i).roibb;
    end


    % Pour chaque ROI candidate, vérifier si elle existe déjà dans la FOV
    for j = 1:size(candidateROIs, 1)
         candidateValue = candidateROIs(j, :);
         % On construit un identifiant candidate basé sur l'identifiant du fov et le numéro de ROI
         candidateROIid = sprintf('%s_%d', shallowObj.fov(i).id, j);

         % Vérification de l'existence d'une ROI avec le même id et la même valeur
         roiExists = false;
         if ~isempty(shallowObj.fov(i).roi)
             for k = 1:numel(shallowObj.fov(i).roi)
                  existingROI = shallowObj.fov(i).roi(k);
                  if strcmp(existingROI.id, candidateROIid) && isequal(existingROI.value, candidateValue)
                      roiExists = true;
                      break;
                  end
             end
         end

         % N'ajouter la ROI que si elle n'existe pas déjà
         if ~roiExists
             shallowObj.fov(i).addROI(candidateValue, shallowObj.fov(i).id);
             if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
                 hprogressbar.Message = sprintf('FOV %d/%d: added ROI %d/%d', i, nFov, j, size(candidateROIs, 1));
                 drawnow;
             end
         end
    end

    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 0.50 + 0.10 * (i / nFov);
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
    if numel(fovArg)
    shallowObj.saveCroppedImages('frames', framesCell, 'fov', fovArg, 'cut', parsedData.maxframeloading, ...
        'correctdrift', corrDrift,'cropdrift', 1, 'crashrecovery', 0, ...
        'channel', channelCell, 'scale', parsedData.scale,'hprogressbar',hprogressbar);
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 0.80;
         hprogressbar.Message = 'Cropped images saved...';
         drawnow;
    end
    else % save the project at this point, knowing that saveCroppred Images saves the project anyway
    shallowSave(shallowObj);
    if exist('hprogressbar', 'var') && ~isempty(hprogressbar)
         hprogressbar.Value = 0.90;
         hprogressbar.Message = 'Project saved...';
         drawnow;
    end
    end

   % fullpath = fullfile(char(projFolder), [char(projFilename) '.mat']);
   % disp(['Shallow project created and saved: ' fullpath]);


    %% Manage the variable in the workspace

    if ~projectLoaded % in this case load the project in the workspace

    % projName = shallowObj.io.file;
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
            appFigure.addROI(roiObj);
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
