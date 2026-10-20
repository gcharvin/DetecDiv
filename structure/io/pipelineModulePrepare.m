function [ctx,record] = pipelineModulePrepare(pkg,classif,ctx)
%PIPELINEMODULEPREPARE Validate/pin one module selection per node and run.
% Preparation only reads explicit artifacts. Legacy adapters retain execution.
if nargin<3||~isstruct(ctx), ctx=struct(); end
pkg=char(string(pkg));
classifierId=''; classifierPath='';
try, classifierId=char(string(classif.strid)); catch, end
try, classifierPath=char(string(classif.path)); catch, end
nodeId=classifierId;
if isfield(ctx,'pipeline')&&isstruct(ctx.pipeline)
    nodeId=field(ctx.pipeline,'nodeId',field(ctx.pipeline,'currentNode',nodeId));
end
runId=char(string(field(ctx,'runId','')));
if ~isfield(ctx,'moduleRuntimeCache')||~isa(ctx.moduleRuntimeCache,'containers.Map')
    ctx.moduleRuntimeCache=containers.Map('KeyType','char','ValueType','any');
end
% Lookup before calling any hook: mutable pointers cannot be followed per ROI.
key=jsonencode({runId,nodeId,pkg,classifierPath,classifierId});
if isKey(ctx.moduleRuntimeCache,key)
    record=ctx.moduleRuntimeCache(key);
    selected=which([pkg '.classify']);
    sameAdapter=strcmp(selected,record.provenance.adapter.path);
    if ispc, sameAdapter=strcmpi(selected,record.provenance.adapter.path); end
    if ~sameAdapter
        error('pipelineModulePrepare:AdapterChanged','Selected adapter changed during run for %s.',pkg);
    end
    ctx=attach(ctx,record);
    assertReady(record);
    return;
end
record=struct('format','detecdiv.module_runtime.v1','moduleId',['legacy.classifier.' pkg], ...
    'package',pkg,'classifierId',classifierId,'nodeId',char(string(nodeId)), ...
    'runId',runId,'preparedAt',char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")), ...
    'status','legacy','parameters',field(ctx,'params',struct()), ...
    'diagnostics',pipelineModuleDiagnostics([]), 'provenance',struct(), 'context',struct());
record.provenance.adapter=pipelineModuleCodeIdentity(which([pkg '.classify']));
record.provenance.detecdiv=pipelineModuleCodeIdentity([mfilename('fullpath') '.m']);
% A legacy adapter cannot expose effective defaults through this protocol.
% Keep requested values separate rather than claiming they are effective.
record.requestedParameters=record.parameters;
record.parameters=struct();
record.executionParameters=struct('at',{},'roiId',{},'parameters',{});
try
    hooks=pipelineModuleHooks(pkg);
    record.moduleId=hooks.moduleId;
    record.provenance.descriptor=pipelineModuleFileIdentity(hooks.manifestPath);
    if hooks.supported
        record.package=hooks.package;
        record.provenance.validation=pipelineModuleFileIdentity(which(hooks.validate));
        record.provenance.preparation=pipelineModuleFileIdentity(which(hooks.prepare));
        preparationCtx=ctx;
        if isfield(preparationCtx,'moduleRuntime')
            preparationCtx=rmfield(preparationCtx,'moduleRuntime');
        end
        prepared=feval(hooks.prepare,classif,preparationCtx);
        validatePrepared(prepared,hooks.prepare);
        record.parameters=prepared.parameters;
        record.context=prepared.context;
        names=fieldnames(prepared.provenance);
        for i=1:numel(names)
            if ismember(names{i},{'adapter','detecdiv','descriptor','validation','preparation'})
                error('pipelineModulePrepare:Result','Package provenance cannot replace common code identities.');
            end
            record.provenance.(names{i})=prepared.provenance.(names{i});
        end
        record.diagnostics=pipelineModuleDiagnostics(prepared.diagnostics,nodeId);
        record.status='ready';
        if any(strcmp({record.diagnostics.severity},'error')), record.status='failed'; end
    else
        record.diagnostics=pipelineModuleDiagnostics(struct('severity','info', ...
            'code','pipelineModulePrepare:LegacyAdapter','message', ...
            'This selected adapter has no runtime hooks; native execution checks remain authoritative.', ...
            'parameter',''),nodeId);
    end
catch ME
    record.status='failed';
    code=ME.identifier; if isempty(code), code='pipelineModulePrepare:HookFailed'; end
    record.diagnostics=pipelineModuleDiagnostics(struct('severity','error','code',code, ...
        'message',ME.message,'parameter',''),nodeId);
end
ctx.moduleRuntimeCache(key)=record;
ctx=attach(ctx,record);
pipelineRunEvent(ctx,'module_prepared','NodeId',nodeId,'ModuleRuntime',record);
assertReady(record);
end

function ctx=attach(ctx,record)
ctx.moduleRuntime=record;
% Only validated infrastructure selections are overlaid. Effective model
% parameters stay in the pin; caller parameters retain their ownership.
names=fieldnames(record.context);
for i=1:numel(names), ctx.(names{i})=record.context.(names{i}); end
end

function validatePrepared(value,entrypoint)
required={'format','parameters','diagnostics','provenance','context'};
if ~isstruct(value)||~isscalar(value)||~all(isfield(value,required))|| ...
        ~isequal(value.format,'detecdiv.module_runtime.v1')
    error('pipelineModulePrepare:Result','%s must return detecdiv.module_runtime.v1.',entrypoint);
end
for key={'parameters','provenance','context'}
    if ~isstruct(value.(key{1}))||~isscalar(value.(key{1}))
        error('pipelineModulePrepare:Result','%s.%s must be a scalar structure.',entrypoint,key{1});
    end
end
pipelineModuleDiagnostics(value.diagnostics);
blocked={'params','classifier','pipeline','run','runId','moduleRuntime', ...
    'moduleRuntimeCache','io','store','names','sel','exec','cancel','progress', ...
    'progressCallback','roiList','fovList','shallow','shallowObj'};
if any(ismember(fieldnames(value.context),blocked))
    error('pipelineModulePrepare:Context','Runtime hook attempted to replace execution context ownership.');
end
end

function assertReady(record)
if strcmp(record.status,'failed')
    errors=record.diagnostics(strcmp({record.diagnostics.severity},'error'));
    error('pipelineModulePrepare:Failed','Module %s validation failed: %s', ...
        record.package,strjoin({errors.message},' | '));
end
end

function value=field(source,key,fallback)
value=fallback;
if isstruct(source)&&isscalar(source)&&isfield(source,key), value=source.(key); end
end
