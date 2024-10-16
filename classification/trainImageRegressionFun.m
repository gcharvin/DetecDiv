function trainImageRegressionFun(classif,setparam)

% gather all classification images in each class and performs the training and outputs and saves the trained net 
% load training data 

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
            'Select initial version of network to start training with; Default: ImageNet'};

        
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
            'transfer_learning',{{'ImageNet','ImageNet'}},...
            'tip',{tip});
        
        return;
        %   end
    else
        trainingParam=classif.trainingParam;
        
        if numel(trainingParam)==0
            disp('Could not find training parameters : first launch straing with an extra argument to force parameter assignment');
            return;
        end
        
    end
    %-----------------------------------%
    
 blockRNG=1;


fprintf('Loading data repository...\n');
fprintf('------\n');

% load images at once

imagefolder=fullfile(path, '/trainingdataset/images');

listimage=dir([imagefolder '/*.tif']);

%imds = imageDatastore(foldername, ...
  %  'IncludeSubfolders',false, ...
  %  'LabelSource','none'); 

% imds.Labels=[];

 responsefolder=fullfile(path, '/trainingdataset/labels');
listresponse=dir([responsefolder '/*.mat']);


for i=1:numel(listimage)
   im=imread(fullfile(imagefolder,listimage(i).name)); 
    if i==1
      X=im;
    else
     X(:,:,:,i)=im;
    end
end

for i=1:numel(listresponse)

    load(fullfile(responsefolder,listresponse(i).name));
   % if i==1
  %     Y=label;
  %  else
      Y(i)=label;
  %  end
end


% arr=[];
% for i=1:numel(imds.Files)
%     
%     [pth fle ext]=fileparts(imds.Files{i});
%     
%     % load corresponding label
%     
%     load(fullfile(path,'trainingdataset','labels',[fle,'.mat'])); % loads the label variable
%     
%   arr(i)=label;
% end
%   response=arr';
  
  
  rng(0);
  splitfactor=trainingParam.CNN_data_splitting_factor;
numFiles = numel(listimage);
shuffledIndices = randperm(numFiles);

% Use 70% of the images for training.
numTrain = round(splitfactor * numFiles);
trainingIdx = shuffledIndices(1:numTrain);

% Use 20% of the images for validation
numtot = min(numTrain+round((1-splitfactor) * numFiles),numel(shuffledIndices));
valIdx = shuffledIndices(numTrain+1:numtot);


XTrain=X(:,:,:,trainingIdx);
YTrain=Y(trainingIdx); YTrain=YTrain';

XVal=X(:,:,:,valIdx);
YVal=Y(valIdx); YVal=YVal';



% for i=1:numel(list)
% % aa=   list(i)
%     load(fullfile(imfolder,list(i).name));
%     
%     if i==1
%         imstore=im;
%     else
%         imstore(:,:,:,end+1:end+size(im,4))=im;
%     end
% end

% load response at once

% imfolder=fullfile(path, '/trainingdataset/response');
% list=dir([imfolder '/*.mat']);
% 
% for i=1:numel(list)
% % aa=   list(i)
%     load(fullfile(imfolder,list(i).name));
%     if i==1
%        restore=response;
%     else
%         restore(1,end+1:end+size(response,2))=response;
%     end
% end
% restore=restore';

% to do : properly use datastore and assign labels a posteriori once the
% datastore is created 
% this code is not proofread:
%imds = imageDatastore(foldername); 
% imds.Labels={restore};

% then uncomment all the data augmentation things....

% imds = imageDatastore(foldername, ...
%  %   'IncludeSubfolders',true, ...
%     'LabelSource','foldernames'); 

% calculate class frequency for each class 

%ntot=countcats(imds.Labels);
%weights = double(ntot)/double(sum(ntot));

%classWeights = 1./countcats(imds.Labels);
%classWeights = classWeights'/mean(classWeights);

%[imdsTrain, imdsValidation, responseTrain, responseValidation] = subSelectTrainingSet(imds,response,trainingParam.CNN_data_splitting_factor); % subselect images in datastore according to their belonging to classif.trainingset

      
%[imdsTrain,imdsValidation] = splitEachLabel(imds,trainingParam.CNN_data_splitting_factor);


numClasses = 1;%numel(categories(imdsTrain.Labels));

fprintf('Loading network...\n');
fprintf('------\n');


if strcmp(trainingParam.transfer_learning{end},'ImageNet') % creates a new network
disp('Generating new network');

switch trainingParam.CNN_network{end}
    case 'googlenet'
net = googlenet;
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
% eval(['net =' trainingParam.network]);        
end
%

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

%numClasses = numel(categories(imdsTrain.Labels));

%numClasses=1;

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

% removes softmax layer

for i=1:numel(lgraph.Layers)
if isa(lgraph.Layers(i),'nnet.cnn.layer.SoftmaxLayer')
    remLayerName=lgraph.Layers(i).Name; 
    break;
end
end

