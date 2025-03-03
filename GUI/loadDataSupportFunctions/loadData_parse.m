function parsedData = loadData_parse(files, folder, invert)
% loadData_parse Analyse les noms de fichiers et/ou le dossier pour extraire 
% le nombre de frames, de channels, de positions, ainsi que la fréquence
% d'acquisition et la taille des images pour chaque channel.
%
% Syntaxe:
%   parsedData = loadData_parse(files, folder, invert)
%
% Inputs:
%   files  - Liste de noms de fichiers (cell array de strings) sans le chemin.
%            Peut être vide ({}) si l'on souhaite passer uniquement un dossier.
%   folder - Chemin du dossier contenant les fichiers.
%   invert - (booléen) Si true, toutes les positions seront fusionnées en une seule.
%
% Output:
%   parsedData - Structure contenant les informations extraites avec les champs :
%       .numPositions : Nombre de positions (1 si invert==true)
%       .roitype : type of ROI generated upon loading : full (frame),
%       divide (fractionnated), custom 
%       .roipattern : image pattern used to do the detection
%       .roibb : roi boundind box
%      
%       .positions    : Array de structures, chacune correspondant à une position et
%                       contenant notamment :
%           .folder            : Chemin du dossier (ou sous-dossier)
%           .files             : Liste complète des fichiers (cell array)
%           .fileDir           : Structure renvoyée par dir pour l'ensemble des fichiers
%           .channelsDir       : Cell array contenant, pour chaque channel parsé, la
%                                structure dir correspondante.
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
%           .roibb : an array of bounding boxes
%       .minFrame     : La plus petite frame parmi toutes les positions (globale)
%       .maxFrame     : La plus grande frame parmi toutes les positions (globale)
%
% Exemple de nom de fichier attendu:
%   img_channel000_position010_time000000001_z000
%
% Les zstacks (_z0XX) sont traités comme des channels séparés.

if nargin < 3
    invert = false;
end

if isempty(files) && isequal(folder,0)
    parsedData = [];
    disp('Le chemin spécifié n''est pas un dossier valide, ou l''utilisateur a annulé.');
    return;
end

if isempty(files)
    % Cas : Seul le dossier est fourni.
    d = dir(folder);
    d = d(~ismember({d.name}, {'.', '..'})); % Exclure '.' et '..'
    subDirs = d([d.isdir]);
    
    % Exclure "tmpProject"
    subDirs = subDirs(~strcmp({subDirs.name}, 'tmpProject'));
    
    if ~isempty(subDirs)
        % Le dossier contient des sous-dossiers : chaque sous-dossier est une position.
        numPositions = numel(subDirs);
        positions = [];  % initialisation
        for i = 1:numPositions
            subfolderPath = fullfile(folder, subDirs(i).name);
            [fileList, fileDir] = getFileList(subfolderPath);
            posInfo = parseFileList(fileList, true);
            posInfo.folder = subfolderPath;
            posInfo.fileDir = fileDir;  % fileDir est déjà un struct array
            positions = [positions, posInfo]; %#ok<AGROW>
        end
    else
        % Pas de sous-dossiers : le dossier est considéré comme une seule position.
        [fileList, fileDir] = getFileList(folder);
        posInfo = parseFileList(fileList, true);
        posInfo.folder = folder;
        posInfo.fileDir = fileDir;
        positions = posInfo;
    end
else
    % Cas : une liste de fichiers est fournie.
    fileList = cellfun(@(f) fullfile(folder, f), files, 'UniformOutput', false);
    % Pour obtenir un struct array, on utilise cell2mat sur le résultat de dir
    fileDirCells = cellfun(@(f) dir(f), fileList, 'UniformOutput', false);
    fileDir = cell2mat(fileDirCells);
    posInfo = parseFileList(fileList, true);
    posInfo.folder = folder;
    posInfo.fileDir = fileDir;
    positions = posInfo;
    
    % Initialiser d et subDirs pour éviter les erreurs ultérieures
    d = [];
    subDirs = [];
