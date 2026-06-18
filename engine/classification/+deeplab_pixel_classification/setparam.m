function out = setparam(classif)
% deeplab_pixel_classification.setparam
% Initialize training parameters for DeepLab v3+ pixel classification.

out = deeplab_pixel_classification.utils.outInitSafe('deeplab_pixel_classification.setparam');
tp = deeplab_pixel_classification.utils.defaultTrainingParam();

try
    classif.trainingParam = tp;
    classif.classifierPkg = 'deeplab_pixel_classification';
    classif.trainingFun = 'deeplab_pixel_classification.train';
    classif.classifyFun = 'deeplab_pixel_classification.classify';
    classif.category = {'Pixel'};
    if isempty(classif.outputType)
        classif.outputType = 'segmentation';
    end
catch
end

out.refs.trainingParam = tp;
out.status = "OK";
end