lgraph=removeLayers(lgraph, remLayerName);


%Change here to put or not class weighting
%newClassLayer = classificationLayer('Name','new_classoutput');

%newClassLayer = weightedClassificationLayer(classWeights,'new_classoutput');

newRegLayer = regressionLayer('Name','new_regoutput'); % creates reg layer
lgraph = replaceLayer(lgraph,classLayer.Name,newRegLayer); % replace classif layer by regresison layer
 lgraph = connectLayers(lgraph,"new_fc","new_regoutput"); % connect fc to reg layer
 
%fprintf('Freezing layers...\n');

% % freezing layers
% if strcmp(trainingParam.freeze,'y')
% layers = lgraph.Layers;
% connections = lgraph.Connections;
% 
%  layers(1:10) = freezeWeights(layers(1:10)); % only googlenet
%  lgraph = createLgraphUsingConnections(layers,connections); % onlygooglnet
% end

else
    disp(['Loading previously trained network : ' trainingParam.transfer_learning{end}]);
 strpth=fullfile(classif.path,  trainingParam.transfer_learning{end});
if exist(strpth)
    load(strpth); %loads classifier
 lgraph = layerGraph(classifier);    
 net=classifier;
else
    disp(['Unable to load: ' trainingParam.transfer_learning{end}]);
    return;
end
end


inputSize = net.Layers(1).InputSize;
% adjusting data size to network 
%imstore=imresize(imstore,inputSize(1:2));

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
    
 pixelRange = trainingParam.CNN_translation_augmentation;
rotation=trainingParam.CNN_rotation_augmentation;

imageAugmenter = imageDataAugmenter( ...
    'RandXReflection',true, ...
    'RandYReflection',true, ...
    'RandXTranslation',pixelRange, ...
    'RandYTranslation',pixelRange, ...
     'RandRotation',rotation);% , ...

 %augimdsTrain= augmentedImageDatastore(inputSize(1:2),imdsTrain, ...
  %  'DataAugmentation',imageAugmenter);

 augimdsTrain= augmentedImageDatastore(inputSize(1:2),XTrain,YTrain, ...
    'DataAugmentation',imageAugmenter);

miniBatchSize = trainingParam.CNN_mini_batch_size; %8
%valFrequency = 10; %floor(numel(augimdsTrain.Files)/miniBatchSize);

valFrequency = floor(size(XTrain,4)/miniBatchSize);

%augimdsTrain = transform(augimdsTrain,@classificationAugmentationPipeline,'IncludeInfo',true);

augimdsValidation = augmentedImageDatastore(inputSize(1:2),XVal,YVal);

% if gpuDeviceCount>0
% disp('Using GPUs and multiple workers');
options = trainingOptions(trainingParam.CNN_training_method{end}, ...
    'MiniBatchSize',miniBatchSize, ...
    'MaxEpochs',trainingParam.CNN_max_epochs, ...
    'InitialLearnRate',trainingParam.CNN_initial_learning_rate, ...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',10,...
    'LearnRateDropFactor',0.9,...
    'GradientThreshold',0.5, ...
    'L2Regularization',trainingParam.CNN_l2_regularization, ...
    'Shuffle',trainingParam.CNN_data_shuffling{end}, ...
     'ValidationData',augimdsValidation, ...
    'ValidationFrequency',valFrequency, ...
    'VerboseFrequency',10,...
    'Plots','training-progress',...
    'ExecutionEnvironment',trainingParam.execution_environment{end});
  
%    'ValidationData',augimdsValidation, ...

classifier = trainNetwork(augimdsTrain,lgraph,options);

fprintf('Training is done...\n');
fprintf('Saving image classifier ...\n');
fprintf('------\n');

%[path '/' name '.mat']

save([path '/' name '.mat'],'classifier');
% CNNOptions=struct(options);
% 
% CNNOptions.ValidationData=[];
% save([path '/TrainingValidation/' 'CNNOptions' '.mat'],'CNNOptions');
% save([path '/TrainingValidation/' 'tmpoptions' '.mat'],'options');

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


function [imdsTrain, imdsVal, responseTrain, responseValidation] = subSelectTrainingSet(imds,response, splitfactor)
% subselect data in the trainingset
     
      
rng(0);
numFiles = numel(imds.Files);
shuffledIndices = randperm(numFiles);

% Use 70% of the images for training.
numTrain = round(splitfactor * numFiles);
trainingIdx = shuffledIndices(1:numTrain);

% Use 20% of the images for validation
numtot = min(numTrain+round((1-splitfactor) * numFiles),numel(shuffledIndices));
valIdx = shuffledIndices(numTrain+1:numtot);

% Create image datastores for training and test.
trainingImages = imds.Files(trainingIdx);
valImages = imds.Files(valIdx);
%testImages = imds.Files(testIdx);

imdsTrain = imageDatastore(trainingImages);
imdsVal = imageDatastore(valImages);

responseTrain=response(trainingIdx);
responseValidation=response(valIdx);



