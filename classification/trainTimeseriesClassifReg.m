function trainTimeseriesClassifReg(classif,setparam)

path=fullfile(classif.path);
name=classif.strid;

%---------------- parameters setting
if nargin==2 % basic parameter initialization
        
        tip={'Specify if each frame should be classified, or if one class is expected for the whole sequence of images',...
             'Choose the training method',...
               'Enter the number of epochs',...
                 'Choose whether and how training and validation data should be shuffled during training',...
                  'Specify value for L2 regularization',...
                   'Choose the fraction of the data to be used for training vs validation during LSTM training',...
                    'Enter the size of the hidden unit',...
                     'Choose the size of the mini batch; Higher values require more memory and are prone to errors',...
                       'Enter the initial learning rate'
                            'Select initial version of network to start training with; Default: ImageNet'};
       
        classif.trainingParam=struct('classifier_output',{{'sequence-to-sequence','sequence-to-one','sequence-to-sequence'}},...
            'LSTM_training_method',{{'adam','sgdm','adam'}},...
            'LSTM_max_epochs',6,...
            'LSTM_data_shuffling',{{'once','every-epoch','never','every-epoch'}},...
            'LSTM_l2_regularization',0.00001,...
            'LSTM_data_splitting_factor',0.9,...
            'LSTM_hidden_size',150,...
            'LSTM_mini_batch_size',8,...
            'LSTM_initial_learning_rate', 0.0001,...
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
    

fprintf('Loading training data...\n');
filename=fullfile(path,'trainingdataset','TrainingData.mat');

if exist(filename)
load(filename); % load XTrain, YTrain, and classes variable

else
    disp('Training data are not available, first format training data !');
    return;
end

seq={};
if numel(classif.classes)>0 % classification problem
for i=1:numel(YTrain)
        seq{i}=categorical(YTrain{i},1:numel(classes),classes);
end
else
    seq=YTrain;
end

YTrain=seq;

disp('Preparing LSTM network ...');
fprintf('------\n');

% %=====BLOCKs RNG====
% stCPU= RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
% stGPU=parallel.gpu.RandStream('Threefry','Seed',0,'NormalTransform','Inversion');
% RandStream.setGlobalStream(stCPU);
% parallel.gpu.RandStream.setGlobalStream(stGPU);
% %===================

numObservations = numel(XTrain);
idx = randperm(numObservations);
N = floor(trainingParam.LSTM_data_splitting_factor* numObservations); % 0.9 replace
%N=1;
if N==0
    N=1;
end

idxTrain = idx(1:N);
%idxTrain=1; % warning

sequencesTrain = XTrain(idxTrain);
labelsTrain = YTrain(idxTrain);
%class(labelsTrain)
%size(labelsTrain)
%class(labelsTrain{:})
%size(labelsTrain{:})
%labelsTrain{1}= repmat(labelsTrain{1},[1 500])
%class(labels{1})

if trainingParam.classifier_output{end}==1 % sequence to one classification
    labelsTrain=[labelsTrain{:}]';
end

idxValidation = idx(N+1:end);
%idxValidation = 1; %warning
if numel(idxValidation)==0
    idxValidation = 1;
end
sequencesValidation =XTrain(idxValidation);
labelsValidation = YTrain(idxValidation);

if trainingParam.classifier_output{end}==1 % sequence to one classification
    labelsValidation = [labelsValidation{:}]';
end


% labelsValidation{1}= repmat(labelsValidation{1},[1 500])
% create LSTM network

if numel(classif.classes)>0 % classification
    numFeatures = size(sequencesTrain{1},1);
    numClasses = numel(classif.classes); %numel(categories(labelsTrain{1}));
    
    %ntot=countcats(labelsTrain{1});
    %weights = double(ntot)/double(sum(ntot));
    
    sucl=zeros(numObservations,numClasses);
    
    for i=1:numObservations
        
        sucl(i,:)=countcats(YTrain{i});
    end
    sucl=sum(sucl,1);
    
    tempsucl=sucl(sucl>0);
    if numel(tempsucl)
    sucl(sucl==0)=min(tempsucl(:));
    classWeights = 1./sucl;
    classWeights = classWeights'/mean(classWeights);
    else
        classWeights=ones(1,numel(classif.classes));
    end
    
    %classWeights(isnan(classWeights))=0;
    %classWeights
    %return;
    %     layers = [
    %         sequenceInputLayer(numFeatures,'Name','sequence')
    %         bilstmLayer(trainingParam.lstmlayers,'OutputMode','sequence','Name','bilstm')
    %         % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
    %         dropoutLayer(0.5,'Name','drop');
    %         fullyConnectedLayer(numClasses,'Name','fc')
    %         softmaxLayer('Name','softmax')
    %         classificationLayer('Name','classification')];
    
    %==============OPTIONS=================
    
    if trainingParam.classifier_output{end}==0 % seuqence to sequence clssif
        if strcmp(trainingParam.transfer_learning{end},'ImageNet') % creates a new network
        disp('Generating new network');
        layers = [
            sequenceInputLayer(numFeatures,'Name','sequence')
            bilstmLayer(trainingParam.LSTM_hidden_size,'OutputMode','sequence','Name','bilstm')
            % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
            dropoutLayer(0.5,'Name','drop');
            fullyConnectedLayer(numClasses,'Name','fc')
            softmaxLayer('Name','softmax')
            weightedLSTMClassificationLayer(classWeights,'classification')];
        else
                           disp(['Loading previously trained network : ' trainingParam.transfer_learning{end}]);
 strpth=fullfile(classif.path,  trainingParam.transfer_learning{end});
if exist(strpth)
    load(strpth); %loads classifier
 layers = layerGraph(classifier);    
else
    disp(['Unable to load: ' trainingParam.transfer_learning{end}]);
    return;
end
        end
    else % sequence to one classification
          if strcmp(trainingParam.transfer_learning{end},'ImageNet') % creates a new network
        disp('Generating new network');
        layers = [
            sequenceInputLayer(numFeatures,'Name','sequence')
            bilstmLayer(trainingParam.LSTM_hidden_size,'OutputMode','last','Name','bilstm')
            % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
            dropoutLayer(0.5,'Name','drop');
            fullyConnectedLayer(numClasses,'Name','fc')
            softmaxLayer('Name','softmax')
            weightedLSTMClassificationLayer(classWeights,'classification')];
          else
                 disp(['Loading previously trained network : ' trainingParam.transfer_learning{end}]);
 strpth=fullfile(classif.path,  trainingParam.transfer_learning{end});
if exist(strpth)
    load(strpth); %loads classifier
 layers = layerGraph(classifier);    
else
    disp(['Unable to load: ' trainingParam.transfer_learning{end}]);
    return;
end
          end
    end
    
else % regression
    numClasses=1;
    numFeatures = size(sequencesTrain{1},1);
    
    if trainingParam.classifier_output{end}==0
          if strcmp(trainingParam.transfer_learning{end},'ImageNet') % creates a new network
        disp('Generating new network');
        
        layers = [
            sequenceInputLayer(numFeatures,'Name','sequence')
            bilstmLayer(trainingParam.LSTM_hidden_size,'OutputMode','sequence','Name','bilstm')
            % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
            dropoutLayer(0.5,'Name','drop');
            fullyConnectedLayer(numClasses,'Name','fc')
            regressionLayer];
        %softmaxLayer('Name','softmax')
        %weightedLSTMClassificationLayer(classWeights,'classification')];
          else
                disp(['Loading previously trained network : ' trainingParam.transfer_learning{end}]);
 strpth=fullfile(classif.path,  trainingParam.transfer_learning{end});
