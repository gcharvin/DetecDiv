function p = defaultTrainingParam()
%DEFAULTTRAININGPARAM Standard classifier-package discovery hook.
p=lstm_timeseries.setparam();
keys=fieldnames(p);remove=strcmp(keys,'featureCount')|~cellfun(@isempty,regexp(keys,'^feature(?:Column)?\d+$','once'));
parameterKeys=keys(~strcmp(keys,'tip'));
keep=~strcmp(parameterKeys,'featureCount')&cellfun(@isempty,regexp(parameterKeys,'^feature(?:Column)?\d+$','once'));
if isfield(p,'tip'),p.tip=p.tip(keep);end
p=rmfield(p,keys(remove));
end
