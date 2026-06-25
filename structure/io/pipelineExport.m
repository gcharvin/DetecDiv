function [bundlePath, manifest] = pipelineExport(pipeIn, bundlePath, varargin)
% pipelineExport  Export a pipeline as a self-contained bundle.
%
%   [bundlePath, manifest] = pipelineExport(pipeIn, bundlePath, ...)
%
% Required:
%   pipeIn      pipeline object, pipeline folder/json path, or struct with nodes/edges
%   bundlePath  target export directory
%
% Name/value options:
%   'includeWeights'       logical (default true)
%   'includeTrainingData'  logical (default false)
%   'includeTrainingRois'  logical (default false)
%   'includeRunResults'    logical (default false)
%   'includePlugins'       logical (default true)
%   'rebaseOutputPaths'    logical (default true)
%   'runObjects'           pipelineRun array/cell (default [])
%   'projectObj'           shallow project object used to materialize ROI-pattern assets
%   'overwrite'            logical (default false)
%   'progressFcn'          callback @(action, info) for UI progress

    if nargin < 1 || isempty(pipeIn)
        error('pipelineExport:MissingPipeline', 'A pipeline object or path is required.');
    end
    if nargin < 2 || isempty(bundlePath)
        error('pipelineExport:MissingTarget', 'A bundle output folder is required.');
    end

    opts = struct( ...
        'includeWeights', true, ...
        'includeTrainingData', false, ...
        'includeTrainingRois', false, ...
        'includeRunResults', false, ...
        'includePlugins', true, ...
        'rebaseOutputPaths', true, ...
        'runObjects', [], ...
        'projectObj', [], ...
        'overwrite', false, ...
        'progressFcn', []);

    if mod(numel(varargin), 2) ~= 0
        error('pipelineExport:Args', 'Arguments must be Name/Value pairs.');
    end
    for k = 1:2:numel(varargin)
        name = lower(char(string(varargin{k})));
        value = varargin{k+1};
        switch name
            case 'includeweights'
                opts.includeWeights = logical(value);
            case 'includetrainingdata'
                opts.includeTrainingData = logical(value);
            case 'includetrainingrois'
                opts.includeTrainingRois = logical(value);
            case 'includerunresults'
                opts.includeRunResults = logical(value);
            case 'includeplugins'
                opts.includePlugins = logical(value);
            case 'rebaseoutputpaths'
                opts.rebaseOutputPaths = logical(value);
            case 'runobjects'
                opts.runObjects = value;
            case {'projectobj','shallowobj'}
                opts.projectObj = value;
            case 'overwrite'
                opts.overwrite = logical(value);
            case 'progressfcn'
                opts.progressFcn = value;
            otherwise
                error('pipelineExport:UnknownOption', 'Unknown option "%s".', name);
        end
    end

    [pipeObj, pipeSpec, templateName, templatePath] = normalizePipelineInput(pipeIn);

    bundlePath = char(string(bundlePath));
    if exist(bundlePath, 'dir') == 7
        if ~opts.overwrite
            error('pipelineExport:TargetExists', 'Export folder already exists: %s', bundlePath);
        end
        rmdir(bundlePath, 's');
    end
    mkdir(bundlePath);

    pipelineDir = fullfile(bundlePath, 'pipeline');
    assetsDir = fullfile(bundlePath, 'assets');
    runList = normalizeRunList(opts.runObjects);
    runsDir = fullfile(bundlePath, 'runs');
    progressPlan = estimateExportProgressPlan(pipeSpec, opts, templatePath);
    notifyProgress(opts, 'begin', struct( ...
        'totalUnits', progressPlan.totalUnits, ...
        'bundlePath', bundlePath, ...
        'nodeCount', numel(getFieldOrDefault(pipeSpec, 'nodes', struct([]))), ...
        'runCount', progressPlan.runCount));
    notifyProgress(opts, 'phase', struct('message', 'Preparing export folders...'));
    ensureDir(pipelineDir);
    ensureDir(assetsDir);
    if opts.includeRunResults && ~isempty(runList)
        ensureDir(runsDir);
    end

    exportedSpec = pipeSpec;
    if ~isfield(exportedSpec, 'nodes') || isempty(exportedSpec.nodes)
        exportedSpec.nodes = struct([]);
    end
    if ~isfield(exportedSpec, 'edges') || isempty(exportedSpec.edges)
        exportedSpec.edges = struct([]);
    end

    manifest = struct();
    manifest.formatVersion = '1.0';
    manifest.createdAt = char(datetime('now'));
    manifest.pipeline = struct( ...
        'name', char(string(templateName)), ...
        'sourcePath', char(string(templatePath)), ...
        'bundlePipelinePath', './pipeline/pipeline.json');
    manifest.options = rmfield(opts, {'runObjects', 'projectObj'});
    manifest.nodes = struct([]);
    manifest.runs = struct([]);

    for i = 1:numel(exportedSpec.nodes)
        node = exportedSpec.nodes(i);
        notifyProgress(opts, 'node', struct( ...
            'index', i, ...
            'count', numel(exportedSpec.nodes), ...
            'id', char(string(getFieldOrDefault(node, 'id', sprintf('node_%d', i)))), ...
            'type', char(string(getFieldOrDefault(node, 'type', 'node'))), ...
            'message', sprintf('Processing node %d/%d: %s', i, numel(exportedSpec.nodes), char(string(getFieldOrDefault(node, 'id', sprintf('node_%d', i)))))));
        [nodeSummary, exportedNode] = exportNodeBundle(node, opts, bundlePath, pipelineDir, assetsDir, templatePath);
        manifest.nodes = appendStruct(manifest.nodes, nodeSummary);
        exportedSpec.nodes = assignStructElement(exportedSpec.nodes, i, exportedNode);
    end

    pipelineJson = fullfile(pipelineDir, 'pipeline.json');
    notifyProgress(opts, 'write', struct('message', 'Writing pipeline definition...', 'path', pipelineJson));
    writeJson(pipelineJson, pipelineStructFromSpec(exportedSpec, pipeObj, templateName));

    if opts.includeRunResults
        for i = 1:numel(runList)
            runObj = runList(i);
            runSummary = exportRunBundle(runObj, runsDir, opts);
            manifest.runs = appendStruct(manifest.runs, runSummary);
        end
    end

    manifestPath = fullfile(bundlePath, 'export_manifest.json');
    notifyProgress(opts, 'write', struct('message', 'Writing export manifest...', 'path', manifestPath));
    writeJson(manifestPath, manifest);
    notifyProgress(opts, 'end', struct('bundlePath', bundlePath));
    fprintf('Pipeline export created: %s\n', bundlePath);
