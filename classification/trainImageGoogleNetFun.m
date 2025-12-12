function trainImageGoogleNetFun(classif,setparam,inputnetwork,varargin)

path = fullfile(classif.path);
name = classif.strid;

flagCNN = [];

% ------------------------------------------------------------
% Logger control (default: create a new run)
% ------------------------------------------------------------
attachRun = false;
if ~isempty(varargin)
    for k = 1:2:numel(varargin)
        if k+1 <= numel(varargin) && ischar(varargin{k}) || (isstring(varargin{k}) && isscalar(varargin{k}))
            key = lower(string(varargin{k}));
            switch key
                case "attachrun"
                    attachRun = logical(varargin{k+1});
            end
        end
    end
end

%---------------- parameters setting
if nargin==2 % basic parameter initialization

    tip = { ...
        'Choose the training method', ...
        'Choose the CNN', ...
        'Choose the size of the mini batch; Higher values require more memory and are prone to errors', ...
        'Enter the number of epochs', ...
        'Enter the initial learning rate', ...
        'Enter the learning rate drop factor', ...
        'Choose whether and how training and validation data should be shuffled during training', ...
        'Enter fraction of the data to be used for training vs validation during training', ...
        'Enter the magnitude of translation for data augmentation (in pixels)', ...
        'Enter the magnitude of rotation for data augmentation (in degrees)', ...
        'Specify value for L2 regularization', ...
        'Check to use a dropout layer', ...
        'Value for dropout regularization', ...
        'Choose execution environment', ...
        'Select initial version of network to start training with; Default: ImageNet', ...
        'Range of random scale factor for CNN augmentation (e.g. [0.8 1.0])', ...
        'Enable random flips (left/right & up/down) during CNN augmentation', ...
        'Crop-in scale range for CNN augmentation (e.g. [0.8 1.0])', ...
        'Contrast multiplier range for CNN augmentation (e.g. [0.85 1.15])', ...
        'Brightness offset range (additive, e.g. [-0.10 0.10])', ...
        'Gamma exponent range for CNN augmentation (e.g. [0.9 1.1])', ...
        'Saturation multiplier range (RGB only, e.g. [0.95 1.05])', ...
        'Maximum hue jitter (0–0.5, small values recommended)', ...
        'Std-dev of Gaussian noise for CNN augmentation (set 0 to disable)', ...
        'Defocus sigma range in pixels (e.g. [0.3 1.0])', ...
        'Probability to apply defocus blur (e.g. 0.5)', ...
        'Fraction of ROIs used when formatting the LSTM training set', ...       % Format_Fraction
        'Random seed used when sampling ROIs / frames for formatting', ...       % Format_Seed
        'Enable cropping when formatting the LSTM training set (true/false)',... % Format_Crop
        'Crop center [cx cy] used for formatting the LSTM training set', ...     % Format_CropCenter
        'Crop size [w h] used for formatting the LSTM training set', ...         % Format_CropSize
        'Undersample majority classes (1 = no undersampling)', ...               % Format_UndersampleMajority
        'Storage backend for formatted data (''hdf5'' or ''tiff'')' ...          % Format_StorageBackend
        };

    classif.trainingParam = struct( ...
        'CNN_training_method',{{'adam','sgdm','adam'}}, ...
        'CNN_network',{{'googlenet','inceptionresnetv2','inceptionv3','resnet18','resnet50','resnet101','nasnetlarge','inceptionresnetv2','efficientnetb0','googlenet'}}, ...
        'CNN_mini_batch_size',8, ...
        'CNN_max_epochs',6, ...
        'CNN_initial_learning_rate',0.0003, ...
        'CNN_learn_rate_drop_factor',0.9, ...
        'CNN_data_shuffling',{{'once','every-epoch','never','every-epoch'}}, ...
        'CNN_data_splitting_factor',0.7, ...
        'CNN_translation_augmentation',[-5 5], ...
        'CNN_rotation_augmentation',[-20 20], ...
        'CNN_l2_regularization',0.0001, ...
        'CNN_use_dropout',true, ...
        'CNN_dropout',0.5, ...
        'execution_environment',{{'auto','parallel','cpu','gpu','multi-gpu','auto'}}, ...
        'transfer_learning',{{'ImageNet','ImageNet'}}, ...
        'CNN_rand_scale',[0.8 1.0], ...
        'CNN_rand_flip',true, ...
        'CNN_crop_scale',[0.8 1.0], ...
        'CNN_contrast_range',[1 1], ...
        'CNN_brightness_range',[0 0], ...
        'CNN_gamma_range',[1 1], ...
        'CNN_saturation_range',[1 1], ...
        'CNN_hue_delta',0, ...
        'CNN_noise_sigma',0, ...
        'CNN_defocus_sigma_range',[0 0], ...
        'CNN_defocus_prob',0, ...
        'Format_Fraction',1.0, ...
        'Format_Seed',12345, ...
        'Format_Crop',false, ...
        'Format_CropCenter',[88 194], ...
        'Format_CropSize',[60 60], ...
        'Format_UndersampleMajority',1.0, ...
        'Format_StorageBackend',{{'hdf5','tiff','hdf5'}}, ...
        'tip',{tip} ...
        );
    return;

