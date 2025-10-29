function parsedData = loadData_parse(files, folder, invert)
% loadData_parse
%
% Version étendue et robuste:
%   - Dossiers / sous-dossiers (historique)
%   - Liste de fichiers simples (historique)
%   - Liste de multi-TIFFs tifffile.py, chacun = 1 position (NOUVEAU)
%   - Peut recevoir files en char, string, cellstr
%
% -------------------------------------------------------------------------

if nargin < 3
    invert = false;
end

% --- Normalisation de l'argument 'files' en cell array de char ---
if isempty(files)
    filesCell = {};
elseif ischar(files)
    filesCell = {files};
elseif isstring(files)
    tmp = cellstr(files(:)); % string -> cell colonne
    filesCell = tmp(:).';    % row
elseif iscell(files)
    filesCell = files;
else
    error('Argument "files" doit être char, string, cellstr ou vide.');
end
files = filesCell;

if isempty(files) && isequal(folder,0)
    parsedData = [];
    disp('Le chemin spécifié n''est pas un dossier valide, ou l''utilisateur a annulé.');
    return;
end

%% === BRANCHE A : Cas "files" non vide ET tous des multi-TIFF tifffile.py ? ===
if ~isempty(files)
    % chemins absolus
    fullPaths = cellfun(@(f) fullfile(folder,f), files, 'UniformOutput', false);

    isMulti = false(size(fullPaths));
    infoCache = cell(size(fullPaths));
    for k = 1:numel(fullPaths)
        [isMulti(k), infoCache{k}] = isMultiTiffFile(fullPaths{k});
    end

    if all(isMulti)
    % MODE multi-TIFF PAR POSITION
    posCells = cell(1, numel(fullPaths));
    for k = 1:numel(fullPaths)
        posCells{k} = buildPosFromMultiTiff(fullPaths{k}, infoCache{k}, k-1);
    end
    % Convertir cell -> struct array propre, avec union des champs
    positions = unifyStructArray(posCells);

    % Finaliser (channelsDir, invert, etc.)
    positions = finalizePositionsArray(positions, invert);

    % Construire parsedData global
    parsedData = finalizeParsedDataStruct(positions, folder, invert);
    return;
    end

end

%% === BRANCHE B : Cas historique (dossier ou fichiers standards) ===
d_local = [];
subDirs_local = [];

if isempty(files)
    % Cas : seulement un dossier -> scan
    d = dir(folder);
    d = d(~ismember({d.name}, {'.', '..'}));
    subDirs = d([d.isdir]);
    subDirs = subDirs(~strcmp({subDirs.name}, 'tmpProject'));

    if ~isempty(subDirs)
        numPositions = numel(subDirs);
        positions = [];  %#ok<NASGU>
        positions = [];  % init propre
        for i = 1:numPositions
            subfolderPath = fullfile(folder, subDirs(i).name);
            [fileList, fileDir] = getFileList(subfolderPath);
            posInfo = parseFileList(fileList, true);
            posInfo.folder = subfolderPath;
            posInfo.fileDir = fileDir;
            positions = [positions, posInfo]; %#ok<AGROW>
        end
    else
        [fileList, fileDir] = getFileList(folder);
        posInfo = parseFileList(fileList, true);
        posInfo.folder = folder;
        posInfo.fileDir = fileDir;
        positions = posInfo;
    end

    d_local = d;
    subDirs_local = subDirs;

else
    % Cas : liste de fichiers standards (pas multiTIFF global)
    fileList = cellfun(@(f) fullfile(folder, f), files, 'UniformOutput', false);
    fileDirCells = cellfun(@(f) dir(f), fileList, 'UniformOutput', false);
    fileDir = cell2mat(fileDirCells);

    posInfo = parseFileList(fileList, true);
    posInfo.folder = folder;
    posInfo.fileDir = fileDir;
    positions = posInfo;
end

% avertissement si dossiers + fichiers mélangés
if ~isempty(d_local)
    filesInFolder = d_local(~[d_local.isdir]);
    if ~isempty(subDirs_local) && ~isempty(filesInFolder)
        disp('Des fichiers sont présents au même niveau que les sous-dossiers, ils seront ignorés.');
    end
