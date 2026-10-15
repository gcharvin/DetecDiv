function out = train(classif, ctx)
%TRAIN Fit a pure LSTM and frozen training-only feature normalization.
if nargin<2,ctx=struct();end
if ischar(ctx)||(isstring(ctx)&&isscalar(ctx)),ctx=struct('mode',char(ctx));end
if isfield(ctx,'mode')&&any(strcmpi(ctx.mode,{'init','param','params'}))
    classif.trainingParam=lstm_timeseries.setparam();lstm_timeseries.ensureClassMetadata(classif);
    out=lstm_timeseries.result('train');return;
end
overrides=struct();if isfield(ctx,'params'),overrides=ctx.params;end
p=lstm_timeseries.parameters(classif,overrides);
filename=fullfile(classif.path,'trainingdataset','lstm_timeseries_dataset.mat');
assert(isfile(filename),'lstm_timeseries:Dataset','Format reviewed numeric sequences before training.');
s=load(filename,'dataset');d=s.dataset;
assert(isequal(cellstr(string(classif.classes(:).')),d.classes), ...
    'lstm_timeseries:StaleDataset','Classes changed; format the dataset again.');
for key={'featureCount','outputMode','windowLength','missingPolicy'}
    assert(isequal(p.(key{1}),d.parameters.(key{1})),'lstm_timeseries:StaleDataset','%s changed; format the dataset again.',key{1});
end
for k=1:p.featureCount
    assert(strcmp(p.(sprintf('feature%d',k)),d.features(k).selector)&&p.(sprintf('featureColumn%d',k))==d.features(k).column, ...
        'lstm_timeseries:StaleDataset','Input feature %d changed; format the dataset again.',k);
end
trainIdx=find(strcmp({d.samples.split},'train'));valIdx=find(strcmp({d.samples.split},'val'));
stats=lstm_timeseries.normalizer([d.samples(trainIdx).X]);
X=cellfun(@(x)lstm_timeseries.transform(x,stats,p.missingPolicy),{d.samples(trainIdx).X}','UniformOutput',false);
Y={d.samples(trainIdx).Y}';mode='sequence';
if ~strcmp(p.outputMode,'frame'),mode='last';Y=vertcat(Y{:});end
[weights,classCounts]=lstm_timeseries.classWeights([d.samples(trainIdx).Y],d.classes,p.classWeighting);
% Set the seed before any layer initialization as well as trainNetwork.
rng(p.seed,'twister');
layers=[sequenceInputLayer(p.featureCount,'Normalization','none','Name','features'); ...
    lstmLayer(p.hiddenUnits,'OutputMode',mode,'Name','lstm'); ...
    dropoutLayer(p.dropout,'Name','dropout');fullyConnectedLayer(numel(d.classes),'Name','state'); ...
    softmaxLayer('Name','probabilities');classificationLayer('Name','classes', ...
    'Classes',categorical(d.classes,d.classes,d.classes),'ClassWeights',weights)];
extra={};
checkpoint='last-iteration';patience=Inf;
if ~isempty(valIdx)
    XV=cellfun(@(x)lstm_timeseries.transform(x,stats,p.missingPolicy),{d.samples(valIdx).X}','UniformOutput',false);
    YV={d.samples(valIdx).Y}';if ~strcmp(p.outputMode,'frame'),YV=vertcat(YV{:});end
    extra={'ValidationData',{XV,YV},'ValidationFrequency',max(1,floor(numel(X)/p.miniBatchSize))};
    if p.returnBestValidation,checkpoint='best-validation-loss';end
    if p.validationPatience>0,patience=p.validationPatience;end
end
rng(p.seed,'twister');env=p.executionEnvironment;if strcmp(env,'module_default'),env='auto';end
options=trainingOptions('adam','MaxEpochs',p.maxEpochs,'MiniBatchSize',p.miniBatchSize, ...
    'InitialLearnRate',p.initialLearnRate,'Shuffle','every-epoch','ExecutionEnvironment',env, ...
    'GradientThreshold',1,'L2Regularization',p.l2Regularization, ...
    'ValidationPatience',patience,'OutputNetwork',checkpoint,'Verbose',true,'Plots','none',extra{:});
[classifier,info]=trainNetwork(X,Y,layers,options); %#ok<ASGLU>
model=struct('schemaVersion',1,'module','lstm_timeseries','normalization',stats, ...
    'features',d.features,'classes',{d.classes},'outputMode',p.outputMode, ...
    'windowLength',p.windowLength,'missingPolicy',p.missingPolicy, ...
    'trainRoiIndices',d.trainRoiIndices,'validationRoiIndices',d.validationRoiIndices, ...
    'testRoiIndices',d.testRoiIndices,'trainingParameters',p, ...
    'trainingClassCounts',classCounts,'classWeights',weights,'checkpointPolicy',checkpoint);
target=fullfile(classif.path,[classif.strid '.mat']);
save(target,'classifier','model','info','-v7.3');
out=lstm_timeseries.result('train');out.artifacts.model=target;
out.provides={'NumericSequenceClassifier'};out.refs.trainingScope=lstm_timeseries.trainingScopeSpec(classif);
end
