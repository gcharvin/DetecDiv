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
    encodingPrefix = ['set "PYTHONUTF8=1" && ' ...
        'set "PYTHONIOENCODING=utf-8" && '];
    if isempty(sourceRoots)
        cmd = sprintf('%s"%s" %s 2>&1', ...
            encodingPrefix,pythonExe,moduleArgs);
    else
        sourceRoot = strjoin(sourceRoots,';');
        cmd = sprintf([encodingPrefix ...
            'set "PYTHONPATH=%s;%%PYTHONPATH%%" && ' ...
            '"%s" %s 2>&1'],sourceRoot,pythonExe,moduleArgs);
    end
else
    encodingPrefix = 'PYTHONUTF8=1 PYTHONIOENCODING=utf-8 ';
    if isempty(sourceRoots)
        cmd = sprintf('%s%s %s 2>&1', ...
            encodingPrefix,shellQuote(pythonExe),moduleArgs);
    else
        sourceRoot = strjoin(sourceRoots,':');
        cmd = sprintf('%sPYTHONPATH=%s:$PYTHONPATH %s %s 2>&1', ...
            encodingPrefix,shellQuote(sourceRoot), ...
            shellQuote(pythonExe),moduleArgs);
    end
end
processArgs = {pythonExe,'-u','-m','cell_latent_model', ...
    char(string(command)),'--config',char(string(configPath))};
[status,output] = runStreamingProcess( ...
    processArgs,sourceRoots,ctx,stdoutPath,'w');
runtime.command = cmd;
runtime.status = status;
runtime.stdout = stdoutPath;
runtime.windowsAppControl = struct( ...
    'detected',false, ...
    'retryCount',0, ...
    'blockedModule','', ...
    'blockedFile','');

appControl = cellLatentModel.utils.inspectPythonAppControlFailure( ...
    status,output);
if ispc && appControl.retryable
    retryDelaySeconds = 0.5;
    target = blockedTarget(appControl);
    notice = sprintf(['Windows Smart App Control blocked an unsigned or ' ...
        'untrusted Python binary%s during CLI startup. Retrying once in ' ...
        '%.1f s; the scientific command has not run yet.'], ...
        target,retryDelaySeconds);
    emitRetryNotice(ctx,stdoutPath,notice);
    pause(retryDelaySeconds);

    firstStatus = status;
    firstOutput = output;
    [status,output] = runStreamingProcess( ...
        processArgs,sourceRoots,ctx,stdoutPath,'a');
    runtime.status = status;
    runtime.windowsAppControl = struct( ...
        'detected',true, ...
        'retryCount',1, ...
        'blockedModule',appControl.blockedModule, ...
        'blockedFile',appControl.blockedFile);

    if status ~= 0
        retryAppControl = ...
            cellLatentModel.utils.inspectPythonAppControlFailure( ...
            status,output);
        throwRetryFailure(firstStatus,firstOutput,status,output, ...
            appControl,retryAppControl,stdoutPath);
    end
end
if status ~= 0
    error('cellLatentModel:ExternalModelFailed', ...
        'cell_latent_model failed (%d):%s%s',status,newline,output);
end
end

function [status,output] = runStreamingProcess( ...
        processArgs,sourceRoots,ctx,stdoutPath,stdoutMode)
% Read the child pipe ourselves. MATLAB system() can buffer worker output
% until process exit even with -echo, leaving pipeline monitoring silent.
if nargin < 5 || isempty(stdoutMode), stdoutMode = 'w'; end
javaArgs = javaArray('java.lang.String',numel(processArgs));
for i = 1:numel(processArgs)
    javaArgs(i) = javaObject('java.lang.String',char(string(processArgs{i})));
end
builder = javaObject('java.lang.ProcessBuilder',javaArgs);
builder.redirectErrorStream(true);
environment = builder.environment();
% Keep Python and the Java pipe on one explicit encoding. This prevents
% localized Windows loader diagnostics from becoming mojibake in the run log.
environment.put('PYTHONUTF8','1');
environment.put('PYTHONIOENCODING','utf-8');
if ~isempty(sourceRoots)
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
    stdoutFid = fopen(stdoutPath,stdoutMode,'n','UTF-8');
end
stdoutCleanup = onCleanup(@() closeFile(stdoutFid));
process = builder.start();
processCleanup = onCleanup(@() stopProcess(process));
reader = javaObject('java.io.BufferedReader',javaObject( ...
    'java.io.InputStreamReader',process.getInputStream(), ...
    javaObject('java.lang.String','UTF-8')));
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
        lines{end+1} = lineText;
        if stdoutFid >= 0
            fprintf(stdoutFid,'%s\n',lineText);
        end
        if relayProgress(lineText,ctx)
            return;
        end
        fprintf(1,'%s\n',lineText);
        try
            drawnow limitrate;
        catch
        end
    end
end

function emitRetryNotice(ctx,stdoutPath,message)
line = ['[WARN] ' char(string(message))];
fprintf(1,'%s\n',line);
appendLogLine(stdoutPath,line);
try
    detecdiv_progress(ctx,0,message, ...
        'Scope','runtime', ...
        'Status','running', ...
        'Indeterminate',true);
catch
end
try
    drawnow limitrate;
catch
end
end

function appendLogLine(stdoutPath,line)
if isempty(stdoutPath), return; end
fid = -1;
try
    fid = fopen(stdoutPath,'a','n','UTF-8');
    if fid >= 0, fprintf(fid,'%s\n',line); end
catch
end
closeFile(fid);
end

function suffix = blockedTarget(info)
suffix = '';
if ~isempty(info.blockedFile)
    suffix = sprintf(' (%s)',info.blockedFile);
elseif ~isempty(info.blockedModule)
    suffix = sprintf(' (Python module %s)',info.blockedModule);
end
end

function throwRetryFailure(firstStatus,firstOutput,status,output, ...
        firstInfo,retryInfo,stdoutPath)
target = blockedTarget(firstInfo);
if retryInfo.retryable
    outcome = ['Windows Smart App Control blocked Python CLI startup on ' ...
        'both attempts'];
else
    outcome = ['Windows Smart App Control blocked the first Python CLI ' ...
        'startup, and the single automatic retry then failed'];
end
logHint = '';
if ~isempty(stdoutPath)
    logHint = sprintf(' Full attempt output was kept in "%s".',stdoutPath);
end
header = sprintf([ ...
    '%s%s. No further retry was attempted. Keep Windows security enabled; ' ...
    'review the reported Python/SciPy binary in Windows Security, retry ' ...
    'later, and reinstall detecdiv_python only if an integrity check shows ' ...
    'that the binary is missing or damaged.%s'], ...
    outcome,target,logHint);
details = sprintf([ ...
    '%s%s--- attempt 1 (status %d; Smart App Control) ---%s%s' ...
    '--- attempt 2 (status %d) ---%s%s'], ...
    header,newline,firstStatus,newline,firstOutput,status,newline,output);
error('cellLatentModel:ExternalModelFailed', '%s',details);
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
    try
        fclose(fid);
    catch
    end
end
end

function closeReader(reader)
try
    reader.close();
catch
end
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
