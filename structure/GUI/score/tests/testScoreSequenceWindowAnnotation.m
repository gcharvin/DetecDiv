function tests = testScoreSequenceWindowAnnotation
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(root); startup;
end

function testWindowEdgesAndPartialTail(testCase)
[c,r,cleanup] = fixture(); %#ok<ASGLU>
verifyEqual(testCase, cnn_lstm.annotationFrames(c,r,1,12), 1:4);
verifyEqual(testCase, cnn_lstm.annotationFrames(c,r,4,12), 1:4);
verifyEqual(testCase, cnn_lstm.annotationFrames(c,r,5,12), 5:8);
c.trainingParam.LSTM_sequence_length = 5;
verifyEqual(testCase, cnn_lstm.annotationFrames(c,r,12,12), 11:12);
c.trainingParam.LSTM_sequence_length = 0;
verifyEqual(testCase, cnn_lstm.annotationFrames(c,r,5,12), 1:12);
end

function testBoundsAnchorAndFrameMode(testCase)
[c,r,cleanup] = fixture(); %#ok<ASGLU>
c.bounds.Values = [3 10];
verifyEqual(testCase, cnn_lstm.annotationFrames(c,r,5,12), 3:6);
verifyEqual(testCase, cnn_lstm.annotationFrames(c,r,10,12), 7:10);
verifyEmpty(testCase, cnn_lstm.annotationFrames(c,r,11,12));
c.trainingParam.classifier_output{end} = 'sequence-to-sequence';
[frames,window] = cnn_lstm.annotationFrames(c,r,5,12);
verifyEqual(testCase,frames,5); verifyFalse(testCase,window);
end

function testAssignmentsKeepNamesAndIdsAndCanClear(testCase)
[c,r,cleanup] = fixture(); %#ok<ASGLU>
annotationManager.assignFrameLabel(r,c.strid,c.classes,'arrested',5:8);
verifyEqual(testCase,r.data.data.id_training,[zeros(4,1);2*ones(4,1);zeros(4,1)]);
verifyEqual(testCase,string(r.data.data.labels_training(5:8)),repmat("arrested",4,1));
annotationManager.assignFrameLabel(r,c.strid,c.classes,'unclassified',6);
verifyEqual(testCase,r.data.data.id_training(6),0);
verifyEqual(testCase,string(r.data.data.labels_training(6)),"undefined");
verifyError(testCase,@()annotationManager.assignFrameLabel(r,c.strid,c.classes,'bad',1), ...
    'annotationManager:UnknownClass');
end

function testSeq2OneImportCreatesFullLengthBlankLabels(testCase)
[source,r,cleanup] = fixture(); %#ok<ASGLU>
r.save([],false);
f = fov(); f.id = 'position'; f.roi = r;
target = classi(fileparts(source.path),'window_import',1);
target.category = {'LSTM'}; target.classifierPkg = 'cnn_lstm';
target.classes = {}; target.output = 1; target.channelName = 'raw';
target.trainingParam = source.trainingParam;
target.addROI(f,'rois',1,'adjustChannel',{'raw'});
verifyEqual(testCase,numel(target.roi),1);
target.roi(1).load('Data','Silent');
di = find(strcmp({target.roi(1).data.groupid},target.strid),1);
verifyEqual(testCase,height(target.roi(1).data(di).data),12);
verifyEqual(testCase,target.roi(1).data(di).data.id_training,zeros(12,1));
verifyEqual(testCase,target.roi(1).train.(target.strid).id,0);
end

