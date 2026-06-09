function result = detecdiv_pipeline_cli(varargin)
% detecdiv_pipeline_cli  Simple command-line entry point for DetecDiv pipeline runs.
%
% Examples:
%   matlab -batch "startup; detecdiv_pipeline_cli('run','run_config.json', ...
%       '--run-id','test_01', ...
%       '--set','identify_rois.threshold=0.7', ...
%       '--ctx','sel.frames=[1,2,3]')"
%
%   matlab -batch "startup; detecdiv_pipeline_cli('payload','job.json')"
%
% The JSON config is the primary input. CLI flags are only lightweight overrides.
% Minimal JSON:
%   {
%     "project": "C:/data/project.mat",
%     "pipeline": "C:/data/pipeline/pipeline.json",
%     "run": {"selectedNodes": ["load_data"], "runPolicy": "restart"},
%     "nodeParams": {"load_data": {"path": "D:/raw"}},
%     "io": {"globalExistingPolicy": "replace"}
%   }
%
% Useful override flags:
%   --run-id ID                 Override run id.
%   --set NODE.PARAM=VALUE      Override a node param. Repeatable.
%   --ctx PATH=VALUE            Override ctx fields, e.g. sel.frames=[1,2].
%   --dry-run                   Validate without execution.
%   --no-save                   Do not save the project after execution.
%
% Values are parsed as JSON when possible, then booleans/numbers, otherwise text.

    if nargin == 0 || isHelpArg(varargin{1})
        printHelp();
        result = struct('status','help');
        return;
    end

    command = lower(char(string(varargin{1})));
    args = varargin(2:end);

    switch command
        case 'run'
            result = runFromCliArgs(args);
        case {'payload','job'}
            if isempty(args)
                error('detecdiv_pipeline_cli:MissingPayload', 'Payload JSON path is required.');
            end
            result = detecdiv_run_pipeline_job(args{1});
        otherwise
            error('detecdiv_pipeline_cli:UnknownCommand', 'Unknown command: %s', command);
    end
end

