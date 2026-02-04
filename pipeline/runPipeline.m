function report = runPipeline(steps, ctx)
% runPipeline Run a linear pipeline with requires/provides checks.
%   report = runPipeline(steps, ctx)
%
% steps: cell array or struct array with fields:
%   - id (string)
%   - run (function handle) : out = run(ctx)
%   - requires, provides (cellstr)
%
% ctx: pipeline context (from ctxMake). Optional fields used:
%   - project : shallow project object for project patches
%   - sel.rois or rois : ROI array for ROI patches

    if nargin < 2
        ctx = struct();
    end

    steps = normalizeSteps(steps);

    issues = checkConnectivity(steps, ctx);
    if ~isempty(issues)
        msgs = cell(1, numel(issues));
        for i = 1:numel(issues)
            msgs{i} = sprintf('%s missing: %s', issues(i).stepId, strjoin(issues(i).missing, ', '));
        end
        error('runPipeline:Connectivity', 'Connectivity check failed:\n%s', strjoin(msgs, '\n'));
    end

    outs = cell(1, numel(steps));
    available = {};

    for i = 1:numel(steps)
        step = steps{i};
        stepId = getStepId(step, i);

        if ~isfield(step, 'run') || isempty(step.run)
            error('runPipeline:NoRun', 'Step %s has no run() handle.', stepId);
        end

        out = step.run(ctx);
        if ~isstruct(out)
            error('runPipeline:BadOut', 'Step %s did not return a struct.', stepId);
        end

        if ~isfield(out, 'stepId') || isempty(out.stepId)
            out.stepId = stepId;
        end
        if ~isfield(out, 'requires') && isfield(step, 'requires')
            out.requires = step.requires;
        end
        if ~isfield(out, 'provides') && isfield(step, 'provides')
            out.provides = step.provides;
        end

        % Apply patches if provided
        if isfield(out, 'patch') && ~isempty(out.patch)
            if isfield(out.patch, 'project') && ~isempty(out.patch.project)
                if isfield(ctx, 'project') && ~isempty(ctx.project)
                    projectApplyPatch(ctx.project, out.patch, ctx);
                end
            end
            if isfield(out.patch, 'roi') && ~isempty(out.patch.roi)
                rois = [];
                if isfield(ctx, 'rois') && ~isempty(ctx.rois)
                    rois = ctx.rois;
                elseif isfield(ctx, 'sel') && isfield(ctx.sel, 'rois') && ~isempty(ctx.sel.rois)
                    rois = ctx.sel.rois;
                end
                if ~isempty(rois)
                    roiApplyPatch(rois, out.patch, ctx);
                end
            end
        end

        outs{i} = out;
        if isfield(out, 'provides') && ~isempty(out.provides)
            available = union(available, normalizeList(out.provides));
        end
    end

    report = struct();
    report.ok = true;
    report.outs = outs;
    report.provides = available;
    report.issues = issues;
end

function steps = normalizeSteps(steps)
    if isempty(steps)
        steps = {};
        return;
    end
    if isstruct(steps)
        steps = num2cell(steps);
    end
    if ~iscell(steps)
        steps = {steps};
    end
end

function list = normalizeList(v)
    if isstring(v), v = cellstr(v); end
    if ischar(v), v = {v}; end
    if iscell(v), list = v; else, list = {v}; end
    list = list(:)';
end

function id = getStepId(step, idx)
    id = sprintf('step_%d', idx);
    if isfield(step, 'id') && ~isempty(step.id)
        id = char(step.id);
    end
end