end

function [pipeObj, spec, templateName, templatePath] = normalizePipelineInput(pipeIn)
    pipeObj = [];
    templateName = 'pipeline';
    templatePath = '';

    if isa(pipeIn, 'pipeline')
        pipeObj = pipeIn;
        spec = struct();
        spec.nodes = pipeIn.nodes;
        spec.edges = pipeIn.edges;
        if ~isempty(pipeIn.branches)
            spec.branches = pipeIn.branches;
        end
        spec.description = pipeIn.description;
        spec.version = pipeIn.version;
        spec.id = pipeIn.id;
        spec.name = pipeIn.strid;
        spec.runProfiles = pipeIn.runProfiles;
        templateName = pipeIn.strid;
        templatePath = pipeIn.path;
        return;
    end

    if ischar(pipeIn) || isstring(pipeIn)
        [pipeObj, msg] = pipelineLoad(char(string(pipeIn)));
        if isempty(pipeObj)
            error('pipelineExport:LoadFailed', 'Could not load pipeline: %s', msg);
        end
        [pipeObj, spec, templateName, templatePath] = normalizePipelineInput(pipeObj);
        return;
    end

    if isstruct(pipeIn) && isfield(pipeIn, 'nodes')
        spec = pipeIn;
        if isfield(pipeIn, 'name') && ~isempty(pipeIn.name)
            templateName = char(string(pipeIn.name));
        end
        if isfield(pipeIn, 'path') && ~isempty(pipeIn.path)
            templatePath = char(string(pipeIn.path));
        end
        return;
    end

    error('pipelineExport:UnsupportedInput', 'Unsupported pipeline input type: %s', class(pipeIn));
end

function out = pipelineStructFromSpec(spec, pipeObj, templateName)
    out = struct();
    out.name = templateName;
    out.id = getFieldOrDefault(spec, 'id', 1);
    out.version = getFieldOrDefault(spec, 'version', '1.0');
    out.description = getFieldOrDefault(spec, 'description', '');
    out.nodes = getFieldOrDefault(spec, 'nodes', struct([]));
    out.edges = getFieldOrDefault(spec, 'edges', struct([]));
    if isfield(spec, 'branches') && ~isempty(spec.branches)
        out.branches = spec.branches;
    end
    if ~isempty(pipeObj)
        out.runState = pipeObj.runState;
        out.runProfiles = pipeObj.runProfiles;
    else
        out.runState = getFieldOrDefault(spec, 'runState', struct());
        out.runProfiles = getFieldOrDefault(spec, 'runProfiles', struct());
    end
    out.createdAt = '';
    out.updatedAt = char(datetime('now'));
end

function [summary, nodeOut] = exportNodeBundle(node, opts, bundleRoot, pipelineDir, assetsDir, templatePath)
    nodeOut = node;
    contract = getNodeExportContract(node);
    source = resolveNodeExportSource(node, templatePath);

    summary = struct();
    summary.id = char(string(getFieldOrDefault(node, 'id', 'node')));
    summary.type = char(string(getFieldOrDefault(node, 'type', '')));
    summary.pkg = char(string(getFieldOrDefault(node, 'pkg', '')));
    summary.contract = contract;
    summary.source = source;
    summary.exported = struct( ...
        'definition', true, ...
        'definitionAssets', {{}}, ...
        'inferenceAssets', {{}}, ...
        'trainingAssets', {{}}, ...
        'trainingRois', {{}}, ...
        'plugins', {{}}, ...
        'pathRewrites', {{}});
    summary.warnings = {};
    exportFolderName = exportNodeFolderName(summary, source);

    moduleRootDir = fullfile(assetsDir, pluralizeKind(source.kind), exportFolderName);

    if contract.supports.definitionAssets
        targetDir = fullfile(assetsDir, exportAssetSubdir(summary, source, contract), exportFolderName);
        [nodeOut, defCopied, defWarnings] = exportDefinitionAssets(nodeOut, opts, contract, targetDir, pipelineDir, templatePath);
        summary.exported.definitionAssets = defCopied;
        summary.warnings = [summary.warnings, defWarnings];
    end

    if opts.includePlugins
        [nodeOut, pluginCopied, pluginWarnings] = exportNodePlugins(nodeOut, assetsDir, pipelineDir, opts);
        summary.exported.plugins = pluginCopied;
        summary.warnings = [summary.warnings, pluginWarnings];
    end

    if opts.rebaseOutputPaths
        [nodeOut, pathRewrites] = rebaseNodeOutputPaths(nodeOut, pipelineDir);
        summary.exported.pathRewrites = pathRewrites;
    end

    if isempty(source.path) || exist(source.path, 'dir') ~= 7
        if contract.supports.inferenceAssets || contract.supports.trainingAssets || contract.supports.trainingRois
            summary.warnings{end+1} = 'No module source folder was resolved for this node.';
        end
        return;
    end

    relModulePath = '';
    if opts.includeWeights && contract.supports.inferenceAssets
        copied = exportInferenceAssets(source, contract, moduleRootDir, opts);
        summary.exported.inferenceAssets = copied;
        if ~isempty(copied)
            relModulePath = relativePathFromTo(pipelineDir, moduleRootDir);
        end
    end

    if (opts.includeTrainingData || opts.includeTrainingRois) && contract.supports.trainingAssets
        copied = exportTrainingAssets(source, contract, moduleRootDir, opts.includeTrainingRois, opts);
        summary.exported.trainingAssets = copied.training;
        summary.exported.trainingRois = copied.rois;
        if isempty(relModulePath) && (~isempty(copied.training) || ~isempty(copied.rois))
            relModulePath = relativePathFromTo(pipelineDir, moduleRootDir);
        end
    end

    if ~isempty(relModulePath)
        nodeOut = rewriteNodeReferenceForBundle(nodeOut, source, relModulePath);
    end
