function c = classifierSetTrainingSelection(c,train)
%CLASSIFIERSETTRAININGSELECTION Change training membership, retain reserved val.
selection=classifierDatasetSelection(c);n=numel(c.roi);
train=unique(round(double(train(:).')),'stable');train=train(isfinite(train)&train>=1&train<=n);
val=setdiff(selection.val,train,'stable');test=setdiff(1:n,[train val],'stable');
c.trainingset=train;
if ~isstruct(c.dataset),c.dataset=struct();end
c.dataset.split=struct('train',train,'val',val,'test',test);
end
