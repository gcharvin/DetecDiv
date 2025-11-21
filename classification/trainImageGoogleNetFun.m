function trainImageGoogleNetFun(classif,setparam,inputnetwork)

path=fullfile(classif.path);
name=classif.strid;

flagCNN=[];

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
        'Choose storage backend for CNN training data (''tiff'' or ''hdf5'')', ...
        'Range of random scale factor for CNN augmentation (e.g. [0.9 1.1])', ...
        'Enable random flips (left/right & up/down) during CNN augmentation', ...
        'Crop-in scale range for CNN augmentation (e.g. [0.8 1.0])', ...
        'Contrast multiplier range for CNN augmentation (e.g. [0.85 1.15])', ...
        'Maximum hue jitter (0–0.5, small values recommended)', ...
        'Std-dev of Gaussian noise for CNN augmentation (set 0 to disable)' ...
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
        'CNN_use_dropout',true, ...          % <---- NEW (déjà présent)
        'CNN_dropout',0.5, ...               % <---- NEW (déjà présent)
        'execution_environment',{{'auto','parallel','cpu','gpu','multi-gpu','auto'}}, ...
        'transfer_learning',{{'ImageNet','ImageNet'}}, ...
        'CNN_storage_backend','tiff', ...        % 'tiff' (historique) ou 'hdf5'
        'CNN_rand_scale',[0.9 1.1], ...         % RandScale pour TIFF, approx. crop/zoom
        'CNN_rand_flip',true, ...               % flips aléatoires (TIFF / éventuellement HDF5)
        'CNN_crop_scale',[0.8 1.0], ...         % crop-in pour HDF5 datastore
        'CNN_contrast_range',[0.85 1.15], ...   % contraste mult. pour HDF5
        'CNN_hue_delta',0.05, ...               % jitter de teinte (HDF5)
        'CNN_noise_sigma',0.02, ...             % sigma bruit gaussien (HDF5)
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

    % Nouveaux champs backend / augmentation
    if ~isfield(trainingParam,'CNN_storage_backend'); trainingParam.CNN_storage_backend = 'tiff'; end
    if ~isfield(trainingParam,'CNN_rand_scale');      trainingParam.CNN_rand_scale      = [0.9 1.1]; end
    if ~isfield(trainingParam,'CNN_rand_flip');       trainingParam.CNN_rand_flip       = true;      end
    if ~isfield(trainingParam,'CNN_crop_scale');      trainingParam.CNN_crop_scale      = [0.8 1.0]; end
    if ~isfield(trainingParam,'CNN_contrast_range');  trainingParam.CNN_contrast_range  = [0.85 1.15]; end
    if ~isfield(trainingParam,'CNN_hue_delta');       trainingParam.CNN_hue_delta       = 0.05;      end
    if ~isfield(trainingParam,'CNN_noise_sigma');     trainingParam.CNN_noise_sigma     = 0.02;      end

    % On réinjecte dans classif (au cas où tu sauvegardes ensuite)
    classif.trainingParam = trainingParam;

    if numel(trainingParam)==0
        disp('Could not find training parameters : first launch train with an extra argument to force parameter assignment');
        return;
    end
        
    if nargin==3  % input network is provided to be used instead of a virgin network 
        flagCNN = inputnetwork;
    end
end
%-----------------------------------%

blockRNG = 1;

fprintf('Loading data repository...\n');
fprintf('------\n');

% === Choix du backend de données pour le CNN ===
backend = lower(trainingParam.CNN_storage_backend);

%----------------------------------------------------------------------
% 1) Création des datastores d'entraînement / validation
%----------------------------------------------------------------------

