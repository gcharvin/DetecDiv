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
%net=resnet50;

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

 layers(1:10) = freezeWeights(layers(1:10)); % only googlenet
 lgraph = createLgraphUsingConnections(layers,connections); % onlygooglnet

fprintf('Training network...\n');
% training network
% augment dataset

pixelRange = [-30 30];
scaleRange = [0.9 1.1];

%pixelRange = [-100 100];
%scaleRange = [0.7 1.3];
%rotation=[-180 180];

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
    'RandXScale',scaleRange, ...
    'RandYScale',scaleRange);


augimdsTrain = augmentedImageDatastore(inputSize(1:2),imdsTrain, ...
    'DataAugmentation',imageAugmenter);

augimdsValidation = augmentedImageDatastore(inputSize(1:2),imdsValidation);

miniBatchSize = 10; %8
valFrequency = floor(numel(augimdsTrain.Files)/miniBatchSize);

if gpuDeviceCount>0
disp('Using GPUs and multiple workers');
options = trainingOptions('sgdm', ...
    'MiniBatchSize',miniBatchSize, ...
    'MaxEpochs',6, ...
    'InitialLearnRate',3e-4, ... % 3e-4
    'Shuffle','every-epoch', ...
    'ValidationData',augimdsValidation, ...
    'ValidationFrequency',valFrequency, ...
     'VerboseFrequency',2,...
    'Plots','training-progress',...
    'ExecutionEnvironment','parallel');

%   'LearnRateSchedule','piecewise',...
 %   'LearnRateDropPeriod',10,...
  %  'LearnRateDropFactor',0.7,...
  
else
    disp('Using CPUs or whatever is available');
   options = trainingOptions('sgdm', ...
    'MiniBatchSize',miniBatchSize, ...
    'MaxEpochs',6, ...
    'InitialLearnRate',3e-4, ... % 3e-4
    'Shuffle','every-epoch', ...
    'ValidationData',augimdsValidation, ...
    'ValidationFrequency',valFrequency, ...
     'VerboseFrequency',2,...
    'Plots','training-progress',...
    'ExecutionEnvironment','auto');
 
end

classifier = trainNetwork(augimdsTrain,lgraph,options);

fprintf('Training is done...\n');
fprintf('Saving googlenet classifier ...\n');

%[path '/' name '.mat']

save([path '/' name '.mat'],'classifier');

% layers = freezeWeights(layers) sets the learning rates of all the
% parameters of the layers in the layer array |layers| to zero.

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


