function testdatastore

imds = imageDatastore('image','FileExtensions','.mat','ReadFcn',@matReader);

I = readimage(imds,1);

classes=["un" "deux"];

labels={0 1};

pxds = pixelLabelDatastore('label',classes,labels)

tbl = countEachLabel(pxds);
frequency = tbl.PixelCount/sum(tbl.PixelCount)


[imdsTrain, imdsVal, pxdsTrain, pxdsVal] = partitionCamVidData(imds,pxds,classes,labels,0.5,size(I,3));


imageSize = size(I); %[720 960 3];

imageSize= [992 992 4];

imageSize= [256 256 4];

% Specify the number of classes.
numClasses = numel(classes);

% Create DeepLab v3+.
%nettype=1; % 1 for resnet50 , 0 for resnet18;

lgraph = unetLayers(imageSize,numClasses);

% analyzeNetwork(lgraph)
% return


imageFreq = tbl.PixelCount ./ tbl.ImagePixelCount;
classWeights = median(imageFreq) ./ imageFreq;
% 
pxLayer = pixelClassificationLayer('Name','labels','Classes',tbl.Name,'ClassWeights',classWeights); % removing the weights helped increase the resolution
lgraph = replaceLayer(lgraph,"Segmentation-Layer",pxLayer);


%dsTrain = randomPatchExtractionDatastore(imds,pxds,[256,256],'PatchesPerImage',16000);

pximdsVal= randomPatchExtractionDatastore(imdsVal,pxdsVal,[256,256],'PatchesPerImage',1600);

%pximdsVal = pixelLabelImageDatastore(imdsVal,pxdsVal,'OutputSize',imageSize(1:2),'OutputSizeMode','resize');

options = trainingOptions('adam', ...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',2,...
    'LearnRateDropFactor',0.7,...
    'InitialLearnRate',0.001, ...
    'L2Regularization',0.005, ...
    'ValidationData',pximdsVal,...
    'MaxEpochs',3, ...
    'MiniBatchSize',1, ...
    'Shuffle','every-epoch', ...
    'CheckpointPath', tempdir, ...
    'VerboseFrequency',2,...
    'Plots','training-progress',...
    'ValidationFrequency', 10,...
    'ExecutionEnvironment','gpu', ...
    'ValidationPatience', 500);%'Momentum',0.9);%, ...
%  'ValidationFrequency', 10,...


augmenter = imageDataAugmenter('RandXReflection',true,'RandYReflection',true,...
    'RandXScale',[0.5 2],'RandYScale',[0.5 2],...
    'RandRotation',[-5 5],'RandXTranslation',[-5 5],'RandYTranslation',[-5 5]);

%   'RandXScale',[0.9 1.1],'RandYScale',[0.9 1.1],...

pximds= randomPatchExtractionDatastore(imdsTrain,pxdsTrain,[256,256],'PatchesPerImage',1600, 'DataAugmentation',augmenter);

%pximds = pixelLabelImageDatastore(imdsTrain,pxdsTrain, ...
%    'DataAugmentation',augmenter,'OutputSize',imageSize(1:2),'OutputSizeMode','resize'); % default input size imga for training

%if doTraining
[classifier, info] = trainNetwork(pximds,lgraph,options);



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