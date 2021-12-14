function classifyLSTMnet(mov,id,netFull)


load([mov.path '/netCNN.mat']);

if numel(netFull)==0
load([mov.path '/netLSTM.mat']);


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

netFull = assembleNetwork(lgraph);
save([mov.path '/netFull.mat'],'netFull');
end

%return;

% now load and read video 
fprintf('Load videos...\n');

inputSize = netCNN.Layers(1).InputSize(1:2);

%inputSize = netFull.Layers(1).InputSize(1:2); 


for i=id
 fprintf(['Processing video:' num2str(i) '...\n']);   
load([mov.path '/labeled_video_' mov.trap(i).id '.mat']); % loads deep, vid, lab (categories of labels)
 
video = centerCrop(vid,inputSize);

label = classify(netFull,{video});
label=label{1};

pix=label=='largebudded';
    mov.trap(i).div.deepLSTM(pix)=2;

    pix=label=='smallbudded';
    mov.trap(i).div.deepLSTM(pix)=1;
    
    pix=label=='unbudded';
    mov.trap(i).div.deepLSTM(pix)=0;
    
    
%mov.trap(i).div.deepLSTM=YPred;
end


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


%analyzeNetwork(lgraph)




%etc ... 