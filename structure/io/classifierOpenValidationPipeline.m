function app = classifierOpenValidationPipeline(classiObj, varargin)
% classifierOpenValidationPipeline  Open a pipeline2 validation run for a classifier.
%
% The classifier owns its imported ROIs, so this helper builds a one-node
% classifier pipeline and passes classiObj.roi as the runtime ROI source.
% A shallow project may still be provided, but it is not required.

opts = parseOptions(varargin{:});
opts.intent = normalizeIntent(opts.intent);
validateClassifierObject(classiObj);
if isempty(opts.executionTarget)
    opts.executionTarget = classifierDefaultExecutionTarget(classiObj.path);
end

roiIdx = resolveClassifierRoiIndices(classiObj, opts);
if isempty(roiIdx)
    error('classifierOpenValidationPipeline:NoRoi', ...
        'No %s ROI found. Select train/test ROIs in classifierGUI or import ROIs first.', opts.intent);
end
roiList = classiObj.roi;

pipeObj = buildClassifierPipeline(classiObj, opts);
ensureClassifierSnapshot(classiObj);

runId = opts.runId;
if isempty(runId)
    runId = [opts.intent '_' char(string(classiObj.strid)) '_' char(datetime('now','Format','yyyyMMdd_HHmmss'))];
end

args = {pipeObj, ...
    'InputMode', 'classifier_rois', ...
    'Intent', opts.intent, ...
    'LockInputMode', true, ...
    'LockReason', ['Classifier ' opts.intent ' run; classifier.roi is the runtime source.'], ...
    'UnlockRuntime', true, ...
    'Rois', roiIdx, ...
    'RoiObjects', roiList, ...
    'OutputPolicy', opts.outputPolicy, ...
    'Execution', opts.gpuPolicy, ...
    'RunId', runId};

if ~isempty(opts.frames)
    args = [args {'Frames', opts.frames}];
end
if ~isempty(opts.channels)
    args = [args {'Channels', opts.channels}];
end
if ~isempty(opts.executionTarget)
    args = [args {'ExecutionTarget', opts.executionTarget}];
end
if ~isempty(opts.projectObj)
    args = [{opts.projectObj} args];
elseif ~isempty(opts.projectPath)
    args = [args {'ProjectPath', opts.projectPath}];
end

ensureActivePipelineGuiPath();
app = pipeline2(args{:});
end

function opts = parseOptions(varargin)
opts = struct();
opts.rois = [];
opts.frames = '';
opts.channels = '';
opts.projectObj = [];
opts.projectPath = '';
opts.executionTarget = '';
opts.gpuPolicy = 'Auto';
opts.outputPolicy = 'replace';
opts.runId = '';
opts.intent = 'validate';

i = 1;
while i <= numel(varargin)
    key = varargin{i};
    if ~ischar(key) && ~isstring(key)
        i = i + 1;
        continue;
    end
    if i == numel(varargin)
        break;
    end
    value = varargin{i + 1};
    switch lower(strrep(char(string(key)), '_', ''))
        case {'rois','roi','testrois','validationrois'}
            opts.rois = value;
        case {'frames','frame'}
            opts.frames = selectionText(value);
        case {'channels','channel'}
            opts.channels = selectionText(value);
        case {'project','shallow','shallowobj'}
            if isa(value, 'shallow')
                opts.projectObj = value;
            elseif ischar(value) || isstring(value)
                opts.projectPath = char(string(value));
            end
        case {'projectpath'}
            opts.projectPath = char(string(value));
        case {'executiontarget','runtarget','target'}
            opts.executionTarget = char(string(value));
        case {'gpupolicy','execution','compute'}
            opts.gpuPolicy = char(string(value));
        case {'outputpolicy','existingpolicy'}
            opts.outputPolicy = char(string(value));
        case {'runid','runname'}
            opts.runId = char(string(value));
        case {'intent','operation','task','runtype'}
            opts.intent = char(string(value));
    end
    i = i + 2;
end
end

function intent = normalizeIntent(value)
intent = lower(strtrim(char(string(value))));
switch intent
    case {'validate','validation','val','test','evaluate','eval'}
        intent = 'validate';
    case {'train','training','fit'}
        intent = 'train';
    otherwise
        error('classifierOpenValidationPipeline:InvalidIntent', ...
            'Invalid classifier pipeline intent "%s". Use "train" or "validate".', char(string(value)));
