function shallowSave(shallowObj, option, progress)
% Sauvegarde le projet shallowObj et ses dépendances.
% - Sauve ROIs, classifieurs, processors (sauf si option 'shallowObj')
% - Écriture atomique du .mat avec vérification
% - Conserve un unique backup (.bak) correspondant à l'ancienne version

    % ====== Préparation des chemins ======
    [path, file] = shallowObj.getPath;
    shallowObjOnly = nargin >= 2 && strcmp(option, 'shallowObj');

    projectName   = file;
    projectTarget = fullfile(path, [file '.mat']);
    backupFile    = fullfile(path, [file '.bak']); % unique backup à la racine
    nFovTotal     = numel(shallowObj.fov);

    % ====== HEADER ======
    fprintf('\n============================================\n');
    fprintf(' Saving shallow project\n');
    fprintf('   Name    : %s\n', projectName);
    fprintf('   Tag     : %s\n', shallowObj.tag);
    fprintf('   Target  : %s\n', projectTarget);
    fprintf('   #FOV(s) : %d\n', nFovTotal);
    fprintf('============================================\n\n');

    % ====== 1) Sauvegarde FOV / ROI ======
    if ~shallowObjOnly
        for i = 1:nFovTotal
            if nargin == 3
                progress.Message = sprintf('Saving position %d / %d ...', i, nFovTotal);
                progress.Value   = i ./ nFovTotal;
                pause(0.01);
            end

            nRoiTotal = numel(shallowObj.fov(i).roi);
            nRoiSaved = 0;

            for j = 1:nRoiTotal
                roiObj = shallowObj.fov(i).roi(j);
                try
                    didSave = roiObj.save([], false);
                catch
                    roiObj.save(); % rétrocompatibilité
                    didSave = true;
                end
                if didSave
                    nRoiSaved = nRoiSaved + 1;
                end
                roiObj.clear;
            end

            fprintf('FOV %d/%d: saved %d/%d ROIs.\n', i, nFovTotal, nRoiSaved, nRoiTotal);
        end

        % ====== 2) Classifieurs ======
        nClassif = numel(shallowObj.processing.classification);
        if nClassif > 0, fprintf('\nSaving %d classifier(s)...\n', nClassif); end
        for i = 1:nClassif
            if nargin == 3
                progress.Message = sprintf('Saving classifier %d / %d ...', i, nClassif);
                progress.Value   = i ./ nClassif;
                pause(0.01);
            end
            classiSave(shallowObj.processing.classification(i));
        end

        % ====== 3) Processors ======
        nProc = numel(shallowObj.processing.processor);
        if nProc > 0, fprintf('Saving %d processor(s)...\n', nProc); end
        for i = 1:nProc
            if nargin == 3
                progress.Message = sprintf('Saving processor %d / %d ...', i, nProc);
                progress.Value   = i ./ nProc;
                pause(0.01);
            end
            processSave(shallowObj.processing.processor(i));
        end
    end

        % ====== 4) Pipelines ======
        nPipe = numel(shallowObj.processing.pipeline);
        if nPipe > 0, fprintf('Saving %d pipeline(s)...\n', nPipe); end
        for i = 1:nPipe
            try
                pipelineSave(shallowObj.processing.pipeline(i));
            catch ME
                warning('pipelineSave failed: %s', ME.message);
            end
        end


    % ====== 5) Sauvegarde atomique + v?rif + backup .bak ======
    fprintf('\n--------------------------------------------\n');
    fprintf('[INFO] Writing project MAT (atomic write)...\n');

    tmpUuid   = char(java.util.UUID.randomUUID);
    tmpTarget = [projectTarget '.tmp.' tmpUuid];

    % 4.a) Écriture vers un fichier temporaire
    try
        save(tmpTarget, 'shallowObj', '-v7.3');
        fprintf('[OK]   Temp file written: %s\n', tmpTarget);
    catch ME
        fprintf(2, '[ERR]  Failed to write temp MAT: %s\n', ME.message);
        if exist(tmpTarget, 'file'); delete(tmpTarget); end
        fprintf('--------------------------------------------\n\n');
        return;
    end

    % 4.b) Vérification du .mat temporaire
    if ~localVerifyMat(tmpTarget)
        fprintf(2, '[ERR]  Temp MAT verification failed. Aborting.\n');
        if exist(tmpTarget, 'file'); delete(tmpTarget); end
        fprintf('--------------------------------------------\n\n');
        return;
    else
        fprintf('[OK]   Temp MAT verification passed.\n');
    end

    % 4.c) Sauvegarde de l'ancien fichier en .bak
    try
        if exist(projectTarget, 'file')
            copyfile(projectTarget, backupFile, 'f');
            if localVerifyMat(backupFile)
                fprintf('[OK]   Previous version backed up: %s\n', backupFile);
            else
                fprintf(2, '[WARN] Backup verification failed: %s\n', backupFile);
            end
        else
            fprintf('[INFO] No previous MAT to backup.\n');
        end
    catch ME
        fprintf(2, '[WARN] Failed to create backup: %s\n', ME.message);
    end

    % 4.d) Remplacement du fichier principal
    try
        if exist(projectTarget, 'file'), delete(projectTarget); end
        movefile(tmpTarget, projectTarget, 'f');
        fprintf('[OK]   New MAT moved into place: %s\n', projectTarget);
    catch ME
        fprintf(2, '[ERR]  Failed to move new MAT into place: %s\n', ME.message);
        if exist(tmpTarget, 'file'); delete(tmpTarget); end
        fprintf('--------------------------------------------\n\n');
        return;
    end

    % 4.e) Vérification finale
    if ~localVerifyMat(projectTarget)
        fprintf(2, '[WARN] Final MAT verification failed. File may be corrupted.\n');
    else
        fprintf('[OK]   Final MAT verification passed.\n');
    end

    fprintf(' ✅ Shallow project successfully saved.\n');
    fprintf('   -> %s\n', projectTarget);
    fprintf('   .bak -> previous version: %s\n', backupFile);
    fprintf('--------------------------------------------\n\n');
end

function ok = localVerifyMat(matPath)
    ok = false;
    try
        vars = whos('-file', matPath);
        ok   = ~isempty(vars);
    catch
        ok = false;
    end
end
