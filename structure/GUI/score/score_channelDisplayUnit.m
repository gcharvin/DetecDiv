function unit = score_channelDisplayUnit(roiObj, channelIdx)
% score_channelDisplayUnit Human-readable unit for display tables and plots.

tfm = score_channelValueTransform(roiObj, channelIdx);
unit = tfm.unit;
if strcmp(tfm.mode, 'raw')
    unit = 'raw';
end
end
