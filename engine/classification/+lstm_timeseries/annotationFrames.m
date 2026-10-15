function [frames, grouped] = annotationFrames(classif, roiObj, currentFrame, n)
p=lstm_timeseries.parameters(classif);
base=trainingBounds.frames(classif,roiObj,n,[]);
frames=[];grouped=~strcmp(p.outputMode,'frame');
i=find(base==currentFrame,1);if isempty(i),return;end
switch p.outputMode
    case 'frame',frames=currentFrame;
    case 'video',frames=base;
    case 'window'
        first=1+floor((i-1)/p.windowLength)*p.windowLength;
        if first+p.windowLength-1<=numel(base),frames=base(first:first+p.windowLength-1);end
end
end
