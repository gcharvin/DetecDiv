function values = score_decodeChannelValues(roiObj, channelIdx, encodedValues)
% score_decodeChannelValues Convert encoded uint16-like values to UI values.

tfm = score_channelValueTransform(roiObj, channelIdx);
values = double(encodedValues);
if ~strcmp(tfm.mode, 'physical')
    return;
end

er = tfm.encodedRange;
pr = tfm.physicalRange;
values = pr(1) + (double(encodedValues) - er(1)) .* (pr(2) - pr(1)) ./ (er(2) - er(1));
end
