function batchSpec = pipelineBatchNew(selectedRefs, varargin)
% pipelineBatchNew  Create a batch specification from selected catalog refs.

    if nargin < 1 || isempty(selectedRefs)
        selectedRefs = struct([]);
    end

    ip = inputParser;
    ip.addParameter('Name', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('CreatedBy', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('SourceMode', 'local', @(x)ischar(x) || isstring(x));
    ip.addParameter('EntityMode', 'projects', @(x)ischar(x) || isstring(x));
    ip.addParameter('PipelineRef', struct(), @isstruct);
    ip.addParameter('PrototypeRuntimeConfig', struct(), @isstruct);
    ip.parse(varargin{:});
    opts = ip.Results;

    selectedRefs = localNormalizeRefs(selectedRefs);
    batchSpec = struct();
    batchSpec.id = char(java.util.UUID.randomUUID());
    batchSpec.name = localDefaultName(opts.Name);
    batchSpec.createdAt = char(datetime('now'));
    batchSpec.createdBy = char(string(opts.CreatedBy));
    batchSpec.sourceMode = char(string(opts.SourceMode));
    batchSpec.entityMode = char(string(opts.EntityMode));
    batchSpec.pipelineRef = localNormalizePipelineRef(opts.PipelineRef);
    batchSpec.pipelineTemplatePath = char(string(localStructField(batchSpec.pipelineRef, 'path')));
    batchSpec.pipelineTemplate = struct();
    batchSpec.prototypeItemId = '';
    batchSpec.prototypeRuntimeConfig = opts.PrototypeRuntimeConfig;
    batchSpec.items = selectedRefs(:);
    batchSpec.itemsTable = localRefsToTable(batchSpec.items);
    batchSpec.prototypeIndex = localDefaultPrototypeIndex(batchSpec.items);
    batchSpec.execution = struct( ...
        'target', 'local', ...
        'execution_target_id', '', ...
        'localRoot', '', ...
        'hubRoot', '');
    batchSpec.validation = struct();
    batchSpec.monitor = struct();
    batchSpec.artifacts = struct();
end

function refs = localNormalizeRefs(refs)
    if isempty(refs)
        refs = struct([]);
        return;
    end
    if iscell(refs)
        refs = [refs{:}];
    end
    if ~isstruct(refs)
        error('pipelineBatchNew:InvalidRefs', 'Selected refs must be a struct array.');
    end
    refs = refs(:);
    for i = 1:numel(refs)
        if ~isfield(refs, 'batchSelected') || isempty(refs(i).batchSelected)
            refs(i).batchSelected = true;
        else
            refs(i).batchSelected = logical(refs(i).batchSelected);
        end
    end
end

function ref = localNormalizePipelineRef(ref)
    ref = localNormalizeStruct(ref);
    defaults = struct('id', '', 'path', '', 'version', '');
    if isempty(fieldnames(ref))
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

function text = localDefaultName(value)
    text = char(string(value));
    if isempty(strtrim(text))
        text = ['Batch ' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))];
    end
end

function idx = localDefaultPrototypeIndex(items)
    idx = 0;
    if isempty(items)
        return;
    end
    for i = 1:numel(items)
        kind = lower(char(string(localStructField(items(i), 'kind'))));
        if contains(kind, 'project')
            idx = i;
            return;
        end
    end
    idx = 1;
end

function tbl = localRefsToTable(items)
    if isempty(items)
        tbl = table();
        return;
    end
    n = numel(items);
    kind = strings(n, 1);
    name = strings(n, 1);
    source = strings(n, 1);
    ref = strings(n, 1);
    projectMatPath = strings(n, 1);
    datasetId = strings(n, 1);
    selected = false(n, 1);
    for i = 1:n
        kind(i) = string(localStructField(items(i), 'kind'));
        name(i) = string(localStructField(items(i), 'displayName'));
        source(i) = string(localStructField(items(i), 'sourceMode'));
        ref(i) = string(localStructField(items(i), 'catalogId'));
        projectMatPath(i) = string(localStructField(items(i), 'projectMatPath'));
        datasetId(i) = string(localStructField(items(i), 'datasetId'));
        selectedValue = localStructField(items(i), 'batchSelected', true);
        if isempty(selectedValue)
            selectedValue = true;
        end
        selected(i) = logical(selectedValue);
    end
    tbl = table(selected, kind, name, source, ref, projectMatPath, datasetId, ...
        'VariableNames', {'Selected', 'Kind', 'Name', 'Source', 'Ref', 'ProjectMatPath', 'DatasetId'});
end

function value = localStructField(in, fieldName, defaultValue)
    if nargin < 3
        defaultValue = '';
    end
    value = defaultValue;
    if isstruct(in) && isfield(in, fieldName) && ~isempty(in.(fieldName))
        value = in.(fieldName);
    end
end

function out = localNormalizeStruct(in)
    if isempty(in) || ~isstruct(in)
        out = struct();
    else
        out = in;
    end
end
