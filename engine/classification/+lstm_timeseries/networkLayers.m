function layers=networkLayers(p,classes,weights)
%NETWORKLAYERS Reuse the numeric training contract for LSTM or small TCN.
architecture='lstm';if isfield(p,'networkArchitecture'),architecture=p.networkArchitecture;end
output=classificationLayer('Name','classes','Classes',categorical(classes,classes,classes),'ClassWeights',weights);
if lstm_timeseries.isTrajectory(p),output=lstm_timeseries.WindowEndpointLoss(p.windowLength,classes,weights);end
if strcmp(architecture,'lstm')
    mode='sequence';if ~strcmp(p.outputMode,'frame')&&~lstm_timeseries.isTrajectory(p),mode='last';end
    layers=[sequenceInputLayer(p.featureCount,'Normalization','none','Name','features'); ...
        lstmLayer(p.hiddenUnits,'OutputMode',mode,'Name','lstm'); ...
        dropoutLayer(p.dropout,'Name','dropout');fullyConnectedLayer(numel(classes),'Name','state'); ...
        softmaxLayer('Name','probabilities');output];
    return;
end
assert(strcmp(architecture,'tcn')&&strcmp(p.outputMode,'window'),'lstm_timeseries:Architecture','TCN requires window mode.');
layers=layerGraph(sequenceInputLayer(p.featureCount,'Normalization','none','Name','features'));
previous='features';channels=p.featureCount;
for k=1:p.tcnBlocks
    prefix=sprintf('tcn%d_',k);dilation=2^(k-1);
    block=[convolution1dLayer(p.tcnKernelSize,p.tcnChannels,'Padding','causal','DilationFactor',dilation,'Name',[prefix 'conv1']); ...
        reluLayer('Name',[prefix 'relu1']);dropoutLayer(p.dropout,'Name',[prefix 'drop1']); ...
        convolution1dLayer(p.tcnKernelSize,p.tcnChannels,'Padding','causal','DilationFactor',dilation,'Name',[prefix 'conv2']); ...
        reluLayer('Name',[prefix 'relu2']);dropoutLayer(p.dropout,'Name',[prefix 'drop2']); ...
        additionLayer(2,'Name',[prefix 'add']);reluLayer('Name',[prefix 'out'])];
    layers=addLayers(layers,block);layers=connectLayers(layers,previous,[prefix 'conv1']);
    skip=previous;
    if channels~=p.tcnChannels
        skip=[prefix 'skip'];layers=addLayers(layers,convolution1dLayer(1,p.tcnChannels,'Name',skip));
        layers=connectLayers(layers,previous,skip);
    end
    layers=connectLayers(layers,skip,[prefix 'add/in2']);previous=[prefix 'out'];channels=p.tcnChannels;
end
tail=[globalAveragePooling1dLayer('Name','temporal_pool'); ...
    fullyConnectedLayer(numel(classes),'Name','state');softmaxLayer('Name','probabilities');output];
layers=addLayers(layers,tail);layers=connectLayers(layers,previous,'temporal_pool');
end
