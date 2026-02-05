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

    % Keep dataset in sync with legacy fields (best-effort)
    try
        classiObj.syncDatasetFromLegacy();
    catch
    end

    if isfolder(path)
        save(targetFile, 'classiObj');
        fprintf(' ✅ Classification object saved to: %s\n', targetFile);
    else
        fprintf(' ❌ ERROR: Could not access folder "%s". Check your connection. Aborting classification save.\n', path);
    end

    % ===== JSON SNAPSHOTS (best-effort, non-authoritative) =====
    try
        % trainingParam snapshot
        tp = [];
        try, tp = classiObj.trainingParam; catch, end
        if ~isempty(tp)
            localWriteJson(fullfile(path, 'trainingParam.json'), localToJsonSafe(tp));
        end

        % runProfiles snapshot
        rp = [];
        try, rp = classiObj.runProfiles; catch, end
        if ~isempty(rp)
            localWriteJson(fullfile(path, 'runProfiles.json'), localToJsonSafe(rp));
        end

        % dataset snapshot
        ds = [];
        try, ds = classiObj.dataset; catch, end
        if ~isempty(ds)
            localWriteJson(fullfile(path, 'dataset.json'), localToJsonSafe(ds));
        end

        % minimal meta snapshot
        meta = struct();
        try, meta.strid = classiObj.strid; end
        try, meta.path = classiObj.path; end
        try, meta.typeid = classiObj.typeid; end
        try, meta.category = classiObj.category; end
        try, meta.description = classiObj.description; end
        try, meta.classes = classiObj.classes; end
        try, meta.classifierPkg = classiObj.classifierPkg; end
        localWriteJson(fullfile(path, 'classi_meta.json'), localToJsonSafe(meta));
    catch
        % Do not block saving on JSON errors
    end

    fprintf('--------------------------------------------\n\n');

    function localWriteJson(fp, S)
        txt = jsonencode(S);
        txt = regexprep(txt, ',"', sprintf(',\n"'));
        fid = fopen(fp,'w');
        if fid<0, return; end
        fwrite(fid, txt, 'char');
        fclose(fid);
    end

    function out = localToJsonSafe(in)
        % Convert common non-JSON types into JSON-friendly data.
        if isa(in,'function_handle')
            out = func2str(in);
            return;
        end
        if istable(in)
            out = table2struct(in);
            return;
        end
        if isa(in,'containers.Map')
            ks = in.keys;
            out = struct();
            for ii = 1:numel(ks)
                k = ks{ii};
                out.(matlab.lang.makeValidName(char(string(k)))) = localToJsonSafe(in(k));
            end
            return;
        end
        if isstruct(in)
            out = struct();
            f = fieldnames(in);
            for ii = 1:numel(f)
                out.(f{ii}) = localToJsonSafe(in.(f{ii}));
            end
            return;
        end
        if iscell(in)
            out = cell(size(in));
            for ii = 1:numel(in)
                out{ii} = localToJsonSafe(in{ii});
            end
            return;
        end
        if isstring(in)
            out = cellstr(in);
            return;
        end
        if ischar(in) || isnumeric(in) || islogical(in)
            out = in;
            return;
        end

        % Fallback: store class name
        try
            out = class(in);
        catch
            out = 'unserializable';
        end
    end
end
