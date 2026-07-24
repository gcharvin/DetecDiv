function runtime = runPythonModule(command, configPath, ctx, stdoutPath)
%BUDMOTHERLINKER.UTILS.RUNPYTHONMODULE Run the external package CLI.

if nargin < 3, ctx = struct(); end
if nargin < 4, stdoutPath = ''; end
runtime = budMotherLinker.utils.resolvePythonRuntime(ctx);
pythonExe = char(string(runtime.pythonExecutable));
repoRoot = char(string(runtime.repositoryRoot));
moduleArgs = sprintf('-u -m cell_lineage_linker %s --config %s', ...
    char(string(command)), quoteArg(configPath));

if ispc
    if isempty(repoRoot)
        cmd = sprintf('"%s" %s 2>&1', pythonExe, moduleArgs);
    else
        sourceRoot = fullfile(repoRoot, 'src');
        cmd = sprintf(['set "PYTHONPATH=%s;%%PYTHONPATH%%" && ' ...
            '"%s" %s 2>&1'], sourceRoot, pythonExe, moduleArgs);
    end
else
    if isempty(repoRoot)
        cmd = sprintf('%s %s 2>&1', shellQuote(pythonExe), moduleArgs);
    else
        sourceRoot = fullfile(repoRoot, 'src');
        cmd = sprintf('PYTHONPATH=%s:$PYTHONPATH %s %s 2>&1', ...
            shellQuote(sourceRoot), shellQuote(pythonExe), moduleArgs);
    end
end
try
    [status, output] = system(cmd, '-echo');
catch
    [status, output] = system(cmd);
end
if ~isempty(stdoutPath)
    fid = fopen(stdoutPath, 'w');
    if fid >= 0
        cleanup = onCleanup(@() fclose(fid));
        fwrite(fid, output, 'char');
        clear cleanup;
    end
end
runtime.command = cmd;
runtime.status = status;
runtime.stdout = stdoutPath;
if status ~= 0
    error('budMotherLinker:ExternalLinkerFailed', ...
        'cell_lineage_linker failed (%d):%s%s', status, newline, output);
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
value = ['''' strrep(char(string(raw)), '''', '''"''"''') ''''];
end