end

function [nodeOut, copied, warningsOut] = exportNodePlugins(nodeOut, assetsDir, pipelineDir, opts)
    copied = {};
    warningsOut = {};
    params = getFieldOrDefault(nodeOut, 'params', struct());
    if ~isstruct(params)
        return;
    end

    packageDir = '';
    packageRoot = '';
    if isfield(nodeOut, 'customPackageDir') && ~isempty(nodeOut.customPackageDir)
        packageDir = char(string(nodeOut.customPackageDir));
    elseif isfield(params, 'customPackageDir') && ~isempty(params.customPackageDir)
        packageDir = char(string(params.customPackageDir));
    end
    if isfield(nodeOut, 'customPackageRoot') && ~isempty(nodeOut.customPackageRoot)
        packageRoot = char(string(nodeOut.customPackageRoot));
    elseif isfield(params, 'customPackageRoot') && ~isempty(params.customPackageRoot)
        packageRoot = char(string(params.customPackageRoot));
    end
    if isempty(packageDir) && ~isempty(packageRoot) && isfield(nodeOut, 'pkg') && ~isempty(nodeOut.pkg)
        packageDir = fullfile(packageRoot, ['+' char(string(nodeOut.pkg))]);
    end
    if isempty(packageDir) || exist(packageDir, 'dir') ~= 7
        originalPackageDir = packageDir;
        [packageDir, packageRoot, recoveredMsg] = recoverPluginPackageForExport(nodeOut, params, packageDir, packageRoot);
        if isempty(packageDir) || exist(packageDir, 'dir') ~= 7
            if ~isempty(originalPackageDir)
                warningsOut{end+1} = sprintf('Custom package folder was not found: %s', originalPackageDir);
            end
            return;
        end
        if ~isempty(recoveredMsg)
            warningsOut{end+1} = recoveredMsg;
        end
    end

    if isempty(packageRoot)
        packageRoot = fileparts(packageDir);
    end
    if exist(packageRoot, 'dir') ~= 7
        packageRoot = fileparts(packageDir);
    end

    packageLeaf = getLeafNameLocal(packageDir);
    pluginKind = lower(char(string(getFieldOrDefault(nodeOut, 'type', 'plugin'))));
    if strcmp(pluginKind, 'processor')
        pluginKind = 'processor';
    elseif strcmp(pluginKind, 'classifier')
        pluginKind = 'classifier';
    else
        pluginKind = 'module';
    end
    targetRoot = fullfile(assetsDir, 'plugins', pluginKind);
    targetDir = fullfile(targetRoot, packageLeaf);
    ensureDir(targetRoot);
    if exist(targetDir, 'dir') == 7
        rmdir(targetDir, 's');
    end
    [ok, msg] = copyfile(packageDir, targetDir);
    if ~ok
        warningsOut{end+1} = sprintf('Could not copy custom package %s: %s', packageDir, msg);
        return;
    end

    copied = listFilesRelativeToBundle(targetDir, fileparts(assetsDir));
    notifyProgress(opts, 'file', struct( ...
        'sourcePath', packageDir, ...
        'targetPath', targetDir, ...
        'message', sprintf('Copying plugin package: %s', packageLeaf)));

    nodeOut.customPackageRoot = relativePathFromTo(pipelineDir, targetRoot);
    nodeOut.customPackageDir = relativePathFromTo(pipelineDir, targetDir);
    nodeOut.customPackageLoadedAt = '';
    params = removeLegacyCustomPackageParams(params);
    nodeOut.params = params;
end

function [packageDir, packageRoot, msg] = recoverPluginPackageForExport(node, params, packageDir, packageRoot)
    msg = '';
    pkg = char(string(getFieldOrDefault(node, 'pkg', '')));
    if isempty(pkg) && isstruct(params) && isfield(params, 'pkg') && ~isempty(params.pkg)
        pkg = char(string(params.pkg));
    end
    if isempty(pkg)
        return;
    end

    nodeType = lower(char(string(getFieldOrDefault(node, 'type', ''))));
    if strcmp(nodeType, 'processor')
        wantedType = 'processor';
    elseif strcmp(nodeType, 'classifier')
        wantedType = 'classifier';
    else
        wantedType = '';
    end

    try
        if exist('detecdiv_plugins_addpath', 'file') == 2
            detecdiv_plugins_addpath();
        end
        if exist('detecdiv_plugins_list', 'file') ~= 2
            return;
        end
        plugins = detecdiv_plugins_list();
    catch
        return;
    end
    if isempty(plugins)
        return;
    end

    for i = 1:numel(plugins)
        try
            if ~strcmp(char(string(plugins(i).name)), pkg)
                continue;
            end
            if ~isempty(wantedType) && ~strcmpi(char(string(plugins(i).type)), wantedType)
                continue;
            end
            candidateDir = char(string(plugins(i).path));
            if exist(candidateDir, 'dir') ~= 7
                continue;
            end
            packageDir = candidateDir;
            if isfield(plugins(i), 'root') && ~isempty(plugins(i).root)
                packageRoot = char(string(plugins(i).root));
            else
                packageRoot = fileparts(candidateDir);
            end
            msg = sprintf('Recovered custom package "%s" from registered plugin root after stored path was unavailable.', pkg);
            return;
        catch
        end
    end
end

function params = removeLegacyCustomPackageParams(params)
if ~isstruct(params)
    return;
end
rm = {};
keys = {'customPackageRoot','customPackageDir','customPackageLoadedAt'};
for i = 1:numel(keys)
    if isfield(params, keys{i})
        rm{end+1} = keys{i}; %#ok<AGROW>
    end
end
if ~isempty(rm)
    params = rmfield(params, rm);
end
end

