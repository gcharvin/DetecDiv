function out = format(classif, rois, ctx)
%FORMAT Build reviewed feature sequences; retain ROI-disjoint validation.
if nargin<3,ctx=struct();end
p=lstm_timeseries.parameters(classif);classes=cellstr(string(classif.classes(:).'));
assert(numel(classes)>=2&&numel(unique(classes))==numel(classes),'lstm_timeseries:Classes','Define at least two distinct state classes.');
assert(all(strlength(strtrim(string(classes)))>0)&& ...
    ~any(ismember(lower(string(classes)),["undefined","unclassified","<undefined>"])), ...
    'lstm_timeseries:Classes','State classes must have nonempty names distinct from undefined/unclassified.');
test=[];val=[];
try,test=classif.dataset.split.test;val=classif.dataset.split.val;catch,end
assert(isempty(intersect(rois,val)),'lstm_timeseries:SplitOverlap','Training and validation ROI overlap.');
assert(isempty(intersect(val,test)),'lstm_timeseries:SplitOverlap','Validation and test ROI overlap.');
rois=setdiff(rois,test,'stable');
if isempty(val)&&p.validationFraction>0&&numel(rois)>1
    s=RandStream('mt19937ar','Seed',p.seed);order=randperm(s,numel(rois));
    count=min(numel(rois)-1,max(1,round(numel(rois)*p.validationFraction)));
    val=rois(order(1:count));rois=rois(order(count+1:end));
end
assert(~isempty(rois),'lstm_timeseries:NoTrainingRois','No training ROI available.');
requested=[];if isfield(ctx,'sel')&&isfield(ctx.sel,'frames'),requested=ctx.sel.frames;end
[selection,~]=annotationManager.reviewedFramesForClassifier(classif,[rois val],'Frames',requested);
samples=struct('roiIndex',{},'roiId',{},'frames',{},'X',{},'Y',{},'split',{});schema=[];
for k=[rois(:)' val(:)']
    r=classif.roi(k);[X,currentSchema]=lstm_timeseries.features(classif,r,p);
    if isempty(schema),schema=currentSchema;end
    selected=selection.(sprintf('roi%d',k));
    if isempty(selected),continue;end
    spec=annotationManager.specForClassifier(classif);
    validation=annotationManager.validate(r,spec,'RequireReviewed',true,'AllowPartial',true,'ReviewFrames',selected);
    assert(validation.valid,'lstm_timeseries:InvalidGT','ROI %s: %s',r.id,strjoin(cellstr(validation.errors),' '));
    i=find(strcmp({r.data.groupid},classif.strid),1);
    assert(~isempty(i),'lstm_timeseries:MissingGT','ROI %s has no state annotations.',r.id);
    t=r.data(i).data;
    assert(ismember('labels_training',t.Properties.VariableNames),'lstm_timeseries:MissingGT','Missing labels_training.');
    names=string(t.labels_training);known=ismember(names,string(classes));
    selected=selected(selected<=numel(known));selected=selected(known(selected));
    windows=lstm_timeseries.sequences(classif,r,size(X,2),selected,p);
    split='train';if ismember(k,val),split='val';end
    for w=1:numel(windows)
        f=windows{w};labels=categorical(names(f),classes);
        if ~strcmp(p.outputMode,'frame')
            assert(numel(unique(labels))==1,'lstm_timeseries:ConflictingWindowGT', ...
                'ROI %s frames %d:%d have conflicting state labels; annotate one class for the complete %s.',r.id,f(1),f(end),p.outputMode);
            labels=labels(1);
        else,labels=labels(:)';end
        if strcmp(p.missingPolicy,'error'),assert(all(isfinite(X(:,f)),'all'),'lstm_timeseries:MissingValues','ROI %s has missing feature values inside a reviewed sequence.',r.id);end
        samples(end+1)=struct('roiIndex',k,'roiId',r.id,'frames',f,'X',X(:,f),'Y',labels,'split',split); %#ok<AGROW>
    end
end
isTrain=strcmp({samples.split},'train');assert(any(isTrain),'lstm_timeseries:NoSamples','No complete reviewed training sequence.');
labels=string([samples(isTrain).Y]);
assert(all(ismember(string(classes),labels)),'lstm_timeseries:MissingTrainingClass','Every class must occur in training ROI. Adjust the ROI split or add reviewed examples.');
dataset=struct('schemaVersion',1,'parameters',p,'classes',{classes},'features',schema, ...
    'trainRoiIndices',rois,'validationRoiIndices',val,'testRoiIndices',test,'samples',samples);
folder=fullfile(classif.path,'trainingdataset');if ~isfolder(folder),mkdir(folder);end
filename=fullfile(folder,'lstm_timeseries_dataset.mat');save(filename,'dataset','-v7.3');
out=lstm_timeseries.result('format');out.artifacts.dataset=filename;
out.metrics=struct('trainingSequences',nnz(isTrain),'validationSequences',nnz(~isTrain));
out.provides={'NumericSequenceTrainingSet'};
end
