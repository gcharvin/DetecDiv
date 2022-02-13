function trainImageGoogleNetFun(classif,setparam)

path=fullfile(classif.path);
name=classif.strid;

%---------------- parameters setting
if nargin==2 % basic parameter initialization
        
        tip={'Choose the training method',...
            'Choose the CNN',...
            'Choose the size of the mini batch; Higher values require more memory and are prone to errors',...
            'Enter the number of epochs',...
            'Enter the initial learning rate',...
            'Choose whether and how training and validation data should be shuffled during training',...
            'Enter fraction of the data to be used for training vs validation during training',...
            'Enter the magnitude of translation for data augmentation (in pixels)',...
            'Enter the magnitude of rotation for data augmentation (in pixels)',...
            'Specify value for L2 regularization',...
            'Choose execution environment',...
            };
        
        classif.trainingParam=struct('CNN_training_method',{{'adam','sgdm','adam'}},...
            'CNN_network',{{'googlenet','resnet18','resnet50','resnet101','nasnetlarge','inceptionresnetv2', 'efficientnetb0','googlenet'}},...
            'CNN_mini_batch_size',8,...
            'CNN_max_epochs',6,...
            'CNN_initial_learning_rate',0.0003,...
            'CNN_data_shuffling',{{'once','every-epoch','never','every-epoch'}},...
            'CNN_data_splitting_factor',0.7,...
            'CNN_translation_augmentation',[-5 5],...
            'CNN_rotation_augmentation',[-20 20],...
            'CNN_l2_regularization',0.00001,...
            'execution_environment',{{'auto','parallel','cpu','gpu','multi-gpu','auto'}},...
            'tip',{tip});
        
        return;
        %   end
    else
        trainingParam=classif.trainingParam;
        
        if numel(trainingParam)==0
            disp('Could not find training parameters : first launch train with an extra argument to force parameter assignment');
            return;
        end
        
    end
    %-----------------------------------%


% gather all classification images in each class and performs the training and outputs and saves the trained net 
% load training data 
blockRNG=0;

fprintf('Loading data repository...\n');
fprintf('------\n');

foldername=[path '/trainingdataset/images'];

imds = imageDatastore(foldername, ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames'); 

% calculate class frequency for each class 

%ntot=countcats(imds.Labels);
%weights = double(ntot)/double(sum(ntot));

classWeights = 1./countcats(imds.Labels);
classWeights = classWeights'/mean(classWeights);


fprintf('Loading training options...\n');
fprintf('------\n');


[imdsTrain,imdsValidation] = splitEachLabel(imds,trainingParam.CNN_data_splitting_factor);

numClasses = classif.classes; %numel(categories(imdsTrain.Labels));

fprintf('Loading network...\n');
fprintf('------\n');

switch trainingParam.CNN_network{end}
    case 'googlenet'
net = googlenet;
%net=googlenet('Weights','places365');% trained on places rather than on
%imageNet; but is much worse than imagenet pretraining

    case 'resnet18'
net=resnet18;
    case 'resnet50'
net=resnet50;
    case 'resnet101'
net=resnet101;
    case 'nasnetlarge'
net=nasnetlarge;
    case 'inceptionresnetv2'
net=inceptionresnetv2;
   case 'efficientnetb0'
net=efficientnetb0;
%     otherwise
% fprintf('User selected custom CNN...\n');
% eval(['net =' trainingParam.CNN_network]);        
end
%

inputSize = net.Layers(1).InputSize;

fprintf('Reformatting net for transfer learning...\n');
fprintf('------\n');

% formatting the net for transferred learning
% extract the layer graph from the trained network 
if isa(net,'SeriesNetwork') 
  lgraph = layerGraph(net.Layers); 
else
  lgraph = layerGraph(net);
end

[learnableLayer,classLayer] = findLayersToReplace(lgraph);

numClasses = numel(categories(imdsTrain.Labels));

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
end

lgraph = replaceLayer(lgraph,learnableLayer.Name,newLearnableLayer);

%Change here to put or not class weighting
%newClassLayer = classificationLayer('Name','new_classoutput');
newClassLayer = weightedClassificationLayer(classWeights,'new_classoutput');

lgraph = replaceLayer(lgraph,classLayer.Name,newClassLayer);

%fprintf('Freezing layers...\n');

% freezing layers
% if strcmp(trainingParam.freeze,'y')
% layers = lgraph.Layers;
% connections = lgraph.Connections;
% 
%  layers(1:10) = freezeWeights(layers(1:10)); % only googlenet
%  lgraph = createLgraphUsingConnections(layers,connections); % onlygooglnet
% end

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
    
% training network
% augment dataset

%pixelRange=[-5 5];

pixelRange = trainingParam.CNN_translation_augmentation;

%scaleRange = [0.9 1.1];

%pixelRange = [-100 100];
%scaleRange = [0.7 1.3];

%rotation=[180 180];
rotation=trainingParam.CNN_rotation_augmentation;

% imageAugmenter = imageDataAugmenter( ...
%     'RandXReflection',true, ...
%     'RandYReflection',true, ...
%     'RandXTranslation',pixelRange, ...
%     'RandRotation',rotation, ...
%     'RandYTranslation',pixelRange, ...
%     'RandXScale',scaleRange, ...
%     'RandYScale',scaleRange);

imageAugmenter = imageDataAugmenter( ...
    'RandXReflection',true, ...
    'RandYReflection',true, ...
    'RandXTranslation',pixelRange, ...
    'RandYTranslation',pixelRange, ...
     'RandRotation',rotation);% , ...

  %  'RandXScale',scaleRange, ...
  %  'RandYScale',scaleRange);

