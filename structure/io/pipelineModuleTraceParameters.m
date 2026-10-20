function entry = pipelineModuleTraceParameters(ctx,parameters,roiId)
%PIPELINEMODULETRACEPARAMETERS Record ROI-normalized values before inference.
% The prepared deployment remains pinned; this is an additive observation.
entry=struct([]);
if nargin<3, roiId=''; end
if ~isstruct(ctx)||~isfield(ctx,'moduleRuntime')|| ...
        ~isstruct(ctx.moduleRuntime)||~isscalar(ctx.moduleRuntime)
    return;
end
record=ctx.moduleRuntime;
required={'format','status','moduleId','nodeId','package','classifierId'};
if ~all(isfield(record,required))|| ...
        ~strcmp(record.format,'detecdiv.module_runtime.v1')||~strcmp(record.status,'ready')
    return;
end
if ~isstruct(parameters)||~isscalar(parameters)
    error('pipelineModuleTraceParameters:Parameters','Normalized execution parameters must be a scalar structure.');
end
if isempty(roiId), roiId=''; else, roiId=char(string(roiId)); end
entry=struct('at',char(datetime('now','TimeZone','UTC','Format', ...
    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")), 'roiId',roiId,'parameters',parameters);
if isfield(ctx,'moduleRuntimeCache')&&isa(ctx.moduleRuntimeCache,'containers.Map')
    keys=ctx.moduleRuntimeCache.keys;
    for i=1:numel(keys)
        cached=ctx.moduleRuntimeCache(keys{i});
        if sameRecord(cached,record)
            if ~isfield(cached,'executionParameters'), cached.executionParameters=entry([]); end
            cached.executionParameters(end+1)=entry;
            ctx.moduleRuntimeCache(keys{i})=cached;
            break;
        end
    end
end
pipelineRunEvent(ctx,'module_execution_parameters','NodeId',record.nodeId, ...
    'ModuleId',record.moduleId,'Package',record.package, ...
    'ClassifierId',record.classifierId,'ExecutionParameters',entry);
end

function tf=sameRecord(a,b)
tf=isstruct(a)&&isscalar(a);
for key={'runId','nodeId','package','classifierId'}
    name=key{1};
    tf=tf&&isfield(a,name)&&isfield(b,name)&&isequal(a.(name),b.(name));
end
end
