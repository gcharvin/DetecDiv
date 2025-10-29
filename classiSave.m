function classiSave(classiObj)
% classiSave  Sauvegarde un objet classification (classiObj)
% - Sauvegarde toutes les ROI associées (en silencieux)
% - Affiche un résumé (#ROIs sauvegardées)
% - Sauvegarde l'objet classiObj lui-même sur disque

    % Récupérer chemin et nom de base pour l'export
    [path, file] = classiObj.getPath;
    targetFile   = fullfile(path, [file '_classification.mat']);

    % Récupérer un nom humain pour affichage
    if isprop(classiObj,'strid') && ~isempty(classiObj.strid)
        classiName = classiObj.strid;
    elseif isprop(classiObj,'id')
        classiName = ['classi_' num2str(classiObj.id)];
    else
        classiName = file;
    end

    % Combien de ROI à traiter ?
    nRoiTotal = numel(classiObj.roi);

    % ===== HEADER =====
    fprintf('\n--------------------------------------------\n');
    fprintf(' Saving classification object\n');
    fprintf('   Name         : %s\n', classiName);
    fprintf('   Target       : %s\n', targetFile);
    fprintf('   #ROI(s)      : %d\n', nRoiTotal);
    fprintf('--------------------------------------------\n');

    % ===== SAUVEGARDE DES ROI =====
    nRoiActuallySaved = 0;

    for j = 1:nRoiTotal

        thisROI = classiObj.roi(j);

        % skip ROI invalides / vides
        if isempty(thisROI) || ~isprop(thisROI,'id') || isempty(thisROI.id)
            continue;
        end

        % on essaye la nouvelle API silencieuse [didSave = save([],false)]
        try
            didSave = thisROI.save([], false);
        catch
            % rétrocompat si ancienne signature sans verbose/output
            thisROI.save();
            didSave = true;
        end

        if didSave
            nRoiActuallySaved = nRoiActuallySaved + 1;
        end

        % libère la mémoire image associée à la ROI après sauvegarde
        thisROI.clear;
    end

    % petit résumé global pour cette classification
    fprintf(' Classification "%s": saved %d/%d ROI(s).\n', ...
            classiName, nRoiActuallySaved, nRoiTotal);

    % ===== LOG / SAUVEGARDE DE L'OBJET LUI-MÊME =====
    % noter dans le journal interne
    classiObj.log('Classi is saved','Creation');

    if isfolder(path)
        save(targetFile, 'classiObj');
        fprintf(' ✅ Classification object saved to: %s\n', targetFile);
    else
        fprintf(' ❌ ERROR: Could not access folder "%s". Check your connection. Aborting classification save.\n', path);
    end

    fprintf('--------------------------------------------\n\n');
end