end

% Finaliser (minFrame/maxFrame, userName, channelsDir, merge invert)
positions = finalizePositionsArray(positions, invert);

% Construire parsedData global
parsedData = finalizeParsedDataStruct(positions, folder, invert);

end % ===== fin loadData_parse =====


%% ===== Helper: détecter si un fichier est un multi-TIFF tifffile.py exploitable
function [tf, infoTif] = isMultiTiffFile(fullpath)
    tf = false;
    infoTif = [];
    if ~isfile(fullpath)
        return;
    end
    [~,~,ext] = fileparts(fullpath);
    if ~any(strcmpi(ext,{'.tif','.tiff'}))
        return;
    end

    try
        infoTif = imfinfo(fullpath);
    catch
        return;
    end

    if numel(infoTif) < 2
        return;
    end
    if ~isfield(infoTif(1),'ImageDescription') || isempty(infoTif(1).ImageDescription)
        return;
    end

    shapeOK = regexp(infoTif(1).ImageDescription, '\{\s*"shape"\s*:\s*\[', 'once');
    if isempty(shapeOK)
        return;
    end

    tf = true;
end


%% ===== Helper: construit UNE position à partir d'un multi-TIFF
function posInfo = buildPosFromMultiTiff(tiffFile, infoTif, posIdxForName)
    % Lire shape [T C H W]
    shapeStr = infoTif(1).ImageDescription;
    shapeNums = regexp(shapeStr, '\[([\d\s,]+)\]', 'tokens', 'once');
    if isempty(shapeNums)
        error('Impossible de parser "shape" dans %s', tiffFile);
    end
    nums = regexp(shapeNums{1}, '\d+', 'match');
    nums = str2double(nums);
    if numel(nums) < 4
        error('Le champ "shape" ne ressemble pas à [T,C,H,W] dans %s', tiffFile);
    end

    T = nums(1); % timepoints
    C = nums(2); % channels
    nPages = numel(infoTif);

    if T*C ~= nPages
        warning('Attention: T*C ~= nPages dans %s. On continue.', tiffFile);
    end

    % Construire les noms virtuels (un par page)
    [folderPath, baseName, ~] = fileparts(tiffFile);

    virtFileList = cell(1, nPages);
    fileDir      = repmat(struct('name','','folder','','bytes',NaN,'datenum',NaN), 1, nPages);

    for k = 1:nPages
        chID = mod(k-1, C);        % canal (0..C-1)
        tID  = floor((k-1)/C);     % time index (0..T-1)
        zID  = 0;
        pID  = 0;                  % une seule position interne dans ce TIFF

        virtName = sprintf('%s_channel%03d_position%03d_time%09d_z%03d.tif', ...
            baseName, chID, pID, tID, zID);
        virtFull = fullfile(folderPath, virtName);

        virtFileList{k} = virtFull;

        [~, onlyName, onlyExt] = fileparts(virtFull);
        fileDir(k).name   = [onlyName onlyExt];
        fileDir(k).folder = folderPath;

        if isfield(infoTif(k),'FileSize')
            fileDir(k).bytes = infoTif(k).FileSize;
        else
            fileDir(k).bytes = NaN;
        end
        if isfield(infoTif(k),'FileModDate')
            try
                fileDir(k).datenum = datenum(infoTif(k).FileModDate);
            catch
                fileDir(k).datenum = now;
            end
        else
            fileDir(k).datenum = now;
        end
    end

 % Parser les noms virtuels -> frames, channels, etc.
    posInfo = parseVirtualFileList(virtFileList, fileDir, infoTif);

    % --- Ajouts spécifiques multi-TIFF ---
    posInfo.isMultiTiff    = true;
    posInfo.tiffSource     = tiffFile;
    % On garde l'index de page pour chaque "fichier virtuel"
    % Ici, virtFileList{k} correspond à la page k du TIFF.
    posInfo.pageIndexPerFile = 1:numel(infoTif);

    % Champs attendus par l'appli
    posInfo.folder     = folderPath;
    posInfo.fileDir    = fileDir;
    posInfo.selected   = true;
    posInfo.roibb      = [];
    posInfo.extractROI = true;
    posInfo.userName   = sprintf('Pos%d', posIdxForName);

    if ~isempty(posInfo.frames)
        posInfo.minFrame = min(posInfo.frames);
        posInfo.maxFrame = max(posInfo.frames);
    else
        posInfo.minFrame = NaN;
        posInfo.maxFrame = NaN;
    end
