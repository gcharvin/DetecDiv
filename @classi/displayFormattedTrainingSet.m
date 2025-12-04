function [output, himg] = displayFormattedTrainingSet(classif, varargin)
% displayFormattedTrainingSet  Aperçu du training set (RAW ou Augmentations)
%
%   [output, himg] = displayFormattedTrainingSet(classif)
%   [output, himg] = displayFormattedTrainingSet(classif,'Display')
%   [output, himg] = displayFormattedTrainingSet(classif,'Nimages',N)
%   [output, himg] = displayFormattedTrainingSet(classif,'Mode','raw'/'Augmentation')
%
% Mode 'raw' (par défaut) :
%   - Comportement identique à la version originale :
%       * pour Image/LSTM : comptage par classe, montage d'images TIFF ou HDF5
%       * pour Pixel / Delta : inchangé
%   - Écrit sampleImage.png dans le dossier de la classification.
%
% Mode 'Augmentation' (Image/LSTM uniquement) :
%   - Figure 1 : paires RAW / AUG (échantillons aléatoires)
%   - Figure 2 : tableau (types d'augmentation en lignes, colonnes = RAW + 3/4 augmentations)
%   - Ne touche PAS au fichier sampleImage.png.
%
% Paramètres :
%   'Display'       : (logique) active l'affichage en mode 'raw'. Ignoré en 'Augmentation'
%                     (car l'affichage est intrinsèque en mode Augmentation).
%   'Nimages'       : nombre d'images à utiliser (raw ou paires). Par défaut : 10.
%   'Mode'          : 'raw' (default) ou 'Augmentation'.
%   'NAugPerType'   : nb d'exemples augmentés par type (colonnes) pour la figure 2 (default 4).

% -------------------------------------------------------------------------
% 1) Parsing des paramètres
% -------------------------------------------------------------------------
display  = 0;
n        = 10;
mode     = 'raw';          % 'raw' ou 'Augmentation'
nAugPerType = 4;           % # augmentations par type (figure 2)

for i = 1:numel(varargin)
    if ischar(varargin{i}) || isstring(varargin{i})
        key = lower(string(varargin{i}));
        switch key
            case "display"
                display = 1;
            case "nimages"
                if i+1 <= numel(varargin)
                    n = varargin{i+1};
                end
            case "mode"
                if i+1 <= numel(varargin)
                    mode = char(varargin{i+1});
                end
            case "naugpertype"
                if i+1 <= numel(varargin)
                    nAugPerType = varargin{i+1};
                end
        end
    end
end

mode = lower(mode);
himg   = [];
output = {};

cate = classif.category{1};
pth  = classif.getPath;

disp(['This classification is of this type: ' cate]);

% Détection éventuelle d'un framebank HDF5 (utile en particulier pour Pixel/CPSAM)
h5FramebankFile     = fullfile(pth, [classif.strid '_framebank.h5']);
hasPixelFramebank   = isfile(h5FramebankFile);

% Backend (TIFF / HDF5) utile pour Image/LSTM & Augmentation
backend = "tiff";
if isprop(classif,'trainingParam') && isfield(classif.trainingParam,'Format_StorageBackend')
    backend = lower(string(classif.trainingParam.Format_StorageBackend{end}));
end
isHDF5 = strcmp(backend,'hdf5');

% En mode Augmentation, l'affichage est implicite
if strcmpi(mode,'augmentation')
    display = 1;
end

% -------------------------------------------------------------------------
% 2) Comportement selon la catégorie
% -------------------------------------------------------------------------
switch cate
    % =====================================================================
    %              IMAGE / LSTM : RAW + AUGMENTATION
    % =====================================================================
    case {'Image','LSTM'}

        switch lower(mode)
            % -------------------------------------------------------------
            % MODE 'raw' : comportement historique, plus PNG
            % -------------------------------------------------------------
            case 'raw'
                if ~isHDF5
                    % -----------------------------------------------------
                    % ======= MODE TIFF (RAW) ========
                    % -----------------------------------------------------
                    nfolder = fullfile(pth, 'trainingdataset/images');
                    l = dir(nfolder);

                    if numel(l) <= 2
                        disp('No exported TIFF dataset found.');
                        return;
                    end

                    output = {};
                    img    = {};
                    ccc    = 1; 
                    cc     = 1;
                    totalImages = 0;

                    for i = 3:numel(l)
                        className = l(i).name;
                        nsfolder  = fullfile(nfolder, className);
                        p         = dir(fullfile(nsfolder,'*.tif'));

                        nb = numel(p);
                        totalImages = totalImages + nb;

                        output{ccc,1} = className;
                        output{ccc,2} = nb;

                        if display && nb > 0
                            maxe = min(n, nb);
                            idx  = randperm(nb, maxe);
                            for j = idx
                                tmp = imread(fullfile(p(j).folder, p(j).name));
                                tmp = insertText(tmp, [1 1], className, ...
                                    'TextColor',[255 255 255], ...
                                    'BoxOpacity',0,'FontSize',24);
                                img{cc} = tmp;
                                cc      = cc + 1;
                            end
                        end
                        ccc = ccc + 1;
                    end

                    if display && ~isempty(img)
                        himg = montage(img);
                        h = gcf; set(h,'Position',[100 100 800 600]);
                    end

                    disp(['Total number of TIFF images in trainingset: ' num2str(totalImages)]);

                else
                    % -----------------------------------------------------
                    % ======= MODE HDF5 (RAW) ========
                    % -----------------------------------------------------
                    h5File = fullfile(pth,[classif.strid,'_framebank.h5']);

                    if ~isfile(h5File)
                        disp('No HDF5 framebank found.');
                        return;
                    end

                    classNames  = h5read(h5File, '/classNames');    % 1×C strings
                    labels      = double(h5read(h5File, '/labels')); % 1×N int
                    totalFrames = numel(labels);

                    output = {};
                    img    = {};
                    cc     = 1;

                    % Compter nb frames par classe
                    for ci = 1:numel(classNames)
                        cname = classNames(ci);
                        idx   = find(labels == ci);

                        output{ci,1} = cname;
                        output{ci,2} = numel(idx);

                        disp(['Class ' char(cname) ' has ' num2str(numel(idx)) ' frames']);

                        if display && ~isempty(idx)
                            pick = idx(randperm(numel(idx), min(n, numel(idx))));
                            for f = pick
                                % On suppose /frames [H W C N]
                                tmp = h5read(h5File, '/frames', [1 1 1 f], [Inf Inf Inf 1]);
                                tmp = squeeze(tmp);
                                if ndims(tmp) == 2
                                    tmp = repmat(tmp,[1 1 3]);
                                elseif size(tmp,3) == 1
                                    tmp = repmat(tmp,[1 1 3]);
                                end
                                tmp = uint8(tmp);  % sécurité
                                tmp = insertText(tmp,[1 1],cname,'TextColor',[255 255 255], ...
                                    'BoxOpacity',0,'FontSize',24);
                                img{cc} = tmp; 
                                cc = cc + 1;
                            end
                        end
                    end

                    % Affichage montage
                    if display && ~isempty(img)
                        figure;
                        himg = montage(img);
                        h = gcf; set(h,'Position',[100 100 800 600]);
                    end

                    disp(['Total number of frames in HDF5 framebank: ' num2str(totalFrames)]);
                end

            % -------------------------------------------------------------
            % MODE 'Augmentation' : paires + tableau par type
            % -------------------------------------------------------------
            case 'augmentation'
                % On ne génère PAS de PNG ici.
                if ~isprop(classif,'trainingParam') || isempty(classif.trainingParam)
                    warning('No trainingParam found in classif. Cannot preview augmentations.');
                    return;
                end

                tp = classif.trainingParam;

                % Taille d'entrée du CNN (on essaye depuis CNN_network)
                inputSizeHW = [224 224];
                if isfield(tp,'CNN_network')
                    netName = tpLast(tp,'CNN_network','');
                    if ~isempty(netName)
                        try
                            netTmp = eval(netName);
                            inputSizeHW = netTmp.Layers(1).InputSize(1:2);
                        catch
                            warning('Could not evaluate %s, using default [224 224]', netName);
                        end
                    end
                end

                % Figure 1 : paires RAW / AUG
                localShowPairsAugmentation(classif, backend, tp, n, inputSizeHW);

                % Figure 2 : tableau types x colonnes (RAW + plusieurs AUG)
                localShowTypesGridAugmentation(classif, backend, tp, nAugPerType, inputSizeHW);

                % Pas de PNG, pas de montage en sortie
                himg   = [];
                output = {};
                return;

            otherwise
                error('Unknown Mode: %s (use ''raw'' or ''Augmentation'')', mode);
        end

    % =====================================================================
    %                           PIXEL
    % =====================================================================
    case 'Pixel'
    classes = classif.classes; %#ok<NASGU>

    if hasPixelFramebank
        % -------------------------------------------------------------
        % ======= MODE HDF5 (framebank Pixel / CPSAM) ========
        % -------------------------------------------------------------
        h5File = h5FramebankFile;  % déjà construit en haut

        if ~isfile(h5File)
            disp('No HDF5 framebank found for Pixel trainingset; quitting...');
            return;
        end

        info = h5info(h5File);

        % --- Détection du dataset d'images (frames) ---
        candFrame = {'/frames','/images','/raw'};
        dsetFrame = '';
        for k = 1:numel(candFrame)
            try
                h5info(h5File, candFrame{k});
                dsetFrame = candFrame{k};
                break;
            catch
            end
        end
        if isempty(dsetFrame)
            % fallback : premier dataset du fichier
            if ~isempty(info.Datasets)
                dsetFrame = ['/' info.Datasets(1).Name];
            elseif ~isempty(info.Groups) && ~isempty(info.Groups(1).Datasets)
                dsetFrame = ['/' info.Groups(1).Name '/' info.Groups(1).Datasets(1).Name];
            else
                warning('No suitable image dataset found in %s', h5File);
                return;
            end
        end

        infoFrames = h5info(h5File, dsetFrame);
        sz = infoFrames.Dataspace.Size;  % [H W C N] ou [H W N]

        if numel(sz) == 3
            H = sz(1); W = sz(2); C = 1; Nobs = sz(3);
        else
            H = sz(1); W = sz(2); C = sz(3); Nobs = sz(4);
        end

        if Nobs == 0
            disp('No frames in HDF5 Pixel trainingset; quitting...');
            return;
        end

        % --- Détection éventuelle d'un dataset de labels / masques ---
        candLab   = {'/labels','/masks','/labelmaps'};
        dsetLabel = '';
        for k = 1:numel(candLab)
            try
                h5info(h5File, candLab{k});
                dsetLabel = candLab{k};
                break;
            catch
            end
        end
        hasLabels = ~isempty(dsetLabel);

        output{1,1} = 'images';
        output{1,2} = Nobs;

        disp(['Total number of frames in HDF5 Pixel trainingset: ' num2str(Nobs)]);

        if display
            img  = {};
            maxe = min(n, Nobs);
            idx  = randperm(Nobs, maxe);
            cc   = 1;

            for j = idx
                % lecture frame j
                start = [1 1 1 j];
                count = [H W C 1];
                I = h5read(h5File, dsetFrame, start, count);
                I = squeeze(I);

                if ndims(I) == 2
                    Irgb = repmat(I, [1 1 3]);
                elseif size(I,3) == 1
                    Irgb = repmat(I, [1 1 3]);
                else
                    Irgb = I;
                end
                Irgb = im2uint8(mat2gray(Irgb));  % safe

                % overlay labels si disponibles
                if hasLabels
                    try
                        infoLab = h5info(h5File, dsetLabel);
                        szL     = infoLab.Dataspace.Size;

                        if numel(szL) == 3
                            HL = szL(1); WL = szL(2); NL = szL(3);
                            startL = [1 1 j];
                            countL = [HL WL 1];
                        else
                            HL = szL(1); WL = szL(2); CL = szL(3); NL = szL(4);
                            startL = [1 1 1 j];
                            countL = [HL WL CL 1];
                        end

                        if NL >= j
                            L = h5read(h5File, dsetLabel, startL, countL);
                            L = squeeze(L);

                            if ~islogical(L) && max(L(:)) > 1
                                % carte de labels -> pseudo-couleurs
                                Lrgb = label2rgb(uint16(L), 'jet', 'k', 'shuffle');
                                Lrgb = im2uint8(mat2gray(Lrgb));
                                Irgb = imlincomb(0.75, Irgb, 0.25, Lrgb);
                            else
                                % masque binaire
                                mask = L ~= 0;
                                try
                                    Irgb = insertObjectMask(Irgb, mask, ...
                                        'Opacity',0.4, 'LineOpacity',1, 'LineWidth',2);
                                catch
                                    mr = Irgb(:,:,1);
                                    mr(mask) = 255;
                                    Irgb(:,:,1) = mr;
                                end
                            end
                        end
                    catch
                        % en cas d'erreur sur les labels, on affiche juste l'image
                    end
                end

                img{cc} = Irgb; %#ok<AGROW>
                cc = cc + 1;
            end

            try
                figure;
                himg = montage(img);
            catch
            end
        end

    else
        % -------------------------------------------------------------
        % ======= MODE TIFF (code historique) ========
        % -------------------------------------------------------------
        nfolder = fullfile(pth, 'trainingdataset/images');
        l       = dir(nfolder);

        nfolder2 = fullfile(pth, 'trainingdataset/labels');
        l2       = dir(nfolder2);

        if numel(l) <= 2
            disp('there is no exported dataset in folder; quitting...');
            return;
        end

        cd = numel(l) - 2;
        disp(['Total number of images in trainingset: ' num2str(cd)]);

        output{1,1} = 'images';
        output{1,2} = cd;

        img = [];

        if display
            maxe = min(n, numel(l)-2);
            if numel(l) > 2
                idx = randi([3 numel(l)],[1 maxe]);
            else
                idx = [];
            end

            cc = 1;
            for j = idx
                try
                    tmp = imread(fullfile(l(j).folder,l(j).name));

                    if strcmp(classif.description{3},'Solov2')
                        tmp2 = load(fullfile(l2(j).folder,l2(j).name));
                        mas  = tmp2.masks;
                        lab  = tmp2.labels;
                        dis  = uint8(zeros(size(tmp,1:2))); %#ok<NASGU>
                        nm   = size(mas,3);
                        cm   = lines(numel(classif.classes));

                        for ii = 1:nm
                            bwtmp = tmp2.masks(:,:,ii);
                            pixc  = find(matches(classif.classes,string(tmp2.labels(ii))));
                            col   = cm(pixc,:);
                            tmp   = insertObjectMask(tmp,bwtmp,'MaskColor',col, ...
                                'Opacity',0.5,'LineOpacity',1,'LineWidth',2);
                        end
                    else
                        tmp2 = imread(fullfile(l2(j).folder,l2(j).name));
                        tmp  = imlincomb(0.75,tmp,0.25,tmp2);
                    end
                catch
                    % do nothing
                end

                disp(['Display image: ' l(j).name ]);
                try
                    img{cc} = tmp; %#ok<AGROW>
                catch
                end
                cc = cc + 1;
            end

            try
                figure;
                himg = montage(img);
            catch
            end
        end
    end



    % =====================================================================
    %                           DELTA
    % =====================================================================
    case 'Delta'
        % --- Code original conservé (RAW uniquement) ---
        classes = classif.classes; %#ok<NASGU>
        nfolder = fullfile(pth, 'trainingdataset/images');
        l       = dir(nfolder);

        nfolder2 = fullfile(pth, 'trainingdataset/labels');
        l2       = dir(nfolder2);

        if numel(l) <= 2
            disp('there is no exported dataset in folder; quitting...');
            return;
        end

        cd = numel(l) - 2;
        disp(['Total number of images in trainingset: ' num2str(cd)]);

        output{1,1} = 'images';
        output{1,2} = cd;

        if display
            img  = [];
            maxe = min(n, numel(l)-2);
            if numel(l) > 2
                idx = randi([3 numel(l)],[1 maxe]);
            else
                idx = [];
            end

            cc = 1;
            for j = idx
                load(fullfile(l(j).folder,l(j).name),'tmpcrop'); %#ok<LOAD>
                tmp  = tmpcrop; % tmpcrop is stored in the file
                tmp2 = imread(fullfile(l2(j).folder,l2(j).name));

                tmpa = repmat(tmp(:,:,1),[1 1 3]);
                tmpb = repmat(tmp(:,:,2),[1 1 3]);
                tmpc = repmat(tmp(:,:,3),[1 1 3]);
                tmpd = repmat(tmp(:,:,4),[1 1 3]);

                tmp3 = [tmpa tmpb tmpc tmpd tmp2];

                disp(['Display image: ' l(j).name ]);
                img{cc} = tmp3; %#ok<AGROW>
                cc = cc + 1;
            end

            figure;
            himg = montage(img,'Size',[NaN 1]);
        end
