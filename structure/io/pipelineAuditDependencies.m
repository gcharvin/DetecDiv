function report = pipelineAuditDependencies(pipeIn, varargin)
% pipelineAuditDependencies  Inspect pipeline module dependencies and path mobility.
%
%   report = pipelineAuditDependencies(pipeIn, ...)
%
% Supported inputs:
%   - pipeline object
%   - pipeline folder
%   - path to pipeline.json or export_manifest.json
%
% Name/value options:
%   'ProjectRoot'      optional project anchor for future use
%   'Mode'             descriptive mode string: save, migrate, run, repair
%   'TargetHost'       optional target host label for diagnostics
%   'Strict'           logical flag, currently informational
%   'IncludeDerived'   logical, default true
%   'Context'          optional pipeline execution context for path mappings
%   'Hub'              optional Hub settings struct for path mappings
%
% The function is intentionally read-only. It classifies module references as
% embedded, linked, derived, or ephemeral and reports whether required
% inference assets appear resolvable on the current machine.

    opts = parseOptions(varargin{:});
    [pipeObj, spec, templateRoot, sourceLabel] = normalizePipelineInputLocal(pipeIn);

    report = struct();
    report.status = 'ok';
    report.mode = opts.Mode;
    report.targetHost = opts.TargetHost;
    report.source = sourceLabel;
    report.pipelineName = char(string(getFieldOrDefault(spec, 'name', 'pipeline')));
    report.pipelineRoot = templateRoot;
    report.summary = struct();
    report.dependencies = struct([]);
    report.errors = {};
    report.warnings = {};
    report.suggestedFixes = {};

    nodes = getFieldOrDefault(spec, 'nodes', struct([]));
    if isempty(nodes)
        report.pipelineStatus = 'portable';
        report.summary = buildSummary(report.dependencies);
        return;
    end

    deps = struct([]);
    for i = 1:numel(nodes)
        dep = auditSingleNode(nodes(i), i, templateRoot, opts, pipeObj);
        if ~opts.IncludeDerived && any(strcmp(dep.dependency_mode, {'derived','ephemeral'}))
            continue;
        end
        if isempty(deps)
            deps = dep;
        else
            deps(end+1) = dep; %#ok<AGROW>
        end
    end
    report.dependencies = deps;
    report.summary = buildSummary(deps);
    report.pipelineStatus = classifyPipelineStatus(report.summary);

    if report.summary.malformed_count > 0
        report.status = 'warning';
        report.errors{end+1} = sprintf('%d dependency record(s) are malformed.', report.summary.malformed_count);
    end
    if report.summary.required_missing_count > 0
        report.status = 'warning';
        report.errors{end+1} = sprintf('%d required dependency(ies) are unresolved.', report.summary.required_missing_count);
    end
    if report.summary.legacy_count > 0
        report.warnings{end+1} = sprintf('%d legacy absolute-path dependency(ies) remain.', report.summary.legacy_count);
    end
    if report.summary.rewrite_candidate_count > 0
        report.suggestedFixes{end+1} = sprintf('%d embedded dependency path(s) can be rewritten relative to the pipeline root.', report.summary.rewrite_candidate_count);
    end
end

