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

        % ====== 4) Pipeline runs ======
        nRun = 0;
        if isfield(shallowObj.processing,'pipelineRun')
            nRun = numel(shallowObj.processing.pipelineRun);
        end
        if nRun > 0, fprintf('Saving %d pipeline run(s)...\n', nRun); end
        for i = 1:nRun
            try
                pipelineRunSave(shallowObj.processing.pipelineRun(i));
            catch ME
                warning('pipeline run save failed: %s', ME.message);
            end
        end
        % Pipeline templates are independent objects and are not persisted in shallowObj.


    % ====== 5) Sauvegarde atomique + v?rif + backup .bak ======
    fprintf('\n--------------------------------------------\n');
    fprintf('[INFO] Writing project MAT (atomic write)...\n');
    localSetProgress(progress, 0.82, 'Preparing lightweight project view...');

    tmpUuid   = char(java.util.UUID.randomUUID);
    tmpTarget = [projectTarget '.tmp.' tmpUuid];
    cleanupSaveView = localPrepareLightProjectForMat(shallowObj);

    % 4.a) Écriture vers un fichier temporaire
    try
        localSetProgress(progress, 0.86, 'Writing project MAT file...');
        save(tmpTarget, 'shallowObj', '-v7.3');
        fprintf('[OK]   Temp file written: %s\n', tmpTarget);
    catch ME
        delete(cleanupSaveView);
        fprintf(2, '[ERR]  Failed to write temp MAT: %s\n', ME.message);
        if exist(tmpTarget, 'file'); delete(tmpTarget); end
        fprintf('--------------------------------------------\n\n');
        return;
    end

    % 4.b) Vérification du .mat temporaire
    delete(cleanupSaveView);

    localSetProgress(progress, 0.91, 'Verifying project MAT file...');
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
        localSetProgress(progress, 0.94, 'Backing up previous project file...');
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
        localSetProgress(progress, 0.97, 'Installing new project file...');
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
    localSetProgress(progress, 0.99, 'Final project verification...');
    if ~localVerifyMat(projectTarget)
        fprintf(2, '[WARN] Final MAT verification failed. File may be corrupted.\n');
    else
        fprintf('[OK]   Final MAT verification passed.\n');
    end

    fprintf(' ✅ Shallow project successfully saved.\n');
    fprintf('   -> %s\n', projectTarget);
    fprintf('   .bak -> previous version: %s\n', backupFile);
    fprintf('--------------------------------------------\n\n');
    localSetProgress(progress, 1.0, 'Project saved.');
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

function localSetProgress(progress, value, message)
    if nargin < 1 || isempty(progress)
        return;
    end
    try
        if nargin >= 2 && ~isempty(value)
            progress.Value = max(0, min(1, value));
        end
        if nargin >= 3 && ~isempty(message)
            progress.Message = message;
        end
        drawnow limitrate;
    catch
    end
end

function cleanupObj = localPrepareLightProjectForMat(shallowObj)
% Temporarily strip cached/heavy runtime data before serializing the project.
% The onCleanup restores the live handle object immediately after save().

    state = struct();

    state.hasParsedData = isprop(shallowObj, 'parsedData');
    state.parsedData = [];
    if state.hasParsedData
        state.parsedData = shallowObj.parsedData;
        shallowObj.parsedData = localCompactParsedData(shallowObj.parsedData);
    end

    state.processing = shallowObj.processing;
    shallowObj.processing = localCompactProcessing(shallowObj.processing);

    nFov = numel(shallowObj.fov);
    state.fovParent = cell(1, nFov);
    state.fovSrclist = {};
    state.roiImage = {};
    state.roiData = {};
    state.roiHistory = {};
    state.roiResults = {};
    state.roiTrain = {};
    state.roiProc = {};
    state.roiClasses = {};

    for iFov = 1:nFov
        try
            state.fovParent{iFov} = shallowObj.fov(iFov).parent;
            shallowObj.fov(iFov).parent = [];
        catch
            state.fovParent{iFov} = [];
        end

        if localCanCompactSrclist(shallowObj.fov(iFov))
            try
                state.fovSrclist(end+1, :) = {iFov, shallowObj.fov(iFov).srclist}; %#ok<AGROW>
                shallowObj.fov(iFov).srclist = {};
            catch
            end
        end

        nRoi = numel(shallowObj.fov(iFov).roi);
        for iRoi = 1:nRoi
            r = shallowObj.fov(iFov).roi(iRoi);

            state.roiImage(end+1, :) = {iFov, iRoi, r.image}; %#ok<AGROW>
            state.roiData(end+1, :) = {iFov, iRoi, r.data}; %#ok<AGROW>
            r.image = [];
            r.data = dataseries.empty;

            if isprop(r, 'history')
                state.roiHistory(end+1, :) = {iFov, iRoi, r.history}; %#ok<AGROW>
                r.history = localCompactRoiHistory(r.history);
            end

            if isprop(r, 'results')
                state.roiResults(end+1, :) = {iFov, iRoi, r.results}; %#ok<AGROW>
                r.results = [];
            end
            if isprop(r, 'train')
                state.roiTrain(end+1, :) = {iFov, iRoi, r.train}; %#ok<AGROW>
                r.train = [];
            end
            if isprop(r, 'proc')
                state.roiProc(end+1, :) = {iFov, iRoi, r.proc}; %#ok<AGROW>
                r.proc = [];
            end
            if isprop(r, 'classes')
                state.roiClasses(end+1, :) = {iFov, iRoi, r.classes}; %#ok<AGROW>
                r.classes = {};
            end
        end
    end

    cleanupObj = onCleanup(@() localRestoreProjectAfterMat(shallowObj, state));