end

% -------------------------------------------------------------------------
% 3) Écriture du sampleImage.png (UNIQUEMENT en mode RAW)
% -------------------------------------------------------------------------
if strcmpi(mode,'raw')
    fle = fullfile(pth, 'sampleImage.png');

    if display
        % Mode affichage : on a himg = montage
        if ~isempty(himg)
            if isgraphics(himg)
                sample = himg.CData;
            else
                sample = himg;
            end
            imwrite(sample, fle);
            himg = sample;
        end
    else
        % Mode silencieux : lire sampleImage.png ou en créer un
        if isfile(fle)
            himg = imread(fle);
        else
            if exist('img','var') && ~isempty(img)
                sample = img{1};
            else
                sample = uint8(255 * ones(100,100,3));
            end
            imwrite(sample, fle);
            himg = sample;
        end
    end
end

end % <-- fin de la fonction principale
% =====================================================================
% ===================== HELPER FUNCTIONS ==============================
% =====================================================================

function val = tpLast(tp, name, defaultVal)
    % Récupère la dernière valeur d'un champ de trainingParam
    if ~isfield(tp, name)
        val = defaultVal;
        return;
    end
    v = tp.(name);
    if iscell(v)
        if isempty(v)
            val = defaultVal;
        else
            val = v{end};
        end
    else
        if isempty(v)
            val = defaultVal;
        else
            val = v;
        end
    end
