function payload = pipelineRunJobPayload(runObj, project, pipelineInputPath, varargin)
% pipelineRunJobPayload  Build the shared worker payload for a pipelineRun.
%
% The returned value contains plain MATLAB data only and can be serialized
% to JSON, sent to DetecDiv Hub, or passed to detecdiv_run_pipeline_job in a
% separate MATLAB process.

    if nargin < 1 || isempty(runObj) || ~isa(runObj, 'pipelineRun')
        error('pipelineRunJobPayload:MissingRun', 'A pipelineRun object is required.');
    end
    if nargin < 2
        project = [];
    end
    if nargin < 3
        pipelineInputPath = '';
    end

    opts = localParse(varargin{:});
    ctx = runObj.ctx;
    if ~isstruct(ctx)
        ctx = struct();
    end
    run = localStructField(ctx, 'run');
    io = localStructField(ctx, 'io');

    if isempty(pipelineInputPath)
        pipelineInputPath = localPipelinePath(runObj, ctx);
    end
    projectPath = localProjectPath(project, runObj);
    targetRef = localStructProperty(runObj, 'targetRef');
    classifierPath = localTextField(targetRef, 'classiPath', '');
    classifierScoped = any(strcmpi(localTextField(targetRef, 'type', ''), {'classi','classifier'})) ...
        || (~isempty(classifierPath) && contains(lower(localTextField(run, 'inputSource', '')), 'classifier'));

    payload = struct();
    payload.job_kind = 'pipeline_run';
    if classifierScoped
        payload.project_ref = struct( ...
            'scope', 'classifier', ...
            'type', 'classi', ...
            'classifier_path', classifierPath, ...
            'project_mat_path', '');
    else
        payload.project_ref = struct( ...
            'scope', 'project', ...
            'type', 'shallow', ...
            'project_mat_path', projectPath);
    end

    pipelineRef = localStructProperty(runObj, 'pipelineRef');
    payload.pipeline_ref = struct( ...
        'pipeline_id', localTextField(pipelineRef, 'id', localTextProperty(runObj, 'templateId', '')), ...
        'pipeline_version', localTextField(pipelineRef, 'version', ''), ...
        'pipeline_json_path', char(string(pipelineInputPath)));

    request = struct();
    request.run_id = localTextProperty(runObj, 'runId', localTextField(run, 'runId', ''));
    request.description = localTextProperty(runObj, 'description', localTextField(run, 'description', ''));
    request.selected_nodes = localCellText(localField(run, 'selectedNodes', {}));
    request.node_params = localNodeParams(localField(run, 'nodeParams', struct()), request.selected_nodes);
    request.run_policy = localTextField(run, 'runPolicy', 'resume');
    request.input_source = localTextField(run, 'inputSource', '');
    request.intent = localTextField(run, 'intent', localTextField(run, 'classifierIntent', ''));
    request.existing_data_policy = localTextField(io, 'globalExistingPolicy', ...
        localTextField(io, 'existingPolicy', 'replace'));
    request.roi_cache_policy = localTextField(io, 'cachePolicy', 'auto');
    request.available_channels = localCellText(localField(run, 'availableChannels', localField(ctx, 'channels', {})));
    request.roi_channels = localCellText(localField(ctx, 'roiChannels', request.available_channels));
    request.masks = localCellText(localField(ctx, 'masks', {}));
    request.data_series = localCellText(localField(ctx, 'dataSeriesNames', localField(ctx, 'dataSeries', {})));
    request.selection = localSelection(ctx, run);
    request.gpu = struct('mode', localTextField(run, 'gpuPolicy', 'module_default'));
    request.python = localPythonPolicy(ctx);
    request.control = localStructField(run, 'control');
    request.paths = localRunPaths(run, io, classifierPath, opts.pathMappings);
    payload.run_request = request;

    payload.execution = struct( ...
        'requested_mode', opts.requestedMode, ...
        'allow_gui', false, ...
        'interactive', false, ...
        'save_project', logical(opts.saveProject), ...
        'save_project_mode', opts.saveProjectMode, ...
        'result_json_path', opts.resultPath, ...
        'cancel_token_file', opts.cancelTokenFile, ...
        'progress_json_path', opts.progressPath, ...
        'console_log_path', opts.consolePath);
end

function opts = localParse(varargin)
    opts = struct('requestedMode', 'local_process', 'saveProject', true, ...
        'saveProjectMode', 'shallowObj', 'resultPath', '', ...
        'cancelTokenFile', '', 'progressPath', '', 'consolePath', '', ...
        'pathMappings', struct('localRoot', {}, 'remoteRoot', {}));
    if mod(numel(varargin), 2) ~= 0
        error('pipelineRunJobPayload:Arguments', 'Options must be Name/Value pairs.');
    end
    for i = 1:2:numel(varargin)
        key = lower(char(string(varargin{i})));
        value = varargin{i+1};
        switch key
            case 'requestedmode'
                opts.requestedMode = char(string(value));
            case 'saveproject'
                opts.saveProject = logical(value);
            case 'saveprojectmode'
                opts.saveProjectMode = char(string(value));
            case 'resultpath'
                opts.resultPath = char(string(value));
            case 'canceltokenfile'
                opts.cancelTokenFile = char(string(value));
            case 'progresspath'
                opts.progressPath = char(string(value));
            case 'consolepath'
                opts.consolePath = char(string(value));
            case 'pathmappings'
                opts.pathMappings = value;
            otherwise
                error('pipelineRunJobPayload:UnknownOption', 'Unknown option: %s', key);
        end
    end