function dep = auditSingleNode(node, idx, templateRoot, opts, pipeObj) %#ok<INUSD>
    contract = getNodeExportContractLocal(node, opts);
    source = resolveNodeSourceLocal(node, templateRoot, opts);
    nodeId = char(string(getFieldOrDefault(node, 'id', sprintf('node_%d', idx))));
    nodeType = lower(char(string(getFieldOrDefault(node, 'type', ''))));
    referenceConfigured = ~isempty(source.configuredPath) || ~isempty(source.configuredId);
    pathExists = ~isempty(source.path) && exist(source.path, 'dir') == 7;
    pathIsRelative = ~isempty(source.configuredPath) && ~isAbsolutePathLocal(source.configuredPath);
    pathUnderPipeline = pathExists && ~isempty(templateRoot) && isSubPathLocal(source.path, templateRoot);
    requiredForRun = contract.supports.definitionAssets || ...
        (contract.supports.inferenceAssets && referenceConfigured);
    malformed = false;
    issues = {};
    warnings = {};

    inferenceAssets = struct('count', 0, 'sample', {{}});
    trainingAssets = struct('count', 0, 'sample', {{}});
    definitionAssets = struct('count', 0, 'sample', {{}});

    if contract.supports.inferenceAssets && pathExists
        files = collectMatchingAssetsLocal(source.path, contract.inference.include, contract.exclude, source.id);
        inferenceAssets = summarizeFiles(files);
    end
    if contract.supports.trainingAssets && pathExists
        files = collectMatchingAssetsLocal(source.path, contract.training.include, contract.exclude, source.id);
        trainingAssets = summarizeFiles(files);
    end
    if contract.supports.definitionAssets
        definitionAssets = inspectDefinitionAssetsLocal(node, templateRoot, opts);
    end

    if referenceConfigured && isempty(source.configuredId)
        malformed = true;
        issues{end+1} = 'Reference path configured without module id.';
    end
    if contract.supports.inferenceAssets && referenceConfigured && ~pathExists
        issues{end+1} = 'Configured source folder does not exist.';
    end
    if contract.supports.inferenceAssets && pathExists && inferenceAssets.count == 0
        issues{end+1} = 'No inference assets found in source folder.';
    end
    if contract.supports.definitionAssets && definitionAssets.count == 0
        warnings{end+1} = 'No definition assets were detected for this node.';
    end

    dependencyMode = inferDependencyModeLocal(contract, referenceConfigured, pathUnderPipeline, pathExists);
    locatorKind = inferLocatorKindLocal(source);
    isResolved = true;
    if requiredForRun
        if contract.supports.inferenceAssets
            isResolved = pathExists && inferenceAssets.count > 0;
        elseif contract.supports.definitionAssets
            isResolved = definitionAssets.count > 0;
        end
    end

    normalizationAction = '';
    normalizedRef = char(string(source.configuredPath));
    if strcmp(dependencyMode, 'embedded') && ~isempty(source.configuredPath) && isAbsolutePathLocal(source.configuredPath) && pathUnderPipeline
        normalizedRef = relativePathFromToLocal(templateRoot, source.path);
        if ~strcmp(normalizedRef, source.configuredPath)
            normalizationAction = 'rewrite_relative_module_path';
        end
    end

    dep = struct();
    dep.node_index = idx;
    dep.node_id = nodeId;
    dep.node_type = nodeType;
    dep.module_id = source.id;
    dep.module_kind = source.kind;
    dep.dependency_mode = dependencyMode;
    dep.locator_kind = locatorKind;
    dep.required_for = ifelseCell(requiredForRun, {'run'}, {});
    dep.is_required_for_run = requiredForRun;
    dep.is_resolved = isResolved;
    dep.is_portable = strcmp(dependencyMode, 'embedded') || strcmp(dependencyMode, 'derived');
    dep.is_legacy = strcmp(locatorKind, 'external_path');
    dep.is_malformed = malformed;
    dep.source = struct( ...
        'configured_path', char(string(source.configuredPath)), ...
        'resolved_path', char(string(source.path)), ...
        'path_exists', pathExists, ...
        'path_is_relative', pathIsRelative, ...
        'path_under_pipeline', pathUnderPipeline, ...
        'module_id', source.id, ...
        'module_kind', source.kind);
    dep.assets = struct( ...
        'inference', inferenceAssets, ...
        'training', trainingAssets, ...
        'definition', definitionAssets);
    dep.normalization = struct( ...
        'action', normalizationAction, ...
        'normalized_reference', normalizedRef);
    dep.issues = issues;
    dep.warnings = warnings;
    dep.contract = contract.supports;
end

