function out = setparam(classif)
%CELLLATENTTRACKER.SETPARAM Initialize tracker training and inference.
out = cellLatentModel.utils.outInitSafe('cellLatentTracker.setparam');
if nargin < 1 || isempty(classif) || ~isa(classif,'classi')
    out.refs.trainingParam = cellLatentTracker.utils.defaultTrainingParam();
    out.refs.executionParam = cellLatentTracker.utils.defaultExecutionParam();
    out.status = "OK";
    return;
end
cellLatentTracker.ensureClassMetadata(classif);
classif.trainingParam = cellLatentTracker.utils.defaultTrainingParam();
classif.trainingParam.groundTruthChannelName = ...
    cellLatentTracker.annotationChannelName(classif);
classif.executionParam = cellLatentTracker.utils.defaultExecutionParam();
out.refs.trainingParam = classif.trainingParam;
out.refs.executionParam = classif.executionParam;
out.status = "OK";
end
