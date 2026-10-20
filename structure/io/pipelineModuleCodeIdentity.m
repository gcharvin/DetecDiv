function identity = pipelineModuleCodeIdentity(location)
%PIPELINEMODULECODEIDENTITY Explicit code identity, including uncommitted code.
location = char(string(location));
identity = struct('path',location,'root','','gitCommit','','dirty',[], ...
    'file',pipelineModuleFileIdentity(location));
if isfile(location), folder=fileparts(location); else, folder=location; end
if ~isfolder(folder), return; end
[ok,root] = gitOutput(folder,{'rev-parse','--show-toplevel'});
if ~ok, return; end
identity.root = strtrim(root);
[ok,commit] = gitOutput(folder,{'rev-parse','HEAD'});
if ok, identity.gitCommit=strtrim(commit); end
[ok,changes] = gitOutput(folder,{'status','--porcelain','--untracked-files=no'});
if ok, identity.dirty=~isempty(strtrim(changes)); end
end

function [ok,out] = gitOutput(folder,args)
ok=false; out='';
try
    command=java.util.ArrayList();
    for item=[{'git','-C',folder} args], command.add(java.lang.String(item{1})); end
    builder=java.lang.ProcessBuilder(command);
    builder.redirectErrorStream(true);
    process=builder.start();
    reader=java.io.BufferedReader(java.io.InputStreamReader(process.getInputStream(),'UTF-8'));
    lines={};
    while true
        line=reader.readLine();
        if isempty(line), break; end
        lines{end+1}=char(line); %#ok<AGROW>
    end
    reader.close();
    out=strjoin(lines,newline);
    ok=process.waitFor()==0;
catch
    % Git is optional: exact entrypoint hashes remain available.
end
end
