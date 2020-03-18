function netFULL=assembleNet(mov)

% assembles the CNN and LSTM

load([mov.path '/netLSTM.mat']);
load([mov.path '/netCNN.mat']);

cnnLayers = layerGraph(netCNN); % load a graph the google network that has been pretrained

 % removes the input layer data  after the pooling layer used for the
 % activation 
 
layerNames = ["data" "pool5-drop_7x7_s1" "loss3-classifier" "prob" "output"];
cnnLayers = removeLayers(cnnLayers,layerNames);

% add sequence input layer
inputSize = netCNN.Layers(1).InputSize(1:2);
averageImage = netCNN.Layers(1).Mean;

inputLayer = sequenceInputLayer([inputSize 3], ...
    'Normalization','zerocenter', ...
    'Mean',averageImage, ...
    'Name','input');

% add the seuqence input layer to the layer graph

layers = [
    inputLayer
    sequenceFoldingLayer('Name','fold')];

lgraph = addLayers(cnnLayers,layers);
lgraph = connectLayers(lgraph,"fold/out","conv1-7x7_s2");

%add lstm layers

lstmLayers = netLSTM.Layers;
lstmLayers(1) = [];

layers = [
    sequenceUnfoldingLayer('Name','unfold')
    flattenLayer('Name','flatten')
    lstmLayers];

lgraph = addLayers(lgraph,layers);
lgraph = connectLayers(lgraph,"pool5-7x7_s1","unfold/in");

lgraph = connectLayers(lgraph,"fold/miniBatchSize","unfold/miniBatchSize");

% check network 

netFULL = assembleNetwork(lgraph);

save([mov.path '/netFULL.mat'],'netFULL');





