function tests=testClassifierStatistics
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));addpath(genpath(root));
% genpath intentionally omits fixtures directories; add this test package explicitly.
addpath(fullfile(fileparts(mfilename('fullpath')),'fixtures'));
end

function testPerfectInstancesIgnoreNumericIds(t)
m=classifierStats.instanceMetrics([0 7 7 0 900],[0 42 42 0 3]);
verifyEqual(t,[m.truePositive m.falsePositive m.falseNegative],[2 0 0]);
verifyEqual(t,[m.precision m.recall m.f1 m.matchedIoU m.panopticQuality],ones(1,5));
end
function testSplitAndMergePenalized(t)
split=classifierStats.instanceMetrics([1 1 1 1],[8 8 9 9]);
merge=classifierStats.instanceMetrics([8 8 9 9],[1 1 1 1]);
verifyEqual(t,[split.truePositive split.falsePositive split.falseNegative],[1 1 0]);
verifyEqual(t,[merge.truePositive merge.falsePositive merge.falseNegative],[1 0 1]);
verifyEqual(t,split.f1,2/3,'AbsTol',1e-12);verifyEqual(t,split.panopticQuality,1/3,'AbsTol',1e-12);
end
function testMatchingMaximizesCardinalityBeforeIoU(t)
m=classifierStats.instanceMetrics([1 1 1 1 1 2 2],[1 1 1 2 2 1 1],0.35);
verifyEqual(t,m.truePositive,2);verifyEqual(t,m.sumMatchedIoU,0.8,'AbsTol',1e-12);
end
function testEmptyAndMissingObjects(t)
a=classifierStats.instanceMetrics([0 1],[0 0]);b=classifierStats.instanceMetrics([0 0],[0 8]);
z=classifierStats.instanceMetrics([0 0],[0 0]);
verifyEqual(t,[a.falseNegative b.falsePositive],[1 1]);verifyEqual(t,[a.f1 b.f1],[0 0]);
verifyTrue(t,isnan(z.f1));verifyTrue(t,isnan(z.panopticQuality));
end
function testInvalidMasksAndShapes(t)
verifyError(t,@()classifierStats.instanceMetrics([0 -1],[0 1]),'classifierStats:InvalidMask');
verifyError(t,@()classifierStats.instanceMetrics([0 NaN],[0 1]),'classifierStats:InvalidMask');
verifyError(t,@()classifierStats.instanceMetrics([0 1.5],[0 1]),'classifierStats:InvalidMask');
verifyError(t,@()classifierStats.instanceMetrics(zeros(2),zeros(3)),'classifierStats:Shape');
end
function testManagedGtAndExplicitOutputUseReviewedTestFramesOnly(t)
c=instanceFixture();report=classifierStats.statistics(c,'PredictionChannel','results_renamed','Silent');s=report.components;
verifyEqual(t,s.frameMetrics.roiIndex,[2;2]);verifyEqual(t,s.frameMetrics.frame,[1;3]);
verifyEqual(t,s.frameMetrics.prediction,repmat({'results_renamed'},2,1));
verifyEqual(t,s.instances.truePositive,2);verifyEqual(t,s.instances.f1,1);
end
function testMissingConfiguredPredictionNeverChoosesOtherClassifier(t)
c=instanceFixture();verifyError(t,@()classifierStats.statistics(c,'Silent'),'classifierStats:MissingPrediction');
verifyError(t,@()classifierStats.statistics(c,'PredictionChannel','missing','Silent'),'classifierStats:MissingPrediction');
end
function testGroundTruthCannotBeSelectedAsPrediction(t)
c=instanceFixture();verifyError(t,@()classifierStats.statistics(c,'PredictionChannel','gt_custom','Silent'), ...
    'classifierStats:GroundTruthAsPrediction');
end
function testMissingGtCannotFallBackToOldMasks(t)
c=instanceFixture();c.trainingParam.groundTruthChannelName='missing_gt';
verifyError(t,@()classifierStats.statistics(c,'PredictionChannel','results_renamed','Silent'), ...
    'classifierStats:MissingGroundTruth');
