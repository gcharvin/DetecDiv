function parsedData = loadData_parse(files, folder)
% loadData_parse Analyse les noms de fichiers et/ou le dossier pour extraire 
% le nombre de frames, de channels, de positions, ainsi que la fréquence
% d'acquisition et la taille des images pour chaque channel.
%
% Syntaxe:
%   parsedData = loadData_parse(files, folder)
%
% Inputs:
%   files  - Liste de noms de fichiers (cell array de strings) sans le chemin.
%            Peut être vide ({}) si l'on souhaite passer uniquement un dossier.
%   folder - Chemin du dossier contenant les fichiers.
%
% Output:
%   parsedData - Structure contenant les informations extraites avec les champs :
%       .numPositions : Nombre de positions
%       .positions    : Array de structures, chacune correspondant à une position et
%                       contenant notamment :
%           .folder            : Chemin du dossier (ou sous-dossier)
%           .files             : Liste complète des fichiers (cell array)
%           .numFrames         : Nombre de frames (basé sur le champ "time")
%           .frames            : Vecteur des frames uniques
%           .minFrame          : Valeur minimale parmi les frames de la position
%           .maxFrame          : Valeur maximale parmi les frames de la position
%           .numChannels       : Nombre de channels (identifiant unique issu de channel et z)
%           .channels          : Cell array des channels uniques
%           .channelFrequencies: Vecteur indiquant la fréquence d'acquisition de chaque channel
%           .channelSizes      : Cell array indiquant la taille (Width x Height) de la première image de chaque channel
%           .channelsSelected  : Vecteur logique indiquant si chaque channel est sélectionné (par défaut true)
%           .userChanName      : Cell array de noms d'utilisateur par défaut pour chaque channel
%           .selected          : (Pour la position) true par défaut
%           .userName          : Nom d'utilisateur par défaut pour la position
%       .minFrame     : La plus petite frame parmi toutes les positions (globale)
%       .maxFrame     : La plus grande frame parmi toutes les positions (globale)
%
% Exemple de nom de fichier attendu:
%   img_channel000_position010_time000000001_z000
%
% Les zstacks (_z0XX) sont traités comme des channels séparés.

if ~isfolder(folder)
    error('Le chemin spécifié n''est pas un dossier valide.');
end

if isempty(files)
    % Cas : Seul le dossier est fourni.
    d = dir(folder);
    d = d(~ismember({d.name}, {'.', '..'})); % Exclure '.' et '..'
    subDirs = d([d.isdir]);
    
    if ~isempty(subDirs)
        % Le dossier contient des sous-dossiers : chaque sous-dossier est une position.
        numPositions = numel(subDirs);
        positions = [];  % initialisation
        for i = 1:numPositions
            subfolderPath = fullfile(folder, subDirs(i).name);
            fileList = getFileList(subfolderPath);
            posInfo = parseFileList(fileList, true);
            posInfo.folder = subfolderPath;
            positions = [positions, posInfo]; %#ok<AGROW>
        end
    else
        % Pas de sous-dossiers : le dossier est considéré comme une seule position.
        fileList = getFileList(folder);
        posInfo = parseFileList(fileList, true);
        posInfo.folder = folder;
        positions = posInfo;
    end
else
    % Cas : une liste de fichiers est fournie.
    fileList = cellfun(@(f) fullfile(folder, f), files, 'UniformOutput', false);
    posInfo = parseFileList(fileList, true);
    posInfo.folder = folder;
    positions = posInfo;
end

% Pour chaque position, calculer minFrame et maxFrame et ajouter les champs par défaut.
for i = 1:numel(positions)
    if ~isempty(positions(i).frames)
        positions(i).minFrame = min(positions(i).frames);
        positions(i).maxFrame = max(positions(i).frames);
    else
        positions(i).minFrame = NaN;
        positions(i).maxFrame = NaN;
    end
    % Marquer la position comme sélectionnée par défaut.
    positions(i).selected = true;
    % Définir un nom d'utilisateur pour la position.
    if isfield(positions(i), 'folder') && ~isempty(positions(i).folder)
        folderPath = positions(i).folder;
        if folderPath(end)==filesep || folderPath(end)=='/'
            folderPath = folderPath(1:end-1);
        end
        idx = find(folderPath==filesep | folderPath=='/', 1, 'last');
        if isempty(idx)
            posName = folderPath;
        else
            posName = folderPath(idx+1:end);
        end
        positions(i).userName = posName;
    else
        positions(i).userName = sprintf('Pos%d', i-1);
    end
end

parsedData.numPositions = numel(positions);
parsedData.positions = positions;

% Calcul global de minFrame et maxFrame sur toutes les positions
globalFrames = [];
for i = 1:numel(positions)
    globalFrames = [globalFrames; positions(i).frames(:)]; %#ok<AGROW>