if exist(strpth)
    load(strpth); %loads classifier
 layers = layerGraph(classifier);    
else
    disp(['Unable to load: ' trainingParam.transfer_learning{end}]);
    return;
end
          end
    else
          if strcmp(trainingParam.transfer_learning{end},'ImageNet') % creates a new network
        disp('Generating new network');
        layers = [
            sequenceInputLayer(numFeatures,'Name','sequence')
            bilstmLayer(trainingParam.LSTM_hidden_size,'OutputMode','last','Name','bilstm')
            % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
            dropoutLayer(0.5,'Name','drop');
            fullyConnectedLayer(numClasses,'Name','fc')
            regressionLayer];
        %softmaxLayer('Name','softmax')
        %weightedLSTMClassificationLayer(classWeights,'classification')];
          else
   disp(['Loading previously trained network : ' trainingParam.transfer_learning{end}]);
 strpth=fullfile(classif.path,  trainingParam.transfer_learning{end});
if exist(strpth)
    load(strpth); %loads classifier
 layers = layerGraph(classifier);    
else
    disp(['Unable to load: ' trainingParam.transfer_learning{end}]);
    return;
end
          end
    end
end

% specifiy training options

miniBatchSize = trainingParam.LSTM_mini_batch_size;
numObservations = numel(sequencesTrain);
numIterationsPerEpoch = max(1,floor(numObservations / miniBatchSize));

% sequencesTrain,labelsTrain
% 
% sequencesValidation,labelsValidation

options = trainingOptions(trainingParam.LSTM_training_method{end}, ...
    'MiniBatchSize',miniBatchSize, ...
    'MaxEpochs',300,...
    'InitialLearnRate',trainingParam.LSTM_initial_learning_rate, ...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',10,...
    'LearnRateDropFactor',0.9,...
    'GradientThreshold',2, ...
    'Shuffle',trainingParam.LSTM_data_shuffling{end}, ...
    'ValidationData',{sequencesValidation,labelsValidation}, ...
    'ValidationFrequency',numIterationsPerEpoch, ...
    'Plots','training-progress', ...
    'ExecutionEnvironment','auto',...
    'VerboseFrequency',10);

% warning : Parallel training of recurrent networks is not supported. 'ExecutionEnvironment' value in trainingOptions function must be 'auto',

disp('Training LSTM network ...');
fprintf('------\n');

[classifier,info] = trainNetwork(sequencesTrain,labelsTrain,layers,options);

    save([path '/' name '.mat'],'classifier');

    saveTrainingPlot(path, 'LSTMTraining'); 
    
disp('Training LSTM network is done and saved ...');
fprintf('------\n');

