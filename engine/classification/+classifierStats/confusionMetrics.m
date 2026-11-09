function m=confusionMetrics(matrix)
%CONFUSIONMETRICS Ratios in [0,1]; an unsupported denominator yields NaN.
tp=diag(matrix);support=sum(matrix,2);predicted=sum(matrix,1).';
fp=predicted-tp;fn=support-tp;total=sum(matrix(:));
m=struct('accuracy',ratio(sum(tp),total),'precision',ratio(tp,predicted), ...
    'recall',ratio(tp,support),'f1',ratio(2*tp,2*tp+fp+fn), ...
    'dice',ratio(2*tp,2*tp+fp+fn),'iou',ratio(tp,tp+fp+fn), ...
    'support',support,'predicted',predicted,'truePositive',tp,'falsePositive',fp,'falseNegative',fn);
end
function v=ratio(a,b)
v=a./b;v(b==0)=NaN;
end
