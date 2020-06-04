function trainImageGoogleNetFun(path,name)

% gather all classification images in each class and performs the training and outputs and saves the trained net 

% load training data 

fprintf('Loading data repository...\n');

foldername=[path '/trainingdataset/images'];

imds = imageDatastore(foldername, ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames'); 
[imdsTrain,imdsValidation] = splitEachLabel(imds,0.7);

numClasses = numel(categories(imdsTrain.Labels));

fprintf('Loading googlenet...\n');

% load google net
net = googlenet;

inputSize = net.Layers(1).InputSize;

fprintf('Reformatting net for transfer learning...\n');

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
        'WeightLearnRateFactor',10, ...
        'BiasLearnRateFactor',10);
    
elseif isa(learnableLayer,'nnet.cnn.layer.Convolution2DLayer')
    newLearnableLayer = convolution2dLayer(1,numClasses, ...
        'Name','new_conv', ...
        'WeightLearnRateFactor',10, ...
        'BiasLearnRateFactor',10);
end

lgraph = replaceLayer(lgraph,learnableLayer.Name,newLearnableLayer);

newClassLayer = classificationLayer('Name','new_classoutput');
lgraph = replaceLayer(lgraph,classLayer.Name,newClassLayer);

%fprintf('Freezing layers...\n');

% freezing layers
layers = lgraph.Layers;
connections = lgraph.Connections;

% layers(1:10) = freezeWeights(layers(1:10));
% lgraph = createLgraphUsingConnections(layers,connections);

fprintf('Training network...\n');
% training network
% augment dataset

pixelRange = [-100 100];
scaleRange = [0.9 1.1];
rotation=[-180 180];

imageAugmenter = imageDataAugmenter( ...
    'RandXReflection',true, ...
    'RandXTranslation',pixelRange, ...
    'RandRotation',rotation, ...
    'RandYTranslation',pixelRange, ...
    'RandXScale',scaleRange, ...
    'RandYScale',scaleRange);
augimdsTrain = augmentedImageDatastore(inputSize(1:2),imdsTrain, ...
    'DataAugmentation',imageAugmenter);

augimdsValidation = augmentedImageDatastore(inputSize(1:2),imdsValidation);

miniBatchSize = 64;
valFrequency = floor(numel(augimdsTrain.Files)/miniBatchSize);
options = trainingOptions('sgdm', ...
    'MiniBatchSize',miniBatchSize, ...
    'MaxEpochs',30, ...
    'InitialLearnRate',3e-4, ... % 3e-4
    'Shuffle','every-epoch', ...
    'ValidationData',augimdsValidation, ...
    'ValidationFrequency',valFrequency, ...
     'VerboseFrequency',2,...
    'Plots','training-progress',...
    'ExecutionEnvironment','auto');

%   'LearnRateSchedule','piecewise',...
 %   'LearnRateDropPeriod',10,...
  %  'LearnRateDropFactor',0.7,...

classifier = trainNetwork(augimdsTrain,lgraph,options);

fprintf('Training is done...\n');
fprintf('Saving googlenet classifier ...\n');

%[path '/' name '.mat']

save([path '/' name '.mat'],'classifier');