augimdsTrain = augmentedImageDatastore(inputSize(1:2),imdsTrain, ...
    'DataAugmentation',imageAugmenter);

augimdsValidation = augmentedImageDatastore(inputSize(1:2),imdsValidation);

miniBatchSize = trainingParam.CNN_mini_batch_size; %8
valFrequency = floor(numel(augimdsTrain.Files)/miniBatchSize);

% if gpuDeviceCount>0
% disp('Using GPUs and multiple workers');
options = trainingOptions(trainingParam.CNN_training_method{end}, ...
    'MiniBatchSize',miniBatchSize, ...
    'MaxEpochs',trainingParam.CNN_max_epochs, ...
    'InitialLearnRate',trainingParam.CNN_initial_learning_rate, ...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',2,...
    'LearnRateDropFactor',0.5,...
    'GradientThreshold',0.5, ...
    'L2Regularization',trainingParam.CNN_l2_regularization, ...
    'Shuffle',trainingParam.CNN_data_shuffling{end}, ...
    'ValidationData',augimdsValidation, ...
    'ValidationFrequency',valFrequency, ...
    'VerboseFrequency',10,...
    'Plots','training-progress',...
    'ExecutionEnvironment',trainingParam.execution_environment{end});
  
% else
%     disp('Using CPUs or whatever is available');
%    options = trainingOptions('sgdm', ...
%     'MiniBatchSize',miniBatchSize, ...
%     'MaxEpochs',6, ...
%     'InitialLearnRate',3e-4, ... % 3e-4
%     'Shuffle','every-epoch', ...
%     'ValidationData',augimdsValidation, ...
%     'ValidationFrequency',valFrequency, ...
%      'VerboseFrequency',2,...
%     'Plots','training-progress',...%     'ExecutionEnvironment','auto');
%  
% end
classifier = trainNetwork(augimdsTrain,lgraph,options);

fprintf('Training is done...\n');
fprintf('Saving image classifier ...\n');
fprintf('------\n');

%[path '/' name '.mat']

save([path '/' name '.mat'],'classifier');
CNNOptions=struct(options);

CNNOptions.ValidationData=[];
save([path '/TrainingValidation/' 'CNNOptions' '.mat'],'CNNOptions');
save([path '/TrainingValidation/' 'tmpoptions' '.mat'],'options');

% layers = freezeWeights(layers) sets the learning rates of all the
% parameters of the layers in the layer array |layers| to zero.
% saveTrainingPlot(path,'CNNTraining');
 
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

% lgraph = createLgraphUsingConnections(layers,connections) creates a layer
% graph with the layers in the layer array |layers| connected by the
% connections in |connections|.
        
function lgraph = createLgraphUsingConnections(layers,connections)

lgraph = layerGraph();
for i = 1:numel(layers)
    lgraph = addLayers(lgraph,layers(i));
end

for c = 1:size(connections,1)
    lgraph = connectLayers(lgraph,connections.Source{c},connections.Destination{c});
end


