function loadData_load(parsedData)

    %% Extraction des informations de base sur le projet
    [projFolder, projFilename, ~] = fileparts(parsedData.projectPath);
    
    % Création de l'instance du projet shallow via shallowNew
    shallowObj = shallowNew('path', char(projFolder), 'filename', [char(projFilename) '.mat']);
    if isempty(shallowObj)
         disp('Création du projet annulée par l''utilisateur.');
         return;
    end

    %% Construction de la structure newdata à fournir à addData
    % Pour chaque position, nous utilisons le champ channelsDir (déjà créé dans parsedData)
    % pour renseigner le champ filelist, et nous répétons le dossier pour chaque canal dans pathlist.
    newdata.pos = [];
    for i = 1:numel(parsedData.positions)
         pos = parsedData.positions(i);
         
         % Le nombre de canaux est déterminé à partir du champ channelsDir
         if isfield(pos, 'channelsDir') && ~isempty(pos.channelsDir)
             nChannels = numel(pos.channelsDir);
         else
             nChannels = 0;
         end
         
         newdata.pos(i).name = pos.userName;
         newdata.pos(i).contours = [];
         
         % Le champ pathlist : même dossier répété pour chacun des canaux
         newdata.pos(i).pathlist = repmat({pos.folder}, 1, nChannels);
         
         % Le champ filelist : directement le cell array channelsDir
         newdata.pos(i).filelist = pos.channelsDir;
         
         % Le nom des canaux : si pos.userChanName est défini et cohérent, on l'utilise,
         % sinon on se base sur pos.channels
         if isfield(pos, 'userChanName') && numel(pos.userChanName)==nChannels
             newdata.pos(i).channelname = pos.userChanName;
         elseif isfield(pos, 'channels') && numel(pos.channels)==nChannels
             newdata.pos(i).channelname = pos.channels;
         else
             newdata.pos(i).channelname = cell(1, nChannels);
             for j = 1:nChannels
                 newdata.pos(i).channelname{j} = sprintf('Channel %d', j-1);
             end
         end
         
         % Le nombre de frames pour chaque canal : ici on se base sur le nombre de fichiers trouvés
         newdata.pos(i).frames = zeros(1, nChannels);
         for j = 1:nChannels
             newdata.pos(i).frames(j) = numel(pos.channelsDir{j});
         end
         
         % L'intervalle (fréquence) : on utilise pos.channelFrequencies si disponible, sinon 1 par défaut
         if isfield(pos, 'channelFrequencies') && numel(pos.channelFrequencies) >= nChannels
             newdata.pos(i).interval = pos.channelFrequencies(1:nChannels);
         else
             newdata.pos(i).interval = ones(1, nChannels);
         end
         
         % Le binning : on extrait la largeur à partir de pos.channelSizes et on normalise par rapport
         % au premier canal (si disponible)
         newdata.pos(i).binning = zeros(1, nChannels);
         for j = 1:nChannels
             if isfield(pos, 'channelSizes') && numel(pos.channelSizes) >= j && ~isempty(pos.channelSizes{j})
                 dims = sscanf(pos.channelSizes{j}, '%d x %d');
                 if ~isempty(dims)
                     newdata.pos(i).binning(j) = dims(1);
                 else
                     newdata.pos(i).binning(j) = 1;
                 end
             else
                 newdata.pos(i).binning(j) = 1;
             end
         end
         if nChannels > 0 && newdata.pos(i).binning(1) ~= 0
             newdata.pos(i).binning = newdata.pos(i).binning ./ newdata.pos(i).binning(1);
         end
    end

    %% Ajout des données au projet shallow et sauvegarde
    shallowObj.addData(newdata);
    shallowSave(shallowObj);

    fullpath = fullfile(char(projFolder), [char(projFilename) '.mat']);
    disp(['Projet shallow créé et sauvegardé : ' fullpath]);

    %% Gestion de la variable dans l'espace de travail
    % Récupération du nom du projet depuis shallowObj.io.file
    projName = shallowObj.io.file;
    
    % Si une variable portant ce nom existe déjà, on la supprime
    if evalin('base', sprintf('exist(''%s'', ''var'')', projName))
        evalin('base', sprintf('clear %s', projName));
        disp(['Variable ', projName, ' existait déjà et a été supprimée.']);
    end

    [shallowObj, msg] = shallowLoad(fullpath);
    if ~isempty(msg)
        disp(msg);
    end

    assignin('base', projName, shallowObj);

    
end