end
end

function validateClassifierObject(classiObj)
if isempty(classiObj) || ~isa(classiObj, 'classi')
    error('classifierOpenValidationPipeline:InvalidClassifier', ...
        'Expected a classi object.');
end
if isempty(classiObj.roi) || (isscalar(classiObj.roi) && isempty(classiObj.roi(1).id))
    error('classifierOpenValidationPipeline:NoRoi', ...
        'This classifier has no attached ROI.');
end
end

function idx = resolveClassifierRoiIndices(classiObj, opts)
n = numel(classiObj.roi);
idx = normalizeIndexVector(opts.rois, n);
if ~isempty(idx)
    return;
end

try
    if isstruct(classiObj.dataset) && isfield(classiObj.dataset, 'split') && isstruct(classiObj.dataset.split)
        if strcmp(opts.intent, 'train') && isfield(classiObj.dataset.split, 'train')
            idx = normalizeIndexVector(classiObj.dataset.split.train, n);
        elseif isfield(classiObj.dataset.split, 'test')
            idx = normalizeIndexVector(classiObj.dataset.split.test, n);
        end
        if isempty(idx) && isfield(classiObj.dataset.split, 'val')
            idx = normalizeIndexVector(classiObj.dataset.split.val, n);
        end
    end
catch
end

if isempty(idx)
    trainIdx = normalizeIndexVector(classiObj.trainingset, n);
    if strcmp(opts.intent, 'train')
        idx = trainIdx;
    else
        idx = setdiff(1:n, trainIdx, 'stable');
    end
end
if isempty(idx)
    idx = 1:n;
end
end

function pipeObj = buildClassifierPipeline(classiObj, opts)
pipeRoot = fullfile(classiObj.path, 'pipeline_templates');
if exist(pipeRoot, 'dir') ~= 7
    mkdir(pipeRoot);
end
pipeName = [opts.intent '_' char(string(classiObj.strid))];
pipeObj = pipelineConstruct(pipeRoot, pipeName, 1);
pipeObj.description = [upper(opts.intent(1)) opts.intent(2:end) ' pipeline for classifier ' char(string(classiObj.strid))];

params = classifierNodeParams(classiObj, opts);
pkg = char(string(classiObj.classifierPkg));
if isempty(pkg)
    pkg = inferPkg(classiObj);
end
func = char(string(classiObj.classifyFun));
if isempty(func) && ~isempty(pkg)
    func = [pkg '.classify'];
end

nodeId = char(string(classiObj.strid));
node = struct();
node.id = nodeId;
node.name = nodeId;
node.type = 'classifier';
node.pkg = pkg;
node.func = func;
node.gui = 'classifierGUI';
node.guiMode = 'replace';
node.paramRequired = {'pkg'};
node.params = params;
node.inputs = {'roiList'};
if any(strcmpi(pkg,{'budMotherLinker','cellLatentModel'}))
    node.outputs = {'roiList','dataSeries'};
else
    node.outputs = {'roiList','masks'};
end
node.enabled = true;
node.status = '';
node.layout = [10 10 24 10];
node.origin = struct('kind','classifier', 'path', classiObj.path, 'id', classiObj.strid);

pipeObj.nodes = pipelineNormalizeNodes(node, 'persist');
pipeObj.edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
% Do not save here. pipeline2 receives the pipeline object directly and will
% persist the template when the user saves/runs it. Saving at this stage makes
% classifierGUI feel sluggish on network-backed classifier folders because
% pipelineSave also runs dependency audits.
end

function params = classifierNodeParams(classiObj, opts)
params = struct();
params.pkg = char(string(classiObj.classifierPkg));
if isempty(params.pkg)
    params.pkg = inferPkg(classiObj);
end
params.modulePath = char(string(classiObj.path));
params.moduleId = char(string(classiObj.strid));
params.outputName = char(string(classiObj.strid));
params.existingPolicy = opts.outputPolicy;
params.intent = opts.intent;
params.operation = opts.intent;
params.classes = classiObj.classes;
params.description = classiObj.description;
params.category = classiObj.category;
params.outputType = classiObj.outputType;
if ~isempty(opts.channels)
    params.channels = opts.channels;
elseif ~isempty(classiObj.channelName)
    params.channels = classiObj.channelName;
elseif ~isempty(classiObj.channel)
    params.channel = classiObj.channel;
