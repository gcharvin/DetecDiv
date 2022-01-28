function trainUNetFun(classif,setparam)

% gather all classification images in each class : unbudded, small budded,
% large budded, perform the training and outputs and saves the trained net

path=fullfile(classif.path);
name=classif.strid;

%---------------- parameters setting
if nargin==2 % basic parameter initialization
        
        tip={'Choose the training method',...
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
            'CNN_mini_batch_size',8,...
            'CNN_max_epochs',20,...
            'CNN_initial_learning_rate',0.001,...
            'CNN_data_shuffling',{{'once','every-epoch','never','every-epoch'}},...
            'CNN_data_splitting_factor',0.9,...
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
            disp('Could not find training parameters : first launch straing with an extra argument to force parameter assignment');
            return;
        end
        
    end
    %-----------------------------------%


fprintf('Loading data...\n');


imagesfoldername=[path '/trainingdataset/images'];

labelsfoldername=[path '/trainingdataset/labels'];

classification=classif;

channels=classification.channelName;

totchan=0; % total number of channels

for i=1:numel(channels)
    pix=classification.roi(1).findChannelID(channels{i});
    totchan=totchan+numel(pix);
end

if totchan>3
imds = imageDatastore(imagesfoldername,'FileExtensions','.mat','ReadFcn',@matReader);  
else
imds = imageDatastore(imagesfoldername);
end

nclasses=numel(classification.classes);
%colormap=classification.colormap(1:nclasses,:);

classes=string();
labelsIDs={};

for i=1:nclasses
    classes(i)=string(classification.classes{i});
    labelsIDs{i}=round(255*classification.colormap(i+1,:)); % !! +1 because the first index in the colormap is black color
end

pxds = pixelLabelDatastore(labelsfoldername,classes,labelsIDs);

I = readimage(imds,1);
%
% I = histeq(I);
% imshow(I)
% C = readimage(pxds,1);
% cmap = jet(2);
% B = labeloverlay(I,C,'ColorMap',classification.colormap(2:end,:));
% imshow(B)
% pixelLabelColorbar(classification.colormap(2:end,:),classes);

%figure, imshow(C,[])
%return;

tbl = countEachLabel(pxds);
frequency = tbl.PixelCount/sum(tbl.PixelCount);

%
% bar(1:numel(classes),frequency)
% xticks(1:numel(classes))
% xticklabels(tbl.Name)
% xtickangle(45)
% ylabel('Frequency')

[imdsTrain, imdsVal, pxdsTrain, pxdsVal] = partitionCamVidData(imds,pxds,classes,labelsIDs,trainingParam.CNN_data_splitting_factor,size(I,3));

% Specify the network image size. This is typically the same as the traing image sizes.
%imageSize = size(I); %[720 960 3];

%imageSize= [992 992 size(I,3)];

imageSize= [64 64 size(I,3)];

% Specify the number of classes.
numClasses = numel(classes);

% Create DeepLab v3+.
%nettype=1; % 1 for resnet50 , 0 for resnet18;

lgraph = unetLayers(imageSize,numClasses);


%analyzeNetwork(lgraph);
%return;

imageFreq = tbl.PixelCount ./ tbl.ImagePixelCount;
classWeights = median(imageFreq) ./ imageFreq;
%return;


pxLayer = pixelClassificationLayer('Name','labels','Classes',tbl.Name,'ClassWeights',classWeights); % removing the weights helped increase the resolution
lgraph = replaceLayer(lgraph,"Segmentation-Layer",pxLayer);

%pximdsVal = pixelLabelImageDatastore(imdsVal,pxdsVal);
pximdsVal = pixelLabelImageDatastore(imdsVal,pxdsVal,'OutputSize',imageSize(1:2),'OutputSizeMode','resize');

%pximdsVal= randomPatchExtractionDatastore(imdsVal,pxdsVal,[256,256],'PatchesPerImage',10);

% L2regularisation = 0.005;

options = trainingOptions(trainingParam.CNN_training_method{end}, ...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',2,...
    'LearnRateDropFactor',0.7,...
    'InitialLearnRate',trainingParam.CNN_initial_learning_rate, ...
    'L2Regularization',trainingParam.CNN_l2_regularization, ...
    'ValidationData',pximdsVal,...
    'MaxEpochs',trainingParam.CNN_max_epochs, ...
    'MiniBatchSize',trainingParam.CNN_mini_batch_size, ...
    'Shuffle',trainingParam.CNN_data_shuffling{end}, ...
    'CheckpointPath', tempdir, ...
    'VerboseFrequency',2,...
    'Plots','training-progress',...
    'ValidationFrequency', 10,...
    'ExecutionEnvironment',trainingParam.execution_environment{end}, ...
    'ValidationPatience', 500);%'Momentum',0.9);%, ...
