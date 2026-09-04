function sequence = readRaw(roiObj, family, trackId, varargin)
%CELLMETRICS.READRAW Read raw pixels aligned to a latent-model track.
% Pixels remain owned by the ROI image store. This function returns a
% bounded view plus exact cell-model identities and masks; it never copies
% raw data into the cell-model sidecar.

p=inputParser;
p.addParameter('Channels',{},@(x)ischar(x)||isstring(x)||iscell(x));
p.addParameter('Frames',[],@isnumeric);
p.addParameter('Scope','track',@(x)ischar(x)||isstring(x));
p.addParameter('MarginPixels',8,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=0);
p.addParameter('Model',struct(),@isstruct);
p.parse(varargin{:});
if ~(isobject(roiObj)&&isa(roiObj,'roi'))
    error('cellMetrics:InvalidRoi','First input must be a roi object.');
end
if isempty(fieldnames(p.Results.Model))
    [model,~]=roiObj.loadCellModel('MigrateLegacy',true);
else
    model=cellModel.normalize(p.Results.Model,roiObj.id);
end
[familyIndex,familyId]=cellModel.familyIndex(model,family);
if isempty(familyIndex), error('cellMetrics:UnknownFamily','Cell-model family was not found.'); end
provider=char(string(model.families.mask_provider{familyIndex}));
trackId=uint64(trackId);
if ~isscalar(trackId)||trackId==0, error('cellMetrics:InvalidTrack','TrackId must be a positive scalar.'); end

channels=normalizeChannels(p.Results.Channels);
if isempty(channels)
    channels=defaultRawChannels(roiObj,provider);
end
needed=unique([channels {provider}],'stable');
missing=needed(cellfun(@(x)isempty(roiObj.findChannelID(x,'exact')),needed));
if ~isempty(missing)
    roiObj.load('Channel',missing,'Data',false,'Silent');
end
providerIndex=roiObj.findChannelID(provider,'exact');
if numel(providerIndex)~=1
    error('cellMetrics:InvalidMaskProvider','Mask provider "%s" must resolve to one image plane.',provider);
end
channelIndices=[]; planeNames={};
for i=1:numel(channels)
    idx=roiObj.findChannelID(channels{i},'exact');
    if isempty(idx), error('cellMetrics:MissingRawChannel','Raw channel "%s" was not found.',channels{i}); end
    channelIndices=[channelIndices idx]; %#ok<AGROW>
    if numel(idx)==1
        planeNames{end+1}=channels{i}; %#ok<AGROW>
    else
        for j=1:numel(idx), planeNames{end+1}=sprintf('%s:%d',channels{i},j); end %#ok<AGROW>
    end
end

instanceRows=find(model.instances.family_id==familyId & model.instances.track_id==trackId);
if isempty(instanceRows), error('cellMetrics:UnknownTrack','Track %s has no instance in the selected family.',string(trackId)); end
if isempty(p.Results.Frames)
    frames=unique(double(model.instances.frame(instanceRows)),'stable');
else
    frames=unique(round(double(p.Results.Frames(:))),'stable');
end
if any(frames<1) || any(frames>size(roiObj.image,4))
    error('cellMetrics:FrameOutOfRange','Requested raw frames are outside the loaded ROI range.');
end
parentTrack=parentForTrack(model,familyId,trackId);
scope=lower(char(string(p.Results.Scope)));
if ~ismember(scope,{'track','mother_bud_pair','full_roi'})
    error('cellMetrics:InvalidScope','Scope must be track, mother_bud_pair, or full_roi.');
end

h=size(roiObj.image,1); w=size(roiObj.image,2); nt=numel(frames);
primary=false(h,w,nt); parent=false(h,w,nt);
objectIds=zeros(nt,1,'uint64'); maskLabels=zeros(nt,1,'uint32');
for t=1:nt
    frame=frames(t);
    row=find(model.instances.family_id==familyId & model.instances.track_id==trackId & ...
        model.instances.frame==uint32(frame),1,'first');
    maskFrame=roiObj.image(:,:,providerIndex,frame);
    if ~isempty(row)
        maskLabels(t)=model.instances.mask_label(row);
        objectIds(t)=model.instances.object_id(row);
        primary(:,:,t)=maskFrame==maskLabels(t);
    end
    if strcmp(scope,'mother_bud_pair') && parentTrack>0
        prow=find(model.instances.family_id==familyId & model.instances.track_id==parentTrack & ...
            model.instances.frame==uint32(frame),1,'first');
        if ~isempty(prow), parent(:,:,t)=maskFrame==model.instances.mask_label(prow); end
    end
end

if strcmp(scope,'full_roi')
    rr=1:h; cc=1:w;
else
    support=primary|parent;
    [r,c,~]=ind2sub(size(support),find(support));
    if isempty(r), error('cellMetrics:EmptyTrackMask','Selected track has no pixels in the requested frames.'); end
    margin=round(p.Results.MarginPixels);
    rr=max(1,min(r)-margin):min(h,max(r)+margin);
    cc=max(1,min(c)-margin):min(w,max(c)+margin);
end
sequence=struct( ...
    'schema_version',uint16(1), ...
    'roi_id',char(string(roiObj.id)), ...
    'family_id',familyId, ...
    'family_name',char(string(model.families.name{familyIndex})), ...
    'mask_provider',provider, ...
    'track_id',trackId, ...
    'parent_track_id',parentTrack, ...
    'frames',uint32(frames(:)), ...
    'object_ids',objectIds, ...
    'mask_labels',maskLabels, ...
    'channel_names',{planeNames}, ...
    'row_range',uint32(rr(:)), ...
    'column_range',uint32(cc(:)), ...
    'bbox_xywh',uint32([cc(1) rr(1) numel(cc) numel(rr)]), ...
    'images',roiObj.image(rr,cc,channelIndices,frames), ...
    'primary_mask',primary(rr,cc,:), ...
    'parent_mask',parent(rr,cc,:));
end

function values=normalizeChannels(value)
if isempty(value)
    values={};
elseif ischar(value)||isstring(value)
    values=cellstr(string(value));
else
    values=cellfun(@(x)char(string(x)),value,'UniformOutput',false);
end
values=reshape(values,1,[]);
end

function channels=defaultRawChannels(roiObj,provider)
channels={};
try
    names=roiObj.display.channel;
    indexed=logical(roiObj.display.indexed);
    for i=1:min(numel(names),numel(indexed))
        if ~indexed(i)&&~strcmpi(char(string(names{i})),provider)
            channels{end+1}=char(string(names{i})); %#ok<AGROW>
        end
    end
catch
end
if isempty(channels)
    error('cellMetrics:ChannelsRequired','Specify Channels because no raw intensity channel could be inferred.');
end
end

function parent=parentForTrack(model,familyId,track)
row=find(model.relations.family_id==familyId & model.relations.type_id==uint8(1) & ...
    model.relations.child_track_id==track,1,'first');
if isempty(row), parent=uint64(0); else, parent=model.relations.parent_track_id(row); end
end