end


%% ===== Helper: finalise un array de positions (ajoute channelsDir, gère invert)
function positionsOut = finalizePositionsArray(positionsIn, invert)

    positions = positionsIn;

    % 1. channelsDir pour chaque position si pas déjà présent
    for i = 1:numel(positions)
        if ~isfield(positions(i),'channelsDir') || isempty(positions(i).channelsDir)
            channelsDir = cell(1, numel(positions(i).channels));
            for c = 1:numel(positions(i).channels)
                channelID = positions(i).channels{c};  % ex '000_z000'
                filesPos  = positions(i).files;
                dirStruct = positions(i).fileDir;
                matchIDs = cell(size(filesPos));
                for f = 1:length(filesPos)
                    tokens = regexp(filesPos{f}, ...
                        '.*_channel(\d+)_position(\d+)_time(\d+)_z(\d+)', ...
                        'tokens');
                    if ~isempty(tokens)
                        tokens = tokens{1};
                        chStr = sprintf('%03d_z%03d', ...
                            str2double(tokens{1}), ...
                            str2double(tokens{4}));
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
    end

    % 2. userName, selected, roibb, extractROI, min/maxFrame si manquants
    for i = 1:numel(positions)
        if ~isfield(positions(i),'userName') || isempty(positions(i).userName)
            if isfield(positions(i),'folder') && ~isempty(positions(i).folder)
                folderPath_i = positions(i).folder;
                if folderPath_i(end)==filesep || folderPath_i(end)=='/'
                    folderPath_i = folderPath_i(1:end-1);
                end
                idx = find(folderPath_i==filesep | folderPath_i=='/', 1, 'last');
                if isempty(idx)
                    posName = folderPath_i;
                else
                    posName = folderPath_i(idx+1:end);
                end
                positions(i).userName = posName;
            else
                positions(i).userName = sprintf('Pos%d', i-1);
            end
        end

        if ~isfield(positions(i),'selected'),   positions(i).selected   = true; end
        if ~isfield(positions(i),'roibb'),      positions(i).roibb      = [];   end
        if ~isfield(positions(i),'extractROI'), positions(i).extractROI = true; end

        if ~isfield(positions(i),'minFrame') || ~isfield(positions(i),'maxFrame')
            if ~isempty(positions(i).frames)
                positions(i).minFrame = min(positions(i).frames);
                positions(i).maxFrame = max(positions(i).frames);
            else
                positions(i).minFrame = NaN;
                positions(i).maxFrame = NaN;
            end
        end
    end

    % 3. invert -> fusionner toutes les positions en une seule
    if invert && numel(positions) > 1
        mergedPos = positions(1);

        % Fusion channelsDir
        for c = 1:numel(mergedPos.channels)
            mergedList = mergedPos.channelsDir{c};
            for p = 2:numel(positions)
                if numel(positions(p).channels) >= c
                    mergedList = [mergedList; positions(p).channelsDir{c}]; %#ok<AGROW>
                end
            end
            mergedPos.channelsDir{c} = mergedList;
        end

        % Fusion des listes virtuelles de fichiers
        mergedPos.files = {};
        for p = 1:numel(positions)
            mergedPos.files = [mergedPos.files, positions(p).files]; %#ok<AGROW>
        end

        mergedPos.userName = 'AllPositions';

        if isfield(positions(1),'folder')
            mergedPos.folder = positions(1).folder;
        else
            mergedPos.folder = '';
        end

        newFrames = zeros(1, numel(mergedPos.channelsDir));
        for c = 1:numel(mergedPos.channelsDir)
            newFrames(c) = numel(mergedPos.channelsDir{c});
        end
        mergedPos.frames   = newFrames;
        mergedPos.minFrame = min(newFrames);
        mergedPos.maxFrame = max(newFrames);

        positionsOut = mergedPos;
    else
        positionsOut = positions;
    end
