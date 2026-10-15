function windows = sequences(classif, roiObj, n, selected, p)
%SEQUENCES Share training/inference segmentation; never bridge frame gaps.
base=trainingBounds.frames(classif,roiObj,n,[]);
if isempty(selected),windows={};return;end
selected=intersect(base,selected,'stable');windows={};
switch p.outputMode
    case 'video'
        if isequal(selected(:),base(:))&&~isempty(base),windows={base};end
    case 'window'
        for a=1:p.windowLength:numel(base)-p.windowLength+1
            f=base(a:a+p.windowLength-1);
            if all(ismember(f,selected))&&all(diff(f)==1),windows{end+1}=f;end %#ok<AGROW>
        end
    case 'frame'
        breaks=[1 find(diff(selected)~=1)+1 numel(selected)+1];
        for k=1:numel(breaks)-1
            f=selected(breaks(k):breaks(k+1)-1);
            L=p.windowLength;if L==0,L=numel(f);end
            for a=1:L:numel(f),windows{end+1}=f(a:min(a+L-1,numel(f)));end %#ok<AGROW>
        end
end
end
