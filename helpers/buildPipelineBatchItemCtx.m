function [ctx, itemInfo] = buildPipelineBatchItemCtx(batchSpec, itemIndex, varargin)
% buildPipelineBatchItemCtx  Build a run context for one batch item.

    if nargin < 2
        error('buildPipelineBatchItemCtx:MissingItemIndex', 'itemIndex is required.');
    end

    ip = inputParser;
    ip.addParameter('BatchRoot', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('ItemOverrides', struct(), @isstruct);
    ip.parse(varargin{:});
    opts = ip.Results;

    if ~isstruct(batchSpec) || ~isfield(batchSpec, 'items') || isempty(batchSpec.items)
        error('buildPipelineBatchItemCtx:InvalidBatch', 'batchSpec.items is empty.');
    end
    if itemIndex < 1 || itemIndex > numel(batchSpec.items)
        error('buildPipelineBatchItemCtx:InvalidItemIndex', 'itemIndex is out of range.');
    end

    item = localNormalizeItem(batchSpec.items(itemIndex));
    itemInfo = item;
    itemInfo.index = itemIndex;
    itemInfo.batchId = localStringField(batchSpec, 'id');
    itemInfo.batchName = localStringField(batchSpec, 'name');
    itemInfo.batchRoot = char(string(opts.BatchRoot));

    if isempty(itemInfo.kind)
        itemInfo.kind = 'project';
    end

    if startsWith(lower(itemInfo.kind), 'dataset')
        ctx = struct();
        ctx.allowGUI = false;
        ctx.interactive = false;
        ctx.batch = struct('id', itemInfo.batchId, 'name', itemInfo.batchName, 'root', itemInfo.batchRoot);
        ctx.run = struct();
        ctx.run.batchId = itemInfo.batchId;
        ctx.run.batchItemId = itemInfo.id;
        ctx.run.batchItemIndex = itemIndex;
        ctx.run.batchItemKind = itemInfo.kind;
        ctx.run.batchItemName = itemInfo.displayName;
        ctx.run.executionTarget = localStringField(batchSpec.execution, 'target', 'local');
        ctx.run.batchSourceMode = localStringField(batchSpec, 'sourceMode');
        ctx.datasetRef = itemInfo;
        return;
    end

    projectMatPath = localStringField(itemInfo, 'projectMatPath');
    if isempty(projectMatPath) || exist(projectMatPath, 'file') ~= 2
        error('buildPipelineBatchItemCtx:MissingProject', ...
            'Project MAT file not found for item "%s": %s', itemInfo.displayName, projectMatPath);
    end
    itemInfo.projectName = localProjectNameFromPath(projectMatPath);

    [shallowObj, msg] = shallowLoad(projectMatPath);
    if isempty(shallowObj)
        if isempty(msg)
            msg = 'Unable to load project.';
        end
        error('buildPipelineBatchItemCtx:ProjectLoadFailed', ...
            'Unable to load project for batch item "%s": %s', itemInfo.displayName, msg);
    end

    prototypeRuntime = struct();
    if isfield(batchSpec, 'prototypeRuntimeConfig') && isstruct(batchSpec.prototypeRuntimeConfig)
        prototypeRuntime = localStripPrototypeRuntime(batchSpec.prototypeRuntimeConfig);
    end
    prototypeRuntime = mergePipelineRuntimeConfig(struct(), prototypeRuntime);
    prototypeRuntime = mergePipelineRuntimeConfig(prototypeRuntime, localStripPrototypeRuntime(opts.ItemOverrides));

    ctx = mergePipelineRuntimeConfig(struct('allowGUI', false, 'interactive', false), prototypeRuntime);
    ctx.allowGUI = false;
    ctx.interactive = false;
    ctx.shallow = shallowObj;
    ctx.shallowObj = shallowObj;
    ctx.pipelineRef = localNormalizePipelineRef(localPipelineRef(batchSpec));
    ctx.targetRef = struct( ...
        'type', 'shallow', ...
        'projectPath', projectMatPath, ...
        'projectName', itemInfo.projectName, ...
        'fovIds', [], ...
        'roiIds', {{}}, ...
        'classiPath', '', ...
        'notes', '');

    if ~isfield(ctx, 'run') || ~isstruct(ctx.run)
        ctx.run = struct();
    end
    ctx.run.batchId = itemInfo.batchId;
    ctx.run.batchItemId = itemInfo.id;
    ctx.run.batchItemIndex = itemIndex;
    ctx.run.batchItemKind = itemInfo.kind;
    ctx.run.batchItemName = itemInfo.displayName;
    ctx.run.batchExecutionTarget = localStringField(batchSpec.execution, 'target', 'local');
    ctx.run.executionTarget = localStringField(batchSpec.execution, 'target', 'local');
    ctx.run.batchSourceMode = localStringField(batchSpec, 'sourceMode');
    ctx.run.projectPath = projectMatPath;
    ctx.run.projectName = itemInfo.projectName;
    if ~isempty(opts.BatchRoot)
        ctx.run.batchRoot = char(string(opts.BatchRoot));
    end

    if ~isfield(ctx, 'batch') || ~isstruct(ctx.batch)
        ctx.batch = struct();
    end
    ctx.batch.id = itemInfo.batchId;
    ctx.batch.name = itemInfo.batchName;
    ctx.batch.root = char(string(opts.BatchRoot));
    ctx.batch.itemIndex = itemIndex;
    ctx.batch.itemId = itemInfo.id;

    if ~isempty(fieldnames(opts.ItemOverrides))
        ctx = mergePipelineRuntimeConfig(ctx, opts.ItemOverrides);
        ctx.allowGUI = false;
        ctx.interactive = false;
        ctx.shallow = shallowObj;
        ctx.shallowObj = shallowObj;
        ctx.pipelineRef = localNormalizePipelineRef(localPipelineRef(batchSpec));
        ctx.targetRef.projectPath = projectMatPath;
        ctx.targetRef.projectName = localProjectNameFromPath(projectMatPath);
    end
end

function item = localNormalizeItem(item)
    if isempty(item) || ~isstruct(item)
        item = struct();
    end
    defaults = struct( ...
        'id', '', ...
        'kind', 'project', ...
        'displayName', '', ...
        'sourceMode', '', ...
        'entityMode', '', ...
        'catalogId', '', ...
        'projectMatPath', '', ...
        'datasetId', '', ...
        'rootPath', '', ...
        'localPathHint', '', ...
        'batchSelected', false);
    fn = fieldnames(defaults);
    for i = 1:numel(fn)
        if ~isfield(item, fn{i}) || isempty(item.(fn{i}))
            item.(fn{i}) = defaults.(fn{i});
        end
    end
    item.id = char(string(item.id));
    item.kind = char(string(item.kind));
    item.displayName = char(string(item.displayName));
    item.sourceMode = char(string(item.sourceMode));
    item.entityMode = char(string(item.entityMode));
    item.catalogId = char(string(item.catalogId));
    item.projectMatPath = char(string(item.projectMatPath));
    item.datasetId = char(string(item.datasetId));
    item.rootPath = char(string(item.rootPath));
    item.localPathHint = char(string(item.localPathHint));
    item.batchSelected = logical(item.batchSelected);
end

function ref = localNormalizePipelineRef(ref)
    defaults = struct('id', '', 'path', '', 'version', '');
    if nargin < 1 || isempty(ref) || ~isstruct(ref)
        ref = defaults;
        return;
    end
    fn = fieldnames(defaults);
    for i = 1:numel(fn)
        if ~isfield(ref, fn{i}) || isempty(ref.(fn{i}))
            ref.(fn{i}) = defaults.(fn{i});
        else
            ref.(fn{i}) = char(string(ref.(fn{i})));
        end
    end
end

function txt = localStringField(S, fieldName, defaultVal)
    if nargin < 3
        defaultVal = '';
    end
    txt = defaultVal;
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        txt = char(string(S.(fieldName)));
    end
end

function ref = localPipelineRef(batchSpec)
    ref = struct();
    if isstruct(batchSpec) && isfield(batchSpec, 'pipelineRef') && isstruct(batchSpec.pipelineRef)
        ref = batchSpec.pipelineRef;
    end
end

function out = localStripPrototypeRuntime(in)
    out = struct();
    if isempty(in) || ~isstruct(in)
        return;
    end
    out = in;
    forbidden = {'shallow','shallowObj','targetRef','pipelineRef','progressDlg','cancel'};
    for i = 1:numel(forbidden)
        if isfield(out, forbidden{i})
            out = rmfield(out, forbidden{i});
        end
    end
end

function name = localProjectNameFromPath(projectMatPath)
    [~, name] = fileparts(char(string(projectMatPath)));
end