end

function aug = localGetAugConfigFromTP(tp)
% Construit une structure d'augmentation à partir des trainingParam.
% Essaie plusieurs noms de champs (avec / sans préfixe CNN_).

    aug = struct();

    % --- Géométrique ---
    aug.FlipProb = tpLastOr(tp, {'CNN_rand_flip','rand_flip'}, 0); % 0 ou 1
    trans = tpLastOr(tp, {'CNN_translation_augmentation','TranslationRange'}, [0 0]);
    if isscalar(trans), trans = [trans trans]; end
    aug.TransRange = trans;

    rot = tpLastOr(tp, {'CNN_rotation_augmentation','RotationRange'}, 0);
    if isscalar(rot), rot = [-rot rot]; end
    aug.RotRange = rot;

    scale = tpLastOr(tp, {'CNN_rand_scale','CropScale'}, [1 1]);
    if numel(scale) ~= 2
        scale = [min(scale(:)) max(scale(:))];
    end
    aug.ScaleRange = scale;

    % --- Photométrique ---
    aug.ContrastRange    = tpLastOr(tp, {'CNN_contrast_range','ContrastRange'}, [1 1]);
    aug.BrightnessRange  = tpLastOr(tp, {'CNN_brightness_range','BrightnessRange'}, [0 0]);
    aug.GammaRange       = tpLastOr(tp, {'CNN_gamma_range','GammaRange'}, [1 1]);
    aug.SaturationRange  = tpLastOr(tp, {'CNN_saturation_range','SaturationRange'}, [1 1]);
    aug.HueDelta         = tpLastOr(tp, {'CNN_hue_delta','HueDelta'}, 0);
    aug.NoiseSigma       = tpLastOr(tp, {'CNN_noise_sigma','NoiseSigma'}, 0);
    aug.DefocusSigmaRange= tpLastOr(tp, {'CNN_defocus_sigma_range','DefocusSigmaRange'}, [0 0]);
