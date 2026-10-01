function ctx = process(ctx)
% Execute directly or as a pipeline custom node. User code owns its IO.
cfg = customModule.configuration(ctx.params);
[fun, info, cleanup] = customModule.resolve(cfg, ctx); %#ok<ASGLU>
if isfield(ctx, 'dryRun') && logical(ctx.dryRun), return; end
for i = 1:numel(cfg.in)
    if ~isfield(ctx, cfg.in(i).name)
        error('customModule:MissingInput', 'Missing input ctx.%s.', cfg.in(i).name);
    end
end
nodeParams = ctx.params;
info.sha256 = fileChecksum(info.file);
fprintf('[custom] %s (%s) from %s\n', info.entryPoint, info.callMode, info.file);
started = tic;
if strcmp(cfg.callMode, 'context')
    callCtx = ctx;
    callCtx.params = cfg.userParams;
    result = feval(fun, callCtx);
    if ~isstruct(result) || ~isscalar(result)
        error('customModule:InvalidContext', '%s must return a scalar ctx structure.', cfg.entryPoint);
    end
    for i = 1:numel(cfg.out)
        if ~isfield(result, cfg.out(i).name)
            error('customModule:MissingOutput', '%s did not return declared output ctx.%s.', cfg.entryPoint, cfg.out(i).name);
        end
    end
    fields = fieldnames(result);
    for i = 1:numel(fields), ctx.(fields{i}) = result.(fields{i}); end
    % Keep the node recipe in the runner; user code sees only its parameters.
    ctx.params = nodeParams;
else
    args = cfg.args;
    for i = 1:numel(args)
        arg = args{i};
        if isstruct(arg)
            if isfield(arg, 'context')
                args{i} = customModule.readField(ctx, arg.context);
            elseif isfield(arg, 'param')
                args{i} = customModule.readField(cfg.userParams, arg.param);
            else
                args{i} = arg.value;
            end
        end
    end
    values = cell(1, numel(cfg.out));
    if isempty(values)
        feval(fun, args{:});
    else
        [values{:}] = feval(fun, args{:});
    end
    for i = 1:numel(values), ctx.(cfg.out(i).name) = values{i}; end
end
info.durationSec = toc(started);
info.nodeId = '';
if isfield(ctx, 'pipeline') && isfield(ctx.pipeline, 'currentNode')
    info.nodeId = ctx.pipeline.currentNode;
end
if ~isfield(ctx, 'customModuleRuns') || isempty(ctx.customModuleRuns)
    ctx.customModuleRuns = info;
else
    ctx.customModuleRuns(end+1) = info;
end
end

function checksum = fileChecksum(file)
fid = fopen(file, 'rb');
if fid < 0, error('customModule:Checksum', 'Cannot read %s.', file); end
cleanup = onCleanup(@()fclose(fid));
bytes = fread(fid, Inf, '*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
checksum = lower(reshape(dec2hex(typecast(digest.digest(), 'uint8'), 2).', 1, []));
end