switch backend
    case 'tiff'
        % ----- BACKEND HISTORIQUE : dossiers de TIFF -----

        foldername = fullfile(path,'trainingdataset','images');
        if ~exist(foldername,"dir")
            disp('Folder does not exist; first export images for training; quitting !')
            return;
        end

        imds = imageDatastore(foldername, ...
            'IncludeSubfolders',true, ...
            'LabelSource','foldernames'); 

        fprintf('------\n');

        % Split TRAIN / VAL
        [imdsTrain,imdsValidation] = splitEachLabel(imds, ...
            trainingParam.CNN_data_splitting_factor);

        % Class weights calculés sur TRAIN seulement
        tbl   = countEachLabel(imdsTrain);      % table Label, Count
        cnt   = tbl.Count;
        cnt(cnt==0) = 1;
        classWeights = 1 ./ cnt;
        classWeights = classWeights' / mean(classWeights);
        classWeights(~isfinite(classWeights)) = 1;

        % Photometric jitter via ReadFcn (TRAIN seulement)
        imdsTrainPhot = imageDatastore(imdsTrain.Files, ...
            'Labels', imdsTrain.Labels, ...
            'IncludeSubfolders', false);  % files list already résolus
        imdsTrainPhot.ReadFcn = @(fn) photometricReadFcn(fn);  % jitter photométrique

        % Géométrie via imageDataAugmenter
        pixelRange = trainingParam.CNN_translation_augmentation;
        rotation   = trainingParam.CNN_rotation_augmentation;
        scaleRange = trainingParam.CNN_rand_scale;
        if numel(scaleRange) ~= 2
            scaleRange = [0.9 1.1];
        end

        imageAugmenter = imageDataAugmenter( ...
            'RandXReflection',trainingParam.CNN_rand_flip, ...
            'RandYReflection',trainingParam.CNN_rand_flip, ...
            'RandScale',scaleRange, ...
            'RandXTranslation',pixelRange, ...
            'RandYTranslation',pixelRange, ...
            'RandRotation',rotation);

        % Ces variables seront utilisées plus loin
        dataTrain   = imdsTrainPhot;
        dataValBase = imdsValidation;
        useHDF5     = false;

    case 'hdf5'
        % ----- NOUVEAU BACKEND : framebank HDF5 -----

        h5File = fullfile(path,'trainingdataset','framebank.h5');
        if ~exist(h5File,"file")
            disp('HDF5 framebank file not found:');
            disp(h5File);
            disp('Export HDF5 training data first (frames + labels). Quitting !');
            return;
        end

        % Datastore HDF5 custom (nécessite H5ImageDatastore.m dans le path)
        augParams = localGetH5AugParams(trainingParam);
        dsAll = H5ImageDatastore(h5File, ...
            'MiniBatchSize', trainingParam.CNN_mini_batch_size, ...
            'TransRange',    augParams.TransRange, ...
            'RotRange',      augParams.RotRange, ...
            'CropScale',     augParams.CropScale, ...
            'ContrastRange', augParams.ContrastRange, ...
            'HueDelta',      augParams.HueDelta, ...
            'NoiseSigma',    augParams.NoiseSigma, ...
            'ClassNames',    classif.classes);

        % Split TRAIN / VAL au niveau des indices
        nObs = numObservations(dsAll);
        if nObs == 0
            disp('No observations found in HDF5 dataset; quitting !');
            return;
        end

        idxAll = 1:nObs;
        idxAll = idxAll(randperm(nObs));
        Ntrain = floor(trainingParam.CNN_data_splitting_factor * nObs);
        if Ntrain < 1, Ntrain = max(1, nObs-1); end

        idxTrain = idxAll(1:Ntrain);
        idxVal   = idxAll(Ntrain+1:end);
        if isempty(idxVal), idxVal = idxTrain; end   % fallback trivial

        dsTrain = subset(dsAll, idxTrain);
        dsVal   = subset(dsAll, idxVal);

        % Class weights via /labels du HDF5
        labsAll = h5read(h5File, '/labels');
        labsAll = squeeze(labsAll);
        % On se base sur TRAIN uniquement
        labsTrain = labsAll(idxTrain);
        if isnumeric(labsTrain)
            labsTrain = categorical(labsTrain, 1:numel(classif.classes), classif.classes);
        else
            labsTrain = categorical(string(labsTrain), classif.classes);
        end
        cnt = countcats(labsTrain);
        cnt(cnt==0) = 1;
        classWeights = 1 ./ cnt;
        classWeights = classWeights' / mean(classWeights);
        classWeights(~isfinite(classWeights)) = 1;

        dataTrain   = dsTrain;
        dataValBase = dsVal;
        useHDF5     = true;

    otherwise
        error('Unknown CNN_storage_backend: %s (use ''tiff'' or ''hdf5'')', ...
            trainingParam.CNN_storage_backend);
