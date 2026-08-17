function ensureClassMetadata(classif)
% Ensure DeepLab semantic-pixel classifiers have stable class metadata.

if isempty(classif)
    return;
end

try
    userComment='';
    try d=classif.description;if iscell(d)&&numel(d)>=2,userComment=char(string(d{2}));end,catch,end
    classif.classifierPkg = 'deeplab_pixel_classification';
    classif.trainingFun = 'deeplab_pixel_classification.train';
    classif.classifyFun = 'deeplab_pixel_classification.classify';
    classif.category = {'Pixel'};
    classif.description={'DeepLab v3+ semantic segmentation',userComment, ...
        ['[TRAIN] DeepLab semantic-pixel network only. [INPUT] microscopy ' ...
         'images; [GT] reviewed semantic masks; [PRED] semantic masks and ' ...
         'probabilities. Tracking and lineage remain frozen.']};

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
