function validateCNNBackends(classif, varargin)
% validateCNNBackends  Compare CNN training sets between TIFF and HDF5.
%
%   validateCNNBackends(classif)
%   validateCNNBackends(classif,'Verbose',true)
%
% Affiche pour chaque backend (TIFF / HDF5) :
%   - nombre total d'images
%   - comptage par classe (aligné sur classif.classes)
%   - comparaison des fractions (Δ en % entre TIFF et HDF5)
%
% Hypothèses:
%   - Backend TIFF : images dans  <classif.path>/trainingdataset/images/<classe>/*.tif|*.png|...
%   - Backend HDF5 : fichier      <classif.path>/<classif.strid>_framebank.h5
%                    dataset      '/labels' (entier 1..K ou chaîne avec noms de classes)

    p = inputParser;
    p.addParameter('Verbose',true,@(x)islogical(x)&&isscalar(x));
    p.parse(varargin{:});
    verbose = p.Results.Verbose;

    basePath = classif.path;
    name     = classif.strid;
    classes  = string(classif.classes(:));
    K        = numel(classes);

    fprintf('=== validateCNNBackends for classif "%s" ===\n', name);
    fprintf('Classes (classif.classes): %s\n', strjoin(classes.', ', '));
    fprintf('Base path: %s\n\n', basePath);

    % ------------------------------------------------------------------
    % 1) Backend TIFF
    % ------------------------------------------------------------------
    tiffFolder = fullfile(basePath,'trainingdataset','images');
    hasTIFF    = isfolder(tiffFolder);

    if ~hasTIFF
        fprintf('[TIFF] Folder not found: %s\n', tiffFolder);
        tblTIFF = [];
    else
        imds = imageDatastore(tiffFolder, ...
            'IncludeSubfolders', true, ...
            'LabelSource', 'foldernames');

        if isempty(imds.Files)
            fprintf('[TIFF] No image files found in %s\n', tiffFolder);
            tblTIFF = [];
        else
            tblTIFF = countEachLabel(imds);
            % Forcer l'ordre des classes de classif
            cntTIFF = zeros(K,1);
            for i = 1:K
                ix = find(tblTIFF.Label == categorical(classes(i)), 1);
                if ~isempty(ix)
                    cntTIFF(i) = tblTIFF.Count(ix);
                end
            end
            tblTIFF = table(categorical(classes), cntTIFF, ...
                'VariableNames', {'Label','Count'});
            nTIFF = sum(cntTIFF);

            fprintf('[TIFF] Found %d images.\n', nTIFF);
            if verbose
                for i = 1:K
                    fprintf('  %-10s : %5d (%.1f%%)\n', ...
                        char(classes(i)), cntTIFF(i), 100*cntTIFF(i)/max(1,nTIFF));
                end
            end
            fprintf('\n');
        end
    end

   % ------------------------------------------------------------------
% 2) Backend HDF5
% ------------------------------------------------------------------
h5File  = fullfile(basePath,[name '_framebank.h5']);
hasH5   = isfile(h5File);

if ~hasH5
    fprintf('[HDF5] File not found: %s\n', h5File);
    tblH5 = [];
else
    fprintf('[HDF5] Reading labels from %s\n', h5File);

    try
        labsAll = h5read(h5File, '/labels');
    catch ME
        warning('[HDF5] Could not read /labels: %s', ME.message);
        tblH5 = [];
        labsAll = [];
    end

    if isempty(labsAll)
        fprintf('[HDF5] Empty /labels dataset.\n');
        tblH5 = [];
    else
        labsAll = squeeze(labsAll);

        % --- Construire un categorical ALIGNE SUR classif.classes ---
        if isnumeric(labsAll)
            % on suppose des indices 1..K
            u = unique(labsAll(:));
            if any(u < 1) || any(u > K)
                warning('[HDF5] Numeric labels out of range 1..K. Unique labels: %s', ...
                    mat2str(u(:).'));
            end
            labsCat = categorical(labsAll(:), 1:K, cellstr(classes));
        else
            % chaînes -> mapper explicitement sur classes
            labsStr = string(labsAll(:));
            labsCat = categorical(labsStr, classes);   % catégories = classes (ordre imposé)

            u = unique(labsStr);
            miss = setdiff(u, classes);
            if ~isempty(miss)
                warning('[HDF5] Some label strings are not in classif.classes: %s', ...
                    strjoin(miss.', ', '));
            end
        end

        % --- Comptage par classe, dans le même ordre que "classes" ---
        cntH5 = countcats(labsCat);
        cntH5 = cntH5(:);            % **forcer colonne Kx1**
        if numel(cntH5) ~= K
            % sécurité (ne devrait pas arriver si categorical ci-dessus est bien aligné)
            cntH5 = zeros(K,1);
            cats  = categories(labsCat);
            for i = 1:K
                ix = find(strcmp(cats, char(classes(i))), 1);
                if ~isempty(ix)
                    cntH5(i) = sum(labsCat == cats{ix});
                end
            end
        end

        tblH5 = table(categorical(classes), cntH5, ...
            'VariableNames', {'Label','Count'});

        nH5 = sum(cntH5);

        fprintf('[HDF5] Found %d labeled frames.\n', nH5);
        if verbose
            for i = 1:K
                fprintf('  %-10s : %5d (%.1f%%)\n', ...
                    char(classes(i)), cntH5(i), 100*cntH5(i)/max(1,nH5));
            end
        end
        fprintf('\n');
    end
end


    % ------------------------------------------------------------------
    % 3) Comparaison des deux backends
    % ------------------------------------------------------------------
    if isempty(tblTIFF) || isempty(tblH5)
        fprintf('Comparison skipped (one of the backends is missing or empty).\n');
        return;
    end

    cntTIFF = double(tblTIFF.Count);
    cntH5   = double(tblH5.Count);
    nTIFF   = sum(cntTIFF);
    nH5     = sum(cntH5);

    fracTIFF = cntTIFF / max(1,nTIFF);
    fracH5   = cntH5   / max(1,nH5);
    deltaFrac = fracH5 - fracTIFF;   % H5 - TIFF

    compTable = table(classes, cntTIFF, cntH5, ...
                      100*fracTIFF, 100*fracH5, 100*deltaFrac, ...
        'VariableNames', {'Class','Count_TIFF','Count_H5', ...
                          'Frac_TIFF_percent','Frac_H5_percent','Delta_percent(H5-TIFF)'});

    fprintf('=== Per-class comparison (TIFF vs HDF5) ===\n');
    disp(compTable);

    % Petit résumé global
    fprintf('\nTotal TIFF = %d, total HDF5 = %d (ratio H5/TIFF = %.3f)\n', ...
        nTIFF, nH5, nH5/max(1,nTIFF));

    if verbose
        bigDiff = abs(deltaFrac) > 0.05; % > 5 points de % de diff
        if any(bigDiff)
            fprintf('WARNING: Large fraction differences (>5%%) for classes: %s\n', ...
                strjoin(classes(bigDiff).', ', '));
        else
            fprintf('Fractions per class are broadly consistent between TIFF and HDF5.\n');
        end
    end

    fprintf('===========================================\n');
end