end

function val = tpLastOr(tp, names, defaultVal)
    % Essaie plusieurs noms possibles dans trainingParam
    val = defaultVal;
    for iName = 1:numel(names)
        nm = names{iName};
        if isfield(tp, nm)
            v = tp.(nm);
            if iscell(v)
                if ~isempty(v)
                    val = v{end};
                    return;
                end
            elseif ~isempty(v)
                val = v;
                return;
            end
        end
    end
end

% ---------------------------------------------------------------------
% Figure 1 : pairs RAW / AUG
% ---------------------------------------------------------------------
function localShowPairsAugmentation(classif, backend, tp, Npairs, inputSizeHW)

    backend = lower(string(backend));
    imgsRaw = {};
    imgsAug = {};
    labels  = {};

    switch backend
        case "tiff"
            foldername = fullfile(classif.path,'trainingdataset','images');
            if ~isfolder(foldername)
                warning('TIFF folder not found: %s', foldername);
                return;
            end

            imds = imageDatastore(foldername, ...
                'IncludeSubfolders',true, ...
                'LabelSource','foldernames');

            nFiles = numel(imds.Files);
            if nFiles == 0
                warning('No TIFF images found in %s', foldername);
                return;
            end

            Npairs = min(Npairs, nFiles);
            idxSel = randperm(nFiles, Npairs);

            % Config géométrique : on essaie de coller aux params CNN_
            pixelRange = tpLast(tp,'CNN_translation_augmentation',[0 0]);
            if isscalar(pixelRange), pixelRange = [pixelRange pixelRange]; end
            rotation   = tpLast(tp,'CNN_rotation_augmentation',0);
            if isscalar(rotation), rotation = [-rotation rotation]; end
            scaleRange = tpLast(tp,'CNN_rand_scale',[1 1]);
            if numel(scaleRange) ~= 2
                scaleRange = [min(scaleRange(:)) max(scaleRange(:))];
            end
            randFlip = tpLast(tp,'CNN_rand_flip',0) ~= 0;

            imageAugmenter = imageDataAugmenter( ...
                'RandXReflection',randFlip, ...
                'RandYReflection',randFlip, ...
                'RandScale',scaleRange, ...
                'RandXTranslation',pixelRange, ...
                'RandYTranslation',pixelRange, ...
                'RandRotation',rotation);

            for k = 1:Npairs
                idx = idxSel(k);
                fn  = imds.Files{idx};
                lab = string(imds.Labels(idx));

                Iraw = imread(fn);
                IrawShow = imresize(Iraw, inputSizeHW);

                % Photométrique via CNN_photometricReadFcn (si disponible)
                tmpImds = imageDatastore(fn);
                if exist('CNN_photometricReadFcn','file') == 2
                    tmpImds.ReadFcn = @(f) CNN_photometricReadFcn(f, tp);
                else
                    tmpImds.ReadFcn = @(f) im2single(imread(f));
                end

                augDS = augmentedImageDatastore(inputSizeHW, tmpImds, ...
                    'DataAugmentation', imageAugmenter);

                batch = read(augDS);
                Iaug  = localExtractFromBatch(batch);

                if isa(Iaug,'single') || isa(Iaug,'double')
                    IaugShow = im2uint8(Iaug);
                else
                    IaugShow = Iaug;
                end

                imgsRaw{end+1} = IrawShow; %#ok<AGROW>
                imgsAug{end+1} = IaugShow; %#ok<AGROW>
                labels{end+1}  = char(lab); %#ok<AGROW>
            end

        case "hdf5"
            h5File = fullfile(classif.path,[classif.strid '_framebank.h5']);
            if ~isfile(h5File)
                warning('HDF5 framebank not found: %s', h5File);
                return;
            end

            infoFrames = h5info(h5File,'/frames');
            sz = infoFrames.Dataspace.Size; % [H W C N]
            H = sz(1); W = sz(2);
            if numel(sz) == 3
                C = 1; Nobs = sz(3);
            else
                C = sz(3); Nobs = sz(4);
            end

            labsAll = h5read(h5File,'/labels');
            labsAll = squeeze(labsAll);
            if isnumeric(labsAll)
                labsAllCat = categorical(labsAll,1:numel(classif.classes),classif.classes);
            else
                labsAllCat = categorical(string(labsAll), classif.classes);
            end

            if Nobs == 0
                warning('No frames in HDF5 /frames');
                return;
            end

            Npairs = min(Npairs, Nobs);
            idxSel = randperm(Nobs, Npairs);

            augCfg = localGetAugConfigFromTP(tp);

            for k = 1:Npairs
                idx = idxSel(k);
                start = [1 1 1 idx];
                count = [H W C 1];
                Iraw = h5read(h5File,'/frames',start,count);
                Iraw = squeeze(Iraw);

                if ndims(Iraw) == 2
                    IrawShow = repmat(Iraw,[1 1 3]);
                elseif size(Iraw,3) == 1
                    IrawShow = repmat(Iraw,[1 1 3]);
                else
                    IrawShow = Iraw;
                end
                IrawShow = imresize(IrawShow, inputSizeHW);

                Iaug = localApplyFullAug(IrawShow, augCfg);
                IaugShow = im2uint8(Iaug);

                imgsRaw{end+1} = im2uint8(IrawShow); %#ok<AGROW>
                imgsAug{end+1} = IaugShow; %#ok<AGROW>
                labels{end+1}  = char(string(labsAllCat(idx))); %#ok<AGROW>
            end

        otherwise
            error('Unknown backend for augmentation preview: %s', backend);
    end

    nPairsShow = numel(imgsRaw);
    if nPairsShow == 0
        warning('No images found for augmentation preview.');
        return;
    end