end
if ~isempty(opts.frames)
    params.frames = opts.frames;
end

try
    specFun = str2func([params.pkg '.executionSpec']);
    spec = specFun(classiObj);
    if isstruct(spec) && isfield(spec, 'defaults') && isstruct(spec.defaults)
        defaults = spec.defaults;
        privateKeys = {};
        if isfield(spec,'artifactKeys'), privateKeys = [privateKeys spec.artifactKeys]; end
        if isfield(spec,'environmentKeys'), privateKeys = [privateKeys spec.environmentKeys]; end
        privateKeys = unique(privateKeys,'stable');
        privateKeys = privateKeys(isfield(defaults,privateKeys));
        if ~isempty(privateKeys), defaults = rmfield(defaults,privateKeys); end
        params = mergeStructDefaults(params, defaults);
    end
catch
end

% Resolve the effective input keys from the shared Pipeline2 contract.  The
% contract is package-aware (including backend variants), so this applies to
% every classifier without embedding package-specific channel rules here.
try
    contractNode = struct('type', 'classifier', 'pkg', params.pkg, ...
        'func', char(string(classiObj.classifyFun)), 'params', params);
    contract = pipelineNodeContract(contractNode);
catch
    contract = struct();
end
params = classifierApplyPipelineInputBindings( ...
    params, classiObj, contract, opts.intent, opts.channels);
end

function ensureClassifierSnapshot(classiObj)
target = fullfile(classiObj.path, [classiObj.strid '_classification.mat']);
if exist(target, 'file') == 2
    return;
end
try
    classiSave(classiObj);
catch ME
    warning('classifierOpenValidationPipeline:ClassifierSaveFailed', ...
        'Could not save classifier snapshot for pipeline run: %s', ME.message);
end
end

function out = mergeStructDefaults(out, defaults)
keys = fieldnames(defaults);
for i = 1:numel(keys)
    key = keys{i};
    if ~isfield(out, key) || isempty(out.(key))
        out.(key) = defaults.(key);
    end
end
end

function pkg = inferPkg(classiObj)
pkg = '';
try
    if ~isempty(classiObj.trainingFun) && contains(classiObj.trainingFun, '.')
        pkg = extractBefore(char(string(classiObj.trainingFun)), '.');
    elseif ~isempty(classiObj.classifyFun) && contains(classiObj.classifyFun, '.')
        pkg = extractBefore(char(string(classiObj.classifyFun)), '.');
    end
catch
end
end

function txt = selectionText(value)
if isempty(value)
    txt = '';
elseif ischar(value) || isstring(value)
    txt = char(string(value));
elseif isnumeric(value) || islogical(value)
    values = double(value(:)');
    txt = strjoin(arrayfun(@(x)sprintf('%g', x), values, 'UniformOutput', false), ',');
elseif iscell(value)
    txt = strjoin(cellstr(string(value(:)')), ',');
else
    try
        txt = char(string(value));
    catch
        txt = '';
    end
end
end

function idx = normalizeIndexVector(value, n)
idx = [];
if isempty(value)
    return;
end
if ischar(value) || isstring(value)
    txt = strtrim(char(string(value)));
    if isempty(txt) || strcmpi(txt, 'all')
        idx = 1:n;
        return;
    end
    value = str2num(txt); %#ok<ST2NM>
end
if islogical(value)
    value = find(value(:)');
end
if isnumeric(value)
    value = double(value(:)');
    value = value(isfinite(value));
    idx = unique(round(value(value >= 1 & value <= n)), 'stable');
end
end

function ensureActivePipelineGuiPath()
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(fileparts(thisFile)));
backupRoot = localNormalizePath(fullfile(repoRoot, 'backups'));
guiDir = fullfile(repoRoot, 'structure', 'GUI');

parts = strsplit(path, pathsep);
for i = 1:numel(parts)
    p = parts{i};
    if isempty(p)
        continue;
    end
    pNorm = localNormalizePath(p);
    if strcmpi(pNorm, backupRoot) || startsWith([lower(pNorm) filesep], [lower(backupRoot) filesep])
        rmpath(p);
    end
end

if exist(guiDir, 'dir') == 7
    addpath(guiDir, '-begin');
end
end

function p = localNormalizePath(p)
p = char(string(p));
p = strrep(p, '/', filesep);
while endsWith(p, filesep)
    p(end) = [];
end
end
