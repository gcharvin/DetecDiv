function out = setparam(classif)
%CELLLATENTMODEL.SETPARAM Initialize the builtin trainable classifier.
if nargin < 1 || isempty(classif) || ~isa(classif,'classi')
    out = cellLatentModel.utils.outInitSafe('cellLatentModel.setparam');
    out.refs.trainingParam = ...
        cellLatentModel.utils.defaultTrainingParam();
    out.refs.executionParam = ...
        cellLatentModel.utils.defaultExecutionParam();
    out.status = "OK";
    return;
end
cellLatentModel.ensureClassMetadata(classif);
classif.trainingParam = cellLatentModel.utils.defaultTrainingParam();
classif.executionParam = cellLatentModel.utils.defaultExecutionParam();
out = cellLatentModel.utils.outInitSafe('cellLatentModel.setparam');
out.refs.trainingParam = classif.trainingParam;
out.refs.executionParam = classif.executionParam;
out.status = "OK";
end
