function out = frozenFormat(c,rois,ctx)
%FROZENFORMAT Format reviewed complete windows, preserving explicit ROI splits.
p=cnn_lstm.frozenParameters(c,ctx);split=c.dataset.split;
assert(~isempty(split.val),'cnn_lstm:ValidationSplit','Set explicit validation ROIs for the frozen encoder head.');
assert(isempty(intersect(split.train,split.val))&&isempty(intersect([split.train split.val],split.test)), ...
 'cnn_lstm:SplitOverlap','Training, validation and test ROI must be disjoint.');
rois=intersect(rois,split.train,'stable');assert(~isempty(rois),'cnn_lstm:TrainRois','Select training ROIs.');
samples=struct('roiIndex',{},'roiId',{},'frames',{},'X',{},'Y',{},'split',{});
spec=annotationManager.specForClassifier(c);[coverage,~]=annotationManager.reviewedFramesForClassifier(c,[rois split.val]);
for k=[rois(:)' split.val(:)']
 r=c.roi(k);r.load('Data','Silent');
 r.load('Channel',c.channelName,'Silent');
 n=annotationManager.frameCount(r);selected=coverage.(sprintf('roi%d',k));
 windows=lstm_timeseries.sequences(c,r,n,selected,p);if isempty(windows),r.clear;continue;end
 frames=unique([windows{:}],'stable');[features,encoder]=cnn_lstm.frozenFeatures(c,r,p,frames);
 p.featureCount=size(features,1);j=find(strcmp({r.data.groupid},c.strid),1);labels=string(r.data(j).data.labels_training);
 for w=1:numel(windows)
  f=windows{w};assert(numel(unique(labels(f)))==1,'cnn_lstm:ConflictingGT','Regroup annotations before formatting mixed windows.');
  [~,idx]=ismember(f,frames);part='train';if ismember(k,split.val),part='val';end
  samples(end+1)=struct('roiIndex',k,'roiId',r.id,'frames',f,'X',features(:,idx), ...
   'Y',categorical(labels(f(1)),c.classes,c.classes),'split',part); %#ok<AGROW>
 end
 r.clear;
end
assert(~isempty(samples),'cnn_lstm:NoSamples','No complete reviewed image windows.');
dataset=struct('parameters',p,'classes',{c.classes},'features',struct('selector','frozenCNN / embedding', ...
 'group','frozenCNN','variable','embedding','column',1),'encoder',encoder,'samples',samples, ...
 'trainRoiIndices',rois,'validationRoiIndices',split.val,'testRoiIndices',split.test);
folder=fullfile(c.path,'trainingdataset');if ~isfolder(folder),mkdir(folder);end
file=fullfile(folder,'frozen_encoder_dataset.mat');save(file,'dataset','-v7.3');
out=cnn_lstm.utils.outInitSafe('cnn_lstm.frozenFormat');out.artifacts.dataset=file;
out.metrics=struct('trainingSequences',nnz(strcmp({samples.split},'train')), ...
 'validationSequences',nnz(strcmp({samples.split},'val')),'featureDimension',p.featureCount);
end
