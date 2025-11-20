classdef H5ImageDatastore < matlab.io.Datastore & ...
                             matlab.io.datastore.MiniBatchable & ...
                             matlab.io.datastore.Shuffleable & ...
                             matlab.io.datastore.PartitionableByIndex
    %H5ImageDatastore  Datastore HDF5 pour entraînement CNN
    %
    %   Hypothèse HDF5 :
    %       /frames      : [H W 3 N] uint8
    %       /labels      : [N 1] (numérique ou string)
    %       /classNames  : [K 1] string (optionnel)
    %
    %   read(ds) retourne [data, labels] :
    %       data   : [H W 3 B] single in [0,1]
    %       labels : [B 1] categorical
    %
    %   Augmentations supportées :
    %       - TransRange     : [min max] translation en pixels (x,y)
    %       - RotRange       : [min max] rotation en degrés
    %       - CropScale      : [smin smax], s<=1 → crop-in + resize
    %       - ContrastRange  : [cmin cmax], multiplicateur de contraste
    %       - HueDelta       : max ΔH (0–1), jitter dans [-HueDelta, +HueDelta]
    %       - NoiseSigma     : écart-type du bruit gaussien ajouté

    properties
        % Public config
        Filename           (1,:) char
        FrameDataset       (1,:) char = '/frames'
        LabelDataset       (1,:) char = '/labels'
        ClassNames                         % cellstr

        ImageSize         (1,3) double     % [H W 3]
        MiniBatchSize     (1,1) double = 32

        % Augmentation geo basique
        TransRange        (1,2) double = [0 0]   % ex: [-5 5]
        RotRange          (1,2) double = [0 0]   % ex: [-20 20]

        % Augmentation supplémentaires
        CropScale         (1,2) double = [1 1]   % ex: [0.8 1.0] (crop-in)
        ContrastRange     (1,2) double = [1 1]   % ex: [0.8 1.2]
        HueDelta          (1,1) double = 0       % ex: 0.05 -> ±0.05
        NoiseSigma        (1,1) double = 0       % ex: 0.02 (sur [0,1])
    end

    properties(Access = private)
        NumObs            (1,1) double = 0      % total frames
        Indices                         % indices logiques (ordre de lecture)
        CurrentIdx        (1,1) double = 1
        LabelsRaw                       % labels tels que stockés dans HDF5
    end

    %==================================================================
    methods
        function ds = H5ImageDatastore(filename, varargin)
            % Constructor
            %
            % ds = H5ImageDatastore(filename, 'Name',Value,...)
            %
            % Options:
            %   'FrameDataset'   : chemin dataset images
            %   'LabelDataset'   : chemin dataset labels
            %   'MiniBatchSize'  : taille minibatch
            %   'TransRange'     : [min max] translation
            %   'RotRange'       : [min max] rotation
            %   'CropScale'      : [smin smax] (s<=1 pour crop-in)
            %   'ContrastRange'  : [cmin cmax]
            %   'HueDelta'       : scalar max ΔH (0–0.5 conseillé)
            %   'NoiseSigma'     : sigma du bruit gaussien
            %   'ClassNames'     : cellstr ou string (ordre des classes)

            p = inputParser;
            p.addRequired('filename', @(x)ischar(x)||isstring(x));
            p.addParameter('FrameDataset', '/frames', @(x)ischar(x)||isstring(x));
            p.addParameter('LabelDataset', '/labels', @(x)ischar(x)||isstring(x));
            p.addParameter('MiniBatchSize', 32, @(x)isnumeric(x)&&isscalar(x)&&x>0);
            p.addParameter('TransRange', [0 0], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('RotRange', [0 0], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('CropScale', [1 1], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('ContrastRange', [1 1], @(x)isnumeric(x)&&numel(x)==2);
            p.addParameter('HueDelta', 0, @(x)isnumeric(x)&&isscalar(x));
            p.addParameter('NoiseSigma', 0, @(x)isnumeric(x)&&isscalar(x));
            p.addParameter('ClassNames', [], @(x)iscellstr(x)||isstring(x)||isempty(x));
            p.parse(filename, varargin{:});

            ds.Filename      = char(p.Results.filename);
            ds.FrameDataset  = char(p.Results.FrameDataset);
            ds.LabelDataset  = char(p.Results.LabelDataset);
            ds.MiniBatchSize = p.Results.MiniBatchSize;
            ds.TransRange    = p.Results.TransRange;
            ds.RotRange      = p.Results.RotRange;
            ds.CropScale     = p.Results.CropScale;
            ds.ContrastRange = p.Results.ContrastRange;
            ds.HueDelta      = p.Results.HueDelta;
            ds.NoiseSigma    = p.Results.NoiseSigma;

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
            ds.ImageSize = sz(1:3);
            ds.NumObs    = sz(4);

            % --- Lecture des labels une fois pour toutes ---
            labs = h5read(ds.Filename, ds.LabelDataset);
            labs = squeeze(labs);
            if numel(labs) ~= ds.NumObs
                error('Labels length (%d) does not match number of frames (%d).', ...
                    numel(labs), ds.NumObs);
            end
            ds.LabelsRaw = labs;

            % --- ClassNames depuis HDF5 si pas fournis ---
            if isempty(ds.ClassNames)
                try
                    cn = h5read(ds.Filename, '/classNames');
                    ds.ClassNames = cellstr(string(cn(:)));
                catch
                    ds.ClassNames = [];
                end
            end

            % Indices initiaux
            ds.Indices    = 1:ds.NumObs;
            ds.CurrentIdx = 1;
        end

        %--------------------------------------------------------------
        function tf = hasdata(ds)
            tf = ds.CurrentIdx <= numel(ds.Indices);
        end

        %--------------------------------------------------------------
        function [data, labels] = read(ds)
            % READ  Retourne un minibatch [data, labels]
            %
            % data   : [H W 3 B] single in [0,1]
            % labels : [B 1] categorical

            if ~hasdata(ds)
                error('No more data to read. Call reset(ds) to restart.');
            end

            % indices de ce batch
            startIdx = ds.CurrentIdx;
            stopIdx  = min(ds.CurrentIdx + ds.MiniBatchSize - 1, numel(ds.Indices));
            batchIdx = ds.Indices(startIdx:stopIdx);
            B = numel(batchIdx);

            H = ds.ImageSize(1);
            W = ds.ImageSize(2);
            C = ds.ImageSize(3);

            data = zeros(H, W, C, B, 'single');
            labBatchRaw = ds.LabelsRaw(batchIdx);

            % --- Lecture frame par frame + augmentation ---
            for k = 1:B
                idx = batchIdx(k);
                % HDF5 indices 1-based -> [1 1 1 idx] / [H W 3 1]
                img = h5read(ds.Filename, ds.FrameDataset, ...
                             [1 1 1 idx], [H W C 1]);

                img = squeeze(img);
                if ndims(img)==2
                    img = repmat(img,[1 1 3]);
                end
                img = single(img) / 255; % normalisation simple [0,1]

                img = ds.applyAugment(img);

                data(:,:,:,k) = img;
            end

            % --- Labels -> categorical ---
            labels = ds.formatLabels(labBatchRaw);

            % avance le pointeur
            ds.CurrentIdx = stopIdx + 1;
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
            % partition pour multi-GPU ou splits
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
        end

        %--------------------------------------------------------------
        function dsSub = subset(ds, idx)
            dsSub = copy(ds);
            dsSub.Indices    = ds.Indices(idx);
            dsSub.CurrentIdx = 1;
        end

        %--------------------------------------------------------------
        function frac = progress(ds)
            frac = (ds.CurrentIdx-1) / max(1, numel(ds.Indices));
        end

        %--------------------------------------------------------------
        function dsCopy = copy(ds)
            % helper pour créer un "clone" simple
            dsCopy = H5ImageDatastore(ds.Filename, ...
                'FrameDataset',  ds.FrameDataset, ...
                'LabelDataset',  ds.LabelDataset, ...
                'MiniBatchSize', ds.MiniBatchSize, ...
                'TransRange',    ds.TransRange, ...
                'RotRange',      ds.RotRange, ...
                'CropScale',     ds.CropScale, ...
                'ContrastRange', ds.ContrastRange, ...
                'HueDelta',      ds.HueDelta, ...
                'NoiseSigma',    ds.NoiseSigma, ...
                'ClassNames',    ds.ClassNames ...
                );
            dsCopy.Indices    = ds.Indices;
            dsCopy.CurrentIdx = ds.CurrentIdx;
        end
    end

    %==================================================================
    methods(Access = private)
        function labels = formatLabels(ds, labRaw)
            % labRaw peut être numeric, char, string...
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
            imgOut = imgIn;
            [H,W,~] = size(imgOut);

            %% 1) Crop-in (zoom) aléatoire + resize
            % On suppose CropScale dans [smin smax], avec s<=1 pour crop-in
            smin = min(ds.CropScale);
            smax = max(ds.CropScale);
            smin = max(0, smin);
            smax = min(1, smax);
            if smax < 1 || smin < 1
                scale = smin + (smax - smin)*rand();
                if scale < 1
                    hCrop = max(1, round(H * scale));
                    wCrop = max(1, round(W * scale));
                    y0 = randi([1, H - hCrop + 1]);
                    x0 = randi([1, W - wCrop + 1]);
                    imgCrop = imgOut(y0:y0+hCrop-1, x0:x0+wCrop-1, :);
                    imgOut = imresize(imgCrop, [H W]);
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
                imgOut = imrotate(imgOut, theta, ...
                                  'bilinear', 'crop');
            end

            %% 4) Contraste
            if any(ds.ContrastRange ~= 1)
                cmin = ds.ContrastRange(1);
                cmax = ds.ContrastRange(2);
                alpha = cmin + (cmax - cmin)*rand();
                imgOut = (imgOut - 0.5) * alpha + 0.5;
            end

            %% 5) Teinte (Hue)
            if ds.HueDelta > 0
                % ΔH dans [-HueDelta, +HueDelta]
                delta = (2*rand() - 1) * ds.HueDelta;
                hsv = rgb2hsv(imgOut);
                h = hsv(:,:,1) + delta;
                % wrap modulo 1
                h = h - floor(h);
                hsv(:,:,1) = h;
                imgOut = hsv2rgb(hsv);
            end

            %% 6) Bruit gaussien
            if ds.NoiseSigma > 0
                imgOut = imgOut + ds.NoiseSigma * randn(size(imgOut), 'like', imgOut);
            end

            %% 7) Clamping final
            imgOut = min(max(imgOut, 0), 1);
        end
    end
end
