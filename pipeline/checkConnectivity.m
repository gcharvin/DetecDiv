function issues = checkConnectivity(steps, ctx)
% checkConnectivity Validate requires/provides along a linear pipeline.
%   issues = checkConnectivity(steps, ctx)
% Returns array of structs with fields: stepId, missing, requires, available.

    if nargin < 2
        ctx = struct();
    end

    steps = normalizeSteps(steps);

    available = {};
    if isfield(ctx, 'provides') && ~isempty(ctx.provides)
        available = normalizeList(ctx.provides);
    end

    issues = struct('stepId', {}, 'missing', {}, 'requires', {}, 'available', {});

    for i = 1:numel(steps)
        step = steps{i};
        req = {};
        if isfield(step, 'requires') && ~isempty(step.requires)
            req = normalizeList(step.requires);
        end
        missing = setdiff(req, available);
        if ~isempty(missing)
            issue.stepId = getStepId(step, i);
            issue.missing = missing;
            issue.requires = req;
            issue.available = available;
            issues(end+1) = issue; %#ok<AGROW>
        end
        if isfield(step, 'provides') && ~isempty(step.provides)
            available = union(available, normalizeList(step.provides));
        end
    end
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