%% --- Layout options (modifiable facilement) ---
tileW = inputSizeHW(2);   % largeur d'une tuile ≈ largeur image
tileH = inputSizeHW(1);   % hauteur d'une tuile ≈ hauteur image

margin      = 10;         % marge intérieure entre les tuiles
extraMargin = 20;         % marge supplémentaire pour stabilité
background  = [0 0 0];    % fond noir (comme montage)

MasterRows = nPairsShow;
MasterCols = 2;

figWidth  = MasterCols * tileW + (MasterCols+1)*margin;
figHeight = MasterRows * tileH + (MasterRows+1)*margin + extraMargin;

fig = figure('Name', sprintf('CNN samples (%s, %d pairs)', backend, nPairsShow), ...
             'NumberTitle','off', ...
             'Units','pixels', ...
             'Position',[100 100 figWidth figHeight]);

set(fig,'Color',background);

masterTL = tiledlayout(fig, MasterRows, MasterCols, ...
    'TileSpacing','none', ...
    'Padding','tight');

    for k = 1:nPairsShow
        % RAW
        % RAW
nexttile(2*k-1);
I = imgsRaw{k};
txt = sprintf('RAW %s', labels{k});
I = insertText(I, [2 2], txt, ...
    'FontSize', 20, 'BoxOpacity', 0, 'TextColor', 'white');
