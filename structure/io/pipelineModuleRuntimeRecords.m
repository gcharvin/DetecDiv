function records = pipelineModuleRuntimeRecords(ctx)
%PIPELINEMODULERUNTIMERECORDS Serializable trace for completed/failed prepares.
records=struct([]);
if ~isstruct(ctx), return; end
if isfield(ctx,'moduleRuntimeCache')&&isa(ctx.moduleRuntimeCache,'containers.Map')
    values=ctx.moduleRuntimeCache.values;
    if ~isempty(values), records=[values{:}]; end
elseif isfield(ctx,'moduleRuntime')&&isstruct(ctx.moduleRuntime)
    records=ctx.moduleRuntime;
end
end