end
function testEmptyManagedGtAndPredictionsCountAsFalsePositiveAndNegative(t)
c=instanceFixture();r=c.roi(2);g=r.findChannelID('gt_custom');p=r.findChannelID('results_renamed');
r.image(:,:,g,1)=0;r.image(:,:,p,3)=0;
report=classifierStats.statistics(c,'PredictionChannel','results_renamed','Silent');s=report.components.instances;
verifyEqual(t,[s.truePositive s.falsePositive s.falseNegative],[0 1 1]);verifyEqual(t,s.f1,0);
end
function testRequestedFramesIntersectReviewAndBounds(t)
c=instanceFixture();report=classifierStats.statistics(c,'PredictionChannel','results_renamed','Frames',[2 3],'Silent');
verifyEqual(t,report.components.frameMetrics.frame,3);
end
function testNoReviewedFramesDoesNotOpenWindowOrReplaceScore(t)
c=instanceFixture();c.score=struct('old',true);before=numel(findall(groot,'Type','figure'));
verifyError(t,@()classifierStats.statistics(c,'PredictionChannel','results_renamed','Frames',2,'Confusion'), ...
    'classifierStats:NoEvaluationSamples');
verifyEqual(t,numel(findall(groot,'Type','figure')),before);verifyEqual(t,c.score,struct('old',true));
end
function testStaleApprovalRejected(t)
c=instanceFixture();spec=annotationManager.specForClassifier(c);r=c.roi(2);
[entry,~]=annotationManager.entryForSpec(r,spec);entry.status='approved';entry.approved_hash='stale';
annotationManager.setEntry(r,spec,entry,'Save',false);
verifyError(t,@()classifierStats.statistics(c,'PredictionChannel','results_renamed','Silent'), ...
    'classifierStats:StaleGroundTruth');
