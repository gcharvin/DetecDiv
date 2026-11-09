function frames=contextFrames(classif,roiObj,n,target,p)
%CONTEXTFRAMES Center a target window without crossing ROI bounds or gaps.
% Edge repetition keeps the target at a fixed position in every input.
frames=target;
if ~isfield(p,'contextWindowLength')||p.contextWindowLength==0,return;end
base=trainingBounds.frames(classif,roiObj,n,[]);base=sort(unique(base));
assert(all(ismember(target,base))&&all(diff(target)==1), ...
    'lstm_timeseries:ContextBounds','Target must be contiguous and inside ROI bounds.');
breaks=[1 find(diff(base)~=1)+1 numel(base)+1];
for k=1:numel(breaks)-1
    run=base(breaks(k):breaks(k+1)-1);
    if all(ismember(target,run))
        flank=(p.contextWindowLength-numel(target))/2;
        assert(flank>=0&&flank==fix(flank),'lstm_timeseries:ContextBounds','Context must symmetrically contain the target.');
        frames=max(run(1),min(run(end),(target(1)-flank):(target(end)+flank)));
        return;
    end
end
error('lstm_timeseries:ContextBounds','Context cannot bridge a gap in the ROI bounds.');
end
