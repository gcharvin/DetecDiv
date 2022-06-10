function trainPixelDeeplabNetFun(classif,setparam)

% gather all classification images in each class : unbudded, small budded,
% large budded, perform the training and outputs and saves the trained net

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
            'Check if random crossvalidation is to be performed',...
            'Enter the magnitude of translation for data augmentation (in pixels)',...
            'Enter the magnitude of rotation for data augmentation (in pixels)',...
            'Specify value for L2 regularization',...
            'Choose execution environment',...
            'Select initial version of network to start training with; Default: ImageNet'};
      
        classif.trainingParam=struct('CNN_training_method',{{'adam','sgdm','adam'}},...
            'CNN_network',{{'resnet18','resnet50','resnet50'}},...
            'CNN_mini_batch_size',8,...
            'CNN_max_epochs',20,...
            'CNN_initial_learning_rate',0.001,...
            'CNN_data_shuffling',{{'once','every-epoch','never','every-epoch'}},...
            'CNN_data_splitting_factor',0.9,...
            'CNN_crossvalidation',false,...
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


imagesfoldername=[path '/trainingdataset/images'];

labelsfoldername=[path '/trainingdataset/labels'];

imds = imageDatastore(imagesfoldername);

classification=classif;


nclasses=numel(classification.classes);
%colormap=classification.colormap(1:nclasses,:);

classes=string();
labelsIDs={};

for i=1:nclasses
    classes(i)=string(classification.classes{i});
    labelsIDs{i}=round(255*classification.colormap(i+1,:)); % !! +1 because the first index in the colormap is black color
end

%classes, labelsIDs

%classes=["Background" "Cell"];
%labelIDs={[255 0 0] [0 255 0]};

pxds = pixelLabelDatastore(labelsfoldername,classes,labelsIDs);

%return;

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



if trainingParam.CNN_crossvalidation==true % randomly select rois, respecting the initial number of ROIs in classif.trainingset variable
 nrois= numel(classif.trainingset);
 shuffledIndices = randperm(numel(classif.roi));
 classif.trainingset=shuffledIndices(1:nrois);
end

disp('ROis used for training : ' );

roitraining=classif.trainingset;

[imds, pxds] = subSelectTrainingSet(imds,pxds,classes,labelsIDs, classif); % subselect images in datastore according to their belonging to classif.trainingset
 
nfiles=numel(imds.Files);

[imdsTrain, imdsVal, pxdsTrain, pxdsVal] = partitionCamVidData(imds,pxds,classes,labelsIDs,trainingParam.CNN_data_splitting_factor);

% Specify the network image size. This is typically the same as the traing image sizes.
imageSize = size(I); %[720 960 3];

% Specify the number of classes.
numClasses = numel(classes);
imageFreq = tbl.PixelCount ./ tbl.ImagePixelCount;
classWeights = median(imageFreq) ./ imageFreq;

% Create DeepLab v3+.
%nettype=1; % 1 for resnet50 , 0 for resnet18;

if strcmp(trainingParam.transfer_learning{end},'ImageNet') % creates a new network
disp('Generating new network');
lgraph = helperDeeplabv3PlusResnet18(imageSize, numClasses,trainingParam.CNN_network{end});

%analyzeNetwork(lgraph);
%return;

% this replacement is used when wighted classes must be used :
%pxLayer=tverskyPixelClassificationLayer('labels',0.7,0.3); % alpha and beta parameters
%pxLayer.Classes=tbl.Name;
%pxLayer=dicePixelClassificationLayer('Name','labels','Classes',tbl.Name);

pxLayer = pixelClassificationLayer('Name','labels','Classes',tbl.Name,'ClassWeights',classWeights); % removing the weights helped increase the resolution
lgraph = replaceLayer(lgraph,"classification",pxLayer);
else
 disp(['Loading previously trained network : ' trainingParam.transfer_learning{end}]);
 strpth=fullfile(classif.path,  trainingParam.transfer_learning{end});
if exist(strpth)
    load(strpth); %loads classifier
 lgraph = layerGraph(classifier);    
else
    disp(['Unable to load: ' trainingParam.transfer_learning{end}]);
    return;
end
end

%pximdsVal = pixelLabelImageDatastore(imdsVal,pxdsVal);
pximdsVal = pixelLabelImageDatastore(imdsVal,pxdsVal,'OutputSize',imageSize(1:2),'OutputSizeMode','resize');

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

%if doTraining
[classifier, info] = trainNetwork(pximds,lgraph,options);
fprintf('Training is done...\n');
save([path '/' name '.mat'],'classifier');
fprintf('Saving DeepLab network classifier...\n');

CNNOptions=struct(options);
if ~exist(fullfile(path,'TrainingValidation'))
    mkdir(path,'TrainingValidation');
end

save(fullfile(path,'TrainingValidation','CNNOptions.mat'),'CNNOptions');

%saveTrainingPlot(path,name);


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

function [imdsTrain, imdsVal, pxdsTrain, pxdsVal] = partitionCamVidData(imds,pxds,classes,labelIDs,split)
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


function [imdsTrain, pxdsTrain] = subSelectTrainingSet(imds,pxds,classes,labelIDs, classif)
% subselect data in the trainingset

str={};
for i=1:numel(classif.trainingset)
    str{i}= classif.roi(classif.trainingset(i)).id;
end

pix=contains(imds.Files,str);

trainingImages = imds.Files(pix);

imdsTrain = imageDatastore(trainingImages);

trainingLabels = pxds.Files(pix);

pxdsTrain = pixelLabelDatastore(trainingLabels, classes, labelIDs);


