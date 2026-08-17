function [model, report] = fromLegacy(roiobj, varargin)
%CELLMODEL.FROMLEGACY Build schema v1 from mask channels/cell_information.
% Legacy stable mask labels are imported as track IDs; masks are referenced,
% never copied into the model sidecar.

p=inputParser;
p.addParameter('IncludeIndexedChannels',true,@(x)islogical(x)&&isscalar(x));
p.addParameter('Channels',{},@(x)iscell(x)||ischar(x)||isstring(x));
p.parse(varargin{:});

model=cellModel.create(roiobj.id);
records=legacyFamilyRecords(roiobj);
requested=cellstr(string(p.Results.Channels));
if p.Results.IncludeIndexedChannels
    indexed=cellModel.maskProviderNames(roiobj);
    if ~isempty(requested), indexed=intersect(indexed,requested,'stable'); end
    usedProviders=string({records.mask_provider});
    for i=1:numel(indexed)
        if any(strcmp(usedProviders,string(indexed{i}))), continue; end
        records(end+1)=struct('name',indexed{i},'mask_provider',indexed{i}, ...
            'lineage_source','','source',struct()); %#ok<AGROW>
    end
end
if ~isempty(requested)
    keep=ismember(string({records.mask_provider}),string(requested)); records=records(keep);
end

