function ensureClassMetadata(classif)
% Ensure SAM3.1 classifiers keep instance tracking metadata.

if isempty(classif)
    return;
end

try
    userComment='';
    try d=classif.description;if iscell(d)&&numel(d)>=2,userComment=char(string(d{2}));end,catch,end
    classif.classifierPkg = 'sam31';
    classif.trainingFun = 'sam31.train';
    classif.classifyFun = 'sam31.classify';
    classif.category = {'Pixel'};
    classif.description={'SAM3.1 segmentation and video memory',userComment, ...
        ['[TRAIN] Only sub-modules selected by trainModules. [INPUT] microscopy ' ...
         'movies; [GT] reviewed tracked instances; [PRED] instance/tracking ' ...
         'masks. Optional bud pairing is inference post-processing.']};

    if isempty(classif.classes)
        classif.classes = {'cell'};
    end
    if isempty(classif.colormap) || size(classif.colormap, 1) < numel(classif.classes) + 1
        classif.colormap = shallowColormap(numel(classif.classes));
    end
    if isempty(classif.outputType)
        classif.outputType = 'segmentation';
    end
    if isprop(classif, 'trainingParam') && isstruct(classif.trainingParam)
        classif.trainingParam = sam31.utils.normalizeTrainingParam(classif.trainingParam);
    end
catch
end
end
