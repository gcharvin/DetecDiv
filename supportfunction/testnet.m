function testnet

numClasses = 2;%numel(categories(imdsTrain.Labels));

fprintf('Loading googlenet...\n');

% load google net
%net = googlenet;
net=resnet50;

inputSize = net.Layers(1).InputSize;
numClasses=2;

layersTransfer = net.Layers(1:end-3);
layers = [
    layersTransfer
    fullyConnectedLayer(numClasses,'WeightLearnRateFactor',20,'BiasLearnRateFactor',20)
    softmaxLayer
    classificationLayer];

analyzeNetwork(layers)