function opts = parseOptions(varargin)
    opts = struct( ...
        'ProjectRoot', '', ...
        'Mode', 'inspect', ...
        'TargetHost', '', ...
        'Strict', false, ...
        'IncludeDerived', true, ...
        'Context', struct(), ...
        'Hub', struct());

    if mod(numel(varargin), 2) ~= 0
        error('pipelineAuditDependencies:Args', 'Arguments must be Name/Value pairs.');
    end
    for i = 1:2:numel(varargin)
        name = lower(char(string(varargin{i})));
        value = varargin{i+1};
        switch name
            case 'projectroot'
                opts.ProjectRoot = char(string(value));
            case 'mode'
                opts.Mode = char(string(value));
            case 'targethost'
                opts.TargetHost = char(string(value));
            case 'strict'
                opts.Strict = logical(value);
            case 'includederived'
                opts.IncludeDerived = logical(value);
            case 'context'
                if isstruct(value)
                    opts.Context = value;
                end
            case 'hub'
                if isstruct(value)
                    opts.Hub = value;
                end
            otherwise
                error('pipelineAuditDependencies:UnknownOption', 'Unknown option "%s".', name);
        end
    end
end

function [pipeObj, spec, templateRoot, sourceLabel] = normalizePipelineInputLocal(pipeIn)
    pipeObj = [];
    spec = struct();
    templateRoot = '';
    sourceLabel = '';

    if isa(pipeIn, 'pipeline')
        pipeObj = pipeIn;
        spec.name = pipeIn.strid;
        spec.id = pipeIn.id;
        spec.version = pipeIn.version;
        spec.description = pipeIn.description;
        spec.nodes = pipeIn.nodes;
        spec.edges = pipeIn.edges;
        spec.runProfiles = pipeIn.runProfiles;
        spec.runState = pipeIn.runState;
        templateRoot = char(string(pipeIn.path));
        sourceLabel = templateRoot;
        return;
    end

    if ischar(pipeIn) || isstring(pipeIn)
        inputPath = char(string(pipeIn));
        [pipeObj, msg] = pipelineLoad(inputPath);
        if isempty(pipeObj)
            error('pipelineAuditDependencies:LoadFailed', 'Could not load pipeline: %s', msg);
        end
        [pipeObj, spec, templateRoot, sourceLabel] = normalizePipelineInputLocal(pipeObj);
        if isempty(sourceLabel)
            sourceLabel = inputPath;
        end
        return;
    end

    if isstruct(pipeIn) && isfield(pipeIn, 'nodes')
        spec = pipeIn;
        templateRoot = char(string(getFieldOrDefault(pipeIn, 'path', '')));
        if ~isempty(templateRoot) && exist(templateRoot, 'file') == 2
            templateRoot = fileparts(templateRoot);
        end
        sourceLabel = templateRoot;
        return;
    end

    error('pipelineAuditDependencies:UnsupportedInput', 'Unsupported input type: %s', class(pipeIn));
end

function summary = buildSummary(deps)
    summary = struct( ...
        'dependency_count', 0, ...
        'embedded_count', 0, ...
        'linked_count', 0, ...
        'derived_count', 0, ...
        'ephemeral_count', 0, ...
        'required_count', 0, ...
        'required_missing_count', 0, ...
        'legacy_count', 0, ...
        'malformed_count', 0, ...
        'rewrite_candidate_count', 0);

    if isempty(deps)
        return;
    end

    summary.dependency_count = numel(deps);
    for i = 1:numel(deps)
        mode = char(string(deps(i).dependency_mode));
        switch mode
            case 'embedded'
                summary.embedded_count = summary.embedded_count + 1;
            case 'linked'
                summary.linked_count = summary.linked_count + 1;
            case 'derived'
                summary.derived_count = summary.derived_count + 1;
            case 'ephemeral'
                summary.ephemeral_count = summary.ephemeral_count + 1;
        end
        if logical(deps(i).is_required_for_run)
            summary.required_count = summary.required_count + 1;
            if ~logical(deps(i).is_resolved)
                summary.required_missing_count = summary.required_missing_count + 1;
            end
        end
        if logical(deps(i).is_legacy)
            summary.legacy_count = summary.legacy_count + 1;
        end
        if logical(deps(i).is_malformed)
            summary.malformed_count = summary.malformed_count + 1;
        end
        if ~isempty(char(string(deps(i).normalization.action)))
            summary.rewrite_candidate_count = summary.rewrite_candidate_count + 1;
        end
    end
