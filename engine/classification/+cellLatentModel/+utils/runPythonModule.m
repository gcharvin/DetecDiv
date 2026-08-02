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
try
    [status,output] = system(cmd,'-echo');
catch
    [status,output] = system(cmd);
end
if ~isempty(stdoutPath)
    fid = fopen(stdoutPath,'w');
    if fid >= 0
        cleanup = onCleanup(@() fclose(fid));
        fwrite(fid,output,'char');
        clear cleanup;
    end
end
runtime.command = cmd;
runtime.status = status;
runtime.stdout = stdoutPath;
if status ~= 0
    error('cellLatentModel:ExternalModelFailed', ...
        'cell_latent_model failed (%d):%s%s',status,newline,output);
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
