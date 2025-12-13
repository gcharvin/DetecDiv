function L = runLogger(action, varargin)
% runLogger  Minimal run logging utility.
%
% Usage:
%   L = runLogger('start', classif, trainingFunName, trainingParamStructOrEmpty)
%   runLogger('msg',   L, 'hello %d', 3)
%   runLogger('save',  L, 'file.mat', 'var1', var1, 'var2', var2, ...)
%   runLogger('saveStruct', L, 'trainingParam.mat', trainingParam)
%   runLogger('json',  L, 'run.json', someStruct)
%   runLogger('stop',  L)
%
% Notes:
% - Uses diary to capture all console output into console.log
% - Writes events.log with timestamps

switch lower(action)

    case 'start'
        classif        = varargin{1};
        trainingFun    = varargin{2};
        trainingParam  = [];
        if numel(varargin) >= 3
            trainingParam = varargin{3};
        end

        % Base folder
        base = fullfile(classif.path, 'runs');
        if ~exist(base,'dir'); mkdir(base); end

        ts = datestr(now,'yyyymmdd_HHMMSS');
        safeStrid = regexprep(string(classif.strid), '[^\w\-]', '_');
        safeFun   = regexprep(string(trainingFun),   '[^\w\-]', '_');
        runDir = fullfile(base, sprintf('%s_%s_%s', ts, safeStrid, safeFun));
        mkdir(runDir);

        % Console capture
        consoleFile = fullfile(runDir,'console.log');
        diary off;
        diary(consoleFile);

        % Init logger struct
        L = struct();
        L.runDir = runDir;
        L.consoleFile = consoleFile;
        L.eventsFile = fullfile(runDir,'events.log');
        L.metaFile   = fullfile(runDir,'run.json');
        L.startTime  = datetime('now');
        L.strid      = char(safeStrid);
        L.trainingFun= char(safeFun);

        % Collect meta
        meta = localCollectMeta(classif, trainingFun, trainingParam, runDir);

        % Write json meta
        localWriteJson(L.metaFile, meta);

        % Save trainingParam snapshot if provided
        if ~isempty(trainingParam)
            try
                save(fullfile(runDir,'trainingParam.mat'),'trainingParam','-v7.3');
            catch
            end
        end

        % First event
        localAppendEvent(L.eventsFile, sprintf('RUN START dir=%s', runDir));

    case 'msg'
        L = varargin{1};
        fmt = varargin{2};
        args = varargin(3:end);
        if isempty(args)
            txt = sprintf('%s', fmt);
        else
            txt = sprintf(fmt, args{:});
        end
        localAppendEvent(L.eventsFile, txt);

    case 'save'
        L = varargin{1};
        fileName = varargin{2};
        % remaining args: name,value pairs
        S = struct();
        for k=3:2:numel(varargin)
            if k+1 > numel(varargin); break; end
            key = varargin{k};
            val = varargin{k+1};
            S.(key) = val;
        end
        fp = fullfile(L.runDir, fileName);
        try
            save(fp,'-struct','S','-v7.3');
            localAppendEvent(L.eventsFile, sprintf('Saved MAT: %s', fp));
        catch ME
            localAppendEvent(L.eventsFile, sprintf('WARN save failed: %s (%s)', fp, ME.message));
        end

    case 'savestruct'
        L = varargin{1};
        fileName = varargin{2};
        obj = varargin{3};
        fp = fullfile(L.runDir, fileName);
        try
            save(fp,'obj','-v7.3');
            localAppendEvent(L.eventsFile, sprintf('Saved MAT struct: %s', fp));
        catch ME
            localAppendEvent(L.eventsFile, sprintf('WARN saveStruct failed: %s (%s)', fp, ME.message));
        end

    case 'json'
        L = varargin{1};
        fileName = varargin{2};
        obj = varargin{3};
        fp = fullfile(L.runDir, fileName);
        try
            localWriteJson(fp, obj);
            localAppendEvent(L.eventsFile, sprintf('Saved JSON: %s', fp));
        catch ME
            localAppendEvent(L.eventsFile, sprintf('WARN json failed: %s (%s)', fp, ME.message));
        end

    case 'stop'
        L = varargin{1};
        localAppendEvent(L.eventsFile, 'RUN STOP');
        diary off;

    otherwise
        error('runLogger:UnknownAction','Unknown action: %s', action);
end
end

% -------------------- local helpers --------------------

function meta = localCollectMeta(classif, trainingFun, trainingParam, runDir)
meta = struct();
meta.timestamp = char(datetime('now'));
meta.runDir    = runDir;
meta.strid     = classif.strid;
meta.path      = classif.path;
meta.trainingFun = trainingFun;

% MATLAB / OS
meta.matlab = struct();
meta.matlab.version = version;
meta.matlab.release = version('-release');
meta.matlab.java    = version('-java');

meta.system = struct();
try
    meta.system.computer = computer;
    meta.system.arch     = computer('arch');
    meta.system.ispc     = ispc;
    meta.system.ismac    = ismac;
    meta.system.isunix   = isunix;
catch
end

% GPU
meta.gpu = struct();
try
    g = gpuDevice;
    meta.gpu.name = g.Name;
    meta.gpu.computeCapability = g.ComputeCapability;
    meta.gpu.totalMemoryGB = double(g.TotalMemory)/1e9;
    meta.gpu.driverVersion = g.DriverVersion;
catch
    meta.gpu = [];
end

% RNG
meta.rng = struct();
try
    r = rng;
    meta.rng.type  = r.Type;
    meta.rng.seed  = r.Seed;
catch
end

% Git (best-effort)
meta.git = struct();
[ok, git] = localGitInfo(classif.path);
if ok
    meta.git = git;
else
    meta.git = [];
end

% Training params snapshot (lightweight)
try
    meta.trainingParam = trainingParam;
catch
end
end

function [ok, git] = localGitInfo(repoPath)
ok = false;
git = struct('commit','', 'branch','', 'status','');
try
    % Only works if git is available + repoPath is in a git repo
    [s1, out1] = system(sprintf('cd "%s" && git rev-parse HEAD', repoPath));
    [s2, out2] = system(sprintf('cd "%s" && git rev-parse --abbrev-ref HEAD', repoPath));
    [s3, out3] = system(sprintf('cd "%s" && git status --porcelain', repoPath));
    if s1==0
        git.commit = strtrim(out1);
        git.branch = strtrim(out2);
        git.status = strtrim(out3); % empty => clean
        ok = true;
    end
catch
end
end

function localAppendEvent(eventsFile, msg)
try
    fid = fopen(eventsFile,'a');
    if fid<0, return; end
    fprintf(fid,'[%s] %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'), msg);
    fclose(fid);
catch
end
end

function localWriteJson(fp, obj)
txt = jsonencode(obj);
% pretty-ish: add newlines after commas (simple)
txt = regexprep(txt, ',"', sprintf(',\n"'));
fid = fopen(fp,'w');
fwrite(fid, txt, 'char');
fclose(fid);
end
