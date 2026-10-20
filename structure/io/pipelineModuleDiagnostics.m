function diagnostics = pipelineModuleDiagnostics(raw,nodeId)
%PIPELINEMODULEDIAGNOSTICS Normalize the public module diagnostic contract.
if nargin<2, nodeId=''; end
diagnostics=struct('severity',{},'code',{},'message',{},'parameter',{},'nodeId',{});
if isempty(raw), return; end
if ~isstruct(raw) || ~all(isfield(raw,{'severity','code','message'}))
    error('pipelineModuleDiagnostics:Invalid','Module diagnostics must declare severity, code and message.');
end
for i=1:numel(raw)
    severity=lower(textValue(raw(i).severity));
    code=textValue(raw(i).code); message=textValue(raw(i).message);
    if ~any(strcmp(severity,{'error','warning','info'})) || isempty(code) || isempty(message)
        error('pipelineModuleDiagnostics:Invalid','Invalid module diagnostic severity, code or message.');
    end
    parameter='';
    if isfield(raw,'parameter'), parameter=textValue(raw(i).parameter); end
    diagnostics(end+1)=struct('severity',severity,'code',code,'message',message, ...
        'parameter',parameter,'nodeId',char(string(nodeId))); %#ok<AGROW>
end
end

function value=textValue(raw)
if ~(ischar(raw) && (isrow(raw)||isempty(raw))) && ~(isstring(raw)&&isscalar(raw))
    error('pipelineModuleDiagnostics:Invalid','Diagnostic values must be scalar text.');
end
value=char(raw);
end
