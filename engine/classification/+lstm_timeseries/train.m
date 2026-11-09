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
    assert(strcmp(p.(sprintf('feature%d',k)),lstm_timeseries.featureSelector(d.features(k).selector))&&p.(sprintf('featureColumn%d',k))==d.features(k).column, ...
        'lstm_timeseries:StaleDataset','Input feature %d changed; format the dataset again.',k);
end
[classifier,model,info]=lstm_timeseries.fitSequences(d,p);

target=fullfile(classif.path,[classif.strid '.mat']);
save(target,'classifier','model','info','-v7.3');
out=lstm_timeseries.result('train');out.artifacts.model=target;
out.provides={'NumericSequenceClassifier'};out.refs.trainingScope=lstm_timeseries.trainingScopeSpec(classif);
end
