function out = setparam(classif)
%BUDMOTHERLINKER.SETPARAM Initialize the trainable lineage classifier.

if nargin < 1 || isempty(classif) || ~isa(classif, 'classi')
    out = budMotherLinker.utils.outInitSafe('budMotherLinker.setparam');
    out.refs.trainingParam = budMotherLinker.utils.defaultTrainingParam();
    out.refs.executionParam = budMotherLinker.utils.defaultExecutionParam();
    out.status = "OK";
    return;
end

budMotherLinker.ensureClassMetadata(classif);
classif.trainingParam = budMotherLinker.utils.defaultTrainingParam();
classif.executionParam = budMotherLinker.utils.defaultExecutionParam();

out = budMotherLinker.utils.outInitSafe('budMotherLinker.setparam');
out.refs.trainingParam = classif.trainingParam;
out.refs.executionParam = classif.executionParam;
out.status = "OK";
end