function result = runFromCliArgs(args)
    opts = parseArgs(args);

    if isempty(opts.project)
        error('detecdiv_pipeline_cli:MissingProject', '--project is required.');
    end
    if isempty(opts.pipeline)
        error('detecdiv_pipeline_cli:MissingPipeline', '--pipeline is required.');
    end

    repoRoot = fileparts(mfilename('fullpath'));
    ensureRepoOnPath(repoRoot);

    [shallowObj, msg] = shallowLoad(opts.project);
    if isempty(shallowObj)
        error('detecdiv_pipeline_cli:ProjectLoadFailed', '%s', msg);
    end

    [pipeObj, msg] = pipelineLoad(opts.pipeline);
    if isempty(pipeObj)
        error('detecdiv_pipeline_cli:PipelineLoadFailed', '%s', msg);
    end

    ctx = buildBaseContext(shallowObj, pipeObj);
    if ~isempty(opts.ctxFromConfig)
        ctx = mergeStructDeep(ctx, opts.ctxFromConfig);
    end
    if ~isempty(opts.profile)
        ctx = mergeStructDeep(ctx, resolveProfile(opts.profile, pipeObj, shallowObj));
    end
    if ~isempty(opts.ctxJson)
        ctx = mergeStructDeep(ctx, readJsonFile(opts.ctxJson));
    end

    ctx.allowGUI = opts.allowGui;
    ctx.interactive = opts.allowGui;
    if opts.dryRun
        ctx.dryRun = true;
    end

    if ~isfield(ctx,'run') || ~isstruct(ctx.run), ctx.run = struct(); end
    if ~isfield(ctx,'io') || ~isstruct(ctx.io), ctx.io = struct(); end

    if ~isempty(opts.runFromConfig)
        ctx.run = mergeStructDeep(ctx.run, opts.runFromConfig);
    end
    if ~isempty(opts.ioFromConfig)
        ctx.io = mergeStructDeep(ctx.io, opts.ioFromConfig);
    end

    if ~isempty(opts.nodes)
        ctx.run.selectedNodes = opts.nodes;
    end
    if ~isempty(opts.runPolicy)
        ctx.run.runPolicy = opts.runPolicy;
    end
    if ~isempty(opts.existingPolicy)
        ctx.io.existingPolicy = opts.existingPolicy;
        ctx.io.globalExistingPolicy = opts.existingPolicy;
    end

    ctx.run.nodeParams = mergeNodeParams(getFieldDefault(ctx.run, 'nodeParams', struct()), opts.nodeParams);
    if ~isempty(opts.overrideJson)
        ctx.run.nodeParams = mergeNodeParams(ctx.run.nodeParams, readNodeOverrides(opts.overrideJson));
    end
    for i = 1:numel(opts.ctxPatches)
        ctx = setNestedField(ctx, opts.ctxPatches(i).path, opts.ctxPatches(i).value);
    end

    runId = opts.runId;
    if isempty(runId)
        runId = suggestRunId(shallowObj, pipeObj.strid);
    end
    ctx.runId = runId;
    ctx.run.runId = runId;

    result = initResult(runId, opts.project, pipeObj, opts.pipeline);

    runObj = [];
    try
        if opts.dryRun
            [~, report] = runPipelineDetecDiv(pipeObj, ctx);
            status = 'dry_run_done';
        else
            runObj = ensureRunObject(shallowObj, pipeObj, ctx, opts, runId);
            runObj.status = 'running';
            runObj.ctx = ctx;
            pipelineRunSave(runObj);
            ctx = runObj.ctx;

            [ctxOut, report] = runPipelineDetecDiv(pipeObj, ctx);
            runObj.ctx = ctxOut;
            runObj.outputs = struct('report', report);
            runObj.status = 'done';
            pipelineRunSave(runObj);
            if opts.saveProject
                saveProject(shallowObj, opts.saveMode);
            end
            status = 'done';
        end

        result.status = status;
        result.run_id = runId;
        result.summary = getFieldDefault(report, 'summary', struct());
        if ~isempty(runObj)
            result.run_json_path = fullfile(runObj.path, 'run.json');
        end
        fprintf('DETECDIV_CLI_RESULT status=%s run_id=%s\n', result.status, result.run_id);
        if ~isempty(result.run_json_path)
            fprintf('DETECDIV_CLI_RUN_JSON %s\n', result.run_json_path);
        end
    catch ME
        if ~isempty(runObj)
            try
                runObj.status = 'failed';
                runObj.ctx = ctx;
                pipelineRunSave(runObj);
                result.run_json_path = fullfile(runObj.path, 'run.json');
            catch
            end
        end
        result.status = 'failed';
        result.error = getReport(ME, 'extended', 'hyperlinks', 'off');
        fprintf(2, '%s\n', result.error);
        rethrow(ME);
    end
end

