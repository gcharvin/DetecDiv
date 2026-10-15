function tests=testFormatFixedWindows
tests=functiontests(localfunctions);
end
function testScalarChannelAndGlobalBoundsExportTwoWindows(testCase)
root=tempname;mkdir(root);cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
c=classi(root,'window_fixture',1,'ClassID',5,'InitTraining',false);
if ~isfolder(c.path),mkdir(c.path);end
c.category={'LSTM'};c.classifierPkg='cnn_lstm';
c.classes={'budding','arrested','dead'};c.channelName='BF';
c.dataset.channels='BF';c.trainingParam=cnn_lstm.setparam();
c.trainingParam.classifier_output{end}='sequence-to-one';
c.trainingParam.LSTM_sequence_length=3;c.trainingParam.Format_Crop=false;
c.bounds.Type='Auto';c.bounds.Values=[2 7];
r=roi('window_roi',[1 1 16 16]);r.path=c.path;r.parent=c;r.channelid=1;
r.display=struct('channel',{{'BF'}},'stretchlim',[0;1],'indexed',0);
r.image=zeros(16,16,1,8,'uint16');
for k=1:8,r.image(:,:,1,k)=uint16(k*1000+reshape(0:255,16,16));end
ds=dataseries;ds.groupid=c.strid;
ids=[0;1;1;1;2;2;2;0];
ds.data=table(categorical(ids,1:3,c.classes),ids,'VariableNames',{'labels_training','id_training'});
r.data=ds;c.roi=r;
out=cnn_lstm.format(c,1,struct());
verifyTrue(testCase,out.ok);
fb=out.artifacts.framebank;
verifyEqual(testCase,double(h5read(fb,'/series_len')),6);
verifyEqual(testCase,double(h5read(fb,'/labels')),[1 1 1 2 2 2]);
image=h5read(fb,'/frames',[1 1 1 1],[224 224 3 1]);
verifyEqual(testCase,image(:,:,1),image(:,:,2));
verifyEqual(testCase,image(:,:,1),image(:,:,3));
verifyEqual(testCase,double(h5read(fb,'/series_start')),1);
end