end

function status = classifyPipelineStatus(summary)
    if summary.malformed_count > 0
        status = 'broken';
        return;
    end
    if summary.required_missing_count > 0
        if summary.linked_count > 0
            status = 'linked_unresolvable';
        else
            status = 'broken';
        end
        return;
    end
    if summary.linked_count > 0
        status = 'linked_resolvable';
        return;
    end
    status = 'portable';
end

function mode = inferDependencyModeLocal(contract, referenceConfigured, pathUnderPipeline, pathExists)
    if contract.supports.inferenceAssets || contract.supports.trainingAssets || contract.supports.trainingRois
        if ~referenceConfigured
            if contract.supports.definitionAssets
                mode = 'embedded';
            else
                mode = 'derived';
            end
            return;
        end
        if pathUnderPipeline
            mode = 'embedded';
            return;
        end
        if pathExists || referenceConfigured
            mode = 'linked';
            return;
        end
    end

    if contract.supports.definitionAssets
        mode = 'embedded';
    else
        mode = 'ephemeral';
    end
end

function locatorKind = inferLocatorKindLocal(source)
    if isempty(source.configuredPath)
        locatorKind = '';
        return;
    end
    if isAbsolutePathLocal(source.configuredPath)
        locatorKind = 'external_path';
    else
        locatorKind = 'anchored_path';
    end
end

function summary = inspectDefinitionAssetsLocal(node, templateRoot, opts)
    summary = struct('count', 0, 'sample', {{}});
    params = getFieldOrDefault(node, 'params', struct());
    files = {};
    embedded = {};

    if isstruct(params)
        if isfield(params, 'pattern') && isstruct(params.pattern)
            files = [files, extractPatchFilesLocal(params.pattern, templateRoot, opts)]; %#ok<AGROW>
            if hasEmbeddedDefinitionLocal(params.pattern)
                embedded{end+1} = 'embedded:pattern'; %#ok<AGROW>
            end
        end
        if isfield(params, 'patternList')
            list = params.patternList;
            if isstruct(list)
                for i = 1:numel(list)
                    files = [files, extractPatchFilesLocal(list(i), templateRoot, opts)]; %#ok<AGROW>
                    if hasEmbeddedDefinitionLocal(list(i))
                        embedded{end+1} = sprintf('embedded:patternList(%d)', i); %#ok<AGROW>
                    end
                end
            end
        end
    end

    files = files(cellfun(@(p) exist(p, 'file') == 2, files));
    summary = summarizeFiles(unique(files, 'stable'));
    if ~isempty(embedded)
        sample = [summary.sample unique(embedded, 'stable')]; %#ok<AGROW>
        summary.count = summary.count + numel(unique(embedded, 'stable'));
        summary.sample = sample(1:min(numel(sample), 5));
    end
end

function files = extractPatchFilesLocal(pat, templateRoot, opts)
    files = {};
    if ~isstruct(pat)
        return;
    end
    keys = {'patchFile', 'patchPreviewFile'};
    for i = 1:numel(keys)
        key = keys{i};
        if isfield(pat, key) && ~isempty(pat.(key))
            fullp = char(string(pat.(key)));
            if ~isAbsolutePathLocal(fullp) && ~isempty(templateRoot)
                fullp = fullfile(templateRoot, fullp);
            end
            fullp = mapPathForAuditLocal(fullp, opts, 'server');
            files{end+1} = fullp; %#ok<AGROW>
        end
    end
end

function tf = hasEmbeddedDefinitionLocal(value)
    tf = false;
    if ~isstruct(value) || isempty(fieldnames(value))
        return;
    end
    fileKeys = {'patchFile', 'patchPreviewFile'};
    names = fieldnames(value);
    tf = any(~ismember(names, fileKeys));
end

function out = summarizeFiles(files)
    out = struct('count', 0, 'sample', {{}});
    if isempty(files)
        return;
    end
    files = unique(files, 'stable');
    out.count = numel(files);
    out.sample = files(1:min(numel(files), 5));
end

