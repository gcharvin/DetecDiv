function out = classify(roiObj, classif, ctx)
%CLASSIFY Return a prediction patch; never alter ROI GT or save source data.
if nargin<3,ctx=struct();end
overrides=struct();if isfield(ctx,'params'),overrides=ctx.params;end
p=lstm_timeseries.parameters(classif,overrides);
[classifier,model]=lstm_timeseries.loadModel(classif);
assert(isequal(cellstr(string(classif.classes(:).')),model.classes), ...
    'lstm_timeseries:ClassSchema','Class names/order changed; restore them or retrain the model.');
[X,schema]=lstm_timeseries.features(classif,roiObj,p);
assert(numel(schema)==numel(model.features),'lstm_timeseries:FeatureSchema','Input count differs from the trained model.');
for k=1:numel(schema)
    assert(strcmp(schema(k).variable,model.features(k).variable)&&schema(k).column==model.features(k).column, ...
        'lstm_timeseries:FeatureSchema','Input %d must retain the trained variable/component; group names may be rebound.',k);
end
assert(strcmp(p.outputMode,model.outputMode)&&p.windowLength==model.windowLength, ...
    'lstm_timeseries:ModelMode','Output mode/window length are frozen in the trained model. Restore them or retrain.');
requested=[];if isfield(ctx,'sel')&&isfield(ctx.sel,'frames'),requested=ctx.sel.frames;end
n=size(X,2);selected=trainingBounds.frames(classif,roiObj,n,requested);
windows=lstm_timeseries.sequences(classif,roiObj,n,selected,p);
assert(~isempty(windows)||isempty(selected),'lstm_timeseries:IncompleteSequence', ...
    'The frame selection contains no complete annotation unit. Select a complete window/video or change the ROI bounds.');
classes=model.classes;C=numel(classes);prob=nan(n,C);ids=zeros(n,1);
env=p.executionEnvironment;
if isfield(ctx,'exec')&&isfield(ctx.exec,'gpu')&&~isfield(overrides,'executionEnvironment')
    if ctx.exec.gpu,env='gpu';else,env='cpu';end
end
if strcmp(env,'module_default'),env='auto';end
for w=1:numel(windows)
    f=windows{w};input=lstm_timeseries.transform(X(:,f),model.normalization,model.missingPolicy);
    [~,scores]=classify(classifier,{input},'ExecutionEnvironment',env);
    if iscell(scores),scores=scores{1};end
    if strcmp(model.outputMode,'frame')
        % Legacy sequence-to-sequence classify returns C-by-T scores.
        if size(scores,1)==C,scores=scores';end
        assert(isequal(size(scores),[numel(f) C]),'lstm_timeseries:PredictionShape','Unexpected frame-score shape.');
    else
        scores=reshape(scores,1,C);scores=repmat(scores,numel(f),1);
    end
    learned=cellstr(string(classifier.Layers(end).Classes));[ok,order]=ismember(classes,learned);
    assert(all(ok),'lstm_timeseries:Classes','Trained model class metadata do not match.');
    scores=scores(:,order);prob(f,:)=scores;[~,ids(f)]=max(scores,[],2);
end
name=classif.strid;
if isfield(ctx,'names')&&isfield(ctx.names,'outputName')&&~isempty(ctx.names.outputName),name=char(string(ctx.names.outputName));
elseif isfield(overrides,'outputName')&&~isempty(overrides.outputName),name=char(string(overrides.outputName));end
assert(~endsWith(name,'_training'),'lstm_timeseries:OutputName','Prediction output cannot target a training field.');
t=table((1:n)',ids,categorical(ids,1:C,classes),'VariableNames',{'frame','id','labels'});
columns=cell(1,C);
for k=1:C,columns{k}=matlab.lang.makeValidName(['prob_' classes{k}]);end
assert(numel(unique(columns))==C,'lstm_timeseries:ClassNames','Class names produce duplicate probability column names.');
for k=1:C,t.(columns{k})=prob(:,k);end
old=find(strcmp({roiObj.data.groupid},name),1);oldUserData=struct();
if ~isempty(old)
    previous=roiObj.data(old).data;oldUserData=roiObj.data(old).userData;
    if ~isstruct(oldUserData),oldUserData=struct();end
    for key={'labels_training','id_training'}
        if ismember(key{1},previous.Properties.VariableNames)
            assert(height(previous)==n,'lstm_timeseries:GTLength','Existing GT frame count differs from feature rows.');
            t.(key{1})=previous.(key{1});
        end
    end
end
ds=dataseries(t);ds.groupid=name;ds.parentid=roiObj.id;ds.class='classification';ds.type='temporal';
ds.userData=struct('classes',{classes},'quality','pred','producer','lstm_timeseries', ...
    'outputMode',model.outputMode,'windowLength',model.windowLength,'features',schema);
for key=fieldnames(oldUserData)'
    if ~isfield(ds.userData,key{1}),ds.userData.(key{1})=oldUserData.(key{1});end
end
ds.plotProperties(:,1)={true};
out=lstm_timeseries.result('classify');out.requires={'ROIDataSeries'};out.provides={'ClassificationScores'};
out.patch.roi.dataseries.upsert={struct('groupid',name,'dataseries',ds,'mode','replace')};
out.metrics=struct('nFrames',n,'classifiedFrames',nnz(ids),'sequences',numel(windows));
end
