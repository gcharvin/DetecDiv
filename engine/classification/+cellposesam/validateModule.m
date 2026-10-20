function diagnostics = validateModule(params)
%VALIDATEMODULE Inspect configured values without a Python or model runtime.
if nargin < 1 || isempty(params), params = struct(); end
diagnostics = repmat(struct('severity','','code','','message','','parameter',''),0,1);
if ~isstruct(params) || ~isscalar(params)
    add('error','InvalidParameters','Module parameters must be one struct.','');
    return;
end
if isfield(params,'outputType') && ~isempty(params.outputType)
    mode = choice(params.outputType);
elseif isfield(params,'outputMode')
    mode = choice(params.outputMode);
else
    mode = '';
end
if ~isempty(mode) && ~any(strcmpi(mode, ...
        {'segmentation','proba','probability','both','postprocessing'}))
    add('warning','LegacyOutputModeFallback', ...
        'The historical execution fallback will use segmentation for this output mode.', ...
        'outputType');
end
names = {'diameter','flow_threshold','cell_prob_threshold','min_size'};
for i = 1:numel(names)
    name = names{i};
    if ~isfield(params,name) || isempty(params.(name)), continue; end
    raw = params.(name);
    while iscell(raw) && ~isempty(raw), raw = raw{end}; end
    if isempty(raw), continue; end
    % The Python runner's to_float accepts numeric text and unset tokens.
    % min_size is rounded in MATLAB before Python and keeps that behavior.
    if ~strcmp(name,'min_size') && ...
            ((ischar(raw) && isrow(raw)) || (isstring(raw) && isscalar(raw)))
        token = lower(strtrim(char(string(raw))));
        if any(strcmp(token,{'','nan','none','null'})), continue; end
        numeric = str2double(token);
        if ~isnan(numeric), raw = numeric; end
    end
    if ~isnumeric(raw) || ~isscalar(raw) || ~isreal(raw) || ...
            (~isfinite(raw) && ~(strcmp(name,'diameter') && isnan(raw)))
        add('error','InvalidNumericParameter', ...
            [name ' must be a real scalar (numeric text is supported by Python).'],name);
    end
end
    function add(severity,code,message,parameter)
        diagnostics(end+1,1) = struct('severity',severity,'code',code, ...
            'message',message,'parameter',parameter);
    end
end

function value = choice(value)
while iscell(value)
    if isempty(value), value = ''; return; end
    value = value{end};
end
value = strtrim(char(string(value)));
end