function source = resolveNodeSourceLocal(node, templateRoot, opts)
    source = struct('path', '', 'configuredPath', '', 'configuredId', '', 'id', '', 'kind', lower(char(string(getFieldOrDefault(node, 'type', '')))));
    params = getFieldOrDefault(node, 'params', struct());
    if isstruct(params)
        if isfield(params, 'modulePath') && ~isempty(params.modulePath)
            source.configuredPath = char(string(params.modulePath));
            source.path = source.configuredPath;
        end
        if isfield(params, 'moduleId') && ~isempty(params.moduleId)
            source.configuredId = char(string(params.moduleId));
            source.id = source.configuredId;
        end
        if isfield(params, 'moduleKind') && ~isempty(params.moduleKind)
            source.kind = lower(char(string(params.moduleKind)));
        end
    end

    origin = getFieldOrDefault(node, 'origin', struct());
    if (isempty(source.path) || isempty(source.id)) && isstruct(origin)
        if isempty(source.path) && isfield(origin, 'path') && ~isempty(origin.path)
            source.configuredPath = char(string(origin.path));
            source.path = source.configuredPath;
        end
        if isempty(source.id) && isfield(origin, 'id') && ~isempty(origin.id)
            source.configuredId = char(string(origin.id));
            source.id = source.configuredId;
        end
        if isfield(origin, 'kind') && ~isempty(origin.kind)
            source.kind = lower(char(string(origin.kind)));
        end
    end

    if isempty(source.id)
        source.id = char(string(getFieldOrDefault(node, 'id', 'module')));
    end
    if ~isempty(source.path) && ~isAbsolutePathLocal(source.path) && ~isempty(templateRoot)
        source.path = fullfile(templateRoot, source.path);
    end
    if ~isempty(source.path)
        source.path = mapPathForAuditLocal(source.path, opts, 'server');
    end
end

function contract = getNodeExportContractLocal(node, opts)
    nodeType = lower(char(string(getFieldOrDefault(node, 'type', ''))));
    pkg = lower(char(string(getFieldOrDefault(node, 'pkg', ''))));

    contract = struct();
    contract.supports = struct('definitionAssets', false, 'inferenceAssets', false, 'trainingAssets', false, 'trainingRois', false);
    contract.definition = struct('include', {{}});
    contract.inference = struct('include', {{}});
    contract.training = struct('include', {{}});
    contract.exclude = {'tmp.mat', 'results.mat', 'runner_stdout.txt', 'runner_stderr.txt', 'runner_live.log', '.log', '.tmp'};

    switch nodeType
        case {'roiidentify','roipattern'}
            contract.supports.definitionAssets = true;
            contract.definition.include = {'patternPatch'};

        case 'classifier'
            contract.supports.inferenceAssets = true;
            contract.supports.trainingAssets = true;
            contract.supports.trainingRois = true;
            if strcmp(pkg, 'cellposesam')
                % CellposeSAM can run from Python package defaults ("sam") or
                % from package-local fine-tuned weights under modulePath/models.
                % Only the latter is a required portable artifact bundle.
                hasLocalModel = cellposeHasLocalModelAssetLocal(node, opts);
                contract.supports.inferenceAssets = hasLocalModel;
                contract.supports.trainingAssets = false;
                contract.supports.trainingRois = false;
                contract.inference.include = { ...
                    'file:%ID%_classification.mat', ...
                    'dir:models', ...
                    'glob:**/*.pth', ...
                    'glob:**/*.pt', ...
                    'glob:**/*.onnx', ...
                    'glob:**/*.yaml', ...
                    'glob:**/*.yml'};
            elseif strcmp(pkg, 'cnn_lstm')
                contract.inference.include = { ...
                    'file:%ID%_classification.mat', ...
                    'file:%ID%.mat'};
                contract.training.include = { ...
                    'file:netCNN_%ID%.mat', ...
                    'file:netLSTM_%ID%.mat', ...
                    'file:%ID%_image_classifier_activations.mat', ...
                    'file:CNN_info.mat', ...
                    'file:LSTM_info.mat', ...
                    'file:%ID%_framebank.mat', ...
                    'file:trainingParam.mat', ...
                    'glob:**/*framebank*.h5', ...
                    'glob:**/*framebank*.mat', ...
                    'dir:trainingdataset', ...
                    'dir:TrainingValidation', ...
                    'dir:runs'};
            else
                contract.inference.include = { ...
                    'file:%ID%_classification.mat', ...
                    'file:%ID%.mat', ...
                    'dir:models', ...
                    'dir:model', ...
                    'dir:weights', ...
                    'glob:**/*.pth', ...
                    'glob:**/*.pt', ...
                    'glob:**/*.onnx', ...
                    'glob:**/*.keras', ...
                    'glob:**/*.yaml', ...
                    'glob:**/*.yml'};
                contract.training.include = { ...
                    'glob:**/*framebank*.h5', ...
                    'glob:**/*dataset*', ...
                    'glob:**/*manifest*', ...
                    'dir:framebank', ...
                    'dir:training', ...
                    'dir:trainingdataset', ...
                    'dir:annotations'};
            end

        case 'processor'
            contract.supports.inferenceAssets = true;
            contract.inference.include = { ...
                'file:%ID%_processor.mat', ...
                'file:%ID%.mat', ...
                'dir:models', ...
                'dir:weights'};
    end
