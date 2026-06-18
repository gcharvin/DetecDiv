function out = setparam(classif)
% cellposesam.setparam  Initialize training parameters for CellposeSAM.

out = cellposesam.utils.outInitSafe('cellposesam.setparam');
classif.trainingParam = cellposesam.utils.defaultTrainingParam();
cellposesam.ensureClassMetadata(classif);
out.refs.trainingParam = classif.trainingParam;
out.status = "OK";
end
