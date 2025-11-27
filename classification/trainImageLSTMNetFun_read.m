function trainImageLSTMNetFun_read(classif, varargin)
% trainImageLSTMNetFun_read  Aperçu des images d'entraînement CNN
%
%   trainImageLSTMNetFun_read(classif)
%   trainImageLSTMNetFun_read(classif,'NumImages',N,'Backend','tiff'/'hdf5')
%
% - Affiche N paires d'images : RAW (gauche) / AUGMENTÉE (droite).
% - Utilise classif.trainingParam pour reconstruire les paramètres d'augmentation
%   du CNN (même logique que trainImageGoogleNetFun).
%
% Backend:
%   'tiff' : lit les TIFF dans trainingdataset/images
%   'hdf5' : lit le framebank <strid>_framebank.h5

% ----------------- Parse options -----------------
p = inputParser;
p.addParameter('NumImages',8,@(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('Backend',[],@(x)ischar(x)||isstring(x)||isempty(x));
p.parse(varargin{:});
Npairs  = p.Results.NumImages;
backend = lower(string(p.Results.Backend));

tp = classif.trainingParam;

if numel(backend)==0
    if isfield(tp,'Format_StorageBackend') && ~isempty(tp.Format_StorageBackend)
        backend = lower(string(tp.Format_StorageBackend{end}));
    elseif isfield(tp,'CNN_storage_backend') && ~isempty(tp.CNN_storage_backend)
        backend = lower(string(tp.CNN_storage_backend{end}));
    else
        backend = "tiff";
    end
end

% ----------------- Taille d'entrée du CNN -----------------
netName = tp.CNN_network{end};
try
    netTmp = eval(netName);   % réseau ImageNet
    inputSizeHW = netTmp.Layers(1).InputSize(1:2);
catch
    warning('Impossible d''évaluer %s, on prend [224 224] comme taille d''entrée.', netName);
    inputSizeHW = [224 224];
end

imgsRaw   = {};
imgsAug   = {};
labels    = {};
allRawVals = [];
allAugVals = [];
rawType   = '';
rawC      = [];

switch backend
    %==================================================================
    %                           BACKEND TIFF
    %==================================================================
    case "tiff"
        foldername = fullfile(classif.path,'trainingdataset','images');
        if ~isfolder(foldername)
            error('Dossier TIFF introuvable : %s', foldername);
        end

        % imds de base (RAW)
        imds = imageDatastore(foldername, ...
            'IncludeSubfolders',true, ...
            'LabelSource','foldernames');

        nFiles = numel(imds.Files);
        if nFiles == 0
            error('Aucune image dans %s', foldername);
        end

        % On prend des indices aléatoires pour éviter le biais de classe
        Npairs = min(Npairs, nFiles);
        idxSel = randperm(nFiles, Npairs);

        % Geometric augmenter comme dans trainImageGoogleNetFun
        pixelRange = tp.CNN_translation_augmentation;
        rotation   = tp.CNN_rotation_augmentation;
        scaleRange = tp.CNN_rand_scale;
        if numel(scaleRange) ~= 2
            scaleRange = [0.8 1.0];
        end

        imageAugmenter = imageDataAugmenter( ...
            'RandXReflection',tp.CNN_rand_flip, ...
            'RandYReflection',tp.CNN_rand_flip, ...
            'RandScale',scaleRange, ...
            'RandXTranslation',pixelRange, ...
            'RandYTranslation',pixelRange, ...
            'RandRotation',rotation);

        % Boucle sur les paires
        for k = 1:Npairs
            idx = idxSel(k);
            fn  = imds.Files{idx};
            lab = string(imds.Labels(idx));

            % --- RAW ---
            Iraw = imread(fn);
            if isempty(rawType)
                rawType = class(Iraw);
                sz = size(Iraw);
                if numel(sz) < 3, rawC = 1; else, rawC = sz(3); end
            end
            allRawVals = [allRawVals; double(Iraw(:))]; %#ok<AGROW>

            % Pour affichage, on met tout à la taille du CNN
            IrawShow = imresize(Iraw, inputSizeHW);

            % --- AUG (photometric + geometric) ---
            tmpImds = imageDatastore(fn);
            tmpImds.ReadFcn = @(f) CNN_photometricReadFcn(f, tp);

            augDS = augmentedImageDatastore(inputSizeHW, tmpImds, ...
                'DataAugmentation', imageAugmenter);

            batch = read(augDS);
            Iaug  = extractFromBatch(batch);

            if isa(Iaug,'single') || isa(Iaug,'double')
                allAugVals = [allAugVals; double(Iaug(:))*double(max(Iraw(:))>1)*1 + double(Iaug(:))*double(max(Iraw(:))<=1)*255]; %#ok<AGROW>
                % petite bidouille : si Iaug est [0,1], on approx l'échelle
            else
                allAugVals = [allAugVals; double(Iaug(:))]; %#ok<AGROW>
            end

            if isa(Iaug,'single') || isa(Iaug,'double')
                IaugShow = im2uint8(Iaug);
            else
                IaugShow = Iaug;
            end

            imgsRaw{end+1} = IrawShow; %#ok<AGROW>
            imgsAug{end+1} = IaugShow; %#ok<AGROW>
            labels{end+1}  = char(lab); %#ok<AGROW>
        end

    %==================================================================
    %                           BACKEND HDF5
    %==================================================================
    case "hdf5"
        h5File = fullfile(classif.path, [classif.strid '_framebank.h5']);
        if ~isfile(h5File)
            error('Fichier HDF5 framebank introuvable : %s', h5File);
        end

        % Infos frames
        infoFrames = h5info(h5File, '/frames');
        sz = infoFrames.Dataspace.Size;   % [H W C N]
        H = sz(1); W = sz(2);
        if numel(sz) == 3
            C = 1; Nobs = sz(3);
        else
            C = sz(3); Nobs = sz(4);
        end

        % Labels pour les titres
        labsAll = h5read(h5File, '/labels');
        labsAll = squeeze(labsAll);

        if isnumeric(labsAll)
            labsAllCat = categorical(labsAll, 1:numel(classif.classes), classif.classes);
        else
            labsAllCat = categorical(string(labsAll), classif.classes);
        end

        if Nobs == 0
            error('Pas d''observations dans %s:/frames', h5File);
        end

        % Indices aléatoires
        Npairs = min(Npairs, Nobs);
        idxSel = randperm(Nobs, Npairs);

        % Datastore HDF5 pour l'augmentation (exact pipeline training)
        aug = localGetH5AugParams(tp);
        dsAug = H5ImageDatastore(h5File, ...
            'MiniBatchSize', max(1,tp.CNN_mini_batch_size), ...
            'TransRange',    aug.TransRange, ...
            'RotRange',      aug.RotRange, ...
            'CropScale',     aug.CropScale, ...
            'ContrastRange', aug.ContrastRange, ...
            'BrightnessRange', aug.BrightnessRange, ...
            'GammaRange',      aug.GammaRange, ...
            'SaturationRange', aug.SaturationRange, ...
            'HueDelta',      aug.HueDelta, ...
            'NoiseSigma',    aug.NoiseSigma, ...
            'DefocusSigmaRange', aug.DefocusSigmaRange, ...
            'DefocusProb',   aug.DefocusProb, ...
            'ClassNames',    classif.classes);
        dsAug.OutputSize = inputSizeHW;

        % On fait un subset avec ces indices, puis read séquentiel
        dsAugSub = subset(dsAug, idxSel);
        reset(dsAugSub);

        imgsAugCell = {};
        labelsAug   = {};
        while numel(imgsAugCell) < Npairs && hasdata(dsAugSub)
            batch = read(dsAugSub);
            if istable(batch)
                imgCells = batch.input;
                labCol   = batch.response;
                B = numel(imgCells);
                for b = 1:B
                    if numel(imgsAugCell) >= Npairs, break; end
                    I = imgCells{b};
                    if isa(I,'single') || isa(I,'double')
                        allAugVals = [allAugVals; double(I(:))*255]; %#ok<AGROW>
                        Ishow = im2uint8(I);
                    else
                        allAugVals = [allAugVals; double(I(:))]; %#ok<AGROW>
                        Ishow = I;
                    end
                    imgsAugCell{end+1} = Ishow; %#ok<AGROW>
                    labelsAug{end+1}   = char(string(labCol(b))); %#ok<AGROW>
                end
            else
                I4 = batch; % HxWxCxB
                if isa(I4,'single') || isa(I4,'double')
                    allAugVals = [allAugVals; double(I4(:))*255]; %#ok<AGROW>
                    I4 = im2uint8(I4);
                else
                    allAugVals = [allAugVals; double(I4(:))]; %#ok<AGROW>
                end
                B = size(I4,4);
                for b = 1:B
                    if numel(imgsAugCell) >= Npairs, break; end
                    imgsAugCell{end+1} = I4(:,:,:,b); %#ok<AGROW>
                    labelsAug{end+1}   = ''; %#ok<AGROW>
                end
            end
        end

        if numel(imgsAugCell) < Npairs
            warning('Seulement %d images augmentées lues sur %d demandées.', numel(imgsAugCell), Npairs);
            Npairs = numel(imgsAugCell);
            idxSel = idxSel(1:Npairs);
        end

        % RAW directement depuis HDF5 pour chacun de ces indices
        for k = 1:Npairs
            idx = idxSel(k);

            start = [1 1 1 idx];
            count = [H W C 1];
            Iraw = h5read(h5File, '/frames', start, count);
            Iraw = squeeze(Iraw);

            if isempty(rawType)
                rawType = class(Iraw);
                szR = size(Iraw);
                if numel(szR)<3, rawC = 1; else, rawC = szR(3); end
            end

            allRawVals = [allRawVals; double(Iraw(:))]; %#ok<AGROW>

            IrawShow = imresize(Iraw, inputSizeHW);

            imgsRaw{end+1} = IrawShow; %#ok<AGROW>
            imgsAug{end+1} = imgsAugCell{k}; %#ok<AGROW>

            labk = string(labsAllCat(idx));
            labels{end+1} = char(labk); %#ok<AGROW>
        end

    otherwise
        error('Backend inconnu : %s (utilise ''tiff'' ou ''hdf5'')', backend);
end


% ----------------- Affichage en PAIRES -----------------
nPairsShow = numel(imgsRaw);
if nPairsShow == 0
    warning('Aucune image trouvée pour l''aperçu (%s).', backend);
    return;
end

% figure haute et pas trop large
figH = 140 * nPairsShow;           %  ~140 px par paire
figW = 600;
figure('Name',sprintf('CNN samples (%s, %d paires)', backend, nPairsShow), ...
       'NumberTitle','off', ...
       'Units','pixels', ...
       'Position',[100 100 figW figH], ...
       'Color','w');

tiledlayout(nPairsShow,2, ...
    'Padding','none', ...          % pas de marge externe
    'TileSpacing','none');         % pas d'espace entre tuiles

for k = 1:nPairsShow
    % RAW
    nexttile(2*k-1);
    imshow(imgsRaw{k}, [], 'InitialMagnification','fit');
    axis image off
    if ~isempty(labels{k})
        title(sprintf('RAW (%s)', labels{k}), ...
              'Interpreter','none','FontSize',9);
    else
        title('RAW','FontSize',9);
    end

    % AUG
    nexttile(2*k);
    imshow(imgsAug{k}, [], 'InitialMagnification','fit');
    axis image off
    if ~isempty(labels{k})
        title(sprintf('AUG (%s)', labels{k}), ...
              'Interpreter','none','FontSize',9);
    else
        title('AUG','FontSize',9);
    end
end

% ----------------- Stats globales RAW / AUG -----------------
if isempty(allRawVals), allRawVals = 0; end
if isempty(allAugVals), allAugVals = 0; end

rawMin = min(allRawVals);
rawMed = median(allRawVals);
rawMax = max(allRawVals);

augMin = min(allAugVals);
augMed = median(allAugVals);
augMax = max(allAugVals);

if isempty(rawType)
    rawType = 'unknown';
    rawC = NaN;
end

sgtitle(sprintf( ...
    'CNN samples (%s, %d paires) | RAW: %s, C=%d, min=%.1f, med=%.1f, max=%.1f | AUG: min=%.1f, med=%.1f, max=%.1f', ...
    backend, nPairsShow, rawType, rawC, ...
    rawMin, rawMed, rawMax, ...
    augMin, augMed, augMax), ...
    'Interpreter','none','FontSize',10);



% ----------------- Stats globales RAW / AUG -----------------
if isempty(allRawVals)
    allRawVals = 0;
end
if isempty(allAugVals)
    allAugVals = 0;
end

rawMin = min(allRawVals);
rawMed = median(allRawVals);
rawMax = max(allRawVals);

augMin = min(allAugVals);
augMed = median(allAugVals);
augMax = max(allAugVals);

if isempty(rawType)
    rawType = 'unknown';
    rawC = NaN;
end

sgtitle(sprintf( ...
    'CNN samples (%s, %d paires) | RAW: %s, C=%d, min=%.1f, med=%.1f, max=%.1f | AUG: min=%.1f, med=%.1f, max=%.1f', ...
    backend, nPairsShow, rawType, rawC, rawMin, rawMed, rawMax, augMin, augMed, augMax), ...
    'Interpreter','none');

end

% ================== Helpers ==================



function I = extractFromBatch(batch)
% Gère les deux cas de sortie : table ou 4D array
if istable(batch)
    if any(strcmp(batch.Properties.VariableNames,'input'))
        imgCells = batch.input;
    else
        v1 = batch.Properties.VariableNames{1};
        imgCells = batch.(v1);
    end
    I = imgCells{1};
else
    I = batch(:,:,:,1);
end
end
