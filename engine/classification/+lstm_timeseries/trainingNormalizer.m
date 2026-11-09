function stats=trainingNormalizer(samples)
%TRAININGNORMALIZER Count each observed training ROI/frame once, not per overlap.
if ~isfield(samples,'inputFrames')
    stats=lstm_timeseries.normalizer([samples.X]);return;
end
values=[];
for roiIndex=unique([samples.roiIndex])
    part=samples([samples.roiIndex]==roiIndex);
    frames=[part.inputFrames];X=[part.X];
    [~,indices]=unique(frames,'stable');
    values=[values X(:,indices)]; %#ok<AGROW>
end
stats=lstm_timeseries.normalizer(values);
end
