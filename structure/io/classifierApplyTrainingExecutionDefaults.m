function params = classifierApplyTrainingExecutionDefaults( ...
        params, classiObj, spec, intent)
%classifierApplyTrainingExecutionDefaults Apply training-compatible runtime defaults.

if nargin < 1 || isempty(params) || ~isstruct(params)
    params = struct();
end
if nargin < 4
    return;
end
intent = lower(strtrim(char(string(intent))));
if ~any(strcmp(intent, {'validate','annotation','active_model'}))
    return;
end
defaults = classifierTrainingExecutionDefaults(classiObj, spec);
if isempty(defaults) || ~isstruct(defaults) || ~isstruct(spec)
    return;
end

% Pipeline validation inherits only graph-safe static values.  Artifact
% paths, typed input bindings and canonical PRED names stay private to the
% linked classifier.  Direct annotation inference, on the other hand, must
% execute the exact post-training deployment snapshot, including those
% private fields; otherwise a legacy in-memory executionParam can silently
% select the wrong backend or make the newly written PRED family
% undiscoverable by the GT bootstrap catalog.
groups = {'staticKeys'};
if any(strcmp(intent, {'annotation','active_model'}))
    groups = {'staticKeys','inputKeys','artifactKeys','outputKeys'};
end
declared = {};
for i = 1:numel(groups)
    if isfield(spec, groups{i})
        declared = [declared cellstr(string(spec.(groups{i})))]; %#ok<AGROW>
    end
end
declared = unique(declared, 'stable');
keys = intersect(declared, fieldnames(defaults), 'stable');
for i = 1:numel(keys)
    params.(keys{i}) = defaults.(keys{i});
end
end
