function [plan, overrides, accepted] = annotationResolvePredictionInputs( ...
        parent, classif, roiIndices, plan)
%ANNOTATIONRESOLVEPREDICTIONINPUTS Resolve only inputs already present in ROIs.
%   This helper never launches segmentation.  In particular, CellposeSAM
%   remains an explicit, separate classifier/pipeline action.

if nargin < 4, plan = []; end
overrides = struct();
accepted = false;
if isempty(plan)
    try
        plan = classifierPredictForAnnotation(classif, roiIndices, ...
            'PlanOnly', true);
    catch ME
        uialert(parent, ME.message, 'Cannot prepare model prediction', ...
            'Icon', 'error');
        return;
    end
end
if ~planCanRun(plan)
    requests = annotationInputMappingRequests(plan);
    if isempty(requests)
        uialert(parent, planIssues(plan), 'Cannot run active model', ...
            'Icon', 'error');
        return;
    end
    [overrides, accepted] = annotationInputMappingDialog(parent, plan);
    if ~accepted, return; end
    try
        plan = classifierPredictForAnnotation(classif, roiIndices, ...
            'PlanOnly', true, 'InputOverrides', overrides);
    catch ME
        accepted = false;
        uialert(parent, ME.message, 'Cannot prepare model prediction', ...
            'Icon', 'error');
        return;
    end
    if ~planCanRun(plan)
        accepted = false;
        uialert(parent, planIssues(plan), 'Cannot run active model', ...
            'Icon', 'error');
        return;
    end
end

accepted = true;
end

function value = planCanRun(plan)
value = false;
try, value = logical(plan.canRun); catch, end
end

function text = planIssues(plan)
text = 'The active model inputs could not be resolved safely.';
try
    issues = string(plan.issues);
    issues = issues(strlength(issues) > 0);
    if ~isempty(issues), text = char(strjoin(issues, newline)); end
catch
end
text = sprintf('%s\n\n%s', text, separateSegmentationGuidance(plan));
end

function text = separateSegmentationGuidance(plan) %#ok<INUSD>
text = ['The active latent model only uses compatible PRED masks/tracks ' ...
    'that already exist in the ROI. Run CellposeSAM separately, then ' ...
    'click Refresh and reopen Initialize GT. No segmentation is launched ' ...
    'automatically from Initialize GT.'];
end
