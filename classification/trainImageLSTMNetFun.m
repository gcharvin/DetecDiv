function trainImageLSTMNetFun(path,name)


fprintf('Loading training options...\n');
fprintf('------\n');

load([path '/trainingParam.mat']);

%load([ path '/options.mat']); % loading options for training --> imageclassifier, cactivations, lstm_training, assemblenet, validation


%%% training image classifier

if strcmp(trainingParam.imageclassifier,'y')
    feval('trainImageGoogleNetFun',path,'netCNN'); % trainImageGoogle net first and saves it as netCNN.mat in the LSTM dir
    % corresponding variable name is 'classifier'
end


fprintf('Loading Image classifier...\n');
fprintf('------\n');
load([ path '/netCNN.mat']); % load the image classifier
netCNN=classifier;

%%% Calculate activations from the image classifier network based on the training
%%% set

% load and format data as sequences of vectors using spepcific network
% layer

inputSize = netCNN.Layers(1).InputSize(1:2);

if strcmp(trainingParam.network,'googlenet')
layerName = "pool5-7x7_s1"; % layer id where the network will be connected 
end
if strcmp(trainingParam.network,'resnet50')
layerName = "avg_pool"; % layer id where the network will be connected 
end

tempFile = [path '/' name '_image_classifier_activations.mat']; 


if ~strcmp(trainingParam.cactivations,'y') && exist(tempFile)  % if acitvations already exist
    fprintf('Loading Image classifier activation data...\n');
    fprintf('------\n');

    load(tempFile,"sequences","labels"); % loads vid, lab, deep variables
% label in an array of categorical labels, vid is a video file of uint8
else % compute acitvations for input data
    fprintf('Computing Image classifier activation data...\n');
    fprintf('------\n');
    
    cc=1;
    
    % load all the files in the timeseries
    fol= [path '/trainingdataset/timeseries'];
    list=dir([fol '/*.mat']);
    numFiles = numel(list);
    sequences = cell(numFiles,1);
    labels = cell(numFiles,1);
    
    for i=1:numel(list)
        
        fprintf(['Processing movie ' num2str(i) '...']);
        
        load([list(i).folder '/' list(i).name]); % loads deep, vid, lab (categories of labels)
        
        video = centerCrop(vid,inputSize);
        
        sequences{cc,1} = activations(netCNN,video,layerName,'OutputAs','columns');
        labels{cc,1}= lab;
        cc=cc+1;
        fprintf('\n');
    end
    
    save(tempFile,"sequences","labels","-v7.3");
    fprintf('\n');
end

%return;

if strcmp(trainingParam.lstmtraining,'y') | ~exist([path '/netLSTM.mat']) % training of LSTM network, if file does not exist, then must train
    
    disp('Preparing LSTM network ...');
    fprintf('------\n');
    % prepare training data : 90% in training and 10% used for validation
    
    numObservations = numel(sequences);
    idx = randperm(numObservations);
    N = floor(trainingParam.lstmsplit* numObservations); % 0.9 replace
    
    idxTrain = idx(1:N);
    %idxTrain=1; % warning
    
    sequencesTrain = sequences(idxTrain);
    labelsTrain = labels(idxTrain);
    
    idxValidation = idx(N+1:end);
    %idxValidation = 1; %warning
    
    sequencesValidation = sequences(idxValidation);
    labelsValidation = labels(idxValidation);
    
    % create LSTM network
    
    numFeatures = size(sequencesTrain{1},1);
    numClasses = numel(categories(labelsTrain{1}));
    
    %ntot=countcats(labelsTrain{1});
    %weights = double(ntot)/double(sum(ntot));
    
    sucl=zeros(numObservations,numClasses);
    
    for i=1:numObservations
    sucl(i,:)=countcats(labels{i});
    end
    sucl=sum(sucl,1);
    
    tempsucl=sucl(sucl>0);
    sucl(sucl==0)=min(tempsucl(:));
    classWeights = 1./sucl;
    classWeights = classWeights'/mean(classWeights)
    %classWeights(isnan(classWeights))=0;
    classWeights
    return;
