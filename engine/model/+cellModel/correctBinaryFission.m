function [model, report] = correctBinaryFission(model, family, parentFrame, parentLabel, daughterLabels)
%CORRECTBINARYFISSION Atomically split identities and replace one fission.
% The selected parent is on parentFrame; daughters are on parentFrame+1.
% Pixel masks and object IDs are unchanged. Existing future track segments,
% their later descendants and censoring follow the reassigned identities.
model=cellModel.normalize(model);
[~,familyId]=cellModel.familyIndex(model,family);
if isempty(familyId),error('cellModel:UnknownFamily','Unknown family.');end
if ~strcmp(cellModel.divisionMode(model,familyId),'binary_fission')
    error('cellModel:NotBinaryFission','This family is not configured for binary fission.');
end
validateattributes(parentFrame,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(daughterLabels,{'numeric'},{'vector','numel',2,'integer','positive','finite'});
if daughterLabels(1)==daughterLabels(2)
    error('cellModel:SameFissionDaughter','Select two distinct daughter objects.');
end
birth=double(parentFrame)+1;
parent=cellModel.findInstance(model,familyId,parentFrame,parentLabel);
if isempty(parent)||parent.track_id==0
    error('cellModel:UnknownFissionParent','The selected parent must have a track ID.');
end
sources=zeros(1,2,'uint64');
for k=1:2
    child=cellModel.findInstance(model,familyId,birth,daughterLabels(k));
    if isempty(child)||child.track_id==0
        error('cellModel:UnknownFissionDaughter','Each daughter must be a tracked object on frame %u.',birth);
    end
    sources(k)=child.track_id;
end
if sources(1)==sources(2)
    error('cellModel:SameFissionDaughterTrack','The two objects share an invalid track identity.');
end
inFamily=model.instances.family_id==familyId;
parentTrack=parent.track_id;
if ~ismember(parentTrack,sources) && any(inFamily & ...
        model.instances.track_id==parentTrack & model.instances.frame>=birth)
    error('cellModel:FissionParentContinues','The parent continues outside the two selected daughters. Correct the selection or its tracking first.');
end
used=[model.instances.track_id(inFamily); ...
    model.relations.parent_track_id(model.relations.family_id==familyId); ...
    model.relations.child_track_id(model.relations.family_id==familyId);uint64(0)];
last=max(used);
if last>intmax('uint64')-uint64(2),error('cellModel:TrackIdOverflow','No free track IDs.');end
newIds=last+uint64([1 2]);
before=model;
changedFrames=[];
% Remove the previous assertion at precisely this division, including a
% wrongly associated sibling. The user-selected pair replaces it together.
remove=model.relations.family_id==familyId & ...
    model.relations.parent_track_id==parentTrack & model.relations.event_frame==birth;
removedRelations=nnz(remove);
names=fieldnames(model.relations);
for k=1:numel(names),model.relations.(names{k})(remove,:)=[];end
for k=1:2
    oldRows=inFamily & before.instances.track_id==sources(k);
    bornHere=min(double(before.instances.frame(oldRows)))>=birth;
    [model,moved]=cellModel.reassignTrack(model,familyId,birth,daughterLabels(k),newIds(k),'to-last','Fast',true);
    changedFrames=union(changedFrames,moved.frames);
    % Child links follow a completely moved identity. A continuing parent's
    % own earlier ancestry must remain attached to its pre-division segment.
    relFamily=model.relations.family_id==familyId;
    if bornHere
        rows=relFamily & model.relations.child_track_id==sources(k);
        model.relations.child_track_id(rows)=newIds(k);
    end
    rows=relFamily & model.relations.parent_track_id==sources(k) & ...
        model.relations.event_frame>birth;
    model.relations.parent_track_id(rows)=newIds(k);
end
for k=1:2
    model=cellModel.setParentTrack(model,familyId,birth,newIds(k),parentTrack,'Fast',true);
end
model=cellModel.normalize(model);
cellModel.validate(model,'Throw',true);
report=struct('parent_track_id',parentTrack,'parent_frame',double(parentFrame), ...
    'event_frame',birth,'old_daughter_track_ids',sources,'daughter_track_ids',newIds, ...
    'daughter_mask_labels',uint32(daughterLabels),'family_id',familyId, ...
    'frames',unique([double(parentFrame) changedFrames(:).']), ...
    'replaced_parent_links',removedRelations);
end