end
function testDispatchAndReadOnlySource(t)
c=instanceFixture();r=c.roi(2);image=r.image;spec=annotationManager.specForClassifier(c);
before=annotationManager.inspect(r,spec,'ReviewFrames',1:3);
c.stats('PredictionChannel','results_renamed','Force','Silent');
verifyEqual(t,c.score.schema,'detecdiv.classifier_statistics.v1');verifyEqual(t,r.image,image);
verifyEqual(t,c.score.fscore,100);verifyEqual(t,c.score.classes.fscore,100);
verifyEqual(t,annotationManager.inspect(r,spec,'ReviewFrames',1:3),before);
end
function testSemanticSegmentationUsesDeclaredClassIds(t)
c=contractFixture('semantic_mask','channel');r=c.roi(1);
r.addChannel(uint16(reshape([0 1 2 2],2,2)),'gt_mask');
r.addChannel(uint16(reshape([0 2 2 2],2,2)),'results_mask');mark(c,1,1);
report=classifierStats.statistics(c,'Silent');s=report.components;
verifyFalse(t,s.instanceSegmentation);verifyEqual(t,s.confusion,[0 0 0;0 0 1;0 0 2]);
verifyEqual(t,s.pixel.accuracy,2/3,'AbsTol',1e-12);verifyEqual(t,s.pixel.iou(3),2/3,'AbsTol',1e-12);
end
function testSemanticUndefinedPredictionIsPenalizedAndVoidGtIgnored(t)
c=contractFixture('semantic_mask','channel');r=c.roi(1);
r.addChannel(uint16([0 1;2 2]),'gt_mask');r.addChannel(uint16([2 1;0 2]),'results_mask');mark(c,1,1);
report=classifierStats.statistics(c,'Silent');s=report.components;
verifyEqual(t,s.confusion,[0 0 0;0 1 0;1 0 1]);verifyEqual(t,s.pixel.recall(3),0.5);
end
function testTrackedMaskEvaluationIsFrameLocal(t)
c=contractFixture('tracked_instances','channel');r=c.roi(1);
r.addChannel(uint16([0 71;0 71]),'gt_mask');r.addChannel(uint16([0 9;0 9]),'results_mask');mark(c,1,1);
report=classifierStats.statistics(c,'Silent');verifyTrue(t,report.components.instanceSegmentation);
verifyEqual(t,report.components.instances.f1,1);
end
function testFrameLabelsUseRenamedGroupsAndReviewedFrames(t)
c=contractFixture('frame_labels','dataseries');r=c.roi(1);
truth=table(categorical({'a';'b';'b'}),[2;1;1],'VariableNames',{'labels_training','id_training'});
pred=table(categorical({'a';'a';'b'}),'VariableNames',{'labels'});
g=dataseries();g.groupid='gt_group';g.data=truth;p=dataseries();p.groupid='custom_pred';p.data=pred;r.data=[g p];
mark(c,1,[1 3]);report=classifierStats.statistics(c,'PredictionGroup','custom_pred','Silent');s=report.components;
verifyEqual(t,s.confusion,eye(2));verifyEqual(t,s.frameMetrics.frame,[1;3]);
verifyEqual(t,s.pixel.accuracy,1); % Incorrect numeric IDs must not override named labels.
end
function testSequenceLabelsCountOncePerRoi(t)
c=contractFixture('sequence_label','dataseries');r=c.roi(1);
g=dataseries();g.groupid='gt_group';g.data=table(categorical({'a';'a';'a'}),'VariableNames',{'labels_training'});
p=dataseries();p.groupid='prediction_group';p.data=table(categorical({'b';'b';'b'}),'VariableNames',{'labels'});
r.data=[g p];mark(c,1,1:3);report=classifierStats.statistics(c,'Silent');
verifyEqual(t,sum(report.components.confusion(:)),1);verifyEqual(t,height(report.components.frameMetrics),1);
end
function testMissingReviewedPredictionLabelIsNotDropped(t)
c=contractFixture('frame_labels','dataseries');r=c.roi(1);
g=dataseries();g.groupid='gt_group';g.data=table([1;2;1],'VariableNames',{'id_training'});
p=dataseries();p.groupid='prediction_group';p.data=table([1;0;1],'VariableNames',{'id'});
r.data=[g p];mark(c,1,1:3);
verifyError(t,@()classifierStats.statistics(c,'Silent'),'classifierStats:MissingLabels');
end
function testDataseriesFramesAlignByFrameColumn(t)
c=contractFixture('frame_labels','dataseries');r=c.roi(1);
g=dataseries();g.groupid='gt_group';g.data=table([1;2;1],'VariableNames',{'id_training'});
p=dataseries();p.groupid='prediction_group';p.data=table([3;1;2],[1;1;2],'VariableNames',{'frame','id'});
r.data=[g p];mark(c,1,1:3);report=classifierStats.statistics(c,'Silent');
verifyEqual(t,report.components.confusion,diag([2 1]));
end
function testSavedGroupsAreReadableWithoutDiscardingUnsavedReview(t)
folder=tempname;mkdir(folder);clean=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
c=contractFixture('frame_labels','dataseries');r=c.roi(1);r.path=folder;
r.image=ones(2,2,1,3,'uint16');
g=dataseries();g.groupid='gt_group';g.data=table([1;2;1],'VariableNames',{'id_training'});
p=dataseries();p.groupid='prediction_group';p.data=table([1;1;1],'VariableNames',{'id'});
data=[g p];save(fullfile(folder,['data_' r.id '.mat']),'data');
mark(c,1,[1 3]);spec=annotationManager.specForClassifier(c);
% Simulate a classifier snapshot holding only its unsaved annotation manifest.
[~,manifestIndex]=annotationManager.readManifest(r);r.data=r.data(manifestIndex);
before=annotationManager.entryForSpec(r,spec);
report=classifierStats.statistics(c,'Silent');verifyEqual(t,report.components.confusion,diag([2 0]));
verifyEqual(t,annotationManager.entryForSpec(r,spec),before);
verifyFalse(t,any(strcmp({r.data.groupid},'prediction_group')));
end
function testLoadingSavedMaskDoesNotOverwriteUnsavedReview(t)
folder=tempname;mkdir(folder);clean=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
c=instanceFixture();r=c.roi(2);r.path=folder;r.save([],false);
spec=annotationManager.specForClassifier(c);[entry,~]=annotationManager.entryForSpec(r,spec);
entry.review(1).frames(:)=false;entry.review(1).frames(3)=true;
entry=annotationManager.setEntry(r,spec,entry,'Save',false);r.image=[];
report=classifierStats.statistics(c,'PredictionChannel','results_renamed','Silent');
verifyEqual(t,report.components.frameMetrics.frame,3);
verifyEqual(t,annotationManager.entryForSpec(r,spec),entry);
end
function testLegacyMaskNamesRemainSupported(t)
c=classi(tempdir,'legacy_stats',1,'InitTraining',false);c.category={'Pixel'};c.classes={'cell'};
c.dataset.split.test=1;r=roi('legacy',[1 1 2 2]);r.addChannel(uint16([0 1;0 1]),c.strid);
r.addChannel(uint16([0 1;0 1]),['results_' c.strid]);c.roi=r;
report=classifierStats.statistics(c,'Silent');verifyEqual(t,report.components.pixel.accuracy,1);
verifyEqual(t,report.components.legacyRois,1);
end
function testSilentExportContainsDataAndPlotsWithoutVisibleWindows(t)
c=instanceFixture();folder=tempname;mkdir(folder);clean=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
before=numel(findall(groot,'Type','figure'));prefix=fullfile(folder,'stats');
classifierStats.statistics(c,'PredictionChannel','results_renamed','Export',prefix,'Confusion','Silent');
verifyTrue(t,isfile([prefix '.json']));verifyTrue(t,isfile([prefix '_instances_frames.csv']));
verifyTrue(t,isfile([prefix '_instances_statistics.png']));verifyEqual(t,numel(findall(groot,'Type','figure')),before);
end