function opts = parseArgs(args)
    opts = struct();
    opts.config = '';
    opts.project = '';
    opts.pipeline = '';
    opts.profile = '';
    opts.runId = '';
    opts.description = '';
    opts.runPolicy = '';
    opts.existingPolicy = '';
    opts.nodes = {};
    opts.nodeParams = struct();
    opts.ctxPatches = struct('path', {}, 'value', {});
    opts.overrideJson = '';
    opts.ctxJson = '';
    opts.dryRun = false;
    opts.allowGui = false;
    opts.saveProject = true;
    opts.saveMode = 'shallowObj';
    opts.ctxFromConfig = struct();
    opts.runFromConfig = struct();
    opts.ioFromConfig = struct();

    [opts, args] = applyConfigArgument(opts, args);

    i = 1;
    while i <= numel(args)
        key = char(string(args{i}));
        switch lower(key)
            case {'--help','-h'}
                printHelp();
                return;
            case {'--config','-c'}
                error('detecdiv_pipeline_cli:ConfigPosition', ...
                    'Use --config before other flags, or pass the JSON path directly after run.');
            case {'--project','-p'}
                opts.project = nextValue(args, i, key); i = i + 2;
            case {'--pipeline','--template','-t'}
                opts.pipeline = nextValue(args, i, key); i = i + 2;
            case '--profile'
                opts.profile = nextValue(args, i, key); i = i + 2;
            case '--run-id'
                opts.runId = nextValue(args, i, key); i = i + 2;
            case '--description'
                opts.description = nextValue(args, i, key); i = i + 2;
            case '--run-policy'
                opts.runPolicy = nextValue(args, i, key); i = i + 2;
            case {'--existing-policy','--existing-data-policy'}
                opts.existingPolicy = nextValue(args, i, key); i = i + 2;
            case '--nodes'
                opts.nodes = splitList(nextValue(args, i, key)); i = i + 2;
            case {'--set','--override'}
                opts.nodeParams = mergeNodeParams(opts.nodeParams, parseNodeParamOverride(nextValue(args, i, key))); i = i + 2;
            case '--ctx'
                opts.ctxPatches(end+1) = parseCtxPatch(nextValue(args, i, key));
                i = i + 2;
            case '--override-json'
                opts.overrideJson = nextValue(args, i, key); i = i + 2;
            case '--ctx-json'
                opts.ctxJson = nextValue(args, i, key); i = i + 2;
            case '--dry-run'
                opts.dryRun = true; i = i + 1;
            case '--allow-gui'
                opts.allowGui = true; i = i + 1;
            case '--no-save'
                opts.saveProject = false; i = i + 1;
            case '--save-mode'
                opts.saveMode = nextValue(args, i, key); i = i + 2;
            otherwise
                error('detecdiv_pipeline_cli:UnknownFlag', 'Unknown flag: %s', key);
        end
    end
end

function [opts, args] = applyConfigArgument(opts, args)
    configPath = '';
    removeIdx = [];

    if ~isempty(args)
        first = char(string(args{1}));
        if ~startsWith(first, '-')
            configPath = first;
            removeIdx = 1;
        end
    end

    if isempty(configPath)
        for i = 1:numel(args)
            key = char(string(args{i}));
            if any(strcmpi(key, {'--config','-c'}))
                configPath = nextValue(args, i, key);
                removeIdx = [i i+1];
                break;
            end
        end
    end

    if isempty(configPath)
        return;
    end

    args(removeIdx) = [];
    opts.config = configPath;
    cfg = readJsonFile(configPath);
    opts = applyRunConfig(opts, cfg);
end

function opts = applyRunConfig(opts, cfg)
    if ~isstruct(cfg) || isempty(cfg)
        error('detecdiv_pipeline_cli:InvalidConfig', 'Run config JSON must decode to a struct.');
    end

    opts.project = getTextAny(cfg, {'project','project_mat_path'}, opts.project);
    opts.pipeline = getTextAny(cfg, {'pipeline','pipeline_json_path','pipeline_path'}, opts.pipeline);
    if isempty(opts.project) && isfield(cfg, 'project_ref') && isstruct(cfg.project_ref)
        opts.project = getTextAny(cfg.project_ref, {'project_mat_path'}, opts.project);
    end
    if isempty(opts.pipeline) && isfield(cfg, 'pipeline_ref') && isstruct(cfg.pipeline_ref)
        opts.pipeline = getTextAny(cfg.pipeline_ref, {'pipeline_json_path','pipeline_bundle_uri','export_manifest_uri'}, opts.pipeline);
    end
    opts.profile = getTextAny(cfg, {'profile'}, opts.profile);
    opts.runId = getTextAny(cfg, {'runId','run_id'}, opts.runId);
    opts.description = getTextAny(cfg, {'description'}, opts.description);

    if isfield(cfg, 'ctx') && isstruct(cfg.ctx)
        opts.ctxFromConfig = cfg.ctx;
    end
    if isfield(cfg, 'run') && isstruct(cfg.run)
        opts.runFromConfig = normalizeRunConfig(cfg.run);
        opts.runId = getTextAny(cfg.run, {'runId','run_id'}, opts.runId);
        opts.description = getTextAny(cfg.run, {'description'}, opts.description);
    end
    if isfield(cfg, 'io') && isstruct(cfg.io)
        opts.ioFromConfig = normalizeIoConfig(cfg.io);
    end
    if isfield(cfg, 'nodeParams')
        opts.nodeParams = mergeNodeParams(opts.nodeParams, cfg.nodeParams);
    elseif isfield(cfg, 'node_params')
        opts.nodeParams = mergeNodeParams(opts.nodeParams, cfg.node_params);
    end
    if isfield(cfg, 'execution') && isstruct(cfg.execution)
        ex = cfg.execution;
        if isfield(ex, 'dryRun'), opts.dryRun = logical(ex.dryRun); end
        if isfield(ex, 'dry_run'), opts.dryRun = logical(ex.dry_run); end
        if isfield(ex, 'allowGUI'), opts.allowGui = logical(ex.allowGUI); end
        if isfield(ex, 'allow_gui'), opts.allowGui = logical(ex.allow_gui); end
        if isfield(ex, 'saveProject'), opts.saveProject = logical(ex.saveProject); end
        if isfield(ex, 'save_project'), opts.saveProject = logical(ex.save_project); end
        opts.saveMode = getTextAny(ex, {'saveMode','save_project_mode'}, opts.saveMode);
    end