end

function tf = cellposeHasLocalModelAssetLocal(node, opts)
    tf = false;
    params = getFieldOrDefault(node, 'params', struct());
    if ~isstruct(params) || ~isfield(params, 'modulePath') || isempty(params.modulePath)
        return;
    end
    modulePath = mapPathForAuditLocal(char(string(params.modulePath)), opts, 'server');
    if exist(modulePath, 'dir') ~= 7
        return;
    end
    moduleId = char(string(getFieldOrDefault(params, 'moduleId', '')));
    modelDir = fullfile(modulePath, 'models');
    candidates = {};
    if ~isempty(moduleId)
        candidates{end+1} = fullfile(modelDir, moduleId); %#ok<AGROW>
        candidates{end+1} = fullfile(modelDir, [moduleId '.pth']); %#ok<AGROW>
        candidates{end+1} = fullfile(modelDir, [moduleId '.pt']); %#ok<AGROW>
        candidates{end+1} = fullfile(modelDir, [moduleId '.onnx']); %#ok<AGROW>
    end
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file') == 2
            tf = true;
            return;
        end
    end
    if exist(modelDir, 'dir') == 7
        files = [dir(fullfile(modelDir, '*.pth')); dir(fullfile(modelDir, '*.pt')); dir(fullfile(modelDir, '*.onnx'))];
        tf = ~isempty(files);
    end
end

function files = collectMatchingAssetsLocal(rootPath, rules, excludeRules, sourceId)
    files = {};
    if isempty(rootPath) || exist(rootPath, 'dir') ~= 7 || isempty(rules)
        return;
    end
    rootPath = char(string(rootPath));
    for i = 1:numel(rules)
        rule = char(string(rules{i}));
        if startsWith(rule, 'file:')
            rel = strrep(rule(6:end), '%ID%', char(string(sourceId)));
            matches = dir(fullfile(rootPath, rel));
        elseif startsWith(rule, 'dir:')
            rel = rule(5:end);
            target = fullfile(rootPath, rel);
            if exist(target, 'dir') == 7
                matches = dir(fullfile(target, '**', '*'));
            else
                matches = struct([]);
            end
        elseif startsWith(rule, 'glob:')
            pattern = rule(6:end);
            matches = dir(fullfile(rootPath, pattern));
        else
            matches = struct([]);
        end
        if isempty(matches)
            continue;
        end
        matches = matches(~[matches.isdir]);
        for j = 1:numel(matches)
            fullp = fullfile(matches(j).folder, matches(j).name);
            if isExcludedAssetLocal(fullp, excludeRules)
                continue;
            end
            files{end+1} = fullp; %#ok<AGROW>
        end
    end
    files = unique(files, 'stable');
end

