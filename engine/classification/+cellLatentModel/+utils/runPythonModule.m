function runtime = runPythonModule(command,configPath,ctx,stdoutPath)
%CELLLATENTMODEL.UTILS.RUNPYTHONMODULE Run the external package CLI.
if nargin < 3, ctx = struct(); end
if nargin < 4, stdoutPath = ''; end
runtime = cellLatentModel.utils.resolvePythonRuntime(ctx);
pythonExe = char(string(runtime.pythonExecutable));
repoRoot = char(string(runtime.repositoryRoot));
lineageRepoRoot = char(string(runtime.lineageRepositoryRoot));
moduleArgs = sprintf('-u -m cell_latent_model %s --config %s', ...
    char(string(command)),quoteArg(configPath));
sourceRoots = {};
if ~isempty(repoRoot), sourceRoots{end+1} = fullfile(repoRoot,'src'); end
if ~isempty(lineageRepoRoot)
    sourceRoots{end+1} = fullfile(lineageRepoRoot,'src');
end
if ispc
    if isempty(sourceRoots)
        cmd = sprintf('"%s" %s 2>&1',pythonExe,moduleArgs);
    else
        sourceRoot = strjoin(sourceRoots,';');
        cmd = sprintf(['set "PYTHONPATH=%s;%%PYTHONPATH%%" && ' ...
            '"%s" %s 2>&1'],sourceRoot,pythonExe,moduleArgs);
    end
else
    if isempty(sourceRoots)
        cmd = sprintf('%s %s 2>&1',shellQuote(pythonExe),moduleArgs);
    else
        sourceRoot = strjoin(sourceRoots,':');
        cmd = sprintf('PYTHONPATH=%s:$PYTHONPATH %s %s 2>&1', ...
            shellQuote(sourceRoot),shellQuote(pythonExe),moduleArgs);
    end
end
processArgs = {pythonExe,'-u','-m','cell_latent_model', ...
    char(string(command)),'--config',char(string(configPath))};
[status,output] = runStreamingProcess( ...
    processArgs,sourceRoots,ctx,stdoutPath);
runtime.command = cmd;
runtime.status = status;
runtime.stdout = stdoutPath;
if status ~= 0
    error('cellLatentModel:ExternalModelFailed', ...
        'cell_latent_model failed (%d):%s%s',status,newline,output);
end
end

function [status,output] = runStreamingProcess( ...
        processArgs,sourceRoots,ctx,stdoutPath)
% Read the child pipe ourselves. MATLAB system() can buffer worker output
% until process exit even with -echo, leaving pipeline monitoring silent.
javaArgs = javaArray('java.lang.String',numel(processArgs));
for i = 1:numel(processArgs)
    javaArgs(i) = javaObject('java.lang.String',char(string(processArgs{i})));
end
builder = javaObject('java.lang.ProcessBuilder',javaArgs);
builder.redirectErrorStream(true);
if ~isempty(sourceRoots)
    environment = builder.environment();
    sourceRoot = strjoin(sourceRoots,pathsep);
    inherited = environment.get('PYTHONPATH');
    if ~isempty(inherited)
        inherited = char(inherited);
        if ~isempty(inherited), sourceRoot = [sourceRoot pathsep inherited]; end
    end
    environment.put('PYTHONPATH',sourceRoot);
end

stdoutFid = -1;
if ~isempty(stdoutPath)
    stdoutFolder = fileparts(stdoutPath);
    if ~isempty(stdoutFolder) && exist(stdoutFolder,'dir') ~= 7
        mkdir(stdoutFolder);
    end
    stdoutFid = fopen(stdoutPath,'w');
end
stdoutCleanup = onCleanup(@() closeFile(stdoutFid));
process = builder.start();
processCleanup = onCleanup(@() stopProcess(process));
reader = javaObject('java.io.BufferedReader',javaObject( ...
    'java.io.InputStreamReader',process.getInputStream()));
readerCleanup = onCleanup(@() closeReader(reader));
lines = {};

while process.isAlive()
    readAvailableLines();
    if exist('detecdiv_check_cancel','file') == 2
        detecdiv_check_cancel(ctx,'cellLatentModel Python process');
    end
    pause(0.05);
end
while true
    javaLine = reader.readLine();
    if isempty(javaLine), break; end
    relayLine(char(javaLine));
end
status = double(process.waitFor());
output = strjoin(lines,newline);
if ~isempty(lines), output = [output newline]; end
clear readerCleanup processCleanup stdoutCleanup;

    function readAvailableLines()
        while reader.ready()
            javaLine = reader.readLine();
            if isempty(javaLine), return; end
            relayLine(char(javaLine));
        end
    end

    function relayLine(lineText)
        lines{end+1} = lineText; %#ok<AGROW>
        if stdoutFid >= 0
            fprintf(stdoutFid,'%s\n',lineText);
        end
        if relayProgress(lineText,ctx)
            return;
        end
        fprintf(1,'%s\n',lineText);
        try, drawnow limitrate; catch, end
    end
end

function handled = relayProgress(lineText,ctx)
handled = false;
marker = '@@DETECDIV_PROGRESS@@';
trimmed = strtrim(lineText);
if ~startsWith(trimmed,marker), return; end
try
    payload = jsondecode(char(strtrim(extractAfter( ...
        string(trimmed),strlength(marker)))));
    localValue = fieldValue(payload,'localValue', ...
        fieldValue(payload,'value',0));
    mapped = detecdiv_progress(ctx,localValue, ...
        fieldValue(payload,'message',''), ...
        'Scope',fieldValue(payload,'scope','training'), ...
        'Current',fieldValue(payload,'current',[]), ...
        'Total',fieldValue(payload,'total',[]), ...
        'Status',fieldValue(payload,'status','running'), ...
        'Indeterminate',logical(fieldValue(payload,'indeterminate',false)));
    handled = isstruct(mapped) && ~isempty(fieldnames(mapped));
catch
    handled = false;
end
end

function value = fieldValue(source,name,fallback)
value = fallback;
try
    if isstruct(source) && isfield(source,name) && ~isempty(source.(name))
        value = source.(name);
    end
catch
    value = fallback;
end
end

function closeFile(fid)
if fid >= 0
    try, fclose(fid); catch, end
end
end

function closeReader(reader)
try, reader.close(); catch, end
end

function stopProcess(process)
try
    if process.isAlive()
        process.destroy();
        pause(0.1);
    end
    if process.isAlive(), process.destroyForcibly(); end
catch
end
end

function value = quoteArg(raw)
if ispc
    value = ['"' char(string(raw)) '"'];
else
    value = shellQuote(raw);
end
end

function value = shellQuote(raw)
value = ['''' strrep(char(string(raw)),'''','''"''"''') ''''];
end