end

%----------------------------------------------------------------------
% 2) Classes (depuis classif)
%----------------------------------------------------------------------
classes = classif.classes;
if numel(classes)==0
    disp('There is no classes defined ; Cannot continue !')
    return;
end

fprintf('Loading network...\n');
fprintf('------\n');

%----------------------------------------------------------------------
% 3) Chargement / préparation du backbone CNN
%----------------------------------------------------------------------
if strcmp(trainingParam.transfer_learning{end},'ImageNet')  % crée un nouveau réseau
    disp('Generating new network');
    net = eval(trainingParam.CNN_network{end});

    fprintf('Reformatting net for transfer learning...\n');
    fprintf('------\n');

    % extract layer graph
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

% Recompute handles in case graph changed
[learnableLayer,classLayer] = findLayersToReplace(lgraph);

% adjust the final layers of the net
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

% Use class weights (calculés plus haut selon backend)
newClassLayer = weightedClassificationLayer(classWeights,'new_classoutput');
lgraph = replaceLayer(lgraph,classLayer.Name,newClassLayer);

inputSize = net.Layers(1).InputSize;

fprintf('Training network...\n');
fprintf('------\n');

%=====BLOCK RNG====
if blockRNG==1
    stCPU= RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
    stGPU=parallel.gpu.RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
    RandStream.setGlobalStream(stCPU);
    parallel.gpu.RandStream.setGlobalStream(stGPU);
end
%===================

%----------------------------------------------------------------------
% 4) Construction des datastores finaux (en fonction du backend)
%----------------------------------------------------------------------

miniBatchSize = trainingParam.CNN_mini_batch_size;

if ~isfield(trainingParam,'CNN_learn_rate_drop_factor')
    trainingParam.CNN_learn_rate_drop_factor = 0.9;
end

patience = 10;

switch backend
    case 'tiff'
        % --- Backend TIFF : augmentedImageDatastore comme avant ---
        pixelRange = trainingParam.CNN_translation_augmentation;
        rotation   = trainingParam.CNN_rotation_augmentation;
        scaleRange = trainingParam.CNN_rand_scale;
        if numel(scaleRange) ~= 2
            scaleRange = [0.9 1.1];
        end

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
        % --- Backend HDF5 : H5ImageDatastore directement dans trainNetwork ---
        % dataTrain = dsTrain ; dataValBase = dsVal
        nTrainObs = numObservations(dataTrain);
        valFrequency = floor(max(1, nTrainObs / miniBatchSize));

        trainingData   = dataTrain;
        validationData = dataValBase;
end

%----------------------------------------------------------------------
% 5) trainingOptions & trainNetwork
%----------------------------------------------------------------------

options = trainingOptions(trainingParam.CNN_training_method{end}, ...
    'MiniBatchSize',miniBatchSize, ...
    'MaxEpochs',trainingParam.CNN_max_epochs, ...
    'InitialLearnRate',trainingParam.CNN_initial_learning_rate, ...
    'LearnRateSchedule','piecewise', ...
    'LearnRateDropPeriod',2, ...
    'LearnRateDropFactor',trainingParam.CNN_learn_rate_drop_factor, ...
    'GradientThreshold',0.5, ...
    'L2Regularization',trainingParam.CNN_l2_regularization, ...
    'Shuffle',trainingParam.CNN_data_shuffling{end}, ...
    'ValidationData',validationData, ...
    'ValidationFrequency',valFrequency, ...
    'ValidationPatience', patience, ...
    'VerboseFrequency',10, ...
    'Plots','training-progress', ...
    'ExecutionEnvironment',trainingParam.execution_environment{end});

