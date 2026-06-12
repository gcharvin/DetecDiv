function [ok, report] = validatePipelineBatch(batchSpec, varargin)
% validatePipelineBatch  Validate a batch spec before execution.

    ip = inputParser;
    ip.addParameter('AllowGUI', false, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('BatchRoot', '', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    ok = true;
    report = struct();
    report.batchId = localStringField(batchSpec, 'id');
    report.batchName = localStringField(batchSpec, 'name');
    report.batchRoot = char(string(opts.BatchRoot));
    report.pipeline = struct('status', 'missing', 'errors', {{ }}, 'warnings', {{ }});
    report.items = struct([]);
    report.summary = struct('totalItems', 0, 'validItems', 0, 'warningItems', 0, 'errorItems', 0);

    if nargin < 1 || isempty(batchSpec) || ~isstruct(batchSpec)
        ok = false;
        report.pipeline.status = 'error';
        report.pipeline.errors = {'batchSpec must be a struct.'};
        return;
    end
    if ~isfield(batchSpec, 'items') || isempty(batchSpec.items)
        ok = false;
        report.pipeline.status = 'error';
        report.pipeline.errors = {'batchSpec.items is empty.'};
        return;
    end

    [pipe, pipelineMsg] = resolveBatchPipeline(batchSpec);
    if isempty(pipe)
        ok = false;
        report.pipeline.status = 'error';
        report.pipeline.errors = {pipelineMsg};
    else
        report.pipeline.status = 'ok';
    end

    report.summary.totalItems = numel(batchSpec.items);
    report.items = repmat(localEmptyItemReport(), report.summary.totalItems, 1);

    for i = 1:report.summary.totalItems
        item = batchSpec.items(i);
        itemReport = localEmptyItemReport();
        itemReport.index = i;
        itemReport.id = localStringField(item, 'id');
        itemReport.kind = localStringField(item, 'kind');
        itemReport.name = localStringField(item, 'displayName');
        itemReport.sourceMode = localStringField(item, 'sourceMode');
        itemReport.catalogId = localStringField(item, 'catalogId');
        itemReport.projectMatPath = localStringField(item, 'projectMatPath');
        itemReport.datasetId = localStringField(item, 'datasetId');
        itemReport.status = 'error';

        if startsWith(lower(itemReport.kind), 'dataset')
            itemReport.errors{end+1} = 'Raw dataset batch execution is not enabled yet.'; %#ok<AGROW>
            report.items(i) = itemReport;
            ok = false;
            continue;
        end

        if isempty(itemReport.projectMatPath) || exist(itemReport.projectMatPath, 'file') ~= 2
            itemReport.errors{end+1} = ['Missing project MAT: ' itemReport.projectMatPath]; %#ok<AGROW>
            report.items(i) = itemReport;
            ok = false;
            continue;
        end

        try
            [ctx, ~] = buildPipelineBatchItemCtx(batchSpec, i, 'BatchRoot', opts.BatchRoot);
            if isfield(batchSpec, 'validation') && isstruct(batchSpec.validation) && ...
                    isfield(batchSpec.validation, 'itemOverrides') && ~isempty(batchSpec.validation.itemOverrides)
                ctx = mergePipelineRuntimeConfig(ctx, batchSpec.validation.itemOverrides);
            end
            [itemOk, validation] = validatePipeline(pipe, ctx, struct('allowGui', logical(opts.AllowGUI)));
            itemReport.pipelineOk = itemOk;
            itemReport.pipelineErrors = getFieldOrDefault(validation, 'errors', {});
            itemReport.pipelineWarnings = getFieldOrDefault(validation, 'warnings', {});
            itemReport.warnings = localCellstr(itemReport.pipelineWarnings);
            itemReport.errors = localCellstr(itemReport.pipelineErrors);
            if itemOk
                itemReport.status = 'ok';
            else
                itemReport.status = 'error';
                ok = false;
            end
        catch ME
            itemReport.errors{end+1} = ME.message; %#ok<AGROW>
            itemReport.status = 'error';
            ok = false;
        end

        if strcmp(itemReport.status, 'ok')
            report.summary.validItems = report.summary.validItems + 1;
            if ~isempty(itemReport.warnings)
                report.summary.warningItems = report.summary.warningItems + 1;
            end
        else
            report.summary.errorItems = report.summary.errorItems + 1;
        end
        report.items(i) = itemReport;
    end

    if ~isempty(report.pipeline.errors)
        ok = false;
    end
end

function [pipe, msg] = resolveBatchPipeline(batchSpec)
    msg = '';
    pipe = [];
    if isfield(batchSpec, 'pipelineTemplate') && ~isempty(batchSpec.pipelineTemplate) && ...
            (isstruct(batchSpec.pipelineTemplate) || isobject(batchSpec.pipelineTemplate))
        pipe = batchSpec.pipelineTemplate;
        return;
    end
    if ~isfield(batchSpec, 'pipelineRef') || ~isstruct(batchSpec.pipelineRef) || ...
            ~isfield(batchSpec.pipelineRef, 'path') || isempty(batchSpec.pipelineRef.path)
        msg = 'batchSpec.pipelineRef.path is empty.';
        return;
    end
    [pipe, msg] = pipelineLoad(char(string(batchSpec.pipelineRef.path)));
    if isempty(pipe)
        msg = ['Unable to load pipeline template: ' msg];
    end
end

function item = localEmptyItemReport()
    item = struct( ...
        'index', 0, ...
        'id', '', ...
        'kind', '', ...
        'name', '', ...
        'sourceMode', '', ...
        'catalogId', '', ...
        'projectMatPath', '', ...
        'datasetId', '', ...
        'status', 'pending', ...
        'pipelineOk', false, ...
        'pipelineErrors', {{}}, ...
        'pipelineWarnings', {{}}, ...
        'warnings', {{}}, ...
        'errors', {{}});
end

function txt = localStringField(S, fieldName)
    txt = '';
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        txt = char(string(S.(fieldName)));
    end
end

function out = localCellstr(in)
    if isempty(in)
        out = {};
        return;
    end
    if iscell(in)
        out = cell(size(in));
        for i = 1:numel(in)
            out{i} = char(string(in{i}));
        end
        return;
    end
    if isstring(in)
        out = cellstr(in);
        return;
    end
    if ischar(in)
        out = {in};
        return;
    end
    out = {char(string(in))};
end

function v = getFieldOrDefault(S, name, defaultVal)
    v = defaultVal;
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        v = S.(name);
    end
end
