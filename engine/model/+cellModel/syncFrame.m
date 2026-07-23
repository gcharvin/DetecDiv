function [model, report] = syncFrame(model, family, frame, maskFrame, varargin)
%CELLMODEL.SYNCFRAME Synchronize references after a provider-mask edit.
% Masks remain authoritative; no mask pixels are stored in the model.

p=inputParser;
p.addParameter('TrackPolicy','preserve_or_unassigned',@(x)ischar(x)||isstring(x));
p.parse(varargin{:});
policy=lower(char(string(p.Results.TrackPolicy)));
if ~any(strcmp(policy,{'preserve_or_unassigned','preserve_or_label','mask_label'}))
    error('cellModel:BadTrackPolicy','Unknown TrackPolicy: %s',policy);
end

model=cellModel.normalize(model);
[~,familyId]=cellModel.familyIndex(model,family);
if isempty(familyId), error('cellModel:UnknownFamily','Unknown family: %s',string(family)); end
frame=uint32(frame);
labels=unique(uint32(maskFrame(:))); labels=labels(labels~=0);

oldRows=find(model.instances.family_id==familyId & model.instances.frame==frame);
oldLabels=model.instances.mask_label(oldRows);
preserved=intersect(oldLabels,labels,'stable');
added=setdiff(labels,oldLabels,'stable');
removed=setdiff(oldLabels,labels,'stable');

keep=true(numel(model.instances.object_id),1); keep(oldRows)=false;
base=subsetColumns(model.instances,keep);
nextObject=max([model.instances.object_id;uint64(0)])+uint64(1);
rows=emptyLike(model.instances,numel(labels));
for i=1:numel(labels)
    label=labels(i);
    oldHit=oldRows(find(oldLabels==label,1,'first'));
    if ~isempty(oldHit)
        rows.object_id(i)=model.instances.object_id(oldHit);
        rows.track_id(i)=model.instances.track_id(oldHit);
        rows.state_id(i)=model.instances.state_id(oldHit);
    else
        rows.object_id(i)=nextObject; nextObject=nextObject+uint64(1);
        rows.track_id(i)=newTrackId(model,familyId,label,policy);
        rows.state_id(i)=uint16(0);
    end
    rows.family_id(i)=familyId;
    rows.frame(i)=frame;
    rows.mask_label(i)=label;
end
model.instances=appendColumns(base,rows);
model=cellModel.normalize(model);
report=struct('family_id',familyId,'frame',frame,'added',added, ...
    'removed',removed,'preserved',preserved);
end

function trackId=newTrackId(model,familyId,label,policy)
if strcmp(policy,'mask_label'), trackId=uint64(label); return; end
same=find(model.instances.family_id==familyId & model.instances.mask_label==label & ...
    model.instances.track_id~=0,1,'last');
if ~isempty(same), trackId=model.instances.track_id(same); return; end
if strcmp(policy,'preserve_or_label'), trackId=uint64(label); else, trackId=uint64(0); end
end

function out=subsetColumns(in,keep)
out=in; names=fieldnames(in);
for i=1:numel(names), out.(names{i})=in.(names{i})(keep,:); end
end

function out=emptyLike(in,n)
out=in; names=fieldnames(in);
for i=1:numel(names), out.(names{i})=zeros(n,1,class(in.(names{i}))); end
end

function out=appendColumns(a,b)
out=a; names=fieldnames(a);
for i=1:numel(names), out.(names{i})=[a.(names{i});b.(names{i})]; end
end
