function out = setparam(classif)
% trackastra.setparam  Initialize training and inference parameters.

out = trackastra.utils.outInitSafe('trackastra.setparam');
classif.trainingParam = trackastra.utils.defaultTrainingParam();
classif.executionParam = trackastra.utils.defaultExecutionParam();
trackastra.ensureClassMetadata(classif);
out.refs.trainingParam = classif.trainingParam;
out.refs.executionParam = classif.executionParam;
out.status = "OK";
end
