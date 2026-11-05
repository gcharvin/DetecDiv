function tests = testValidateClassifier
tests = functiontests(localfunctions);
end

function setupOnce(~)
detecdiv_setup_path;
end

function testLegacyReviewRequiresAttestationAndValidLabels(testCase)
[c,cleanup] = fixture(); %#ok<ASGLU>
before = c.roi(1).data.data;
report = annotationManager.validateClassifier(c,1);
verifyEqual(testCase,report.invalid,1);
report = annotationManager.validateClassifier(c,1:3,'ConfirmReviewed',true);
verifyEqual(testCase,{report.items.status},{'ready','invalid','invalid'});
verifyTrue(testCase,contains(report.items(2).message,'frames: 2'));
c.roi(1).load('Data','Silent');
verifyEqual(testCase,c.roi(1).data(1).data,before);
session = annotationManager.createSession(c,1);
verifyEqual(testCase,session.summary('VerifyHash',true).status,'approved');
report = annotationManager.validateClassifier(c,1);
verifyEqual(testCase,report.ready,1);
end

function testBoundsAndShortSeries(testCase)
[c,cleanup] = fixture(); %#ok<ASGLU>
c.bounds.Values = [3 4];
report = annotationManager.validateClassifier(c,2,'ConfirmReviewed',true);
verifyEqual(testCase,report.ready,1);
c.bounds.Values = [];
% Real image length is four, but GT has only three labels.
c.roi(1).data.data(4,:) = [];
report = annotationManager.validateClassifier(c,1,'ConfirmReviewed',true);
verifyEqual(testCase,report.invalid,1);
verifyTrue(testCase,contains(report.items.message,'only 3 labels'));
end

function testRecoveryHonorsHistoryAndKeepsInternalHoles(testCase)
[c,cleanup] = fixture(); %#ok<ASGLU>
c.roi(1).data.userData=struct('bounds',[0 3]);
report=annotationManager.validateClassifier(c,1:2,'RecoverBounds',true);
verifyEqual(testCase,report.ready,1);
verifyEqual(testCase,report.invalid,1);
verifyEqual(testCase,trainingBounds.resolve(c,1),[1 3]);
verifyEqual(testCase,trainingBounds.resolve(c,2),[1 4]);
verifyTrue(testCase,contains(report.items(2).message,'frames: 2'));
verifyEqual(testCase,report.boundsRecovery(1).source,'historical');
end

function testRecoveryTrimsOnlyEndsAndPreservesUnselectedScopes(testCase)
[c,cleanup] = fixture(); %#ok<ASGLU>
c.roi(1).data.data.labels_training(1)=categorical({''},c.classes);
c.roi(1).data.data.labels_training(4)=categorical({''},c.classes);
c.roi(2).data.userData=struct('bounds',[2 3]);
report=annotationManager.validateClassifier(c,1,'RecoverBounds',true);
verifyEqual(testCase,report.ready,1);
verifyEqual(testCase,trainingBounds.resolve(c,1),[2 3]);
verifyEqual(testCase,trainingBounds.resolve(c,2),[1 4]);
verifyEqual(testCase,report.boundsRecovery.source,'annotated');
end

function testRecoveryRejectsEmptyLabelsAndCancelledRunIsUnchanged(testCase)
[c,cleanup] = fixture(); %#ok<ASGLU>
before=c.bounds;
annotationManager.validateClassifier(c,1,'RecoverBounds',true,'CancelFcn',@()true);
verifyEqual(testCase,c.bounds,before);
c.roi(1).data.data.labels_training(:)=categorical({''},c.classes);
report=annotationManager.validateClassifier(c,1,'RecoverBounds',true);
verifyEqual(testCase,report.invalid,1);
verifyTrue(testCase,contains(report.items.message,'No defined label'));
verifyEqual(testCase,c.bounds,before);
end

function testRecoveryTreatsNumericZeroAsUnlabelled(testCase)
[c,cleanup] = fixture(); %#ok<ASGLU>
c.roi(1).data.data.labels_training=[0;1;2;0];
c.roi(1).data.data.id_training=[0;1;2;0];
report=annotationManager.validateClassifier(c,1,'RecoverBounds',true);
verifyEqual(testCase,report.ready,1);
verifyEqual(testCase,trainingBounds.resolve(c,1),[2 3]);
end

function testCancellationAndPerRoiFailureIsolation(testCase)
[c,cleanup] = fixture(); %#ok<ASGLU>
report = annotationManager.validateClassifier(c,1:3, ...
    'ConfirmReviewed',true,'CancelFcn',@()true);
verifyTrue(testCase,report.cancelled);
verifyEqual(testCase,report.pending,3);
verifyEmpty(testCase,dir(fullfile(c.path,'data_*.mat')));
c.roi(2).path = fullfile(c.path,'nonexistent');
report = annotationManager.validateClassifier(c,[2 1],'ConfirmReviewed',true);
verifyEqual(testCase,{report.items.status},{'failed','ready'});
end

function [c,cleanup] = fixture()
folder=tempname; mkdir(folder);
cleanup=onCleanup(@()rmdir(folder,'s'));
c=classi(folder,'legacy_batch',1);
c.classifierPkg='cnn_lstm'; c.category={'LSTM'};
c.classes={'alpha','beta'};
for k=1:3
    r=roi(sprintf('R%d',k),[1 1 2 2]); r.path=c.path;
    r.image=ones(2,2,1,4,'uint16'); r.display.channel={'raw'};
    ds=dataseries; ds.groupid=c.strid;
    labels={'alpha';'beta';'alpha';'beta'};
    ids=[1;2;1;2];
    if k==2,labels{2}='';ids(2)=0;end
    ds.data=table(categorical(labels,c.classes),ids, ...
        'VariableNames',{'labels_training','id_training'});
    if k==3,ds.groupid='prediction_only';end
    r.data=ds; c.roi(k)=r;
end
end
