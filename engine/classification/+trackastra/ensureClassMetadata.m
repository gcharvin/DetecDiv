function ensureClassMetadata(classif)
% trackastra.ensureClassMetadata  Keep Trackastra classifier metadata stable.

if isempty(classif)
    return;
end
try
    classif.classifierPkg = 'trackastra';
    classif.trainingFun = 'trackastra.train';
    classif.classifyFun = 'trackastra.classify';
    classif.category = {'Pixel'};
    classif.classes = {'tracklet'};
    classif.description = {'Trackastra cell tracking', ...
        'Links existing instance masks into stable temporal tracklets.'};
    classif.outputType = 'segmentation';
    if isempty(classif.colormap) || size(classif.colormap,1) < 2
        classif.colormap = shallowColormap(1);
    end
catch
end
end
