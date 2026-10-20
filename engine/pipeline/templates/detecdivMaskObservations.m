function ctx = detecdivMaskObservations(ctx)
%DETECDIVMASKOBSERVATIONS Register mask observations without temporal tracking.
% Pipeline customModule context function. Parameters: maskChannelName,
% familyName, and optional requireImmediatePersistence (default false).
% Every (frame, mask_label) receives its own positive identity. Equal pixel
% labels in different frames never imply that the observations are one cell.
% Cell-model sidecars are persisted immediately; image pixels are not saved.
% An existing owned family is reusable only when pixels, frames and identity
% rows are unchanged and no state, lineage or censoring has been added to it.
if isfield(ctx,'dryRun') && logical(ctx.dryRun), return; end
if ~isfield(ctx,'params') || ~isstruct(ctx.params) || ~isscalar(ctx.params)
    error('detecdivMaskObservations:Parameters','A scalar params structure is required.');
end
p=ctx.params;
maskName=requiredText(p,'maskChannelName');
familyName=requiredText(p,'familyName');
requireImmediate=false;
if isfield(p,'requireImmediatePersistence')
    validateattributes(p.requireImmediatePersistence,{'logical'},{'scalar'});
    requireImmediate=p.requireImmediatePersistence;
end
if requireImmediate && deferredImages(ctx)
    error('detecdivMaskObservations:DeferredImages', ...
        ['The consuming adapter reloads its mask channel from disk. Use ' ...
         'immediate image persistence before this observation bridge.']);
end
if ~isfield(ctx,'roiList') || ~isa(ctx.roiList,'roi') || isempty(ctx.roiList)
    error('detecdivMaskObservations:ROI','A nonempty ctx.roiList of ROI objects is required.');
end

% Prepare and validate every ROI before the first persistent write.
rois=ctx.roiList;
models=cell(size(rois)); changed=false(size(rois));
for k=1:numel(rois)
    r=rois(k);
    if isempty(r.id) || isempty(r.path) || ~isfolder(r.path)
        error('detecdivMaskObservations:Path', ...
            'ROI %s needs an existing data folder before observations can be saved.',string(r.id));
    end
    pix=r.findChannelID(maskName,'exact','IgnoreCase',false);
    if isempty(r.image) || isempty(pix)
        r.load('Channel',maskName,'Data',false,'Silent');
        pix=r.findChannelID(maskName,'exact','IgnoreCase',false);
    end
    if numel(pix)~=1 || isempty(r.image) || pix>size(r.image,3)
        error('detecdivMaskObservations:MaskChannel', ...
            'ROI %s requires one loaded scalar mask channel named %s.',string(r.id),maskName);
    end
    frames=selectedFrames(ctx,size(r.image,4));
    [frameColumn,labelColumn,sourceHash]=observations(r.image,pix,frames);
    model=r.loadCellModel('MigrateLegacy',false);
    model=cellModel.normalize(model,r.id);
    cellModel.validate(model,'Throw',true);
    [models{k},changed(k)]=prepareModel(model,maskName,familyName, ...
        frames,frameColumn,labelColumn,sourceHash);
    cellModel.validate(models{k},'Throw',true);
end
for k=1:numel(rois)
    if changed(k), rois(k).saveCellModel(models{k}); end
end
ctx.roiList=rois;
end

function value=requiredText(p,name)
if ~isfield(p,name) || ...
        ~((ischar(p.(name)) && isrow(p.(name))) || ...
          (isstring(p.(name)) && isscalar(p.(name)) && ~ismissing(p.(name))))
    error('detecdivMaskObservations:Parameters','Set %s explicitly.',name);
end
value=strtrim(char(p.(name)));
if isempty(value), error('detecdivMaskObservations:Parameters','Set %s explicitly.',name); end
end

function tf=deferredImages(ctx)
tf=false;
if ~isfield(ctx,'io') || ~isstruct(ctx.io), return; end
if isfield(ctx.io,'deferredSave') && isequal(ctx.io.deferredSave,true), tf=true; end
if isfield(ctx.io,'saveMode') && ~isempty(ctx.io.saveMode)
    tf=tf || any(strcmpi(strtrim(char(string(ctx.io.saveMode))), ...
        {'defer','deferred','roi','roi_final','roi_finalized','final','finalized','memory'}));
end
end

