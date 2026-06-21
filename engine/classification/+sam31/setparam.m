function out = setparam(classif)
% sam31.setparam  Initialize SAM3.1 training/inference parameters.

out = sam31.utils.outInitSafe('sam31.setparam');
classif.trainingParam = sam31.utils.defaultTrainingParam();
sam31.ensureClassMetadata(classif);
out.refs.trainingParam = classif.trainingParam;
out.status = "OK";
end