%  'ValidationFrequency', 10,...


augmenter = imageDataAugmenter('RandXReflection',true,'RandYReflection',true,...
    'RandXScale',[0.5 2],'RandYScale',[0.5 2],...
    'RandRotation',trainingParam.CNN_rotation_augmentation,'RandXTranslation',trainingParam.CNN_translation_augmentation,'RandYTranslation',trainingParam.CNN_translation_augmentation);

%   'RandXScale',[0.9 1.1],'RandYScale',[0.9 1.1],...

pximds = pixelLabelImageDatastore(imdsTrain,pxdsTrain, ...
    'DataAugmentation',augmenter,'OutputSize',imageSize(1:2),'OutputSizeMode','resize'); % default input size imga for training

%pximds= randomPatchExtractionDatastore(imdsTrain,pxdsTrain,[256,256],'PatchesPerImage',10, 'DataAugmentation',augmenter);


%if doTraining
[classifier, info] = trainNetwork(pximds,lgraph,options);
fprintf('Training is done...\n');
save([path '/' name '.mat'],'classifier');
fprintf('Saving DeepLab network classifier...\n');

CNNOptions=struct(options);
if ~exist(fullfile(path,'TrainingValidation'))
    makedir(path,'TrainingValidation');
end

save(fullfile(path,'TrainingValidation','CNNOptions.mat'),'CNNOptions');

%saveTrainingPlot(path,name);


function [imdsTrain, imdsVal, pxdsTrain, pxdsVal] = partitionCamVidData(imds,pxds,classes,labelIDs,split,channels)
% Partition CamVid data by randomly selecting 60% of the data for training. The
% rest is used for testing.

% Set initial random state for example reproducibility.
rng(0);
numFiles = numel(imds.Files);
shuffledIndices = randperm(numFiles);

% Use 70% of the images for training.
numTrain = round(split * numFiles);
trainingIdx = shuffledIndices(1:numTrain);

% Use 20% of the images for validation
numtot = min(numTrain+round((1-split) * numFiles),numel(shuffledIndices));
valIdx = shuffledIndices(numTrain+1:numtot);

% Use the rest for testing.
%testIdx = shuffledIndices(numTrain+numVal+1:end);

% Create image datastores for training and test.
trainingImages = imds.Files(trainingIdx);
valImages = imds.Files(valIdx);
%testImages = imds.Files(testIdx);

if channels>3
imdsTrain = imageDatastore(trainingImages,'FileExtensions','.mat','ReadFcn',@matReader);
imdsVal = imageDatastore(valImages,'FileExtensions','.mat','ReadFcn',@matReader);
else
imdsTrain = imageDatastore(trainingImages);
imdsVal = imageDatastore(valImages);    
end
%imdsTest = imageDatastore(testImages);

% Extract class and label IDs info.
%classes = pxds.ClassNames;
%labelIDs = camvidPixelLabelIDs();

% Create pixel label datastores for training and test.
trainingLabels = pxds.Files(trainingIdx);
valLabels = pxds.Files(valIdx);
%testLabels = pxds.Files(testIdx);

pxdsTrain = pixelLabelDatastore(trainingLabels, classes, labelIDs);
pxdsVal = pixelLabelDatastore(valLabels, classes, labelIDs);
%pxdsTest = pixelLabelDatastore(testLabels, classes, labelIDs);