end
if ~isempty(globalFrames)
    parsedData.minFrame = min(globalFrames);
    parsedData.maxFrame = max(globalFrames);
else
    parsedData.minFrame = NaN;
    parsedData.maxFrame = NaN;
end

end

%% Fonction locale pour récupérer la liste des fichiers d'un dossier
function fileList = getFileList(folderPath)
    d = dir(folderPath);
    d = d(~[d.isdir]);  % Conserver uniquement les fichiers
    fileList = fullfile(folderPath, {d.name});
end

%% Fonction locale pour parser la liste de fichiers
function info = parseFileList(fileList, forceSinglePosition)
% Analyse la liste de fichiers pour extraire les informations de frame, channel et position.
% De plus, calcule pour chaque channel la fréquence d'acquisition et la taille
% de la première image (si fichier TIFF), puis initialise par défaut :
%   - channelsSelected à true pour chaque channel,
%   - userChanName à 'Channel X' pour chaque channel.
%
% Si forceSinglePosition est vrai, on considère qu'il n'y a qu'une seule position.

    if nargin < 2
        forceSinglePosition = false;
    end
    
    acceptedExtensions = {'.tif', '.tiff', '.png', '.jpg', '.jpeg'};
    
    times = [];
    channelsArr = [];
    posArr = [];
    zArr = [];
    
    for i = 1:length(fileList)
        [~, name, ext] = fileparts(fileList{i});
        if ~any(strcmpi(ext, acceptedExtensions))
            continue;
        end
        fileName = [name, ext];
        % Expression régulière pour extraire channel, position, time et z.
        tokens = regexp(fileName, '.*_channel(\d+)_position(\d+)_time(\d+)_z(\d+)', 'tokens');
        if ~isempty(tokens)
            tokens = tokens{1};
            chVal = str2double(tokens{1});
            posVal = str2double(tokens{2});
            timeVal = str2double(tokens{3});
            zVal = str2double(tokens{4});
            
            channelsArr(end+1) = chVal;
            posArr(end+1) = posVal;
            times(end+1) = timeVal;
            zArr(end+1) = zVal;
        else
            continue;
        end
    end
    
    if isempty(times)
        info.numFrames = 0;
        info.frames = [];
        info.numChannels = 0;
        info.channels = {};
        info.channelFrequencies = [];
        info.channelSizes = {};
        info.channelsSelected = [];
        info.userChanName = {};
        if forceSinglePosition
            info.numPositions = 1;
            info.positions = 1;
        else
            info.numPositions = 0;
            info.positions = [];
        end
        info.files = fileList;
        return;
    end
    
    uniqueFrames = unique(times);
    info.numFrames = numel(uniqueFrames);
    info.frames = uniqueFrames;
    
    % Création des identifiants de channels à partir de channel et z.
    ch_z = arrayfun(@(c, z) sprintf('%03d_z%03d', c, z), channelsArr, zArr, 'UniformOutput', false);
    uniqueCh = unique(ch_z);
    info.numChannels = numel(uniqueCh);
    info.channels = uniqueCh;
    
    channelFrequencies = zeros(1, info.numChannels);
    channelSizes = cell(1, info.numChannels);
    
    for c = 1:info.numChannels
        idx = find(strcmp(ch_z, uniqueCh{c}));
        channelTimes = sort(times(idx));
        if numel(channelTimes) > 1
            diffs = diff(channelTimes);
            freq = median(diffs);
            channelFrequencies(c) = freq;
        else
            channelFrequencies(c) = 1;
        end
        
        firstIdx = idx(1);
        fileForChannel = fileList{firstIdx};
        [~, ~, extFile] = fileparts(fileForChannel);
        try
            if strcmpi(extFile, '.tif') || strcmpi(extFile, '.tiff')
                infoTif = imfinfo(fileForChannel);
                width = infoTif(1).Width;
                height = infoTif(1).Height;
                channelSizes{c} = sprintf('%d x %d', width, height);
            else
                channelSizes{c} = 'N/A';
            end
        catch ME
            warning('Impossible de lire la taille de l''image pour %s: %s', fileForChannel, ME.message);
            channelSizes{c} = 'N/A';
        end
    end
    
    info.channelFrequencies = channelFrequencies;
    info.channelSizes = channelSizes;
    
    % Initialiser les champs de sélection et de nom d'utilisateur pour les channels
    info.channelsSelected = true(1, info.numChannels);
    info.userChanName = cell(1, info.numChannels);
    for j = 1:info.numChannels
        info.userChanName{j} = ['Channel ' num2str(j-1)];
    end
    
    if forceSinglePosition
        info.numPositions = 1;
        info.positions = 1;
    else
        uniquePos = unique(posArr);
        info.numPositions = numel(uniquePos);
        info.positions = uniquePos;
    end
    
    info.files = fileList;
end
