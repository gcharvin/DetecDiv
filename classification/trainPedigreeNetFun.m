function trainPedigreeNetFun(path,name)

% first train googlenet network based on specific images



load([ path '/options.mat']); % loading options for training --> imageclassifier, cactivations, lstm_training, assemblenet, validation

%%% training google net classifier independtly

% if strcmp(imageclassifier,'y')
%     feval('trainImageGoogleNetFun',path,'netCNN'); % trainImageGoogle net first and saves it as netCNN.mat in the LSTM dir
%     % corresponding variable is 'classifier'
% end

  load([ path '/netCNN.mat']);
  netCNN=classifier;
 
 %netCNN=googlenet;
    
  
%%%

%%% Computer activations from the google net network based on the training
%%% set 

% load and format data as sequences of vectors using spepcific network
% layer

inputSize = netCNN.Layers(1).InputSize(1:2);
layerName = "pool5-7x7_s1";

% load all the files in the timeseries
fol= [path '/trainingdataset/timeseries'];
list=dir([fol '/*.mat']);

% for i=1:numel(list)
%     
% end

%%%% HERE need to gather files in correct folders
numFiles = numel(list);

sequences = cell(numFiles,1);
labels = [];%cell(numFiles,1);

tempFile = [path '/' name '_googlenet_activations.mat']; % loads vid, lab, deep variables
% label in an array of categorical labels, vid is a video file of uint8

%cc=1;
% cactivations='n'; %warning !
% list

if ~strcmp(cactivations,'y') %exist(tempFile,'file')
    load(tempFile,"sequences","labels")
else
    cc=1;
    for i=1:numel(list)
        
        fprintf(['Processing movie ' num2str(i) '...']);
        
        load([list(i).folder '/' list(i).name]); % loads deep, vid, lab ( lab are numeric values)
        
        video = centerCrop(vid,inputSize);
        
        sequences{cc,1} = activations(netCNN,video,layerName,'OutputAs','columns');
        labels(cc)=lab;
        %labels{cc,1}= lab;
        cc=cc+1;
        fprintf('\n');
    end
    
    save(tempFile,"sequences","labels","-v7.3");
    fprintf('\n');
end

labels=labels';
%return; 

if strcmp(lstmtraining,'y') % training of LSTM network
    
    disp('Preparing LSTM network ...');
% prepare training data : 90% in training and 10% used for validation

numObservations = numel(sequences);
idx = randperm(numObservations);
N = floor(0.9 * numObservations); % 0.9 replace

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
%numClasses = numel(categories(labelsTrain{1}));

%return;
layers = [
    sequenceInputLayer(numFeatures,'Name','sequence')
    bilstmLayer(200,'OutputMode','last','Name','bilstm')
   % lstmLayer(200,'OutputMode','sequence','Name','bilstm')
    dropoutLayer(0.5,'Name','drop')
   % fullyConnectedLayer(numClasses,'Name','fc')
    fullyConnectedLayer(1,'Name','fc')
  %  softmaxLayer('Name','softmax')
    regressionLayer('Name','regression')];
    %classificationLayer('Name','classification')];

% specifiy training options

miniBatchSize = 16;
numObservations = numel(sequencesTrain);
numIterationsPerEpoch = max(1,floor(numObservations / miniBatchSize));

% 'MaxEpochs',maxEpochs, ...
     
options = trainingOptions('adam', ...
    'MiniBatchSize',miniBatchSize, ...
    'InitialLearnRate',1e-2, ...
    'LearnRateSchedule','piecewise',...
     'LearnRateDropPeriod',30,...
    'LearnRateDropFactor',0.7,...
    'MaxEpochs',100, ...
    'GradientThreshold',2, ...
    'Shuffle','every-epoch', ...
    'ValidationData',{sequencesValidation,labelsValidation}, ...
    'ValidationFrequency',numIterationsPerEpoch, ....
     'VerboseFrequency',2,...
    'Plots','training-progress',...
    'ValidationFrequency', 10,...
    'ExecutionEnvironment','auto');

%options.SequenceLength
%options.SequencePaddingValue
%return;
% train network
 disp('Training LSTM network ...');
[netLSTM,info] = trainNetwork(sequencesTrain,labelsTrain,layers,options);

save([path '/netLSTM.mat'],'netLSTM','info');
 disp('Training LSTM network is done and saved ...');
 
else
 load([path '/netLSTM.mat']); 
  disp('Loading LSTM network ...');
end

%return;
%%% assemble the full network
%%%

if strcmp(assemblenet,'y')
%if numel(netFull)==0
%load([mov.path '/netLSTM.mat']);


% remove non necessary layers
fprintf(' remove output layers from CNN net\n');

cnnLayers = layerGraph(netCNN);
%layerNames = ["data" "pool5-drop_7x7_s1" "loss3-classifier" "prob" "output"]; % for default goglenet network
layerNames = ["data" "pool5-drop_7x7_s1" "new_fc" "prob" "new_classoutput"]; % for custom trainied googlenet
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
lgraph = connectLayers(lgraph,"fold/out","conv1-7x7_s2");

% create lstm network and remove first layer (sequence)
fprintf(' create LSTM network\n');

lstmLayers = netLSTM.Layers;
lstmLayers(1) = [];

layers = [
    sequenceUnfoldingLayer('Name','unfold')
    flattenLayer('Name','flatten')
    lstmLayers];

lgraph = addLayers(lgraph,layers);
lgraph = connectLayers(lgraph,"pool5-7x7_s1","unfold/in");
lgraph = connectLayers(lgraph,"fold/miniBatchSize","unfold/miniBatchSize");

%analyzeNetwork(lgraph) 

fprintf('Assembled full network; Now saving....\n');

classifier = assembleNetwork(lgraph);
save([path '/' name '.mat'],'classifier');


fprintf('Full network is assembled and saved !\n');

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
