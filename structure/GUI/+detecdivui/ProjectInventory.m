classdef ProjectInventory
    % Metadata/cache-only resource inventory. No readers, filesystem probes or migration.
    methods (Static)
        function signature = fingerprint(value)
            signature = digest(value);
        end
        function state = inspect(session)
            state = struct('scope',struct('fov',session.Position,'roi',session.Zone), ...
                'roiIds',{{}},'channels',{{}},'masks',{{}},'families',{{}}, ...
                'rawReferenced',false,'roiCount',0,'images','missing','maskState','missing', ...
                'familyState','missing','frameCounts',[],'signature','');
            if session.Position==0 || isempty(session.Project), state = finish(state,{}); return; end
            f = session.Project.fov(session.Position);
            state.rawReferenced = ~isempty(f.srclist) || any(strlength(string(f.srcpath))>0);
            indices = 1:numel(f.roi); if session.Zone>0, indices = session.Zone; end
            details = {}; haveImages = []; stale = false; maskLists = {}; familyLists = {};
            for k = indices
                r = f.roi(k);
                if isempty(r.id) && isempty(r.value) && isempty(r.image), continue; end
                state.roiIds{end+1} = r.id; state.roiCount = state.roiCount+1;
                names = {}; masks = {}; families = {}; count = 0;
                if isfield(r.display,'channel'), names = cellstr(string(r.display.channel)); end
                for j = 1:numel(names)
                    indexed = isfield(r.display,'indexed') && numel(r.display.indexed)>=j && r.display.indexed(j);
                    if ~indexed && isfield(r.display,'intensity') && size(r.display.intensity,1)>=j
                        indexed = all(r.display.intensity(j,:)==0);
                    end
                    if indexed && ~groundTruth(names{j}), masks{end+1} = names{j}; end %#ok<AGROW>
                end
                status = r.getExtractionStatus(); stale = stale || strcmp(status,'stale');
                cached = ~isempty(r.image);
                haveImages(end+1) = cached || any(strcmp(status,{'extracted','memory'})); %#ok<AGROW>
                if cached, count = size(r.image,4); end
                state.frameCounts(end+1) = count;
                model = r.cellModel; coverage = {};
                if isstruct(model) && isfield(model,'families') && isfield(model,'instances')
                    fs = model.families; instances = model.instances;
                    required = {'family_id','name','mask_provider','lineage_source'};
                    if all(isfield(fs,required)) && all(isfield(instances,{'family_id','frame','track_id'}))
                        for j = 1:numel(fs.family_id)
                            rows = instances.family_id==fs.family_id(j) & instances.track_id>0;
                            frames = unique(instances.frame(rows));
                            coverage{end+1} = struct('name',fs.name{j},'frames',frames, ...
                                'tracks',instances.track_id(rows),'source',fs.lineage_source{j}); %#ok<AGROW>
                            if ~groundTruth(fs.name{j}) && any(strcmp(fs.mask_provider{j},masks)) && ...
                                    any(rows) && ~isempty(fs.lineage_source{j})
                                families{end+1} = fs.name{j}; %#ok<AGROW>
                            end
                        end
                    end
                end
                if state.roiCount==1, state.channels = names;
                else, state.channels = intersect(state.channels,names,'stable'); end
                maskLists{end+1} = masks; familyLists{end+1} = families; %#ok<AGROW>
                details{end+1} = struct('id',r.id,'names',{names},'masks',{masks}, ...
                    'extraction',r.extraction,'cachedSize',size(r.image),'coverage',{coverage}, ...
                    'modelSignature',digest(model)); %#ok<AGROW>
            end
            if ~isempty(haveImages)
                state.images = 'missing';
                if all(haveImages), state.images = 'declared';
                elseif any(haveImages), state.images = 'partial'; end
            end
            [state.masks,state.maskState] = common(maskLists);
            [state.families,state.familyState] = common(familyLists);
            if stale
                state.images = 'stale';
                if ~strcmp(state.maskState,'missing'), state.maskState = 'stale'; end
                if ~strcmp(state.familyState,'missing'), state.familyState = 'stale'; end
            end
            details{end+1} = struct('fov',f.id,'srcpath',{f.srcpath},'srclist',{f.srclist});
            state = finish(state,details);
        end
    end
end
function yes = groundTruth(name)
value = lower(strtrim(char(string(name))));
yes = startsWith(value,{'[gt]','gt_','ground_truth','groundtruth'}) || strcmp(value,'gt');
end
function [names,status] = common(lists)
names = {}; status = 'missing'; if isempty(lists), return; end
names = lists{1};
for k = 2:numel(lists), names = intersect(names,lists{k},'stable'); end
if ~isempty(names), status = 'unverified';
elseif any(~cellfun(@isempty,lists)), status = 'partial'; end
end
function state = finish(state,details)
state.signature = digest(struct('state',rmfield(state,'signature'),'details',{details}));
end
function signature = digest(value)
% Hash typed metadata arrays without making a large JSON copy of cached models.
md = java.security.MessageDigest.getInstance('SHA-256');
feed(value);
bytes = typecast(md.digest(),'uint8'); signature = lower(reshape(dec2hex(bytes,2).',1,[]));
    function feed(item)
        token([class(item) ':' mat2str(size(item)) ':']);
        if isnumeric(item) && isreal(item) && ~issparse(item)
            write(typecast(typecast(item(:),'uint8'),'int8'));
        elseif islogical(item)
            write(int8(item(:)));
        elseif isstruct(item)
            fields = sort(fieldnames(item));
            for row = 1:numel(item)
                for col = 1:numel(fields), name = fields{col}; token(name); feed(item(row).(name)); end
            end
        elseif iscell(item)
            for at = 1:numel(item), feed(item{at}); end
        else
            token(jsonencode(item));
        end
    end
    function token(text)
        encoded = unicode2native(text,'UTF-8');
        write(typecast(uint32(numel(encoded)),'int8')); write(typecast(uint8(encoded),'int8'));
    end
    function write(bytes)
        if ~isempty(bytes), md.update(reshape(bytes,1,[]),int32(0),int32(numel(bytes))); end
    end
end