function tf = isExcludedAssetLocal(pathText, excludeRules)
    tf = false;
    leaf = lower(char(string(getLeafNameLocal(pathText))));
    for i = 1:numel(excludeRules)
        rule = lower(char(string(excludeRules{i})));
        if startsWith(rule, '.')
            if endsWith(leaf, rule)
                tf = true;
                return;
            end
        elseif strcmp(leaf, rule)
            tf = true;
            return;
        end
    end
end

function tf = isSubPathLocal(candidatePath, rootPath)
    tf = false;
    if isempty(candidatePath) || isempty(rootPath)
        return;
    end
    candidate = normalizePathLocal(candidatePath);
    root = normalizePathLocal(rootPath);
    if isempty(candidate) || isempty(root)
        return;
    end
    tf = strcmp(candidate, root) || startsWith(candidate, [root filesep]) || startsWith(candidate, [strrep(root, '\', '/') '/']);
end

function pathOut = mapPathForAuditLocal(pathIn, opts, preferredDirection)
    pathOut = char(string(pathIn));
    if isempty(pathOut) || exist('detecdiv_paths_map_module_path', 'file') ~= 2
        return;
    end

    ctx = auditMappingContextLocal(opts);
    candidates = {pathOut};
    try
        [serverPath, serverMapped] = detecdiv_paths_map_module_path(pathOut, ctx, 'server');
        if serverMapped
            candidates{end+1} = serverPath; %#ok<AGROW>
        end
    catch
        serverPath = '';
        serverMapped = false;
    end
    try
        [localPath, localMapped] = detecdiv_paths_map_module_path(pathOut, ctx, 'local');
        if localMapped
            candidates{end+1} = localPath; %#ok<AGROW>
        end
    catch
        localPath = '';
        localMapped = false;
    end

    for i = 1:numel(candidates)
        candidate = char(string(candidates{i}));
        if exist(candidate, 'dir') == 7 || exist(candidate, 'file') == 2
            pathOut = candidate;
            return;
        end
    end

    if nargin >= 3 && any(strcmpi(preferredDirection, {'server','remote'})) && serverMapped
        pathOut = serverPath;
    elseif nargin >= 3 && any(strcmpi(preferredDirection, {'local','client'})) && localMapped
        pathOut = localPath;
    elseif ~ispc && serverMapped
        pathOut = serverPath;
    elseif ispc && localMapped
        pathOut = localPath;
    end
end

function ctx = auditMappingContextLocal(opts)
    ctx = struct();
    try
        if isfield(opts, 'Context') && isstruct(opts.Context)
            ctx = opts.Context;
        end
    catch
        ctx = struct();
    end
    try
        if isfield(opts, 'Hub') && isstruct(opts.Hub) && ~isempty(fieldnames(opts.Hub))
            ctx.hub = opts.Hub;
        end
    catch
    end
end

function out = normalizePathLocal(pathText)
    out = char(string(pathText));
    if isempty(out)
        return;
    end
    try
        out = char(java.io.File(out).getCanonicalPath());
    catch
        out = char(string(pathText));
    end
    out = strrep(out, '/', filesep);
    out = regexprep(out, [regexptranslate('escape', filesep) '+$'], '');
    if ispc
        out = lower(out);
    end
end

function rel = relativePathFromToLocal(basePath, targetPath)
    base = string(java.io.File(char(string(basePath))).getCanonicalPath());
    target = string(java.io.File(char(string(targetPath))).getCanonicalPath());
    rel = char(java.nio.file.Paths.get(char(base)).relativize(java.nio.file.Paths.get(char(target))).toString());
    rel = strrep(rel, '\', '/');
end

function tf = isAbsolutePathLocal(p)
    tf = false;
    p = char(string(p));
    if isempty(p)
        return;
    end
    tf = startsWith(p, '/') || ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
end

function out = getFieldOrDefault(S, name, default)
    if isstruct(S) && isfield(S, name)
        out = S.(name);
    else
        out = default;
    end
end

function out = ifelseCell(tf, a, b)
    if tf
        out = a;
    else
        out = b;
    end
end

function leaf = getLeafNameLocal(pathText)
    [~, leaf, ext] = fileparts(char(string(pathText)));
    leaf = [leaf ext];
end