%     layers = [
%         sequenceInputLayer(numFeatures,'Name','sequence')
%         bilstmLayer(trainingParam.lstmlayers,'OutputMode','sequence','Name','bilstm')
%         % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
%         dropoutLayer(0.5,'Name','drop');
%         fullyConnectedLayer(numClasses,'Name','fc')
%         softmaxLayer('Name','softmax')
%         classificationLayer('Name','classification')];
    
    layers = [
        sequenceInputLayer(numFeatures,'Name','sequence')
        bilstmLayer(trainingParam.lstmlayers,'OutputMode','sequence','Name','bilstm')
        % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
        dropoutLayer(0.5,'Name','drop');
        fullyConnectedLayer(numClasses,'Name','fc')
        softmaxLayer('Name','softmax')
        weightedLSTMClassificationLayer(classWeights,'classification')];
    
    % specifiy training options
    
    miniBatchSize = trainingParam.lstmMiniBatchSize;
    numObservations = numel(sequencesTrain);
    numIterationsPerEpoch = max(1,floor(numObservations / miniBatchSize));
    
    options = trainingOptions('adam', ...
            'MiniBatchSize',miniBatchSize, ...
            'MaxEpochs',15,...
            'InitialLearnRate',trainingParam.lstmInitialLearnRate, ...
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
    
    [netLSTM,info] = trainNetwork(sequencesTrain,labelsTrain,layers,options);
    
    save([path '/netLSTM.mat'],'netLSTM','info');
    disp('Training LSTM network is done and saved ...');
    fprintf('------\n');
    
else
    load([path '/netLSTM.mat']);
    disp('Loading LSTM network ...');
    fprintf('------\n');
end


%%% assemble the full network
%%%

if strcmp(trainingParam.assemblenet,'y') | ~exist([path '/' name '.mat']) 
    disp('Assembling full network ...');
    fprintf('------\n');
    
   
    % remove non necessary layers
    fprintf(' remove output layers from CNN net\n');
    
    cnnLayers = layerGraph(netCNN);
    %layerNames = ["data" "pool5-drop_7x7_s1" "loss3-classifier" "prob" "output"];
    
    if strcmp(trainingParam.network,'googlenet')
    layerNames = ["data" "pool5-drop_7x7_s1" "new_fc" "prob" "new_classoutput"];
    end
    if strcmp(trainingParam.network,'resnet50')
    layerNames = ["data" "new_fc" "prob" "new_classoutput"];
    end
    
    cnnLayers = removeLayers(cnnLayers,layerNames);
    
    % create layers to adjust to CNN network layers
    fprintf(' create layers to adjust to CNN network layers\n');
    
    inputSize = netCNN.Layers(1).InputSize(1:2);
    averageImage = netCNN.Layers(1).AverageImage;
    
    inputLayer = sequenceInputLayer([inputSize 3], ...
        'Normalization','zerocenter', ...
        'Mean',averageImage, ...
        'Name','input');
    
    % add the sequence input layer to the layer graph
    layers = [
        inputLayer
        sequenceFoldingLayer('Name','fold')];
    
    lgraph = addLayers(cnnLayers,layers);
    
     if strcmp(trainingParam.network,'googlenet')
    lgraph = connectLayers(lgraph,"fold/out","conv1-7x7_s2");
     end
     if strcmp(trainingParam.network,'resnet50')
    lgraph = connectLayers(lgraph,"fold/out","conv1");    
      end
    
    % create lstm network and remove first layer (sequence)
    fprintf(' create LSTM network\n');
    
    lstmLayers = netLSTM.Layers;
    lstmLayers(1) = [];
    
    layers = [
        sequenceUnfoldingLayer('Name','unfold')
        flattenLayer('Name','flatten')
        lstmLayers];
    
    lgraph = addLayers(lgraph,layers);
   % lgraph = connectLayers(lgraph,"pool5-7x7_s1","unfold/in");
    lgraph = connectLayers(lgraph,layerName,"unfold/in");
    lgraph = connectLayers(lgraph,"fold/miniBatchSize","unfold/miniBatchSize");
    
    %analyzeNetwork(lgraph)
    
    fprintf('Assemble full network\n');
    
    classifier = assembleNetwork(lgraph);
    save([path '/' name '.mat'],'classifier');
    
    
    fprintf('Full network is assembled !\n');
    
else
    load( [path '/' name '.mat']); % loading the fully assembled network
end




%end




function videoResized = centerCrop(video,inputSize)

sz = size(video);

if sz(1) < sz(2)
    % Video is landscape
    idx = floor((sz(2) - sz(1))/2);
    video(:,1:(idx-1),:,:) = [];
    video(:,(sz(1)+1):end,:,:) = [];
    
elseif sz(2) < sz(1)
    % Video is portrait
    idx = floor((sz(1) - sz(2))/2);
    video(1:(idx-1),:,:,:) = [];
    video((sz(2)+1):end,:,:,:) = [];
end

videoResized = imresize(video,inputSize(1:2));
