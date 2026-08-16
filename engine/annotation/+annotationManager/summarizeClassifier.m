function rows = summarizeClassifier(classif, roiIndices, varargin)
%ANNOTATIONMANAGER.SUMMARIZECLASSIFIER Build classifierGUI annotation rows.

if nargin < 2 || isempty(roiIndices), roiIndices = 1:numel(classif.roi); end
p = inputParser;
p.addParameter('Fast', false, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});
roiIndices = unique(round(double(roiIndices(:)')), 'stable');
roiIndices = roiIndices(isfinite(roiIndices) & roiIndices >= 1 & ...
    roiIndices <= numel(classif.roi));
spec = annotationManager.specForClassifier(classif);
template = struct('roiIndex', 0, 'roiId', '', 'status', 'missing', ...
    'coverage', 0, 'reviewed', 0, 'total', 0, 'legacy', false, ...
    'validationStatus', 'not_run', 'validationMessage', '', ...
    'validatedAt', '', ...
    'coverageComponents', struct([]), ...
    'supportsBootstrap', spec.supportsBootstrap);
rows = repmat(template, numel(roiIndices), 1);
for i = 1:numel(roiIndices)
    index = roiIndices(i);
    bounds = trainingBounds.resolve(classif,index);
    reviewFrames = [];
    if ~isempty(bounds), reviewFrames = bounds(1):bounds(2); end
    summary = annotationManager.inspect(classif.roi(index), spec, ...
        'CheckAssets', ~p.Results.Fast,'ReviewFrames',reviewFrames);
    if p.Results.Fast && summary.legacy && strcmpi(summary.status, 'missing')
        % A missing lifecycle manifest is not proof that legacy GT assets
        % are absent. Fall back to the asset scan before reporting Missing;
        % otherwise older reviewed families disappear from classifierGUI.
        summary = annotationManager.inspect(classif.roi(index), spec, ...
            'CheckAssets', true,'ReviewFrames',reviewFrames);
    end
    rows(i).roiIndex = index;
    rows(i).roiId = char(string(classif.roi(index).id));
    rows(i).status = summary.status;
    rows(i).coverage = summary.coverage.fraction;
    rows(i).reviewed = summary.coverage.reviewed;
    rows(i).total = summary.coverage.total;
    rows(i).coverageComponents = summary.coverage.components;
    rows(i).legacy = summary.legacy;
    rows(i).validationStatus = summary.validationStatus;
    rows(i).validationMessage = summary.validationMessage;
    rows(i).validatedAt = summary.validatedAt;
end
end
