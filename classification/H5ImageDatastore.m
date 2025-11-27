classdef H5ImageDatastore < matlab.io.Datastore & ...
        matlab.io.datastore.MiniBatchable & ...
        matlab.io.datastore.Shuffleable & ...
        matlab.io.datastore.PartitionableByIndex
    %H5ImageDatastore  Datastore HDF5 pour entraînement CNN
    %
    % Hypothèse HDF5 :
    %   /frames      : [H W 3 N] uint8
    %   /labels      : [N 1] (numérique ou string)
    %   /classNames  : [K 1] string (optionnel)
    %
    % read(ds) retourne [data, labels] :
    %   data   : table avec colonne 'input' (images [H W 3] single [0,1])
    %   labels : colonne 'response' categorical
    %
    % Augmentations supportées :
    %   - TransRange         : [min max] translation en pixels (x,y)
    %   - RotRange           : [min max] rotation en degrés
    %   - CropScale          : [smin smax], s<=1 → crop-in + resize
    %   - ContrastRange      : [cmin cmax], multiplicateur de contraste
    %   - BrightnessRange    : [bmin bmax], offset additif
    %   - GammaRange         : [gmin gmax], exponent
    %   - SaturationRange    : [smin smax], multiplicateur de saturation (HSV)
    %   - HueDelta           : max ΔH (0–1), jitter dans [-HueDelta, +HueDelta]
    %   - NoiseSigma         : écart-type du bruit gaussien ajouté (0–1)
    %   - DefocusSigmaRange  : [smin smax] sigma du flou gaussien (en pixels)
    %   - DefocusProb        : probabilité d'appliquer le flou

    properties
        % Public config
        Filename           (1,:) char
        FrameDataset       (1,:) char = '/frames'
        LabelDataset       (1,:) char = '/labels'
        ClassNames                         % cellstr

        ImageSize         (1,3) double     % [H W 3]
        MiniBatchSize = 32

        % Taille de sortie (optionnelle) pour adapter au réseau CNN
        % Si vide -> on garde la taille native du HDF5
        OutputSize = []    % [H W] ou [H W 3]

        % Augmentation géométrique
        TransRange        (1,2) double = [0 0]
        RotRange          (1,2) double = [0 0]

        % Augmentations photométriques
        CropScale         (1,2) double = [1 1]
        ContrastRange     (1,2) double = [1 1]
        BrightnessRange   (1,2) double = [0 0]
        GammaRange        (1,2) double = [1 1]
        SaturationRange   (1,2) double = [1 1]
        HueDelta          (1,1) double = 0
        NoiseSigma        (1,1) double = 0
        DefocusSigmaRange (1,2) double = [0 0]
        DefocusProb       (1,1) double = 0
    end

    properties (SetAccess = protected)
        NumObservations = 0;
    end

    properties(Access = private)
        Indices
        CurrentIdx        (1,1) double = 1
        LabelsRaw
    end

    %==================================================================
    methods
        function ds = H5ImageDatastore(filename, varargin)
            % Constructor
            %
            % ds = H5ImageDatastore(filename, 'Name',Value,...)

            p = inputParser;
            p.addRequired('filename', @(x)ischar(x)||isstring(x));
            p.addParameter('FrameDataset', '/frames', @(x)ischar(x)||isstring(x));
            p.addParameter('LabelDataset', '/labels', @(x)ischar(x)||isstring(x));
            p.addParameter('MiniBatchSize', 32, @(x)isnumeric(x)&&isscalar(x)&&x>0);
            p.addParameter('TransRange', [0 0], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('RotRange', [0 0], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('CropScale', [1 1], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('ContrastRange', [1 1], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('BrightnessRange', [0 0], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('GammaRange', [1 1], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('SaturationRange', [1 1], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('HueDelta', 0, @(x)isnumeric(x)&&isscalar(x));
            p.addParameter('NoiseSigma', 0, @(x)isnumeric(x)&&isscalar(x));
            p.addParameter('DefocusSigmaRange', [0 0], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('DefocusProb', 0, @(x)isnumeric(x)&&isscalar(x));
            p.addParameter('ClassNames', [], @(x)iscellstr(x)||isstring(x)||isempty(x));
            p.parse(filename, varargin{:});

            ds.Filename      = char(p.Results.filename);
            ds.FrameDataset  = char(p.Results.FrameDataset);
            ds.LabelDataset  = char(p.Results.LabelDataset);
            ds.MiniBatchSize = p.Results.MiniBatchSize;
            ds.TransRange    = p.Results.TransRange;
            ds.RotRange      = p.Results.RotRange;
            ds.CropScale     = p.Results.CropScale;
            ds.ContrastRange   = p.Results.ContrastRange;
            ds.BrightnessRange = p.Results.BrightnessRange;
            ds.GammaRange      = p.Results.GammaRange;
            ds.SaturationRange = p.Results.SaturationRange;
            ds.HueDelta        = p.Results.HueDelta;
            ds.NoiseSigma      = p.Results.NoiseSigma;
            ds.DefocusSigmaRange = p.Results.DefocusSigmaRange;
            ds.DefocusProb     = p.Results.DefocusProb;

            if ~isempty(p.Results.ClassNames)
                ds.ClassNames = cellstr(p.Results.ClassNames);
            else
                ds.ClassNames = [];
            end

            % --- Infos sur le dataset images ---
            info = h5info(ds.Filename, ds.FrameDataset);
            sz   = info.Dataspace.Size;
            if numel(sz) ~= 4
                error('Expected /frames to have size [H W 3 N]. Got: %s', mat2str(sz));
            end
            ds.ImageSize       = sz(1:3);
            ds.NumObservations = sz(4);

            % --- Lecture des labels une fois pour toutes ---
          labs = h5read(ds.Filename, ds.LabelDataset);
labs = squeeze(labs);

% Normalisation des labels numériques potentiellement 0-based
if isnumeric(labs) && ~isempty(ds.ClassNames)
    K = numel(ds.ClassNames);
    minLab = min(labs(:));
    maxLab = max(labs(:));
    if minLab == 0 && maxLab == K-1
        fprintf('H5ImageDatastore: detected 0-based labels -> shifting by +1\n');
        labs = labs + 1;
    end
end

ds.LabelsRaw = labs;


            % Indices initiaux
            ds.Indices    = 1:ds.NumObservations;
            ds.CurrentIdx = 1;

            % ClassNames depuis HDF5 si pas fournis
            if isempty(ds.ClassNames)
                try
                    cn = h5read(ds.Filename, '/classNames');
                    ds.ClassNames = cellstr(string(cn(:)));
                catch
                    ds.ClassNames = [];
                end
            end
        end

        %--------------------------------------------------------------
        function tf = hasdata(ds)
            tf = ds.CurrentIdx <= numel(ds.Indices);
        end

        %--------------------------------------------------------------
        function [dataTbl, info] = read(ds)
            % READ  Retourne un minibatch sous forme de table B×2
            if ~hasdata(ds)
                error('No more data to read. Call reset(ds) to restart.');
            end

            startIdx = ds.CurrentIdx;
            stopIdx  = min(ds.CurrentIdx + ds.MiniBatchSize - 1, numel(ds.Indices));
            batchIdx = ds.Indices(startIdx:stopIdx);
            B = numel(batchIdx);

            H0 = ds.ImageSize(1);
            W0 = ds.ImageSize(2);
            C  = ds.ImageSize(3);

            if ~isempty(ds.OutputSize)
                osz = ds.OutputSize;
                if numel(osz) >= 2
                    H = osz(1);
                    W = osz(2);
                else
                    H = H0;
                    W = W0;
                end
            else
                H = H0;
                W = W0;
            end

            X = cell(B,1);
            labBatchRaw = ds.LabelsRaw(batchIdx);

            for k = 1:B
                idx = batchIdx(k);

                img = h5read(ds.Filename, ds.FrameDataset, ...
                    [1 1 1 idx], [H0 W0 C 1]);

                img = squeeze(img);
                if ndims(img)==2
                    img = repmat(img,[1 1 3]);
                end
                img = single(img) / 255;   % [0,1]

                % Augmentations à la taille native
                img = ds.applyAugment(img);

                % Resize vers taille cible
                if H ~= H0 || W ~= W0
                    img = imresize(img, [H W]);
                end
                
                img = uint8(img*256); % added to convert to uint8 format;

                X{k} = img;
            end

            labels = ds.formatLabels(labBatchRaw);

            ds.CurrentIdx = stopIdx + 1;

            dataTbl = table(X, labels, ...
                'VariableNames', {'input','response'});

            if nargout > 1
                info = struct();
                info.BatchIndices = batchIdx;
                info.StartIndex   = startIdx;
                info.StopIndex    = stopIdx;
            end
        end

        %--------------------------------------------------------------
        function reset(ds)
            ds.CurrentIdx = 1;
        end

        %--------------------------------------------------------------
        function dsNew = shuffle(ds)
            dsNew = copy(ds);
            dsNew.Indices    = ds.Indices(randperm(numel(ds.Indices)));
            dsNew.CurrentIdx = 1;
        end

        %--------------------------------------------------------------
        function n = numObservations(ds)
            n = numel(ds.Indices);
        end

        %--------------------------------------------------------------
        function dsNew = partition(ds, N, idx)
            arguments
                ds
                N   (1,1) double {mustBePositive}
                idx (1,1) double {mustBePositive}
            end
            if idx < 1 || idx > N
                error('partition index must be between 1 and N.');
            end
            dsNew = copy(ds);
            allIdx = ds.Indices;
            nTotal = numel(allIdx);
            edges = round(linspace(0, nTotal, N+1));
            sel = allIdx(edges(idx)+1:edges(idx+1));
            dsNew.Indices    = sel;
            dsNew.CurrentIdx = 1;
            dsNew.NumObservations = numel(dsNew.Indices);
        end

        %--------------------------------------------------------------
        function dsSub = subset(ds, idx)
            dsSub = copy(ds);
            dsSub.Indices    = ds.Indices(idx);
            dsSub.CurrentIdx = 1;
            dsSub.NumObservations = numel(dsSub.Indices);
        end

        %--------------------------------------------------------------
        function frac = progress(ds)
            frac = (ds.CurrentIdx-1) / max(1, numel(ds.Indices));
        end

        %--------------------------------------------------------------
        function dsOut = partitionByIndex(ds, indices)
            dsOut = subset(ds, indices);
        end
    end

    %==================================================================
    methods(Access = private)
        function labels = formatLabels(ds, labRaw)
            if isnumeric(labRaw)
                labRaw = labRaw(:);
                if ~isempty(ds.ClassNames)
                    K = numel(ds.ClassNames);
                    labels = categorical(labRaw, 1:K, ds.ClassNames);
                else
                    labels = categorical(labRaw);
                end
            else
                labStr = string(labRaw(:));
                if ~isempty(ds.ClassNames)
                    labels = categorical(labStr, ds.ClassNames);
                else
                    labels = categorical(labStr);
                end
            end
        end

        %----------------------------------------------------------
        function imgOut = applyAugment(ds, imgIn)
            % imgIn / imgOut : [H W 3] single [0,1]
            % Robustifié : force du réel, vérifie le nombre de canaux avant rgb2hsv.

            % --- Sécurisation de base ---
            imgOut = imgIn;

            % on s'assure qu'on a bien un type flottant réel
            if ~isfloat(imgOut)
                imgOut = im2single(imgOut);
            else
                imgOut = real(imgOut);
                imgOut = single(imgOut);
            end

            [H,W,C] = size(imgOut);

            %% 1) Crop-in (zoom) aléatoire + resize
            smin = min(ds.CropScale);
            smax = max(ds.CropScale);
            smin = max(0, smin);
            smax = min(1, smax);
            if smax < 1 || smin < 1
                scale = smin + (smax - smin)*rand();
                if scale < 1
                    hCrop = max(1, round(H * scale));
                    wCrop = max(1, round(W * scale));
                    if hCrop < H || wCrop < W
                        y0 = randi([1, H - hCrop + 1]);
                        x0 = randi([1, W - wCrop + 1]);
                        imgCrop = imgOut(y0:y0+hCrop-1, x0:x0+wCrop-1, :);
                        imgOut  = imresize(imgCrop, [H W]);
                    end
                end
            end

            %% 2) Translation aléatoire
            tx = 0; ty = 0;
            if any(ds.TransRange ~= 0)
                tx = ds.TransRange(1) + ...
                    (ds.TransRange(2)-ds.TransRange(1))*rand();
                ty = ds.TransRange(1) + ...
                    (ds.TransRange(2)-ds.TransRange(1))*rand();
            end
            if tx ~= 0 || ty ~= 0
                imgOut = imtranslate(imgOut, [tx ty], ...
                    'FillValues',0, ...
                    'OutputView','same');
            end

            %% 3) Rotation aléatoire
            theta = 0;
            if any(ds.RotRange ~= 0)
                theta = ds.RotRange(1) + ...
                    (ds.RotRange(2)-ds.RotRange(1))*rand();
            end
            if theta ~= 0
                imgOut = imrotate(imgOut, theta, 'bilinear', 'crop');
            end

            %% 4) Contraste
            if any(ds.ContrastRange ~= 1)
                cmin = ds.ContrastRange(1);
                cmax = ds.ContrastRange(2);
                alpha = cmin + (cmax - cmin)*rand();
                imgOut = (imgOut - 0.5) * alpha + 0.5;
            end

            %% 5) Teinte (Hue) - seulement si 3 canaux et HueDelta > 0
            if ds.HueDelta > 0 && size(imgOut,3) == 3
                % on s'assure encore une fois que c'est bien un float réel dans [0,1]
                imgOut = real(imgOut);
                imgOut = min(max(imgOut,0),1);

                delta = (2*rand() - 1) * ds.HueDelta;
                hsv = rgb2hsv(imgOut);
                h = hsv(:,:,1) + delta;
                h = h - floor(h);      % wrap modulo 1
                hsv(:,:,1) = h;
                imgOut = hsv2rgb(hsv);
            end

            %% 6) Bruit gaussien
            if ds.NoiseSigma > 0
                % randn produit du réel, mais on force le type cohérent avec imgOut
                noise = ds.NoiseSigma * randn(size(imgOut), 'like', imgOut);
                imgOut = imgOut + noise;
            end

            %% 7) Clamping final & sécurité "réel"
            imgOut = real(imgOut);
            imgOut = min(max(imgOut, 0), 1);
        end
    end
end
