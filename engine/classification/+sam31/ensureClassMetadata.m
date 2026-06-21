function ensureClassMetadata(classif)
% Ensure SAM3.1 classifiers keep instance tracking metadata.

if isempty(classif)
    return;
end

try
    classif.classifierPkg = 'sam31';
    classif.trainingFun = 'sam31.train';
    classif.classifyFun = 'sam31.classify';
    classif.category = {'Pixel'};

    if isempty(classif.classes)
        classif.classes = {'cell'};
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
