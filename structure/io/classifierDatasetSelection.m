function selection = classifierDatasetSelection(c)
%CLASSIFIERDATASETSELECTION Read explicit train/validation/test ROI membership.
n=numel(c.roi);split=struct();
try,split=c.dataset.split;catch,end
train=[];try,train=c.trainingset;catch,end
if isfield(split,'train')&&~isempty(split.train),train=split.train;end
train=clean(train,n);val=[];if isfield(split,'val'),val=clean(split.val,n);end
test=[];if isfield(split,'test'),test=clean(split.test,n);end
% Preserve the historical complement only when no explicit held-out split exists.
if isempty(test)&&isempty(val),test=setdiff(1:n,train,'stable');end
selection=struct('train',train,'val',val,'test',test);
end
function value=clean(value,n)
value=unique(double(value(:).'),'stable');
value=value(isfinite(value)&value==fix(value)&value>=1&value<=n);
end
