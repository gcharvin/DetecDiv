function tests=testCellposeManagedGroundTruthFormat
tests=functiontests(localfunctions);
end

function setupOnce(~)
repo=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(genpath(repo));
end

function testManagedGtExportsReviewedTrainingFramesAndExcludesTestRoi(t)
root=tempname;mkdir(root);cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
c=fixture(root,false);
out=cellposesam.format(c,[],struct());
verifyEqual(t,out.metrics.outputCount,2);
file=fullfile(c.path,[c.strid '_framebank.h5']);
verifyEqual(t,reshape(h5read(file,'/frame_idx'),1,[]),int32([1 3]));
verifyEqual(t,reshape(h5read(file,'/roi_id'),1,[]),int32([1 1]));
masks=h5read(file,'/masks');
expected=zeros(12,13,'uint16');expected(3:5,4:7)=1;
verifyEqual(t,masks(:,:,1),expected);
verifyEqual(t,masks(:,:,2),expected);
verifyEqual(t,out.metrics.roiFrameSummary.exportedFrameIndices,[1 3]);
end

function testExplicitGtBindingWinsOverLegacyAndPredictionChannels(t)
root=tempname;mkdir(root);cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
c=fixture(root,true);
out=cellposesam.format(c,[],struct());
verifyEqual(t,out.metrics.outputCount,2);
masks=h5read(fullfile(c.path,[c.strid '_framebank.h5']),'/masks');
verifyEqual(t,nnz(masks),24);
verifyEqual(t,masks(3:5,4:7,:),ones(3,4,2,'uint16'));
verifyEqual(t,nnz(masks(8:10,9:11,:)),0);
end

function testMissingConfiguredGtCannotExportLegacyOrPredictionMasks(t)
root=tempname;mkdir(root);cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
c=fixture(root,true);
c.trainingParam.groundTruthChannelName='gt_missing';
spec=annotationManager.specForClassifier(c);
c.roi(1).load('Silent');
annotationManager.markReviewed(c.roi(1),spec,'Frames',[1 3], ...
    'Components',{'instances'},'Save',true);
verifyError(t,@()cellposesam.format(c,[],struct()), ...
    'cellposesam:MissingGroundTruthChannel');
end

function c=fixture(root,explicit)
c=classi(root,'managed_gt',1,'InitTraining',false);
c.classifierPkg='cellposesam';c.category={'Pixel'};
c.channelName='raw';c.classes={'cell'};c.trainingset=1;
c.dataset=struct('classes',{{'cell'}},'channels',{{'raw'}}, ...
    'split',struct('train',1,'val',[],'test',2));
c.trainingParam=struct('min_train_masks',0,'min_train_pixels',0, ...
    'MaxTrainImages',0,'NegDownsampleTrainRatio',0,'CPSAM_ValFraction',0,'Seed',11);
gt=cellposesam.annotationChannelName(c);
if explicit,gt='gt_explicit_reviewed_instances';c.trainingParam.groundTruthChannelName=gt;end
spec=annotationManager.specForClassifier(c);
c.roi=roi.empty;
for k=1:2
    r=roi(sprintf('roi_%d',k),[1 1 13 12]);r.path=c.path;
    r.addChannel(uint16(reshape(1:468,12,13,1,3)),'raw');
    truth=zeros(12,13,1,3,'uint16');truth(3:5,4:7,1,:)=7;
    decoy=zeros(12,13,1,3,'uint16');decoy(8:10,9:11,1,:)=19;
    r.addChannel(truth,gt,[1 1 1],[0 0 0]);
    r.addChannel(decoy,'results_pred_cellposesam_cell',[1 1 1],[0 0 0]);
    if explicit,r.addChannel(decoy,[c.strid '_cell'],[1 1 1],[0 0 0]);end
    annotationManager.markReviewed(r,spec,'Frames',[1 3], ...
        'Components',{'instances'},'Save',false);
    r.save([],false);c.roi(end+1)=r;
end
end