else
    trainingParam = classif.trainingParam;

    % ==== Backward compatibility defaults ====
    if ~isfield(trainingParam,'CNN_use_dropout');        trainingParam.CNN_use_dropout = true;  end
    if ~isfield(trainingParam,'CNN_dropout');            trainingParam.CNN_dropout     = 0.5;   end
    if ~isfield(trainingParam,'CNN_learn_rate_drop_factor')
        trainingParam.CNN_learn_rate_drop_factor = 0.9;
    end

    if ~isfield(trainingParam,'CNN_storage_backend'); trainingParam.CNN_storage_backend = {'hdf5','tiff','hdf5'}; end

    if ~isfield(trainingParam,'CNN_rand_scale') && ~isfield(trainingParam,'CNN_crop_scale')
        trainingParam.CNN_rand_scale = [0.8 1.0];
        trainingParam.CNN_crop_scale = [0.8 1.0];
    elseif ~isfield(trainingParam,'CNN_rand_scale') && isfield(trainingParam,'CNN_crop_scale')
        trainingParam.CNN_rand_scale = trainingParam.CNN_crop_scale;
    elseif ~isfield(trainingParam,'CNN_crop_scale') && isfield(trainingParam,'CNN_rand_scale')
        trainingParam.CNN_crop_scale = trainingParam.CNN_rand_scale;
    end

    if ~isfield(trainingParam,'CNN_rand_flip');      trainingParam.CNN_rand_flip      = true;   end
    if ~isfield(trainingParam,'CNN_contrast_range'); trainingParam.CNN_contrast_range = [1 1];  end
    if ~isfield(trainingParam,'CNN_brightness_range'); trainingParam.CNN_brightness_range = [0 0]; end
    if ~isfield(trainingParam,'CNN_gamma_range');      trainingParam.CNN_gamma_range  = [1 1];  end
    if ~isfield(trainingParam,'CNN_saturation_range'); trainingParam.CNN_saturation_range = [1 1]; end
    if ~isfield(trainingParam,'CNN_hue_delta');      trainingParam.CNN_hue_delta      = 0;      end
    if ~isfield(trainingParam,'CNN_noise_sigma');    trainingParam.CNN_noise_sigma    = 0;      end
    if ~isfield(trainingParam,'CNN_defocus_sigma_range'); trainingParam.CNN_defocus_sigma_range = [0 0]; end
    if ~isfield(trainingParam,'CNN_defocus_prob');       trainingParam.CNN_defocus_prob = 0;    end

    classif.trainingParam = trainingParam;

    if numel(trainingParam)==0
        disp('Could not find training parameters : first launch train with an extra argument to force parameter assignment');
        return;
    end

    if nargin>=3 && ~isempty(inputnetwork)
        flagCNN = inputnetwork;
    end
end
%-----------------------------------%

% ---- local helper: stop only if we started the run ourselves ----
startedRunHere = false;
    function safeRunStop()
        if ~attachRun && startedRunHere
            try
                classif.runStop();
            catch
            end
        end
    end

