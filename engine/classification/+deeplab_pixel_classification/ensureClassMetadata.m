function ensureClassMetadata(classif)
% Ensure DeepLab semantic-pixel classifiers have stable class metadata.

if isempty(classif)
    return;
end

try
    classif.classifierPkg = 'deeplab_pixel_classification';
    classif.trainingFun = 'deeplab_pixel_classification.train';
    classif.classifyFun = 'deeplab_pixel_classification.classify';
    classif.category = {'Pixel'};

    if isempty(classif.classes)
        classif.classes = {'background', 'structure'};
    end
    if isempty(classif.colormap) || size(classif.colormap, 1) < numel(classif.classes) + 1
        classif.colormap = shallowColormap(numel(classif.classes));
    end
    if isempty(classif.outputType)
        classif.outputType = 'segmentation';
    end
catch
end
end
