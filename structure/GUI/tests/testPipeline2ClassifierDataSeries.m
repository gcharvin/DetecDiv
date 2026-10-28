function tests=testPipeline2ClassifierDataSeries
tests=functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.path=path;
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(root));
end

function teardownOnce(tc)
path(tc.TestData.path);
end

function testHubCheckFindsPersistedAttachedRoiSeries(tc)
[c,cleanup]=fixture(); %#ok<ASGLU>
app=classifierOpenValidationPipeline(c,'Intent','train','Rois',[1 3],'ExecutionTarget','hub');
finish=onCleanup(@()delete(app)); %#ok<NASGU>
app.UIFigure.Visible='off';
setHubRoot(app,'Local root',fileparts(c.path));
setHubRoot(app,'Remote root','/data/numeric-fixture');
app.CheckbuildButton.ButtonPushedFcn(app.CheckbuildButton,[]);
message=string(app.PipelineandRuncheckreportLabel.Text);
verifyFalse(tc,contains(message,'Missing inputs for node'),message);
verifyFalse(tc,contains(message,'no upstream dataSeries output'),message);
verifyFalse(tc,contains(message,'Errors:'),message);
verifyNotEmpty(tc,c.roi(1).data);
verifyEmpty(tc,c.roi(2).data,'Unselected test ROIs must not be loaded for the training inventory.');
end

function setHubRoot(app,label,value)
caption=findall(app.UIFigure,'Type','uilabel','Text',label);
controls=findall(caption.Parent,'Type','uieditfield');
control=controls(arrayfun(@(item)isequal(item.Layout.Row,caption.Layout.Row),controls));
assert(isscalar(control));control.Value=value;
end

function testBackendRecognizesLoadedRoiSeriesWithoutSeparateContextPort(tc)
[c,cleanup]=fixture(); %#ok<ASGLU>
for k=[1 3],c.roi(k).load('Data','Silent');end
[ok,report]=validatePipeline(numericPipeline(c),struct('roiList',c.roi([1 3])));
verifyTrue(tc,ok,strjoin(report.errors,newline));
end

function testMissingRoiSeriesStillBlockValidation(tc)
[c,cleanup]=fixture(); %#ok<ASGLU>
[ok,report]=validatePipeline(numericPipeline(c),struct('roiList',c.roi([1 3])));
verifyFalse(tc,ok);
verifyTrue(tc,any(contains(string(report.errors),'dataSeries')));
end

function pipe=numericPipeline(c)
p=lstm_timeseries.executionSpec(c).defaults;
p.pkg='lstm_timeseries';p.modulePath=c.path;p.moduleId=c.strid;
p.intent='train';p.operation='train';
node=struct('id',c.strid,'name',c.strid,'type','classifier','pkg','lstm_timeseries', ...
    'func','lstm_timeseries.classify','params',p,'enabled',true);
pipe=struct('nodes',node,'edges',struct('from',{},'to',{},'fromPort',{},'toPort',{}));
end

function [c,cleanup]=fixture()
root=tempname;mkdir(root);cleanup=onCleanup(@()rmdir(root,'s'));
c=classi(root,'numeric_attached_rois',1);
if ~isfolder(c.path),mkdir(c.path);end
lstm_timeseries.ensureClassMetadata(c);c.classes={'budding','dead'};
c.trainingParam=lstm_timeseries.setparam();c.trainingParam.featureCount=1;
c.trainingParam.feature1='input / signal';c.trainingParam.featureColumn1=1;
c.trainingParam.outputMode='window';c.trainingParam.windowLength=4;
c.trainingParam.validationFraction=0;c.trainingParam.executionEnvironment='cpu';
c.trainingset=[1 3];c.channelName={};
c.dataset=struct('classes',{c.classes},'channels',{{}}, ...
    'split',struct('train',[1 3],'val',[],'test',[2 4]));
for k=1:4
    r=roi(sprintf('series%d',k),[]);r.path=c.path;r.parent=c;
    input=dataseries(table((1:8)',(1:8)'+k,'VariableNames',{'frame','signal'}));input.groupid='input';
    ids=[ones(4,1);2*ones(4,1)];
    gt=dataseries(table(ids,categorical(ids,1:2,c.classes),'VariableNames',{'id_training','labels_training'}));
    gt.groupid=c.strid;gt.class='classification';r.data=[input gt];c.roi(k)=r;
    session=c.annotationSession(k);session.markReviewed('Frames',1:8,'Save',false);
    r.save('data',false);
end
classiObj=c;save(fullfile(c.path,[c.strid '_classification.mat']),'classiObj');
end
