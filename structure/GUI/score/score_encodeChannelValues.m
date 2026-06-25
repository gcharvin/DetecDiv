function encodedValues = score_encodeChannelValues(roiObj, channelIdx, displayValues)
% score_encodeChannelValues Convert UI values to encoded uint16-like values.

tfm = score_channelValueTransform(roiObj, channelIdx);
encodedValues = double(displayValues);
if ~strcmp(tfm.mode, 'physical')
    encodedValues = max(0, min(65535, encodedValues));
    return;
end

er = tfm.encodedRange;
pr = tfm.physicalRange;
encodedValues = er(1) + (double(displayValues) - pr(1)) .* (er(2) - er(1)) ./ (pr(2) - pr(1));
encodedValues = max(min(er), min(max(er), encodedValues));
end
