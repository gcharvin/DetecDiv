function [channel,audit] = resolveFrameLocalInstanceChannel( ...
        classif,requested,groundTruthChannel,ctx)
%RESOLVEFRAMELOCALINSTANCECHANNEL Resolve a composite inference mask input.
%
% The reviewed tracking channel is a training target.  It must never become
% the runtime instance input merely because an older classifier used one
% channel for both roles.  Explicit, distinct inputs remain authoritative;
% otherwise a persisted segmentation provider is selected conservatively.

if nargin < 4 || isempty(ctx),ctx=struct();end
requested=textValue(requested);
groundTruthChannel=textValue(groundTruthChannel);
audit=struct('requested',requested,'ground_truth',groundTruthChannel, ...
    'resolved','','source','none','migrated_from_ground_truth',false);

if isUsable(requested,groundTruthChannel)
    channel=requested;
    audit.resolved=channel;
    audit.source='explicit';
    return;
end
audit.migrated_from_ground_truth=~isempty(requested) && ...
    strcmpi(requested,groundTruthChannel);

% A concrete pipeline/resource binding has precedence over classifier
% history.  It is provenance supplied by the graph, not a guessed GT input.
runtime=fieldText(ctx,{'params','instanceChannelName'});
if isUsable(runtime,groundTruthChannel)
    channel=runtime;
    audit.resolved=channel;
    audit.source='runtime_binding';
    return;
end

sources={ ...
    propertyFieldText(classif,'trainingParam','instanceChannelName'), ...
    propertyFieldText(classif,'executionParam','instanceChannelName')};
for i=1:numel(sources)
    if isUsable(sources{i},groundTruthChannel)
        channel=sources{i};
        audit.resolved=channel;
        audit.source='classifier_binding';
        return;
    end
end

[names,counts,familyProviders]=catalogCandidates(classif);
valid=~strcmpi(names,groundTruthChannel) & ...
    arrayfun(@isSegmentationLike,names);
names=names(valid);
counts=counts(valid);
familyProviders=familyProviders(valid);
if isempty(names)
    channel='';
    return;
end

% The canonical CellposeSAM output is deterministic and deliberately wins
% over generic mask-like names.  Remaining candidates prefer declared
% cell-model mask providers, then the widest ROI coverage.
canonical=find(strcmpi(names,'results_cellposeSAM_cell'),1);
if ~isempty(canonical)
    choice=canonical;
else
    score=100*double(familyProviders)+counts;
    cellpose=contains(lower(string(names)),'cellpose');
    sam=contains(lower(string(names)),'sam');
    score=score+50*double(cellpose)+20*double(sam);
    [~,choice]=max(score);
end
channel=names{choice};
audit.resolved=channel;
if familyProviders(choice)
    audit.source='cell_model_mask_provider';
else
    audit.source='indexed_segmentation_channel';
end
end

function [names,counts,familyProviders]=catalogCandidates(classif)
names={};counts=[];familyProviders=false(1,0);
try
    catalog=classifierBinding.catalog(classif);
catch
    return;
end
try
    rows=catalog.channels;
    for i=1:numel(rows)
        if double(rows(i).indexedRoiCount)<=0,continue;end
        names{end+1}=char(string(rows(i).name)); %#ok<AGROW>
        counts(end+1)=double(rows(i).indexedRoiCount); %#ok<AGROW>
        familyProviders(end+1)=false; %#ok<AGROW>
    end
catch
end
try
    families=catalog.families;
    for i=1:numel(families)
        provider=textValue(families(i).maskProvider);
        if isempty(provider),continue;end
        index=find(strcmpi(names,provider),1);
        if isempty(index)
            names{end+1}=provider; %#ok<AGROW>
            counts(end+1)=double(families(i).roiCount); %#ok<AGROW>
            familyProviders(end+1)=true; %#ok<AGROW>
        else
            counts(index)=max(counts(index),double(families(i).roiCount));
            familyProviders(index)=true;
        end
    end
catch
end
end

function tf=isSegmentationLike(value)
value=lower(textValue(value));
tf=contains(value,'cellpose') || contains(value,'sam') || ...
    contains(value,'segment') || contains(value,'instance') || ...
    contains(value,'_mask') || endsWith(value,'mask');
tf=tf && ~contains(value,'track') && ~contains(value,'lineage');
end

function tf=isUsable(value,groundTruthChannel)
value=textValue(value);
tf=~isempty(value) && ~any(strcmpi(value, ...
    {'<none>','<auto>','n/a'})) && ...
    (isempty(groundTruthChannel) || ~strcmpi(value,groundTruthChannel));
end

function value=propertyFieldText(obj,property,field)
value='';
try
    container=obj.(property);
    if isstruct(container)&&isfield(container,field)
        value=textValue(container.(field));
    end
catch
end
end

function value=fieldText(container,path)
value='';
try
    for i=1:numel(path)
        if ~isstruct(container)||~isfield(container,path{i}),return;end
        container=container.(path{i});
    end
    value=textValue(container);
catch
end
end

function value=textValue(value)
while iscell(value)
    if isempty(value),value='';return;end
    value=value{end};
end
value=strtrim(char(string(value)));
end
