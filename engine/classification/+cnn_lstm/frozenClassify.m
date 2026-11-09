function out = frozenClassify(r,c,ctx)
%FROZENCLASSIFY Return the normal classification patch from frozen CNN features.
s=load(fullfile(c.path,[c.strid '.mat']),'classifier','model');m=s.model;
assert(isequal(cellstr(string(c.classes(:))),cellstr(string(m.classes(:)))), ...
 'cnn_lstm:ClassSchema','Restore the trained class order or retrain.');
p=cnn_lstm.frozenParameters(c);assert(p.windowLength==m.windowLength,'cnn_lstm:StaleModel','Restore trained window length or retrain.');
if isfield(ctx,'params')&&isfield(ctx.params,'executionEnvironment')&&~strcmp(ctx.params.executionEnvironment,'module_default')
 p.executionEnvironment=ctx.params.executionEnvironment;
end
r.load('Data','Silent');n=annotationManager.frameCount(r);requested=[];
if isfield(ctx,'sel')&&isfield(ctx.sel,'frames'),requested=ctx.sel.frames;end
selected=trainingBounds.frames(c,r,n,requested);windows=lstm_timeseries.sequences(c,r,n,selected,p);
assert(~isempty(windows),'cnn_lstm:IncompleteWindow','Select at least one complete trained output window.');
frames=unique([windows{:}],'stable');r.load('Channel',c.channelName,'Silent');
[X,encoder]=cnn_lstm.frozenFeatures(c,r,p,frames);
assert(strcmp(encoder.sha256,m.encoder.sha256)&&strcmp(encoder.layer,m.encoder.layer)&& ...
 isequal(encoder.channels,m.encoder.channels),'cnn_lstm:StaleEncoder','CNN artifact/layer/channel bindings differ from training.');
C=numel(m.classes);prob=nan(n,C);ids=zeros(n,1);
for w=1:numel(windows)
 f=windows{w};[~,idx]=ismember(f,frames);
 input=lstm_timeseries.transform(X(:,idx),m.normalization,m.missingPolicy);
 [~,score]=classify(s.classifier,{input},'ExecutionEnvironment',p.executionEnvironment);
 learned=cellstr(string(s.classifier.Layers(end).Classes));[ok,order]=ismember(m.classes,learned);assert(all(ok));
 score=score(:,order);prob(f,:)=repmat(score,numel(f),1);[~,id]=max(score);ids(f)=id;
end
name=c.strid;if isfield(ctx,'names')&&isfield(ctx.names,'outputName'),name=ctx.names.outputName;end
assert(~endsWith(name,'_training'),'cnn_lstm:OutputName','Prediction cannot target a training field.');
t=table((1:n)',ids,categorical(ids,1:C,m.classes),'VariableNames',{'frame','id','labels'});
for j=1:C,t.(['prob_' m.classes{j}])=prob(:,j);end
old=find(strcmp({r.data.groupid},name),1);
if ~isempty(old)
 for key={'labels_training','id_training'}
  if ismember(key{1},r.data(old).data.Properties.VariableNames),t.(key{1})=r.data(old).data.(key{1});end
 end
end
ds=dataseries(t);ds.groupid=name;ds.parentid=r.id;ds.class='classification';ds.type='temporal';
ds.userData=struct('quality','pred','producer','cnn_lstm','frozenEncoder',true,'encoder',encoder, ...
 'classes',{m.classes},'outputMode','window','windowLength',m.windowLength);
if ~isempty(old)&&isstruct(r.data(old).userData)
 previous=r.data(old).userData;
 for key=fieldnames(previous)'
  if ~isfield(ds.userData,key{1}),ds.userData.(key{1})=previous.(key{1});end
 end
end
out=cnn_lstm.utils.outInitSafe('cnn_lstm.frozenClassify');
out.patch.roi.dataseries.upsert={struct('groupid',name,'dataseries',ds,'mode','replace')};
out.metrics=struct('classifiedFrames',nnz(ids),'sequences',numel(windows));
end
