function shallowSave(shallowObj, option, progress)
% Sauvegarde le projet shallowObj et ses dépendances.
% - Sauve toutes les ROI (images+data si dispo), classifications et processors
% - Donne un résumé par FOV : combien de ROIs ont vraiment été écrites sur disque
% - Affiche un en-tête avec les infos projet

    % Récupérer chemin + nom du projet
    [path, file] = shallowObj.getPath;

    % Mode "shallowObj only" = on ne sauvegarde pas les ROIs/classif/etc.,
    % juste l'objet global .mat
    shallowObjOnly = 0;
    if nargin >= 2 && strcmp(option,'shallowObj')
        shallowObjOnly = 1;
    end

    % Infos projet pour le header
    projectName   = file;  % typiquement le nom du .mat sans extension
    projectTarget = fullfile(path, [file '.mat']);
    nFovTotal     = numel(shallowObj.fov);

    % ====== HEADER / CONTEXTE ======
    fprintf('\n============================================\n');
    fprintf(' Saving shallow project\n');
    fprintf('   Name    : %s\n', projectName);
    fprintf('   Tag     : %s\n', shallowObj.tag);
    fprintf('   Target  : %s\n', projectTarget);
    fprintf('   #FOV(s) : %d\n', nFovTotal);
    fprintf('============================================\n\n');

    % ====== 1) Sauvegarde des FOV / ROI ======
    if shallowObjOnly == 0

        for i = 1:nFovTotal

            % Mettre à jour la barre de progression dans l'UI si on l'a reçue
            if nargin == 3
                progress.Message = sprintf('Saving position %d / %d ...', i, nFovTotal);
                progress.Value   = i ./ nFovTotal;
                pause(0.01);
            end

            % Compteurs ROIs pour ce FOV
            nRoiTotal = numel(shallowObj.fov(i).roi);
            nRoiSaved = 0;

            for j = 1:nRoiTotal
                roiObj = shallowObj.fov(i).roi(j);

                % Appel silencieux : pas de spam par ROI
                % didSave = true si quelque chose a effectivement été écrit
                try
                    didSave = roiObj.save([], false);
                catch
                    % rétrocompatibilité si ancienne version de roi.save()
                    roiObj.save();
                    didSave = true; % hypothèse "ancienne version sauvait vraiment"
                end

                if didSave
                    nRoiSaved = nRoiSaved + 1;
                end

                % Libérer l'image après sauvegarde pour ne pas garder ça en RAM
                roiObj.clear;
            end

            % Résumé lisible pour CE FOV uniquement
            fprintf('FOV %d/%d: saved %d/%d ROIs.\n', ...
                    i, nFovTotal, nRoiSaved, nRoiTotal);
        end

        % ====== 2) Sauvegarde des classifieurs ======
        nClassif = numel(shallowObj.processing.classification);
        if nClassif > 0
            fprintf('\nSaving %d classifier(s)...\n', nClassif);
        end
        for i = 1:nClassif
            if nargin == 3
                progress.Message = sprintf('Saving classifier %d / %d ...', i, nClassif);
                progress.Value   = i ./ nClassif;
                pause(0.01);
            end
            classiSave(shallowObj.processing.classification(i));
        end

        % ====== 3) Sauvegarde des processors ======
        nProc = numel(shallowObj.processing.processor);
        if nProc > 0
            fprintf('Saving %d processor(s)...\n', nProc);
        end
        for i = 1:nProc
            if nargin == 3
                progress.Message = sprintf('Saving processor %d / %d ...', i, nProc);
                progress.Value   = i ./ nProc;
                pause(0.01);
            end
            processSave(shallowObj.processing.processor(i));
        end
    end

    % ====== 4) Sauvegarde finale de l'objet shallow ======
    save(projectTarget, 'shallowObj');

    fprintf('\n--------------------------------------------\n');
    fprintf(' ✅ Shallow project successfully saved.\n');
    fprintf('   -> %s\n', projectTarget);
    fprintf('--------------------------------------------\n\n');
end
