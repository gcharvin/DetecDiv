function out = setparam(classif)
% trackastra.setparam  Initialize training and inference parameters.

out = trackastra.utils.outInitSafe('trackastra.setparam');
trackastra.ensureClassMetadata(classif);
classif.trainingParam = trackastra.utils.defaultTrainingParam();
classif.trainingParam.groundTruthChannelName = trackastra.annotationChannelName(classif);
classif.executionParam = trackastra.utils.defaultExecutionParam();
out.refs.trainingParam = classif.trainingParam;
out.refs.executionParam = classif.executionParam;
out.status = "OK";
end
