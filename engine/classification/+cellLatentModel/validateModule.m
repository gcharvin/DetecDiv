function diagnostics = validateModule(params)
%VALIDATEMODULE Validate supplied controls without data or artifact access.
if nargin < 1 || isempty(params), params = struct(); end
diagnostics = repmat(struct('severity','','code','','message','','parameter',''),0,1);
if ~isstruct(params) || ~isscalar(params)
    add('InvalidParameters','Module parameters must be one struct.','');
    return;
end
backend = lower(text(params,'backend'));
backend = strrep(strrep(backend,'-','_'),' ','_');
checkChoice('backend',{'legacy','relation_ensemble','relationensemble', ...
    'temporal_lineage','continuous_cell_state','continuouscellstate', ...
    'causal_composite','causalcomposite','composite','cell_latent_composite'});
checkChoice('modelUpdatePolicy',{'pinned','follow_promoted'});
checkChoice('device',{'auto','cuda','cpu'});
checkChoice('primaryStateAxis',{'none','budding'});
checkChoice('stateUpdateMode',{'none','promoted_frozen_bf'});
if any(strcmp(backend,{'temporal_lineage'}))
    checkChoice('temporalVariant',{'temporal_geometry','all_observed'});
end
if isfield(params,'frameIntervalMinutes') && ~isempty(params.frameIntervalMinutes)
    raw = params.frameIntervalMinutes;
    while iscell(raw) && ~isempty(raw), raw = raw{end}; end
    if ischar(raw) || isstring(raw)
        if strlength(strtrim(string(raw))) == 0, raw = []; else, raw = str2double(raw); end
    end
    if ~isempty(raw) && (~isnumeric(raw) || ~isscalar(raw) || ...
            ~isreal(raw) || ~isfinite(raw) || raw <= 0)
        add('InvalidFrameInterval','frameIntervalMinutes must be a positive finite scalar.', ...
            'frameIntervalMinutes');
    end
end
    function checkChoice(key,allowed)
        value = lower(text(params,key));
        if strcmp(key,'backend'), value = backend; end
        if ~isempty(value) && ~any(strcmp(value,allowed))
            add('InvalidParameterChoice', ...
                sprintf('%s must be one of: %s.',key,strjoin(allowed,', ')),key);
        end
    end
    function add(code,message,parameter)
        diagnostics(end+1,1) = struct('severity','error','code',code, ...
            'message',message,'parameter',parameter);
    end
end

function value = text(source,key)
value = '';
if ~isfield(source,key), return; end
raw = source.(key);
while iscell(raw)
    if isempty(raw), return; end
    raw = raw{end};
end
if ~isempty(raw), value = strtrim(char(string(raw))); end
end
