function ensureClassMetadata(classif)
% Ensure CellposeSAM classifiers keep instance-segmentation metadata.

if isempty(classif)
    return;
end

try
    classif.classifierPkg = 'cellposesam';
    classif.trainingFun = 'cellposesam.train';
    classif.classifyFun = 'cellposesam.classify';
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
