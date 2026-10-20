function frame = adjacentAnnotationFrame(classif,roiObj,currentFrame,direction,n)
%ADJACENTANNOTATIONFRAME Navigate complete annotation units within ROI bounds.
assert(isscalar(direction)&&ismember(direction,[-1 1]), ...
    'lstm_timeseries:NavigationDirection','Direction must be -1 or 1.');
if nargin<5,n=annotationManager.frameCount(roiObj);end
p=lstm_timeseries.parameters(classif);base=trainingBounds.frames(classif,roiObj,n,[]);
frame=currentFrame;
if strcmp(p.outputMode,'frame')
    starts=base;stops=base;
else
    units=lstm_timeseries.sequences(classif,roiObj,n,base,p);
    starts=cellfun(@(f)f(1),units);stops=cellfun(@(f)f(end),units);
end
if isempty(starts),return;end
index=find(currentFrame>=starts&currentFrame<=stops,1);
if ~isempty(index)
    index=max(1,min(numel(starts),index+direction));
elseif direction>0
    index=find(starts>currentFrame,1);if isempty(index),index=numel(starts);end
else
    index=find(stops<currentFrame,1,'last');if isempty(index),index=1;end
end
frame=starts(index);
end