function [nodeOut, rewrites] = rebaseNodeOutputPaths(nodeOut, pipelineDir)
    rewrites = {};
    params = getFieldOrDefault(nodeOut, 'params', struct());
    if ~isstruct(params)
        return;
    end
    keys = fieldnames(params);
    nodeId = sanitizeName(getFieldOrDefault(nodeOut, 'id', 'node'));
    for i = 1:numel(keys)
        key = keys{i};
        if ~isOutputPathKey(key)
            continue;
        end
        value = params.(key);
        if ~(ischar(value) || (isstring(value) && isscalar(value)))
            continue;
        end
        oldPath = char(string(value));
        if isempty(strtrim(oldPath))
            continue;
        end
        leaf = getLeafNameLocal(oldPath);
        if isempty(leaf)
            leaf = sanitizeName(key);
        end
        newPath = '../outputs';
        newPath = [newPath '/' nodeId '/' leaf];
        params.(key) = newPath;
        rewrites{end+1} = struct( ...
            'param', key, ...
            'kind', 'output', ...
            'originalPath', oldPath, ...
            'bundlePath', newPath); %#ok<AGROW>

        outputDir = fullfile(fileparts(pipelineDir), 'outputs', nodeId, leaf);
        ensureDir(outputDir);
    end
    nodeOut.params = params;
end

function copied = exportInferenceAssets(source, contract, targetDir, opts)
    ensureDir(targetDir);
    copied = {};
    files = collectMatchingAssets(source.path, contract.inference.include, contract.exclude, source.id);
    copied = copyAssetList(files, source.path, targetDir, opts);
end

function copied = exportTrainingAssets(source, contract, targetDir, includeRois, opts)
    ensureDir(targetDir);
    copied = struct('training', {{}}, 'rois', {{}});
    files = collectMatchingAssets(source.path, contract.training.include, contract.exclude, source.id);
    copied.training = copyAssetList(files, source.path, targetDir, opts);

    if includeRois && strcmpi(source.kind, 'classifier')
        roiFiles = collectClassifierTrainingRoiAssets(source);
        copied.rois = copySpecificFiles(roiFiles, targetDir, opts);
    end
end

function roiFiles = collectClassifierTrainingRoiAssets(source)
    roiFiles = {};
    snap = fullfile(source.path, [source.id '_classification.mat']);
    if exist(snap, 'file') ~= 2
        return;
    end
    try
        [classObj, ~] = classiLoad(snap);
    catch
        classObj = [];
    end
    if isempty(classObj) || ~isa(classObj, 'classi') || isempty(classObj.roi)
        return;
    end

    for i = 1:numel(classObj.roi)
        try
            roiId = char(string(classObj.roi(i).id));
            roiPath = char(string(classObj.roi(i).path));
            if isempty(roiPath)
                roiPath = source.path;
            end
            cand = { ...
                fullfile(roiPath, ['im_' roiId '.h5']), ...
                fullfile(roiPath, ['data_' roiId '.mat'])};
            for j = 1:numel(cand)
                if exist(cand{j}, 'file') == 2
                    roiFiles{end+1} = cand{j}; %#ok<AGROW>
                end
            end
        catch
        end
    end
    roiFiles = unique(roiFiles, 'stable');
end

