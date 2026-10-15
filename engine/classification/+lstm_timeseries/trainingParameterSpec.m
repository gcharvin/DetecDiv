function [spec, policy] = trainingParameterSpec(classif)
if nargin<1,classif=[];end
p=lstm_timeseries.setparam();cfg=lstm_timeseries.parameters(classif);
for k=1:cfg.featureCount,p.(sprintf('featureColumn%d',k))=1;end
spec=classifierBinding.parameterSpecFromDefaults(p);
keep=true(size(spec));
for k=1:numel(spec)
    number=regexp(spec(k).param,'^feature(?:Column)?(\d+)$','tokens','once');
    if ~isempty(number)&&str2double(number{1})>cfg.featureCount,keep(k)=false;end
end
spec=spec(keep);policy=struct('showUnspecified',false);
for k=1:numel(spec)
    if startsWith(spec(k).param,'featureColumn')
        spec(k).group='Data bindings';spec(k).tip='Scalar column index inside the chosen numeric table variable (1 for a scalar variable).';
    end
end
end
