function trainImageGoogleNetFun(classif,setparam,inputnetwork)

path=fullfile(classif.path);
name=classif.strid;

flagCNN=[];

%---------------- parameters setting
if nargin==2 % basic parameter initialization
        
        tip={'Choose the training method',...
            'Choose the CNN',...
            'Choose the size of the mini batch; Higher values require more memory and are prone to errors',...
            'Enter the number of epochs',...
            'Enter the initial learning rate',...
            'Enter the learning rate drop factor',...
            'Choose whether and how training and validation data should be shuffled during training',...
            'Enter fraction of the data to be used for training vs validation during training',...
            'Enter the magnitude of translation for data augmentation (in pixels)',...
            'Enter the magnitude of rotation for data augmentation (in degrees)',...
            'Specify value for L2 regularization',...
            'Check to use a dropout layer',...
            'Value for dropout regularization',...
            'Choose execution environment',...
            'Select initial version of network to start training with; Default: ImageNet'};
        
        classif.trainingParam=struct( ...
            'CNN_training_method',{{'adam','sgdm','adam'}},...
            'CNN_network',{{'googlenet','inceptionresnetv2','inceptionv3','resnet18','resnet50','resnet101','nasnetlarge','inceptionresnetv2','efficientnetb0','googlenet'}},...
            'CNN_mini_batch_size',8,...
            'CNN_max_epochs',6,...
            'CNN_initial_learning_rate',0.0003,...
            'CNN_learn_rate_drop_factor',0.9,...
            'CNN_data_shuffling',{{'once','every-epoch','never','every-epoch'}},...
            'CNN_data_splitting_factor',0.7,...
            'CNN_translation_augmentation',[-5 5],...
            'CNN_rotation_augmentation',[-20 20],...
            'CNN_l2_regularization',0.0001,...
            'CNN_use_dropout',true,...                 % <---- NEW
            'CNN_dropout',0.5,...                      % <---- NEW
            'execution_environment',{{'auto','parallel','cpu','gpu','multi-gpu','auto'}},...
            'transfer_learning',{{'ImageNet','ImageNet'}},...
            'tip',{tip} ...
        );
        return;

else
        trainingParam=classif.trainingParam;

        % Backward compatibility defaults
        if ~isfield(trainingParam,'CNN_use_dropout'); trainingParam.CNN_use_dropout = true; end
        if ~isfield(trainingParam,'CNN_dropout');      trainingParam.CNN_dropout     = 0.5;  end
        
        if numel(trainingParam)==0
            disp('Could not find training parameters : first launch train with an extra argument to force parameter assignment');
            return;
        end
        
        if nargin==3  % input network is provided to be used instad of a virgin network 
            flagCNN=inputnetwork;
        end
end
%-----------------------------------%

% gather all classification images in each class and performs the training and outputs and saves the trained net 
% load training data 
blockRNG=1;

fprintf('Loading data repository...\n');
fprintf('------\n');

foldername=[path '/trainingdataset/images'];
if ~exist(foldername,"dir")
    disp('Folder does not  exist; first export images for training; quitting !')
    return;
end

