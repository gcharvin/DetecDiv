function out = frozenTrain(c,ctx)
%FROZENTRAIN Fit the same temporal head as numeric LSTM; never update the CNN.
p=cnn_lstm.frozenParameters(c,ctx);
file=fullfile(c.path,'trainingdataset','frozen_encoder_dataset.mat');
assert(isfile(file),'cnn_lstm:Dataset','Format reviewed frozen encoder windows first.');
s=load(file,'dataset');d=s.dataset;p.featureCount=d.parameters.featureCount;
identity=cnn_lstm.encoderIdentity(c,p);
assert(isequal(identity,d.encoder),'cnn_lstm:StaleEncoder','Frozen CNN artifact or image bindings changed; restore them or format again.');
assert(p.windowLength==d.parameters.windowLength&&strcmp(p.encoderLayer,d.encoder.layer), ...
 'cnn_lstm:StaleDataset','Encoder layer/window length changed; format again.');
assert(isequal(c.classes,d.classes)&&isequal(c.dataset.split.test,d.testRoiIndices)&& ...
 isequal(c.dataset.split.train,d.trainRoiIndices)&&isequal(c.dataset.split.val,d.validationRoiIndices), ...
 'cnn_lstm:StaleDataset','Classes or ROI split changed; format again.');
[classifier,model,info]=lstm_timeseries.fitSequences(d,p);
model.module='cnn_lstm';model.frozenEncoder=true;model.encoder=d.encoder;
target=fullfile(c.path,[c.strid '.mat']);save(target,'classifier','model','info','-v7.3');
out=cnn_lstm.utils.outInitSafe('cnn_lstm.frozenTrain');out.artifacts.model=target;
out.refs.trainingScope=cnn_lstm.trainingScopeSpec(c);out.provides={'FrozenCNNSequenceClassifier'};
end
