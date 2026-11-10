function [prob,ids]=trajectoryPredictions(classif,roiObj,X,p,model,classifier,selected,environment)
%TRAJECTORYPREDICTIONS One recurrent pass per contiguous bounded ROI run.
% Subset requests retain the preceding bounded history; only requested
% complete units are published. A unidirectional LSTM cannot use future input.
n=size(X,2);C=numel(model.classes);prob=nan(n,C);ids=zeros(n,1);
base=trainingBounds.frames(classif,roiObj,n,[]);
units=lstm_timeseries.sequences(classif,roiObj,n,base,p);runs=lstm_timeseries.trajectoryRuns(units);
learned=cellstr(string(classifier.Layers(end).Classes));[ok,order]=ismember(model.classes,learned);assert(all(ok));
for k=1:numel(runs)
    frames=runs{k};input=lstm_timeseries.transform(X(:,frames),model.normalization,model.missingPolicy);
    [~,scores]=classify(classifier,{input},'ExecutionEnvironment',environment);
    if iscell(scores),scores=scores{1};end
    if size(scores,1)==C,scores=scores';end
    assert(isequal(size(scores),[numel(frames) C]),'lstm_timeseries:PredictionShape','Unexpected trajectory-score shape.');
    scores=scores(:,order);
    for endpoint=p.windowLength:p.windowLength:numel(frames)
        f=frames(endpoint-p.windowLength+1:endpoint);
        if ~all(ismember(f,selected)),continue;end
        row=scores(endpoint,:);prob(f,:)=repmat(row,numel(f),1);[~,winner]=max(row);ids(f)=winner;
    end
end
end
