function rows = numericSeries(roiObj)
%NUMERICSERIES Inventory numeric temporal table variables without images.
rows=struct('name',{},'group',{},'variable',{},'columns',{},'roiCount',{});
data=roiObj.data;
if isempty(data)||all(arrayfun(@(d)isempty(d.data),data))
    filename=fullfile(roiObj.path,['data_' roiObj.id '.mat']);
    if isfile(filename),roiObj.load('Data','Silent');data=roiObj.data;end
end
for k=1:numel(data)
    ds=data(k);t=ds.data;group=char(string(ds.groupid));
    if isempty(ds.groupid)||~istable(t)||~strcmp(ds.type,'temporal'),continue;end
    for name=t.Properties.VariableNames
        key=name{1};[v,valid]=classifierBinding.numericTrace(t.(key));
        if ~valid||endsWith(key,'_training'),continue;end
        rows(end+1)=struct('name',[group ' / ' key],'group',group, ...
            'variable',key,'columns',size(v,2),'roiCount',1); %#ok<AGROW>
    end
end
end
