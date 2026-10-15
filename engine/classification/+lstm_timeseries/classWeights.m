function [weights,counts] = classWeights(labels, classes, policy)
%CLASSWEIGHTS Fit loss weights exclusively to the supplied training labels.
labels=string(labels(:));classes=string(classes(:)');
assert(all(ismember(labels,classes)),'lstm_timeseries:UnknownLabel','Training labels must belong to the declared classes.');
counts=arrayfun(@(name)sum(labels==name),classes);
assert(all(counts>0),'lstm_timeseries:MissingTrainingClass','Every class must occur in actual training samples.');
weights=ones(size(counts));
switch char(policy)
    case 'none'
    case 'inverse-frequency'
        weights=numel(labels)./(numel(classes)*counts);
    otherwise
        error('lstm_timeseries:ClassWeighting','Unknown class weighting policy.');
end
end
