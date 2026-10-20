function [diagnostics,records] = pipelineModuleValidation(nodes,ctx)
%PIPELINEMODULEVALIDATION Pure configuration checks shared by GUI and batch.
% Does not inspect model files, select Python, import packages or change paths.
if nargin<2, ctx=struct(); end %#ok<NASGU>
diagnostics=pipelineModuleDiagnostics([]);
records=struct('nodeId',{},'package',{},'moduleId',{},'diagnostics',{});
for i=1:numel(nodes)
    node=nodes(i);
    if ~strcmpi(field(node,'type',''),'classifier'), continue; end
    params=field(node,'params',struct()); pkg=field(node,'pkg','');
    if isstruct(params)&&isfield(params,'pkg')&&~isempty(params.pkg), pkg=params.pkg; end
    if isempty(pkg), continue; end
    nodeId=field(node,'id',''); moduleId='';
    try
        hooks=pipelineModuleHooks(pkg);
        if ~hooks.supported, continue; end
        moduleId=hooks.moduleId;
        d=pipelineModuleDiagnostics(feval(hooks.validate,params),nodeId);
    catch ME
        d=pipelineModuleDiagnostics(struct('severity','error','code',ME.identifier, ...
            'message',ME.message,'parameter',''),nodeId);
    end
    records(end+1)=struct('nodeId',char(string(nodeId)),'package',char(string(pkg)), ...
        'moduleId',moduleId,'diagnostics',d); %#ok<AGROW>
    diagnostics=[diagnostics d]; %#ok<AGROW>
end
end

function value=field(source,key,fallback)
value=fallback;
if isstruct(source)&&isscalar(source)&&isfield(source,key), value=source.(key); end
end
