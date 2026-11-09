function plans = samplingPlan(r, names, channels, param, ctx)
% Acquisition cadence, not a zero-valued cell measurement, identifies gaps.
% Explicit periods support non-Zarr/standalone ROIs. Zero means metadata.
n = size(r.image,4);
if nargin<5, ctx=struct(); end
parent = r.parent;
if isempty(parent) || ~isa(parent,'fov')
    candidates=[];
    if isfield(ctx,'fovList') && isa(ctx.fovList,'fov')
        candidates=ctx.fovList;
    elseif isfield(ctx,'shallow') && isa(ctx.shallow,'shallow')
        candidates=ctx.shallow.fov;
    end
    for f=1:numel(candidates)
        if any(strcmp({candidates(f).roi.id},r.id))
            parent=candidates(f); break;
        end
    end
end
plans = repmat(struct('channel','','period',1,'first_frame',1, ...
    'source','unavailable','missing_frames',[]),1,numel(names));
for i=1:numel(names)
    plans(i).channel = names{i};
    key = findChannelParameter(param,names{i});
    period = 0; first = 1;
    if ~isempty(key)
        period = getNumber(param,[key '_acquisitionPeriod'],0);
        first = getNumber(param,[key '_firstAcquisitionFrame'],1);
    end
    if period > 0
        plans(i).source = 'explicit';
    else
        [period,source] = metadataPeriod(parent,names{i});
        plans(i).source = source;
    end
    plans(i).period = max(1,period);
    plans(i).first_frame = first;
    if period <= 1 || ~param.interpolateSparseAcquisition, continue; end
    missing = (1:n)<first | mod((1:n)-first,period) ~= 0;
    % Only zero-filled unacquired planes are replaced. Nonzero unexpected
    % acquisitions and genuine zero measurements on acquired frames survive.
    for t=find(missing)
        plane = r.image(:,:,channels{i},t);
        missing(t) = all(plane(:)==0);
    end
    plans(i).missing_frames = find(missing);
end
end

function key=findChannelParameter(param,name)
key='';
for j=1:param.scoreChannelCount
    k=sprintf('channel%d',j);
    if strcmp(param.([k '_name']),name), key=k; return; end
end
end

function v=getNumber(s,key,fallback)
v=fallback;
if ~isfield(s,key) || isempty(s.(key)), return; end
v=s.(key);
if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v) || v<0 || v~=round(v) ...
        || (endsWith(key,'Frame') && v<1)
    error('computeMetrics:InvalidAcquisitionCadence','%s must be an integer (%g or greater).',key,double(endsWith(key,'Frame')));
end
end

function [period,source]=metadataPeriod(f,name)
period=1; source='unavailable';
if isempty(f) || ~isa(f,'fov') || ~f.isOMEZarr, return; end
k=find(strcmp(f.channel,name),1);
if isempty(k) || k>numel(f.omeZarrChannelIndices), return; end
p=fullfile(f.omeZarrPath,char(string(f.omeZarrSeries)),'zarr.json');
if ~isfile(p), return; end
% Reuse series metadata across the ROIs, invalidating on file replacement.
persistent cachedPath cachedStamp cachedJson
info=dir(p); stamp=[info.datenum info.bytes];
if isempty(cachedPath) || ~strcmp(cachedPath,p) || ~isequal(stamp,cachedStamp)
    cachedJson=jsondecode(fileread(p)); cachedPath=p; cachedStamp=stamp;
end
try
    seq=cachedJson.attributes.pymmcore_plus.summary_metadata.mda_sequence.channels;
    c=f.omeZarrChannelIndices(k)+1;
    if iscell(seq), ch=seq{c}; else, ch=seq(c); end
    % Verify mapping against the channel name as well as its C index.
    base=regexprep(name,'_z\d+$','');
    if ~strcmp(base,ch.config), return; end
    if ~isfield(ch,'acquire_every'), return; end
    period=getNumber(struct('period',ch.acquire_every),'period',1);
    if period<1, period=1; end
    source='pymmcore_plus.mda_sequence.acquire_every';
catch ME
    if strcmp(ME.identifier,'computeMetrics:InvalidAcquisitionCadence'), rethrow(ME); end
    % Other writers need an explicit cadence; never guess from cell zeros.
end
end