try
    if ~attachRun
        classif.runStart('trainImageGoogleNetFun', trainingParam, 'Attach', true);
        startedRunHere = true;
        classif.runMsg('CNN backend=%s', trainingParam.Format_StorageBackend{end});
    else
        % We are inside a parent run (e.g., LSTM); just log a step.
        try
            classif.runMsg('CNN step (attachRun=true) backend=%s', trainingParam.Format_StorageBackend{end});
        catch
        end
    end


    blockRNG = 1;

    disablePhotometricAug = false;
    if disablePhotometricAug
        fprintf('Photometric augmentations are disabled\n');

        if isfield(trainingParam,'CNN_contrast_range'),      trainingParam.CNN_contrast_range = [1 1]; end
        if isfield(trainingParam,'CNN_brightness_range'),    trainingParam.CNN_brightness_range = [0 0]; end
        if isfield(trainingParam,'CNN_gamma_range'),         trainingParam.CNN_gamma_range = [1 1]; end
        if isfield(trainingParam,'CNN_saturation_range'),    trainingParam.CNN_saturation_range = [1 1]; end
        if isfield(trainingParam,'CNN_hue_delta'),           trainingParam.CNN_hue_delta = 0; end
        if isfield(trainingParam,'CNN_noise_sigma'),         trainingParam.CNN_noise_sigma = 0; end
        if isfield(trainingParam,'CNN_defocus_sigma_range'), trainingParam.CNN_defocus_sigma_range = [0 0]; end
        if isfield(trainingParam,'CNN_defocus_prob'),        trainingParam.CNN_defocus_prob = 0; end
    end

    fprintf('Loading data repository...\n');
    fprintf('------\n');

    backend = lower(trainingParam.Format_StorageBackend{end});

    %----------------------------------------------------------------------    
    % 1) Datastores train/val + class weights
    %----------------------------------------------------------------------    
    switch backend
        case 'tiff'
            foldername = fullfile(path,'trainingdataset','images');
            if ~exist(foldername,"dir")
                disp('Folder does not exist; first export images for training; quitting !')
                safeRunStop();
                return;
            end

            imds = imageDatastore(foldername, ...
                'IncludeSubfolders',true, ...
                'LabelSource','foldernames');

            fprintf('------\n');

            [imdsTrain,imdsValidation] = splitEachLabel(imds, ...
                trainingParam.CNN_data_splitting_factor);

            tbl = countEachLabel(imdsTrain);
            cnt = tbl.Count;
            cnt(cnt==0) = 1;
            classWeights = 1 ./ cnt;
            classWeights = classWeights' / mean(classWeights);
            classWeights(~isfinite(classWeights)) = 1;

            fprintf('--- CNN class weights (TRAIN) ---\n');
            for i = 1:numel(classif.classes)
                labName = char(classif.classes{i});
                ix = find(tbl.Label == labName);
                if isempty(ix), n = 0; else, n = tbl.Count(ix); end
                fprintf('  %s : count = %d, weight = %.3f\n', labName, n, classWeights(i));
            end
            fprintf('-------------------------------\n');

            imdsTrainPhot = imageDatastore(imdsTrain.Files, ...
                'Labels', imdsTrain.Labels, ...
                'IncludeSubfolders', false);
            imdsTrainPhot.ReadFcn = @(fn) CNN_photometricReadFcn(fn, trainingParam);

            pixelRange = trainingParam.CNN_translation_augmentation;
            rotation   = trainingParam.CNN_rotation_augmentation;
            scaleRange = trainingParam.CNN_rand_scale;
            if numel(scaleRange) ~= 2, scaleRange = [0.8 1.0]; end

            imageAugmenter = imageDataAugmenter( ...
                'RandXReflection',trainingParam.CNN_rand_flip, ...
                'RandYReflection',trainingParam.CNN_rand_flip, ...
                'RandScale',scaleRange, ...
                'RandXTranslation',pixelRange, ...
                'RandYTranslation',pixelRange, ...
                'RandRotation',rotation);

            dataTrain   = imdsTrainPhot;
            dataValBase = imdsValidation;
            useHDF5     = false;

        case 'hdf5'
            pattern = sprintf('%s_framebank*.h5', classif.strid);
            d = dir(fullfile(path, pattern));

            if isempty(d)
                fprintf('HDF5 framebank file not found for this classification.\n');
                fprintf('Expected pattern: %s in folder: %s\n', pattern, path);
                fprintf('Export HDF5 training data first (Format LSTM dataset, backend = HDF5). Quitting!\n');
                safeRunStop();
                return;
            end

            [~, idxSort] = sort([d.datenum], 'descend');
            d = d(idxSort);

            h5File = '';
            for k = 1:numel(d)
                cand = fullfile(d(k).folder, d(k).name);
                try
                    h5info(cand);
                    h5File = cand;
                    break;
                catch ME
                    warning('[WARN] Unreadable framebank candidate %s (%s). Skipping...', cand, ME.message);
                end
            end

            if isempty(h5File)
                fprintf('No readable HDF5 framebank found for pattern %s in %s.\n', pattern, path);
                fprintf('You may have a corrupted/locked old file. Delete it manually then re-format.\n');
                safeRunStop();
                return;
            end

            fprintf('[INFO] Using framebank for CNN training: %s\n', h5File);

            augParams = localGetH5AugParams(trainingParam);

            dsAll = H5ImageDatastore(h5File, ...
                'MiniBatchSize',      trainingParam.CNN_mini_batch_size, ...
                'TransRange',         augParams.TransRange, ...
                'RotRange',           augParams.RotRange, ...
                'CropScale',          augParams.CropScale, ...
                'ContrastRange',      augParams.ContrastRange, ...
                'BrightnessRange',    augParams.BrightnessRange, ...
                'GammaRange',         augParams.GammaRange, ...
                'SaturationRange',    augParams.SaturationRange, ...
                'HueDelta',           augParams.HueDelta, ...
                'NoiseSigma',         augParams.NoiseSigma, ...
                'DefocusSigmaRange',  augParams.DefocusSigmaRange, ...
                'DefocusProb',        augParams.DefocusProb, ...
                'ClassNames',         classif.classes);

            fracTrain = trainingParam.CNN_data_splitting_factor;
            [idxTrain, idxVal, labsTrain, labsVal] = localSplitTrainValH5( ...
                h5File, classif.classes, fracTrain, true);

            if isempty(idxTrain)
                disp('No observations found in HDF5 dataset; quitting !');
                safeRunStop();
                return;
            end

            dsTrain = subset(dsAll, idxTrain);
            dsVal   = subset(dsAll, idxVal);

            dsVal.TransRange        = [0 0];
            dsVal.RotRange          = [0 0];
            dsVal.CropScale         = [1 1];
            dsVal.ContrastRange     = [1 1];
            dsVal.BrightnessRange   = [0 0];
            dsVal.GammaRange        = [1 1];
            dsVal.SaturationRange   = [1 1];
            dsVal.HueDelta          = 0;
            dsVal.NoiseSigma        = 0;
            dsVal.DefocusSigmaRange = [0 0];
            dsVal.DefocusProb       = 0;

            cnt = countcats(labsTrain);
            cnt(cnt==0) = 1;
            classWeights = 1 ./ cnt;
            classWeights = classWeights' / mean(classWeights);
            classWeights(~isfinite(classWeights)) = 1;

            dataTrain   = dsTrain;
            dataValBase = dsVal;
            useHDF5     = true;

        otherwise
            error('Unsupported backend: %s', backend);
    end

    classif.runSave('CNN_split.mat', ...
        'backend', backend, ...
        'miniBatchSize', trainingParam.CNN_mini_batch_size, ...
        'classWeights', classWeights);

    %----------------------------------------------------------------------    
    % 2) Classes
    %----------------------------------------------------------------------    
    classes = classif.classes;
    if numel(classes)==0
        disp('There is no classes defined ; Cannot continue !')
        safeRunStop();
        return;
    end

    fprintf('Loading network...\n');
    fprintf('------\n');

    %----------------------------------------------------------------------    
    % 3) Backbone
    %----------------------------------------------------------------------    
    if strcmp(trainingParam.transfer_learning{end},'ImageNet')
        disp('Generating new network');
        net = eval(trainingParam.CNN_network{end});

        fprintf('Reformatting net for transfer learning...\n');
        fprintf('------\n');

        if isa(net,'SeriesNetwork')
            lgraph = layerGraph(net.Layers);
        else
            lgraph = layerGraph(net);
        end

    else
        disp(['Loading previously trained CNN network associated with: ' trainingParam.transfer_learning{end}]);
        if numel(flagCNN)
            lgraph = layerGraph(flagCNN);
            net    = flagCNN;
        else
            strpth = fullfile(classif.path, trainingParam.transfer_learning{end});
            if exist(strpth,"file") || exist([strpth '.mat'],"file")
                load(strpth); % loads 'classifier'
                lgraph = layerGraph(classifier);
                net    = classifier;
            else
                disp(['Unable to load: ' trainingParam.transfer_learning{end}]);
                safeRunStop();
                return;
            end
        end
    end

    % ===== Insert/adjust DROPOUT before we swap heads =====
    [learnableLayer,classLayer] = findLayersToReplace(lgraph);

    if trainingParam.CNN_use_dropout
        netName = lower(trainingParam.CNN_network{end});
        pDrop   = trainingParam.CNN_dropout;

        if contains(netName,'googlenet')
            if any(strcmp({lgraph.Layers.Name}, 'pool5-drop_7x7_s1'))
                lgraph = replaceLayer(lgraph,'pool5-drop_7x7_s1', ...
                    dropoutLayer(pDrop,'Name','pool5-drop_7x7_s1'));
                fprintf('Applied dropout %.2f to GoogLeNet (pool5-drop_7x7_s1).\n', pDrop);
            else
                if any(strcmp({lgraph.Layers.Name}, 'pool5-7x7_s1'))
                    if ~any(strcmp({lgraph.Layers.Name},'custom_dropout'))
                        lgraph = addLayers(lgraph, dropoutLayer(pDrop,'Name','custom_dropout'));
                        lgraph = disconnectLayers(lgraph,'pool5-7x7_s1',learnableLayer.Name);
                        lgraph = connectLayers(lgraph,'pool5-7x7_s1','custom_dropout');
                        lgraph = connectLayers(lgraph,'custom_dropout',learnableLayer.Name);
                        fprintf('Inserted custom dropout %.2f before final head (GoogLeNet).\n', pDrop);
                    end
                end
            end

        elseif contains(netName,'resnet18') || contains(netName,'resnet50')
            if any(strcmp({lgraph.Layers.Name},'avg_pool'))
                if ~any(strcmp({lgraph.Layers.Name},'custom_dropout'))
                    lgraph = addLayers(lgraph, dropoutLayer(pDrop,'Name','custom_dropout'));
                    if any(strcmp(lgraph.Connections.Source,'avg_pool') & strcmp(lgraph.Connections.Destination,learnableLayer.Name))
                        lgraph = disconnectLayers(lgraph,'avg_pool',learnableLayer.Name);
                    else
                        nextIdx = strcmp(lgraph.Connections.Source,'avg_pool');
                        nextDest = lgraph.Connections.Destination(nextIdx);
                        for ii=1:numel(nextDest)
                            lgraph = disconnectLayers(lgraph,'avg_pool',nextDest{ii});
                        end
                    end
                    lgraph = connectLayers(lgraph,'avg_pool','custom_dropout');
                    lgraph = connectLayers(lgraph,'custom_dropout',learnableLayer.Name);
                    fprintf('Inserted custom dropout %.2f after avg_pool (ResNet).\n', pDrop);
                end
            else
                warning('avg_pool not found; skipping dropout insertion for ResNet.');
            end
        else
            if ~any(strcmp({lgraph.Layers.Name},'custom_dropout'))
                lgraph = addLayers(lgraph, dropoutLayer(pDrop,'Name','custom_dropout'));
                srcMask = strcmp(lgraph.Connections.Destination, learnableLayer.Name);
                srcNames = lgraph.Connections.Source(srcMask);
                for ii=1:numel(srcNames)
                    lgraph = disconnectLayers(lgraph, srcNames{ii}, learnableLayer.Name);
                    lgraph = connectLayers(lgraph, srcNames{ii}, 'custom_dropout');
                end
                lgraph = connectLayers(lgraph,'custom_dropout',learnableLayer.Name);
                fprintf('Inserted custom dropout %.2f before final head (generic path).\n', pDrop);
            end
        end
    end
    % ===== End DROPOUT insertion =====

    [learnableLayer,classLayer] = findLayersToReplace(lgraph);

    numClasses = numel(classes);
    if isa(learnableLayer,'nnet.cnn.layer.FullyConnectedLayer')
        newLearnableLayer = fullyConnectedLayer(numClasses, ...
            'Name','new_fc', ...
            'WeightLearnRateFactor',1, ...
            'BiasLearnRateFactor',1);
    elseif isa(learnableLayer,'nnet.cnn.layer.Convolution2DLayer')
        newLearnableLayer = convolution2dLayer(1,numClasses, ...
            'Name','new_conv', ...
            'WeightLearnRateFactor',1, ...
            'BiasLearnRateFactor',1);
    else
        error('Unsupported learnable layer type: %s', class(learnableLayer));
    end

    lgraph = replaceLayer(lgraph,learnableLayer.Name,newLearnableLayer);

    conns = lgraph.Connections;
    mask  = strcmp(conns.Destination, classLayer.Name);

    if any(mask)
        softmaxLayerName = conns.Source{find(mask,1,'first')};
    else
        isSoft = arrayfun(@(L) isa(L,'nnet.cnn.layer.SoftmaxLayer'), lgraph.Layers);
        if any(isSoft)
            softmaxLayerName = lgraph.Layers(find(isSoft,1,'first')).Name;
        else
            error('Impossible de trouver une couche Softmax connectée à %s.', classLayer.Name);
        end
    end

    if isa(classLayer,'nnet.cnn.layer.ClassificationOutputLayer')
        lgraph = removeLayers(lgraph, classLayer.Name);
    end

    inputSize = net.Layers(1).InputSize;

    fprintf('Training network...\n');
    fprintf('------\n');

    if blockRNG==1
        stCPU= RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
        stGPU=parallel.gpu.RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
        RandStream.setGlobalStream(stCPU);
        parallel.gpu.RandStream.setGlobalStream(stGPU);
    end

    %----------------------------------------------------------------------    
    % 4) final datastore wrappers
    %----------------------------------------------------------------------    
    miniBatchSize = trainingParam.CNN_mini_batch_size;
    patience = 10;

    switch backend
        case 'tiff'
            pixelRange = trainingParam.CNN_translation_augmentation;
            rotation   = trainingParam.CNN_rotation_augmentation;
            scaleRange = trainingParam.CNN_rand_scale;
            if numel(scaleRange) ~= 2, scaleRange = [0.8 1.0]; end

            imageAugmenter = imageDataAugmenter( ...
                'RandXReflection',trainingParam.CNN_rand_flip, ...
                'RandYReflection',trainingParam.CNN_rand_flip, ...
                'RandScale',scaleRange, ...
                'RandXTranslation',pixelRange, ...
                'RandYTranslation',pixelRange, ...
                'RandRotation',rotation);

            augimdsTrain = augmentedImageDatastore(inputSize(1:2), dataTrain, ...
                'DataAugmentation', imageAugmenter);

            augimdsValidation = augmentedImageDatastore(inputSize(1:2), dataValBase);

            valFrequency = floor(max(1, numel(augimdsTrain.Files)/miniBatchSize));

            trainingData   = augimdsTrain;
            validationData = augimdsValidation;

        case 'hdf5'
            nTrainObs = numObservations(dataTrain);
            valFrequency = floor(max(1, nTrainObs / miniBatchSize));
            trainingData   = dataTrain;
            validationData = dataValBase;
    end

    if exist('useHDF5','var') && useHDF5
        targetHW = inputSize(1:2);
        trainingData.OutputSize   = targetHW;
        validationData.OutputSize = targetHW;
    end

    %----------------------------------------------------------------------    
    % 5) trainnet
    %----------------------------------------------------------------------    
    outputLayerName = softmaxLayerName;
    dlNet = dlnetwork(lgraph, "OutputNames", outputLayerName);

    options = trainingOptions(trainingParam.CNN_training_method{end}, ...
        "MiniBatchSize",        miniBatchSize, ...
        "MaxEpochs",            trainingParam.CNN_max_epochs, ...
        "InitialLearnRate",     trainingParam.CNN_initial_learning_rate, ...
        "LearnRateSchedule",    "piecewise", ...
        "LearnRateDropPeriod",  2, ...
        "LearnRateDropFactor",  trainingParam.CNN_learn_rate_drop_factor, ...
        "GradientThreshold",    0.5, ...
        "L2Regularization",     trainingParam.CNN_l2_regularization, ...
        "Shuffle",              trainingParam.CNN_data_shuffling{end}, ...
        "ValidationData",       validationData, ...
        "ValidationFrequency",  valFrequency, ...
        "ValidationPatience",   patience, ...
        "VerboseFrequency",     10, ...
        "Plots",                "training-progress", ...
        "ExecutionEnvironment", trainingParam.execution_environment{end}, ...
        "Metrics",              "accuracy");

    classWeightsVec = reshape(single(classWeights(:)), 1, []);

    fprintf('--- CNN class weights (trainnet) ---\n');
    for i = 1:numel(classWeightsVec)
        fprintf('  %-12s : w = %.3f\n', classif.classes{i}, classWeightsVec(i));
    end
    fprintf('------------------------------------\n');

    lossFcn = @(Y,T) crossentropy(Y, T, classWeightsVec, WeightsFormat="UC");

    [classifier, info] = trainnet(trainingData, dlNet, lossFcn, options);
  

    classif.runSaveTrainingCurves(info, 'CNN');

    classif.runSave('CNN_info.mat', 'info', info);
    classif.runMsg('CNN trainnet finished');

    fprintf('Training is done...\n');
    fprintf('Saving image classifier ...\n');
    fprintf('------\n');

    save(fullfile(path,[name '.mat']),"classifier");

    CNNOptions = struct(options);
    CNNOptions.ValidationData = [];

    if ~exist(fullfile(path,"TrainingValidation"),"dir")
        mkdir(path,"TrainingValidation");
    end

    save(fullfile(path,"TrainingValidation","CNNOptions.mat"),"CNNOptions");
    save(fullfile(path,"TrainingValidation","tmpoptions.mat"),"options");

    classif.runMsg('Saved classifier: %s', fullfile(path,[name '.mat']));
     if ~attachRun
      %  classif.runStop();
    else
        try, classif.runMsg('CNN step finished (attachRun=true)'); catch, end
    end