imshow(I, [], 'InitialMagnification','fit');
axis image off


        % AUG
       % AUG
nexttile(2*k);
I = imgsAug{k};
txt = sprintf('AUG %s', labels{k});
I = insertText(I, [2 2], txt, ...
    'FontSize', 20, 'BoxOpacity', 0, 'TextColor', 'white');
imshow(I, [], 'InitialMagnification','fit');
axis image off

    end

end

function I = localExtractFromBatch(batch)
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

% ---------------------------------------------------------------------
% Figure 2 : types d'augmentation x (RAW + N versions)
% ---------------------------------------------------------------------
function localShowTypesGridAugmentation(classif, backend, tp, nAugPerType, inputSizeHW)

    backend = lower(string(backend));
    augCfg  = localGetAugConfigFromTP(tp);

    % 1) Choisir une image de base (grayscale ou RGB) selon le backend
    switch backend
        case "tiff"
            foldername = fullfile(classif.path,'trainingdataset','images');
            if ~isfolder(foldername)
                warning('TIFF folder not found: %s', foldername);
                return;
            end
            imds = imageDatastore(foldername, ...
                'IncludeSubfolders',true, ...
                'LabelSource','foldernames');

            if numel(imds.Files) == 0
                warning('No TIFF images for augmentation grid.');
                return;
            end
            idxBase = randi(numel(imds.Files));
            Iraw = imread(imds.Files{idxBase});

        case "hdf5"
            h5File = fullfile(classif.path,[classif.strid '_framebank.h5']);
            if ~isfile(h5File)
                warning('HDF5 framebank not found: %s', h5File);
                return;
            end
            infoFrames = h5info(h5File,'/frames');
            sz = infoFrames.Dataspace.Size; % [H W C N]
            H = sz(1); W = sz(2);
            if numel(sz) == 3
                C = 1; Nobs = sz(3);
            else
                C = sz(3); Nobs = sz(4);
            end
            if Nobs == 0
                warning('No frames in HDF5 for augmentation grid.');
                return;
            end
            idxBase = randi(Nobs);
            start = [1 1 1 idxBase];
            count = [H W C 1];
            Iraw  = h5read(h5File,'/frames',start,count);
            Iraw  = squeeze(Iraw);

        otherwise
            warning('Unknown backend for augmentation grid: %s', backend);
            return;
    end

    if ndims(Iraw) == 2
        IrawRGB = repmat(Iraw,[1 1 3]);
    elseif size(Iraw,3) == 1
        IrawRGB = repmat(Iraw,[1 1 3]);
    else
        IrawRGB = Iraw;
    end

    IrawRGB = im2double(imresize(IrawRGB, inputSizeHW));

    % 2) Liste des types d'augmentation actifs
    typeNames = {};
    if augCfg.FlipProb ~= 0
        typeNames{end+1} = 'Flip'; %#ok<AGROW>
    end
    if any(abs(augCfg.TransRange) > 0)
        typeNames{end+1} = 'Translation'; %#ok<AGROW>
    end
    if any(abs(augCfg.RotRange) > 0)
        typeNames{end+1} = 'Rotation'; %#ok<AGROW>
    end
    if any(abs(augCfg.ScaleRange - 1) > 1e-3)
        typeNames{end+1} = 'Scale'; %#ok<AGROW>
    end
    if any(abs(augCfg.ContrastRange - 1) > 1e-3)
        typeNames{end+1} = 'Contrast'; %#ok<AGROW>
    end
    if any(abs(augCfg.BrightnessRange) > 1e-6)
        typeNames{end+1} = 'Brightness'; %#ok<AGROW>
    end
    if any(abs(augCfg.GammaRange - 1) > 1e-3)
        typeNames{end+1} = 'Gamma'; %#ok<AGROW>
    end
    if any(abs(augCfg.SaturationRange - 1) > 1e-3)
        typeNames{end+1} = 'Saturation'; %#ok<AGROW>
    end
    if abs(augCfg.HueDelta) > 1e-6
        typeNames{end+1} = 'Hue'; %#ok<AGROW>
    end
    if augCfg.NoiseSigma > 0
        typeNames{end+1} = 'Noise'; %#ok<AGROW>
    end
    if any(abs(augCfg.DefocusSigmaRange) > 1e-6)
        typeNames{end+1} = 'Defocus'; %#ok<AGROW>
    end

    nTypes = numel(typeNames);
    if nTypes == 0
        warning('No active augmentation parameters found in trainingParam.');
        return;
    end

    nCols = 1 + nAugPerType;

