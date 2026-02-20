function [h5File, info] = findExistingFramebank(baseFB)
%FINDEXISTINGFRAMEBANK  Trouve un framebank HDF5 "valide" à partir d'un tronc de nom.
%
%   [h5File, info] = findExistingFramebank(baseFB)
%
%   baseFB : chemin SANS extension, typiquement
%            fullfile(path, [classif.strid '_framebank'])
%
%   h5File : chemin complet du framebank choisi ('' si aucun)
%   info   : struct retournée par h5info pour ce fichier ( [] si aucun )

    h5File = '';
    info   = [];

    if nargin < 1 || isempty(baseFB)
        warning('findExistingFramebank:emptyInput', ...
            'baseFB is empty. No framebank to search.');
        return;
    end

    [folder, base, ~] = fileparts(baseFB);

    if isempty(folder)
        folder = pwd;
    end

    % On cherche tous les fichiers du type viterbi_1_framebank*.h5
    pattern = sprintf('%s*.h5', base);
    files = dir(fullfile(folder, pattern));

    if isempty(files)
        fprintf('findExistingFramebank: aucun fichier %s trouvé dans %s\n', ...
            pattern, folder);
        return;
    end

    % Trier par date décroissante -> le plus récent en premier
    [~, idx] = sort([files.datenum], 'descend');
    files = files(idx);

    % Boucle sur les candidats, on prend le premier qui s'ouvre vraiment
    for k = 1:numel(files)
        candPath = fullfile(folder, files(k).name);

        fprintf('findExistingFramebank: test du candidat %s\n', candPath);

        try
            infoTmp = h5info(candPath);  %#ok<HDF5HINFO>

            % Ici on pourrait ajouter des checks plus spécifiques,
            % par ex. présence d'un dataset particulier.
            % Pour l'instant, si h5info passe, on considère que c'est OK.

            h5File = candPath;
            info   = infoTmp;

            fprintf('findExistingFramebank: utilisation de %s\n', h5File);
            return;
        catch ME
            warning('findExistingFramebank:invalidFile', ...
                'Impossible d''ouvrir le framebank %s (%s). Candidat suivant...', ...
                candPath, ME.message);
        end
    end

    % Si on arrive ici, aucun fichier n'a été utilisable
    warning('findExistingFramebank:noValidFile', ...
        'Aucun framebank HDF5 utilisable trouvé pour la base "%s".', baseFB);
end
