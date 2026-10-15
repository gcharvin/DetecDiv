function [X, schema] = features(classif, roiObj, p)
%FEATURES Align numeric scalar traces by absolute ROI frame; no image load.
if nargin<3,p=lstm_timeseries.parameters(classif);end
classifierBinding.numericSeries(roiObj); % materialize persisted dataseries if needed
n=annotationManager.frameCount(roiObj);data=roiObj.data;
assert(n>0,'lstm_timeseries:NoFrames','ROI %s has no temporal rows.',roiObj.id);
X=nan(p.featureCount,n);schema=struct('selector',{},'group',{},'variable',{},'column',{});
for k=1:p.featureCount
    selector=strtrim(p.(sprintf('feature%d',k)));column=p.(sprintf('featureColumn%d',k));
    parts=regexp(selector,'\s*/\s*','split');
    assert(numel(parts)==2&&all(strlength(string(parts))>0)&&~startsWith(selector,'@'), ...
        'lstm_timeseries:FeatureBinding','Input %d requires a resolved "group / variable" binding, got "%s".',k,selector);
    group=parts{1};variable=parts{2};
    assert(~strcmp(group,classif.strid)&&~endsWith(variable,'_training'), ...
        'lstm_timeseries:GroundTruthInput','Training labels and the classifier own output cannot be input features.');
    match=find(strcmp(string({data.groupid}),string(group)));
    assert(numel(match)==1,'lstm_timeseries:MissingSeries','ROI %s: expected one dataseries "%s".',roiObj.id,group);
    ds=data(match);t=ds.data;
    assert(strcmp(ds.type,'temporal')&&ismember(variable,t.Properties.VariableNames), ...
        'lstm_timeseries:MissingVariable','ROI %s: no temporal variable "%s" in "%s".',roiObj.id,variable,group);
    [values,valid]=classifierBinding.numericTrace(t.(variable));
    assert(valid&&size(values,2)>=column, ...
        'lstm_timeseries:NonNumericFeature','%s column %d must be a real numeric scalar per frame. Select/aggregate multiple objects upstream.',selector,column);
    frames=(1:height(t))';
    if ismember('frame',t.Properties.VariableNames),frames=double(t.frame);end
    assert(isvector(frames)&&numel(frames)==height(t)&&all(isfinite(frames))&& ...
        all(frames==fix(frames))&&all(frames>=1)&&all(diff(frames)>0), ...
        'lstm_timeseries:FrameAlignment','%s requires unique increasing absolute frames; aggregate object/generation tables first.',group);
    if ~isempty(frames)&&max(frames)>size(X,2),X(:,end+1:max(frames))=NaN;end
    trace=double(values(:,column));
    if strcmp(ds.class,'classification')&& ...
            (startsWith(variable,'prob')||strcmp(variable,'id'))&&ismember('id',t.Properties.VariableNames)
        predictionIds=t.id;
        if isnumeric(predictionIds)&&isvector(predictionIds)&&numel(predictionIds)==height(t)
            trace(~isfinite(predictionIds)|predictionIds<=0)=NaN;
        end
    end
    X(k,frames)=trace;
    schema(k)=struct('selector',selector,'group',group,'variable',variable,'column',column);
end
end