end


%% ===== Helper: finalise parsedData
function parsedData = finalizeParsedDataStruct(positions, folder, invert)
    if invert
        numPos = 1;
    else
        numPos = numel(positions);
    end

    parsedData.positions        = positions;
    parsedData.numPositions     = numPos;

    parsedData.roitype          = 'full';
    parsedData.roibb            = [];
    parsedData.roipattern       = [];
    parsedData.maxframeloading  = 20;
    parsedData.scale            = 1;
    parsedData.correctdrift     = false;
    parsedData.maxroidisplay    = 10;
    parsedData.allpositions     = true;

    parsedData.folder           = folder;
    parsedData.advancedMode     = false;
    parsedData.projectPath      = fullfile(parsedData.folder,'tmpProject.mat');

    globalFrames = [];
    for i = 1:numel(positions)
        if isfield(positions(i),'frames') && ~isempty(positions(i).frames)
            globalFrames = [globalFrames; positions(i).frames(:)]; %#ok<AGROW>
        end
    end
    if ~isempty(globalFrames)
        parsedData.minFrame = min(globalFrames);
        parsedData.maxFrame = max(globalFrames);
    else
        parsedData.minFrame = NaN;
        parsedData.maxFrame = NaN;
    end
    parsedData.currentMinFrame = parsedData.minFrame;
    parsedData.currentMaxFrame = parsedData.maxFrame;
end


%% ===== Helper: getFileList (historique)
function [fileList, fileDir] = getFileList(folderPath)
    d = dir(folderPath);
    d = d(~[d.isdir]);
    fileList = fullfile(folderPath, {d.name});
    fileDir = d;
end


%% ===== Helper: parseFileList (historique)
function info = parseFileList(fileList, forceSinglePosition)
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
        tokens = regexp(fileName, '.*_channel(\d+)_position(\d+)_time(\d+)_z(\d+)', 'tokens');
        if ~isempty(tokens)
            tokens = tokens{1};
            chVal   = str2double(tokens{1});
            posVal  = str2double(tokens{2});
            timeVal = str2double(tokens{3});
            zVal    = str2double(tokens{4});

            channelsArr(end+1) = chVal;
            posArr(end+1)      = posVal;
            times(end+1)       = timeVal;
            zArr(end+1)        = zVal;
        else
            continue;
        end
    end

    if isempty(times)
        info.numFrames          = 0;
        info.frames             = [];
        info.numChannels        = 0;
        info.channels           = {};
        info.channelFrequencies = [];
        info.channelSizes       = {};
        info.channelsSelected   = [];
        info.userChanName       = {};
        if forceSinglePosition
            info.numPositions = 1;
            info.positions    = 1;
        else
            info.numPositions = 0;
            info.positions    = [];
        end
        info.files = fileList;
        return;
    end

    uniqueFrames   = unique(times);
    info.numFrames = numel(uniqueFrames);
    info.frames    = 1:numel(uniqueFrames);

    ch_z = arrayfun(@(c,z) sprintf('%03d_z%03d', c, z), channelsArr, zArr, 'UniformOutput', false);
    uniqueCh = unique(ch_z);
    info.numChannels = numel(uniqueCh);
    info.channels    = uniqueCh;

    channelFrequencies = zeros(1, info.numChannels);
    channelSizes       = cell(1, info.numChannels);

    for c = 1:info.numChannels
        idx = find(strcmp(ch_z, uniqueCh{c}));
        channelTimes = sort(times(idx));
        if numel(channelTimes) > 1
            diffs = diff(channelTimes);
            channelFrequencies(c) = median(diffs);
        else
            channelFrequencies(c) = 1;
        end

        firstIdx        = idx(1);
        fileForChannel  = fileList{firstIdx};
        [~, ~, extFile] = fileparts(fileForChannel);
        try
            if strcmpi(extFile, '.tif') || strcmpi(extFile, '.tiff')
                infoTif_local = imfinfo(fileForChannel);
                width         = infoTif_local(1).Width;
                height        = infoTif_local(1).Height;
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
    info.channelSizes       = channelSizes;

    info.channelsSelected = true(1, info.numChannels);
    info.userChanName     = cell(1, info.numChannels);
    for j = 1:info.numChannels
        info.userChanName{j} = ['Channel' num2str(j-1)];
    end

    if forceSinglePosition
        info.numPositions = 1;
        info.positions    = 1;
    else
        uniquePos = unique(posArr);
        info.numPositions = numel(uniquePos);
        info.positions    = uniquePos;
    end

    info.files = fileList;