end

function runCfg = normalizeRunConfig(runCfg)
    if isfield(runCfg, 'selected_nodes') && ~isfield(runCfg, 'selectedNodes')
        runCfg.selectedNodes = normalizeStringList(runCfg.selected_nodes);
    end
    if isfield(runCfg, 'run_policy') && ~isfield(runCfg, 'runPolicy')
        runCfg.runPolicy = char(string(runCfg.run_policy));
    end
    if isfield(runCfg, 'node_params') && ~isfield(runCfg, 'nodeParams')
        runCfg.nodeParams = runCfg.node_params;
    end
end

function ioCfg = normalizeIoConfig(ioCfg)
    if isfield(ioCfg, 'existing_data_policy') && ~isfield(ioCfg, 'globalExistingPolicy')
        ioCfg.globalExistingPolicy = char(string(ioCfg.existing_data_policy));
    end
    if isfield(ioCfg, 'global_existing_policy') && ~isfield(ioCfg, 'globalExistingPolicy')
        ioCfg.globalExistingPolicy = char(string(ioCfg.global_existing_policy));
    end
    if isfield(ioCfg, 'existing_policy') && ~isfield(ioCfg, 'existingPolicy')
        ioCfg.existingPolicy = char(string(ioCfg.existing_policy));
    end
    if isfield(ioCfg, 'globalExistingPolicy') && ~isfield(ioCfg, 'existingPolicy')
        ioCfg.existingPolicy = ioCfg.globalExistingPolicy;
    end
    if isfield(ioCfg, 'existingPolicy') && ~isfield(ioCfg, 'globalExistingPolicy')
        ioCfg.globalExistingPolicy = ioCfg.existingPolicy;
    end
end

function out = normalizeStringList(value)
    if isempty(value)
        out = {};
    elseif iscell(value)
        out = cellfun(@(v) char(string(v)), value(:), 'UniformOutput', false);
    elseif isstring(value)
        out = cellstr(value(:));
    else
        out = {char(string(value))};
    end
end

function value = getTextAny(S, names, default)
    value = default;
    if ~isstruct(S)
        return;
    end
    for i = 1:numel(names)
        name = char(string(names{i}));
        if isfield(S, name) && ~isempty(S.(name))
            value = char(string(S.(name)));
            return;
        end
    end
end

function value = nextValue(args, i, key)
    if i + 1 > numel(args)
        error('detecdiv_pipeline_cli:MissingFlagValue', 'Missing value for %s.', key);
    end
    value = char(string(args{i+1}));
end

