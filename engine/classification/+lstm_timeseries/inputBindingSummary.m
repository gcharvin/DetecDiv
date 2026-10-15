function lines=inputBindingSummary(classif)
%INPUTBINDINGSUMMARY Saved bindings only: never scan ROI while showing training.
p=lstm_timeseries.parameters(classif);lines=cell(p.featureCount,1);
for k=1:p.featureCount
    value=p.(sprintf('feature%d',k));if isempty(value),value='<not configured>';end
    component=p.(sprintf('featureColumn%d',k));suffix='';
    if component>1,suffix=sprintf(' (component %d)',component);end
    lines{k}=sprintf('%d. %s%s',k,value,suffix);
end
end