end

function localRestoreProjectAfterMat(shallowObj, state)
    if state.hasParsedData
        shallowObj.parsedData = state.parsedData;
    end
    shallowObj.processing = state.processing;

    for iFov = 1:numel(state.fovParent)
        try
            shallowObj.fov(iFov).parent = state.fovParent{iFov};
        catch
        end
    end
    for k = 1:size(state.fovSrclist, 1)
        try
            shallowObj.fov(state.fovSrclist{k, 1}).srclist = state.fovSrclist{k, 2};
        catch
        end
    end

    localRestoreRoiField(shallowObj, state.roiImage, 'image');
    localRestoreRoiField(shallowObj, state.roiData, 'data');
    localRestoreRoiField(shallowObj, state.roiHistory, 'history');
    localRestoreRoiField(shallowObj, state.roiResults, 'results');
    localRestoreRoiField(shallowObj, state.roiTrain, 'train');
    localRestoreRoiField(shallowObj, state.roiProc, 'proc');
    localRestoreRoiField(shallowObj, state.roiClasses, 'classes');
end

function localRestoreRoiField(shallowObj, rows, fieldName)
    for k = 1:size(rows, 1)
        try
            iFov = rows{k, 1};
            iRoi = rows{k, 2};
            shallowObj.fov(iFov).roi(iRoi).(fieldName) = rows{k, 3};
        catch
        end
    end
end

function tf = localCanCompactSrclist(f)
    tf = false;
    try
        if isprop(f, 'isOMEZarr') && f.isOMEZarr
            tf = isprop(f, 'omeZarrPath') && ~isempty(f.omeZarrPath) && ...
                 isprop(f, 'omeZarrShape') && ~isempty(f.omeZarrShape);
            return;
        end
        if isprop(f, 'isNDTiff') && f.isNDTiff
            tf = isprop(f, 'ndtiffPath') && ~isempty(f.ndtiffPath);
            return;
        end
        if isprop(f, 'isMultiTiff') && f.isMultiTiff
            tf = isprop(f, 'tiffSource') && ~isempty(f.tiffSource) && ...
                 isprop(f, 'pageMap') && ~isempty(f.pageMap);
        end
    catch
        tf = false;
    end
end

function h = localCompactRoiHistory(h)
    maxRows = 20;
    try
        emptyHist = table('Size', [0 3], ...
            'VariableTypes', {'datetime', 'string', 'string'}, ...
            'VariableNames', {'Date', 'Category', 'Message'});
        if isempty(h) || ~istable(h)
            h = emptyHist;
            return;
        end

        keep = true(height(h), 1);
        if any(strcmp(h.Properties.VariableNames, 'Category'))
            cat = string(h.Category);
            keep = keep & ~strcmpi(cat, "Saving") & ~ismissing(cat);
        end
        if any(strcmp(h.Properties.VariableNames, 'Message'))
            msg = string(h.Message);
            keep = keep & ~ismissing(msg);
        end

        h = h(keep, :);
        if height(h) > maxRows
            h = h(end-maxRows+1:end, :);
        end
    catch
        h = table('Size', [0 3], ...
            'VariableTypes', {'datetime', 'string', 'string'}, ...
            'VariableNames', {'Date', 'Category', 'Message'});
    end
end

function processing = localCompactProcessing(processing)
    if ~isstruct(processing)
        processing = struct('roi', [], 'classification', [], 'processor', [], 'pipelineRun', []);
        return;
    end

    if isfield(processing, 'classification')
        try
            processing.classification = classi.empty;
        catch
            processing.classification = [];
        end
    end
    if isfield(processing, 'processor')
        try
            processing.processor = process.empty;
        catch
            processing.processor = [];
        end
    end
    if isfield(processing, 'pipelineRun')
        try
            processing.pipelineRun = pipelineRun.empty;
        catch
            processing.pipelineRun = [];
        end
    end
end

function parsedData = localCompactParsedData(parsedData)
    if isempty(parsedData) || ~isstruct(parsedData)
        return;
    end

    parsedData = localRemoveFieldsIfPresent(parsedData, ...
        {'files', 'filelist', 'channelsDir', 'roipattern', 'image', 'preview', 'metadata'});

    if isfield(parsedData, 'positions') && isstruct(parsedData.positions)
        pos = parsedData.positions;
        heavyPositionFields = {'channelsDir', 'filelist', 'roipattern', 'image', ...
            'preview', 'contours', 'metadata', 'metadataText'};
        for i = 1:numel(heavyPositionFields)
            if isfield(pos, heavyPositionFields{i})
                pos = rmfield(pos, heavyPositionFields{i});
            end
        end
        parsedData.positions = pos;
    end

    if isfield(parsedData, 'files')
        parsedData.files = {};
    end
    if isfield(parsedData, 'roipattern')
        parsedData.roipattern = [];
    end
end

function S = localRemoveFieldsIfPresent(S, names)
    for i = 1:numel(names)
        if isfield(S, names{i})
            S = rmfield(S, names{i});
        end
    end
end
