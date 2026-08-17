function ensureClassMetadata(classif)
% Ensure CellposeSAM classifiers keep instance-segmentation metadata.

if isempty(classif)
    return;
end

try
    userComment='';
    try
        previous=classif.description;
        if iscell(previous)&&numel(previous)>=2,userComment=char(string(previous{2}));end
    catch
    end
    classif.classifierPkg = 'cellposesam';
    classif.trainingFun = 'cellposesam.train';
    classif.classifyFun = 'cellposesam.classify';
    classif.category = {'Pixel'};
    classif.description={ ...
        'CellposeSAM segmentation only',userComment, ...
        ['[TRAIN] CellposeSAM instance-segmentation weights. [INPUT] microscopy ' ...
         'images; [GT] reviewed instance masks; [PRED] frame-local instances. ' ...
         'No tracking or lineage model is changed.']};

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