function ctx = buildBaseContext(shallowObj, pipeObj)
    projectPath = fullfile(shallowObj.io.path, shallowObj.io.file);
    ctx = struct();
    ctx.shallow = shallowObj;
    ctx.shallowObj = shallowObj;
    ctx.allowGUI = false;
    ctx.interactive = false;
    ctx.pipelineRef = struct('id', char(string(pipeObj.strid)), ...
        'path', canonicalPipelinePath(pipeObj), ...
        'version', char(string(pipeObj.version)));
    ctx.targetRef = struct('type','shallow', ...
        'projectPath', projectPath, ...
        'projectName', shallowObj.io.file, ...
        'fovIds', [], ...
        'roiIds', {{}}, ...
        'classiPath', '', ...
        'notes', '');
    ctx.run = struct();
    ctx.io = struct();
end

function profile = resolveProfile(name, pipeObj, shallowObj)
    key = matlab.lang.makeValidName(char(string(name)));

    if isprop(pipeObj, 'runProfiles') && isstruct(pipeObj.runProfiles) && isfield(pipeObj.runProfiles, key)
        profile = unwrapProfile(pipeObj.runProfiles.(key));
        return;
    end

    if isprop(shallowObj, 'runProfiles') && isstruct(shallowObj.runProfiles) && isfield(shallowObj.runProfiles, key)
        profile = unwrapProfile(shallowObj.runProfiles.(key));
        return;
    end

    error('detecdiv_pipeline_cli:ProfileNotFound', ...
        'Profile "%s" not found in pipeline.runProfiles or shallowObj.runProfiles.', char(string(name)));
end

function profile = unwrapProfile(profile)
    if isstruct(profile) && isfield(profile, 'ctx') && isstruct(profile.ctx)
        profile = profile.ctx;
    end
    if isempty(profile) || ~isstruct(profile)
        profile = struct();
    end
end

function override = parseNodeParamOverride(text)
    [lhs, rhs] = splitAssignment(text);
    parts = regexp(lhs, '\.', 'split');
    if numel(parts) < 2
        error('detecdiv_pipeline_cli:InvalidOverride', ...
            'Node override must look like NODE.PARAM=VALUE: %s', text);
    end
    nodeId = parts{1};
    paramPath = strjoin(parts(2:end), '.');
    params = setNestedField(struct(), paramPath, parseValue(rhs));
    override = struct();
    override.(matlab.lang.makeValidName(nodeId)) = params;
end

function patch = parseCtxPatch(text)
    [lhs, rhs] = splitAssignment(text);
    patch = struct('path', lhs, 'value', parseValue(rhs));
end

function [lhs, rhs] = splitAssignment(text)
    text = char(string(text));
    eq = strfind(text, '=');
    if isempty(eq)
        error('detecdiv_pipeline_cli:InvalidAssignment', 'Expected NAME=VALUE: %s', text);
    end
    lhs = strtrim(text(1:eq(1)-1));
    rhs = strtrim(text(eq(1)+1:end));
    if isempty(lhs)
        error('detecdiv_pipeline_cli:InvalidAssignment', 'Assignment has an empty name: %s', text);
    end
end

function value = parseValue(text)
    text = strtrim(char(string(text)));
    if isempty(text)
        value = '';
        return;
    end
    try
        value = jsondecode(text);
        return;
    catch
    end
    switch lower(text)
        case 'true'
            value = true;
            return;
        case 'false'
            value = false;
            return;
    end
    num = str2double(text);
    if ~isnan(num)
        value = num;
        return;
    end
    if startsWith(text, '[') && endsWith(text, ']')
        try
            value = str2num(text); %#ok<ST2NM>
            return;
        catch
        end
    end
    value = stripQuotes(text);
end