end

function pathText = localPipelinePath(runObj, ctx)
    pathText = '';
    ref = localStructProperty(runObj, 'pipelineRef');
    pathText = localTextField(ref, 'path', '');
    if isempty(pathText)
        pathText = localTextProperty(runObj, 'templatePath', '');
    end
    if isempty(pathText)
        pathText = localTextField(localStructField(ctx, 'pipelineRef'), 'path', '');
    end
end

function pathText = localProjectPath(project, runObj)
    pathText = '';
    if isa(project, 'shallow')
        try
            [projectDir, projectName] = project.getPath;
            pathText = fullfile(projectDir, [projectName '.mat']);
        catch
        end
    elseif ischar(project) || isstring(project)
        pathText = char(string(project));
    end
    if isempty(pathText)
        pathText = localTextProperty(runObj, 'projectPath', '');
    end
    if ~isempty(pathText) && ~endsWith(lower(pathText), '.mat')
        pathText = [pathText '.mat'];
    end
    if ~isempty(pathText) && exist(pathText, 'file') ~= 2
        jsonPath = regexprep(pathText, '\.mat$', '.json', 'ignorecase');
        if exist(jsonPath, 'file') == 2
            pathText = jsonPath;
        end
    end
end

function selection = localSelection(ctx, run)
    sel = localStructField(ctx, 'sel');
    selection = struct( ...
        'fovs', localField(sel, 'fovs', localField(run, 'fovIndex', [])), ...
        'frames', localField(sel, 'frames', localField(run, 'frames', [])), ...
        'rois', localField(sel, 'rois', localField(run, 'rois', [])), ...
        'channels', localCellText(localField(sel, 'channels', {})));
end

function python = localPythonPolicy(ctx)
    python = struct();
    exec = localStructField(ctx, 'exec');
    if isfield(exec, 'python') && isstruct(exec.python)
        python = exec.python;
    end
end

function paths = localRunPaths(run, io, classifierPath, pathMappings)
    paths = localStructField(run, 'paths');
    paths.raw_data_path = localTextField(run, 'rawDataPath', localTextField(io, 'rawDataPath', ''));
    paths.project_path = localTextField(run, 'projectPath', localTextField(io, 'projectPath', ''));
    if ~isempty(classifierPath)
        paths.classifier_path = classifierPath;
    end
    if ~isempty(pathMappings)
        paths.path_mappings = pathMappings;
    elseif ~isfield(paths, 'path_mappings')
        paths.path_mappings = struct('localRoot', {}, 'remoteRoot', {});
    end
end

function out = localNodeParams(value, selectedNodes)
    out = struct('id', {}, 'params', {});
    if isempty(value) || ~isstruct(value)
        return;
    end
    if isfield(value, 'id') && isfield(value, 'params')
        out = value;
        return;
    end
    ids = localCellText(selectedNodes);
    names = fieldnames(value);
    orderedNames = {};
    for i = 1:numel(ids)
        key = matlab.lang.makeValidName(ids{i});
        if isfield(value, key)
            orderedNames{end+1} = key; %#ok<AGROW>
        end
    end
    orderedNames = [orderedNames setdiff(names(:)', orderedNames, 'stable')];
    for i = 1:numel(orderedNames)
        key = orderedNames{i};
        nodeId = key;
        match = find(strcmp(cellfun(@matlab.lang.makeValidName, ids, 'UniformOutput', false), key), 1);
        if ~isempty(match)
            nodeId = ids{match};
        end
        params = value.(key);
        if ~isstruct(params)
            params = struct();
        end
        out(end+1) = struct('id', nodeId, 'params', params); %#ok<AGROW>
    end
end

function out = localCellText(value)
    if isempty(value)
        out = {};
    elseif iscell(value)
        out = cellfun(@(x)char(string(x)), value(:)', 'UniformOutput', false);
    elseif isstring(value)
        out = cellstr(value(:)');
    elseif ischar(value)
        out = {value};
    else
        try
            out = cellstr(string(value(:)'));
        catch
            out = {};
        end
    end
    out = out(~cellfun(@isempty, out));
end

function value = localField(S, name, defaultValue)
    value = defaultValue;
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        value = S.(name);
    end
end

function value = localStructField(S, name)
    value = struct();
    if isstruct(S) && isfield(S, name) && isstruct(S.(name))
        value = S.(name);
    end
end

function value = localStructProperty(obj, name)
    value = struct();
    try
        if isprop(obj, name) && isstruct(obj.(name))
            value = obj.(name);
        end
    catch
    end
end

function value = localTextField(S, name, defaultValue)
    value = defaultValue;
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            value = char(string(S.(name)));
        end
    catch
    end
end

function value = localTextProperty(obj, name, defaultValue)
    value = defaultValue;
    try
        if isprop(obj, name) && ~isempty(obj.(name))
            value = char(string(obj.(name)));
        end
    catch
    end
end
