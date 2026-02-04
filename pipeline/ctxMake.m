function ctx = ctxMake(project, varargin)
% ctxMake Create a pipeline context with stable sub-structs.
%   ctx = ctxMake(project, 'Name', value, ...)

    if nargin < 1
        project = [];
    end

    ctx = struct();
    ctx.project = project;

    ctx.run = struct( ...
        'id',     "", ...
        'tag',    "", ...
        'stepId', "", ...
        'rootRel',"", ...
        'rootAbs',"", ...
        'dryRun', false, ...
        'resume', true ...
    );

    ctx.io = struct( ...
        'projectRootAbs', "", ...
        'rawRootAbs',     "", ...
        'artifactRootAbs',"", ...
        'tmpRootAbs',     "", ...
        'pathMap',        struct(), ...
        'writePolicy',    "commit", ...
        'overwrite',      false ...
    );

    ctx.sel = struct( ...
        'rois',      [], ...
        'frames',    [], ...
        'channels',  {{}}, ...
        'maskChannels', {{}}, ...
        'classes',   {{}}, ...
        'timeRange', [] ...
    );

    ctx.names = struct( ...
        'outputName',    "", ...
        'namespace',     "", ...
        'channelPrefix', "results", ...
        'dataseriesPrefix', "ds", ...
        'tablePrefix',   "tbl" ...
    );

    ctx.store = struct( ...
        'registry',    struct(), ...
        'cacheMode',   "auto", ...
        'fingerprint', struct(), ...
        'handles',     struct() ...
    );

    ctx.exec = struct( ...
        'gpu',      0, ...
        'python',   struct('env', "", 'exe', "", 'ok', true), ...
        'parallel', false, ...
        'nWorkers', 0 ...
    );

    ctx.log = struct( ...
        'info',  @(varargin) disp(sprintf(varargin{:})), ...
        'warn',  @(varargin) warning(sprintf(varargin{:})), ...
        'error', @(varargin) error(sprintf(varargin{:})), ...
        'event', @(S) [] ...
    );

    ctx.meta = struct( ...
        'matlab',  struct('release', version('-release'), 'version', version), ...
        'git',     struct('commit', "", 'branch', "", 'dirty', false), ...
        'machine', struct('computer', computer, 'ispc', ispc) ...
    );

    % Fill obvious defaults from project when possible.
    if ~isempty(project)
        try
            if isprop(project, 'io') && isstruct(project.io)
                if isfield(project.io, 'path') && ~isempty(project.io.path)
                    ctx.io.projectRootAbs = char(project.io.path);
                end
                if isfield(project.io, 'file') && ~isempty(project.io.file)
                    if ~isempty(ctx.io.projectRootAbs)
                        ctx.io.projectRootAbs = fullfile(ctx.io.projectRootAbs, char(project.io.file));
                    end
                end
            end
        catch
            % Best effort only.
        end
    end

    if isempty(varargin)
        return;
    end

    % Single struct override
    if numel(varargin) == 1 && isstruct(varargin{1})
        ctx = mergeStruct(ctx, varargin{1});
        return;
    end

    % Name-value overrides
    if mod(numel(varargin), 2) ~= 0
        error('ctxMake:BadArgs', 'Name-value pairs are not balanced.');
    end

    for i = 1:2:numel(varargin)
        key = varargin{i};
        val = varargin{i+1};
        if isstring(key), key = char(key); end
        if ~ischar(key)
            error('ctxMake:BadKey', 'Keys must be strings.');
        end

        keyLower = lower(strtrim(key));

        % Dotted path support: e.g. 'run.id'
        if contains(keyLower, '.')
            parts = strsplit(keyLower, '.');
            if numel(parts) == 2 && isfield(ctx, parts{1})
                sub = ctx.(parts{1});
                if isstruct(sub)
                    sub.(parts{2}) = val;
                    ctx.(parts{1}) = sub;
                    continue;
                end
            end
        end

        switch keyLower
            case 'run'
                ctx.run = mergeStruct(ctx.run, val);
            case 'io'
                ctx.io = mergeStruct(ctx.io, val);
            case 'sel'
                ctx.sel = mergeStruct(ctx.sel, val);
            case 'names'
                ctx.names = mergeStruct(ctx.names, val);
            case 'store'
                ctx.store = mergeStruct(ctx.store, val);
            case 'exec'
                ctx.exec = mergeStruct(ctx.exec, val);
            case 'log'
                ctx.log = mergeStruct(ctx.log, val);
            case 'meta'
                ctx.meta = mergeStruct(ctx.meta, val);

            case 'outputname'
                ctx.names.outputName = val;
            case 'namespace'
                ctx.names.namespace = val;
            case 'frames'
                ctx.sel.frames = val;
            case 'channels'
                ctx.sel.channels = val;
            case 'maskchannels'
                ctx.sel.maskChannels = val;
            case 'classes'
                ctx.sel.classes = val;
            case 'rois'
                ctx.sel.rois = val;
            case 'timerange'
                ctx.sel.timeRange = val;

            case 'runid'
                ctx.run.id = val;
            case 'runtag'
                ctx.run.tag = val;
            case 'stepid'
                ctx.run.stepId = val;
            case 'runrootabs'
                ctx.run.rootAbs = val;
            case 'runrootrel'
                ctx.run.rootRel = val;
            case 'dryrun'
                ctx.run.dryRun = logical(val);
            case 'resume'
                ctx.run.resume = logical(val);

            case 'projectrootabs'
                ctx.io.projectRootAbs = val;
            case 'rawrootabs'
                ctx.io.rawRootAbs = val;
            case 'artifactrootabs'
                ctx.io.artifactRootAbs = val;
            case 'tmprootabs'
                ctx.io.tmpRootAbs = val;
            case 'writepolicy'
                ctx.io.writePolicy = val;
            case 'overwrite'
                ctx.io.overwrite = logical(val);

            case 'gpu'
                ctx.exec.gpu = val;
            case 'parallel'
                ctx.exec.parallel = logical(val);
            case 'nworkers'
                ctx.exec.nWorkers = val;

            otherwise
                % Store unknown overrides in meta.extra to avoid dropping them.
                if ~isfield(ctx.meta, 'extra') || ~isstruct(ctx.meta.extra)
                    ctx.meta.extra = struct();
                end
                safeKey = matlab.lang.makeValidName(key);
                ctx.meta.extra.(safeKey) = val;
        end
    end
end

function out = mergeStruct(base, override)
    out = base;
    if isempty(override)
        return;
    end
    if ~isstruct(override)
        out = override;
        return;
    end
    f = fieldnames(override);
    for i = 1:numel(f)
        k = f{i};
        if isfield(out, k) && isstruct(out.(k)) && isstruct(override.(k))
            out.(k) = mergeStruct(out.(k), override.(k));
        else
            out.(k) = override.(k);
        end
    end
end