%% --- Layout options pour figure 2 ---
tileW = inputSizeHW(2);
tileH = inputSizeHW(1);

margin      = 10;
extraMargin = 20;
background  = [0 0 0];

MasterRows = nTypes;
MasterCols = nCols;

figWidth  = MasterCols * tileW + (MasterCols+1)*margin;
figHeight = MasterRows * tileH + (MasterRows+1)*margin + extraMargin;

fig = figure('Name','CNN augmentation types (per single image)', ...
             'NumberTitle','off', ...
             'Units','pixels', ...
             'Position',[100 100 figWidth figHeight]);

set(fig,'Color',background);

masterTL = tiledlayout(fig, MasterRows, MasterCols, ...
    'TileSpacing','none', ...
    'Padding','tight');



    for it = 1:nTypes
        tname = typeNames{it};

        % Colonne 1 : RAW
      nexttile((it-1)*nCols + 1);
      if it==1
I = insertText(IrawRGB, [2 2], sprintf('%s RAW', tname), ...
    'FontSize', 36, 'BoxOpacity', 0, 'TextColor', 'white');
imshow(I,[]);

      end

  
I = insertText(IrawRGB, [2 40], sprintf('%s', tname), ...
    'FontSize', 36, 'BoxOpacity', 0, 'TextColor', 'white');
imshow(I,[]);

      axis image off


        % Colonnes suivantes : plusieurs augmentations de ce type
        for c = 1:nAugPerType
           nexttile((it-1)*nCols + 1 + c);
Iaug = localApplySingleAug(IrawRGB, augCfg, tname);
% Iaug = insertText(Iaug, [2 2], tname, ...
%     'FontSize', 36, 'BoxOpacity', 0, 'TextColor', 'white');
 imshow(Iaug,[]);
 axis image off

        end
    end

end

% ---------------------------------------------------------------------
% Appliquer toutes les augmentations (géométriques + photométriques)
% ---------------------------------------------------------------------
function Iout = localApplyFullAug(Iin, aug)
    I = im2double(Iin);

    % Géométrique
    % Flip
    if aug.FlipProb ~= 0 && rand < 0.5
        if rand < 0.5
            I = fliplr(I);
        else
            I = flipud(I);
        end
    end
    % Translation
    if any(abs(aug.TransRange) > 0)
        dx = (2*rand-1)*aug.TransRange(1);
        dy = (2*rand-1)*aug.TransRange(2);
        I  = imtranslate(I,[dx dy],'FillValues',median(I(:)));
    end
    % Rotation
    if any(abs(aug.RotRange) > 0)
        ang = aug.RotRange(1) + rand*(aug.RotRange(2)-aug.RotRange(1));
        I   = imrotate(I, ang,'bilinear','crop');
    end
    % Scale (zoom)
    if any(abs(aug.ScaleRange - 1) > 1e-3)
        sc = aug.ScaleRange(1) + rand*(aug.ScaleRange(2)-aug.ScaleRange(1));
        if sc ~= 1
            I = localZoomRescale(I, sc);
        end
    end

    % Photométrique
    I = localApplyPhotometric(I, aug);

    Iout = I;
end

% ---------------------------------------------------------------------
% Appliquer UNE seule augmentation (pour la figure "types x colonnes")
% ---------------------------------------------------------------------
function Iout = localApplySingleAug(Iin, aug, typeName)
    I = im2double(Iin);
    switch lower(typeName)
        case 'flip'
            if rand < 0.5
                I = fliplr(I);
            else
                I = flipud(I);
            end
        case 'translation'
            dx = (2*rand-1)*aug.TransRange(1);
            dy = (2*rand-1)*aug.TransRange(2);
            I  = imtranslate(I,[dx dy],'FillValues',median(I(:)));
        case 'rotation'
            ang = aug.RotRange(1) + rand*(aug.RotRange(2)-aug.RotRange(1));
            I   = imrotate(I, ang,'bilinear','crop');
        case 'scale'
            sc = aug.ScaleRange(1) + rand*(aug.ScaleRange(2)-aug.ScaleRange(1));
            I  = localZoomRescale(I, sc);

        case {'contrast','brightness','gamma','saturation','hue','noise','defocus'}
            % On applique uniquement la partie photométrique correspondante
            I = localApplyPhotometricSingle(I, aug, lower(typeName));
    end
    Iout = I;
end