function runSummary = exportRunBundle(runObj, runsDir, opts)
    runSummary = struct('runId', '', 'path', '', 'copiedFiles', {{}}, 'warnings', {{}});
    if isempty(runObj) || ~isa(runObj, 'pipelineRun')
        runSummary.warnings = {'Invalid pipelineRun object.'};
        return;
    end
    runSummary.runId = char(string(runObj.runId));
    if isempty(runObj.path) || exist(runObj.path, 'dir') ~= 7
        runSummary.warnings = {'Run folder not found on disk.'};
        return;
    end
    targetDir = fullfile(runsDir, sanitizeName(runSummary.runId));
    ensureDir(targetDir);
    notifyProgress(opts, 'run', struct( ...
        'runId', runSummary.runId, ...
        'sourcePath', runObj.path, ...
        'targetPath', targetDir, ...
        'message', sprintf('Copying run folder: %s', runSummary.runId)));
    if copyfile(runObj.path, targetDir)
        runSummary.path = targetDir;
        d = dir(fullfile(targetDir, '**', '*'));
        d = d(~[d.isdir]);
        runSummary.copiedFiles = cellfun(@(p) strrep(p, '\', '/'), fullfile({d.folder}, {d.name}), 'UniformOutput', false);
    else
        runSummary.warnings = {'Could not copy run directory.'};
    end
end

function node = rewriteNodeReferenceForBundle(node, source, relModulePath)
    if ~isfield(node, 'params') || ~isstruct(node.params)
        node.params = struct();
    end
    node.params.modulePath = relModulePath;
    if ~isfield(node.params, 'moduleId') || isempty(node.params.moduleId)
        node.params.moduleId = source.id;
    end
    if ~isfield(node.params, 'moduleKind') || isempty(node.params.moduleKind)
        node.params.moduleKind = source.kind;
    end
    if isfield(node, 'origin') && isstruct(node.origin)
        node.origin.path = relModulePath;
        if isfield(node.origin, 'id') && isempty(node.origin.id)
            node.origin.id = source.id;
        end
        if isfield(node.origin, 'kind') && isempty(node.origin.kind)
            node.origin.kind = source.kind;
        end
    end
end

function contract = getNodeExportContract(node)
    nodeType = lower(char(string(getFieldOrDefault(node, 'type', ''))));
    pkg = lower(char(string(getFieldOrDefault(node, 'pkg', ''))));

    contract = struct();
    contract.supports = struct('definition', true, 'definitionAssets', false, 'inferenceAssets', false, 'trainingAssets', false, 'trainingRois', false, 'runArtifacts', false);
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
                contract.inference.include = { ...
                    'file:%ID%_classification.mat', ...
                    'dir:models', ...
                    'glob:**/*.pth', ...
                    'glob:**/*.pt', ...
                    'glob:**/*.onnx', ...
                    'glob:**/*.yaml', ...
                    'glob:**/*.yml'};
                contract.training.include = { ...
                    'file:trainingParam.mat', ...
                    'glob:**/*framebank*.h5', ...
                    'glob:**/*framebank*.mat', ...
                    'dir:framebank', ...
                    'dir:trainingdataset', ...
                    'glob:**/train_cellposesam_config.json'};
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

        otherwise
            % Builtin dataloader/ROI nodes generally carry their portable state
            % in the pipeline params themselves.
    end
end

function out = exportAssetSubdir(summary, source, contract)
    if isfield(contract.supports, 'definitionAssets') && contract.supports.definitionAssets
        switch lower(summary.type)
            case {'roiidentify','roipattern'}
                out = 'roipatterns';
                return;
        end
    end
    out = pluralizeKind(source.kind);
end

function out = exportNodeFolderName(summary, source)
    out = '';
    if isstruct(source) && isfield(source, 'id') && ~isempty(source.id)
        out = sanitizeName(source.id);
    end
    if isempty(out)
        out = sanitizeName(summary.id);
    end
end

function [nodeOut, copied, warningsOut] = exportDefinitionAssets(nodeOut, opts, contract, targetDir, pipelineDir, templatePath)
    copied = {};
    warningsOut = {};
    nodeType = lower(char(string(getFieldOrDefault(nodeOut, 'type', ''))));
    pkg = lower(char(string(getFieldOrDefault(nodeOut, 'pkg', ''))));
    if any(strcmp(nodeType, {'roiidentify','roipattern'})) || strcmp(pkg, 'roipattern')
        [nodeOut, copied, warningsOut] = exportRoiPatternAssets(nodeOut, opts, targetDir, pipelineDir, templatePath);
    end
end

function [nodeOut, copied, warningsOut] = exportRoiPatternAssets(nodeOut, opts, targetDir, pipelineDir, templatePath)
    copied = {};
    warningsOut = {};
    ensureDir(targetDir);

    params = getFieldOrDefault(nodeOut, 'params', struct());
    [patternList, activeIdx] = extractPatternListFromNode(params);
    if isempty(patternList)
        warningsOut{end+1} = 'No roiPattern patternList/pattern found in node params.';
        return;
    end

    if nargin < 5
        templatePath = '';
    end

    projectObj = [];
    if isfield(opts, 'projectObj') && isa(opts.projectObj, 'shallow')
        projectObj = opts.projectObj;
    end

    exported = patternList;
    allFiles = {};
    for i = 1:numel(patternList)
        pat = patternList(i);
        [img, warnMsg] = materializePatternPatchForExport(projectObj, pat, params, templatePath);
        if ~isempty(warnMsg)
            warningsOut{end+1} = sprintf('Pattern %d: %s', i, warnMsg);
            continue;
        end

        matPath = fullfile(targetDir, sprintf('pattern_%03d.mat', i));
        pngPath = fullfile(targetDir, sprintf('pattern_%03d.png', i));
        patternImage = img; %#ok<NASGU>
        patternMeta = sanitizePatternMetaForExport(pat); %#ok<NASGU>
        save(matPath, 'patternImage', 'patternMeta', '-v7.3');
        notifyProgress(opts, 'file', struct( ...
            'sourcePath', '', ...
            'targetPath', matPath, ...
            'message', sprintf('Writing pattern asset: %s', getLeafNameLocal(matPath))));
        try
            imwrite(toPreviewUint8Local(img), pngPath);
            notifyProgress(opts, 'file', struct( ...
                'sourcePath', '', ...
                'targetPath', pngPath, ...
                'message', sprintf('Writing pattern preview: %s', getLeafNameLocal(pngPath))));
            allFiles = [allFiles, {matPath, pngPath}]; %#ok<AGROW>
        catch
            allFiles = [allFiles, {matPath}]; %#ok<AGROW>
        end

        exported(i).patchFile = relativePathFromTo(pipelineDir, matPath);
        try
            exported(i).patchPreviewFile = relativePathFromTo(pipelineDir, pngPath);
        catch
        end
    end

    exported = harmonizeStructArray(exported);
    params.patternList = exported;
    if ~isempty(activeIdx) && activeIdx >= 1 && activeIdx <= numel(exported)
        params.pattern = exported(activeIdx);
    elseif ~isempty(exported)
        params.pattern = exported(1);
    end
    nodeOut.params = params;
    copied = allFiles;
end

function [img, warnMsg] = materializePatternPatchForExport(projectObj, pat, params, templatePath)
    img = [];
    warnMsg = '';

    if isfield(pat, 'patchFile') && ~isempty(pat.patchFile)
        existingPath = resolveExportRelativePath(char(string(pat.patchFile)), templatePath);
        [img, ok] = loadPatternPatchFile(existingPath);
        if ok
            return;
        end
    end

    if isempty(projectObj) || ~isa(projectObj, 'shallow') || isempty(projectObj.fov)
        warnMsg = 'no project object available to rebuild the pattern patch image';
        return;
    end

    try
        fovList = projectObj.fov;
        refFov = fovList(1);
        if isfield(pat, 'fovIndex') && ~isempty(pat.fovIndex)
            candIdx = round(double(pat.fovIndex(1)));
            if candIdx >= 1 && candIdx <= numel(fovList)
                refFov = fovList(candIdx);
            end
        elseif isfield(pat, 'fovId') && ~isempty(pat.fovId)
            for ii = 1:numel(fovList)
                if isprop(fovList(ii), 'id') && strcmp(char(string(fovList(ii).id)), char(string(pat.fovId)))
                    refFov = fovList(ii);
                    break;
                end
            end
        end

        refFrame = 1;
        if isfield(params, 'referenceFrame') && ~isempty(params.referenceFrame)
            refFrame = round(double(params.referenceFrame(1)));
        end
        if isfield(pat, 'frame') && ~isempty(pat.frame)
            refFrame = round(double(pat.frame(1)));
        end

        chanIdx = 1;
        if isfield(params, 'channelIndex') && ~isempty(params.channelIndex)
            chanIdx = round(double(params.channelIndex(1)));
        elseif isfield(params, 'channel') && ~isempty(params.channel)
            chanIdx = resolvePatternChannelIndexForExport(refFov, params.channel);
        end
        if isfield(pat, 'channelIndex') && ~isempty(pat.channelIndex)
            chanIdx = round(double(pat.channelIndex(1)));
        elseif isfield(pat, 'channel') && ~isempty(pat.channel)
            chanIdx = resolvePatternChannelIndexForExport(refFov, pat.channel);
        end
        chanIdx = max(1, chanIdx);

        tmp = readImage(refFov, refFrame, chanIdx);
        if isempty(tmp)
            warnMsg = 'failed to read the reference FOV image for the stored pattern';
            return;
        end

        rect = double(pat.rect(:)');
        if numel(rect) < 4
            warnMsg = 'stored pattern rect is invalid';
            return;
        end
        x1 = max(1, round(rect(1)));
        y1 = max(1, round(rect(2)));
        x2 = min(size(tmp, 2), x1 + max(1, round(rect(3))) - 1);
        y2 = min(size(tmp, 1), y1 + max(1, round(rect(4))) - 1);
        img = tmp(y1:y2, x1:x2);
    catch ME
        warnMsg = ME.message;
    end
end

function idx = resolvePatternChannelIndexForExport(fovObj, channelValue)
    idx = 1;
    try
        channelName = char(string(channelValue));
        if isempty(channelName)
            return;
        end
        if isprop(fovObj, 'channel') && ~isempty(fovObj.channel)
            pix = find(strcmp(cellstr(string(fovObj.channel)), channelName), 1, 'first');
            if ~isempty(pix)
                idx = pix;
            end
        end
    catch
    end
end

function [img, ok] = loadPatternPatchFile(patchPath)
    img = [];
    ok = false;
    if isempty(patchPath) || exist(patchPath, 'file') ~= 2
        return;
    end
    try
        [~, ~, ext] = fileparts(patchPath);
        switch lower(ext)
            case '.mat'
                S = load(patchPath);
                if isfield(S, 'patternImage')
                    img = S.patternImage;
                elseif isfield(S, 'pattimg')
                    img = S.pattimg;
                elseif isfield(S, 'patch')
                    img = S.patch;
                end
            otherwise
                img = imread(patchPath);
        end
        ok = ~isempty(img);
    catch
        img = [];
        ok = false;
    end
end

function [patternList, activeIdx] = extractPatternListFromNode(params)
    patternList = struct([]);
    activeIdx = 1;
    if ~isstruct(params)
        return;
    end
    if isfield(params, 'patternList') && isstruct(params.patternList) && ~isempty(params.patternList)
        patternList = params.patternList;
    elseif isfield(params, 'pattern') && isstruct(params.pattern) && ~isempty(params.pattern)
        patternList = params.pattern;
    end
    if isfield(params, 'activePatternIndex') && ~isempty(params.activePatternIndex)
        activeIdx = round(double(params.activePatternIndex(1)));
    end
    if isempty(patternList)
        activeIdx = [];
    end
end

function out = harmonizeStructArray(in)
    out = in;
    if isempty(in) || ~isstruct(in)
        return;
    end
    allFields = {};
    for i = 1:numel(in)
        allFields = union(allFields, fieldnames(in(i)));
    end
    for i = 1:numel(in)
        for j = 1:numel(allFields)
            fn = allFields{j};
            if ~isfield(out(i), fn)
                out(i).(fn) = [];
            end
        end
    end
    try
        out = orderfields(out);
    catch
    end
end

function out = sanitizePatternMetaForExport(pat)
    out = pat;
    if isfield(out, 'patchFile')
        out = rmfield(out, 'patchFile');
    end
    if isfield(out, 'patchPreviewFile')
        out = rmfield(out, 'patchPreviewFile');
    end
    if isfield(out, 'updatedAt')
        try
            out.updatedAt = char(string(out.updatedAt));
        catch
        end
    end
end

function img8 = toPreviewUint8Local(img)
    if ndims(img) > 2
        img = img(:,:,1);
    end
    img = double(img);
    finiteMask = isfinite(img);
    if ~any(finiteMask(:))
        img8 = uint8(zeros(size(img), 'uint8'));
        return;
    end
    mn = min(img(finiteMask));
    mx = max(img(finiteMask));
    if mx > mn
        img = (img - mn) ./ (mx - mn);
    else
        img = zeros(size(img));
    end
    img(~finiteMask) = 0;
    img8 = uint8(max(0, min(255, round(img * 255))));
end

function fullp = resolveExportRelativePath(p, templatePath)
    fullp = char(string(p));
    if isempty(fullp) || isAbsolutePathLocal(fullp) || isempty(templatePath)
        return;
    end
    base = templatePath;
    if exist(base, 'file') == 2
        base = fileparts(base);
    end
    if exist(base, 'dir') == 7
        fullp = fullfile(base, fullp);
    end
end

function source = resolveNodeExportSource(node, templatePath)
    source = struct('path', '', 'id', '', 'kind', lower(char(string(getFieldOrDefault(node, 'type', '')))));
    if nargin < 2
        templatePath = '';
    end
    params = getFieldOrDefault(node, 'params', struct());
    if isstruct(params)
        if isfield(params, 'modulePath') && ~isempty(params.modulePath)
            source.path = char(string(params.modulePath));
        end
        if isfield(params, 'moduleId') && ~isempty(params.moduleId)
            source.id = char(string(params.moduleId));
        end
        if isfield(params, 'moduleKind') && ~isempty(params.moduleKind)
            source.kind = lower(char(string(params.moduleKind)));
        end
    end
    if (isempty(source.path) || isempty(source.id)) && isfield(node, 'origin') && isstruct(node.origin)
        if isempty(source.path) && isfield(node.origin, 'path') && ~isempty(node.origin.path)
            source.path = char(string(node.origin.path));
        end
        if isempty(source.id) && isfield(node.origin, 'id') && ~isempty(node.origin.id)
            source.id = char(string(node.origin.id));
        end
        if isfield(node.origin, 'kind') && ~isempty(node.origin.kind)
            source.kind = lower(char(string(node.origin.kind)));
        end
    end
    if isempty(source.id)
        source.id = char(string(getFieldOrDefault(node, 'id', 'module')));
    end
    if ~isempty(source.path) && ~isAbsolutePathLocal(source.path) && ~isempty(templatePath)
        base = templatePath;
        if exist(base, 'file') == 2
            base = fileparts(base);
        end
        if exist(base, 'dir') == 7
            source.path = fullfile(base, source.path);
        end
    end
end

function files = collectMatchingAssets(rootPath, rules, excludeRules, sourceId)
    files = {};
    if isempty(rootPath) || exist(rootPath, 'dir') ~= 7 || isempty(rules)
        return;
    end
    if nargin < 4
        sourceId = '';
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
            if isExcludedAsset(fullp, excludeRules)
                continue;
            end
            files{end+1} = fullp; %#ok<AGROW>
        end
    end
    files = unique(files, 'stable');
end

function copied = copyAssetList(files, sourceRoot, targetRoot, opts)
    copied = {};
    if isempty(files)
        return;
    end
    for i = 1:numel(files)
        src = char(string(files{i}));
        if exist(src, 'file') ~= 2
            continue;
        end
        rel = relativePathFromTo(sourceRoot, src);
        dst = fullfile(targetRoot, rel);
        ensureDir(fileparts(dst));
        [ok, msg] = copyfile(src, dst);
        if ok
            copied{end+1} = dst; %#ok<AGROW>
            notifyProgress(opts, 'file', struct( ...
                'sourcePath', src, ...
                'targetPath', dst, ...
                'message', sprintf('Copying file: %s', getLeafNameLocal(src))));
        else
            warning('pipelineExport:CopyAsset', 'Could not copy %s: %s', src, msg);
        end
    end
end

function copied = copySpecificFiles(files, targetRoot, opts)
    copied = {};
    if isempty(files)
        return;
    end
    for i = 1:numel(files)
        src = char(string(files{i}));
        if exist(src, 'file') ~= 2
            continue;
        end
        [~, name, ext] = fileparts(src);
        % Keep training ROI files at classifier root so classiLoad/classiSave
        % continue to find im_<roiId>.h5 and data_<roiId>.mat where legacy
        % classifier objects expect them.
        dst = fullfile(targetRoot, [name ext]);
        ensureDir(fileparts(dst));
        [ok, msg] = copyfile(src, dst);
        if ok
            copied{end+1} = dst; %#ok<AGROW>
            notifyProgress(opts, 'file', struct( ...
                'sourcePath', src, ...
                'targetPath', dst, ...
                'message', sprintf('Copying training ROI: %s', getLeafNameLocal(src))));
        else
            warning('pipelineExport:CopyRoi', 'Could not copy %s: %s', src, msg);
        end
    end
end

function files = listFilesRelativeToBundle(rootPath, bundleRoot)
    files = {};
    if isempty(rootPath) || exist(rootPath, 'dir') ~= 7
        return;
    end
    d = dir(fullfile(rootPath, '**', '*'));
    d = d(~[d.isdir]);
    for i = 1:numel(d)
        rel = relativePathFromTo(bundleRoot, fullfile(d(i).folder, d(i).name));
        files{end+1} = strrep(rel, '\', '/'); %#ok<AGROW>
    end
end

function tf = isOutputPathKey(key)
    key = lower(char(string(key)));
    tf = strcmp(key, 'outputdir') || strcmp(key, 'outputfolder') || ...
        strcmp(key, 'exportdir') || strcmp(key, 'exportfolder') || ...
        strcmp(key, 'resultsdir') || strcmp(key, 'resultsfolder') || ...
        strcmp(key, 'figuresdir') || strcmp(key, 'figuresfolder') || ...
        strcmp(key, 'workbookdir') || strcmp(key, 'reportdir') || ...
        endsWith(key, 'outputdir') || endsWith(key, 'outputfolder') || ...
        endsWith(key, 'exportdir') || endsWith(key, 'exportfolder') || ...
        endsWith(key, 'resultsdir') || endsWith(key, 'resultsfolder');
end

function tf = isExcludedAsset(p, excludeRules)
    tf = false;
    pname = lower(char(string(p)));
    for i = 1:numel(excludeRules)
        rule = lower(char(string(excludeRules{i})));
        if endsWith(rule, '.log') || endsWith(rule, '.tmp')
            if endsWith(pname, rule)
                tf = true;
                return;
            end
        elseif contains(pname, lower(strrep(rule, '\', '/')))
            tf = true;
            return;
        end
    end
end

function rel = relativePathFromTo(fromPath, toPath)
    fromPath = normalizePathLocal(fromPath);
    toPath = normalizePathLocal(toPath);

    if exist(fromPath, 'file') == 2
        fromPath = normalizePathLocal(fileparts(fromPath));
    end

    fromParts = splitPathLocal(fromPath);
    toParts = splitPathLocal(toPath);
    n = min(numel(fromParts), numel(toParts));
    common = 0;
    for i = 1:n
        if strcmpi(fromParts{i}, toParts{i})
            common = i;
        else
            break;
        end
    end

    up = repmat({'..'}, 1, numel(fromParts) - common);
    down = toParts(common+1:end);
    parts = [up, down];
    if isempty(parts)
        rel = '.';
    else
        rel = fullfile(parts{:});
    end
    rel = formatRelativeJsonPath(rel);
end

function rel = formatRelativeJsonPath(rel)
    rel = strrep(char(string(rel)), '\', '/');
    if isempty(rel) || strcmp(rel, '.')
        rel = './';
        return;
    end
    if startsWith(rel, '../') || startsWith(rel, './')
        return;
    end
    if strcmp(rel, '..')
        rel = '../';
        return;
    end
    rel = ['./' rel];
end

function parts = splitPathLocal(p)
    p = strrep(char(string(p)), '\', '/');
    parts = regexp(p, '/', 'split');
    parts = parts(~cellfun(@isempty, parts));
end

function p = normalizePathLocal(p)
    p = char(string(p));
    p = strrep(p, '/', filesep);
    p = strrep(p, '\', filesep);
    p = regexprep(p, [regexptranslate('escape', filesep) '+$'], '');
end

function tf = isAbsolutePathLocal(p)
tf = false;
if isempty(p)
    return;
end
p = char(string(p));
tf = startsWith(p, '/') || ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
end

function out = pluralizeKind(kind)
    kind = lower(char(string(kind)));
    switch kind
        case 'classifier'
            out = 'classification';
        case 'processor'
            out = 'processing';
        otherwise
            out = 'modules';
    end
end

function out = sanitizeName(nameIn)
    out = regexprep(char(string(nameIn)), '[^a-zA-Z0-9_\-]', '_');
    if isempty(out)
        out = 'item';
    end
end

function list = normalizeRunList(runObjects)
    list = pipelineRun.empty;
    if isempty(runObjects)
        return;
    end
    if isa(runObjects, 'pipelineRun')
        list = runObjects(:)';
        return;
    end
    if iscell(runObjects)
        for i = 1:numel(runObjects)
            if isa(runObjects{i}, 'pipelineRun')
                list(end+1) = runObjects{i}; %#ok<AGROW>
            end
        end
    end
end

function S = appendStruct(S, row)
    if isempty(S)
        S = row;
    else
        [S, row] = alignStructArrayAndRow(S, row);
        S(end+1) = row; %#ok<AGROW>
    end
end

function S = assignStructElement(S, idx, row)
    if isempty(S)
        S = row;
        return;
    end
    [S, row] = alignStructArrayAndRow(S, row);
    S(idx) = row;
end

function [S, row] = alignStructArrayAndRow(S, row)
    if ~isstruct(S) || ~isstruct(row)
        return;
    end

    existingFields = fieldnames(S);
    rowFields = fieldnames(row);
    allFields = unique([existingFields; rowFields], 'stable');

    for i = 1:numel(allFields)
        fieldName = allFields{i};
        if ~isfield(S, fieldName)
            [S.(fieldName)] = deal([]);
        end
        if ~isfield(row, fieldName)
            row.(fieldName) = [];
        end
    end

    try
        S = orderfields(S, allFields);
        row = orderfields(row, allFields);
    catch
    end
end

function ensureDir(p)
    if isempty(p)
        return;
    end
    if exist(p, 'dir') ~= 7
        mkdir(p);
    end
end

function v = getFieldOrDefault(S, name, defaultVal)
    v = defaultVal;
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        v = S.(name);
    end
end

function plan = estimateExportProgressPlan(spec, opts, templatePath)
    nodes = getFieldOrDefault(spec, 'nodes', struct([]));
    totalUnits = 2 + numel(nodes); % pipeline.json + manifest + one unit per node
    for i = 1:numel(nodes)
        node = nodes(i);
        contract = getNodeExportContract(node);
        source = resolveNodeExportSource(node, templatePath);
        if contract.supports.definitionAssets
            totalUnits = totalUnits + estimateDefinitionAssetUnits(node);
        end
        if isempty(source.path) || exist(source.path, 'dir') ~= 7
            continue;
        end
        if opts.includeWeights && contract.supports.inferenceAssets
            totalUnits = totalUnits + numel(collectMatchingAssets(source.path, contract.inference.include, contract.exclude, source.id));
        end
        if (opts.includeTrainingData || opts.includeTrainingRois) && contract.supports.trainingAssets
            totalUnits = totalUnits + numel(collectMatchingAssets(source.path, contract.training.include, contract.exclude, source.id));
            if opts.includeTrainingRois && strcmpi(source.kind, 'classifier')
                totalUnits = totalUnits + numel(collectClassifierTrainingRoiAssets(source));
            end
        end
    end
    runList = normalizeRunList(opts.runObjects);
    if opts.includeRunResults
        totalUnits = totalUnits + numel(runList);
        runCount = numel(runList);
    else
        runCount = 0;
    end
    plan = struct('totalUnits', max(1, totalUnits), 'runCount', runCount);
end

function n = estimateDefinitionAssetUnits(node)
    n = 1;
    params = getFieldOrDefault(node, 'params', struct());
    [patternList, ~] = extractPatternListFromNode(params);
    if ~isempty(patternList)
        n = max(1, 2 * numel(patternList));
    end
end

function notifyProgress(opts, action, info)
    if ~isstruct(opts) || ~isfield(opts, 'progressFcn') || isempty(opts.progressFcn)
        return;
    end
    try
        feval(opts.progressFcn, action, info);
    catch
    end
end

function nameOut = getLeafNameLocal(p)
    [~, name, ext] = fileparts(char(string(p)));
    nameOut = [name ext];
end

function writeJson(filename, S)
    S = sanitizeForJsonLocal(S);
    try
        txt = jsonencode(S, 'PrettyPrint', true);
    catch
        txt = jsonencode(S);
    end
    fid = fopen(filename, 'w');
    if fid < 0
        error('pipelineExport:IO', 'Unable to write %s', filename);
    end
    fwrite(fid, txt, 'char');
    fclose(fid);
end

function out = sanitizeForJsonLocal(in)
    if isempty(in)
        out = in;
        return;
    end

    if isstruct(in)
        out = in;
        fn = fieldnames(in);
        for k = 1:numel(in)
            for i = 1:numel(fn)
                out(k).(fn{i}) = sanitizeForJsonLocal(in(k).(fn{i}));
            end
        end
        return;
    end

    if iscell(in)
        out = cell(size(in));
        for i = 1:numel(in)
            out{i} = sanitizeForJsonLocal(in{i});
        end
        return;
    end

    if isdatetime(in)
        out = cellstr(string(in));
        if isscalar(in)
            out = out{1};
        end
        return;
    end

    if isnumeric(in) || islogical(in) || ischar(in)
        out = in;
        return;
    end

    if isstring(in)
        out = cellstr(in);
        if isscalar(in)
            out = out{1};
        end
        return;
    end

    if isa(in, 'handle')
        out = struct('className', class(in), 'note', 'handle omitted for JSON');
        return;
    end

    try
        jsonencode(in);
        out = in;
    catch
        out = struct('className', class(in), 'note', 'value omitted for JSON');
    end
end