function c=instanceFixture()
c=classi(tempdir,'other_model_name',1,'InitTraining',false);c.classifierPkg='cellposesam';
c.category={'Pixel'};c.classes={'cell'};c.trainingParam=struct('groundTruthChannelName','gt_custom');
c.dataset.split=struct('train',1,'val',[],'test',2);c.roi=roi.empty;
for k=1:2
    r=roi(sprintf('fixture_%d',k),[1 1 5 4]);r.path=tempdir;
    mask=zeros(4,5,1,3,'uint16');mask(2:3,2:3,1,:)=42;
    pred=mask;pred(pred>0)=103;pred(:,:,1,2)=0;
    r.addChannel(mask,'gt_custom');r.addChannel(pred,'results_renamed');
    r.addChannel(zeros(size(mask),'uint16'),[c.strid '_cell']);
    c.roi(end+1)=r;mark(c,k,[1 3]);
end
end
function c=contractFixture(kind,storage)
c=classi(tempdir,'contract_model',1,'InitTraining',false);c.classifierPkg='statisticsTestFixture';
c.classes={'a','b'};c.category={'Pixel'};c.dataset.split.test=1;
spec=annotationManager.newSpec(c);spec.allowPartialApproval=true;
if strcmp(storage,'channel')
    gt=annotationManager.newAsset('channel','gt_mask');pred=annotationManager.newAsset('channel','results_mask');unit='frame';
else
    gt=annotationManager.newAsset('groupId','gt_group','valueField','labels_training','idField','id_training');
    pred=annotationManager.newAsset('groupId','prediction_group','valueField','labels','idField','id');unit='frame';
    if strcmp(kind,'sequence_label'),unit='roi';end
end
spec.components=annotationManager.newComponent('id','sample','kind',kind,'storage',storage, ...
    'coverageUnit',unit,'classes',c.classes,'groundTruth',gt,'prediction',pred);
c.userData=struct('statisticsSpec',spec);r=roi('contract_fixture',[1 1 2 2]);r.path=tempdir;c.roi=r;
end
function mark(c,index,frames)
spec=annotationManager.specForClassifier(c);
annotationManager.markReviewed(c.roi(index),spec,'Frames',frames,'Save',false);
end