function testScoreDropdownKeyboardAndWindowReview(testCase)
[c,r,cleanup] = fixture(); %#ok<ASGLU>
r.save([],false);
session = c.annotationSession(1);
session.startBlank('Save',false);
r.data(1).userData.classes = {'stale_class'};
r.save('data',false);
app = score(r,'dataAnnotation');
appCleanup = onCleanup(@()closeApp(app)); %#ok<NASGU>
app.setAnnotationSession(session);
app.UIDataTable.Selection = [1 1];
row = find(strcmp(app.UISubDataTable.Data(:,2),'labels_training'),1);
verifyNotEmpty(testCase,row);
app.UISubDataTable.Selection = [row 2];
r.display.frame = 6;
verifyTrue(testCase,all(ismember(c.classes,app.ClassDropDown.Items)), ...
    'The palette must follow the classifier when imported class metadata is stale.');
app.ClassDropDown.Value = 'arrested';
callback = app.ClassDropDown.ValueChangedFcn; callback(app.ClassDropDown,[]);
di = find(strcmp({r.data.groupid},c.strid),1);
verifyEqual(testCase,r.data(di).data.id_training(5:8),2*ones(4,1));
verifyEqual(testCase,r.data(di).data.id_training([1:4 9:12]),zeros(8,1));
r.display.frame = 2;
app.keys = {'a','z'};
callback = app.ScoreAppUIFigure.KeyPressFcn;
callback(app.ScoreAppUIFigure,struct('Key','a','Modifier',{{'shift'}}));
verifyEqual(testCase,r.data(di).data.id_training(1:4),ones(4,1));
verifyEqual(testCase,r.data(di).data.id_training(9:12),zeros(4,1));
session.markUnreviewed('Frames',1:12);
callback = app.MarkFrameReviewedButton.ButtonPushedFcn;
callback(app.MarkFrameReviewedButton,[]);
summary = session.summary();
verifyTrue(testCase,all(summary.entry.review(1).frames(1:4)));
verifyFalse(testCase,any(summary.entry.review(1).frames(5:12)));
verifyEqual(testCase,r.display.frame,5);
c.trainingParam.classifier_output{end} = 'sequence-to-sequence';
session.refresh();
r.display.frame = 10;
app.assignSelectedTrainingClass('budding');
verifyEqual(testCase,r.data(di).data.id_training(9:12),[0;1;0;0]);
app.assignSelectedTrainingClass('arrested',true);
verifyEqual(testCase,r.data(di).data.id_training(9:12),[0;2;2;2]);
end

function [c,r,cleanup] = fixture()
folder = tempname; mkdir(folder);
cleanup = onCleanup(@()removeFolder(folder));
c = classi(folder,'test_window',1);
c.classifierPkg = 'cnn_lstm'; c.category = {'LSTM'}; c.output = 1;
c.classes = {'budding','arrested'}; c.channelName = 'raw';
c.trainingParam = struct('classifier_output',{{'sequence-to-sequence','sequence-to-one'}}, ...
    'LSTM_sequence_length',4);
r = roi('R1',[1 1 8 8]); r.path = c.path; r.parent = c;
r.image = uint16(ones(8,8,1,12)); r.channelid = 1;
r.display.channel = {'raw'};
ds = dataseries; ds.groupid = c.strid; ds.class = 'classification';
ds.data = table(categorical(repmat({'undefined'},12,1), ...
    {'undefined','budding','arrested'}),zeros(12,1), ...
    'VariableNames',{'labels_training','id_training'});
ds.userData = struct('classes',{c.classes});
ds.plotProperties = {true,'labels_training','categorical','k',2,'label';false,'id_training','double','k',2,'id'};
ds.plotGroup = {[] [] [] [] [] {'label','id'}};
ds.groupProperties = {'label','Plot','auto','auto';'id','Plot','auto','auto'};
r.data = ds; c.roi = r;
end

function closeApp(app)
try app.ModifiedRoiIds = strings(0,1); catch, end
try if isgraphics(app.ImageFigure),delete(app.ImageFigure);end, catch,end
try if isgraphics(app.DataFigure),delete(app.DataFigure);end, catch,end
try delete(app); catch,end
end

function removeFolder(folder)
if isfolder(folder),rmdir(folder,'s');end
end
