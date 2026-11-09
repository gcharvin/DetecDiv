function m=instanceMetrics(truth,prediction,threshold)
%INSTANCEMETRICS Maximum-cardinality, then maximum-IoU one-to-one matching.
% IDs are frame-local, arbitrary positive integers. Background is zero.
if nargin<3,threshold=0.5;end
validateattributes(threshold,{'numeric'},{'scalar','finite','>',0,'<=',1});
assert(isequal(size(truth),size(prediction)),'classifierStats:Shape','GT and prediction sizes differ.');
for values={truth,prediction}
    a=double(values{1}(:));assert(all(isfinite(a)&a>=0&a==fix(a)), ...
        'classifierStats:InvalidMask','Instance masks must contain finite nonnegative integer labels.');
end
[g,~,gi]=unique(double(truth(:)));[p,~,pi]=unique(double(prediction(:)));
gkeep=g>0;pkeep=p>0;ng=nnz(gkeep);np=nnz(pkeep);
overlap=accumarray([gi pi],1,[numel(g) numel(p)]);
ga=sum(overlap,2);pa=sum(overlap,1);
intersection=overlap(gkeep,pkeep);union=ga(gkeep)+pa(pkeep)-intersection;
iou=intersection./union;pairs=zeros(0,2);sumIoU=0;
if ng>0&&np>0
    % One extra match outweighs every possible IoU tie-break combined.
    cost=ones(ng,np);eligible=iou>=threshold;
    cost(eligible)=-1-iou(eligible)/(1+min(ng,np));
    pairs=matchpairs(cost,0,'min');
    if ~isempty(pairs),sumIoU=sum(iou(sub2ind(size(iou),pairs(:,1),pairs(:,2))));end
end
tp=size(pairs,1);fp=np-tp;fn=ng-tp;
m=struct('groundTruthCount',ng,'predictionCount',np,'truePositive',tp, ...
    'falsePositive',fp,'falseNegative',fn,'sumMatchedIoU',sumIoU, ...
    'precision',ratio(tp,tp+fp),'recall',ratio(tp,tp+fn), ...
    'f1',ratio(2*tp,2*tp+fp+fn),'matchedIoU',ratio(sumIoU,tp), ...
    'panopticQuality',ratio(sumIoU,tp+0.5*(fp+fn)),'iouThreshold',threshold);
end
function v=ratio(a,b)
v=a./b;if b==0,v=NaN;end
end