catch ME
    try
        classif.runMsg('FATAL: %s', ME.getReport('extended','hyperlinks','off'));
    catch
    end
    safeRunStop();
    rethrow(ME);
end
end


% -------------------- helper --------------------

function [idxTrain, idxVal, labsTrain, labsVal] = localSplitTrainValH5(h5File, classes, fracTrain, doDebug)
if nargin < 4, doDebug = false; end

labsAll = h5read(h5File, '/labels');
labsAll = squeeze(labsAll);

if isnumeric(labsAll)
    labsAll = categorical(labsAll, 1:numel(classes), classes);
else
    labsAll = categorical(string(labsAll), classes);
end

nObs = numel(labsAll);

idxTrain = zeros(0,1);
idxVal   = zeros(0,1);

for ic = 1:numel(classes)
    cName = classes{ic};
    maskC = (labsAll == cName);
    idxC  = find(maskC);
    nC    = numel(idxC);
    if nC == 0
        continue;
    end

    nTrainC = max(1, round(fracTrain * nC));
    permC   = idxC(randperm(nC));

    permC = permC(:);
if isempty(permC)
    continue;
end
nTrainC = max(0, min(nTrainC, numel(permC)));
idxTrain = [idxTrain; permC(1:nTrainC)];
if nTrainC < numel(permC)
    idxVal = [idxVal; permC(nTrainC+1:end)];
end

end

idxTrain = idxTrain(randperm(numel(idxTrain)));
if isempty(idxVal)
    idxVal = idxTrain;
else
    idxVal = idxVal(randperm(numel(idxVal)));
end

labsTrain = labsAll(idxTrain);
labsVal   = labsAll(idxVal);

if doDebug
    fprintf('--- HDF5 train/val split (per class) ---\n');
    fprintf('Total obs: %d | Train: %d | Val: %d (fracTrain=%.2f)\n', ...
        nObs, numel(idxTrain), numel(idxVal), fracTrain);

    cats = categories(labsAll);
    for ic = 1:numel(cats)
        cName = cats{ic};
        nTot  = sum(labsAll == cName);
        nTr   = sum(labsTrain == cName);
        nVa   = sum(labsVal   == cName);
        fprintf('  %s : total=%d, train=%d (%.1f%%), val=%d (%.1f%%)\n', ...
            cName, nTot, nTr, 100*nTr/max(1,nTot), nVa, 100*nVa/max(1,nTot));
    end
    fprintf('----------------------------------------\n');
end
end
