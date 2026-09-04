function [values, spec] = readGroundTruth(roiObj, definition)
%CELLLATENTMODEL.SIGNAL.READGROUNDTRUTH Read GT with its identity contract.
spec=cellLatentModel.signal.annotationSpec(definition);
if strcmp(definition.task,'segmentation')
    idx=roiObj.findChannelID(definition.ground_truth_channel,'exact');
    if isempty(idx), error('cellLatentModel:MissingSignalGroundTruth','Signal GT channel is missing.'); end
    values=roiObj.image(:,:,idx(1),:);
else
    idx=find(arrayfun(@(x)strcmp(char(string(x.groupid)),definition.ground_truth_group),roiObj.data),1);
    if isempty(idx), error('cellLatentModel:MissingSignalGroundTruth','Signal GT dataseries is missing.'); end
    values=roiObj.data(idx).data;
end
end