nextObject=uint64(1); nextRelation=uint64(1);
messages=strings(0,1);
for i=1:numel(records)
    provider=records(i).mask_provider;
    [maskStack,color,ok,msg]=loadProvider(roiobj,provider);
    if ~ok, messages(end+1)=string(msg); continue; end %#ok<AGROW>

    familyId=uint32(numel(model.families.family_id)+1);
    model.families.family_id(end+1,1)=familyId;
    model.families.name{end+1,1}=uniqueFamilyName(model.families.name,records(i).name);
    model.families.mask_provider{end+1,1}=provider;
    model.families.lineage_source{end+1,1}=records(i).lineage_source;
    model.families.color_rgb(end+1,:)=uint8(round(255*max(0,min(1,color))));

    for frame=1:size(maskStack,4)
        labels=unique(uint32(maskStack(:,:,1,frame))); labels=labels(labels~=0);
        n=numel(labels);
        if n==0, continue; end
        model.instances.object_id(end+1:end+n,1)=nextObject+uint64((0:n-1)');
        nextObject=nextObject+uint64(n);
        model.instances.family_id(end+1:end+n,1)=familyId;
        model.instances.frame(end+1:end+n,1)=uint32(frame);
        model.instances.mask_label(end+1:end+n,1)=labels;
        model.instances.track_id(end+1:end+n,1)=uint64(labels);
        model.instances.state_id(end+1:end+n,1)=uint16(0);
    end

    [parents,children,eventFrames]=legacyRelations(records(i).source,model,familyId);
    n=numel(children);
    if n>0
        model.relations.relation_id(end+1:end+n,1)=nextRelation+uint64((0:n-1)');
        nextRelation=nextRelation+uint64(n);
        model.relations.family_id(end+1:end+n,1)=familyId;
        model.relations.parent_track_id(end+1:end+n,1)=parents;
        model.relations.child_track_id(end+1:end+n,1)=children;
        model.relations.event_frame(end+1:end+n,1)=eventFrames;
        model.relations.type_id(end+1:end+n,1)=uint8(1);
        model.relations.confidence(end+1:end+n,1)=single(NaN);
    end
end

model.provenance.source='legacy_cell_information_and_masks';
model=cellModel.normalize(model,roiobj.id);
validation=cellModel.validate(model);
report=struct('validation',validation,'messages',{cellstr(messages)}, ...
    'counts',validation.counts);
end

function records=legacyFamilyRecords(roiobj)
records=struct('name',{},'mask_provider',{},'lineage_source',{},'source',{});
try
    idx=find(arrayfun(@(x)isprop(x,'groupid')&&strcmp(char(string(x.groupid)),'cell_information'),roiobj.data),1);
    if isempty(idx) || ~isstruct(roiobj.data(idx).userData), return; end
    ud=roiobj.data(idx).userData;
    if isfield(ud,'lineageSources')&&isstruct(ud.lineageSources)
        keys=fieldnames(ud.lineageSources);
        for i=1:numel(keys)
            src=ud.lineageSources.(keys{i}); provider='';
            if isfield(src,'channelName'), provider=char(string(src.channelName)); end
            if isempty(provider)&&isfield(ud,'lineageChannelName'),provider=char(string(ud.lineageChannelName));end
            if isempty(provider),continue;end
            name=keys{i}; if isfield(src,'displayName')&&~isempty(src.displayName),name=char(string(src.displayName));end
            records(end+1)=struct('name',name,'mask_provider',provider, ...
                'lineage_source',keys{i},'source',src); %#ok<AGROW>
        end
    elseif isfield(ud,'motherOf')&&isa(ud.motherOf,'containers.Map')
        provider=''; if isfield(ud,'lineageChannelName'),provider=char(string(ud.lineageChannelName));end
        if ~isempty(provider)
            src=struct('motherOf',ud.motherOf); if isfield(ud,'events'),src.events=ud.events;end
            records=struct('name',provider,'mask_provider',provider,'lineage_source','legacy','source',src);
        end
    end
catch
end
end

function [stack,color,ok,msg]=loadProvider(roiobj,name)
stack=[];color=[1 1 1];ok=false;msg='';
try
    pix=roiobj.findChannelID(name,'exact');
catch
    try pix=roiobj.findChannelID(name); catch, pix=[]; end
end
if isempty(pix)||max(pix)>size(roiobj.image,3)
    try roiobj.load('Channel',name,'Data',false,'Silent'); pix=roiobj.findChannelID(name,'exact');
    catch ME, msg=sprintf('Could not load mask provider %s: %s',name,ME.message); return; end
end
if isempty(pix)||max(pix)>size(roiobj.image,3),msg=sprintf('Missing mask provider %s',name);return;end
stack=roiobj.image(:,:,pix(1),:);
try
    idx=find(strcmp(cellstr(string(roiobj.display.channel)),name),1); color=double(roiobj.display.rgb(idx,:));
catch
end
ok=true;
end

function name=uniqueFamilyName(existing,candidate)
name=char(string(candidate)); if isempty(name),name='cells';end
if ~any(strcmp(existing,name)),return;end
base=name; k=2; while any(strcmp(existing,name)),name=sprintf('%s_%d',base,k);k=k+1;end
end

function [parents,children,eventFrames]=legacyRelations(src,model,familyId)
parents=zeros(0,1,'uint64');children=zeros(0,1,'uint64');eventFrames=zeros(0,1,'uint32');
if ~isstruct(src)||~isfield(src,'motherOf')||~isa(src.motherOf,'containers.Map'),return;end
known=unique(model.instances.track_id(model.instances.family_id==familyId)); keys=src.motherOf.keys;
for i=1:numel(keys)
    child=uint64(keys{i}); parent=uint64(src.motherOf(keys{i}));
    if child==0||parent==0||~ismember(child,known)||~ismember(parent,known),continue;end
    children(end+1,1)=child;parents(end+1,1)=parent;eventFrames(end+1,1)=eventFrame(src,child,model,familyId); %#ok<AGROW>
end
end

function frame=eventFrame(src,child,model,familyId)
frame=uint32(0);
if isfield(src,'events')
    for i=1:numel(src.events)
        if isfield(src.events(i),'childId')&&uint64(src.events(i).childId)==child&&isfield(src.events(i),'startFrame')
            frame=uint32(src.events(i).startFrame);return;
        end
    end
end
rows=model.instances.family_id==familyId & model.instances.track_id==child;
if any(rows),frame=min(model.instances.frame(rows));end
end
