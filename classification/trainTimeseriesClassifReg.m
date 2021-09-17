function trainTimeseriesClassifReg(path,name)


fprintf('Loading training data...\n');
filename=fullfile(path,'trainingdataset','TrainingData.mat');

load(filename); % load XTrain, YTrain, and classes variable

seq={};
if numel(classes)>0 % classification problem
for i=1:numel(YTrain)
        seq{i}=categorical(YTrain{i},1:numel(classes),classes);
end
else
    seq=YTrain;
end

YTrain=seq;

fprintf('Loading training options...\n');
fprintf('------\n');

load([path '/trainingParam.mat']);


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
N = floor(trainingParam.lstmsplit* numObservations); % 0.9 replace

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

if trainingParam.output==1 % sequence to one classification
    labelsTrain=[labelsTrain{:}]';
end

idxValidation = idx(N+1:end);
%idxValidation = 1; %warning

sequencesValidation =XTrain(idxValidation);
labelsValidation = YTrain(idxValidation);

if trainingParam.output==1 % sequence to one classification
    labelsValidation = [labelsValidation{:}]';
end


% labelsValidation{1}= repmat(labelsValidation{1},[1 500])
% create LSTM network

if numel(trainingParam.classes)>0 % classification
    numFeatures = size(sequencesTrain{1},1);
    numClasses = numel(trainingParam.classes); %numel(categories(labelsTrain{1}));
    
    %ntot=countcats(labelsTrain{1});
    %weights = double(ntot)/double(sum(ntot));
    
    sucl=zeros(numObservations,numClasses);
    
    for i=1:numObservations
        
        sucl(i,:)=countcats(YTrain{i});
    end
    sucl=sum(sucl,1);
    
    tempsucl=sucl(sucl>0);
    sucl(sucl==0)=min(tempsucl(:));
    classWeights = 1./sucl;
    classWeights = classWeights'/mean(classWeights);
    
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
    
    if trainingParam.output==0 % seuqence to sequence clssif
        layers = [
            sequenceInputLayer(numFeatures,'Name','sequence')
            bilstmLayer(trainingParam.lstmlayers,'OutputMode','sequence','Name','bilstm')
            % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
            dropoutLayer(0.5,'Name','drop');
            fullyConnectedLayer(numClasses,'Name','fc')
            softmaxLayer('Name','softmax')
            weightedLSTMClassificationLayer(classWeights,'classification')];
    else % sequence to one classification
        layers = [
            sequenceInputLayer(numFeatures,'Name','sequence')
            bilstmLayer(trainingParam.lstmlayers,'OutputMode','last','Name','bilstm')
            % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
            dropoutLayer(0.5,'Name','drop');
            fullyConnectedLayer(numClasses,'Name','fc')
            softmaxLayer('Name','softmax')
            weightedLSTMClassificationLayer(classWeights,'classification')];
    end
    
else % regression
    numClasses=1;
    numFeatures = size(sequencesTrain{1},1);
    
    if trainingParam.output==0
        layers = [
            sequenceInputLayer(numFeatures,'Name','sequence')
            bilstmLayer(trainingParam.lstmlayers,'OutputMode','sequence','Name','bilstm')
            % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
            dropoutLayer(0.5,'Name','drop');
            fullyConnectedLayer(numClasses,'Name','fc')
            regressionLayer];
        %softmaxLayer('Name','softmax')
        %weightedLSTMClassificationLayer(classWeights,'classification')];
    else
        layers = [
            sequenceInputLayer(numFeatures,'Name','sequence')
            bilstmLayer(trainingParam.lstmlayers,'OutputMode','last','Name','bilstm')
            % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
            dropoutLayer(0.5,'Name','drop');
            fullyConnectedLayer(numClasses,'Name','fc')
            regressionLayer];
        %softmaxLayer('Name','softmax')
        %weightedLSTMClassificationLayer(classWeights,'classification')];
    end
end

% specifiy training options

miniBatchSize = trainingParam.lstmMiniBatchSize;
numObservations = numel(sequencesTrain);
numIterationsPerEpoch = max(1,floor(numObservations / miniBatchSize));

options = trainingOptions('adam', ...
    'MiniBatchSize',miniBatchSize, ...
    'MaxEpochs',300,...
    'InitialLearnRate',trainingParam.lstmInitialLearnRate, ...
    'LearnRateSchedule','piecewise',...
    'LearnRateDropPeriod',10,...
    'LearnRateDropFactor',0.9,...
    'GradientThreshold',2, ...
    'Shuffle','every-epoch', ...
    'ValidationData',{sequencesValidation,labelsValidation}, ...
    'ValidationFrequency',numIterationsPerEpoch, ...
    'Plots','training-progress', ...
    'ExecutionEnvironment','auto',...
    'VerboseFrequency',10);

% warning : Parallel training of recurrent networks is not supported. 'ExecutionEnvironment' value in trainingOptions function must be 'auto',
%'gpu', or 'cpu'.

%options.SequenceLength
%options.SequencePaddingValue
%return;
% train network
disp('Training LSTM network ...');
fprintf('------\n');

[classifier,info] = trainNetwork(sequencesTrain,labelsTrain,layers,options);

    save([path '/' name '.mat'],'classifier');

    saveTrainingPlot(path, 'LSTMTraining'); 
    
disp('Training LSTM network is done and saved ...');
fprintf('------\n');




% if nargin==2
%     roilist=1:numel(classiobj.roi);
% end
% 
% className=classiobj.classes{classeid};
% cate=categorical({className, 'other'});
% classes=categories(cate);
% 
% % get the groundtruth data and results from classif
% 
% X={};
% Y={};
% 
% for i=1:numel(roilist)
%     roiid=roilist(i);
%     
%     X{i}=classiobj.roi(roiid).results.(classiobj.strid).prob(classeid,:);
%     temp=uint8(classiobj.roi(roiid).train.(classiobj.strid).id==classeid);
%     temp=temp+1;
%     Y{i}=categorical(temp,[1 2],classes);
% end
% 
% 
% lstmmodel=[];
% 
% % setup architecture of lstm network
% 
% numFeatures = 1;
% numHiddenUnits = 20;
% numClasses = 2;
% 
% layers = [ ...
%     sequenceInputLayer(numFeatures)
%     lstmLayer(numHiddenUnits,'OutputMode','sequence')
%     fullyConnectedLayer(numClasses)
%     softmaxLayer
%     classificationLayer];
% 
% options = trainingOptions('adam', ...
%     'MaxEpochs',300, ...
%     'InitialLearnRate',0.005, ...
%     'GradientThreshold',2, ...
%     'Verbose',0, ...
%     'Plots','training-progress');
% 
% lstmmodel = trainNetwork(X,Y,layers,options);