classifier = trainNetwork(trainingData,lgraph,options);

fprintf('Training is done...\n');
fprintf('Saving image classifier ...\n');
fprintf('------\n');

save(fullfile(path,[name '.mat']),'classifier');
CNNOptions = struct(options);
CNNOptions.ValidationData = [];

if ~exist(fullfile(path,'TrainingValidation'),"dir")
    mkdir(path,'TrainingValidation');
end

save(fullfile(path,'TrainingValidation','CNNOptions.mat'),'CNNOptions');
save(fullfile(path,'TrainingValidation','tmpoptions.mat'),'options');

% ===== helpers =====
function augParams = localGetH5AugParams(trainingParam)
% Paramètres d'augmentation à partager entre entraînement CNN et lecture HDF5
augParams = struct();
augParams.TransRange    = trainingParam.CNN_translation_augmentation;
augParams.RotRange      = trainingParam.CNN_rotation_augmentation;
augParams.CropScale     = trainingParam.CNN_crop_scale;
augParams.ContrastRange = trainingParam.CNN_contrast_range;
augParams.HueDelta      = trainingParam.CNN_hue_delta;
augParams.NoiseSigma    = trainingParam.CNN_noise_sigma;

function layers = freezeWeights(layers)
for ii = 1:size(layers,1)
    props = properties(layers(ii));
    for p = 1:numel(props)
        propName = props{p};
        if ~isempty(regexp(propName, 'LearnRateFactor$', 'once'))
            layers(ii).(propName) = 0;
        end
    end
end

function lgraph = createLgraphUsingConnections(layers,connections)
lgraph = layerGraph();
for i = 1:numel(layers)
    lgraph = addLayers(lgraph,layers(i));
end
for c = 1:size(connections,1)
    lgraph = connectLayers(lgraph,connections.Source{c},connections.Destination{c});
end

function I = photometricReadFcn(filename)
% ReadFcn pour imageDatastore de TRAIN (backend TIFF) :
% lit, applique jitter, renvoie uint8.
I = imread(filename);
I = photometricJitter(I);

function Iout = photometricJitter(Iin)
% Photometric-only jitter (contraste/luminosité/gamma/bruit/flou léger)
% Entrée: uint8/uint16/grayscale ou RGB. Sortie: uint8.

I = im2double(Iin);
isRGB = (ndims(I)==3) && (size(I,3)==3);

% contraste / luminosité / gamma (petits jitters)
alpha = 0.85 + 0.30*rand();    % 0.85–1.15
beta  = -0.10 + 0.20*rand();   % -0.10–0.10
gamma = 0.90 + 0.20*rand();    % 0.9–1.1
I = I .* alpha + beta;
I = max(min(I,1),0);
I = I .^ gamma;

% saturation très légère si RGB
if isRGB && rand < 0.5
    HSV = rgb2hsv(I);
    satJit = 0.95 + 0.10*rand();   % 0.95–1.05
    HSV(:,:,2) = max(min(HSV(:,:,2)*satJit,1),0);
    I = hsv2rgb(HSV);
end

% bruit gaussien léger
if rand < 0.7
    var = 1e-4 + 4e-4*rand();      % 0.0001–0.0005
    I = imnoise(I,'gaussian',0,var);
end

% défocus léger
if rand < 0.5
    sigma = 0.3 + 0.7*rand();      % 0.3–1.0 px
    ksz   = max(3, 2*ceil(2*sigma)+1);
    I     = imgaussfilt(I, sigma, 'FilterSize', ksz);
end

Iout = im2uint8(max(min(I,1),0));