end

% Vérifier s'il y a des fichiers dans le dossier principal (seulement si d est défini)
if exist('d','var') && ~isempty(d)
    filesInFolder = d(~[d.isdir]);  % Liste des fichiers
    if ~isempty(subDirs) && ~isempty(filesInFolder)
        disp('Des fichiers sont présents au même niveau que les sous-dossiers, ils seront ignorés.');
    end
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
    positions(i).roibb=[];
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

% Découper la structure fileDir en un cell array par channel pour chaque position.
% Ce bloc s'assure que pour chaque position, positions(i).channelsDir est un cell array
% dont chaque cellule est un struct array (comme dans le cas du chargement d'un dossier).
for i = 1:numel(positions)
    channelsDir = cell(1, numel(positions(i).channels));
    for c = 1:numel(positions(i).channels)
         channelID = positions(i).channels{c};  % ex: '000_z000'
         files = positions(i).files;
         dirStruct = positions(i).fileDir;
         matchIDs = cell(size(files));
         for f = 1:length(files)
             tokens = regexp(files{f}, '.*_channel(\d+)_position(\d+)_time(\d+)_z(\d+)', 'tokens');
             if ~isempty(tokens)
                 tokens = tokens{1};
                 chStr = sprintf('%03d_z%03d', str2double(tokens{1}), str2double(tokens{4}));
                 matchIDs{f} = chStr;
             else
                 matchIDs{f} = '';
             end
         end
         mask = strcmp(matchIDs, channelID);
         channelsDir{c} = dirStruct(mask);
    end
    positions(i).channelsDir = channelsDir;
end

% Fusionner les positions en une seule si invert est true.
if invert
    nPos = numel(positions);
    % On part de la première position comme base
    mergedPos = positions(1);
    % Pour chaque canal, concaténer les structures de tous les positions
    for c = 1:numel(mergedPos.channels)
        mergedList = mergedPos.channelsDir{c};
        for p = 2:nPos
            if numel(positions(p).channels) >= c
                mergedList = [mergedList; positions(p).channelsDir{c}];
            end
        end
        mergedPos.channelsDir{c} = mergedList;
    end
    % Fusionner également la liste globale des fichiers
    mergedPos.files = {};
    for p = 1:nPos
        mergedPos.files = [mergedPos.files, positions(p).files];
    end
    % Remplacer le nom d'utilisateur par "AllPositions"
    mergedPos.userName = 'AllPositions';
    % Conserver le dossier de la première position
    mergedPos.folder = positions(1).folder;
    % Recalculer le champ frames pour chaque canal après stacking
    newFrames = zeros(1, numel(mergedPos.channelsDir));
    for c = 1:numel(mergedPos.channelsDir)
         newFrames(c) = numel(mergedPos.channelsDir{c});
    end
    mergedPos.frames = newFrames;
    positions = mergedPos;
end

if invert
    parsedData.numPositions = 1;
else
    parsedData.numPositions = numel(positions);
end

parsedData.positions = positions;
parsedData.roitype='full'; 
parsedData.roibb=[];
parsedData.roipattern=[];
parsedData.maxframeloading=20;
parsedData.correctdrift=false;
parsedData.maxroidisplay=10;
parsedData.allpositions=true;
parsedData.folder=folder; 
parsedData.advancedMode=false;
parsedData.projectPath=fullfile(parsedData.folder,'tmpProject.mat');


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
function [fileList, fileDir] = getFileList(folderPath)
    d = dir(folderPath);
    d = d(~[d.isdir]);  % Conserver uniquement les fichiers
    fileList = fullfile(folderPath, {d.name});
    fileDir = d;  % Renvoie directement le struct array
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
    info.frames = 1:numel(uniqueFrames);
    
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
                channelSizes{c} = sprintf('%d %d', width, height);
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
