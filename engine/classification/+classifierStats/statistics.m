function [report,figures]=statistics(classif,varargin)
%STATISTICS Evaluate saved predictions against reviewed GT, without inference.
% PredictionChannel/PredictionGroup may be a name or a struct keyed by component.
o=struct('Rois',[],'Frames',[],'Component','','PredictionChannel','', ...
    'PredictionGroup','','IoUThreshold',0.5,'Export','','Silent',false,'Show',false);
i=1;
while i<=numel(varargin)
    key=char(string(varargin{i}));
    switch lower(key)
        case {'force'} % Current data is always evaluated, never cached scores.
        case {'confusion','classes','roi'},o.Show=true;
        case 'silent',o.Silent=true;
        otherwise
            fields=fieldnames(o);k=find(strcmpi(fields,key),1);
            assert(~isempty(k)&&i<numel(varargin),'classifierStats:Option','Unsupported or incomplete statistics option: %s.',key);
            o.(fields{k})=varargin{i+1};i=i+1;
    end
    i=i+1;
end
validateattributes(o.IoUThreshold,{'numeric'},{'scalar','finite','>',0,'<=',1});
if isempty(o.Rois),o.Rois=classif.dataset.split.test;end
indices=unique(double(o.Rois(:).'),'stable');
assert(~isempty(indices)&&all(isfinite(indices)&indices==fix(indices)&indices>=1&indices<=numel(classif.roi)), ...
    'classifierStats:NoTestRois','Select valid test ROIs before displaying statistics.');
spec=annotationManager.specForClassifier(classif);
report=struct('schema','detecdiv.classifier_statistics.v1','classifierId',classif.strid, ...
    'roiIndices',indices,'iouThreshold',o.IoUThreshold,'components',struct([]), ...
    'notes','Ratios are in [0,1]. Undefined denominators are NaN. Only reviewed frames are used for managed annotations.');
for component=spec.components(:).'
    if ~isempty(o.Component)&&~strcmp(component.id,o.Component),continue;end
    mask=strcmp(component.storage,'channel')&&any(strcmp(component.kind,{'instance_mask','tracked_instances','semantic_mask'}));
    labels=strcmp(component.storage,'dataseries')&&any(strcmp(component.kind,{'frame_labels','sequence_label'}));
    if ~mask&&~labels,continue;end
    instance=mask&&any(strcmp(component.kind,{'instance_mask','tracked_instances'}))&& ...
        (~spec.legacyFallback||contains(component.groundTruth.semantic,'instances'));
    classes=cellstr(string(component.classes));if isempty(classes),classes=cellstr(string(classif.classes));end
    if instance,names={'background','cell'};else,names=classes;end
    % Semantic class IDs follow the annotation/training convention 1..K.
    % GT zero is unlabelled, not an invented background class. Prediction
    % zero on a labelled GT pixel remains an error (column 1).
    if mask&&~instance,names=[{'unclassified (0)'},names(:).'];end
    C=numel(names);assert(C>0,'classifierStats:Classes','No classes declared for %s.',component.id);
    matrix=zeros(C);rows=struct([]);details=struct([]);legacyRois=[];
    for index=indices
        r=classif.roi(index);
        if isempty(r.image)&&mask,loadImages(r);end
        % Annotation manifests may live in userData on an empty dataseries.
        % Never reload that in-memory manifest merely because its table is empty.
        if isempty(r.data),r.load('data');end
        [frames,legacy]=classifierStats.reviewedFrames(classif,index,spec,component,o.Frames);
        if isempty(frames),continue;end
        if legacy,legacyRois(end+1)=index;end %#ok<AGROW>
        if mask
            [gtName,exists]=annotationManager.resolveChannel(r,component.groundTruth);
            if ~exists&&spec.legacyFallback
                [gtName,exists]=annotationManager.resolveChannel(r,annotationManager.newAsset('channel',classif.strid));
            end
            assert(exists,'classifierStats:MissingGroundTruth','ROI %s: configured GT channel "%s" is missing.',r.id,component.groundTruth.channel);
            asset=component.prediction;override=binding(o.PredictionChannel,component.id);
            if spec.legacyFallback&&~instance&&isempty(override)
                asset.channelCandidates=[{asset.channel},asset.channelCandidates(:).'];
                asset.channel=['results_' classif.strid];
            end
            if ~isempty(override),asset.channel=override;asset.channelCandidates={};asset.family='';end
            [predName,exists]=annotationManager.resolveChannel(r,asset);
            assert(exists,'classifierStats:MissingPrediction', ...
                'ROI %s: prediction "%s" is missing. Select the saved output with PredictionChannel or run validation.',r.id,asset.channel);
            assert(~strcmpi(gtName,predName),'classifierStats:GroundTruthAsPrediction','GT cannot also be the prediction.');
            truth=channel(r,gtName);pred=channel(r,predName);
            assert(isequal(size(truth),size(pred)),'classifierStats:Shape','ROI %s: GT and prediction shapes differ.',r.id);
            assert(size(truth,3)==1,'classifierStats:Shape','Masks must be indexed single-channel images.');
            if legacy
                frames=frames(arrayfun(@(f)any(reshape(truth(:,:,1,f)~=0,[],1)),frames));
            end
        else
            gtName=component.groundTruth.groupId;asset=component.prediction;
            if isempty(asset.groupId)&&spec.legacyFallback
                asset.groupId=spec.classifierId;asset.valueField='labels';asset.idField='id';
            end
            override=binding(o.PredictionGroup,component.id);if ~isempty(override),asset.groupId=override;end
            predName=asset.groupId;
            truth=labelValues(r,component.groundTruth,classes);pred=labelValues(r,asset,classes);
            if legacy,frames=frames(truth(frames)>0);end
            if strcmp(component.kind,'sequence_label')&&~isempty(frames)
                assert(numel(unique(truth(frames)))==1&&numel(unique(pred(frames)))==1, ...
                    'classifierStats:SequenceLabels','ROI %s has inconsistent labels within a sequence.',r.id);
                frames=frames(1); % One observation per sequence, not per repeated row.
            end
        end
        for frame=frames(:).'
            m=[];
            if mask
                a=double(truth(:,:,1,frame));b=double(pred(:,:,1,frame));
                if instance
                    m=classifierStats.instanceMetrics(a,b,o.IoUThreshold);a=double(a>0);b=double(b>0);
                else
                    assert(all(isfinite(a(:))&a(:)>=0&a(:)==fix(a(:))&a(:)<C)&& ...
                        all(isfinite(b(:))&b(:)>=0&b(:)==fix(b(:))&b(:)<C), ...
                        'classifierStats:InvalidSemanticMask','Semantic labels must be 0 (unlabelled) or declared class indices. Declare an instance-mask contract for object IDs.');
                end
                if instance,keep=true(size(a));else,keep=a>0;end
                if ~any(keep(:)),continue;end
                cm=accumarray([a(keep)+1 b(keep)+1],1,[C C]);
            else
                a=truth(frame);b=pred(frame);
                assert(a>0&&b>0,'classifierStats:MissingLabels', ...
                    'ROI %s frame %d: reviewed GT or prediction is undefined in groups %s / %s.',r.id,frame,gtName,predName);
                cm=accumarray([a b],1,[C C]);
            end
            matrix=matrix+cm;pm=classifierStats.confusionMetrics(cm);
            row=struct('roiIndex',index,'roiId',r.id,'frame',frame,'groundTruth',gtName, ...
                'prediction',predName,'accuracy',pm.accuracy,'foregroundDice',NaN,'foregroundIoU',NaN);
            if instance,row.foregroundDice=pm.dice(2);row.foregroundIoU=pm.iou(2);end
            if instance
                fn=fieldnames(m);for k=1:numel(fn),row.(fn{k})=m.(fn{k});end
                details=[details,m]; %#ok<AGROW>
            end
            rows=[rows,row]; %#ok<AGROW>
        end
    end
    assert(~isempty(rows),'classifierStats:NoEvaluationSamples', ...
        'No reviewed GT frames with predictions for component "%s". Select test ROIs, review their GT, and run validation. Legacy unreviewed empty masks are excluded.',component.id);
    result=struct('id',component.id,'kind',component.kind,'instanceSegmentation',instance, ...
        'classNames',{names},'confusion',matrix,'pixel',classifierStats.confusionMetrics(matrix), ...
        'frameMetrics',struct2table(rows),'instances',struct(),'legacyRois',unique(legacyRois));
    if instance
        totals=details(1);keys={'groundTruthCount','predictionCount','truePositive','falsePositive','falseNegative','sumMatchedIoU'};
        for key=keys,totals.(key{1})=sum([details.(key{1})]);end
        tp=totals.truePositive;fp=totals.falsePositive;fn=totals.falseNegative;
        totals.precision=ratio(tp,tp+fp);totals.recall=ratio(tp,tp+fn);
        totals.f1=ratio(2*tp,2*tp+fp+fn);totals.matchedIoU=ratio(totals.sumMatchedIoU,tp);
        totals.panopticQuality=ratio(totals.sumMatchedIoU,tp+0.5*(fp+fn));result.instances=totals;
    end
    report.components=[report.components,result];
end
assert(~isempty(report.components),'classifierStats:Unsupported','No supported mask or discrete-label component in this annotation contract.');
report=classifierStats.withLegacyFields(report);
% Publish only a complete successful report, so errors cannot replace prior scores.
classif.score=report;figures=gobjects(0);
if ~isempty(o.Export)
    prefix=char(string(o.Export));folder=fileparts(prefix);if ~isempty(folder)&&~isfolder(folder),mkdir(folder);end
    fid=fopen([prefix '.json'],'w');assert(fid>=0);clean=onCleanup(@()fclose(fid));
    fwrite(fid,jsonencode(report,'PrettyPrint',true),'char');clear clean;
    for c=report.components,writetable(c.frameMetrics,[prefix '_' matlab.lang.makeValidName(c.id) '_frames.csv']);end
end
if o.Show&&(~o.Silent||~isempty(o.Export))
    figures=classifierStats.displayReport(report,'Visible',~o.Silent,'Export',o.Export);
end
end

function value=binding(raw,id)
if isstruct(raw)
    key=matlab.lang.makeValidName(id);value='';if isfield(raw,key),value=char(string(raw.(key)));end
else,value=char(string(raw));end
end
function im=channel(r,name)
idx=r.findChannelID(name);
if isempty(idx)||any(idx>size(r.image,3)),loadImages(r,'Channel',name);idx=r.findChannelID(name);end
assert(~isempty(idx)&&all(idx<=size(r.image,3)),'classifierStats:MissingChannel','Cannot read channel %s in ROI %s.',name,r.id);
im=r.image(:,:,idx,:);
end
function loadImages(r,varargin)
% roi.load('Data',false) clears the dataseries cache in the legacy loader.
% Retain live annotation reviews and measurements while reading image planes.
data=r.data;cleanup=onCleanup(@()restoreData(r,data)); %#ok<NASGU>
r.load(varargin{:},'Data',false,'Silent');
end
function restoreData(r,data)
r.data=data;
end
function values=labelValues(r,asset,classes)
data=classifierStats.series(r);k=find(strcmp({data.groupid},asset.groupId),1);
assert(~isempty(k),'classifierStats:MissingLabels','ROI %s: missing dataseries group %s.',r.id,asset.groupId);
t=data(k).data;fields=t.Properties.VariableNames;
% Human-readable labels are authoritative when present (IDs may be stale).
if ~isempty(asset.valueField)&&ismember(asset.valueField,fields),raw=t.(asset.valueField);
elseif ~isempty(asset.idField)&&ismember(asset.idField,fields),raw=t.(asset.idField);
else,error('classifierStats:MissingLabels','ROI %s: missing label fields in group %s.',r.id,asset.groupId);end
if isnumeric(raw)||islogical(raw)
    ids=double(raw(:));assert(all(isfinite(ids)&ids>=0&ids==fix(ids)&ids<=numel(classes)), ...
        'classifierStats:InvalidLabels','Invalid numeric class indices.');
else
    text=string(raw(:));[known,ids]=ismember(text,string(classes));
    blank=ismissing(text)|ismember(lower(text),["","undefined","unclassified","<undefined>"]);
    assert(all(known|blank),'classifierStats:InvalidLabels','Unknown class label in group %s.',asset.groupId);
    ids(blank)=0;
end
frameColumn=find(strcmpi(fields,'frame'),1);
if ~isempty(frameColumn),frames=double(t.(fields{frameColumn})(:));else,frames=(1:height(t)).';end
n=annotationManager.frameCount(r);
assert(numel(ids)==numel(frames)&&numel(unique(frames))==numel(frames)&& ...
    all(isfinite(frames)&frames==fix(frames)&frames>=1&frames<=n), ...
    'classifierStats:InvalidFrames','Invalid/duplicate dataseries frame indices.');
values=zeros(1,n);values(frames)=ids;
end
function v=ratio(a,b)
v=a./b;if b==0,v=NaN;end
end
