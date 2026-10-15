function plan = detecdiv_local_plan_fov_pool(payload, project, cluster, limits)
%DETECDIV_LOCAL_PLAN_FOV_POOL Reserve a batch pool only for local ROI extraction.
% limits optionally supplies measured resource ceilings for deterministic tests.
% AvailableBytes is usable physical RAM, already including the safety reserve.
if nargin<4,limits=struct();end
plan=struct('poolWorkers',0,'fovCount',0,'cpuCores',0,'cpuLimit',0, ...
    'clusterLimit',0,'memoryLimit',0,'availableBytes',0, ...
    'coordinatorBytes',0,'peakBytesPerFov',0,'reason','not_local', ...
    'nodeIds',{{}});
if ~strcmpi(text(getfielddefault(payload,'execution',struct()),'requested_mode',''),'local_process')
    return;
end
plan.reason='no_parallel_extraction';
[pipe,msg]=pipelineLoad(payload.pipeline_ref.pipeline_json_path);
assert(~isempty(pipe),'detecdiv_local_plan_fov_pool:PipelineLoad','%s',msg);
request=getfielddefault(payload,'run_request',struct());
nodes=pipelineApplyRunNodeParams(pipe.nodes,getfielddefault(request,'node_params',struct()));
selected=cellstr(string(getfielddefault(request,'selected_nodes',{})));
active=false(1,numel(nodes));
for i=1:numel(nodes)
    node=nodes(i);
    active(i)=strcmpi(text(node,'type',''),'roiExtract') && ...
        (isempty(selected) || any(strcmp(selected,text(node,'id','')))) && ...
        logical(getfielddefault(node,'enabled',true));
    p=getfielddefault(node,'params',struct());
    if strcmpi(text(p,'executionMode','parallel'),'sequential'),active(i)=false;end
end
if ~any(active),return;end
if ~isa(project,'shallow')
    [project,msg]=shallowLoad(project);
    assert(~isempty(project),'detecdiv_local_plan_fov_pool:ProjectLoad','%s',msg);
end
fovs=project.fov;
% A raw-data run may not have imported its FOVs into the project yet. Probe
% the selected dataloader on a separate, memory-only project; never mutate
% the user's project merely to plan a local batch reservation.
for i=1:numel(nodes)
    node=nodes(i);
    if ~strcmpi(text(node,'type',''),'dataLoader') || ...
            (~isempty(selected) && ~any(strcmp(selected,text(node,'id','')))) || ...
            ~logical(getfielddefault(node,'enabled',true))
        continue;
    end
    loader=getfielddefault(node,'params',struct());
    if logical(getfielddefault(loader,'useExistingProjectSources',false)),continue;end
    if isempty(text(loader,'path','')),continue;end
    loader.write=false;loader.interactive=false;
    probe=struct('shallow',shallow(),'params',loader,'interactive',false, ...
        'io',struct('persistOutputs',false));
    try
        probe=dataLoader.process(probe);fovs=probe.fovList;
    catch ME
        plan.reason='raw_metadata_unavailable';
        warning('detecdiv_local_plan_fov_pool:RawMetadata', ...
            'Could not plan a local FOV pool from raw metadata: %s',ME.message);
        return;
    end
end
selection=getfielddefault(request,'selection',struct());
indices=getfielddefault(selection,'fovs',[]);
if isempty(indices),indices=1:numel(fovs);end
indices=unique(double(indices(:).'),'stable');
indices=indices(isfinite(indices) & indices>=1 & indices<=numel(fovs) & indices==floor(indices));
plan.fovCount=numel(indices);
if plan.fovCount<2,plan.reason='single_fov';return;end
peak=0;baseline=0;available=inf;
for i=find(active)
    p=roiExtract.setparam(struct());
    overrides=getfielddefault(nodes(i),'params',struct());names=fieldnames(overrides);
    for k=1:numel(names),p.(names{k})=overrides.(names{k});end
    [~,estimate]=roiExtract.planFovWorkers(fovs(indices),p,10);
    if ~estimate.known,plan.reason='unknown_memory_footprint';return;end
    peak=max(peak,estimate.peakBytes);baseline=max(baseline,estimate.baselineBytes);
    available=min(available,estimate.availableBytes);
    plan.nodeIds{end+1}=text(nodes(i),'id','');
end
cores=feature('numcores');
try,cores=min(cores,maxNumCompThreads);catch,end
cores=getfielddefault(limits,'CpuCores',cores);
plan.cpuCores=max(1,floor(double(cores)));
% One CPU slot and one MATLAB baseline remain for the batch coordinator.
plan.cpuLimit=max(0,plan.cpuCores-1);
plan.clusterLimit=max(0,double(cluster.NumWorkers)-1);
plan.availableBytes=max(0,double(getfielddefault(limits,'AvailableBytes',available)));
plan.coordinatorBytes=double(getfielddefault(limits,'CoordinatorBytes',baseline));
plan.peakBytesPerFov=peak;
plan.memoryLimit=max(0,floor((plan.availableBytes-plan.coordinatorBytes)/peak));
cap=double(getfielddefault(limits,'MaxPoolWorkers',10));
count=floor(min([10 plan.fovCount plan.cpuLimit plan.clusterLimit plan.memoryLimit cap]));
if count<2
    plan.reason='resource_limit';
else
    plan.poolWorkers=count;plan.reason='parallel_fovs';
end
end

function value=getfielddefault(s,name,fallback)
value=fallback;if isstruct(s) && isfield(s,name) && ~isempty(s.(name)),value=s.(name);end
end

function value=text(s,name,fallback)
value=char(string(getfielddefault(s,name,fallback)));
end
