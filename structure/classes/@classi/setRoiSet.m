function setRoiSet(classif,index,subset)
%SETROISET Keep a single ROI's dataset membership and legacy training list in sync.
validateattributes(index,{'numeric'},{'scalar','integer','positive','<=',numel(classif.roi)});
subset = validatestring(subset,{'Training','Test','Validation'});
train = reshape(double(classif.trainingset),1,[]);
dataset = classif.dataset;
if ~isstruct(dataset) || ~isscalar(dataset), dataset = struct(); end
if ~isfield(dataset,'split') || ~isstruct(dataset.split), dataset.split = struct(); end
val = [];
if isfield(dataset.split,'val'), val = reshape(double(dataset.split.val),1,[]); end
train = validIndices(train,numel(classif.roi)); val = validIndices(val,numel(classif.roi));
train = setdiff(train,index,'stable'); val = setdiff(val,index,'stable');
switch subset
    case 'Training', train(end+1) = index;
    case 'Validation', val(end+1) = index;
end
val = setdiff(val,train,'stable');
dataset.split.train = train; dataset.split.val = val;
dataset.split.test = setdiff(1:numel(classif.roi),[train val],'stable');
classif.trainingset = train; classif.dataset = dataset;
% Existing formatter parameters must not retain the old training selection.
if isstruct(classif.trainingParam) && isscalar(classif.trainingParam) && isfield(classif.trainingParam,'rois')
    classif.trainingParam.rois = train;
end
end
function values = validIndices(values,count)
values = unique(values(isfinite(values) & values == fix(values) & values >= 1 & values <= count),'stable');
end
