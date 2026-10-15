function [spec, policy] = trainingParameterSpec(classif)
if nargin<1,classif=[];end
p=lstm_timeseries.setparam();
spec=classifierBinding.parameterSpecFromDefaults(p);
keys={spec.param};keep=~strcmp(keys,'featureCount')&cellfun(@isempty,regexp(keys,'^feature(?:Column)?\d+$','once'));
spec=spec(keep);
policy=struct('showUnspecified',false,'showBindings',false, ...
    'inputEditor','lstm_timeseries.openInputBindings','inputSummary','lstm_timeseries.inputBindingSummary');
end
