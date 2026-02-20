function img = loadData_readFrameFromParsed(posData, channelIndex, frameIndex)
% readFrameFromParsed
% Retourne l'image (matrice) correspondant à:
%   - cette position (posData)
%   - ce canal (channelIndex, 1-based)
%   - cette frame temporelle demandée (frameIndex, 1-based dans ton slider logique après freq)
%
% Gère deux cas :
%   A) mode classique : chaque frame = vrai fichier sur disque
%   B) mode multi-TIFF : frames virtuelles -> pages d'un tiffSource

    % --- sécurités basiques ---
    if channelIndex > numel(posData.channelsDir)
        error('channelIndex %d out of range for this position', channelIndex);
    end

    channelFiles = posData.channelsDir{channelIndex};
    if isempty(channelFiles)
        error('No files for this channel.');
    end

    % clamp frameIndex dans [1 .. numImagesInThisChannel]
    frameIndex = max(1, min(frameIndex, numel(channelFiles)));

    thisFileStruct = channelFiles(frameIndex); % struct style dir
    fakeName = fullfile(thisFileStruct.folder, thisFileStruct.name);

    % Cas multi-TIFF simulé ?
    if isfield(posData,'isMultiTiff') && posData.isMultiTiff
        % On doit lire la bonne "page" du gros TIFF
        %
        % Attention: posData.files et posData.pageIndexPerFile
        % sont alignés dans l'ordre global des frames VIRTUELLES,
        % mais channelFiles est un sous-ensemble filtré par canal.
        %
        % On doit retrouver l'index global (dans posData.files) qui
        % correspond à fakeName, puis en déduire la page.
        [~, fakeBase, fakeExt] = fileparts(fakeName);
        fullFakeShort = [fakeBase fakeExt];

        % posData.files contient les noms virtuels complets (chemin + nom)
        % On doit retrouver l'indice global du frame virtuel
        matchIdx = [];
        for k = 1:numel(posData.files)
            [~, b, e] = fileparts(posData.files{k});
            if strcmpi([b e], fullFakeShort)
                matchIdx = k;
                break;
            end
        end
        if isempty(matchIdx)
            error('Internal mapping error: cannot find virtual file in posData.files');
        end

        % La page TIFF correspondante :
        pageToRead = posData.pageIndexPerFile(matchIdx);

        % Lecture directe de cette page du TIFF source
        img = imread(posData.tiffSource, pageToRead);

    else
        % Cas classique : on lit le fichier réellement présent
        img = imread(fakeName);
    end
end