function value = stripQuotes(value)
    if numel(value) >= 2
        if (value(1) == '"' && value(end) == '"') || (value(1) == '''' && value(end) == '''')
            value = value(2:end-1);
        end
    end
end

function out = readNodeOverrides(pathIn)
    S = readJsonFile(pathIn);
    if isempty(S)
        out = struct();
    elseif isfield(S, 'node_params')
        out = nodeParamsArrayToMap(S.node_params);
    elseif isfield(S, 'nodeParams')
        out = S.nodeParams;
    else
        out = S;
    end
end

function map = nodeParamsArrayToMap(arr)
    map = struct();
    if ~isstruct(arr)
        return;
    end
    for i = 1:numel(arr)
        if ~isfield(arr(i), 'id') || isempty(arr(i).id)
            continue;
        end
        key = matlab.lang.makeValidName(char(string(arr(i).id)));
        params = struct();
        if isfield(arr(i), 'params') && isstruct(arr(i).params)
            params = arr(i).params;
        end
        map.(key) = params;
    end
end

function S = readJsonFile(pathIn)
    pathIn = char(string(pathIn));
    if exist(pathIn, 'file') ~= 2
        error('detecdiv_pipeline_cli:JsonNotFound', 'JSON file not found: %s', pathIn);
    end
    S = jsondecode(fileread(pathIn));
end

function out = mergeNodeParams(base, patch)
    if isempty(base) || ~isstruct(base)
        base = struct();
    end
    if isempty(patch) || ~isstruct(patch)
        out = base;
        return;
    end
    if isfield(base, 'id')
        base = nodeParamsArrayToMap(base);
    end
    if isfield(patch, 'id')
        patch = nodeParamsArrayToMap(patch);
    end
    out = mergeStructDeep(base, patch);
end

function out = mergeStructDeep(base, patch)
    if isempty(base) || ~isstruct(base)
        base = struct();
    end
    out = base;
    if isempty(patch) || ~isstruct(patch)
        return;
    end
    fn = fieldnames(patch);
    for i = 1:numel(fn)
        name = fn{i};
        if isfield(out, name) && isstruct(out.(name)) && isstruct(patch.(name)) && ...
                isscalar(out.(name)) && isscalar(patch.(name))
            out.(name) = mergeStructDeep(out.(name), patch.(name));
        else
            out.(name) = patch.(name);
        end
    end
end

function S = setNestedField(S, dottedPath, value)
    parts = regexp(char(string(dottedPath)), '\.', 'split');
    parts = cellfun(@matlab.lang.makeValidName, parts, 'UniformOutput', false);
    S = setNestedFieldParts(S, parts, value);
end

function S = setNestedFieldParts(S, parts, value)
    if isscalar(parts)
        S.(parts{1}) = value;
        return;
    end
    key = parts{1};
    if ~isfield(S, key) || ~isstruct(S.(key)) || isempty(S.(key))
        S.(key) = struct();
    end
    S.(key) = setNestedFieldParts(S.(key), parts(2:end), value);
end

function runObj = ensureRunObject(shallowObj, pipeObj, ctx, opts, runId)
    idx = [];
    try
        if isfield(shallowObj.processing, 'pipelineRun') && ~isempty(shallowObj.processing.pipelineRun)
            names = arrayfun(@(r) char(string(r.runId)), shallowObj.processing.pipelineRun, 'UniformOutput', false);
            idx = find(strcmp(names, char(string(runId))), 1, 'first');
        end
    catch
        idx = [];
    end

    templatePath = canonicalPipelinePath(pipeObj);
    if isempty(idx)
        runObj = pipelineRunNew(shallowObj, pipeObj.strid, templatePath, ...
            'runId', runId, ...
            'description', opts.description, ...
            'ctx', ctx, ...
            'status', 'new');
    else
        runObj = shallowObj.processing.pipelineRun(idx);
        runObj.templateId = char(string(pipeObj.strid));
        runObj.templatePath = templatePath;
        runObj.pipelineRef = ctx.pipelineRef;
        runObj.targetRef = ctx.targetRef;
        runObj.description = opts.description;
        runObj.ctx = ctx;
    end
end

function runId = suggestRunId(shallowObj, templateId)
    base = [char(string(templateId)) '_run_'];
    n = 1;
    try
        if isfield(shallowObj.processing, 'pipelineRun') && ~isempty(shallowObj.processing.pipelineRun)
            names = arrayfun(@(r) char(string(r.runId)), shallowObj.processing.pipelineRun, 'UniformOutput', false);
            while any(strcmp(names, [base num2str(n)]))
                n = n + 1;
            end
        end
    catch
    end
    runId = [base num2str(n)];
end

function saveProject(shallowObj, saveMode)
    if any(strcmpi(char(string(saveMode)), {'full','project','fullProject','projectAndRois'}))
        shallowSave(shallowObj);
    else
        shallowSave(shallowObj, 'shallowObj');
    end
end

function pathOut = canonicalPipelinePath(pipeObj)
    pathOut = '';
    try
        if isa(pipeObj, 'pipeline') && ~isempty(pipeObj.path)
            candidate = fullfile(pipeObj.path, 'pipeline.json');
            if exist(candidate, 'file') == 2
                pathOut = candidate;
                return;
            end
            pathOut = char(string(pipeObj.path));
        end
    catch
    end
end

function result = initResult(runId, projectPath, pipeObj, pipelineInputPath)
    result = struct();
    result.status = 'failed';
    result.run_id = char(string(runId));
    result.project_mat_path = char(string(projectPath));
    result.pipeline_json_path = canonicalPipelinePath(pipeObj);
    if isempty(result.pipeline_json_path)
        result.pipeline_json_path = char(string(pipelineInputPath));
    end
    result.run_json_path = '';
    result.summary = struct();
    result.error = '';
end

function values = splitList(text)
    if isempty(text)
        values = {};
        return;
    end
    values = regexp(char(string(text)), '[,;]', 'split');
    values = strtrim(values);
    values = values(~cellfun(@isempty, values));
end

function v = getFieldDefault(S, name, default)
    if isstruct(S) && isfield(S, name)
        v = S.(name);
    else
        v = default;
    end
end

function ensureRepoOnPath(repoRoot)
    if exist('startup', 'file') == 2
        return;
    end
    addpath(repoRoot);
    addpath(genpath(fullfile(repoRoot, 'structure')));
    addpath(genpath(fullfile(repoRoot, 'helpers')));
    addpath(genpath(fullfile(repoRoot, 'engine')));
end

function tf = isHelpArg(arg)
    tf = any(strcmpi(char(string(arg)), {'help','--help','-h'}));
end

function printHelp()
    helpText = [
        "DetecDiv pipeline CLI" newline ...
        "" newline ...
        "Usage:" newline ...
        "  matlab -batch ""startup; detecdiv_pipeline_cli('run','run_config.json')""" newline ...
        "  matlab -batch ""startup; detecdiv_pipeline_cli('run','run_config.json','--set','node.param=42')""" newline ...
        "  matlab -batch ""startup; detecdiv_pipeline_cli('payload','job.json')""" newline ...
        "" newline ...
        "Run config JSON fields:" newline ...
        "  project                     Shallow project .mat path" newline ...
        "  pipeline                    Pipeline JSON, folder, or export manifest" newline ...
        "  ctx                         Base execution context patch" newline ...
        "  run                         ctx.run patch, including selectedNodes/runPolicy" newline ...
        "  io                          ctx.io patch, including globalExistingPolicy" newline ...
        "  nodeParams                  Map of node id to params, or node_params array" newline ...
        "  execution                   dryRun/allowGUI/saveProject/saveMode" newline ...
        "" newline ...
        "Lightweight CLI overrides:" newline ...
        "  --run-id ID                 Explicit run id" newline ...
        "  --run-policy POLICY         resume, restart, rerun, skip" newline ...
        "  --existing-policy POLICY    replace, append, skip, error, upsert" newline ...
        "  --nodes A,B,C               Run only selected node ids" newline ...
        "  --set NODE.PARAM=VALUE      Override node param; repeatable" newline ...
        "  --ctx PATH=VALUE            Override ctx field; repeatable" newline ...
        "  --override-json PATH        JSON node overrides" newline ...
        "  --ctx-json PATH             JSON ctx patch" newline ...
        "  --dry-run                   Validate only" newline ...
        "  --allow-gui                 Allow node GUIs" newline ...
        "  --no-save                   Skip final project save" newline ...
        ];
    fprintf('%s\n', helpText);
end
