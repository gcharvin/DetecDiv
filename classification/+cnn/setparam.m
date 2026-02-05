function tp = setparam(classif)
% cnn.setparam  Initialize training parameters for CNN image classifier.

tp = cnn.utils.defaultTrainingParam();
classif.trainingParam = tp;
end
