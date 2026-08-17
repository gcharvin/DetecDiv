function p = trackerTrainingParams(tp)
%TRACKERTRAININGPARAMS Map composite controls to the existing tracker backend.
p = cellLatentTracker.utils.defaultTrainingParam();
p.instanceChannelName = textValue(tp.instanceChannelName);
p.groundTruthChannelName = textValue(tp.trackChannelName);
p.brightfieldChannelName = textValue(tp.brightfieldChannelName);
p.validationFraction = double(tp.validationFraction);
p.frameIntervalMinutes = double(tp.frameIntervalMinutes);
p.trainingDomain = textValue(tp.trainingDomain);
p.topK = double(tp.trackingTopK);
p.minimumTruthOverlap = double(tp.trackingMinimumTruthOverlap);
p.minimumDetectionCoverage = double(tp.trackingMinimumDetectionCoverage);
p.initialModelSource = tp.trackingInitialModelSource;
p.initialCheckpoint = textValue(tp.trackingInitialCheckpoint);
p.epochs = double(tp.trackingEpochs);
p.learningRate = double(tp.trackingLearningRate);
p.weightDecay = double(tp.trackingWeightDecay);
p.hiddenDim = double(tp.trackingHiddenDim);
p.dropout = double(tp.trackingDropout);
p.associationLossWeight = double(tp.trackingAssociationLossWeight);
p.appearanceLossWeight = double(tp.trackingAppearanceLossWeight);
p.endLossWeight = double(tp.trackingEndLossWeight);
p.device = textValue(tp.device);
end

function value = textValue(value)
while iscell(value)
    if isempty(value),value='';return;else,value=value{end};end
end
value=strtrim(char(string(value)));
end
