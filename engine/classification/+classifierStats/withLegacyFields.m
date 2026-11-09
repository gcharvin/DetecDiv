function report=withLegacyFields(report)
%WITHLEGACYFIELDS Preserve summary consumers of classi.score (percent units).
% The versioned components retain explicit [0,1] metrics. Legacy summary fields
% describe the first evaluated component; comments identify that component.
c=report.components(1);m=c.pixel;selected=1:numel(c.classNames);
if c.instanceSegmentation||strcmp(c.kind,'semantic_mask')||strcmp(c.kind,'instance_mask')
    selected=selected(2:end);
end
report.primaryComponent=c.id;report.comments=['Reviewed GT agreement: ' c.id '; legacy summary fields in percent; components in [0,1].'];
report.thr=NaN;report.N=sum(c.confusion(:));report.accuracy=100*m.accuracy;
report.precision=100*weighted(m.precision(selected),m.support(selected));
report.recall=100*weighted(m.recall(selected),m.support(selected));
report.fscore=100*weighted(m.f1(selected),m.support(selected));
report.confusion=c.confusion;report.confusionLbl=1:numel(c.classNames);report.classNames=c.classNames;
report.classes=struct('name',{},'precision',{},'accuracy',{},'recall',{},'fscore',{},'N',{});
for k=selected
    % Historical per-class "accuracy" is precision, retained as an alias.
    report.classes(end+1)=struct('name',c.classNames{k},'precision',100*m.precision(k), ...
        'accuracy',100*m.precision(k),'recall',100*m.recall(k),'fscore',100*m.f1(k),'N',m.support(k));
end
end
function v=weighted(a,w)
valid=isfinite(a)&w>0;v=sum(a(valid).*w(valid))/sum(w(valid));
end
