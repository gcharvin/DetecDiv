function tests=testFrozenEncoder
tests=functiontests(localfunctions);
end
function testOptInParametersAndStageGuard(testCase)
c=struct('trainingParam',cnn_lstm.setparam());
verifyFalse(testCase,cnn_lstm.isFrozenEncoder(c));
c.trainingParam.frozen_encoder_head=true;c.trainingParam.train_CNN_classifier=false;
c.trainingParam.classifier_output='sequence-to-one';c.trainingParam.execution_environment='cpu';
p=cnn_lstm.frozenParameters(c);verifyEqual(testCase,p.outputMode,'window');
c.trainingParam.train_CNN_classifier=true;
verifyError(testCase,@()cnn_lstm.frozenParameters(c),'cnn_lstm:FrozenBackbone');
end
function testFrozenImageRoundTripKeepsRoiSplitsAndCountsWindows(testCase)
root=tempname;mkdir(root);cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
c=classi(root,'frozen_fixture',1);c.classifierPkg='cnn_lstm';c.category={'LSTM'};
c.classes={'budding','dead'};c.channelName={'RGB'};c.channel=1;c.output=1;
c.trainingParam=cnn_lstm.setparam();c.trainingParam.frozen_encoder_head=true;
c.trainingParam.train_CNN_classifier=false;c.trainingParam.classifier_output{end}='sequence-to-one';
c.trainingParam.LSTM_sequence_length=3;c.trainingParam.LSTM_hidden_size=2;c.trainingParam.LSTM_max_epochs=2;
c.trainingParam.execution_environment{end}='cpu';c.trainingParam.frozen_encoder_layer='pool';
c.bounds.Values=[1 6];c.dataset.split=struct('train',[1 2],'val',3,'test',4);
classifier=dlnetwork([imageInputLayer([16 16 3],'Normalization','none','Name','image'); ...
 globalAveragePooling2dLayer('Name','pool')]);
encoderFile=fullfile(c.path,['netCNN_' c.strid '.mat']);save(encoderFile,'classifier');
for k=1:4
 r=roi(['fixture' num2str(k)],[1 1 16 16]);r.parent=c;r.path=c.path;r.channelid=[1 1 1];
 r.display.channel={'RGB'};r.display.stretchlim=repmat([0;1],1,3);r.display.indexed=0;
 r.image=repmat(reshape(uint16(0:255)*200,16,16),1,1,3,6);
 ids=[1;1;1;2;2;2];ds=dataseries(table((1:6)',ids,categorical(ids,1:2,c.classes), ...
 'VariableNames',{'frame','id_training','labels_training'}));
 ds.groupid=c.strid;ds.type='temporal';ds.class='classification';r.data=ds;c.roi(k)=r;
 spec=cnn_lstm.annotationSpec(c);annotationManager.markReviewed(r,spec,'Frames',1:6,'Save',false);
 annotationManager.approve(r,spec,'Save',false);r.save([],false);r.clear;
end
cnn_lstm.format(c,[1 2],struct());
s=load(fullfile(c.path,'trainingdataset','frozen_encoder_dataset.mat'));
verifyEqual(testCase,s.dataset.trainRoiIndices,[1 2]);verifyEqual(testCase,s.dataset.validationRoiIndices,3);
verifyEqual(testCase,numel(s.dataset.samples),6);verifyFalse(testCase,any([s.dataset.samples.roiIndex]==4));
verifyEqual(testCase,s.dataset.parameters.featureCount,3);
cnn_lstm.train(c,struct());m=load(fullfile(c.path,[c.strid '.mat']),'model');
verifyTrue(testCase,m.model.frozenEncoder);verifyEqual(testCase,m.model.trainingClassCounts,[2 2]);
c.roi(4).load('Data','Silent');truth=c.roi(4).data(1).data.labels_training;
out=cnn_lstm.classify(c.roi(4),c,struct());ds=out.patch.roi.dataseries.upsert{1}.dataseries;
verifyEqual(testCase,ds.data.labels_training,truth);
verifyEqual(testCase,numel(unique(ds.data.labels(1:3))),1);
c.roi(4).data(1)=ds;
[score,fig]=lstm_timeseries.statistics(c,'Rois',4,'Confusion','Classes','Silent');
verifyEqual(testCase,score.N,2);verifyEqual(testCase,sum(score.confusion,'all'),2);close(fig);
end
