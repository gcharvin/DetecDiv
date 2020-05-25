function trainPixelDeeplabNetFun(path,name)

% gather all classification images in each class : unbudded, small budded,
% large budded, perform the training and outputs and saves the trained net 

% load training data 


fprintf('Loading data...\n');

imagesfoldername=[path '/trainingdataset/images'];

labelsfoldername=[path '/trainingdataset/labels'];

imds = imageDatastore(imagesfoldername);

load([path '/classification.mat']); % load the classification variable 

nclasses=numel(classification.classes);
%colormap=classification.colormap(1:nclasses,:);

classes=string();
labelsIDs={};

for i=1:nclasses
    classes(i)=string(classification.classes{i});
    labelsIDs{i}=round(255*classification.colormap(i+1,:)); % !! +1 because the first index in the colormap is black color
end


%classes=["Background" "Cell"];
%labelIDs={[255 0 0] [0 255 0]};

pxds = pixelLabelDatastore(labelsfoldername,classes,labelsIDs);

 I = readimage(imds,1);

% I = histeq(I);
% imshow(I)
% C = readimage(pxds,1);
% cmap = jet(2);
% B = labeloverlay(I,C,'ColorMap',cmap);
% imshow(B)
% pixelLabelColorbar(cmap,classes);

 tbl = countEachLabel(pxds);
 frequency = tbl.PixelCount/sum(tbl.PixelCount);
% 
% bar(1:numel(classes),frequency)
% xticks(1:numel(classes)) 
% xticklabels(tbl.Name)
% xtickangle(45)
% ylabel('Frequency')

[imdsTrain, imdsVal, pxdsTrain, pxdsVal] = partitionCamVidData(imds,pxds,classes,labelsIDs);

% Specify the network image size. This is typically the same as the traing image sizes.
imageSize = size(I); %[720 960 3];

% Specify the number of classes.
numClasses = numel(classes);

% Create DeepLab v3+.
nettype=1; % 1 for resnet50 , 0 for resnet18;

lgraph = helperDeeplabv3PlusResnet18(imageSize, numClasses,nettype);

%analyzeNetwork(lgraph);
%return;

imageFreq = tbl.PixelCount ./ tbl.ImagePixelCount;
classWeights = median(imageFreq) ./ imageFreq;

%analyzeNetwork(lgraph)
pxLayer = pixelClassificationLayer('Name','labels','Classes',tbl.Name); %,'ClassWeights',classWeights); % removing the weights helped increase the resolution 
lgraph = replaceLayer(lgraph,"classification",pxLayer);

pximdsVal = pixelLabelImageDatastore(imdsVal,pxdsVal);

% L2regularisation = 0.005;

if gpuDeviceCount>0
disp('Using GPUs and multiple workers');
options = trainingOptions('sgdm', ...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',10,...
    'LearnRateDropFactor',0.7,...
    'Momentum',0.9, ...
    'InitialLearnRate',1e-1, ...
    'L2Regularization',0.005, ...
    'ValidationData',pximdsVal,...
    'MaxEpochs',60, ...  
    'MiniBatchSize',64, ...
    'Shuffle','every-epoch', ...
    'CheckpointPath', tempdir, ...
    'VerboseFrequency',2,...
    'Plots','training-progress',...
    'ValidationFrequency', 10,...
    'ExecutionEnvironment','parallel', ...
    'ValidationPatience', 4);
else
 disp('Using CPUs or whatever is available');
   options = trainingOptions('sgdm', ...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',10,...
    'LearnRateDropFactor',0.7,...
    'Momentum',0.9, ...
    'InitialLearnRate',1e-2, ...
    'L2Regularization',0.005, ...
    'ValidationData',pximdsVal,...
    'MaxEpochs',30, ...  
    'MiniBatchSize',8, ...
    'Shuffle','every-epoch', ...
    'CheckpointPath', tempdir, ...
    'VerboseFrequency',2,...
    'Plots','training-progress',...
    'ValidationFrequency', 10,...
    'ExecutionEnvironment','auto', ...
    'ValidationPatience', 4); 
end
    
  %  'ValidationFrequency', 10,...
  
augmenter = imageDataAugmenter('RandXReflection',true,'RandYReflection',true,...
  'RandXScale',[0.9 1.1],'RandYScale',[0.9 1.1],...   
    'RandXTranslation',[-10 10],'RandYTranslation',[-10 10]);

%   'RandXScale',[0.9 1.1],'RandYScale',[0.9 1.1],... 

pximds = pixelLabelImageDatastore(imdsTrain,pxdsTrain, ...
    'DataAugmentation',augmenter);

%if doTraining
 [classifier, info] = trainNetwork(pximds,lgraph,options);
 fprintf('Training is done...\n');
save([path '/' name '.mat'],'classifier');
fprintf('Saving DeepLab netork classifier...\n');

%else
%  load([mov.path '/netDeepLab.mat'],'netDeepLab');  
%end

% if doTest
%     cmap=lines(2);
%     I = readimage(imdsTest,option);
%     C = semanticseg(I, netDeepLab);
%     B = labeloverlay(I,C,'Colormap',cmap,'Transparency',0.4);
% imshow(B)
% pixelLabelColorbar(cmap, classes);
% end


function pixelLabelColorbar(cmap, classNames)
% Add a colorbar to the current axis. The colorbar is formatted
% to display the class names with the color.

colormap(gca,cmap)

% Add colorbar to current figure.
c = colorbar('peer', gca);

% Use class names for tick marks.
c.TickLabels = classNames;
numClasses = size(cmap,1);

% Center tick labels.
c.Ticks = 1/(numClasses*2):1/numClasses:1;

% Remove tick mark.
c.TickLength = 0;

function [imdsTrain, imdsVal, pxdsTrain, pxdsVal] = partitionCamVidData(imds,pxds,classes,labelIDs)
% Partition CamVid data by randomly selecting 60% of the data for training. The
% rest is used for testing.
    
% Set initial random state for example reproducibility.
rng(0); 
numFiles = numel(imds.Files);
shuffledIndices = randperm(numFiles);

% Use 70% of the images for training.
numTrain = round(0.70 * numFiles);
trainingIdx = shuffledIndices(1:numTrain);

% Use 20% of the images for validation
numtot = min(numTrain+round(0.30 * numFiles),numel(shuffledIndices));
valIdx = shuffledIndices(numTrain+1:numtot);

% Use the rest for testing.
%testIdx = shuffledIndices(numTrain+numVal+1:end);

% Create image datastores for training and test.
trainingImages = imds.Files(trainingIdx);
valImages = imds.Files(valIdx);
%testImages = imds.Files(testIdx);

imdsTrain = imageDatastore(trainingImages);
imdsVal = imageDatastore(valImages);
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
