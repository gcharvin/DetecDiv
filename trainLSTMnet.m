function trainLSTMnet(mov,trapid,activate,netCNN)

if nargin<4
load([mov.path '/netCNN.mat']); % loads pretrained googlenet, that has been retrained on
%specific images (transfer earning)
end

if nargin==2
activate=1;   
end

% load and format data as sequences of vectors using spepcific network
% layer

inputSize = netCNN.Layers(1).InputSize(1:2);
layerName = "pool5-7x7_s1";

numFiles = numel(trapid);

sequences = cell(numFiles,1);
labels = cell(numFiles,1);

tempFile = [mov.path '/lstm_training_',mov.id,'.mat']; % loads vid, lab, deep variables
% label in an array of categorical labels, vid is a video file of uint8 

%cc=1;

 if activate==0 %exist(tempFile,'file')
     load(tempFile,"sequences","labels")
 else
    cc=1;
for i=trapid
    
fprintf(['Processing movie ' num2str(i) '...']);

load([mov.path '/labeled_video_' mov.trap(i).id '.mat']); % loads deep, vid, lab (categories of labels)
 
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

save([mov.path '/netLSTM.mat'],'netLSTM','info');




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