end


%% ===== Helper: parseVirtualFileList (multi-TIFF)
function info = parseVirtualFileList(virtFileList, fileDir, infoTif)
    times = [];
    channelsArr = [];
    posArr = [];
    zArr = [];

    for i = 1:length(virtFileList)
        [~, name, ext] = fileparts(virtFileList{i});
        fileName = [name, ext];

        toks = regexp(fileName, ...
            '.*_channel(\d+)_position(\d+)_time(\d+)_z(\d+)', ...
            'tokens');

        if ~isempty(toks)
            toks = toks{1};
            chVal   = str2double(toks{1});
            posVal  = str2double(toks{2});
            timeVal = str2double(toks{3});
            zVal    = str2double(toks{4});

            channelsArr(end+1) = chVal;
            posArr(end+1)      = posVal;
            times(end+1)       = timeVal;
            zArr(end+1)        = zVal;
        end
    end

    if isempty(times)
        info.numFrames          = 0;
        info.frames             = [];
        info.numChannels        = 0;
        info.channels           = {};
        info.channelFrequencies = [];
        info.channelSizes       = {};
        info.channelsSelected   = [];
        info.userChanName       = {};
        info.numPositions       = 0;
        info.positions          = [];
        info.files              = virtFileList;
        return;
    end

    uniqueFrames   = unique(times);
    info.numFrames = numel(uniqueFrames);
    info.frames    = 1:numel(uniqueFrames); % renumérotation 1..N

    ch_z = arrayfun(@(c,z) sprintf('%03d_z%03d', c, z), channelsArr, zArr, ...
        'UniformOutput', false);
    uniqueCh = unique(ch_z);
    info.numChannels = numel(uniqueCh);
    info.channels    = uniqueCh;

    channelFrequencies = zeros(1, info.numChannels);
    channelSizes       = cell(1, info.numChannels);

    for c = 1:info.numChannels
        idx = find(strcmp(ch_z, uniqueCh{c}));
        channelTimes = sort(times(idx));
        if numel(channelTimes) > 1
            diffs = diff(channelTimes);
            channelFrequencies(c) = median(diffs);
        else
            channelFrequencies(c) = 1;
        end

        firstIdx = idx(1);
        w = infoTif(firstIdx).Width;
        h = infoTif(firstIdx).Height;
        channelSizes{c} = sprintf('%d %d', w, h);
    end

    info.channelFrequencies = channelFrequencies;
    info.channelSizes       = channelSizes;

    info.channelsSelected = true(1, info.numChannels);
    info.userChanName     = cell(1, info.numChannels);
    for j = 1:info.numChannels
        info.userChanName{j} = ['Channel' num2str(j-1)];
    end

    uniquePos = unique(posArr);
    info.numPositions = numel(uniquePos);
    info.positions    = uniquePos;

    info.files = virtFileList;
end

function S = unifyStructArray(Scell)
% unifyStructArray
% Prend une cell array de structs éventuellement hétérogènes (pas les mêmes champs)
% et renvoie un struct array homogène (tous les structs ont les mêmes champs).
%
% Règle : si un champ manque dans un élément, il est ajouté avec [].

    if isempty(Scell)
        S = struct([]);
        return;
    end

    % 1. construire la liste union de tous les champs
    allFields = {};
    for i = 1:numel(Scell)
        allFields = union(allFields, fieldnames(Scell{i}));
    end

    % 2. construire la sortie
    S = repmat(cell2struct(cell(size(allFields)), allFields, 1), 1, numel(Scell));

    % 3. remplir champ par champ
    for i = 1:numel(Scell)
        fcur = fieldnames(Scell{i});
        for f = 1:numel(fcur)
            fname = fcur{f};
            S(i).(fname) = Scell{i}.(fname);
        end
        % les champs manquants restent []
    end
end
