function trainUNetRegFun(classif, setparam)

% Gather all noisy and clean images for training and perform the training,
% then output and save the trained net.

path = fullfile(classif.path);
name = classif.strid;

% ---------------- Parameters setting
if nargin == 2
    % Basic parameter initialization
    tip = {'Choose the training method',...
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
       
    classif.trainingParam = struct('CNN_training_method', {{'adam','sgdm','adam'}},...
                                   'CNN_mini_batch_size', 8,...
                                   'CNN_max_epochs', 20,...
                                   'CNN_initial_learning_rate', 0.001,...
                                   'CNN_data_shuffling', {{'once','every-epoch','never','every-epoch'}},...
                                   'CNN_data_splitting_factor', 0.9,...
                                   'CNN_translation_augmentation', [-5 5],...
                                   'CNN_rotation_augmentation', [-20 20],...
                                   'CNN_l2_regularization', 0.00001,...
                                   'execution_environment', {{'auto','parallel','cpu','gpu','multi-gpu','auto'}},...
                                   'transfer_learning', {{'ImageNet','ImageNet'}},...
                                   'tip', {tip});
    return;
else
    trainingParam = classif.trainingParam;
    if numel(trainingParam) == 0
        disp('Could not find training parameters.');
        return;
    end
end

% ---------------- Load data
fprintf('Loading data...\n');

imagesfoldername = [path '/trainingdataset/images'];
labelsfoldername = [path '/trainingdataset/labels'];


   % Créer les datastores pour les images bruitées et propres
    imdsNoisy = imageDatastore(imagesfoldername, 'ReadFcn', @(x) im2double(imread(x)));
    imdsClean = imageDatastore(labelsfoldername, 'ReadFcn', @(x) im2double(imread(x)));

    I = readimage(imdsNoisy,1);
imageSize = size(I); %[720 960 3];

two=[2.^(4:9) 992]; % 992 is the max network size for unet;

pix=find(two>=imageSize(1),1,'first');
if numel(pix)==0
    nsize=992;
else
    nsize=two(pix);
end

imageSize= [nsize nsize size(I,3)];

    % Diviser les données en ensembles d'entraînement et de validation
    [imdsNoisyTrain, imdsNoisyVal, imdsCleanTrain, imdsCleanVal] = ...
        partitionDenoisingData(imdsNoisy, imdsClean, trainingParam.CNN_data_splitting_factor);

    % Ajuster la taille des images pour être compatibles avec U-Net
    adjustedHeight = nsize; % Exemple : à remplacer par votre taille d'image
    adjustedWidth = nsize; % Exemple : à remplacer par votre taille d'image

% ---------------- Combiner les datastores
dsTrainCombined = combine(imdsNoisyTrain, imdsCleanTrain);
dsValCombined = combine(imdsNoisyVal, imdsCleanVal);

% ---------------- Appliquer les transformations

% Créer un augmentateur de données
augmenter = imageDataAugmenter('RandXReflection', true, ...
    'RandYReflection', true, ...
    'RandRotation', trainingParam.CNN_rotation_augmentation, ...
    'RandXTranslation', trainingParam.CNN_translation_augmentation, ...
    'RandYTranslation', trainingParam.CNN_translation_augmentation);

% Appliquer une transformation avec augmentation
trainingDatastore = transform(dsTrainCombined, ...
    @(data) augmentAndResize(data{1}, data{2}, augmenter, adjustedHeight, adjustedWidth));

% Testez la structure des données retournées par trainingDatastore
dataSample = read(trainingDatastore);

% Affichez les dimensions et types des données

% disp(size(dataSample)); % Taille globale (doit être une cellule avec 2 colonnes)
% disp(size(dataSample{1})); % Dimensions de l'image bruitée (entrée)
% %disp(size(dataSample{1}{1})); % Dimensions de l'image bruitée (entrée)
% %disp(size(dataSample{1}{2})); % Dimensions de l'image bruitée (entrée)
% disp(size(dataSample{2})); % Dimensions de l'image propre (cible)

% Données de validation
validationDatastore = transform(dsValCombined, ...
    @(data) {imresize(data{1}, [adjustedHeight, adjustedWidth]), ...
             imresize(data{2}, [adjustedHeight, adjustedWidth])});

% ---------------- Set up U-Net
if strcmp(trainingParam.transfer_learning{end}, 'ImageNet') % Creates a new network
   
disp('Generating new network...');
% Ajuster la taille des images pour être des multiples de 8
height = imageSize(1);
width = imageSize(2);

adjustedHeight = ceil(height / 8) * 8; % Arrondir au multiple de 8 supérieur
adjustedWidth = ceil(width / 8) * 8;  % Arrondir au multiple de 8 supérieur
imageSize = [adjustedHeight, adjustedWidth, imageSize(3)];

% Créer le réseau U-Net
lgraph = unetLayers(imageSize, 3, 'EncoderDepth', 3); % Temporarily set numClasses = 2
%here 

myL1LossLayer = l1LossLayer('L1LossOutput'); % regression layer based on L1 error function, rather than L2 error function 
% Ajouter une couche de régression (le nom "regressionOutput" peut être utilisé ici)
%myregressionLayer = regressionLayer('Name', 'regressionOutput');

lgraph = removeLayers(lgraph, 'Softmax-Layer'); % Supprimer la couche Softmax
lgraph = removeLayers(lgraph, 'Segmentation-Layer');
%lgraph = addLayers(lgraph, myregressionLayer);
lgraph = addLayers(lgraph, myL1LossLayer);
%lgraph = connectLayers(lgraph, 'Final-ConvolutionLayer', 'regressionOutput');
lgraph = connectLayers(lgraph, 'Final-ConvolutionLayer', 'L1LossOutput');
%analyzeNetwork(lgraph);
else
    disp(['Loading previously trained network: ' trainingParam.transfer_learning{end}]);
    strpth = fullfile(classif.path, trainingParam.transfer_learning{end});
    if exist(strpth, 'file')
        load(strpth); % Loads previously trained classifier
        lgraph = layerGraph(classifier);
    else
        disp(['Unable to load: ' trainingParam.transfer_learning{end}]);
        return;
    end
end

% ---------------- Training options
options = trainingOptions(trainingParam.CNN_training_method{end}, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropPeriod', 2, ...
    'LearnRateDropFactor', 0.8, ...
    'InitialLearnRate', trainingParam.CNN_initial_learning_rate, ...
    'L2Regularization', trainingParam.CNN_l2_regularization, ...
    'ValidationData', validationDatastore, ...
    'MaxEpochs', trainingParam.CNN_max_epochs, ...
    'MiniBatchSize', trainingParam.CNN_mini_batch_size, ...
    'Shuffle', trainingParam.CNN_data_shuffling{end}, ...
    'CheckpointPath', tempdir, ...
    'VerboseFrequency', 2, ...
    'Plots', 'training-progress', ...
    'ValidationFrequency', 10, ...
    'ExecutionEnvironment', trainingParam.execution_environment{end}, ...
    'ValidationPatience', 500);

% ---------------- Train network
[classifier, info] = trainNetwork(trainingDatastore, lgraph, options);
fprintf('Training is done...\n');

% Save the trained network
save([path '/' name '.mat'],'classifier');
fprintf('Saved the trained regression network...\n');
end

function augmentedData = augmentAndResize(inputImage, targetImage, augmenter, height, width)
    % Redimensionner les images
    resizedInput = imresize(inputImage, [height, width]);
    resizedTarget = imresize(targetImage, [height, width]);

    % Appliquer l'augmentation directement
    augmentedInput = augmenter.augment(resizedInput);
    augmentedTarget = augmenter.augment(resizedTarget);

    % Retourner une cellule avec deux colonnes
    augmentedData = {augmentedInput, augmentedTarget};
end

function augmentedImage = augmentImage(augmenter, image)
    % Appliquer l'augmentation (s'assure que l'image reste compatible)
    augmentedImage = augmenter.augment(image);
end


function [imdsTrain, imdsVal, cleanImdsTrain, cleanImdsVal] = partitionDenoisingData(imds, cleanImds, split)
% Partition the data into training and validation sets

rng(0);
numFiles = numel(imds.Files);
shuffledIndices = randperm(numFiles);

% Training split
numTrain = round(split * numFiles);
trainingIdx = shuffledIndices(1:numTrain);

% Validation split
numVal = numFiles - numTrain;
valIdx = shuffledIndices(numTrain + 1:end);

% Create datastores
imdsTrain = subset(imds, trainingIdx);
imdsVal = subset(imds, valIdx);

cleanImdsTrain = subset(cleanImds, trainingIdx);
cleanImdsVal = subset(cleanImds, valIdx);

end
