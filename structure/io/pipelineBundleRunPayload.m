function payload = pipelineBundleRunPayload(bundlePath, projectMatPath, varargin)
% pipelineBundleRunPayload  Build the shared local/hub payload for a bundle run.
%
%   payload = pipelineBundleRunPayload(bundlePath, projectMatPath, ...)
%
% The payload follows the contract consumed by detecdiv_run_pipeline_job and
% detecdiv-hub. It deliberately references the portable bundle rather than a
% registry pipeline so local and server execution use the same semantics.

    if nargin < 1 || isempty(bundlePath)
        error('pipelineBundleRunPayload:MissingBundle', 'A bundle folder or export_manifest.json path is required.');
    end
    if nargin < 2 || isempty(projectMatPath)
        error('pipelineBundleRunPayload:MissingProject', 'A project .mat path is required.');
    end

    opts = struct( ...
        'runId', '', ...
        'description', '', ...
        'selectedNodes', {{}}, ...
        'nodeParams', struct('id', {}, 'params', {}), ...
        'runPolicy', 'resume', ...
        'existingDataPolicy', 'replace', ...
        'roiCachePolicy', 'auto', ...
        'allowGUI', false, ...
        'interactive', false, ...
        'requestedMode', 'auto', ...
        'hub', struct(), ...
        'pathMappings', struct('localRoot', {}, 'remoteRoot', {}));

    if mod(numel(varargin), 2) ~= 0
        error('pipelineBundleRunPayload:Args', 'Arguments must be Name/Value pairs.');
    end
    for i = 1:2:numel(varargin)
        key = lower(char(string(varargin{i})));
        value = varargin{i+1};
        switch key
            case 'runid'
                opts.runId = char(string(value));
            case 'description'
                opts.description = char(string(value));
            case 'selectednodes'
                opts.selectedNodes = localCellText(value);
            case 'nodeparams'
                opts.nodeParams = localNormalizeNodeParams(value);
            case 'runpolicy'
                opts.runPolicy = char(string(value));
            case 'existingdatapolicy'
                opts.existingDataPolicy = char(string(value));
            case 'roicachepolicy'
                opts.roiCachePolicy = char(string(value));
            case 'allowgui'
                opts.allowGUI = logical(value);
            case 'interactive'
                opts.interactive = logical(value);
            case 'requestedmode'
                opts.requestedMode = char(string(value));
            case 'hub'
                if isstruct(value)
                    opts.hub = value;
                end
            case 'pathmappings'
                opts.pathMappings = localNormalizeMappings(value);
            otherwise
                error('pipelineBundleRunPayload:UnknownOption', 'Unknown option "%s".', key);
        end
    end

    [bundleRoot, manifestPath, pipelineJsonPath] = localResolveBundle(bundlePath);
    mappingCtx = struct('hub', opts.hub, 'run', struct('paths', struct('path_mappings', opts.pathMappings)));
    pathMappings = detecdiv_paths_module_mappings(mappingCtx);

    payload = struct();
    payload.job_kind = 'pipeline_run';
    payload.project_ref = struct( ...
        'project_mat_path', char(string(projectMatPath)));
    payload.pipeline_ref = struct( ...
        'pipeline_bundle_uri', char(string(bundleRoot)), ...
        'export_manifest_uri', char(string(manifestPath)), ...
        'pipeline_json_path', char(string(pipelineJsonPath)));
    payload.run_request = struct();
    payload.run_request.run_id = opts.runId;
    payload.run_request.description = opts.description;
    payload.run_request.selected_nodes = opts.selectedNodes;
    payload.run_request.node_params = opts.nodeParams;
    payload.run_request.run_policy = opts.runPolicy;
    payload.run_request.existing_data_policy = opts.existingDataPolicy;
    payload.run_request.roi_cache_policy = opts.roiCachePolicy;
    payload.run_request.paths = struct('path_mappings', pathMappings);
    payload.execution = struct( ...
        'requested_mode', opts.requestedMode, ...
        'allow_gui', opts.allowGUI, ...
        'interactive', opts.interactive);
end

function [bundleRoot, manifestPath, pipelineJsonPath] = localResolveBundle(bundlePath)
    bundlePath = char(string(bundlePath));
    if exist(bundlePath, 'file') == 2
        [folder, name, ext] = fileparts(bundlePath);
        if strcmpi([name ext], 'export_manifest.json')
            manifestPath = bundlePath;
            bundleRoot = folder;
        else
            pipelineJsonPath = bundlePath;
            bundleRoot = fileparts(fileparts(bundlePath));
            manifestPath = fullfile(bundleRoot, 'export_manifest.json');
            return;
        end
    else
        bundleRoot = bundlePath;
        manifestPath = fullfile(bundleRoot, 'export_manifest.json');
    end

    if exist(manifestPath, 'file') ~= 2
        error('pipelineBundleRunPayload:MissingManifest', 'export_manifest.json not found: %s', manifestPath);
    end
    manifest = jsondecode(fileread(manifestPath));
    relJson = char(string(manifest.pipeline.bundlePipelinePath));
    if localIsAbsolutePath(relJson)
        pipelineJsonPath = relJson;
    else
        pipelineJsonPath = fullfile(bundleRoot, relJson);
    end
end

function nodeParams = localNormalizeNodeParams(value)
    nodeParams = struct('id', {}, 'params', {});
    if isempty(value)
        return;
    end
    if isstruct(value) && isfield(value, 'id') && isfield(value, 'params')
        nodeParams = value;
        return;
    end
    if iscell(value)
        for i = 1:numel(value)
            if isstruct(value{i}) && isfield(value{i}, 'id') && isfield(value{i}, 'params')
                nodeParams(end+1) = value{i}; %#ok<AGROW>
            end
        end
    end
end

function mappings = localNormalizeMappings(value)
    mappings = struct('localRoot', {}, 'remoteRoot', {});
    if isempty(value) || ~isstruct(value)
        return;
    end
    for i = 1:numel(value)
        if isfield(value(i), 'localRoot') && isfield(value(i), 'remoteRoot')
            mappings(end+1).localRoot = char(string(value(i).localRoot)); %#ok<AGROW>
            mappings(end).remoteRoot = char(string(value(i).remoteRoot));
        elseif isfield(value(i), 'local_root') && isfield(value(i), 'remote_root')
            mappings(end+1).localRoot = char(string(value(i).local_root)); %#ok<AGROW>
            mappings(end).remoteRoot = char(string(value(i).remote_root));
        end
    end
end

function out = localCellText(value)
    if isempty(value)
        out = {};
    elseif iscell(value)
        out = cellfun(@(x) char(string(x)), value(:)', 'UniformOutput', false);
    elseif isstring(value)
        out = cellstr(value(:)');
    else
        out = {char(string(value))};
    end
end

function tf = localIsAbsolutePath(pathText)
    pathText = char(string(pathText));
    tf = startsWith(pathText, '/') || startsWith(pathText, '\\') || ...
        ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]', 'once'));
end
