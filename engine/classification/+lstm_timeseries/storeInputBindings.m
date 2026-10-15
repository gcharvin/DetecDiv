function bindings=storeInputBindings(classif,params)
%STOREINPUTBINDINGS Apply an ordered Pipeline2 binding set, without saving GT.
p=lstm_timeseries.parameters(classif,params);
bindings=struct('selector',{},'component',{});
for k=1:p.featureCount
    selector=p.(sprintf('feature%d',k));parts=regexp(selector,'\s*/\s*','split');
    assert(numel(parts)==2&&all(strlength(strtrim(string(parts)))>0)&&~startsWith(selector,'@'), ...
        'lstm_timeseries:UnconfiguredBinding','Select an existing dataseries and variable for input %d before applying.',k);
    assert(~strcmp(parts{1},classif.strid)&&~endsWith(parts{2},'_training'), ...
        'lstm_timeseries:GroundTruthInput','Training labels and this classifier output cannot be inputs.');
    bindings(k)=struct('selector',selector,'component',p.(sprintf('featureColumn%d',k)));
end
data=classif.dataset;if ~isstruct(data),data=struct();end
data.inputBindings=bindings;classif.dataset=data;
keys=fieldnames(classif.trainingParam);
remove=strcmp(keys,'featureCount')|~cellfun(@isempty,regexp(keys,'^feature(?:Column)?\d+$','once'));
classif.trainingParam=rmfield(classif.trainingParam,keys(remove));
end
