function trainImageLSTMNetFun(path,name)

% first train googlenet network based on specific images

% if nargin<4
% load([mov.path '/netCNN.mat']); % loads pretrained googlenet, that has been retrained on
% %specific images (transfer earning)
% end


load([ path '/options.mat']); % loading options for training --> imageclassifier, cactivations,assemblenet

%%% training google net classifier independtly

if strcmp(imageclassifier,'y')
    feval('trainImageGoogleNetFun',path,'netCNN'); % trainImageGoogle net first and saves it as netCNN.mat in the LSTM dir
    % corresponding variable is 'classifier'
    netCNN=classifier;
end

%%%

%%% Computer activations from the google net network based on the training
%%% set 

% load and format data as sequences of vectors using spepcific network
% layer

inputSize = netCNN.Layers(1).InputSize(1:2);
layerName = "pool5-7x7_s1";

% load all the files in the timeseries
fol= [path '/trainingset/timeseries'];
list=dir([fol '/*.mat']);

for i=1:numel(list)
    
end

%%%% HERE need to gather files in correct folders
numFiles = numel(list);

sequences = cell(numFiles,1);
labels = cell(numFiles,1);

tempFile = [path '/' name '_googlenet_activations.mat']; % loads vid, lab, deep variables
% label in an array of categorical labels, vid is a video file of uint8

%cc=1;

if ~strcmp(cactivations,'y') %exist(tempFile,'file')
    load(tempFile,"sequences","labels")
else
    cc=1;
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

if strcmp(assemblenet,'y') % training of LSTM network
    
% prepare training data : 90% in training and 10% used for validation

numObservations = numel(sequences);
idx = randperm(numObservations);
N = floor(0.9 * numObservations);

idxTrain = idx(1:N);
sequencesTrain = sequences(idxTrain);
labelsTrain = labels(idxTrain);

idxValidation = idx(N+1:end);
sequencesValidation = sequences(idxValidation);
labelsValidation = labels(idxValidation);

% create LSTM network

numFeatures = size(sequencesTrain{1},1);
numClasses = numel(categories(labelsTrain{1}));

layers = [
    sequenceInputLayer(numFeatures,'Name','sequence')
    bilstmLayer(2000,'OutputMode','sequence','Name','bilstm')
    dropoutLayer(0.5,'Name','drop')
    fullyConnectedLayer(numClasses,'Name','fc')
    softmaxLayer('Name','softmax')
    classificationLayer('Name','classification')];

% specifiy training options

miniBatchSize = 16;
numObservations = numel(sequencesTrain);
numIterationsPerEpoch = max(1,floor(numObservations / miniBatchSize));

options = trainingOptions('adam', ...
    'MiniBatchSize',miniBatchSize, ...
    'InitialLearnRate',1e-4, ...
    'GradientThreshold',2, ...
    'Shuffle','every-epoch', ...
    'ValidationData',{sequencesValidation,labelsValidation}, ...
    'ValidationFrequency',numIterationsPerEpoch, ...
    'Plots','training-progress', ...
    'Verbose',false);

% train network

[netLSTM,info] = trainNetwork(sequencesTrain,labelsTrain,layers,options);

save([path '/netLSTM.mat'],'netLSTM','info');
else
 load([path '/netLSTM.mat']); 
end


%%% assemble the full network
%%%


%if numel(netFull)==0
%load([mov.path '/netLSTM.mat']);


% remove non necessary layers
fprintf(' remove output layers from CNN net\n');

cnnLayers = layerGraph(netCNN);
%layerNames = ["data" "pool5-drop_7x7_s1" "loss3-classifier" "prob" "output"];
layerNames = ["data" "pool5-drop_7x7_s1" "new_fc" "prob" "new_classoutput"];
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

fprintf('Assemble full network\n');

classifier = assembleNetwork(lgraph);
save([path '/' name '.mat'],'classifier');
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
