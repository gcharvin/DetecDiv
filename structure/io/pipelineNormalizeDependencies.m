function [changed, report] = pipelineNormalizeDependencies(pipeIn, varargin)
% pipelineNormalizeDependencies  Rewrite safe embedded module paths relative to pipeline root.
%
%   [changed, report] = pipelineNormalizeDependencies(pipeIn, ...)
%
% Supported options:
%   'WriteChanges'   logical (default false)
%   'CreateBackup'   logical (default false, reserved)
%   'ProjectRoot'    optional project anchor
%   'Mode'           descriptive mode string
%
% This first implementation is intentionally conservative. It only rewrites
% module reference paths when they already resolve under the current pipeline
% root and can therefore become explicit relative references without changing
% semantics.

    opts = parseNormalizeOptions(varargin{:});
    reportBefore = pipelineAuditDependencies(pipeIn, 'ProjectRoot', opts.ProjectRoot, 'Mode', opts.Mode);
    changed = false;
    report = reportBefore;

    [pipeObj, shouldSave] = normalizeWritablePipelineInput(pipeIn);
    if isempty(pipeObj)
        return;
    end

    if isempty(pipeObj.nodes)
        return;
    end

    for i = 1:numel(pipeObj.nodes)
        if i > numel(reportBefore.dependencies)
            continue;
        end
        dep = reportBefore.dependencies(i);
        action = char(string(dep.normalization.action));
        normalizedRef = char(string(dep.normalization.normalized_reference));
        if ~strcmp(action, 'rewrite_relative_module_path') || isempty(normalizedRef)
            continue;
        end

        node = pipeObj.nodes(i);
        if ~isfield(node, 'params') || ~isstruct(node.params)
            node.params = struct();
        end
        node.params.modulePath = normalizedRef;

        if isfield(node, 'origin') && isstruct(node.origin) && isfield(node.origin, 'path')
            node.origin.path = normalizedRef;
        end

        pipeObj.nodes(i) = node;
        changed = true;
    end

    if changed && opts.WriteChanges && shouldSave
        pipelineSave(pipeObj);
    end

    if changed
        report = pipelineAuditDependencies(pipeObj, 'ProjectRoot', opts.ProjectRoot, 'Mode', opts.Mode);
        report.changed = true;
    else
        report.changed = false;
    end
end

function opts = parseNormalizeOptions(varargin)
    opts = struct( ...
        'WriteChanges', false, ...
        'CreateBackup', false, ...
        'ProjectRoot', '', ...
        'Mode', 'repair');

    if mod(numel(varargin), 2) ~= 0
        error('pipelineNormalizeDependencies:Args', 'Arguments must be Name/Value pairs.');
    end
    for i = 1:2:numel(varargin)
        name = lower(char(string(varargin{i})));
        value = varargin{i+1};
        switch name
            case 'writechanges'
                opts.WriteChanges = logical(value);
            case 'createbackup'
                opts.CreateBackup = logical(value); %#ok<NASGU>
            case 'projectroot'
                opts.ProjectRoot = char(string(value));
            case 'mode'
                opts.Mode = char(string(value));
            otherwise
                error('pipelineNormalizeDependencies:UnknownOption', 'Unknown option "%s".', name);
        end
    end
end

function [pipeObj, shouldSave] = normalizeWritablePipelineInput(pipeIn)
    shouldSave = false;
    if isa(pipeIn, 'pipeline')
        pipeObj = pipeIn;
        shouldSave = ~isempty(pipeObj.path);
        return;
    end
    if ischar(pipeIn) || isstring(pipeIn)
        [pipeObj, msg] = pipelineLoad(char(string(pipeIn)));
        if isempty(pipeObj)
            error('pipelineNormalizeDependencies:LoadFailed', 'Could not load pipeline: %s', msg);
        end
        shouldSave = ~isempty(pipeObj.path);
        return;
    end
    if isstruct(pipeIn) && isfield(pipeIn, 'nodes')
        pipeObj = [];
        return;
    end
    error('pipelineNormalizeDependencies:UnsupportedInput', 'Unsupported input type: %s', class(pipeIn));
end
