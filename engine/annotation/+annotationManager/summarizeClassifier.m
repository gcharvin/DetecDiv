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
    'supportsBootstrap', spec.supportsBootstrap);
rows = repmat(template, numel(roiIndices), 1);
for i = 1:numel(roiIndices)
    index = roiIndices(i);
    summary = annotationManager.inspect(classif.roi(index), spec, ...
        'CheckAssets', ~p.Results.Fast);
    rows(i).roiIndex = index;
    rows(i).roiId = char(string(classif.roi(index).id));
    rows(i).status = summary.status;
    rows(i).coverage = summary.coverage.fraction;
    rows(i).reviewed = summary.coverage.reviewed;
    rows(i).total = summary.coverage.total;
    rows(i).legacy = summary.legacy;
end
end