imds = imageDatastore(foldername, ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames'); 

fprintf('------\n');

[imdsTrain,imdsValidation] = splitEachLabel(imds,trainingParam.CNN_data_splitting_factor);

% -- Recalcule sur le TRAIN uniquement + clamp
tbl = countEachLabel(imdsTrain);          % table avec variables Label, Count
cnt = tbl.Count;
cnt(cnt==0) = 1;                          % évite division par 0
classWeights = 1 ./ cnt;
classWeights = classWeights' / mean(classWeights);
classWeights(~isfinite(classWeights)) = 1; % garde au propre

classes = classif.classes;

if numel(classes)==0
    disp('There is no classes defined ; Cannot continue !')
    return;
end

fprintf('Loading network...\n');
fprintf('------\n');

if strcmp(trainingParam.transfer_learning{end},'ImageNet')  % creates a new network
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
% We will find the current learnable layer to know where to attach dropout (especially for ResNet).
[learnableLayer,classLayer] = findLayersToReplace(lgraph);

% Apply dropout only if requested
if trainingParam.CNN_use_dropout
    netName = lower(trainingParam.CNN_network{end});
    pDrop   = trainingParam.CNN_dropout;

    if contains(netName,'googlenet')
        % GoogLeNet: replace existing dropout just before FC head
        if any(strcmp({lgraph.Layers.Name}, 'pool5-drop_7x7_s1'))
            lgraph = replaceLayer(lgraph,'pool5-drop_7x7_s1', ...
                                  dropoutLayer(pDrop,'Name','pool5-drop_7x7_s1'));
            fprintf('Applied dropout %.2f to GoogLeNet (pool5-drop_7x7_s1).\n', pDrop);
        else
            % Fallback: insert a custom dropout right before the learnable layer
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
        % ResNet: insert dropout between avg_pool and learnable layer
        if any(strcmp({lgraph.Layers.Name},'avg_pool'))
            if ~any(strcmp({lgraph.Layers.Name},'custom_dropout'))
                lgraph = addLayers(lgraph, dropoutLayer(pDrop,'Name','custom_dropout'));
                % disconnect avg_pool -> learnable
                if any(strcmp(lgraph.Connections.Source,'avg_pool') & strcmp(lgraph.Connections.Destination,learnableLayer.Name))
                    lgraph = disconnectLayers(lgraph,'avg_pool',learnableLayer.Name);
                else
                    % More robust: disconnect any outgoing from avg_pool
                    nextIdx = strcmp(lgraph.Connections.Source,'avg_pool');
                    nextDest = lgraph.Connections.Destination(nextIdx);
                    for ii=1:numel(nextDest)
                        lgraph = disconnectLayers(lgraph,'avg_pool',nextDest{ii});
                    end
                end
                % reconnect via dropout
                lgraph = connectLayers(lgraph,'avg_pool','custom_dropout');
                lgraph = connectLayers(lgraph,'custom_dropout',learnableLayer.Name);
                fprintf('Inserted custom dropout %.2f after avg\\_pool (ResNet).\n', pDrop);
            end
        else
            warning('avg_pool not found; skipping dropout insertion for ResNet.');
        end
    else
        % Other nets: try a generic insertion right before learnableLayer
        if ~any(strcmp({lgraph.Layers.Name},'custom_dropout'))
            lgraph = addLayers(lgraph, dropoutLayer(pDrop,'Name','custom_dropout'));
            % find all sources feeding the learnable layer
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
sz=size(learnableLayer.Weights);
numClasses = numel(categories(imdsTrain.Labels));
cates=categories(imdsTrain.Labels);

% adjust the final layers of the net
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

% Use class weights
newClassLayer = weightedClassificationLayer(classWeights,'new_classoutput');
lgraph = replaceLayer(lgraph,classLayer.Name,newClassLayer);

inputSize = net.Layers(1).InputSize;

fprintf('Training network...\n');
fprintf('------\n');

%=====BLOCKs RNG====
if blockRNG==1
    stCPU= RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
    stGPU=parallel.gpu.RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
    RandStream.setGlobalStream(stCPU);
    parallel.gpu.RandStream.setGlobalStream(stGPU);
end
%===================

% --- Photometric jitter via ReadFcn (train only) ---
imdsTrainPhot = imageDatastore(imdsTrain.Files, ...
    'Labels', imdsTrain.Labels, ...
    'IncludeSubfolders', false);  % files list already resolved
imdsTrainPhot.ReadFcn = @(fn) photometricReadFcn(fn);  % << appliquer le jitter ici


pixelRange = trainingParam.CNN_translation_augmentation;
rotation   = trainingParam.CNN_rotation_augmentation;

% basic augmentations (portable)
imageAugmenter = imageDataAugmenter( ...
    'RandXReflection',true, ...
    'RandYReflection',true, ...
    'RandScale',[0.9 1.1], ...
    'RandXTranslation',pixelRange, ...
    'RandYTranslation',pixelRange, ...
    'RandRotation',rotation);

% --- 3) Datastores d'entraînement / validation ---
augimdsTrain = augmentedImageDatastore(inputSize(1:2), imdsTrainPhot, ...
    'DataAugmentation', imageAugmenter);

% augimdsTrain = augmentedImageDatastore(inputSize(1:2),imdsTrain, ...
%     'DataAugmentation',imageAugmenter);

miniBatchSize = trainingParam.CNN_mini_batch_size;
valFrequency  = floor(numel(augimdsTrain.Files)/miniBatchSize);

augimdsValidation = augmentedImageDatastore(inputSize(1:2),imdsValidation);


if ~isfield(trainingParam,'CNN_learn_rate_drop_factor')
    trainingParam.CNN_learn_rate_drop_factor=0.9;
end

patience=3;

options = trainingOptions(trainingParam.CNN_training_method{end}, ...
    'MiniBatchSize',miniBatchSize, ...
    'MaxEpochs',trainingParam.CNN_max_epochs, ...
    'InitialLearnRate',trainingParam.CNN_initial_learning_rate, ...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',2,...
    'LearnRateDropFactor',trainingParam.CNN_learn_rate_drop_factor,...
    'GradientThreshold',0.5, ...
    'L2Regularization',trainingParam.CNN_l2_regularization, ...
    'Shuffle',trainingParam.CNN_data_shuffling{end}, ...
    'ValidationData',augimdsValidation, ...
    'ValidationFrequency',valFrequency, ...
    'ValidationPatience', patience, ...  
    'VerboseFrequency',10,...
    'Plots','training-progress',...
    'ExecutionEnvironment',trainingParam.execution_environment{end});

classifier = trainNetwork(augimdsTrain,lgraph,options);

fprintf('Training is done...\n');
fprintf('Saving image classifier ...\n');
fprintf('------\n');

save([path '/' name '.mat'],'classifier');
CNNOptions=struct(options);
CNNOptions.ValidationData=[];

if ~exist(fullfile(path,'TrainingValidation'),"dir")
    mkdir(path,'TrainingValidation');
end

save([path '/TrainingValidation/' 'CNNOptions' '.mat'],'CNNOptions');
save([path '/TrainingValidation/' 'tmpoptions' '.mat'],'options');

% ===== helpers =====
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
% ReadFcn pour imageDatastore de TRAIN : lit, applique jitter, renvoie uint8.
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


