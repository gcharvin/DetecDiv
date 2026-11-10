function [classifier,model,info] = fitSequences(d,p)
%FITSEQUENCES Shared ROI-disjoint training for numeric and frozen image features.
assert(isempty(intersect(d.trainRoiIndices,d.validationRoiIndices)) && isempty(intersect([d.trainRoiIndices d.validationRoiIndices],d.testRoiIndices)),'lstm_timeseries:SplitOverlap','Training, validation and test ROI must be disjoint.');
trainIdx=find(strcmp({d.samples.split},'train'));valIdx=find(strcmp({d.samples.split},'val'));
assert(~isempty(trainIdx)&&all(ismember([d.samples(trainIdx).roiIndex],d.trainRoiIndices))&& ...
 all(ismember([d.samples(valIdx).roiIndex],d.validationRoiIndices))&& ...
 ~any(ismember([d.samples.roiIndex],d.testRoiIndices)), ...
 'lstm_timeseries:SplitOverlap','Formatted samples must retain their ROI partition and exclude test ROI.');
stats=lstm_timeseries.trainingNormalizer(d.samples(trainIdx));
X=cellfun(@(x)lstm_timeseries.transform(x,stats,p.missingPolicy),{d.samples(trainIdx).X}','UniformOutput',false);
Y={d.samples(trainIdx).Y}';
trajectory=lstm_timeseries.isTrajectory(p);
if ~strcmp(p.outputMode,'frame')&&~trajectory,Y=vertcat(Y{:});end
labels=[d.samples(trainIdx).Y];
if trajectory
    endpointLabels=cellfun(@(y)y(p.windowLength:p.windowLength:end),Y,'UniformOutput',false);labels=[endpointLabels{:}];
end
[weights,classCounts]=lstm_timeseries.classWeights(labels,d.classes,p.classWeighting);
% Set the seed before any layer initialization as well as trainNetwork.
rng(p.seed,'twister');
layers=lstm_timeseries.networkLayers(p,d.classes,weights);
extra={};
if trajectory,extra={'SequenceLength','longest'};end
checkpoint='last-iteration';patience=Inf;
if ~isempty(valIdx)
    XV=cellfun(@(x)lstm_timeseries.transform(x,stats,p.missingPolicy),{d.samples(valIdx).X}','UniformOutput',false);
    YV={d.samples(valIdx).Y}';if ~strcmp(p.outputMode,'frame')&&~trajectory,YV=vertcat(YV{:});end
    extra=[extra {'ValidationData',{XV,YV},'ValidationFrequency',max(1,floor(numel(X)/p.miniBatchSize))}];
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
if isfield(p,'contextWindowLength'),model.contextWindowLength=p.contextWindowLength;else,model.contextWindowLength=0;end
model.contextBoundaryPolicy='repeat-edge';
model.networkArchitecture='lstm';if isfield(p,'networkArchitecture'),model.networkArchitecture=p.networkArchitecture;end
model.sequenceScope='window';if trajectory,model.sequenceScope='trajectory';end
model.lossUnit='native';if trajectory,model.lossUnit='window-endpoint';end
end
