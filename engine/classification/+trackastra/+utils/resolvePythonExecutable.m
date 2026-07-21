function exe = resolvePythonExecutable(explicitValue, ctx)
% trackastra.utils.resolvePythonExecutable  Find a Python containing Trackastra.

if nargin < 1, explicitValue = ''; end
if nargin < 2 || isempty(ctx), ctx = struct(); end
candidates = {};
explicit = scalarText(explicitValue);
if ~isempty(explicit), candidates{end+1} = explicit; end %#ok<AGROW>

try
    if isfield(ctx,'exec') && isstruct(ctx.exec) && isfield(ctx.exec,'python') && ...
            isstruct(ctx.exec.python) && isfield(ctx.exec.python,'executable')
        value = scalarText(ctx.exec.python.executable);
        if ~isempty(value), candidates{end+1} = value; end %#ok<AGROW>
    end
catch
end

try
    value = scalarText(pyenv().Executable);
    if ~isempty(value), candidates{end+1} = value; end %#ok<AGROW>
catch
end

profile = getenv('USERPROFILE');
if ~isempty(profile)
    candidates{end+1} = fullfile(profile,'.conda','envs','detecdiv_python','python.exe'); %#ok<AGROW>
    candidates{end+1} = fullfile(profile,'.conda','envs','detecdiv-python','python.exe'); %#ok<AGROW>
end
candidates = unique(candidates,'stable');

for i = 1:numel(candidates)
    candidate = candidates{i};
    if exist(candidate,'file') == 2 && hasTrackastra(candidate)
        exe = candidate;
        return;
    end
end

if ~isempty(explicit)
    error('trackastra:PythonMissingPackage', ...
        'Configured Python does not provide Trackastra: %s', explicit);
end
error('trackastra:PythonNotConfigured', ...
    ['No Python executable containing Trackastra was found. Configure MATLAB pyenv ' ...
     'or set pythonExecutable to the detecdiv_python executable.']);
end

function tf = hasTrackastra(exe)
persistent checkedPaths checkedValues
if isempty(checkedPaths), checkedPaths = {}; checkedValues = false(1,0); end
hit = find(strcmpi(checkedPaths,exe),1);
if ~isempty(hit), tf = checkedValues(hit); return; end
cmd = sprintf('"%s" -c "import trackastra"',exe);
[status,~] = system(cmd);
tf = status == 0;
checkedPaths{end+1} = exe; %#ok<AGROW>
checkedValues(end+1) = tf; %#ok<AGROW>
end

function txt = scalarText(value)
while iscell(value)
    value = value(~cellfun(@isempty,value));
    if isempty(value), txt = ''; return; end
    value = value{end};
end
txt = strtrim(char(string(value)));
end