function frames=selectedFrames(ctx,nFrames)
frames=1:nFrames;
if isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'frames') && ...
        ~isempty(ctx.sel.frames) && ~isequal(ctx.sel.frames,-1)
    if ~isnumeric(ctx.sel.frames) || ~isreal(ctx.sel.frames)
        error('detecdivMaskObservations:Frames','Frames must be a contiguous one-based numeric range.');
    end
    frames=double(ctx.sel.frames(:)');
end
if isempty(frames) || any(~isfinite(frames)) || any(mod(frames,1)) || ...
        frames(1)<1 || frames(end)>nFrames || frames(end)>double(intmax('uint32')) || ...
        any(diff(frames)~=1)
    error('detecdivMaskObservations:Frames','Frames must be a contiguous one-based range within the ROI.');
end
end

function [frameColumn,labelColumn,fingerprint]=observations(image,pix,frames)
digest=java.security.MessageDigest.getInstance('SHA-256');
header=sprintf('detecdiv.mask_observations.v1\n%d,%d\n',size(image,1),size(image,2));
digest.update(unicode2native(header,'UTF-8'));
digest.update(bytesBigEndian(uint32(frames(:))));
frameRows=cell(numel(frames),1); labelRows=cell(numel(frames),1);
for k=1:numel(frames)
    plane=image(:,:,pix,frames(k));
    values=double(plane(:));
    if ~isreal(plane) || any(~isfinite(values)) || any(values<0) || ...
            any(mod(values,1)) || any(values>double(intmax('uint32')))
        error('detecdivMaskObservations:MaskPixels', ...
            'Mask pixels must be finite nonnegative integers representable as uint32.');
    end
    plane=uint32(plane);
    digest.update(bytesBigEndian(plane(:)));
    labels=unique(plane(:)); labels(labels==0)=[];
    labelRows{k}=labels;
    frameRows{k}=repmat(uint32(frames(k)),numel(labels),1);
end
frameColumn=vertcat(frameRows{:}); labelColumn=vertcat(labelRows{:});
if isempty(frameColumn)
    error('detecdivMaskObservations:NoObservations','Selected masks contain no observations.');
end
fingerprint=digestText(digest);
end

function [model,changed]=prepareModel(model,maskName,familyName,frames,frameColumn,labelColumn,sourceHash)
policy='unique_per_observation';
source='detecdivMaskObservations:unique_per_observation:v1';
records=struct([]);
if isfield(model.provenance,'mask_observation_sources')
    records=model.provenance.mask_observation_sources;
    if ~isempty(records) && ~isstruct(records)
        error('detecdivMaskObservations:Provenance','Existing observation provenance is invalid.');
    end
end
% Resolve strictly by name; familyIndex also accepts mask-provider aliases.
familyIndex=find(strcmp(model.families.name,familyName),1);
if ~isempty(familyIndex)
    familyId=model.families.family_id(familyIndex);
    hits=[];
    if ~isempty(records) && isfield(records,'family_id')
        hits=find(strcmp(arrayfun(@(r)char(string(r.family_id)),records,'UniformOutput',false), ...
            char(string(familyId))));
    end
    rows=find(model.instances.family_id==familyId);
    keysMatch=isequal(model.instances.frame(rows),frameColumn) && ...
        isequal(model.instances.mask_label(rows),labelColumn);
    owned=numel(hits)==1 && strcmp(model.families.mask_provider{familyIndex},maskName) && ...
        strcmp(model.families.lineage_source{familyIndex},source);
    if owned
        record=records(hits);
        required={'format','family_name','mask_provider','identity_policy', ...
            'source_sha256','instances_sha256','source_frames_one_based'};
        owned=all(isfield(record,required));
    end
    if owned
        owned=strcmp(record.format,'detecdiv.mask_observations.v1') && ...
            strcmp(record.family_name,familyName) && strcmp(record.mask_provider,maskName) && ...
            strcmp(record.identity_policy,policy) && strcmp(record.source_sha256,sourceHash) && ...
            isequal(double(record.source_frames_one_based(:)'),frames) && keysMatch && ...
            numel(unique(model.instances.track_id(rows)))==numel(rows) && ...
            all(model.instances.track_id(rows)>0) && all(model.instances.state_id(rows)==0) && ...
            ~any(model.relations.family_id==familyId) && ~any(model.censoring.family_id==familyId) && ...
            strcmp(record.instances_sha256,instanceHash(model.instances,rows));
    end
    if ~owned
        error('detecdivMaskObservations:ExistingFamily', ...
            ['Family %s already exists with changed pixels, identities or annotations, ' ...
             'or belongs to another producer. Choose a new observation family name.'],familyName);
    end
    changed=false;
    return;
end
if max([model.families.family_id;uint32(0)])==intmax('uint32')
    error('detecdivMaskObservations:IdentifierOverflow','No free family identifier.');
end
familyId=max([model.families.family_id;uint32(0)])+uint32(1);
n=numel(frameColumn);
nextObject=max([model.instances.object_id;uint64(0)]);
nextTrack=max([model.instances.track_id;uint64(0)]);
if nextObject>intmax('uint64')-uint64(n) || nextTrack>intmax('uint64')-uint64(n)
    error('detecdivMaskObservations:IdentifierOverflow','No free observation identifiers.');
end
model.families.family_id(end+1,1)=familyId;
model.families.name{end+1,1}=familyName;
model.families.mask_provider{end+1,1}=maskName;
model.families.lineage_source{end+1,1}=source;
model.families.color_rgb(end+1,:)=uint8([180 180 180]);
rows=numel(model.instances.object_id)+(1:n);
model.instances.object_id(rows,1)=nextObject+uint64((1:n)');
model.instances.family_id(rows,1)=familyId;
model.instances.frame(rows,1)=frameColumn;
model.instances.mask_label(rows,1)=labelColumn;
model.instances.track_id(rows,1)=nextTrack+uint64((1:n)');
model.instances.state_id(rows,1)=uint16(0);
record=struct('format','detecdiv.mask_observations.v1', ...
    'family_id',char(string(familyId)),'family_name',familyName,'mask_provider',maskName, ...
    'identity_policy',policy,'source_sha256',sourceHash, ...
    'instances_sha256',instanceHash(model.instances,rows), ...
    'source_frames_one_based',frames);
if isempty(records), records=record; else, records(end+1)=record; end
model.provenance.mask_observation_sources=records;
changed=true;
end

function value=instanceHash(instances,rows)
digest=java.security.MessageDigest.getInstance('SHA-256');
names={'object_id','family_id','frame','mask_label','track_id','state_id'};
for k=1:numel(names)
    digest.update(unicode2native([names{k} newline],'UTF-8'));
    digest.update(bytesBigEndian(instances.(names{k})(rows)));
end
value=digestText(digest);
end

function bytes=bytesBigEndian(values)
[~,~,endian]=computer;
if endian=='L', values=swapbytes(values); end
bytes=typecast(values(:),'uint8');
end

function value=digestText(digest)
value=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end
