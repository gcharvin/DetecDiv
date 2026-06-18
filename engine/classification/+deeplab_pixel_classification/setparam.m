function out = setparam(classif)
% deeplab_pixel_classification.setparam
% Initialize training parameters for DeepLab v3+ pixel classification.

out = deeplab_pixel_classification.utils.outInitSafe('deeplab_pixel_classification.setparam');
tp = deeplab_pixel_classification.utils.defaultTrainingParam();

try
    classif.trainingParam = tp;
    deeplab_pixel_classification.ensureClassMetadata(classif);
catch
end

out.refs.trainingParam = tp;
out.status = "OK";
end
