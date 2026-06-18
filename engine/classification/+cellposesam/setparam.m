function out = setparam(classif)
% cellposesam.setparam  Initialize training parameters for CellposeSAM.

out = cellposesam.utils.outInitSafe('cellposesam.setparam');
classif.trainingParam = cellposesam.utils.defaultTrainingParam();
classif.classifierPkg = 'cellposesam';
classif.trainingFun = 'cellposesam.train';
classif.classifyFun = 'cellposesam.classify';
classif.category = {'Pixel'};
out.refs.trainingParam = classif.trainingParam;
out.status = "OK";
end