function I = localZoomRescale(I, scale)
    % Zoom simple centré, avec crop/padding pour garder la même taille
    [H,W,~] = size(I);
    newH = round(H*scale);
    newW = round(W*scale);
    I2   = imresize(I,[newH newW]);

    if scale >= 1
        % Crop central
        y1 = floor((newH - H)/2) + 1;
        x1 = floor((newW - W)/2) + 1;
        I  = I2(y1:y1+H-1, x1:x1+W-1, :);
    else
        % Pad central
        Ipad = zeros(H,W,size(I,3));
        y1 = floor((H - newH)/2) + 1;
        x1 = floor((W - newW)/2) + 1;
        Ipad(y1:y1+newH-1, x1:x1+newW-1, :) = I2;
        I = Ipad;
    end
end

function I = localApplyPhotometric(I, aug)
    % Applique plusieurs augmentations photométriques "en série"
    % Contrast
    if any(abs(aug.ContrastRange - 1) > 1e-3)
        c = aug.ContrastRange(1) + rand*(aug.ContrastRange(2)-aug.ContrastRange(1));
        I = (I-0.5)*c + 0.5;
    end
    % Brightness
    if any(abs(aug.BrightnessRange) > 1e-6)
        b = aug.BrightnessRange(1) + rand*(aug.BrightnessRange(2)-aug.BrightnessRange(1));
        I = I + b;
    end
    % Gamma
    if any(abs(aug.GammaRange - 1) > 1e-3)
        g = aug.GammaRange(1) + rand*(aug.GammaRange(2)-aug.GammaRange(1));
        I = max(I,0); I = I.^g;
    end
    % Saturation + Hue -> on travaille en HSV
    if any(abs(aug.SaturationRange - 1) > 1e-3) || abs(aug.HueDelta) > 1e-6
        if size(I,3) == 1
            I = repmat(I,[1 1 3]);
        end
        hsv = rgb2hsv(I);
        % Saturation
        if any(abs(aug.SaturationRange - 1) > 1e-3)
            s = aug.SaturationRange(1) + rand*(aug.SaturationRange(2)-aug.SaturationRange(1));
            hsv(:,:,2) = hsv(:,:,2)*s;
        end
        % Hue
        if abs(aug.HueDelta) > 1e-6
            dh = (2*rand-1)*aug.HueDelta;
            hsv(:,:,1) = hsv(:,:,1) + dh;
        end
        hsv(:,:,2) = max(min(hsv(:,:,2),1),0);
        hsv(:,:,1) = mod(hsv(:,:,1),1);
        I = hsv2rgb(hsv);
    end
    % Noise
    if aug.NoiseSigma > 0
        sigma = aug.NoiseSigma*rand;
        I = I + sigma*randn(size(I));
    end
    % Defocus (blur)
    if any(abs(aug.DefocusSigmaRange) > 1e-6)
        s = aug.DefocusSigmaRange(1) + rand*(aug.DefocusSigmaRange(2)-aug.DefocusSigmaRange(1));
        if s > 0
            I = imgaussfilt(I,s);
        end
    end

    I = max(min(I,1),0);
end

function I = localApplyPhotometricSingle(I, aug, tname)
    if size(I,3) == 1
        I = repmat(I,[1 1 3]);
    end
    switch tname
        case 'contrast'
            if any(abs(aug.ContrastRange - 1) > 1e-3)
                c = aug.ContrastRange(1) + rand*(aug.ContrastRange(2)-aug.ContrastRange(1));
                I = (I-0.5)*c + 0.5;
            end
        case 'brightness'
            if any(abs(aug.BrightnessRange) > 1e-6)
                b = aug.BrightnessRange(1) + rand*(aug.BrightnessRange(2)-aug.BrightnessRange(1));
                I = I + b;
            end
        case 'gamma'
            if any(abs(aug.GammaRange - 1) > 1e-3)
                g = aug.GammaRange(1) + rand*(aug.GammaRange(2)-aug.GammaRange(1));
                I = max(I,0); I = I.^g;
            end
        case 'saturation'
            hsv = rgb2hsv(I);
            if any(abs(aug.SaturationRange - 1) > 1e-3)
                s = aug.SaturationRange(1) + rand*(aug.SaturationRange(2)-aug.SaturationRange(1));
                hsv(:,:,2) = hsv(:,:,2)*s;
            end
            hsv(:,:,2) = max(min(hsv(:,:,2),1),0);
            I = hsv2rgb(hsv);
        case 'hue'
            hsv = rgb2hsv(I);
            if abs(aug.HueDelta) > 1e-6
                dh = (2*rand-1)*aug.HueDelta;
                hsv(:,:,1) = mod(hsv(:,:,1) + dh,1);
            end
            I = hsv2rgb(hsv);
        case 'noise'
            if aug.NoiseSigma > 0
                sigma = aug.NoiseSigma*rand;
                I = I + sigma*randn(size(I));
            end
        case 'defocus'
            if any(abs(aug.DefocusSigmaRange) > 1e-6)
                s = aug.DefocusSigmaRange(1) + rand*(aug.DefocusSigmaRange(2)-aug.DefocusSigmaRange(1));
                if s > 0
                    I = imgaussfilt(I,s);
                end
            end
    end

    I = max(min(I,1),0);
end

